import XCTest
@testable import AlarmaSleep

final class AlarmScheduleTests: XCTestCase {
    private func calendar(_ zone: String = "Europe/Madrid") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    func testOnceMovesToTomorrowAfterItsTime() {
        let alarm = WakeAlarm()
        XCTAssertEqual(alarm.nextDate(after: date("2026-09-05T08:00:00Z"), calendar: calendar()), date("2026-09-06T05:30:00Z"))
    }
    func testWeekdaysSkipWeekend() {
        var alarm = WakeAlarm(); alarm.weekdays = [2,3,4,5,6]
        XCTAssertEqual(alarm.nextDate(after: date("2026-09-04T10:00:00Z"), calendar: calendar()), date("2026-09-07T05:30:00Z"))
    }
    func testExactTimeIsStrictlyFuture() {
        let alarm = WakeAlarm()
        XCTAssertEqual(alarm.nextDate(after: date("2026-09-05T05:30:00Z"), calendar: calendar()), date("2026-09-06T05:30:00Z"))
    }
    func testDisabledAndInvalidAlarmsCannotSchedule() {
        var alarm = WakeAlarm(); alarm.enabled = false
        XCTAssertNil(alarm.nextDate(after: Date()))
        alarm.enabled = true; alarm.hour = 25
        XCTAssertNil(alarm.nextDate(after: Date()))
    }
    func testSpringDSTMissingTimeMovesForward() {
        var alarm = WakeAlarm(); alarm.hour = 2; alarm.minute = 30
        XCTAssertEqual(alarm.nextDate(after: date("2026-03-28T23:00:00Z"), calendar: calendar()), date("2026-03-29T01:00:00Z"))
    }
    func testAutumnDSTUsesFirstRepeatedTime() {
        var alarm = WakeAlarm(); alarm.hour = 2; alarm.minute = 30
        XCTAssertEqual(alarm.nextDate(after: date("2026-10-24T22:00:00Z"), calendar: calendar()), date("2026-10-25T00:30:00Z"))
    }
    func testShuffleDoesNotRepeatLastSound() {
        var alarm = WakeAlarm(); alarm.sounds = ["dawn","chimes"]
        for _ in 0..<30 { XCTAssertEqual(alarm.chooseSound(previous: "dawn"), "chimes") }
    }
    func testMissingSoundsHaveSafeFallback() {
        var alarm = WakeAlarm(); alarm.sounds = ["unknown"]
        XCTAssertEqual(alarm.chooseSound(previous: nil), "dawn")
    }
    func testNegativeDurationIsClamped() {
        let now = Date()
        let entry = NightEntry(startedAt: now, endedAt: now.addingTimeInterval(-60))
        XCTAssertEqual(entry.duration, 0)
    }
}

@MainActor
final class StoreTests: XCTestCase {
    private var root: URL!
    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDown() async throws { try FileManager.default.removeItem(at: root) }
    func testPersistsAlarmAndNotesAcrossLaunch() {
        let file = root.appendingPathComponent("state.json")
        let store = SleepStore(file: file)
        var alarm = WakeAlarm(); alarm.name = "Early flight"; alarm.hour = 4
        store.saveAlarm(alarm)
        let again = SleepStore(file: file)
        XCTAssertEqual(again.data.alarms.last, alarm)
        XCTAssertNil(again.error)
    }
    func testRecoveryEndsAtLastCheckpointAndDoesNotDuplicate() {
        let file = root.appendingPathComponent("state.json")
        let store = SleepStore(file: file)
        let started = Date(timeIntervalSince1970: 10000)
        let checkpoint = started.addingTimeInterval(900)
        store.change { $0.activeNight = ActiveNight(startedAt: started, lastCheckpoint: checkpoint, wakeAt: started.addingTimeInterval(2000), alarm: WakeAlarm()) }
        let again = SleepStore(file: file)
        again.recoverInterruptedNight(); again.recoverInterruptedNight()
        XCTAssertNil(again.data.activeNight)
        XCTAssertEqual(again.data.entries.count, 1)
        XCTAssertEqual(again.data.entries[0].duration, 900)
        XCTAssertTrue(again.data.entries[0].interrupted)
    }
    func testCorruptDataIsNotOverwritten() throws {
        let file = root.appendingPathComponent("state.json")
        let bytes = Data("not json".utf8)
        try bytes.write(to: file)
        let store = SleepStore(file: file)
        store.saveAlarm(WakeAlarm())
        XCTAssertNotNil(store.error)
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }
    func testAllAudioAndArtResourcesAreBundled() {
        let bundle = Bundle(for: SleepStore.self)
        for name in ["ambient","dawn","drift","chimes"] {
            XCTAssertNotNil(bundle.url(forResource: name, withExtension: "wav"))
        }
        XCTAssertNotNil(bundle.url(forResource: "night-landscape", withExtension: "png"))
    }
}
