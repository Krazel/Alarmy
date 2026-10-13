import XCTest
@testable import AlarmaNext

final class DiaryPresentationTests: XCTestCase {
    private let start = Date(timeIntervalSince1970:1_800_000_000)
    private func stage(_ key:String,_ begin:Double,_ end:Double) -> SleepStage {
        SleepStage(id:UUID(),start:start.addingTimeInterval(begin),end:start.addingTimeInterval(end),key:key)
    }
    func testAwakeningsExcludeLatencyFinalWakeAndMissingCoverage() {
        XCTAssertNil(DiaryPresentation.awakenings([]))
        XCTAssertNil(DiaryPresentation.awakenings([stage("awake",0,10)]))
        let values = [stage("awake",0,10),stage("core",10,30),stage("awake",30,40),stage("deep",40,60),stage("awake",60,70)]
        XCTAssertEqual(DiaryPresentation.awakenings(values),1)
        XCTAssertEqual(DiaryPresentation.awakenings([stage("core",0,10),stage("awake",20,30),stage("core",30,40)]),0)
        XCTAssertEqual(DiaryPresentation.awakenings(values+values),1)
    }
    func testSleepRingExcludesAwakeAndKeepsUnspecifiedSleep() {
        let night = SleepSession(id:UUID(),start:start,checkpoint:start.addingTimeInterval(100),end:start.addingTimeInterval(100),wake:start.addingTimeInterval(100),alarmID:UUID(),soundID:"aurora")
        let values = [stage("awake",0,10),stage("core",10,30),stage("deep",30,50),stage("rem",50,80),stage("asleep",80,100)]
        let metrics = NightMetrics(nights:[night])
        let sleep = ["core","deep","rem","asleep"].reduce(0.0) { $0+(metrics.healthSeconds(values,key:$1) ?? 0) }
        XCTAssertEqual(sleep,90)
        XCTAssertEqual(sleep,metrics.healthSeconds(values))
        XCTAssertEqual(metrics.healthSeconds(values,key:"awake"),10)
        XCTAssertEqual(DiaryPresentation.duration(nil),"—")
        XCTAssertEqual(DiaryPresentation.clipTime(24),"00:24")
        XCTAssertEqual(DiaryPresentation.clipTime(75),"01:15")
    }
}
