import HealthKit
import Foundation

struct SleepStage: Identifiable {
    let id: UUID; let start: Date; let end: Date; let key: String
}
struct HealthReader {
    private let store = HKHealthStore()
    static func normalize(_ stages: [SleepStage]) -> [SleepStage] {
        let boundaries = Set(stages.flatMap { [$0.start, $0.end] }).sorted()
        var result: [SleepStage] = []
        for (start, end) in zip(boundaries, boundaries.dropFirst()) where end > start {
            let covering = stages.filter { $0.start <= start && $0.end >= end }
            let selected = covering.sorted {
                if ($0.key == "asleep") != ($1.key == "asleep") { return $0.key != "asleep" }
                if $0.start != $1.start { return $0.start > $1.start }
                return $0.id.uuidString < $1.id.uuidString
            }.first
            guard let selected else { continue }
            if let last = result.last, last.key == selected.key, last.end == start {
                result[result.count-1] = SleepStage(id: last.id, start: last.start, end: end, key: last.key)
            } else { result.append(SleepStage(id: UUID(), start: start, end: end, key: selected.key)) }
        }
        return result
    }
    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable(), let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        try await store.requestAuthorization(toShare: [], read: [type])
    }
    func stages(for day: Date) async throws -> [SleepStage] {
        guard HKHealthStore.isHealthDataAvailable(), let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        let start = Calendar.current.date(byAdding: .day, value: -1, to: noon)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: noon, options: [])
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            store.execute(HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples as? [HKCategorySample] ?? []) }
            })
        }
        // Use one source per night so records synced by multiple apps are not double counted.
        let grouped = Dictionary(grouping: samples, by: { $0.sourceRevision.source.bundleIdentifier })
        let candidates = grouped.keys.sorted().map { source in Self.normalize((grouped[source] ?? []).compactMap { sample in
            let key: String
            switch sample.value {
            case HKCategoryValueSleepAnalysis.awake.rawValue: key = "awake"
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue: key = "core"
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: key = "deep"
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue: key = "rem"
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: key = "asleep"
            default: return nil
            }
            let a = max(start, sample.startDate), b = min(noon, sample.endDate)
            return b > a ? SleepStage(id: sample.uuid, start: a, end: b, key: key) : nil
        }) }
        // Compare union durations; duplicated records from the same source do not win.
        return candidates.max { left, right in
            left.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } < right.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        } ?? []
    }
}
