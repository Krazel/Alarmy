import HealthKit
import Foundation

struct SleepStage: Identifiable {
    let id: UUID; let start: Date; let end: Date; let key: String
}
struct HealthReader {
    private let store = HKHealthStore()
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
        let grouped = Dictionary(grouping: samples.filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }, by: { $0.sourceRevision.source.bundleIdentifier })
        let selected = grouped.values.max { left, right in
            left.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } < right.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        } ?? []
        return selected.compactMap { sample in
            let key: String
            switch sample.value {
            case HKCategoryValueSleepAnalysis.awake.rawValue: key = "awake"
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue: key = "core"
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: key = "deep"
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue: key = "rem"
            default: key = "asleep"
            }
            let a = max(start, sample.startDate), b = min(noon, sample.endDate)
            return b > a ? SleepStage(id: sample.uuid, start: a, end: b, key: key) : nil
        }
    }
}
