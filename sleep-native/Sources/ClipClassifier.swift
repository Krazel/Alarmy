import SoundAnalysis
import Foundation

final class ClipClassifier: NSObject, SNResultsObserving {
    private var best: (SleepAudioEvent.Kind, Double)?
    private let lock = NSLock()
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let top = result.classifications.first,
              let kind = Self.kind(identifier: top.identifier, confidence: top.confidence) else { return }
        lock.lock(); defer { lock.unlock() }
        if top.confidence > (best?.1 ?? 0) { best = (kind, top.confidence) }
    }
    func request(_ request: SNRequest, didFailWithError error: Error) {}
    func requestDidComplete(_ request: SNRequest) {}
    static func kind(identifier: String, confidence: Double) -> SleepAudioEvent.Kind? {
        guard confidence >= 0.65 else { return nil }
        switch identifier {
        case "snoring": return .snore
        case "breathing": return .strongBreathing
        case "cough", "coughing": return .cough
        case "speech", "talking", "whispering": return .talking
        default: return nil
        }
    }
    static func classify(url: URL) -> SleepAudioEvent.Kind {
        do {
            let observer = ClipClassifier()
            let analyzer = try SNAudioFileAnalyzer(url: url)
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            try analyzer.add(request, withObserver: observer)
            analyzer.analyze()
            observer.lock.lock(); defer { observer.lock.unlock() }
            return observer.best?.0 ?? .unknown
        } catch { return .unknown }
    }
}
