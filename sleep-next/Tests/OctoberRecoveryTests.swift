import XCTest
@testable import AlarmaNext

final class OctoberRecoveryTests: XCTestCase {
    private func night(clip: NightClip? = nil) -> SleepSession {
        let now = Date()
        return SleepSession(id: UUID(), start: now, checkpoint: now, end: now, wake: now, alarmID: UUID(), soundID: "aurora", clips: clip.map { [$0] } ?? [])
    }
    func testSnoozeResumesCaptureStoppedForAlarm() {
        var session = night(); session.capturePaused = true; session.resumeCaptureAfterAlarm = true
        let wake = Date().addingTimeInterval(300), next = session.snoozed(until: wake)
        XCTAssertEqual(next.id, session.id); XCTAssertNotEqual(next.alarmID, session.alarmID)
        XCTAssertEqual(next.wake, wake); XCTAssertEqual(next.soundID, session.soundID)
        XCTAssertEqual(next.capturePaused, false); XCTAssertNil(next.resumeCaptureAfterAlarm)
    }
    func testSnoozePreservesVoluntaryMicrophonePause() {
        var session = night(); session.capturePaused = true; session.resumeCaptureAfterAlarm = false
        XCTAssertEqual(session.snoozed(until: Date()).capturePaused, true)
    }
    func testSnoozeDoesNotGuessCaptureConsentForLegacyNight() {
        var session = night(); session.capturePaused = true
        XCTAssertEqual(session.snoozed(until: Date()).capturePaused, true)
    }
    func testArchiveWithoutNewOptionalFieldsStillDecodes() throws {
        var archive = AppArchive(); archive.active = night(); archive.pages["day"] = JournalPage(text: "Mi sueño 🌙")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as? [String: Any])
        json.removeValue(forKey: "pendingClipDeletions")
        var active = try XCTUnwrap(json["active"] as? [String: Any]); active.removeValue(forKey: "resumeCaptureAfterAlarm"); json["active"] = active
        let restored = try JSONDecoder().decode(AppArchive.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.pages["day"]?.text, "Mi sueño 🌙")
        XCTAssertEqual(restored.active?.id, archive.active?.id); XCTAssertNil(restored.pendingClipDeletions)
    }
    func testRetentionWriteFailurePreservesAudioAndJournal() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let clips = root.appendingPathComponent("clips"), file = root.appendingPathComponent("archive.json")
        try FileManager.default.createDirectory(at: clips, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let clip = NightClip(id: UUID(), created: Date().addingTimeInterval(-40*86400), filename: "old.wav", duration: 1)
        let audio = clips.appendingPathComponent(clip.filename), original = Data([1,2,3,4])
        try original.write(to: audio)
        let repo = ArchiveRepository(file: file, clipsDirectory: clips), session = night(clip: clip)
        _ = try await repo.update { $0.sessions = [session]; $0.pages["day"] = JournalPage(text: "Keep me") }
        try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        do { _ = try await repo.prune(); XCTFail("The archive write must fail") } catch { }
        XCTAssertEqual(try Data(contentsOf: audio), original)
        let saved = try await repo.load()
        XCTAssertEqual(saved.sessions[0].clips, [clip]); XCTAssertEqual(saved.pages["day"]?.text, "Keep me")
    }
    func testRelaunchCompletesDeletionAndRemovesRecoveryReceipt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let clips = root.appendingPathComponent("clips"), file = root.appendingPathComponent("archive.json")
        defer { try? FileManager.default.removeItem(at: root) }
        let spool = try ClipSpool(directory: clips), id = UUID(), now = Date()
        try spool.begin(nightID: id, created: now, sampleRate: 8000); try spool.append(Array(repeating: 0.1, count: 800))
        let receipt = try XCTUnwrap(spool.close()), session = night(clip: receipt.clip)
        let repo = ArchiveRepository(file: file, clipsDirectory: clips)
        _ = try await repo.update {
            $0.preferences.keepDays = 0; $0.sessions = [session]; $0.pages["day"] = JournalPage(text: "Keep me")
            $0.queueClipDeletion([receipt.clip.filename])
        }
        // Simulate a crash after removing audio and before finalising the archive.
        try FileManager.default.removeItem(at: clips.appendingPathComponent(receipt.clip.filename))
        let restored = try await ArchiveRepository(file: file, clipsDirectory: clips).prune()
        XCTAssertTrue(restored.sessions[0].clips.isEmpty); XCTAssertNil(restored.pendingClipDeletions)
        XCTAssertEqual(restored.pages["day"]?.text, "Keep me")
        XCTAssertTrue(try ClipSpool(directory: clips).recover().isEmpty)
    }
    func testInvalidDeletionCannotReachOutsideClipDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let clips = root.appendingPathComponent("clips"), outside = root.appendingPathComponent("private.wav")
        try FileManager.default.createDirectory(at: clips, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Data([4,3,2,1]); try original.write(to: outside)
        let result = ClipDeletionQueue.remove(["../private.wav"], directory: clips)
        XCTAssertNotNil(result.error); XCTAssertTrue(result.completed.isEmpty)
        XCTAssertEqual(try Data(contentsOf: outside), original)
    }
    func testMissingPCMIsReportedWithoutDiscardingRecoveryManifest() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let spool = try ClipSpool(directory: root), value = OpenClip(nightID: UUID(), id: UUID(), created: Date(), sampleRate: 8000)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent(value.id.uuidString + ".open.json")
        try JSONEncoder().encode(value).write(to: file)
        XCTAssertTrue(try spool.recover().isEmpty); XCTAssertEqual(spool.recoveryFailures, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }
    func testAlarmDismissalReadDoesNotConsumeItBeforeNightIsSaved() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: file) }
        let dismissal = WakeDismissal(alarmID: UUID().uuidString, date: Date())
        try JSONEncoder().encode(dismissal).write(to: file)
        XCTAssertEqual(WakeDismissal.pending(at: file), dismissal)
        XCTAssertEqual(WakeDismissal.pending(at: file), dismissal)
        try WakeDismissal.acknowledge(WakeDismissal(alarmID: UUID().uuidString, date: Date()), at: file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        try WakeDismissal.acknowledge(dismissal, at: file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
}

@MainActor
final class OctoberStoreRecoveryTests: XCTestCase {
    private func fixture(finished: Bool = false) async throws -> (SleepStore, ClipReceipt, URL) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("archive.json")
        let repo = ArchiveRepository(file: file), now = Date()
        let night = SleepSession(id: UUID(), start: now, checkpoint: now, end: finished ? now : nil, wake: now.addingTimeInterval(3600), alarmID: UUID(), soundID: "aurora")
        let archive = try await repo.update { if finished { $0.sessions = [night] } else { $0.active = night } }
        let store = SleepStore(repository: repo); store.archive = archive; store.loaded = true
        let spool = try ClipSpool(directory: DiskLocation.clips)
        try spool.begin(nightID: night.id, created: now, sampleRate: 8000); try spool.append(Array(repeating: 0.1, count: 800))
        let receipt = try XCTUnwrap(spool.close())
        return (store, receipt, DiskLocation.clips.appendingPathComponent(receipt.clip.filename))
    }
    func testFailedDeleteCanRetryAndCannotReindexPendingReceipt() async throws {
        let (store, receipt, audio) = try await fixture(finished: true)
        defer { try? FileManager.default.removeItem(at: audio); try? ClipSpool.acknowledge(receipt, directory: DiskLocation.clips) }
        store.index(receipt); if let tail = store.writeTail { _ = await tail.value }
        // Use a dedicated repository whose next atomic write cannot replace a directory.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = root.appendingPathComponent("archive.json"), repo = ArchiveRepository(file: file)
        defer { try? FileManager.default.removeItem(at: root) }
        let snapshot = store.archive
        _ = try await repo.update { $0 = snapshot }
        let failing = SleepStore(repository: repo); failing.archive = snapshot; failing.loaded = true
        try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        let deleted = await failing.delete(receipt.clip)
        XCTAssertFalse(deleted); XCTAssertTrue(failing.writeFailed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: audio.path))
        failing.index(receipt); XCTAssertEqual(failing.archive.sessions[0].clips.count, 1)
        try FileManager.default.removeItem(at: file)
        await failing.retrySaving()
        XCTAssertFalse(failing.writeFailed); XCTAssertTrue(failing.archive.sessions[0].clips.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audio.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: DiskLocation.clips.appendingPathComponent(receipt.clip.id.uuidString + ".receipt.json").path))
    }
    func testInterruptionEndWaitsForCaptureStop() async throws {
        let repo = ArchiveRepository(file: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("archive.json"))
        let store = SleepStore(repository: repo); store.captureBusy = true; store.audioInterrupted = true
        let ended = Task { await store.interruption(began: false) }
        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertTrue(store.audioInterrupted)
        store.captureBusy = false; await ended.value
        XCTAssertFalse(store.audioInterrupted)
    }
    func testDeletionWaitsForAnInFlightRecovery() async throws {
        let (store, receipt, audio) = try await fixture(finished: true)
        defer { try? FileManager.default.removeItem(at: audio); try? ClipSpool.acknowledge(receipt, directory: DiskLocation.clips) }
        store.index(receipt); if let tail = store.writeTail { _ = await tail.value }
        store.clipFilesBusy = true
        let deleting = Task { await store.delete(receipt.clip) }
        try await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertTrue(FileManager.default.fileExists(atPath: audio.path))
        XCTAssertEqual(store.archive.sessions[0].clips.count, 1)
        store.clipFilesBusy = false
        let deleted = await deleting.value
        XCTAssertTrue(deleted); XCTAssertFalse(FileManager.default.fileExists(atPath: audio.path))
    }
    func testDuplicateInterruptionDoesNotLoseOriginalResumeDecision() async throws {
        let (store, receipt, audio) = try await fixture()
        defer { try? FileManager.default.removeItem(at: audio); try? ClipSpool.acknowledge(receipt, directory: DiskLocation.clips) }
        store.audioInterrupted = true; store.resumeAfterInterruption = true
        await store.interruption(began: true)
        XCTAssertTrue(store.resumeAfterInterruption)
        await store.interruption(began: false, shouldResume: false)
        XCTAssertFalse(store.resumeAfterInterruption); XCTAssertFalse(store.audio.hasCapture)
    }
    func testVoluntaryPauseAfterAlarmOverridesAutomaticSnoozeResume() async throws {
        let (store, receipt, audio) = try await fixture()
        defer { try? FileManager.default.removeItem(at: audio); try? ClipSpool.acknowledge(receipt, directory: DiskLocation.clips) }
        _ = await store.commit { $0.active?.resumeCaptureAfterAlarm = true; $0.active?.capturePaused = true }.value
        await store.pauseCapture(reason: "recordPaused")
        let next = try XCTUnwrap(store.archive.active).snoozed(until: Date().addingTimeInterval(300))
        XCTAssertEqual(next.capturePaused, true)
    }
    func testAlarmStopRemembersCaptureConsentBeforePausing() async throws {
        let (store, receipt, audio) = try await fixture()
        defer { try? FileManager.default.removeItem(at: audio); try? ClipSpool.acknowledge(receipt, directory: DiskLocation.clips) }
        _ = await store.commit { $0.preferences.record = true; $0.active?.capturePaused = false }.value
        await store.pauseCapture(reason: "recordAlarm")
        XCTAssertEqual(store.archive.active?.resumeCaptureAfterAlarm, true)
        XCTAssertEqual(store.archive.active?.capturePaused, true)
        XCTAssertEqual(store.archive.active?.snoozed(until: Date()).capturePaused, false)
    }
}
