import XCTest
import AVFoundation
import SoundAnalysis
@testable import AlarmaNext

private struct CorpusSource: Decodable {
    let filename: String; let kind: String; let split: String
    let offset: Double; let seconds: Double
}
private final class ProbeObserver: NSObject, SNResultsObserving {
    var windows: [[String: Any]] = []
    var complete = false
    var failed = false
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        windows.append(["start": result.timeRange.start.seconds, "duration": result.timeRange.duration.seconds,
                        "scores": Dictionary(uniqueKeysWithValues: result.classifications.map { ($0.identifier, $0.confidence) })])
    }
    func request(_ request: SNRequest, didFailWithError error: Error) { failed = true }
    func requestDidComplete(_ request: SNRequest) { complete = true }
}
final class RecognitionTests: XCTestCase {
    // Real licensed human recordings, never packaged in the production app.
    func testRealRecordingBenchmark() async throws {
        let bundle = Bundle(for: Self.self)
        let manifest = try XCTUnwrap(bundle.url(forResource: "manifest", withExtension: "json"))
        let sources = try JSONDecoder().decode([CorpusSource].self, from: Data(contentsOf: manifest))
        var rows: [[String: Any]] = []
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for source in sources {
            let name = (source.filename as NSString).deletingPathExtension
            let input = try AVAudioFile(forReading: XCTUnwrap(bundle.url(forResource: name, withExtension: "mp3")))
            let rate = input.processingFormat.sampleRate
            input.framePosition = min(input.length, AVAudioFramePosition(source.offset * rate))
            let frames = min(input.length - input.framePosition, AVAudioFramePosition(source.seconds * rate))
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: AVAudioFrameCount(frames)))
            try input.read(into: buffer)
            // Two seconds of zero context on either side match short captured events.
            let context = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: AVAudioFrameCount(frames + Int64(4 * rate))))
            context.frameLength = context.frameCapacity
            for channel in 0..<Int(context.format.channelCount) {
                let pointer = try XCTUnwrap(context.floatChannelData?[channel])
                pointer.initialize(repeating: 0, count: Int(context.frameLength))
                pointer.advanced(by: Int(2 * rate)).update(from: try XCTUnwrap(buffer.floatChannelData?[channel]), count: Int(buffer.frameLength))
            }
            let url = directory.appendingPathComponent(name + ".caf")
            do { let output = try AVAudioFile(forWriting: url, settings: context.format.settings); try output.write(from: context) }
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            let observer = ProbeObserver(), analyzer = try SNAudioFileAnalyzer(url: url)
            try analyzer.add(request, withObserver: observer); _ = await analyzer.analyze()
            XCTAssertTrue(observer.complete && !observer.failed, source.filename)
            let suggestion = await SoundTagger.suggest(url: url)
            XCTAssertTrue(suggestion.completed, source.filename)
            rows.append(["file": source.filename, "expected": source.kind, "split": source.split,
                         "predicted": suggestion.kind.rawValue, "confidence": suggestion.confidence,
                         "events": suggestion.events.map { ["start": $0.start, "duration": $0.duration, "kind": $0.kind.rawValue, "confidence": $0.confidence] as [String: Any] },
                         "defaultWindow": request.windowDuration.seconds, "constraint": String(describing: request.windowDurationConstraint),
                         "knownLabels": request.knownClassifications, "windows": observer.windows])
        }
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "real-recognition-benchmark.json"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertGreaterThanOrEqual(rows.count, 20)
    }
    func testOverlappingWindowsMergeWithoutLosingDifferentSounds() {
        let windows = [SoundEvent(start: 1, duration: 1, kind: .snore, confidence: 0.8),
                       SoundEvent(start: 1.5, duration: 1, kind: .snore, confidence: 0.9),
                       SoundEvent(start: 2, duration: 1, kind: .cough, confidence: 0.75),
                       SoundEvent(start: 6, duration: 1, kind: .snore, confidence: 0.7)]
        let events = SoundSuggestion.coalesce(windows)
        XCTAssertEqual(events.count, 3); XCTAssertEqual(events[0].duration, 1.5)
        XCTAssertEqual(events[0].confidence, 0.9); XCTAssertEqual(events[1].kind, .cough); XCTAssertEqual(events[2].start, 6)
    }
    func testLegacyClipDecodesWithoutRecognitionFields() throws {
        let clip = NightClip(id: UUID(), created: Date(), filename: "legacy.wav", duration: 4)
        let restored = try JSONDecoder().decode(NightClip.self, from: JSONEncoder().encode(clip))
        XCTAssertEqual(restored, clip); XCTAssertNil(restored.events); XCTAssertNil(restored.analysisVersion)
    }
}
