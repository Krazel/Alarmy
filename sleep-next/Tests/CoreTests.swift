import XCTest
import AVFoundation
@testable import AlarmaNext

final class DomainTests: XCTestCase {
    func testNextAlarmAlwaysFutureAtExactMinute() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 7, minute: 30))!
        let date = try XCTUnwrap(AlarmPlan().next(after: now, calendar: calendar))
        XCTAssertEqual(date.timeIntervalSince(now), 86400)
    }
    func testInvalidTimeRejected() { var plan = AlarmPlan(); plan.hour = 24; XCTAssertNil(plan.next(after: Date())) }
    func testDSTGapFindsFutureValidDate() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        var plan = AlarmPlan(); plan.hour = 2; plan.minute = 30
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 1))!
        let next = try XCTUnwrap(plan.next(after: now, calendar: calendar))
        XCTAssertGreaterThan(next, now); XCTAssertLessThan(next.timeIntervalSince(now), 86400)
    }
    func testRandomSoundAvoidsPrevious() { var plan = AlarmPlan(); plan.sounds = ["a", "b"]; for _ in 0..<50 { XCTAssertEqual(plan.sound(excluding: "a"), "b") } }
    func testEmptySelectionHasSafeSound() { var plan = AlarmPlan(); plan.sounds = []; XCTAssertEqual(plan.sound(excluding: nil), "aurora") }
    func testCalendarWeekCrossesYear() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let week = CalendarDay.week(around: day, calendar: calendar)
        XCTAssertEqual(week.count, 7); XCTAssertEqual(CalendarDay.key(week[0], calendar: calendar), "2025-12-29")
    }
    func testStorageRejectsTraversal() { XCTAssertNil(DiskLocation.child("../secret", of: URL(fileURLWithPath: "/tmp"))); XCTAssertNil(DiskLocation.child("a/b", of: URL(fileURLWithPath: "/tmp"))); XCTAssertNotNil(DiskLocation.child("clip.m4a", of: URL(fileURLWithPath: "/tmp"))) }
    func testTranslationsComplete() { for (key, values) in Words.entries { XCTAssertEqual(values.count, 2, key); XCTAssertFalse(values[0].isEmpty, key); XCTAssertFalse(values[1].isEmpty, key) }; XCTAssertEqual(Words(language: "es")("journal"), "Diario"); XCTAssertEqual(Words(language: "en")("journal"), "Journal") }
    func testSoundSuggestionsRejectLowConfidenceAndUnknownLabels() {
        XCTAssertEqual(SoundSuggestion.kind(identifier: "snoring", confidence: 0.9), .snore)
        XCTAssertEqual(SoundSuggestion.kind(identifier: "snoring", confidence: 0.4), .other)
        XCTAssertEqual(SoundSuggestion.kind(identifier: "music", confidence: 0.99), .other)
    }
    func testImportedToneIsPreparedWithinNotificationLimit() throws {
        let source = try XCTUnwrap(ToneLibrary.url("aurora", imported: []))
        let tone = try ToneLibrary.prepare(source)
        let url = try XCTUnwrap(DiskLocation.child(tone.filename, of: DiskLocation.tones))
        defer { try? FileManager.default.removeItem(at: url) }
        let audio = try AVAudioFile(forReading: url)
        XCTAssertLessThanOrEqual(Double(audio.length)/audio.processingFormat.sampleRate, 29)
        XCTAssertGreaterThan(audio.length, 0)
        XCTAssertEqual(ToneLibrary.url(tone.id, imported: [tone]), url)
    }
    func testBundledAssetsExist() { for id in ToneLibrary.builtins { XCTAssertNotNil(ToneLibrary.url(id, imported: [])) }; XCTAssertNotNil(UIImage(named: "DawnArtwork")) }
}
final class RepositoryTests: XCTestCase {
    private func location() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("archive.json") }
    func testRoundTripUnicodeJournal() async throws {
        let url = location(); let repo = ArchiveRepository(file: url)
        _ = try await repo.update { $0.pages["2026-09-05"] = JournalPage(feeling: .peaceful, text: "Un sueño junto al mar 🌙"); $0.preferences.language = "es" }
        let restored = try await ArchiveRepository(file: url).load()
        XCTAssertEqual(restored.pages["2026-09-05"]?.text, "Un sueño junto al mar 🌙"); XCTAssertEqual(restored.preferences.language, "es")
    }
    func testConcurrentMutationsDoNotLosePages() async throws {
        let repo = ArchiveRepository(file: location())
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<40 { group.addTask { _ = try await repo.update { $0.pages["\(i)"] = JournalPage(text: "\(i)") } } }
            try await group.waitForAll()
        }
        let archive = try await repo.load(); XCTAssertEqual(archive.pages.count, 40); XCTAssertEqual(archive.revision, 40)
    }
    func testCorruptArchiveIsNotOverwritten() async throws {
        let url = location(); try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data("not-json".utf8); try data.write(to: url)
        do { _ = try await ArchiveRepository(file: url).update { $0.preferences.record = true }; XCTFail("Should fail") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
    func testFailedMutationDoesNotPublish() async throws {
        let repo = ArchiveRepository(file: location()); _ = try await repo.load()
        do { _ = try await repo.update { $0.preferences.language = "es"; throw CocoaError(.fileWriteUnknown) }; XCTFail("Should fail") } catch { }
        let archive = try await repo.load(); XCTAssertEqual(archive.preferences.language, "system"); XCTAssertEqual(archive.revision, 0)
    }
    func testActiveSessionSurvivesRelaunch() async throws {
        let url = location(); let repo = ArchiveRepository(file: url); let now = Date()
        let night = SleepSession(id: UUID(), start: now, checkpoint: now, wake: now.addingTimeInterval(28800), alarmID: UUID(), soundID: "aurora")
        _ = try await repo.update { $0.active = night }
        let archive = try await ArchiveRepository(file: url).load(); XCTAssertEqual(archive.active, night)
    }
    func testRecoveryUsesCheckpointNotLaunchTime() async throws {
        let repo = ArchiveRepository(file: location()); let start = Date(timeIntervalSince1970: 1000)
        let night = SleepSession(id: UUID(), start: start, checkpoint: start.addingTimeInterval(3600), wake: start.addingTimeInterval(7200), alarmID: UUID(), soundID: "aurora")
        _ = try await repo.update { $0.active = night }; let result = try await repo.recover()
        XCTAssertNil(result.active); XCTAssertEqual(result.sessions.first?.duration, 3600); XCTAssertEqual(result.sessions.first?.interrupted, true)
    }
    func testRetentionKeepsJournalAndRemovesOnlyExpiredClips() async throws {
        let repo = ArchiveRepository(file: location()); let now = Date()
        let old = NightClip(id: UUID(), created: now.addingTimeInterval(-40*86400), filename: "missing-old.m4a", duration: 10)
        let fresh = NightClip(id: UUID(), created: now, filename: "missing-fresh.m4a", duration: 10)
        let night = SleepSession(id: UUID(), start: now, checkpoint: now, end: now, wake: now, alarmID: UUID(), soundID: "aurora", clips: [old, fresh])
        _ = try await repo.update { $0.sessions = [night]; $0.pages["day"] = JournalPage(text: "Keep me") }
        let result = try await repo.prune(now: now)
        XCTAssertEqual(result.sessions[0].clips, [fresh]); XCTAssertEqual(result.pages["day"]?.text, "Keep me")
    }
}
