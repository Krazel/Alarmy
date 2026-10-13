import XCTest
@testable import AlarmaNext

final class AnalysisInsightsTests: XCTestCase {
    private let base = Date(timeIntervalSince1970:1700000000)
    private func night(_ seconds: Double = 3600) -> SleepSession { SleepSession(id:UUID(),start:base,checkpoint:base.addingTimeInterval(seconds),end:base.addingTimeInterval(seconds),wake:base.addingTimeInterval(seconds),alarmID:UUID(),soundID:"aurora") }
    private func stage(_ start: Double,_ end: Double,_ key: String) -> SleepStage {SleepStage(id:UUID(),start:base.addingTimeInterval(start),end:base.addingTimeInterval(end),key:key)}
    func testTrimmingPreservesOriginalAndClipsCoverage() {
        var n = night(); n.acousticEpochs = [AcousticEpoch(id:UUID(),start:base,duration:1800,activeSeconds:100,meanDBFS:-45)]
        n.correction = SessionCorrection(start:base.addingTimeInterval(900),end:base.addingTimeInterval(2700))
        let m = NightMetrics(nights:[n])
        XCTAssertEqual(n.duration,3600); XCTAssertEqual(m.inBed,1800); XCTAssertEqual(m.observed,900); XCTAssertEqual(m.coverage,0.5)
        XCTAssertFalse(SessionCorrection(start:base.addingTimeInterval(-1),end:base.addingTimeInterval(3600)).valid(for:n))
    }
    func testContinuityExcludesLatencyAndFinalWake() {
        let result = SleepContinuity(nights:[night()],stages:[stage(0,300,"awake"),stage(300,1500,"core"),stage(1500,1800,"awake"),stage(1800,3000,"deep"),stage(3000,3600,"awake")])
        XCTAssertEqual(result.asleep,2400); XCTAssertEqual(result.latency,300); XCTAssertEqual(result.awakeDuringSleep,300)
        XCTAssertEqual(result.awakenings,1); XCTAssertEqual(result.longestSleep,1200)
        XCTAssertEqual(result.efficiency!,2.0/3.0,accuracy:0.0001)
    }
    func testMissingObservationsAreNotSleepOrZeroAwakenings() {
        let result = SleepContinuity(nights:[night()],stages:[stage(300,1500,"core"),stage(1800,3000,"core")])
        XCTAssertNil(result.efficiency); XCTAssertNil(result.latency); XCTAssertNil(result.awakenings); XCTAssertNil(result.awakeDuringSleep)
        XCTAssertEqual(result.longestSleep,1200)
        let missing = SleepContinuity(nights:[night()],stages:[])
        XCTAssertNil(missing.asleep); XCTAssertNil(missing.longestSleep)
    }
    func testHabitComparisonExcludesUnrecordedDaysAndNaps() {
        var nights:[SleepSession] = []; var pages:[String:JournalPage] = [:]
        for i in 0..<7 {
            let start = base.addingTimeInterval(Double(i)*86400), end = start.addingTimeInterval(3600)
            let n = SleepSession(id:UUID(),start:start,checkpoint:end,end:end,wake:end,alarmID:UUID(),soundID:"aurora")
            nights.append(n)
            if i < 6 { pages[CalendarDay.key(end)] = JournalPage(habits:i < 3 ? [.lateCoffee] : []) }
        }
        XCTAssertEqual(AnalysisInsights.habit(.lateCoffee,nights:nights,pages:pages)?.taggedDays,3)
        XCTAssertEqual(AnalysisInsights.habit(.lateCoffee,nights:nights,pages:pages)?.otherDays,3)
        nights[0].isNap = true
        XCTAssertNil(AnalysisInsights.habit(.lateCoffee,nights:nights,pages:pages))
    }
    func testArchiveCompatibilityAndRoundTrip() throws {
        let old = Data("{\"feeling\":2,\"text\":\"keep\"}".utf8)
        let page = try JSONDecoder().decode(JournalPage.self,from:old)
        XCTAssertNil(page.habits); XCTAssertEqual(page.text,"keep")
        var n = night(); n.isNap = true; n.snoozeDates = [base]; n.correction = SessionCorrection(start:base,end:base.addingTimeInterval(1800))
        XCTAssertEqual(try JSONDecoder().decode(SleepSession.self,from:JSONEncoder().encode(n)),n)
    }
    func testCSVLeavesUnknownSleepBlankAndExcludesNotes() {
        let n = night(), page = JournalPage(feeling:.bright,text:"private diary",habits:[.exercise])
        let csv = AnalysisInsights.csv(nights:[n],pages:[CalendarDay.key(n.end!):page],stages:[:],words:Words(language:"en"))
        XCTAssertFalse(csv.contains("private diary")); XCTAssertTrue(csv.contains("Unavailable")); XCTAssertTrue(csv.contains("Exercise"))
        XCTAssertTrue(csv.contains("\"60.0\",\"\"")); XCTAssertEqual(csv.components(separatedBy:"\r\n").count,2)
    }
    func testClockDifferenceCrossesMidnight() { XCTAssertEqual(AnalysisInsights.clockDifference(5,1435),10); XCTAssertEqual(AnalysisInsights.clockDifference(1435,5),-10) }
}
