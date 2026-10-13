import SwiftUI
import UIKit
import AVFoundation

@MainActor
final class SleepStore: ObservableObject {
    @Published var archive = AppArchive()
    @Published var recordingUsage: RecordingUsage?
    @Published var deletingRecordings = false
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
    @Published var developerMode = UserDefaults.standard.bool(forKey: "journalDeveloperMode") {
        didSet { if !journalPreview { UserDefaults.standard.set(developerMode, forKey: "journalDeveloperMode") } }
    }
    let audio = NightAudio()
    let repository: ArchiveRepository
    // Design examples use a separate store. They never load, persist or touch audio files.
    let journalPreview: Bool
    let scheduler: any WakeScheduling
    var editingActiveAlarm = false
    var writeTail: Task<Bool, Never>?
    var smartScheduling = false
    private var timer: Timer?
    private var lastCheckpoint = Date.distantPast
    var audioInterrupted = false
    private var writesPending = 0
    var captureBusy = false
    var resumeAfterInterruption = false
    var clipFilesBusy = false
    var words: Words { Words(language: archive.preferences.language) }
    var testMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--ui-test")
        #else
        return false
        #endif
    }
    init(repository: ArchiveRepository? = nil, journalPreview: Bool = false, scheduler: (any WakeScheduling)? = nil) {
        self.scheduler = scheduler ?? WakeScheduler()
        self.journalPreview = journalPreview
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
        guard !journalPreview else { loaded = true; return }
        do {
            archive = try await repository.load()
            do { archive = try await repository.prune() } catch {
                archive = try await repository.load()
                self.error = error.localizedDescription
            }
            #if DEBUG
            if testMode && archive.revision == 0 {
                archive.preferences.language = ProcessInfo.processInfo.arguments.contains("--spanish") ? "es" : "en"
                archive.preferences.appearance = ProcessInfo.processInfo.arguments.contains("--night-fixture") ? "night" : "dawn"
                if ProcessInfo.processInfo.arguments.contains("--design-fixture") {
                    let end = Calendar.current.date(bySettingHour: 7, minute: 15, second: 0, of: Date())!
                    let begin = end.addingTimeInterval(-8*3600-5*60)
                    archive.sessions = [SleepSession(id: UUID(), start: begin, checkpoint: end, end: end, wake: end, alarmID: UUID(), soundID: "aurora")]
                    archive.pages[CalendarDay.key(Date())] = JournalPage(feeling: .peaceful, text: "Ejemplo de diseño: una mañana tranquila, luz en la ventana y un sueño junto al mar.")
                    if ProcessInfo.processInfo.arguments.contains("--clip-fixture"), let tone = ToneLibrary.url("aurora", imported: []) {
                        try FileManager.default.createDirectory(at: DiskLocation.clips, withIntermediateDirectories: true)
                        let kinds = Array(repeating: SoundKind.cough, count: 16) + Array(repeating: .snore, count: 7) + Array(repeating: .breath, count: 4) + [.voice, .voice, .other]
                        for (i, kind) in kinds.enumerated() {
                            let id = UUID(), filename = id.uuidString + ".wav"
                            try FileManager.default.copyItem(at: tone, to: DiskLocation.clips.appendingPathComponent(filename))
                            var clip = NightClip(id: id, created: begin.addingTimeInterval(Double(i+1)*900), filename: filename, duration: 24)
                            clip.kind = kind; clip.suggestion = true; clip.analysisDone = true; clip.analysisVersion = SoundTagger.version
                            clip.events = [SoundEvent(start: 2, duration: 1.5, kind: clip.kind, confidence: 0.9)]
                            archive.sessions[0].clips.append(clip)
                        }
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("--health-fixture"), let latest = archive.sessions.first {
                    for offset in 1...6 {
                        let end = latest.checkpoint.addingTimeInterval(-Double(offset)*86400+Double(offset%3)*600)
                        let begin = end.addingTimeInterval(-Double([430,390,465,360,440,420][offset-1])*60)
                        archive.sessions.append(SleepSession(id:UUID(),start:begin,checkpoint:end,end:end,wake:end,alarmID:UUID(),soundID:"aurora"))
                        archive.pages[CalendarDay.key(end)] = JournalPage(feeling:MorningFeeling.allCases[offset%5],text:"")
                    }
                }
                let fixture = archive
                _ = try await repository.update { $0 = fixture }
            }
            #endif
            loaded = true
            await recoverClips()
            await prune()
            await recoverTemporaryAnalysis()
            await cleanUpAlarmBackup()
            if archive.active != nil {
                audio.captureState = "recordRecovered"
                commit { value in
                    value.active?.capturePaused = true
                    value.active?.resumeCaptureAfterAlarm = false
                    if let count = value.active?.captureSpans?.count, count > 0,
                       value.active?.captureSpans?[count-1].reason == "recordListening" { value.active?.captureSpans?[count-1].reason = "recordRecovered" }
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
        if journalPreview { change(&archive); return Task { true } }
        guard !failed else { return Task { false } }
        change(&archive); writesPending += 1; saving = true
        let snapshot = archive
        let waitForAlarmEdit = editingActiveAlarm
        let preceding = writeTail
        let task = Task { [weak self] in
            if let preceding { _ = await preceding.value }
            guard let self else { return false }
            // Input keeps updating the archive during alarm changes. Defer its
            // persistence until the schedule transaction resolves, then save
            // the latest archive so stale snapshots cannot undo the new time.
            if waitForAlarmEdit {
                while self.editingActiveAlarm { try? await Task.sleep(nanoseconds: 10_000_000) }
            }
            let toSave = waitForAlarmEdit ? self.archive : snapshot
            do {
                _ = try await repository.update { value in let revision = value.revision; value = toSave; value.revision = revision }
                self.writesPending -= 1; self.saving = self.writesPending > 0
                if self.writesPending == 0 { self.writeFailed = false }
                return true
            } catch {
                self.error = error.localizedDescription; self.writeFailed = true
                self.writesPending -= 1; self.saving = self.writesPending > 0
                self.archive.active?.capturePaused = true
                self.archive.active?.resumeCaptureAfterAlarm = false
                self.resumeAfterInterruption = false
                let end = await self.audio.stopRecording(reason: "recordError")
                if let count = self.archive.active?.captureSpans?.count, count > 0,
                   self.archive.active?.captureSpans?[count-1].reason == "recordListening" {
                    self.archive.active?.captureSpans?[count-1].reason = "recordError"
                    if let end { self.archive.active?.captureSpans?[count-1].end = end }
                }
                return false
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
        guard !journalPreview else { return }
        guard !busy, !deletingRecordings, archive.active == nil, !failed else { return }; busy = true; defer { busy = false }
        do {
            if archive.preferences.analysisEnabled && !testMode {
                guard await audio.microphoneAllowed() else { error = words("micError"); return }
            }
            guard let wake = archive.plan.next(after: Date()) else { return }
            let tone = archive.plan.sound(excluding: archive.lastSound)
            let previousSound = archive.lastSound
            var night = SleepSession(id: UUID(), start: Date(), checkpoint: Date(), wake: wake, alarmID: UUID(), soundID: tone)
            night.mode = archive.plan.resolvedMode; night.retainAudio = archive.preferences.record
            if night.mode == .analysis { night.wake = .distantFuture }
            if night.mode == .smart { night.latestWake = wake; night.windowStart = wake.addingTimeInterval(-Double(archive.plan.window)*60) }
            let started = night
            if !testMode && night.hasAlarm { try await scheduler.schedule(id: night.alarmID, date: wake, filename: try await ToneLibrary.alarmFilename(tone, imported: archive.tones, gradual: archive.plan.gradual), words: words) }
            guard await commit({ $0.active = started; $0.lastSound = tone }).value else {
                try? scheduler.cancel(id: night.alarmID)
                archive.active = nil; archive.lastSound = previousSound
                return
            }
            #if DEBUG
            if testMode && ProcessInfo.processInfo.arguments.contains("--night-wave-fixture") {
                audio.captureState = "recordListening"
                audio.waveform = (0..<64).map { 0.65 + 0.12 * sin(Double($0)*0.2) }
            }
            #endif
            do { try await beginRecordingIfNeeded() } catch {
                // Preserve the scheduled alarm and any recoverable audio if input fails.
                audio.captureState = "recordError"
                _ = await commit { $0.active?.capturePaused = true }.value
                self.error = captureFailureMessage(error)
            }
            tab = 0
        } catch WakeFailure.permission { error = words("permissionError") }
        catch { self.error = error.localizedDescription }
    }
    func resume() async {
        guard loaded, !failed, !audioInterrupted else { return }
        if let dismissal = WakeDismissal.pending() {
            if dismissal.alarmID == archive.active?.alarmID.uuidString || dismissal.alarmID == archive.active?.backupAlarmID?.uuidString {
                if await finish(at: dismissal.date) {
                    do { try WakeDismissal.acknowledge(dismissal) } catch { self.error = error.localizedDescription }
                }
                return
            }
            if !writeFailed, !saving, archive.sessions.contains(where: { $0.alarmID.uuidString == dismissal.alarmID }) {
                do { try WakeDismissal.acknowledge(dismissal) } catch { self.error = error.localizedDescription }
            }
        }
        guard archive.active != nil else { return }
        if !busy { await cleanUpAlarmBackup() }
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
        guard night.hasAlarm, UIApplication.shared.applicationState == .active else { return }
        audio.updateLight(wake: night.wake, minutes: archive.plan.lightMinutes)
        if Date() >= night.wake && !ringing && !audioInterrupted {
            ringing = true
            Task { await self.ring(night) }
        }
    }
    private func ring(_ night: SleepSession) async {
            await pauseCapture(reason: "recordAlarm")
            guard archive.active?.id == night.id, archive.active?.alarmID == night.alarmID,
                  ringing, !busy, !audioInterrupted else { return }
            if !testMode { try? scheduler.cancel(id: night.alarmID) }
            do {
                guard let url = ToneLibrary.url(night.soundID, imported: archive.tones) ?? ToneLibrary.url("aurora", imported: []) else { throw CocoaError(.fileNoSuchFile) }
                try audio.play(url: url, id: "wake", loop: true, gradual: archive.plan.gradual)
                if archive.plan.motionSnooze { audio.watchMovement { [weak self] in Task { await self?.snooze() } } }
            } catch { self.error = error.localizedDescription }
    }
    func snooze() async {
        guard !busy, archive.active?.hasAlarm == true else { return }; busy = true; defer { busy = false }
        // The alarm's stop may still be flushing. Snapshot only after its final clips and pause decision.
        await pauseCapture(reason: "recordAlarm")
        guard var night = archive.active else { return }
        let original = night
        let old = night.alarmID; night = night.snoozed(until: Date().addingTimeInterval(Double(archive.plan.snoozeMinutes * 60)))
        do {
            if !testMode { try await scheduler.schedule(id: night.alarmID, date: night.wake, filename: try await ToneLibrary.alarmFilename(night.soundID, imported: archive.tones, gradual: archive.plan.gradual), words: words) }
            let updated = night
            guard await commit({ $0.active = updated }).value else {
                try? scheduler.cancel(id: night.alarmID)
                archive.active = original; archive.active?.resumeCaptureAfterAlarm = false
                return
            }
            if !testMode { try? scheduler.cancel(id: old); if let backup = original.backupAlarmID { try? scheduler.cancel(id: backup) } }
            audio.stopPlayback(); audio.restoreScreen(); ringing = false
            try await beginRecordingIfNeeded()
        } catch { self.error = error.localizedDescription }
    }
    @discardableResult
    func finish(at end: Date = Date()) async -> Bool {
        guard !busy, archive.active != nil else { return false }; busy = true; defer { busy = false }
            if let night = archive.active, night.hasAlarm, !testMode {
                for id in [night.alarmID, night.backupAlarmID].compactMap({ $0 }) { do { try scheduler.cancel(id: id) } catch { self.error = error.localizedDescription } }
            }
            await pauseCapture(reason: "recordOff")
            await audio.stopAll(); ringing = false
            // stopAll flushes the last clip before we snapshot the session.
            guard var night = archive.active else { return false }
            night.end = max(night.start, end); night.checkpoint = max(night.start, end); let finished = night
            guard await commit({ $0.sessions.insert(finished, at: 0); $0.active = nil }).value else { return false }
            selectedDay = night.end ?? Date()
            if archive.preferences.openJournal { tab = 1 }
            return true
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
                    let summary = NightSoundSummary(clip:archive.sessions[i].clips[j])
                    archive.sessions[i].soundSummaries?.removeAll { $0.id == clip.id }
                    if archive.sessions[i].soundSummaries == nil { archive.sessions[i].soundSummaries = [] }
                    archive.sessions[i].soundSummaries?.append(summary)
                }
            }
        }
    }
    func analyzeClips(for day: Date) async {
        guard !journalPreview else { return }
        let pending = sessions(day).flatMap(\.clips).filter {
            $0.analysisFailed != true && (!$0.analysisDone || ($0.suggestion && $0.analysisVersion != SoundTagger.version))
        }
        for clip in pending {
            guard !Task.isCancelled else { return }
            await analyze(clip)
        }
    }
    func analyze(_ clip: NightClip) async {
        guard !journalPreview else { return }
        guard !analyzing.contains(clip.id), let url = DiskLocation.child(clip.filename, of: DiskLocation.clips) else { return }
        analyzing.insert(clip.id); defer { analyzing.remove(clip.id) }
        let result = await SoundTagger.suggest(url: url)
        guard !Task.isCancelled else { return }
        let saved = await commit { value in
            func update(_ night: inout SleepSession) {
                guard let j = night.clips.firstIndex(where: { $0.id == clip.id }), night.clips[j] == clip else { return }
                night.clips[j].analysisFailed = !result.completed
                night.clips[j].analysisDone = result.completed
                night.clips[j].kind = result.kind
                night.clips[j].suggestion = true
                night.clips[j].events = result.events
                night.clips[j].analysisVersion = SoundTagger.version
                var summaries = night.soundSummaries ?? []
                summaries.removeAll { $0.id == clip.id }; summaries.append(NightSoundSummary(clip:night.clips[j]))
                night.soundSummaries = summaries
            }
            if value.active != nil { update(&value.active!) }
            for i in value.sessions.indices { update(&value.sessions[i]) }
        }.value
        if saved { await discardTemporaryClip(clip) }
    }
    func discardTemporaryClip(_ clip: NightClip) async {
        let all = archive.sessions + (archive.active.map { [$0] } ?? [])
        guard all.contains(where: { $0.retainAudio == false && $0.clips.contains(where: { $0.id == clip.id }) }),
              await commit({ $0.queueClipDeletion([clip.filename]) }).value else { return }
        await completePendingClipDeletions()
    }
    func recoverTemporaryAnalysis() async {
        let nights = archive.sessions + (archive.active.map { [$0] } ?? [])
        for night in nights where night.retainAudio == false {
            for clip in night.clips {
                if !clip.analysisDone && clip.analysisFailed != true { await analyze(clip) }
                else { await discardTemporaryClip(clip) }
            }
        }
    }

    @discardableResult
    func delete(_ clip: NightClip) async -> Bool {
        if journalPreview {
            for index in archive.sessions.indices { archive.sessions[index].clips.removeAll { $0.id == clip.id } }
            return true
        }
        audio.stopPlayback()
        guard archive.sessions.contains(where: { $0.clips.contains(where: { $0.id == clip.id }) }) else { return false }
        guard await commit({ $0.queueClipDeletion([clip.filename]) }).value else { return false }
        await completePendingClipDeletions()
        return !archive.sessions.contains(where: { $0.clips.contains(where: { $0.id == clip.id }) }) && !writeFailed
    }
    func retrySaving() async {
        guard await commit({ _ in }).value else { return }
        await completePendingClipDeletions()
    }
    func completePendingClipDeletions() async {
        guard await acquireClipFiles() else { return }; defer { clipFilesBusy = false }
        guard let pending = archive.pendingClipDeletions, !pending.isEmpty else { return }
        // A failed optimistic edit may still be in memory. Persist this exact queue first.
        guard await commit({ _ in }).value else { return }
        let result = await Task.detached { ClipDeletionQueue.remove(pending, directory: DiskLocation.clips) }.value
        if !result.completed.isEmpty { _ = await commit { $0.completeClipDeletion(result.completed) }.value }
        if let error = result.error { self.error = error.localizedDescription }
    }
    func flush() async {
        guard !journalPreview else { return }
        let token = UIApplication.shared.beginBackgroundTask(withName: "Save journal")
        if let writeTail { _ = await writeTail.value }
        if token != .invalid { UIApplication.shared.endBackgroundTask(token) }
    }
    func prune() async {
        guard !journalPreview else { return }
        if archive.preferences.keepDays > 0 {
            let cutoff = Date().addingTimeInterval(-Double(archive.preferences.keepDays)*86400)
            let expired = (archive.sessions.flatMap(\.clips) + (archive.active?.clips ?? [])).filter { $0.created < cutoff }
            if !expired.isEmpty {
                guard await commit({ $0.queueClipDeletion(expired.map(\.filename)) }).value else { return }
            }
        }
        await completePendingClipDeletions()
    }
}
