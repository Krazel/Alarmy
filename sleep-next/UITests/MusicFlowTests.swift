import XCTest

final class MusicFlowTests: XCTestCase {
    func testSpanishMusicProvidersAndLocalFallback() {check(spanish:true)}
    func testEnglishMusicProvidersAndLocalFallback() {check(spanish:false)}
    private func check(spanish:Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test","--reset-test","--archive-id",UUID().uuidString]
        if spanish {app.launchArguments.append("--spanish")}
        app.launch()
        XCTAssertTrue(app.buttons["sounds"].waitForExistence(timeout:15)); app.buttons["sounds"].tap()
        XCTAssertTrue(app.buttons["Apple Music"].exists)
        XCTAssertTrue(app.buttons["Spotify"].exists); app.buttons["Spotify"].tap()
        XCTAssertTrue(app.staticTexts["spotify-pending"].waitForExistence(timeout:5))
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = spanish ? "music-es-pending" : "music-en-pending"; attachment.lifetime = .keepAlways; add(attachment)
        app.navigationBars.buttons.element(boundBy:0).tap()
        XCTAssertTrue(app.otherElements["tone-selection-mode"].exists || app.buttons["tone-selection-mode"].exists)
        let sound = XCTAttachment(screenshot:app.screenshot()); sound.name = spanish ? "music-es-sources" : "music-en-sources"; sound.lifetime = .keepAlways; add(sound)
        app.terminate()
    }
}
