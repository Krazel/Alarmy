import XCTest

final class DesignCatalogueTests: XCTestCase {
    override func setUpWithError() throws {continueAfterFailure = false}
    func testPolishedScreens() {
        for route in ["alarm-editor", "clip", "sounds", "details", "compare", "statistics"] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-test","--reset-test","--archive-id",UUID().uuidString,"--spanish","--design-fixture","--clip-fixture","--stage-fixture","--local-analysis-fixture","--gallery="+route]
            app.launch()
            XCTAssertTrue(app.otherElements["design-capture-ready"].waitForExistence(timeout:15))
            capture("actual-"+route,app)
            if route == "statistics" {
                let details = app.buttons["statistics-stage-details"]
                for _ in 0..<3 { if details.isHittable { break }; app.swipeUp() }
                details.tap()
                XCTAssertTrue(app.staticTexts["statistics-stages"].waitForExistence(timeout:5))
                app.swipeUp(); capture("actual-statistics-details",app)
            }
            app.terminate()
        }
    }
    func testAllCurrentScreens() {
        for route in ["home","home-night","alarm-editor","tones","night","ringing","active-editor","journal","calendar","statistics","details","session-editor","sounds","clip","compare","settings","examples"] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-test","--reset-test","--archive-id",UUID().uuidString,"--spanish","--design-fixture","--clip-fixture","--stage-fixture","--local-analysis-fixture","--gallery="+route]
            app.launch()
            XCTAssertTrue(app.otherElements["design-capture-ready"].waitForExistence(timeout:15),route)
            // Allow the fixture, sheets and native chart layout to settle.
            _ = app.wait(for:.runningForeground,timeout:2)
            capture("actual-"+route,app)
            if ["journal","statistics","settings","details","clip"].contains(route) {
                app.swipeUp(); capture("actual-"+route+"-more",app)
            }
            app.terminate()
        }
    }
    private func capture(_ name:String,_ app:XCUIApplication) {
        let a = XCTAttachment(screenshot:app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
