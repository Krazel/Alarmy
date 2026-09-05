import SwiftUI
import UIKit

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
    @Published var selectedDay = Date()
    let audio = NightAudio()
    let repository: ArchiveRepository
    private let scheduler = WakeScheduler()
    private var writeTail: Task<Bool, Never>?
    private var timer: Timer?
    private var lastCheckpoint = Date.distantPast
    var words: Words { Words(language: archive.preferences.language) }
    var testMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--ui-test")
        #else
        return false
        #endif
    }
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-test") {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("UI-" + UUID().uuidString)
            repository = ArchiveRepository(file: root.appendingPathComponent("archive.json"))
        } else { repository = ArchiveRepository() }
        #else
        repository = ArchiveRepository()
        #endif
    }
    func load() async {
        guard !loaded else { return }
        do {
            archive = try await repository.prune()
            #if DEBUG
            if testMode {
                archive.preferences.language = ProcessInfo.processInfo.arguments.contains("--spanish") ? "es" : "en"
                archive.preferences.appearance = "dawn"
                if ProcessInfo.processInfo.arguments.contains("--design-fixture") {
                    let end = Calendar.current.date(bySettingHour: 7, minute: 15, second: 0, of: Date())!
                    let begin = end.addingTimeInterval(-8*3600-5*60)
                    archive.sessions = [SleepSession(id: UUID(), start: begin, checkpoint: end, end: end, wake: end, alarmID: UUID(), soundID: "aurora")]
                    archive.pages[CalendarDay.key(Date())] = JournalPage(feeling: .peaceful, text: "Ejemplo de diseño: una mañana tranquila, luz en la ventana y un sueño junto al mar.")
                }
                let fixture = archive
                _ = try await repository.update { $0 = fixture }
            }
            #endif
            loaded = true
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
            await resume()
        } catch { failed = true; loaded = true; self.error = words("storageError") }
    }
    @discardableResult
    func commit(_ change: @escaping @Sendable (inout AppArchive) -> Void) -> Task<Bool, Never> {
        guard !failed else { return Task { false } }
        change(&archive); saving = true
        let preceding = writeTail
        let task = Task { [weak self] in
            if let preceding, !(await preceding.value) { return false }
            guard let self else { return false }
            do {
                _ = try await repository.update(change)
                self.saving = false
                return true
            } catch { self.error = error.localizedDescription; self.failed = true; self.saving = false; return false }
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
            let night = SleepSession(id: UUID(), start: Date(), checkpoint: Date(), wake: wake, alarmID: UUID(), soundID: tone)
            if !testMode { try await scheduler.schedule(id: night.alarmID, date: wake, filename: ToneLibrary.filename(tone, imported: archive.tones), words: words) }
            guard await commit({ $0.active = night; $0.lastSound = tone }).value else { try? scheduler.cancel(id: night.alarmID); return }
            do { try beginRecordingIfNeeded() } catch {
                try? scheduler.cancel(id: night.alarmID)
                _ = await commit { $0.active = nil }.value
                throw error
            }
            tab = 0
        } catch WakeFailure.permission { error = words("permissionError") }
        catch { self.error = error.localizedDescription }
    }
    private func beginRecordingIfNeeded() throws {
        guard archive.preferences.record, !audio.isRecording, !ringing, !testMode else { return }
        try audio.startRecording { [weak self] clip in self?.commit { $0.active?.clips.append(clip) } }
    }
    func resume() async {
        guard archive.active != nil, !failed else { return }
        if let dismissal = WakeDismissal.take(), dismissal.alarmID == archive.active?.alarmID.uuidString {
            await finish(at: dismissal.date); return
        }
        do { try beginRecordingIfNeeded() } catch { self.error = error.localizedDescription }
        tick()
    }
    func tick() {
        guard let night = archive.active, !busy, !failed else { return }
        if Date().timeIntervalSince(lastCheckpoint) >= 30 {
            lastCheckpoint = Date(); let now = Date(); commit { $0.active?.checkpoint = now }
        }
        guard UIApplication.shared.applicationState == .active else { return }
        audio.updateLight(wake: night.wake, minutes: archive.plan.lightMinutes)
        if Date() >= night.wake && !ringing {
            ringing = true; audio.stopRecording()
            if !testMode { try? scheduler.cancel(id: night.alarmID) }
            do {
                guard let url = ToneLibrary.url(night.soundID, imported: archive.tones) else { throw CocoaError(.fileNoSuchFile) }
                try audio.play(url: url, id: "wake", loop: true, gradual: archive.plan.gradual)
                if archive.plan.motionSnooze { audio.watchMovement { [weak self] in Task { await self?.snooze() } } }
            } catch { self.error = error.localizedDescription }
        }
    }
    func snooze() async {
        guard !busy, var night = archive.active else { return }; busy = true; defer { busy = false }
        let old = night.alarmID; night.alarmID = UUID(); night.wake = Date().addingTimeInterval(Double(archive.plan.snoozeMinutes * 60))
        do {
            if !testMode { try await scheduler.schedule(id: night.alarmID, date: night.wake, filename: ToneLibrary.filename(night.soundID, imported: archive.tones), words: words); try? scheduler.cancel(id: old) }
            let updated = night
            guard await commit({ $0.active = updated }).value else { try? scheduler.cancel(id: night.alarmID); return }
            audio.stopPlayback(); audio.restoreScreen(); ringing = false
            try beginRecordingIfNeeded()
        } catch { self.error = error.localizedDescription }
    }
    func finish(at end: Date = Date()) async {
        guard !busy, archive.active != nil else { return }; busy = true; defer { busy = false }
        do {
            if let id = archive.active?.alarmID, !testMode { try scheduler.cancel(id: id) }
            audio.stopAll(); ringing = false
            // stopAll flushes the last clip before we snapshot the session.
            guard var night = archive.active else { return }
            night.end = max(night.start, end); night.checkpoint = max(night.start, end); let finished = night
            guard await commit({ $0.sessions.insert(finished, at: 0); $0.active = nil }).value else { return }
            selectedDay = night.end ?? Date()
            if archive.preferences.openJournal { tab = 1 }
        } catch { self.error = error.localizedDescription }
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
                if let j = archive.sessions[i].clips.firstIndex(where: { $0.id == clip.id }) { archive.sessions[i].clips[j].kind = kind }
            }
        }
    }
    func delete(_ clip: NightClip) async {
        audio.stopPlayback()
        let success = await commit { value in for i in value.sessions.indices { value.sessions[i].clips.removeAll { $0.id == clip.id } } }.value
        if success, let url = DiskLocation.child(clip.filename, of: DiskLocation.clips) {
            do { try FileManager.default.removeItem(at: url) } catch { self.error = error.localizedDescription }
        }
    }
    func prune() async {
        if let writeTail { _ = await writeTail.value }
        do { archive = try await repository.prune() } catch { self.error = error.localizedDescription }
    }
}
