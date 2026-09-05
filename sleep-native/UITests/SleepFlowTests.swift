import XCTest

final class SleepFlowTests: XCTestCase {
    func testWelcomeAlarmEditorJournalAndSettings() {
        let app = XCUIApplication()
        app.launch()
        let welcome = app.buttons["Make tonight yours"]
        if welcome.waitForExistence(timeout: 8) {
            capture("01-welcome")
            welcome.tap()
        }
        XCTAssertTrue(app.buttons["Begin tonight"].waitForExistence(timeout: 8))
        capture("02-tonight")
        app.buttons["Add alarm"].tap()
        XCTAssertTrue(app.navigationBars["Your morning"].waitForExistence(timeout: 5))
        capture("03-alarm-editor")
        app.buttons["Cancel"].tap()
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.staticTexts["A fresh page for tomorrow."].waitForExistence(timeout: 5))
        capture("04-journal")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Record night sounds"].waitForExistence(timeout: 5))
        capture("05-settings")
        app.tabBars.buttons["Tonight"].tap()
        app.buttons["Begin tonight"].tap()
        XCTAssertTrue(app.buttons["Start my night"].waitForExistence(timeout: 5))
        capture("06-night-preparation")
        app.buttons["Start my night"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 8) { allow.tap() }
        XCTAssertTrue(app.staticTexts["Nothing to do. Just rest."].waitForExistence(timeout: 12))
        capture("07-active-night")
        app.buttons["End this night"].tap()
        app.buttons["End night"].tap()
        let night = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "night-entry-")).firstMatch
        XCTAssertTrue(night.waitForExistence(timeout: 8))
        night.tap()
        app.buttons["Rested"].tap()
        let notes = app.textViews["Dreams and notes"]
        notes.tap()
        notes.typeText("A calm start.")
        app.toolbars.buttons["Done"].tap()
        app.buttons["Save"].tap()
        app.terminate()
        app.launch()
        app.tabBars.buttons["Journal"].tap()
        let savedNight = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "night-entry-")).firstMatch
        XCTAssertTrue(savedNight.waitForExistence(timeout: 8))
        savedNight.tap()
        XCTAssertEqual(app.textViews["Dreams and notes"].value as? String, "A calm start.")
        capture("08-saved-journal-entry")
        app.buttons["Cancel"].tap()
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name; image.lifetime = .keepAlways
        add(image)
    }
}
