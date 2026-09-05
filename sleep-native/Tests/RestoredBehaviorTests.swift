import UIKit
import XCTest
import HealthKit
@testable import AlarmaSleep

@MainActor
final class RestoredBehaviorTests: XCTestCase {
    private func store() -> SleepStore {
        SleepStore(file: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json"))
    }
    func testJournalAllowsDayWithoutRecordingAndPersistsClearedMood() throws {
        let store = store(), dreams = DreamStore(store: store), day = Date()
        var entry = dreams.entry(for: day)
        entry.notes = "My dream"; entry.wakeMood = .calm
        dreams.upsert(entry)
        XCTAssertEqual(dreams.entry(for: day).notes, "My dream")
        entry.wakeMood = nil; dreams.upsert(entry)
        XCTAssertNil(dreams.entry(for: day).wakeMood)
        XCTAssertTrue(store.data.entries.isEmpty)
    }
    func testNightlyAlarmRearmsOnNextNightAndKeepsOptions() {
        let store = store()
        var alarm = store.sleepAlarm
        alarm.lightWakeEnabled = true; alarm.lightWakeMinutes = 10
        alarm.motionSnooze = true; alarm.snoozeMinutes = 15
        alarm.oneShotDate = .distantPast
        store.updateSleepAlarm(alarm)
        XCTAssertNotNil(store.sleepAlarm.nextDate(after: Date()))
        XCTAssertEqual(store.sleepAlarm.lightWakeMinutes, 10)
        XCTAssertTrue(store.sleepAlarm.lightWakeEnabled)
        XCTAssertEqual(store.sleepAlarm.snoozeMinutes, 15)
    }
    func testNeverRetentionKeepsOldClips() {
        let store = store()
        let clip = SoundClip(date: .distantPast, fileName: "test.m4a", seconds: 3)
        store.change { $0.retentionDays = 0; $0.entries = [NightEntry(startedAt: .distantPast, endedAt: .distantPast, clips: [clip])] }
        store.cleanExpiredClips()
        XCTAssertEqual(store.data.entries.first?.clips.count, 1)
    }
    func testLegacyMoodMigrationAndMissingOptionalFields() throws {
        XCTAssertEqual(try JSONDecoder().decode(WakeMood.self, from: Data("\"rested\"".utf8)), .energized)
        XCTAssertEqual(try JSONDecoder().decode(WakeMood.self, from: Data("\"okay\"".utf8)), .neutral)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SleepData())) as! [String: Any]
        json.removeValue(forKey: "language"); json.removeValue(forKey: "nightlyAlarm")
        let data = try JSONDecoder().decode(SleepData.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(data.language)
        XCTAssertEqual(data.alarms.count, 1)
    }
    func testHealthStagesDoNotInventStagesForUnspecifiedSleep() {
        XCTAssertEqual(SleepHealthReader.stage(HKCategoryValueSleepAnalysis.asleepREM.rawValue), .rem)
        XCTAssertNil(SleepHealthReader.stage(HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue))
        XCTAssertNil(SleepHealthReader.stage(HKCategoryValueSleepAnalysis.inBed.rawValue))
    }
    func testUncertainSoundIsNotMislabelledAsSnoring() {
        XCTAssertNil(ClipClassifier.kind(identifier: "snoring", confidence: 0.4))
        XCTAssertNil(ClipClassifier.kind(identifier: "music", confidence: 0.99))
        XCTAssertEqual(ClipClassifier.kind(identifier: "snoring", confidence: 0.85), .snore)
        XCTAssertEqual(ClipClassifier.kind(identifier: "speech", confidence: 0.8), .talking)
    }
    func testBothLanguagesAndOriginalResources() {
        L10n.language = .es; XCTAssertEqual(L("Empezar la noche"), "Empezar la noche")
        L10n.language = .en; XCTAssertEqual(L("Empezar la noche"), "Start the night")
        XCTAssertEqual(WakeMood.energized.title, "Energized")
        L10n.language = .system
        for sound in AlarmSound.all { XCTAssertNotNil(SleepStore.soundURL(sound.id)) }
        let bundle = Bundle(for: SleepStore.self)
        for name in ["SunsetBackground", "NightBackground", "mood-calm", "mood-energized", "sound-wave"] {
            XCTAssertNotNil(UIImage(named: name, in: bundle, compatibleWith: nil))
        }
    }
}
