import XCTest
import AVFoundation
@testable import AlarmaNext

final class NightFeedbackTests: XCTestCase {
    func testUnifiedPreferencePreservesLegacyOptOutAndAlwaysAnalysesRecording() throws {
        for record in [false,true] {
            for analyze in [nil,false,true] as [Bool?] {
                var prefs = Preferences(); prefs.record = record; prefs.analyze = analyze
                let restored = try JSONDecoder().decode(Preferences.self,from:JSONEncoder().encode(prefs))
                XCTAssertEqual(restored.analysisEnabled,record && analyze != false)
            }
        }
    }
    func testRealFreeSpaceReplacesArtificialNightAndLibraryCaps() throws {
        // Existing recordings can exceed 512 MB without disabling a roomy iPhone.
        try RecordingStorage.ensureAvailable(8*1024*1024*1024)
        XCTAssertThrowsError(try RecordingStorage.ensureAvailable(RecordingStorage.reserveBytes))
        XCTAssertThrowsError(try RecordingStorage.ensureAvailable(nil))
    }
    func testLowSpaceDuringRecordingPreservesPlayableClips() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let origin = Date(), result = CaptureResults()
        var checks = 0
        let worker = try CaptureWorker(nightID:UUID(),start:origin,deadline:origin.addingTimeInterval(200),rate:8000,margin:10,directory:dir,
            storageCheck:{ checks += 1; if checks > 1 { throw RecordingStorageError.lowSpace } },
            receipt:result.add,progress:{ _,_,_ in },failure:result.fail,deadlineReached:result.wake)
        let samples: [Float] = (0..<8000*90).map { i in
            let t = Double(i)/8000
            return Float(sin(2 * .pi * 240*t) * (t < 3 ? 0.0001 : 0.01*(0.65+0.35*sin(.pi*t))))
        }
        for i in stride(from:0,to:samples.count,by:1024) { await worker.feedControlled(Array(samples[i..<min(samples.count,i+1024)])) }
        let end = await worker.stop()
        XCTAssertEqual(result.errors,1); XCTAssertEqual(checks,2)
        XCTAssertLessThan(end.timeIntervalSince(origin),90)
        XCTAssertFalse(result.clips.isEmpty)
        for saved in result.clips { XCTAssertGreaterThan(try AVAudioFile(forReading:dir.appendingPathComponent(saved.clip.filename)).length,0) }
    }
    func testEraseAllIncludesOrphansAndKeepsDiaryAndSoundStatisticsAfterRelaunch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        let dir = root.appendingPathComponent("Clips"), file = root.appendingPathComponent("archive.json")
        let spool = try ClipSpool(directory:dir), id = UUID(), now = Date()
        try spool.begin(nightID:id,created:now,sampleRate:8000); try spool.append(Array(repeating:0.1,count:800))
        let receipt = try XCTUnwrap(spool.close())
        var clip = receipt.clip; clip.analysisDone = true; clip.kind = .cough
        let orphan = UUID().uuidString + ".pcm"
        try Data([1,2,3]).write(to:dir.appendingPathComponent(orphan))
        try Data([9]).write(to:root.appendingPathComponent("alarm.wav"))
        var night = SleepSession(id:id,start:now,checkpoint:now.addingTimeInterval(60),end:now.addingTimeInterval(60),wake:now,alarmID:UUID(),soundID:"aurora")
        night.clips = [clip]; let savedNight = night
        let repo = ArchiveRepository(file:file,clipsDirectory:dir)
        _ = try await repo.update { $0.sessions = [savedNight]; $0.pages["day"] = JournalPage(feeling:.peaceful,text:"Keep this dream"); $0.preferences.keepDays = 0 }
        let usage = try RecordingStorage.inventory(at:dir)
        XCTAssertEqual(usage.count,1); XCTAssertGreaterThan(usage.bytes,0); XCTAssertTrue(usage.filenames.contains(orphan))
        _ = try await repo.update { $0.queueAllRecordingsForDeletion(files:usage.filenames) }
        let restored = try await ArchiveRepository(file:file,clipsDirectory:dir).prune()
        XCTAssertEqual(try RecordingStorage.inventory(at:dir).bytes,0)
        XCTAssertTrue(restored.sessions[0].clips.isEmpty); XCTAssertNil(restored.pendingClipDeletions)
        XCTAssertEqual(restored.pages["day"]?.text,"Keep this dream")
        XCTAssertEqual(restored.pages["day"]?.feeling,.peaceful)
        XCTAssertEqual(NightMetrics(nights:restored.sessions).soundCount,1)
        XCTAssertEqual(NightMetrics(nights:restored.sessions).soundSeconds(.cough),clip.duration)
        XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("alarm.wav")),Data([9]))
        XCTAssertTrue(try ClipSpool(directory:dir).recover().isEmpty)
    }
    func testWaveStaysInsideBoundsAtPeaksAndInterpolatesWithoutJumps() {
        for level in [0.0,0.5,1,20,Double.nan] {
            for layer in 0..<12 {
                for phase in stride(from:0.0,to:20,by:0.5) {
                    for x in stride(from:0.0,through:1,by:0.02) {
                        let y = WaveMotion.offset(x:x,phase:phase,layer:layer,level:level,height:76)
                        XCTAssertTrue(y.isFinite); XCTAssertLessThan(abs(y),34)
                    }
                }
            }
        }
        var envelope = WaveEnvelope(); envelope.update(1,at:1)
        XCTAssertEqual(envelope.level(at:1),0)
        XCTAssertEqual(envelope.level(at:1.11),0.5,accuracy:0.001)
        let before = envelope.level(at:1.12); envelope.update(0,at:1.12)
        XCTAssertEqual(envelope.level(at:1.12),before)
        XCTAssertEqual(envelope.level(at:2),0)
    }
}
