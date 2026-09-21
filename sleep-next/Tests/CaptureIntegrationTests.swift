import XCTest
@testable import AlarmaNext

@MainActor
final class CaptureIntegrationTests: XCTestCase {
    func fixture(finished: Bool = false) async throws -> (SleepStore, SleepSession, ClipReceipt, URL) {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repo=ArchiveRepository(file:root.appendingPathComponent("archive.json"))
        let now=Date(); let night=SleepSession(id:UUID(),start:now,checkpoint:now,end:finished ? now : nil,wake:now.addingTimeInterval(3600),alarmID:UUID(),soundID:"aurora")
        let archive=try await repo.update { if finished { $0.sessions=[night] } else { $0.active=night } }
        let store=SleepStore(repository:repo); store.archive=archive; store.loaded=true
        let spool=try ClipSpool(directory:DiskLocation.clips)
        try spool.begin(nightID:night.id,created:now,sampleRate:8000)
        try spool.append((0..<8000).map { Float(sin(Double($0)*0.2))*0.1 })
        let receipt=try XCTUnwrap(spool.close())
        return (store,night,receipt,DiskLocation.clips.appendingPathComponent(receipt.clip.filename))
    }
    func testReceiptIndexesOnceIntoOwningNightAndCanBeDeleted() async throws {
        let (store,night,receipt,url)=try await fixture()
        store.index(receipt); store.index(receipt)
        if let task=store.writeTail { _=await task.value }
        let saved=try await store.repository.load()
        XCTAssertEqual(saved.active?.id,night.id); XCTAssertEqual(saved.active?.clips.count,1)
        let finished=saved.active!
        _=await store.commit { $0.active=nil; $0.sessions=[finished] }.value
        store.label(receipt.clip,kind:.snore)
        if let task=store.writeTail { _=await task.value }
        XCTAssertEqual(store.archive.sessions[0].clips[0].kind,.snore)
        await store.delete(receipt.clip)
        if let task=store.writeTail { _=await task.value }
        XCTAssertFalse(FileManager.default.fileExists(atPath:url.path))
        XCTAssertTrue(store.archive.sessions[0].clips.isEmpty)
    }
    func testLateReceiptBelongsToFinishedNightNotNewActiveNight() async throws {
        let (store,night,receipt,url)=try await fixture(finished:true)
        defer { try? FileManager.default.removeItem(at:url) }
        let now=Date(); let other=SleepSession(id:UUID(),start:now,checkpoint:now,wake:now.addingTimeInterval(3600),alarmID:UUID(),soundID:"aurora")
        _=await store.commit { $0.active=other }.value
        store.index(receipt)
        if let task=store.writeTail { _=await task.value }
        XCTAssertEqual(store.archive.sessions[0].id,night.id)
        XCTAssertEqual(store.archive.sessions[0].clips.count,1)
        XCTAssertTrue(store.archive.active!.clips.isEmpty)
    }
    func testMissingFileCannotBeResurrectedByReceipt() async throws {
        let (store,_,receipt,url)=try await fixture()
        try FileManager.default.removeItem(at:url); store.index(receipt)
        if let task=store.writeTail { _=await task.value }
        XCTAssertTrue(store.archive.active!.clips.isEmpty)
        try ClipSpool.acknowledge(receipt,directory:DiskLocation.clips)
    }
    func testSystemInterruptionDoesNotResumePreviouslyPausedMicrophone() async throws {
        let (store,_,receipt,url)=try await fixture()
        defer { try? FileManager.default.removeItem(at:url); try? ClipSpool.acknowledge(receipt,directory:DiskLocation.clips) }
        _=await store.commit { $0.preferences.record=true; $0.active?.capturePaused=true }.value
        await store.interruption(began:true)
        await store.interruption(began:false,shouldResume:true)
        XCTAssertFalse(store.audio.isRecording); XCTAssertTrue(store.archive.active?.capturePaused == true)
    }
}
