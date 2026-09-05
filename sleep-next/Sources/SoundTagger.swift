import Foundation
import SoundAnalysis

struct SoundSuggestion {
    let kind: SoundKind
    let confidence: Double
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
}
private final class ClassificationObserver: NSObject, SNResultsObserving {
    private let lock = NSLock()
    private var strongest = SoundSuggestion(kind: .other, confidence: 0)
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult, let top = result.classifications.first else { return }
        let kind = SoundSuggestion.kind(identifier: top.identifier, confidence: top.confidence)
        guard kind != .other else { return }
        lock.lock(); defer { lock.unlock() }
        if top.confidence > strongest.confidence { strongest = SoundSuggestion(kind: kind, confidence: top.confidence) }
    }
    func request(_ request: SNRequest, didFailWithError error: Error) { }
    func requestDidComplete(_ request: SNRequest) { }
    func result() -> SoundSuggestion { lock.lock(); defer { lock.unlock() }; return strongest }
}
struct SoundTagger {
    // Run after the night, on demand in the diary. Raw audio never leaves the device.
    static func suggest(url: URL) async -> SoundSuggestion {
        await Task.detached(priority: .utility) {
            do {
                let observer = ClassificationObserver()
                let analyzer = try SNAudioFileAnalyzer(url: url)
                let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
                try analyzer.add(request, withObserver: observer)
                analyzer.analyze()
                return observer.result()
            } catch { return SoundSuggestion(kind: .other, confidence: 0) }
        }.value
    }
}
