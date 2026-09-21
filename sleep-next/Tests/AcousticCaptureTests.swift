import XCTest
import AVFoundation
@testable import AlarmaNext

private final class CaptureResults: @unchecked Sendable {
    private let lock = NSLock()
    private var saved: [ClipReceipt] = []
    private var problems = 0
    private var deadline = false
    func add(_ receipt: ClipReceipt) { lock.lock(); saved.append(receipt); lock.unlock() }
    func fail(_ error: Error) { lock.lock(); problems += 1; lock.unlock() }
    func wake() { lock.lock(); deadline = true; lock.unlock() }
    var clips: [ClipReceipt] { lock.lock(); defer { lock.unlock() }; return saved }
    var errors: Int { lock.lock(); defer { lock.unlock() }; return problems }
    var reachedDeadline: Bool { lock.lock(); defer { lock.unlock() }; return deadline }
}
final class AcousticCaptureTests: XCTestCase {
    let rate = 8000.0
    let origin = Date(timeIntervalSince1970: 1_800_000_000)
    func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    func signal(seconds: Double = 10, events: [ClosedRange<Double>] = [3...3.3], background: Float = 0.0001, event: Float = 0.01) -> [Float] {
        (0..<Int(seconds*rate)).map { i in
            let t = Double(i)/rate
            let amplitude = events.contains { $0.contains(t) } ? event : background
            return amplitude * Float(sin(2 * .pi * 240 * t))
        }
    }
    func run(_ samples: [Float], block: Int = 1024, deadline: Double = 600, byteLimit: Int = 10_000_000) async throws -> (CaptureResults, URL) {
        let results = CaptureResults(), dir = directory()
        let worker = try CaptureWorker(nightID: UUID(), start: origin, deadline: origin.addingTimeInterval(deadline), rate: rate, margin: 10, directory: dir, byteLimit: byteLimit, receipt: results.add, progress: { _,_,_ in }, failure: results.fail, deadlineReached: results.wake)
        for start in stride(from: 0, to: samples.count, by: block) { await worker.feedControlled(Array(samples[start..<min(samples.count,start+block)])) }
        await worker.stop()
        return (results, dir)
    }
    func testSilenceAndSteadyFanProduceNoFiles() async throws {
        for level: Float in [0, 0.0001, 0.03] {
            let (result, dir) = try await run(signal(events: [], background: level))
            XCTAssertTrue(result.clips.isEmpty); XCTAssertEqual(result.errors, 0)
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
        }
    }
    func testQuietBriefEventIncludesOnsetAndContext() async throws {
        let (result, dir) = try await run(signal(events: [3...3.12], event: 0.003))
        let clip = try XCTUnwrap(result.clips.first?.clip)
        XCTAssertEqual(result.clips.count, 1); XCTAssertLessThanOrEqual(clip.created.timeIntervalSince(origin), 1.2)
        XCTAssertGreaterThan(clip.created.timeIntervalSince(origin) + clip.duration, 5)
        let file = try AVAudioFile(forReading: dir.appendingPathComponent(clip.filename))
        XCTAssertEqual(Double(file.length)/file.processingFormat.sampleRate, clip.duration, accuracy: 0.001)
        let data = try Data(contentsOf: dir.appendingPathComponent(clip.filename))
        let offset = 44 + Int((3.04 - clip.created.timeIntervalSince(origin))*rate)*2
        XCTAssertTrue(data[offset..<offset+100].contains { $0 != 0 }, "Event onset must be audible in saved PCM")
    }
    func testPacketSizesProduceIdenticalAudio() async throws {
        let samples = signal(events: [3...3.3, 7...7.2])
        let (a, aDir) = try await run(samples, block: 97)
        let (b, bDir) = try await run(samples, block: 2048)
        XCTAssertEqual(a.clips.count, b.clips.count)
        for (x,y) in zip(a.clips,b.clips) {
            XCTAssertEqual(x.clip.created,y.clip.created); XCTAssertEqual(x.clip.duration,y.clip.duration)
            XCTAssertEqual(try Data(contentsOf:aDir.appendingPathComponent(x.clip.filename)),try Data(contentsOf:bDir.appendingPathComponent(y.clip.filename)))
        }
    }
    func testNearbyEventsMergeAndSeparatedEventsDoNotOverlap() async throws {
        let (merged, _) = try await run(signal(events: [3...3.2, 4...4.2]))
        XCTAssertEqual(merged.clips.count,1)
        let (split, _) = try await run(signal(seconds: 14, events: [3...3.2, 10...10.2]))
        XCTAssertEqual(split.clips.count,2)
        XCTAssertLessThanOrEqual(split.clips[0].clip.created.addingTimeInterval(split.clips[0].clip.duration),split.clips[1].clip.created)
    }
    func testLongEventSplitsWithoutDuplicateOrMissingSamples() async throws {
        let (result, _) = try await run(signal(seconds: 70, events: [3...67]))
        XCTAssertGreaterThanOrEqual(result.clips.count,3)
        for clip in result.clips { XCTAssertLessThanOrEqual(clip.clip.duration,30.02) }
        for (a,b) in zip(result.clips,result.clips.dropFirst()) { XCTAssertEqual(a.clip.created.addingTimeInterval(a.clip.duration).timeIntervalSince(b.clip.created),0,accuracy:0.001) }
    }
    func testStopFlushesShortEventIntoPlayableWAV() async throws {
        let (result, dir) = try await run(signal(seconds:3.15, events:[3...4]))
        let clip = try XCTUnwrap(result.clips.first?.clip)
        XCTAssertGreaterThan(try AVAudioFile(forReading:dir.appendingPathComponent(clip.filename)).length,0)
    }
    func testAlarmDeadlineExcludesOwnAlarmAudio() async throws {
        let (result,_) = try await run(signal(seconds:12,events:[3...3.2,8...11]),deadline:7)
        XCTAssertTrue(result.reachedDeadline); XCTAssertEqual(result.clips.count,1)
        XCTAssertLessThanOrEqual(result.clips[0].clip.created.addingTimeInterval(result.clips[0].clip.duration),origin.addingTimeInterval(7))
    }
    func testBudgetExhaustionReportsFailureAndLeavesRecoverableData() async throws {
        let (result,dir) = try await run(signal(seconds:8,events:[3...7]),byteLimit:40000)
        XCTAssertGreaterThan(result.errors,0)
        let spool = try ClipSpool(directory:dir); let recovered = try spool.recover()
        XCTAssertFalse(recovered.isEmpty)
        for receipt in recovered { XCTAssertGreaterThan(try AVAudioFile(forReading:dir.appendingPathComponent(receipt.clip.filename)).length,0) }
    }
    func testCrashRecoveryIsIdempotentAndPreservesNightID() throws {
        let dir=directory(), night=UUID()
        var spool: ClipSpool? = try ClipSpool(directory:dir)
        try spool?.begin(nightID:night,created:origin,sampleRate:rate)
        try spool?.append(signal(seconds:1,events:[0...1])); spool=nil
        let recovered=try ClipSpool(directory:dir).recover()
        XCTAssertEqual(recovered.count,1); XCTAssertEqual(recovered.first?.nightID,night)
        XCTAssertEqual(recovered.first?.clip.duration,1)
        XCTAssertEqual(try ClipSpool(directory:dir).recover().first?.clip.id,recovered.first?.clip.id)
        try ClipSpool.acknowledge(recovered[0],directory:dir)
        XCTAssertTrue(try ClipSpool(directory:dir).recover().isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath:dir.appendingPathComponent(recovered[0].clip.filename).path))
    }
    func testDamagedManifestDoesNotHideHealthyClip() throws {
        let dir=directory(); let spool=try ClipSpool(directory:dir)
        try spool.begin(nightID:UUID(),created:origin,sampleRate:rate); try spool.append(signal(seconds:1)); _=try spool.close()
        try Data("broken".utf8).write(to:dir.appendingPathComponent("damaged.open.json"))
        XCTAssertEqual(try spool.recover().count,1); XCTAssertEqual(spool.recoveryFailures,1)
    }
    func testReadOnlyOrInvalidStorageFailsBeforeCapture() throws {
        let file=directory(); try Data().write(to:file)
        XCTAssertThrowsError(try ClipSpool(directory:file))
    }
    func testOldArchiveWithoutCaptureFieldsStillDecodes() throws {
        let old=AppArchive(); let data=try JSONEncoder().encode(old)
        let restored=try JSONDecoder().decode(AppArchive.self,from:data)
        XCTAssertNil(restored.preferences.sensitivity)
    }
    func testClassifierReportsMissingFileInsteadOfSuccessfulUnknown() async {
        let suggestion = await SoundTagger.suggest(url: directory().appendingPathComponent("missing.wav"))
        XCTAssertFalse(suggestion.completed)
    }
    func testNativeClassifierCanReadProducedWAV() async throws {
        let (result,dir) = try await run(signal())
        let clip = try XCTUnwrap(result.clips.first?.clip)
        let suggestion = await SoundTagger.suggest(url:dir.appendingPathComponent(clip.filename))
        XCTAssertTrue(suggestion.completed)
        XCTAssertTrue((0...1).contains(suggestion.confidence))
    }
    func testControlledAudioEvidenceAttachment() async throws {
        let (result,dir)=try await run(signal(seconds:12,events:[3...3.2,8...8.3]))
        XCTAssertEqual(result.clips.count,2)
        for (i,receipt) in result.clips.enumerated() {
            let attachment=XCTAttachment(contentsOfFile:dir.appendingPathComponent(receipt.clip.filename))
            attachment.name="controlled-event-\(i+1).wav"; attachment.lifetime = .keepAlways; add(attachment)
        }
        let inputSpool=try ClipSpool(directory:directory())
        try inputSpool.begin(nightID:UUID(),created:origin,sampleRate:rate)
        try inputSpool.append(signal(seconds:12,events:[3...3.2,8...8.3]))
        let input=try XCTUnwrap(inputSpool.close())
        let original=XCTAttachment(contentsOfFile:inputSpool.directory.appendingPathComponent(input.clip.filename))
        original.name="controlled-input.wav"; original.lifetime = .keepAlways; add(original)
        let evidence=try JSONEncoder().encode(result.clips)
        let attachment=XCTAttachment(data:evidence,uniformTypeIdentifier:"public.json")
        attachment.name="controlled-audio-evidence.json"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
