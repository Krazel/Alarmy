import XCTest
@testable import AlarmaNext

final class RecognitionQueueTests: XCTestCase {
    private func clip(_ kind: SoundKind = .other, done: Bool = false, failed: Bool = false) -> NightClip {
        let id = UUID()
        var clip = NightClip(id:id,created:Date(),filename:id.uuidString+".wav",duration:30)
        clip.kind = kind; clip.analysisDone = done; clip.analysisFailed = failed
        clip.analysisVersion = SoundTagger.version
        return clip
    }
    private func night(_ clips: [NightClip]) -> SleepSession {
        let start = Date().addingTimeInterval(-3600), end = Date().addingTimeInterval(60)
        return SleepSession(id:UUID(),start:start,checkpoint:end,end:end,wake:end,alarmID:UUID(),soundID:"aurora",clips:clips)
    }
    func testUnknownCleanupPreservesPendingFailedAndRecognized() throws {
        let unknown = clip(done:true), pending = clip(), failed = clip(failed:true), known = clip(.snore,done:true)
        var n = night([unknown,pending,failed,known]); n.soundSummaries = n.clips.map {NightSoundSummary(clip:$0)}
        var archive = AppArchive(); archive.sessions = [n]; archive.pages["day"] = JournalPage(text:"Keep this")
        archive.queueUnrecognizedClips()
        XCTAssertEqual(archive.pendingClipDeletions,[unknown.filename])
        XCTAssertEqual(archive.sessions[0].clips.count,4,"Do not remove the index before deleting files")
        archive.completeClipDeletion([unknown.filename])
        XCTAssertEqual(archive.sessions[0].clips.map(\.id),[pending.id,failed.id,known.id])
        XCTAssertEqual(archive.pages["day"]?.text,"Keep this")
        let metrics = NightMetrics(nights:archive.sessions)
        XCTAssertEqual(metrics.soundCount,1); XCTAssertEqual(metrics.pendingSoundCount,1); XCTAssertEqual(metrics.failedSoundCount,1)
        XCTAssertEqual(metrics.recordedSeconds,30,accuracy:0.001)
        let restored = try JSONDecoder().decode(AppArchive.self,from:JSONEncoder().encode(archive))
        XCTAssertNil(restored.pendingClipDeletions)
    }
    @MainActor func testFailedRecognitionRetriesOnNextActivationWithoutEndlessLoop() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        let store = SleepStore(repository:ArchiveRepository(file:root.appendingPathComponent("archive.json")))
        store.archive.sessions = [night([clip()])]; store.loaded = true
        var attempts = 0
        store.classifyClip = { _ in
            attempts += 1
            return attempts == 1 ? SoundSuggestion(kind:.other,confidence:0,completed:false) : SoundSuggestion(kind:.cough,confidence:0.9,events:[SoundEvent(start:0,duration:1,kind:.cough,confidence:0.9)])
        }
        store.scheduleClipAnalysis(); await store.analysisWorker?.value
        XCTAssertEqual(attempts,1); XCTAssertEqual(store.archive.sessions[0].clips.count,1)
        XCTAssertEqual(store.archive.sessions[0].clips[0].analysisFailed,true)
        store.scheduleClipAnalysis(); await store.analysisWorker?.value
        XCTAssertEqual(attempts,1,"A new clip callback must not keep retrying a persistent failure")
        store.retryPendingClipAnalysis(); await store.analysisWorker?.value
        XCTAssertEqual(attempts,2); XCTAssertTrue(store.archive.sessions[0].clips[0].recognized)
        XCTAssertEqual(store.archive.sessions[0].clips[0].kind,.cough)
        let saved = try await store.repository.load()
        XCTAssertEqual(saved.sessions[0].clips[0].kind,.cough)
    }
    @MainActor func testQueueKeepsOnlyRecognizedClipsAndDoesNotDuplicateWork() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        let store = SleepStore(repository:ArchiveRepository(file:root.appendingPathComponent("archive.json")))
        store.archive.sessions = [night([clip(),clip(),clip()])]; store.loaded = true
        var attempts = 0, concurrent = 0, maximum = 0
        store.classifyClip = { _ in
            attempts += 1; concurrent += 1; maximum = max(maximum,concurrent)
            try? await Task.sleep(nanoseconds:1_000_000); concurrent -= 1
            return SoundSuggestion(kind:.other,confidence:0,completed:true)
        }
        store.scheduleClipAnalysis(); store.scheduleClipAnalysis()
        await store.analysisWorker?.value
        XCTAssertEqual(attempts,3); XCTAssertEqual(maximum,1)
        XCTAssertTrue(store.archive.sessions[0].clips.isEmpty)
        XCTAssertEqual(NightMetrics(nights:store.archive.sessions).soundCount,0)
        let saved = try await store.repository.load()
        XCTAssertTrue(saved.sessions[0].clips.isEmpty); XCTAssertNil(saved.pendingClipDeletions)
    }
    func testSixMinutesCannotRepresentAnEightHourNight() {
        let start = Date(), end = start.addingTimeInterval(497*60)
        let n = SleepSession(id:UUID(),start:start,checkpoint:end,end:end,wake:end,alarmID:UUID(),soundID:"aurora")
        let partial = [SleepStage(id:UUID(),start:start,end:start.addingTimeInterval(360),key:"core")]
        let m = NightMetrics(nights:[n])
        XCTAssertEqual(m.sleepSeconds(partial),360)
        XCTAssertNil(m.sleepEstimate(partial))
        XCTAssertEqual(m.inBed,497*60)
    }
}
