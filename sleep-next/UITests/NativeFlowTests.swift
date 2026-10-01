import XCTest

final class NativeFlowTests: XCTestCase {
    func testClipDetailPlaybackNavigationAndCorrection() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--reset-test", "--english", "--design-fixture", "--clip-fixture"]; app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10)); app.tabBars.buttons["Journal"].tap()
        let clip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'clip-detail-'")).firstMatch
        for _ in 0..<4 { if clip.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(clip.waitForExistence(timeout: 5)); clip.tap()
        XCTAssertTrue(app.navigationBars["Listen to clip"].waitForExistence(timeout: 5)); shot("16-en-clip-detail")
        app.buttons["Play"].firstMatch.tap(); XCTAssertTrue(app.buttons["Stop"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Next"].tap(); XCTAssertTrue(app.staticTexts["2 / 2"].exists)
        app.buttons["Previous"].tap(); XCTAssertTrue(app.staticTexts["1 / 2"].exists)
        app.swipeUp(); shot("17-en-clip-intervals")
        app.buttons["correct-clip-label"].tap(); app.buttons["clip-label-cough"].tap(); XCTAssertTrue(app.buttons["correct-clip-label"].label.contains("Cough"))
        shot("18-en-clip-corrected")
        app.buttons["delete-clip"].tap(); app.sheets.buttons["Delete"].tap()
        XCTAssertTrue(app.textViews["journal-note"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'clip-detail-'")).count, 1)
    }
    func testSpanishClipDetail() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--reset-test", "--spanish", "--design-fixture", "--clip-fixture"]; app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10)); app.tabBars.buttons["Diario"].tap()
        let clip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'clip-detail-'")).firstMatch
        for _ in 0..<4 { if clip.isHittable { break }; app.swipeUp() }
        clip.tap(); XCTAssertTrue(app.navigationBars["Escuchar fragmento"].waitForExistence(timeout: 5)); shot("19-es-clip-detail")
        app.buttons["Siguiente"].tap(); XCTAssertTrue(app.staticTexts["2 / 2"].exists); app.buttons["Listo"].tap()
    }
    override func setUpWithError() throws { continueAfterFailure = false }
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testEnglishNightAndJournal() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--reset-test", "--english", "--archive-id", UUID().uuidString]; app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10)); shot("01-en-home")
        app.buttons["edit-alarm"].tap(); XCTAssertTrue(app.navigationBars["Edit alarm"].waitForExistence(timeout: 5)); shot("02-en-alarm-editor"); app.buttons["Done"].tap()
        app.buttons["sounds"].tap(); XCTAssertTrue(app.navigationBars["Sounds"].waitForExistence(timeout: 5)); shot("03-en-sounds"); app.buttons["Done"].tap()
        app.buttons["begin-night"].tap(); XCTAssertTrue(app.buttons["finish-night"].waitForExistence(timeout: 5)); shot("04-en-active-night")
        app.buttons["finish-night"].tap(); app.sheets.buttons["Finish night"].tap()
        XCTAssertTrue(app.textViews["journal-note"].waitForExistence(timeout: 5)); app.buttons["feeling-3"].tap(); shot("05-en-journal")
        app.swipeUp(); app.textViews["journal-note"].tap(); app.textViews["journal-note"].typeText("Example note: a quiet morning.")
        app.buttons["Done"].tap(); app.tabBars.buttons["Settings"].tap(); XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5)); shot("06-en-settings")
        app.tabBars.buttons["Journal"].tap(); XCTAssertEqual(app.textViews["journal-note"].value as? String, "Example note: a quiet morning.")
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10)); app.tabBars.buttons["Journal"].tap()
        XCTAssertEqual(app.textViews["journal-note"].value as? String, "Example note: a quiet morning.")
    }
    func testMicrophoneDeniedStopsNightBeforeScheduling() {
        let app=XCUIApplication(); app.launchArguments=["--reset-test"]
        app.launch(); XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout:10))
        app.switches["record-toggle"].tap(); app.buttons["begin-night"].tap()
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let deny=springboard.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'Allow' AND label != 'Allow'")).firstMatch
        if deny.waitForExistence(timeout:5) { deny.tap() }
        XCTAssertTrue(app.staticTexts["Microphone permission is off. Turn recording off or allow it in Settings."].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["finish-night"].exists)
        shot("15-microphone-denied")
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
        app.tabBars.buttons["Settings"].tap(); app.buttons["appearance"].tap(); app.buttons["Night"].tap()
        app.tabBars.buttons["Journal"].tap(); shot("13-en-journal-dark")
        app.tabBars.buttons["Alarm"].tap(); shot("14-en-home-dark")
    }
}
