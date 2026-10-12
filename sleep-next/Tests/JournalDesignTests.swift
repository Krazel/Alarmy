import XCTest
@testable import AlarmaNext

final class JournalDesignTests: XCTestCase {
    func testDefaultRetentionAndSavedChoices() throws {
        XCTAssertEqual(Preferences().keepDays, 90)
        var existing = Preferences(); existing.keepDays = 30
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(existing))
        XCTAssertEqual(restored.keepDays, 30)
        existing.keepDays = 0
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(existing)).keepDays, 0)
    }
    func testMonthLayoutCrossesYearAndLeapFebruary() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let october = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12)))
        let cells = CalendarDay.month(around: october, calendar: calendar)
        XCTAssertEqual(cells.count, 35); XCTAssertEqual(cells.compactMap { $0 }.count, 31)
        XCTAssertNil(cells[2]); XCTAssertEqual(CalendarDay.key(try XCTUnwrap(cells[3]), calendar: calendar), "2026-10-01")
        let leap = try XCTUnwrap(calendar.date(from: DateComponents(year: 2028, month: 2, day: 1)))
        XCTAssertEqual(CalendarDay.month(around: leap, calendar: calendar).compactMap { $0 }.count, 29)
        let january = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))
        XCTAssertEqual(CalendarDay.key(try XCTUnwrap(CalendarDay.month(around: january, calendar: calendar)[4]), calendar: calendar), "2027-01-01")
    }
    func testExamplesCoverFeelingsClipsAndGapsWithoutActiveAlarm() throws {
        let words = Words(language: "es")
        for scenario in JournalScenario.allCases {
            let (value, day) = scenario.archive(words: words)
            XCTAssertNil(value.active)
            XCTAssertFalse(value.preferences.record); XCTAssertFalse(value.preferences.health)
            XCTAssertTrue(value.sessions.allSatisfy { $0.end! < Date() })
            if scenario == .empty {
                XCTAssertNil(value.pages[CalendarDay.key(day)])
                XCTAssertFalse(value.sessions.contains { Calendar.current.isDate($0.end!, inSameDayAs: day) })
            }
        }
        let (week, _) = JournalScenario.variedWeek.archive(words: words)
        XCTAssertEqual(Set(week.pages.values.compactMap { $0.feeling?.rawValue }), Set(0..<5))
        let (sounds, _) = JournalScenario.sounds.archive(words: words)
        XCTAssertEqual(Set(sounds.sessions[0].clips.map { $0.kind }), Set(SoundKind.allCases))
        XCTAssertEqual(sounds.sessions[0].clips.count, 30)
        XCTAssertEqual(sounds.sessions[0].clips.filter { $0.kind == .cough }.count, 16)
        XCTAssertTrue(sounds.sessions[0].clips.allSatisfy { $0.created >= sounds.sessions[0].start && $0.created < sounds.sessions[0].end! })
        let (interrupted, _) = JournalScenario.interrupted.archive(words: words)
        XCTAssertEqual(interrupted.sessions[0].captureSpans?.count, 2)
    }
}

@MainActor
final class JournalPreviewIsolationTests: XCTestCase {
    func testPreviewEditingDeletionAndPruningLeaveRepositoryUntouched() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = ArchiveRepository(file: folder.appendingPathComponent("archive.json"), clipsDirectory: folder)
        let real = try await repository.update { $0.pages["real"] = JournalPage(feeling: .bright, text: "Keep my real night") }
        let preview = SleepStore(repository: repository, journalPreview: true)
        let (examples, day) = JournalScenario.sounds.archive(words: Words(language: "en"))
        preview.archive = examples; preview.selectedDay = day
        let clip = try XCTUnwrap(preview.sessions(day).first?.clips.first)
        let sentinel = folder.appendingPathComponent(clip.filename)
        try Data("untouched".utf8).write(to: sentinel)
        await preview.load()
        preview.note("Only an example edit", day: day); preview.feeling(.peaceful, day: day)
        await preview.analyze(clip); await preview.prune(); await preview.start()
        let deleted = await preview.delete(clip)
        XCTAssertTrue(deleted)
        let reread = try await repository.load()
        XCTAssertEqual(reread, real)
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("untouched".utf8))
        XCTAssertEqual(preview.page(day).text, "Only an example edit")
        XCTAssertNil(preview.archive.active)
        XCTAssertNil(preview.writeTail)
    }
}
