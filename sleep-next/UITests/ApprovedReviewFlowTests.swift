import XCTest

final class ApprovedReviewFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(spanish: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test", "--reset-test", "--archive-id", UUID().uuidString, spanish ? "--spanish" : "--english", "--design-fixture", "--clip-fixture", "--stage-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10))
        return app
    }
    func testAlarmDraftCancellationAndSaveWithoutLight() {
        let app = launch(spanish: true)
        app.buttons["edit-alarm"].tap()
        XCTAssertTrue(app.buttons["alarm-mode-analysis"].waitForExistence(timeout: 5))
        app.buttons["alarm-mode-analysis"].tap()
        app.buttons["Cancelar"].tap()
        app.buttons["edit-alarm"].tap()
        XCTAssertTrue(app.buttons["alarm-mode-exact"].isSelected)
        app.buttons["alarm-mode-analysis"].tap()
        app.buttons["save-alarm"].tap()
        app.buttons["edit-alarm"].tap()
        XCTAssertTrue(app.buttons["alarm-mode-analysis"].isSelected)
        XCTAssertFalse(app.staticTexts["Luz gradual"].exists)
        app.buttons["Cancelar"].tap()
    }
    func testSpanishDiaryCategoriesAndStatistics() { exercise(spanish: true) }
    func testEnglishDiaryCategoriesAndStatistics() { exercise(spanish: false) }
    private func exercise(spanish: Bool) {
        let app = launch(spanish: spanish)
        app.tabBars.buttons[spanish ? "Diario" : "Journal"].tap()
        let summary = app.buttons["summary-sounds"], face = app.buttons["feeling-2"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(face.isHittable)
        XCTAssertLessThan(summary.frame.maxY, face.frame.minY)
        XCTAssertGreaterThan(app.textViews["journal-note"].frame.minY, face.frame.maxY)
        summary.tap()
        let cough = app.buttons["clip-category-cough"]
        XCTAssertTrue(cough.waitForExistence(timeout: 5)); cough.tap()
        XCTAssertTrue(app.staticTexts["clip-position"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["clip-position"].label, "1 / 16")
        XCTAssertFalse(app.buttons["previous-clip"].isEnabled)
        app.buttons["next-clip"].tap()
        XCTAssertEqual(app.staticTexts["clip-position"].label, "2 / 16")
        app.buttons["close-clip"].tap(); app.buttons["close-sounds"].tap()
        app.buttons["statistics"].tap()
        XCTAssertTrue(app.staticTexts["statistics-sleep"].waitForExistence(timeout: 5))
        let stages = app.buttons["statistics-stage-details"]
        for _ in 0..<3 { if stages.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(stages.isHittable); stages.tap()
        XCTAssertTrue(app.staticTexts["statistics-stages"].waitForExistence(timeout: 5))
    }
}
