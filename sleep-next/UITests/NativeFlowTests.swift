import XCTest

final class NativeFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testEnglishNightAndJournal() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--reset-test", "--english"]; app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10)); shot("01-en-home")
        app.buttons["edit-alarm"].tap(); XCTAssertTrue(app.navigationBars["Edit alarm"].waitForExistence(timeout: 5)); shot("02-en-alarm-editor"); app.buttons["Done"].tap()
        app.buttons["sounds"].tap(); XCTAssertTrue(app.navigationBars["Sounds"].waitForExistence(timeout: 5)); shot("03-en-sounds"); app.buttons["Done"].tap()
        app.buttons["begin-night"].tap(); XCTAssertTrue(app.buttons["finish-night"].waitForExistence(timeout: 5)); shot("04-en-active-night")
        app.buttons["finish-night"].tap(); app.buttons["Finish night"].tap()
        XCTAssertTrue(app.textViews["journal-note"].waitForExistence(timeout: 5)); app.buttons["feeling-3"].tap(); shot("05-en-journal")
        app.swipeUp(); app.textViews["journal-note"].tap(); app.textViews["journal-note"].typeText("Example note: a quiet morning.")
        app.swipeDown(); app.tabBars.buttons["Settings"].tap(); XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5)); shot("06-en-settings")
        app.tabBars.buttons["Journal"].tap(); XCTAssertEqual(app.textViews["journal-note"].value as? String, "Example note: a quiet morning.")
    }
    func testSpanishDiaryDesign() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--reset-test", "--spanish", "--design-fixture"]; app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10)); shot("07-es-home")
        app.tabBars.buttons["Diario"].tap(); XCTAssertTrue(app.buttons["feeling-3"].waitForExistence(timeout: 5)); shot("08-es-journal-design")
        app.swipeUp(); shot("09-es-journal-notes")
        app.swipeDown(); app.buttons["calendar"].tap(); shot("10-es-calendar"); app.buttons["Listo"].tap()
        app.tabBars.buttons["Ajustes"].tap(); shot("11-es-settings")
        app.buttons["language"].tap(); app.buttons["English"].tap()
        XCTAssertTrue(app.tabBars.buttons["Journal"].waitForExistence(timeout: 5)); app.tabBars.buttons["Journal"].tap(); shot("12-en-journal-design")
    }
}
