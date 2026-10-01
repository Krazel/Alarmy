import SwiftUI
import UIKit
import AVFoundation

@MainActor
final class SleepStore: ObservableObject {
    @Published var archive = AppArchive()
    @Published var loaded = false
    @Published var failed = false
    @Published var error: String?
    @Published var tab = 0
    @Published var ringing = false
    @Published var busy = false
    @Published var saving = false
    @Published var writeFailed = false
    @Published var selectedDay = Date()
    @Published var analyzing = Set<UUID>()
    @Published var clipPresented = false
    let audio = NightAudio()
    let repository: ArchiveRepository
    private let scheduler = WakeScheduler()
    var writeTail: Task<Bool, Never>?
    private var timer: Timer?
    private var lastCheckpoint = Date.distantPast
    var audioInterrupted = false
    private var writesPending = 0
    var captureBusy = false
    var resumeAfterInterruption = false
    var words: Words { Words(language: archive.preferences.language) }
    var testMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--ui-test")
        #else
        return false
        #endif
    }
    init(repository: ArchiveRepository? = nil) {
        if let repository { self.repository = repository; return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-test") {
            let args = ProcessInfo.processInfo.arguments
            let index = args.firstIndex(of: "--archive-id")
            let identifier = index.flatMap { $0 + 1 < args.count ? args[$0+1] : nil } ?? UUID().uuidString
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("UI-" + (UUID(uuidString: identifier)?.uuidString ?? UUID().uuidString))
            self.repository = ArchiveRepository(file: root.appendingPathComponent("archive.json"))
        } else { self.repository = ArchiveRepository() }
        #else
        self.repository = ArchiveRepository()
        #endif
    }
    func load() async {
        guard !loaded else { return }
        do {
            archive = try await repository.load()
            do { archive = try await repository.prune() } catch { self.error = error.localizedDescription }
            #if DEBUG
            if testMode && archive.revision == 0 {
                archive.preferences.language = ProcessInfo.processInfo.arguments.contains("--spanish") ? "es" : "en"
                archive.preferences.appearance = "dawn"
                if ProcessInfo.processInfo.arguments.contains("--design-fixture") {
                    let end = Calendar.current.date(bySettingHour: 7, minute: 15, second: 0, of: Date())!
                    let begin = end.addingTimeInterval(-8*3600-5*60)
                    archive.sessions = [SleepSession(id: UUID(), start: begin, checkpoint: end, end: end, wake: end, alarmID: UUID(), soundID: "aurora")]
                    archive.pages[CalendarDay.key(Date())] = JournalPage(feeling: .peaceful, text: "Ejemplo de diseño: una mañana tranquila, luz en la ventana y un sueño junto al mar.")
                    if ProcessInfo.processInfo.arguments.contains("--clip-fixture"), let tone = ToneLibrary.url("aurora", imported: []) {
                        try FileManager.default.createDirectory(at: DiskLocation.clips, withIntermediateDirectories: true)
                        for i in 0..<2 {
                            let id = UUID(), filename = id.uuidString + ".wav"
                            try FileManager.default.copyItem(at: tone, to: DiskLocation.clips.appendingPathComponent(filename))
                            var clip = NightClip(id: id, created: begin.addingTimeInterval(Double(i+1)*3600), filename: filename, duration: 24)
                            clip.kind = i == 0 ? .snore : .cough; clip.suggestion = true; clip.analysisDone = true; clip.analysisVersion = SoundTagger.version
                            clip.events = [SoundEvent(start: 2, duration: 1.5, kind: clip.kind, confidence: 0.9)]
                            archive.sessions[0].clips.append(clip)
                        }
                    }
                }
                let fixture = archive
                _ = try await repository.update { $0 = fixture }
            }
            #endif
            loaded = true
            await recoverClips()
            await prune()
            if archive.active != nil {
                audio.captureState = "recordRecovered"
                commit { value in
                    value.active?.capturePaused = true
                    if let count = value.active?.captureSpans?.count, count > 0 { value.active?.captureSpans?[count-1].reason = "recordRecovered" }
                }
                // An old recovered night must not ring days after its scheduled wake.
                if let night = archive.active, Date().timeIntervalSince(night.wake) > 15*60 {
                    commit { $0.active?.interrupted = true }
                    await finish(at: min(night.checkpoint, night.wake))
                }
            }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
            await resume()
        } catch { failed = true; loaded = true; self.error = words("storageError") }
    }
    @discardableResult
    func commit(_ change: @escaping @Sendable (inout AppArchive) -> Void) -> Task<Bool, Never> {
        guard !failed else { return Task { false } }
        change(&archive); writesPending += 1; saving = true
        let snapshot = archive
        let preceding = writeTail
        let task = Task { [weak self] in
            if let preceding { _ = await preceding.value }
            guard let self else { return false }
            do {
                _ = try await repository.update { value in let revision = value.revision; value = snapshot; value.revision = revision }
                self.writesPending -= 1; self.saving = self.writesPending > 0
                if self.writesPending == 0 { self.writeFailed = false }
                return true
            } catch {
                self.error = error.localizedDescription; self.writeFailed = true
                self.writesPending -= 1; self.saving = self.writesPending > 0
                self.archive.active?.capturePaused = true
                await self.audio.stopRecording(reason: "recordError"); return false
            }
        }
        writeTail = task
        return task
    }
    func plan(_ edit: (inout AlarmPlan) -> Void) {
        guard archive.active == nil else { return }
        var plan = archive.plan; edit(&plan); let next = plan
        commit { $0.plan = next }
    }
    func preferences(_ edit: (inout Preferences) -> Void) {
        var prefs = archive.preferences; edit(&prefs); let next = prefs
        commit { $0.preferences = next }
    }
    func page(_ day: Date) -> JournalPage { archive.pages[CalendarDay.key(day)] ?? JournalPage() }
    func note(_ text: String, day: Date) { let key = CalendarDay.key(day); commit { $0.pages[key, default: JournalPage()].text = text } }
    func feeling(_ feeling: MorningFeeling, day: Date) { let key = CalendarDay.key(day); commit { $0.pages[key, default: JournalPage()].feeling = feeling } }
    func sessions(_ day: Date) -> [SleepSession] { archive.sessions.filter { Calendar.current.isDate($0.end ?? $0.start, inSameDayAs: day) } }
    func start() async {
        guard !busy, archive.active == nil, !failed else { return }; busy = true; defer { busy = false }
        do {
            if archive.preferences.record && !testMode {
                guard await audio.microphoneAllowed() else { error = words("micError"); return }
            }
            guard let wake = archive.plan.next(after: Date()) else { return }
            let tone = archive.plan.sound(excluding: archive.lastSound)
            let previousSound = archive.lastSound
            let night = SleepSession(id: UUID(), start: Date(), checkpoint: Date(), wake: wake, alarmID: UUID(), soundID: tone)
            if !testMode { try await scheduler.schedule(id: night.alarmID, date: wake, filename: ToneLibrary.filename(tone, imported: archive.tones), words: words) }
            guard await commit({ $0.active = night; $0.lastSound = tone }).value else {
                try? scheduler.cancel(id: night.alarmID)
                archive.active = nil; archive.lastSound = previousSound
                return
            }
            do { try beginRecordingIfNeeded() } catch {
                // Preserve the scheduled alarm and any recoverable audio if input fails.
                audio.captureState = "recordError"
                _ = await commit { $0.active?.capturePaused = true }.value
                self.error = words("recordFailure") + " " + error.localizedDescription
            }
            tab = 0
        } catch WakeFailure.permission { error = words("permissionError") }
        catch { self.error = error.localizedDescription }
    }
    func resume() async {
        guard loaded, archive.active != nil, !failed, !audioInterrupted else { return }
        if let dismissal = WakeDismissal.take(), dismissal.alarmID == archive.active?.alarmID.uuidString {
            await finish(at: dismissal.date); return
        }
        if audio.isRecording && AVAudioSession.sharedInstance().recordPermission != .granted { await pauseCapture(reason: "recordDenied") }
        tick()
    }
    func tick() {
        guard let night = archive.active, !busy, !failed else { return }
        if Date().timeIntervalSince(lastCheckpoint) >= 30 {
            lastCheckpoint = Date(); let now = Date(); commit { $0.active?.checkpoint = now }
        }
        if !captureBusy && (audio.inputStalled || audio.needsRebuild) {
            Task { await self.pauseCapture(reason: "recordNoInput") }
        }
        if !captureBusy && audio.isRecording && AVAudioSession.sharedInstance().recordPermission != .granted {
            Task { await self.pauseCapture(reason: "recordDenied") }
        }
        guard UIApplication.shared.applicationState == .active else { return }
        audio.updateLight(wake: night.wake, minutes: archive.plan.lightMinutes)
        if Date() >= night.wake && !ringing && !audioInterrupted {
            ringing = true
            Task { await self.ring(night) }
        }
    }
    private func ring(_ night: SleepSession) async {
            await pauseCapture(reason: "recordAlarm")
            if !testMode { try? scheduler.cancel(id: night.alarmID) }
            do {
                guard let url = ToneLibrary.url(night.soundID, imported: archive.tones) ?? ToneLibrary.url("aurora", imported: []) else { throw CocoaError(.fileNoSuchFile) }
                try audio.play(url: url, id: "wake", loop: true, gradual: archive.plan.gradual)
                if archive.plan.motionSnooze { audio.watchMovement { [weak self] in Task { await self?.snooze() } } }
            } catch { self.error = error.localizedDescription }
    }
    func snooze() async {
        guard !busy, var night = archive.active else { return }; busy = true; defer { busy = false }
        let original = night
        let old = night.alarmID; night.alarmID = UUID(); night.wake = Date().addingTimeInterval(Double(archive.plan.snoozeMinutes * 60))
        do {
            if !testMode { try await scheduler.schedule(id: night.alarmID, date: night.wake, filename: ToneLibrary.filename(night.soundID, imported: archive.tones), words: words) }
            let updated = night
            guard await commit({ $0.active = updated }).value else { try? scheduler.cancel(id: night.alarmID); archive.active = original; return }
            if !testMode { try? scheduler.cancel(id: old) }
            audio.stopPlayback(); audio.restoreScreen(); ringing = false
            try beginRecordingIfNeeded()
        } catch { self.error = error.localizedDescription }
    }
    func finish(at end: Date = Date()) async {
        guard !busy, archive.active != nil else { return }; busy = true; defer { busy = false }
            if let id = archive.active?.alarmID, !testMode { do { try scheduler.cancel(id: id) } catch { self.error = error.localizedDescription } }
            await pauseCapture(reason: "recordOff")
            await audio.stopAll(); ringing = false
            // stopAll flushes the last clip before we snapshot the session.
            guard var night = archive.active else { return }
            night.end = max(night.start, end); night.checkpoint = max(night.start, end); let finished = night
            guard await commit({ $0.sessions.insert(finished, at: 0); $0.active = nil }).value else { return }
            selectedDay = night.end ?? Date()
            if archive.preferences.openJournal { tab = 1 }
    }
    func importTone(_ url: URL) async {
        do {
            let tone = try await Task.detached { try ToneLibrary.prepare(url) }.value
            commit { $0.tones.append(tone); $0.plan.sounds.append(tone.id) }
        } catch { self.error = words("badAudio") }
    }
    func label(_ clip: NightClip, kind: SoundKind) {
        commit { archive in
            for i in archive.sessions.indices {
                if let j = archive.sessions[i].clips.firstIndex(where: { $0.id == clip.id }) {
                    archive.sessions[i].clips[j].kind = kind
                    archive.sessions[i].clips[j].analysisDone = true
                    archive.sessions[i].clips[j].suggestion = false
                    archive.sessions[i].clips[j].analysisVersion = SoundTagger.version
                    archive.sessions[i].clips[j].analysisFailed = nil
                }
            }
        }
    }
    func analyzeClips(for day: Date) async {
        let pending = sessions(day).flatMap(\.clips).filter {
            $0.analysisFailed != true && (!$0.analysisDone || ($0.suggestion && $0.analysisVersion != SoundTagger.version))
        }
        for clip in pending {
            guard !Task.isCancelled else { return }
            await analyze(clip)
        }
    }
    func analyze(_ clip: NightClip) async {
        guard !analyzing.contains(clip.id), let url = DiskLocation.child(clip.filename, of: DiskLocation.clips) else { return }
        analyzing.insert(clip.id); defer { analyzing.remove(clip.id) }
        let result = await SoundTagger.suggest(url: url)
        guard !Task.isCancelled else { return }
        _ = await commit { value in
                for i in value.sessions.indices {
                    if let j = value.sessions[i].clips.firstIndex(where: { $0.id == clip.id }),
                       value.sessions[i].clips[j] == clip {
                        // A manual correction or deletion made while analysing wins.
                        value.sessions[i].clips[j].analysisFailed = !result.completed
                        guard result.completed else { continue }
                        value.sessions[i].clips[j].kind = result.kind
                        value.sessions[i].clips[j].analysisDone = true
                        value.sessions[i].clips[j].suggestion = result.kind != .other
                        value.sessions[i].clips[j].events = result.events
                        value.sessions[i].clips[j].analysisVersion = SoundTagger.version
                    }
                }
        }.value
    }
    func delete(_ clip: NightClip) async {
        audio.stopPlayback()
        guard let owner = archive.sessions.first(where: { $0.clips.contains(where: { $0.id == clip.id }) }) else { return }
        // Save the removal before deleting the audio. Failed writes preserve the file.
        guard await commit({ value in for i in value.sessions.indices { value.sessions[i].clips.removeAll { $0.id == clip.id } } }).value else { return }
        do {
            try await Task.detached {
                if let url = DiskLocation.child(clip.filename, of: DiskLocation.clips), FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }.value
        } catch {
            let message = error.localizedDescription
            _ = await commit { value in
                if let i = value.sessions.firstIndex(where: { $0.id == owner.id }), !value.sessions[i].clips.contains(where: { $0.id == clip.id }) { value.sessions[i].clips.append(clip) }
            }.value
            self.error = message
        }
    }
    func flush() async {
        let token = UIApplication.shared.beginBackgroundTask(withName: "Save journal")
        if let writeTail { _ = await writeTail.value }
        if token != .invalid { UIApplication.shared.endBackgroundTask(token) }
    }
    func prune() async {
        guard archive.preferences.keepDays > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(archive.preferences.keepDays)*86400)
        let expired = (archive.sessions.flatMap(\.clips) + (archive.active?.clips ?? [])).filter { $0.created < cutoff }
        guard !expired.isEmpty else { return }
        let ids = Set(expired.map(\.id))
        do {
            for clip in expired {
                if let url = DiskLocation.child(clip.filename, of: DiskLocation.clips), FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
            _ = await commit { value in
                for i in value.sessions.indices { value.sessions[i].clips.removeAll { ids.contains($0.id) } }
                value.active?.clips.removeAll { ids.contains($0.id) }
            }.value
        } catch { self.error = error.localizedDescription }
    }
}
