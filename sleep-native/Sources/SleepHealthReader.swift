import HealthKit

final class SleepHealthReader {
    private let store = HKHealthStore()
    private let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw CocoaError(.featureUnsupported) }
        try await store.requestAuthorization(toShare: [], read: [type])
    }
    func read() async throws -> [SleepStageSample] {
        let records: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, values, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: values as? [HKCategorySample] ?? []) }
            }
            store.execute(query)
        }
        // Select one source per waking day to avoid plotting overlapping estimates from multiple devices.
        let staged = records.filter { Self.stage($0.value) != nil }
        let days = Dictionary(grouping: staged) { sample in
            DreamEntry.key(for: Calendar.current.date(byAdding: .hour, value: 12, to: sample.startDate)!)
        }
        return days.values.flatMap { day -> [SleepStageSample] in
            let sources = Dictionary(grouping: day) { $0.sourceRevision.source.bundleIdentifier }
            let chosen = sources.sorted { a, b in
                let aDuration = a.value.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let bDuration = b.value.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                return aDuration == bDuration ? a.key < b.key : aDuration > bDuration
            }.first?.value ?? []
            return chosen.compactMap { sample in
                guard let stage = Self.stage(sample.value) else { return nil }
                return SleepStageSample(id: sample.uuid, date: sample.startDate, endDate: sample.endDate, stage: stage, movement: 0, soundEvents: 0)
            }
        }.sorted { $0.date < $1.date }
    }
    static func stage(_ value: Int) -> SleepStageSample.Stage? {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .awake: return .awake
        case .asleepCore: return .light
        case .asleepDeep: return .deep
        case .asleepREM: return .rem
        default: return nil
        }
    }
}
