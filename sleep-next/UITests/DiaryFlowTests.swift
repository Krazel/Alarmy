import XCTest

final class DiaryFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testJournalStatisticsEnglish() { exercise(spanish:false) }
    func testJournalStatisticsSpanish() { exercise(spanish:true) }
    private func exercise(spanish:Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test","--reset-test","--archive-id",UUID().uuidString,spanish ? "--spanish" : "--english","--design-fixture","--clip-fixture","--stage-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout:10))
        app.tabBars.buttons[spanish ? "Diario" : "Journal"].tap()
        let summary = app.buttons["summary-sounds"], face = app.buttons["feeling-2"]
        XCTAssertTrue(summary.waitForExistence(timeout:5))
        XCTAssertTrue(face.isHittable,"Faces should be visible without scrolling")
        XCTAssertLessThan(app.staticTexts["night-summary-title"].frame.maxY,summary.frame.minY)
        XCTAssertLessThan(summary.frame.maxY,face.frame.minY)
        XCTAssertGreaterThan(app.textViews["journal-note"].frame.minY,face.frame.maxY)
        XCTAssertFalse(app.buttons["clip-category-other"].exists)
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
    func testInsightsEditingHabitsAndNaps() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test","--reset-test","--archive-id",UUID().uuidString,"--english","--design-fixture","--local-analysis-fixture"]
        app.launch(); XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout:10))
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.buttons["night-details"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Connect Health"].exists)
        capture("90-en-insights-diary")
        app.swipeUp()
        let habits = app.buttons["Today’s habits"]
        XCTAssertTrue(habits.waitForExistence(timeout:5)); habits.tap()
        let coffee = app.buttons["habit-lateCoffee"]
        if !coffee.isHittable {app.swipeUp()}
        XCTAssertTrue(coffee.waitForExistence(timeout:5)); coffee.tap()
        XCTAssertEqual(coffee.value as? String,"Yes")
        capture("91-en-habits")
        app.swipeDown(); app.swipeDown()
        app.buttons["night-details"].tap()
        let edit = app.buttons["edit-session"]
        XCTAssertTrue(edit.waitForExistence(timeout:5))
        if !edit.isHittable {app.swipeUp()}
        capture("92-en-night-details")
        edit.tap()
        let nap = app.switches["session-nap"]
        XCTAssertTrue(nap.waitForExistence(timeout:5))
        XCTAssertEqual(nap.value as? String,"0")
        // SwiftUI Form exposes the row as a switch; touch the trailing thumb.
        nap.coordinate(withNormalizedOffset:CGVector(dx:0.93,dy:0.5)).tap()
        let enabled = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == '1'"),object:nap)
        XCTAssertEqual(XCTWaiter.wait(for:[enabled],timeout:5),.completed)
        capture("94-en-session-editor")
        app.buttons["save-session"].tap()
        XCTAssertTrue(app.buttons["edit-session"].waitForExistence(timeout:5))
        app.buttons["Done"].tap()
        app.buttons["statistics"].tap()
        let type = app.segmentedControls["statistics-session-type"]
        XCTAssertTrue(type.waitForExistence(timeout:5)); type.buttons["Nap"].tap()
        XCTAssertTrue(app.staticTexts["statistics-sleep"].waitForExistence(timeout:5))
        let estimated = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label != %@", "—"),object:app.staticTexts["statistics-sleep"])
        XCTAssertEqual(XCTWaiter.wait(for:[estimated],timeout:10),.completed)
        capture("93-en-nap-statistics")
        app.buttons["close-statistics"].tap()
    }
    private func capture(_ name:String) {
        let attachment = XCTAttachment(screenshot:XCUIApplication().screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
