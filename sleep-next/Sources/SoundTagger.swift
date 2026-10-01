import Foundation
import SoundAnalysis
import AVFoundation

struct SoundSuggestion {
    let kind: SoundKind
    let confidence: Double
    var completed = true
    var events: [SoundEvent] = []
    static func kind(identifier: String, confidence: Double) -> SoundKind {
        guard confidence >= 0.65 else { return .other }
        switch identifier {
        case "snoring": return .snore
        case "breathing": return .breath
        case "speech": return .voice
        case "cough", "coughing": return .cough
        default: return .other
        }
    }
    static func coalesce(_ windows: [SoundEvent]) -> [SoundEvent] {
        var events: [SoundEvent] = []
        for kind in SoundKind.allCases where kind != .other {
            for window in windows.filter({ $0.kind == kind }).sorted(by: { $0.start < $1.start }) {
                if let index = events.indices.last, events[index].kind == kind,
                   window.start <= events[index].start + events[index].duration + 0.05 {
                    events[index].duration = max(events[index].duration, window.start + window.duration - events[index].start)
                    events[index].confidence = max(events[index].confidence, window.confidence)
                } else { events.append(window) }
            }
        }
        return events.sorted { $0.start < $1.start }
    }
}
private final class ClassificationObserver: NSObject, SNResultsObserving {
    private let lock = NSLock()
    private let duration: Double
    private let breathingOnly: Bool
    private var finished = false
    private var failed = false
    private var windows: [SoundEvent] = []
    init(duration: Double, breathingOnly: Bool = false) { self.duration = duration; self.breathingOnly = breathingOnly }
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let start = max(0, result.timeRange.start.seconds), end = min(duration, result.timeRange.end.seconds)
        guard start.isFinite, end.isFinite, end > start else { return }
        lock.lock(); defer { lock.unlock() }
        let respiratory = result.classifications.filter { ["breathing", "snoring"].contains($0.identifier) }.max { $0.confidence < $1.confidence }?.identifier
        for classification in result.classifications {
            let kind = SoundSuggestion.kind(identifier: classification.identifier, confidence: classification.confidence)
            if breathingOnly && kind != .breath { continue }
            // Breathing and snoring compete within the same window; retain the stronger.
            if (kind == .breath || kind == .snore) && classification.identifier != respiratory { continue }
            if kind != .other { windows.append(SoundEvent(start: start, duration: end-start, kind: kind, confidence: classification.confidence)) }
        }
    }
    func request(_ request: SNRequest, didFailWithError error: Error) { lock.lock(); failed = true; lock.unlock() }
    func requestDidComplete(_ request: SNRequest) { lock.lock(); finished = true; lock.unlock() }
    func result() -> SoundSuggestion {
        lock.lock(); defer { lock.unlock() }
        let events = SoundSuggestion.coalesce(windows)
        let strongest = events.max { $0.confidence < $1.confidence }
        return SoundSuggestion(kind: strongest?.kind ?? .other, confidence: strongest?.confidence ?? 0,
                               completed: finished && !failed, events: events)
    }
}
struct SoundTagger {
    static let version = 2
    static func request(seconds desired: Double = 1) throws -> SNClassifySoundRequest {
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        // A supported window near one second retains brief respiratory events.
        switch request.windowDurationConstraint {
        case .durationRange(let range):
            let seconds = max(range.start.seconds, min(range.end.seconds, desired))
            request.windowDuration = CMTime(seconds: seconds, preferredTimescale: 48000)
        case .enumeratedDurations(let durations):
            if let nearest = durations.min(by: { abs($0.seconds-desired) < abs($1.seconds-desired) }) { request.windowDuration = nearest }
        @unknown default: break
        }
        request.overlapFactor = 0.5
        return request
    }
    // Run after the night, on demand in the diary. Raw audio never leaves the device.
    static func suggest(url: URL) async -> SoundSuggestion {
        let task = Task.detached(priority: .utility) {
            do {
                guard !Task.isCancelled else { return SoundSuggestion(kind: .other, confidence: 0, completed: false) }
                let file = try AVAudioFile(forReading: url)
                let duration = Double(file.length)/file.processingFormat.sampleRate
                func analyze(seconds: Double, breathingOnly: Bool) throws -> SoundSuggestion {
                    let observer = ClassificationObserver(duration: duration, breathingOnly: breathingOnly)
                    let analyzer = try SNAudioFileAnalyzer(url: url)
                    try analyzer.add(request(seconds: seconds), withObserver: observer)
                    analyzer.analyze()
                    return observer.result()
                }
                let brief = try analyze(seconds: 1, breathingOnly: false)
                guard !Task.isCancelled else { return SoundSuggestion(kind: .other, confidence: 0, completed: false) }
                // Soft regular breathing needs more context than a brief cough.
                let breathing = try analyze(seconds: 3, breathingOnly: true)
                let events = SoundSuggestion.coalesce(brief.events + breathing.events)
                let strongest = events.max { $0.confidence < $1.confidence }
                return SoundSuggestion(kind: strongest?.kind ?? .other, confidence: strongest?.confidence ?? 0,
                                       completed: brief.completed && breathing.completed, events: events)
            } catch { return SoundSuggestion(kind: .other, confidence: 0, completed: false) }
        }
        return await withTaskCancellationHandler(operation: { await task.value }, onCancel: { task.cancel() })
    }
}
