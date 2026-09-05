import UIKit
import AVFoundation
import CoreMotion
import Combine

@MainActor
final class NightEngine: NSObject, ObservableObject {
    enum Phase { case idle, sleeping, ringing, snoozing }
    @Published private(set) var phase: Phase = .idle
    @Published var now = Date()
    @Published var error: String?
    @Published private(set) var recording = false
    @Published var previewID: String?
    private var store: SleepStore?
    private var scheduler: ReminderScheduler?
    private var player: AVAudioPlayer?
    private var preview: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var chunkStarted = Date()
    private var chunkHasSound = false
    private var lastCheckpoint = Date()
    private var ringStarted = Date()
    private let motion = CMMotionManager()
    private var shakeSamples = 0
    private var clipCount = 0
    private var starting = false
    @Published var motionProgress = 0.0
    @Published private(set) var lightLevel = 0.0
    private var previousBrightness: CGFloat?
    private var previousIdleTimer: Bool?
    private let classificationQueue = DispatchQueue(label: "Alarma.clipClassification", qos: .utility)
    func configure(store: SleepStore, scheduler: ReminderScheduler) { self.store = store; self.scheduler = scheduler }
    var isActive: Bool { phase != .idle }
    var activeAlarm: WakeAlarm? { store?.data.activeNight?.alarm }
    var ringingAlarm: WakeAlarm? { phase == .ringing || phase == .snoozing ? activeAlarm : nil }
    var isSnoozing: Bool { phase == .snoozing }
    var snoozedUntil: Date? { isSnoozing ? wakeAt : nil }
    func start(alarm: WakeAlarm, dreamStore: DreamStore, recordAudio: Bool, soundRetentionDays: Int?) {
        guard let scheduler else { return }
        Task { await start(alarm: alarm, store: dreamStore.store, scheduler: scheduler) }
    }
    func stop() { finish() }
    private func restoreDisplay() {
        if let previousBrightness { UIScreen.main.brightness = previousBrightness }
        if let previousIdleTimer { UIApplication.shared.isIdleTimerDisabled = previousIdleTimer }
        previousBrightness = nil; previousIdleTimer = nil; lightLevel = 0
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaReset), name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    }
    var wakeAt: Date? { store?.data.activeNight?.wakeAt }
    var elapsed: TimeInterval { now.timeIntervalSince(store?.data.activeNight?.startedAt ?? now) }

    func start(alarm: WakeAlarm, store: SleepStore, scheduler: ReminderScheduler) async {
        guard phase == .idle, !starting, let wake = alarm.nextDate(after: Date()) else { return }
        guard store.data.activeNight == nil else {
            error = L("A previous night has not been saved successfully. Restart the app to recover it before starting another.")
            return
        }
        starting = true
        defer { starting = false }
        stopPreview()
        self.store = store; self.scheduler = scheduler
        guard await scheduler.requestPermission() else { error = scheduler.error; return }
        var record = store.data.recordSounds
        if record {
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard granted else { error = L("Microphone access is off. Enable it in Settings or turn off night recording."); return }
            record = granted
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(record ? .playAndRecord : .playback, mode: .default,
                                    options: record ? [.defaultToSpeaker] : [])
            try session.setActive(true)
            try playLoop("ambient", volume: 0.22)
            let date = Date()
            store.change { $0.activeNight = ActiveNight(startedAt: date, lastCheckpoint: date, wakeAt: wake, alarm: alarm) }
            guard store.data.activeNight != nil else { throw CocoaError(.fileWriteUnknown) }
            try await scheduler.scheduleNight(at: wake)
            // The dedicated session reminder replaces this alarm's ordinary reminder during the night.
            scheduler.cancelReminder(for: alarm)
            previousBrightness = UIScreen.main.brightness
            previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
            if alarm.lightWakeEnabled { UIApplication.shared.isIdleTimerDisabled = true }
            phase = .sleeping; now = date; lastCheckpoint = date; clipCount = 0
            if record { try startChunk(); recording = true }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch {
            self.error = LF("The night could not start: %@", String(describing: error.localizedDescription))
            finish(interrupted: true)
        }
    }
    func tick() {
        now = Date()
        guard let store, let active = store.data.activeNight else { return }
        if now.timeIntervalSince(lastCheckpoint) >= 30 {
            lastCheckpoint = now
            store.change { $0.activeNight?.lastCheckpoint = self.now }
        }
        if (phase == .sleeping || phase == .snoozing), now >= active.wakeAt { ring() }
        if phase == .ringing {
            if active.alarm.lightWakeEnabled {
                lightLevel = min(1, now.timeIntervalSince(ringStarted) / Double(max(1, active.alarm.lightWakeMinutes) * 60))
                UIScreen.main.brightness = max(previousBrightness ?? 0, CGFloat(lightLevel))
            }
            let fade = Double(max(1, active.alarm.fadeSeconds))
            player?.volume = active.alarm.fadeSeconds == 0 ? 1 : Float(min(1, 0.06 + now.timeIntervalSince(ringStarted) / fade * 0.94))
        }
        if recording {
            recorder?.updateMeters()
            if (recorder?.averagePower(forChannel: 0) ?? -160) > -24 { chunkHasSound = true }
            if now.timeIntervalSince(chunkStarted) >= 12 {
                closeChunk()
                if clipCount < 120 {
                    do { try startChunk() } catch { recording = false; self.error = LF("Recording stopped: %@", String(describing: error.localizedDescription)) }
                } else { recording = false; self.error = L("The 120-clip limit was reached. Your alarm is still active.") }
            }
        }
    }
    private func ring() {
        guard let store, let active = store.data.activeNight else { return }
        closeChunk(); recording = false
        phase = .ringing; ringStarted = Date()
        var playable = active.alarm
        playable.sounds = playable.sounds.filter { SleepStore.soundURL($0) != nil }
        let sound = playable.chooseSound(previous: store.data.lastSound)
        store.change { $0.lastSound = sound }
        do { try playLoop(sound, volume: active.alarm.fadeSeconds == 0 ? 1 : 0.06) }
        catch { self.error = LF("Alarm audio stopped: %@. The backup reminder remains scheduled.", String(describing: error.localizedDescription)) }
        if active.alarm.shakeToSnooze, motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 0.1
            motion.startAccelerometerUpdates(to: .main) { [weak self] sample, _ in
                guard let sample else { return }
                let a = sample.acceleration
                let magnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
                Task { @MainActor in
                    guard let self, self.phase == .ringing else { return }
                    self.shakeSamples = magnitude > 2.4 ? self.shakeSamples + 1 : 0
                    self.motionProgress = min(1, Double(self.shakeSamples) / 2)
                    if self.shakeSamples >= 2 { await self.snooze() }
                }
            }
        }
    }
    func snooze() async {
        guard phase == .ringing, let store, let alarm = store.data.activeNight?.alarm else { return }
        phase = .snoozing
        lightLevel = 0; motionProgress = 0
        if let previousBrightness { UIScreen.main.brightness = previousBrightness }
        motion.stopAccelerometerUpdates(); shakeSamples = 0
        let next = Date().addingTimeInterval(Double(alarm.snoozeMinutes) * 60)
        do {
            try await scheduler?.scheduleNight(at: next)
            try playLoop("ambient", volume: 0.22)
            store.change { $0.activeNight?.wakeAt = next }
            phase = .snoozing
        } catch { phase = .ringing; self.error = LF("Could not snooze: %@", String(describing: error.localizedDescription)) }
    }
    func finish(interrupted: Bool = false) {
        restoreDisplay(); motionProgress = 0
        timer?.invalidate(); timer = nil
        motion.stopAccelerometerUpdates()
        closeChunk(); recording = false
        player?.stop(); player = nil
        let alarm = store?.data.activeNight?.alarm
        store?.finishNight(at: Date(), interrupted: interrupted)
        if !interrupted, let alarm, alarm.weekdays.isEmpty {
            store?.change { data in
                if let index = data.alarms.firstIndex(where: { $0.id == alarm.id }) { data.alarms[index].enabled = false }
            }
        }
        phase = .idle
        if !interrupted { scheduler?.cancelNight() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if let store, let scheduler { Task { await scheduler.sync([]) } }
    }
    private func playLoop(_ name: String, volume: Float) throws {
        guard let url = SleepStore.soundURL(name) else { throw CocoaError(.fileNoSuchFile) }
        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.numberOfLoops = -1; newPlayer.volume = volume
        newPlayer.delegate = self
        newPlayer.prepareToPlay()
        guard newPlayer.play() else { throw CocoaError(.fileReadUnknown) }
        player?.stop(); player = newPlayer
    }
    func playPreview(_ name: String, url: URL? = nil) {
        guard phase == .idle else { return }
        if previewID == name { stopPreview(); return }
        do {
            stopPreview()
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            guard let soundURL = url ?? Bundle.main.url(forResource: name, withExtension: "wav") else { throw CocoaError(.fileNoSuchFile) }
            preview = try AVAudioPlayer(contentsOf: soundURL)
            preview?.volume = 0.6; preview?.delegate = self
            guard preview?.play() == true else { throw CocoaError(.fileReadUnknown) }
            previewID = name
        } catch { self.error = LF("Could not play audio: %@", String(describing: error.localizedDescription)) }
    }
    func stopPreview() {
        preview?.stop(); preview = nil; previewID = nil
        if phase == .idle { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
    private func startChunk() throws {
        try FileManager.default.createDirectory(at: SleepStore.clipsDirectory, withIntermediateDirectories: true)
        let url = SleepStore.clipsDirectory.appendingPathComponent("\(UUID()).m4a")
        recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22050, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 32000])
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        guard recorder?.record() == true else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        chunkStarted = Date(); chunkHasSound = false
    }
    private func closeChunk() {
        guard let recorder else { return }
        let seconds = recorder.currentTime
        let url = recorder.url
        recorder.stop(); self.recorder = nil
        if chunkHasSound, seconds >= 1, let store, store.data.activeNight != nil {
            let clip = SoundClip(date: chunkStarted, fileName: url.lastPathComponent, seconds: seconds)
            store.change { $0.activeNight?.clips.append(clip) }
            clipCount += 1
            classificationQueue.async {
                let kind = ClipClassifier.classify(url: url)
                Task { @MainActor in store.setClipKind(id: clip.id, kind: kind) }
            }
        } else { try? FileManager.default.removeItem(at: url) }
    }
    @objc private func interrupted(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              raw == AVAudioSession.InterruptionType.began.rawValue else { return }
        stopPreview()
        if phase != .idle {
            finish(interrupted: true)
            error = L("Audio was interrupted. This night has been saved; restart it to resume. Your backup reminder remains scheduled.")
        }
    }
    @objc private func routeChanged(_ note: Notification) {
        guard let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
        stopPreview()
        if phase != .idle { finish(interrupted: true); error = L("The audio device disconnected. Restart your night to check the speaker.") }
    }
    @objc private func mediaReset() {
        stopPreview()
        if phase != .idle { finish(interrupted: true); error = L("iPhone audio restarted. Your night was saved. Start a new session to continue.") }
    }
}

extension NightEngine: AVAudioPlayerDelegate, AVAudioRecorderDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if player === self.player, self.phase != .idle {
                self.finish(interrupted: true)
                self.error = L("Night audio stopped unexpectedly. Your night was saved and the backup reminder remains scheduled.")
            } else if player === self.preview { self.stopPreview() }
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            if player === self.player { self.finish(interrupted: true) }
            else if player === self.preview { self.stopPreview() }
            self.error = L("Audio could not continue. Check your night session before relying on the alarm.")
        }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            guard recorder === self.recorder else { return }
            self.closeChunk(); self.recording = false
            self.error = L("Night sound recording stopped. Your wake-up audio is still active.")
        }
    }
}
