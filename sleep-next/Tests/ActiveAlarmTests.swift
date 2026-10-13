import XCTest
@testable import AlarmaNext

@MainActor
private final class FakeWakeScheduler: WakeScheduling {
    var scheduled: [(UUID, Date)] = []
    var cancelled: [UUID] = []
    var onSchedule: ((UUID) async throws -> Void)?
    func schedule(id: UUID, date: Date, filename: String, words: Words) async throws {
        scheduled.append((id,date)); try await onSchedule?(id)
    }
    func cancel(id: UUID) throws { cancelled.append(id) }
}

@MainActor
final class ActiveAlarmTests: XCTestCase {
    private func fixture(mode: AlarmMode = .exact) async throws -> (SleepStore, FakeWakeScheduler, URL, Date) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("archive.json")
        let repo = ArchiveRepository(file:file), scheduler = FakeWakeScheduler(), now = Date()
        var night = SleepSession(id:UUID(),start:now.addingTimeInterval(-3600),checkpoint:now,wake:now.addingTimeInterval(3600),alarmID:UUID(),soundID:"aurora")
        night.mode = mode; night.capturePaused = false
        night.clips = [NightClip(id:UUID(),created:now,filename:"keep.wav",duration:4)]
        night.captureSpans = [CaptureSpan(id:UUID(),start:night.start,end:now,reason:"recordListening")]
        if mode == .smart { night.latestWake = night.wake; night.windowStart = night.wake.addingTimeInterval(-1800) }
        let initial = night
        let archive = try await repo.update { $0.active = initial }
        let store = SleepStore(repository:repo,scheduler:scheduler); store.archive = archive; store.loaded = true
        return (store,scheduler,file,now)
    }
    func testSmartChangeKeepsSessionAndConcurrentCaptureCommits() async throws {
        let (store,scheduler,file,now) = try await fixture(mode:.smart)
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let old = try XCTUnwrap(store.archive.active), plan = store.archive.plan
        let epoch = AcousticEpoch(id:UUID(),start:now,duration:30,activeSeconds:2,meanDBFS:-50)
        scheduler.onSchedule = { id in
            let disk = try await store.repository.load()
            XCTAssertEqual(disk.active?.backupAlarmID,id)
            XCTAssertEqual(disk.active?.alarmID,old.alarmID)
            XCTAssertFalse(scheduler.cancelled.contains(old.alarmID))
            store.observe(epoch,nightID:old.id)
        }
        let result = await store.changeActiveAlarm(hour:8,minute:45,now:now)
        XCTAssertTrue(result)
        if let tail = store.writeTail { _ = await tail.value }
        let new = try XCTUnwrap(store.archive.active)
        XCTAssertEqual(new.id,old.id); XCTAssertEqual(new.start,old.start)
        XCTAssertEqual(new.clips,old.clips); XCTAssertEqual(new.captureSpans,old.captureSpans)
        XCTAssertEqual(new.capturePaused,false); XCTAssertEqual(new.acousticEpochs,[epoch])
        XCTAssertEqual(new.latestWake,new.wake)
        XCTAssertEqual(new.wake.timeIntervalSince(try XCTUnwrap(new.windowStart)),1800,accuracy:0.01)
        XCTAssertEqual(Calendar.current.component(.minute,from:new.wake),45)
        XCTAssertGreaterThan(new.wake,now); XCTAssertNotEqual(new.alarmID,old.alarmID)
        XCTAssertEqual(store.archive.plan,plan); XCTAssertNil(new.backupAlarmID)
        XCTAssertTrue(scheduler.cancelled.contains(old.alarmID)); XCTAssertFalse(store.ringing)
        let fresh = try await ArchiveRepository(file:file).load()
        XCTAssertEqual(fresh.active,new)
    }
    func testEditingSnoozedSmartAlarmUsesVisibleTimeAndKeepsExactSnooze() async throws {
        let (store,_,file,now) = try await fixture(mode:.smart)
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let original = try XCTUnwrap(store.archive.active)
        XCTAssertEqual(original.editableAlarmTime,original.latestWake)
        var snoozed = original.snoozed(until:now.addingTimeInterval(1800))
        snoozed.smartTriggered = true
        XCTAssertEqual(snoozed.editableAlarmTime,snoozed.wake)
        XCTAssertNotEqual(snoozed.editableAlarmTime,snoozed.latestWake)
        XCTAssertFalse(snoozed.hasActiveSmartWindow)
        let snapshot = snoozed
        _ = await store.commit { $0.active = snapshot }.value
        let result = await store.changeActiveAlarm(hour:8,minute:45,now:now)
        XCTAssertTrue(result)
        if let tail = store.writeTail { _ = await tail.value }
        let updated = try XCTUnwrap(store.archive.active)
        XCTAssertEqual(updated.id,original.id)
        XCTAssertNil(updated.windowStart); XCTAssertNil(updated.latestWake)
        XCTAssertEqual(updated.editableAlarmTime,updated.wake)
        XCTAssertEqual(Calendar.current.component(.minute,from:updated.wake),45)
        XCTAssertEqual(updated.clips,original.clips)
    }
    func testScheduleFailureKeepsPreviousAlarmAndCapture() async throws {
        let (store,scheduler,file,now) = try await fixture()
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let old = store.archive.active
        scheduler.onSchedule = { _ in throw WakeFailure.permission }
        let result = await store.changeActiveAlarm(hour:8,minute:45,now:now)
        XCTAssertFalse(result)
        if let tail = store.writeTail { _ = await tail.value }
        XCTAssertEqual(store.archive.active,old)
        XCTAssertFalse(scheduler.cancelled.contains(old!.alarmID))
        XCTAssertTrue(scheduler.cancelled.contains(scheduler.scheduled[0].0))
        let disk = try await ArchiveRepository(file:file).load(); XCTAssertEqual(disk.active,old)
    }
    func testFailedFinalWriteCancelsReplacementAndKeepsOriginalTiming() async throws {
        let (store,scheduler,file,now) = try await fixture()
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let old = try XCTUnwrap(store.archive.active)
        scheduler.onSchedule = { _ in
            try FileManager.default.removeItem(at:file)
            try FileManager.default.createDirectory(at:file,withIntermediateDirectories:false)
        }
        let result = await store.changeActiveAlarm(hour:8,minute:45,now:now)
        XCTAssertFalse(result)
        if let tail = store.writeTail { _ = await tail.value }
        XCTAssertEqual(store.archive.active?.alarmID,old.alarmID)
        XCTAssertEqual(store.archive.active?.wake,old.wake)
        XCTAssertFalse(scheduler.cancelled.contains(old.alarmID))
        XCTAssertTrue(scheduler.cancelled.contains(scheduler.scheduled[0].0))
        try FileManager.default.removeItem(at:file)
        await store.retrySaving()
        let disk = try await ArchiveRepository(file:file).load()
        XCTAssertEqual(disk.active?.alarmID,old.alarmID); XCTAssertEqual(disk.active?.wake,old.wake)
        XCTAssertNil(disk.active?.backupAlarmID)
    }
    func testNoAlarmModeCannotAccidentallyCreateAlarmAndBackupRecoveryIsTracked() async throws {
        let (store,scheduler,file,now) = try await fixture(mode:.analysis)
        defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let result = await store.changeActiveAlarm(hour:8,minute:45,now:now)
        XCTAssertFalse(result); XCTAssertTrue(scheduler.scheduled.isEmpty)
        let backup = UUID(); _ = await store.commit { $0.active?.backupAlarmID = backup }.value
        await store.cleanUpAlarmBackup()
        XCTAssertEqual(scheduler.cancelled,[backup]); XCTAssertNil(store.archive.active?.backupAlarmID)
    }
}

final class CaptureRetimeTests: XCTestCase {
    func testDeadlineCanMoveLaterAndEarlierWithoutResettingFrames() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let start = Date(timeIntervalSince1970:1_800_000_000)
        let worker = try CaptureWorker(nightID:UUID(),start:start,deadline:start.addingTimeInterval(1),rate:8000,margin:10,directory:directory,receipt:{ _ in },progress:{ _,_,_ in },failure:{ _ in XCTFail("Unexpected capture failure") },deadlineReached:{})
        await worker.feedControlled(Array(repeating:Float(0),count:4000))
        await worker.updateDeadline(start.addingTimeInterval(3))
        await worker.feedControlled(Array(repeating:Float(0),count:12000))
        await worker.updateDeadline(start.addingTimeInterval(2.5))
        await worker.feedControlled(Array(repeating:Float(0),count:8000))
        let end = await worker.stop()
        XCTAssertEqual(try XCTUnwrap(end).timeIntervalSince(start),2.5,accuracy:0.001)
    }
}
