import AVFoundation
import UIKit
import CoreMotion

@MainActor
final class NightAudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playing: String?
    private var player: AVAudioPlayer?
    @Published var captureState = "recordOff"
    @Published var inputLevel = -100.0
    private var engine: AVAudioEngine?
    private var worker: CaptureWorker?
    private var generation = UUID()
    private var capturedRate = 0.0
    private var lastInput = Date.distantPast
    var inputStalled: Bool { worker != nil && Date().timeIntervalSince(lastInput) > 5 }
    var needsRebuild: Bool {
        guard worker != nil, let engine else { return false }
        return !engine.isRunning || engine.inputNode.outputFormat(forBus: 0).sampleRate != capturedRate
    }
    private var ramp: Timer?
    var onFailure: ((Error) -> Void)?
    private let motion = CMMotionManager()
    private var previousBrightness: CGFloat?
    private var previousIdle: Bool?
    var hasCapture: Bool { worker != nil }
    var isRecording: Bool { engine?.isRunning == true && worker != nil }
    var canResume: Bool { !isRecording && captureState != "recordOff" && captureState != "recordAlarm" }

    func microphoneAllowed() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
    }
    func startRecording(nightID: UUID, wake: Date, margin: Double, byteLimit: Int, receive: @escaping (ClipReceipt) -> Void, progress: @escaping (Date) -> Void) throws {
        guard !isRecording, worker == nil else { return }
        guard AVAudioSession.sharedInstance().recordPermission == .granted else { captureState = "recordDenied"; throw CaptureError.permission }
        guard !isRecording else { throw CaptureError.playbackDuringCapture }
        stopPlayback()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate >= 8000, format.channelCount > 0 else { throw CaptureError.input }
        let generation = UUID(); self.generation = generation
        let worker = try CaptureWorker(nightID: nightID, start: Date(), deadline: wake.addingTimeInterval(-2), rate: format.sampleRate, margin: margin, directory: DiskLocation.clips, byteLimit: byteLimit,
            receipt: { value in Task { @MainActor in receive(value) } },
            progress: { [weak self] date, level, calibrated in Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.lastInput = Date(); self.inputLevel = level
                if self.isRecording { self.captureState = calibrated ? "recordListening" : "recordCalibrating" }
                progress(date)
            } },
            failure: { [weak self] error in Task { @MainActor in
                guard let self, self.generation == generation else { return }
                await self.stopRecording(reason: "recordError"); self.onFailure?(error)
            } },
            deadlineReached: { [weak self] in Task { @MainActor in
                guard let self, self.generation == generation else { return }
                await self.stopRecording(reason: "recordAlarm")
            } })
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            worker.enqueue(Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))))
        }
        do {
            engine.prepare(); try engine.start()
            self.engine = engine; self.worker = worker; self.capturedRate = format.sampleRate; self.lastInput = Date(); captureState = "recordCalibrating"
        } catch { input.removeTap(onBus: 0); engine.stop(); try? session.setActive(false); captureState = "recordError"; throw error }
    }
    @discardableResult
    func stopRecording(reason: String = "recordPaused") async -> Date? {
        let worker = self.worker
        if reason == "recordReset" {
            generation = UUID(); ramp?.invalidate(); ramp = nil; player = nil; playing = nil; restoreScreen()
        } else if let engine { engine.inputNode.removeTap(onBus: 0); engine.stop() }
        engine = nil; self.worker = nil; captureState = reason
        let end = await worker?.stop()
        if player == nil { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        return end
    }
    func play(url: URL, id: String, loop: Bool = false, gradual: Bool = false) throws {
        stopPlayback()
        let session = AVAudioSession.sharedInstance()
        if !isRecording { try session.setCategory(.playback, mode: .default) }
        try session.setActive(true)
        let audio = try AVAudioPlayer(contentsOf: url)
        audio.delegate = self; audio.numberOfLoops = loop ? -1 : 0; audio.volume = gradual ? 0.05 : 1
        guard audio.play() else { throw CocoaError(.fileReadUnknown) }
        player = audio; playing = id
        if gradual {
            ramp = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                Task { @MainActor in
                guard let player = self?.player else { timer.invalidate(); return }
                player.volume = min(1, player.volume + 0.025)
                if player.volume >= 1 { timer.invalidate() }
                }
            }
        }
    }
    func stopPlayback() { ramp?.invalidate(); ramp = nil; player?.stop(); player = nil; playing = nil }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { Task { @MainActor in self.stopPlayback() } }
    func watchMovement(action: @escaping () -> Void) {
        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = 0.2
        let after = Date().addingTimeInterval(3)
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let a = data?.acceleration, Date() > after else { return }
            if sqrt(a.x*a.x + a.y*a.y + a.z*a.z) > 1.65 { self?.motion.stopAccelerometerUpdates(); action() }
        }
    }
    func updateLight(wake: Date, minutes: Int) {
        guard minutes > 0 else { return }
        if previousBrightness == nil { previousBrightness = UIScreen.main.brightness; previousIdle = UIApplication.shared.isIdleTimerDisabled }
        UIApplication.shared.isIdleTimerDisabled = true
        let fraction = 1 - wake.timeIntervalSinceNow / Double(minutes * 60)
        if fraction > 0 { UIScreen.main.brightness = max(previousBrightness ?? 0.2, min(1, fraction)) }
    }
    func restoreScreen() {
        motion.stopAccelerometerUpdates()
        if let previousBrightness { UIScreen.main.brightness = previousBrightness }; previousBrightness = nil
        if let previousIdle { UIApplication.shared.isIdleTimerDisabled = previousIdle }; previousIdle = nil
    }
    func stopAll() async {
        await stopRecording(reason: "recordOff"); stopPlayback(); restoreScreen()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct ToneLibrary {
    static let builtins = ["aurora", "lumen", "brisa"]
    static func url(_ id: String, imported: [ImportedTone]) -> URL? {
        if builtins.contains(id) { return Bundle.main.url(forResource: id, withExtension: "wav") }
        guard let tone = imported.first(where: { $0.id == id }) else { return nil }
        return DiskLocation.child(tone.filename, of: DiskLocation.tones)
    }
    static func filename(_ id: String, imported: [ImportedTone]) -> String { imported.first { $0.id == id }?.filename ?? "\(id).wav" }
    static func prepare(_ source: URL) throws -> ImportedTone {
        let access = source.startAccessingSecurityScopedResource(); defer { if access { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.createDirectory(at: DiskLocation.tones, withIntermediateDirectories: true)
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let frames = min(input.length, AVAudioFramePosition(format.sampleRate * 29))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { throw CocoaError(.fileReadCorruptFile) }
        try input.read(into: buffer, frameCount: AVAudioFrameCount(frames))
        let id = UUID().uuidString; let filename = id + ".caf"
        let target = DiskLocation.tones.appendingPathComponent(filename)
        do {
            let output = try AVAudioFile(forWriting: target, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: format.channelCount, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
            try output.write(from: buffer)
        } catch { try? FileManager.default.removeItem(at: target); throw error }
        return ImportedTone(id: id, name: source.deletingPathExtension().lastPathComponent, filename: filename)
    }
}

enum CaptureError: Error { case permission, input, playbackDuringCapture }
