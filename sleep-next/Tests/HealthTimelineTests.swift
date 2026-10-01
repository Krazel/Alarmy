import XCTest
@testable import AlarmaNext

final class HealthTimelineTests: XCTestCase {
    func testDuplicateHealthRecordsDoNotDoubleCountAndDetailedStagesWin() {
        let origin = Date(timeIntervalSince1970: 1000)
        func stage(_ a: Double, _ b: Double, _ key: String) -> SleepStage { SleepStage(id: UUID(), start: origin.addingTimeInterval(a), end: origin.addingTimeInterval(b), key: key) }
        let stages = HealthReader.normalize([stage(0, 100, "asleep"), stage(0, 100, "asleep"), stage(20, 60, "core"), stage(50, 80, "deep")])
        XCTAssertEqual(stages.map(\.key), ["asleep", "core", "deep", "asleep"])
        XCTAssertEqual(stages.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }, 100)
        XCTAssertEqual(Set(stages.map(\.id)).count, stages.count)
        for (a,b) in zip(stages, stages.dropFirst()) { XCTAssertEqual(a.end, b.start) }
    }
    func testMissingHealthPeriodsRemainGaps() {
        let a = Date(timeIntervalSince1970: 1000)
        let stages = HealthReader.normalize([SleepStage(id: UUID(), start: a, end: a.addingTimeInterval(20), key: "core"), SleepStage(id: UUID(), start: a.addingTimeInterval(80), end: a.addingTimeInterval(100), key: "deep")])
        XCTAssertEqual(stages.count, 2); XCTAssertEqual(stages.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }, 40)
    }
}
