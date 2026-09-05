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
        app.buttons["Cancel"].tap()
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name; image.lifetime = .keepAlways
        add(image)
    }
}
