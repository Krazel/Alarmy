import XCTest

final class DiaryFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testJournalStatisticsEnglish() { exercise(spanish:false) }
    func testJournalStatisticsSpanish() { exercise(spanish:true) }
    private func exercise(spanish:Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test","--reset-test","--archive-id",UUID().uuidString,spanish ? "--spanish" : "--english","--design-fixture","--clip-fixture","--health-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout:10))
        app.tabBars.buttons[spanish ? "Diario" : "Journal"].tap()
        let summary = app.buttons["summary-sounds"], face = app.buttons["feeling-2"]
        XCTAssertTrue(summary.waitForExistence(timeout:5))
        XCTAssertTrue(face.isHittable,"Faces should be visible without scrolling")
        XCTAssertLessThan(app.staticTexts["night-summary-title"].frame.maxY,summary.frame.minY)
        XCTAssertLessThan(summary.frame.maxY,face.frame.minY)
        XCTAssertGreaterThan(app.textViews["journal-note"].frame.minY,face.frame.maxY)
        XCTAssertFalse(app.buttons["clip-category-cough"].exists)
        XCTAssertLessThan(app.buttons["statistics"].frame.maxX,app.buttons["calendar"].frame.midX)
        capture(spanish ? "70-es-diary" : "75-en-diary")
        summary.tap()
        let cough = app.buttons["clip-category-cough"]
        XCTAssertTrue(cough.waitForExistence(timeout:5))
        XCTAssertEqual(cough.value as? String,spanish ? "16 fragmentos guardados" : "16 saved clips")
        cough.tap()
        XCTAssertEqual(app.staticTexts["sound-position"].label,"1 / 16")
        XCTAssertFalse(app.buttons["sound-previous"].isEnabled)
        XCTAssertEqual(app.staticTexts["sound-duration"].label,"00:24")
        app.buttons["sound-next"].tap()
        XCTAssertEqual(app.staticTexts["sound-position"].label,"2 / 16")
        app.buttons["clip-category-snore"].tap()
        XCTAssertEqual(app.staticTexts["sound-position"].label,"1 / 7")
        capture(spanish ? "71-es-sounds" : "76-en-sounds")
        app.buttons["close-sounds"].tap()
        app.buttons["statistics"].tap()
        XCTAssertTrue(app.staticTexts["statistics-sleep"].waitForExistence(timeout:5))
        XCTAssertNotEqual(app.staticTexts["statistics-sleep"].label,"—")
        capture(spanish ? "72-es-statistics" : "77-en-statistics")
        let picker = app.segmentedControls["statistics-period"]
        picker.buttons.element(boundBy:1).tap(); picker.buttons.element(boundBy:3).tap(); picker.buttons.element(boundBy:0).tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["statistics-stages"].exists)
        capture(spanish ? "73-es-stages" : "78-en-stages")
        let sounds = app.buttons["statistics-sounds"]
        for _ in 0..<4 { if sounds.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(sounds.isHittable); sounds.tap()
        XCTAssertTrue(app.buttons["clip-category-cough"].waitForExistence(timeout:5))
        app.buttons["close-sounds"].tap(); app.buttons["close-statistics"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout:5))
    }
    func testMissingHealthAndNightTheme() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test","--reset-test","--archive-id",UUID().uuidString,"--english","--design-fixture","--night-fixture"]
        app.launch(); XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout:10))
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["feeling-2"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["feeling-2"].isHittable)
        capture("79-en-diary-night-no-health")
        app.buttons["summary-sounds"].tap()
        XCTAssertFalse(app.buttons["clip-category-cough"].exists)
        app.buttons["close-sounds"].tap(); app.buttons["statistics"].tap()
        XCTAssertTrue(app.staticTexts["statistics-sleep"].waitForExistence(timeout:5))
        XCTAssertEqual(app.staticTexts["statistics-sleep"].label,"—")
        capture("80-en-statistics-no-health")
    }
    private func capture(_ name:String) {
        let attachment = XCTAttachment(screenshot:XCUIApplication().screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
