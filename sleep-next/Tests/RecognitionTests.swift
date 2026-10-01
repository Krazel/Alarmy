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
        let fan = try AVAudioFile(forReading: XCTUnwrap(bundle.url(forResource: "other-96913", withExtension: "mp3")))
        let fanBuffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: fan.processingFormat, frameCapacity: AVAudioFrameCount(min(fan.length, Int64(fan.processingFormat.sampleRate*16)))))
        try fan.read(into: fanBuffer)
        let fanSamples = Array(UnsafeBufferPointer(start: try XCTUnwrap(fanBuffer.floatChannelData?[0]), count: Int(fanBuffer.frameLength)))
        let fanRMS = sqrt(fanSamples.reduce(0.0) { $0 + Double($1)*Double($1) } / Double(fanSamples.count))
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
            let captured = CaptureResults()
            let captureDirectory = directory.appendingPathComponent(name + "-capture")
            let origin = Date(timeIntervalSince1970: 1_800_000_000)
            let worker = try CaptureWorker(nightID: UUID(), start: origin, deadline: origin.addingTimeInterval(60), rate: rate, margin: 10, directory: captureDirectory,
                                           receipt: captured.add, progress: { _,_,_ in }, failure: captured.fail, deadlineReached: captured.wake)
            let mono = Array(UnsafeBufferPointer(start: try XCTUnwrap(context.floatChannelData?[0]), count: Int(context.frameLength)))
            for offset in stride(from: 0, to: mono.count, by: 8192) { await worker.feedControlled(Array(mono[offset..<min(mono.count, offset+8192)])) }
            await worker.stop()
            XCTAssertEqual(captured.errors, 0, source.filename)
            var pipeline: [[String: Any]] = []
            for receipt in captured.clips {
                let result = await SoundTagger.suggest(url: captureDirectory.appendingPathComponent(receipt.clip.filename))
                XCTAssertTrue(result.completed, source.filename)
                pipeline.append(["start": receipt.clip.created.timeIntervalSince(origin), "duration": receipt.clip.duration,
                                 "predicted": result.kind.rawValue, "confidence": result.confidence,
                                 "events": result.events.map { ["start": $0.start, "duration": $0.duration, "kind": $0.kind.rawValue, "confidence": $0.confidence] as [String: Any] }])
            }
            rows.append(["file": source.filename, "expected": source.kind, "split": source.split, "condition": "clean",
                         "predicted": suggestion.kind.rawValue, "confidence": suggestion.confidence,
                         "events": suggestion.events.map { ["start": $0.start, "duration": $0.duration, "kind": $0.kind.rawValue, "confidence": $0.confidence] as [String: Any] },
                         "defaultWindow": request.windowDuration.seconds, "constraint": String(describing: request.windowDurationConstraint),
                         "knownLabels": request.knownClassifications, "windows": observer.windows, "capturedClips": pipeline])
            let signalSamples = Array(UnsafeBufferPointer(start: try XCTUnwrap(buffer.floatChannelData?[0]), count: Int(buffer.frameLength)))
            let signalRMS = sqrt(signalSamples.reduce(0.0) { $0 + Double($1)*Double($1) } / Double(signalSamples.count))
            for condition in ["quiet-minus18dB", "real-fan-10dB"] {
                let mixed = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: context.format, frameCapacity: context.frameCapacity))
                mixed.frameLength = context.frameLength
                for channel in 0..<Int(context.format.channelCount) {
                    let input = try XCTUnwrap(context.floatChannelData?[channel]), output = try XCTUnwrap(mixed.floatChannelData?[channel])
                    for i in 0..<Int(context.frameLength) {
                        if condition == "quiet-minus18dB" { output[i] = input[i] * 0.12589254 }
                        else {
                            let n = Int(Double(i)*fan.processingFormat.sampleRate/rate) % fanSamples.count
                            let noise = Double(fanSamples[n]) * signalRMS / max(1e-8, fanRMS) / sqrt(10)
                            output[i] = max(-1, min(1, input[i] + Float(noise)))
                        }
                    }
                }
                let mixedURL = directory.appendingPathComponent(name + "-" + condition + ".caf")
                do { let output = try AVAudioFile(forWriting: mixedURL, settings: mixed.format.settings); try output.write(from: mixed) }
                let mixedResult = await SoundTagger.suggest(url: mixedURL)
                XCTAssertTrue(mixedResult.completed, source.filename + condition)
                rows.append(["file": source.filename, "expected": source.kind, "split": source.split, "condition": condition,
                             "predicted": mixedResult.kind.rawValue, "confidence": mixedResult.confidence,
                             "events": mixedResult.events.map { ["start": $0.start, "duration": $0.duration, "kind": $0.kind.rawValue, "confidence": $0.confidence] as [String: Any] }])
            }
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
