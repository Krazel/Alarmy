import Foundation

struct SleepStage: Identifiable {
    let id: UUID; let start: Date; let end: Date; let key: String
}
enum SleepStageTimeline {
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
}
