import XCTest

final class NativeFlowTests: XCTestCase {
    func testFeedbackJournalAndStorageEnglish() { feedbackJournalAndStorage(spanish:false) }
    func testFeedbackJournalAndStorageSpanish() { feedbackJournalAndStorage(spanish:true) }
    private func feedbackJournalAndStorage(spanish: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test","--reset-test","--archive-id",UUID().uuidString,spanish ? "--spanish" : "--english","--design-fixture","--clip-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout:10))
        XCTAssertFalse(app.switches["record-toggle"].exists)
        let settings = spanish ? "Ajustes" : "Settings", journal = spanish ? "Diario" : "Journal"
        app.tabBars.buttons[journal].tap()
        let note = app.textViews["journal-note"]
        XCTAssertTrue(note.waitForExistence(timeout:5))
        XCTAssertGreaterThan(note.frame.minY,app.buttons["feeling-2"].frame.maxY)
        let summary = app.buttons["summary-sounds"]
        XCTAssertLessThan(note.frame.maxY,summary.frame.minY)
        shot(spanish ? "60-es-journal-note" : "63-en-journal-note")
        for _ in 0..<5 { if summary.isHittable { break }; app.swipeUp() }
        XCTAssertEqual(summary.value as? String,"30")
        summary.tap()
        let category = app.buttons["clip-category-cough"]
        let visible = XCTNSPredicateExpectation(predicate:NSPredicate(format:"hittable == true"),object:category)
        XCTAssertEqual(XCTWaiter.wait(for:[visible],timeout:5),.completed)
        shot(spanish ? "61-es-sound-categories" : "64-en-sound-categories")
        app.tabBars.buttons[settings].tap()
        let toggle = app.switches["record-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout:5))
        XCTAssertEqual(toggle.value as? String,"0")
        // Form exposes the whole row as a switch; tap the actual thumb at its trailing edge.
        toggle.coordinate(withNormalizedOffset:CGVector(dx:0.93,dy:0.5)).tap()
        let enabled = XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == '1'"),object:toggle)
        XCTAssertEqual(XCTWaiter.wait(for:[enabled],timeout:5),.completed)
        XCTAssertFalse(app.switches[spanish ? "Analizar sonidos durante la noche" : "Analyse sounds overnight"].exists)
        let erase = app.buttons["delete-all-recordings"]
        for _ in 0..<5 { if erase.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.staticTexts["recording-storage-size"].waitForExistence(timeout:5))
        let ready = XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:erase)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:5),.completed)
        shot(spanish ? "62-es-storage" : "65-en-storage")
        erase.tap(); app.buttons[spanish ? "Cancelar" : "Cancel"].tap()
        XCTAssertTrue(erase.isEnabled)
        erase.tap(); let confirm = app.buttons["confirm-delete-all-recordings"]; XCTAssertTrue(confirm.waitForExistence(timeout:5)); confirm.tap()
        let empty = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label BEGINSWITH '0 '"),object:app.staticTexts["recording-storage-count"])
        XCTAssertEqual(XCTWaiter.wait(for:[empty],timeout:10),.completed)
        XCTAssertFalse(erase.isEnabled)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout:10))
        app.tabBars.buttons[settings].tap(); XCTAssertEqual(app.switches["record-toggle"].value as? String,"1")
        app.tabBars.buttons[journal].tap()
        XCTAssertTrue((app.textViews["journal-note"].value as? String)?.contains("Ejemplo de diseño") == true)
        for _ in 0..<5 { if app.buttons["summary-sounds"].isHittable { break }; app.swipeUp() }
        XCTAssertEqual(app.buttons["summary-sounds"].value as? String,"30")
    }
    func testMinimalNightAndInlineAlarmEnglish() { exerciseInlineAlarm(spanish:false) }
    func testMinimalNightAndInlineAlarmSpanishSmart() { exerciseInlineAlarm(spanish:true) }
    private func exerciseInlineAlarm(spanish: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test","--reset-test",spanish ? "--spanish" : "--english","--night-wave-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["edit-alarm"].waitForExistence(timeout:10))
        if spanish {
            app.buttons["edit-alarm"].tap(); app.buttons["Ventana inteligente"].tap(); app.buttons["Listo"].tap()
        }
        let start = app.buttons["begin-night"]
        for _ in 0..<4 { if start.isHittable { break }; app.swipeUp() }
        start.tap()
        let alarm = app.buttons["night-edit-alarm"]
        XCTAssertTrue(alarm.waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["night-current-time"].exists)
        XCTAssertFalse(app.buttons["pause-capture"].exists)
        XCTAssertTrue(app.staticTexts[spanish ? "Parar" : "Stop"].exists)
        shot(spanish ? "50-es-onda-night" : "53-en-onda-night")
        alarm.tap()
        XCTAssertTrue(app.buttons["save-active-alarm"].waitForExistence(timeout:5))
        let minutes = app.pickerWheels.element(boundBy:1)
        XCTAssertTrue(minutes.waitForExistence(timeout:5)); minutes.adjust(toPickerWheelValue:"45")
        // Let the wheel's native settling animation finish before taking its visual reference.
        Thread.sleep(forTimeInterval:0.8)
        shot(spanish ? "51-es-edit-active-alarm" : "54-en-edit-active-alarm")
        app.buttons["save-active-alarm"].tap()
        let changed = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS ':45'"),object:alarm)
        XCTAssertEqual(XCTWaiter.wait(for:[changed],timeout:10),.completed)
        XCTAssertTrue(alarm.isHittable)
        shot(spanish ? "52-es-onda-updated" : "55-en-onda-updated")
        let after = alarm.label
        alarm.tap(); XCTAssertTrue(app.buttons["cancel-active-alarm"].waitForExistence(timeout:5))
        app.pickerWheels.element(boundBy:1).adjust(toPickerWheelValue:"15")
        app.buttons["cancel-active-alarm"].tap()
        XCTAssertEqual(alarm.label,after)
        let slider = app.descendants(matching:.any).matching(identifier:"finish-night").firstMatch
        slider.tap(); XCTAssertTrue(alarm.exists)
        let bottom = slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.8))
        bottom.press(forDuration:0.1,thenDragTo:slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.6)))
        XCTAssertTrue(alarm.exists)
        bottom.press(forDuration:0.1,thenDragTo:slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.05)))
        XCTAssertTrue(app.buttons["statistics"].waitForExistence(timeout:5))
    }
    func testEnglishExactNightAndAnalysisDiary() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test","--reset-test","--english","--design-fixture"]; app.launch()
        let start = app.buttons["begin-night"]
        XCTAssertTrue(start.waitForExistence(timeout:10))
        for _ in 0..<4 { if start.isHittable {break}; app.swipeUp() }
        start.tap()
        let slider = app.descendants(matching:.any).matching(identifier:"finish-night").firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout:5)); shot("35-en-exact-night")
        slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.8)).press(forDuration:0.1,thenDragTo:slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.05)))
        XCTAssertTrue(app.buttons["statistics"].waitForExistence(timeout:5)); shot("36-en-diary")
        app.swipeUp(); app.swipeUp(); shot("37-en-night-analysis")
    }
    func testNightModesSwipeAndStatistics() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test","--reset-test","--spanish","--design-fixture"]; app.launch()
        XCTAssertTrue(app.buttons["edit-alarm"].waitForExistence(timeout:10))
        app.buttons["edit-alarm"].tap()
        app.buttons["Sin alarma"].tap(); shot("30-es-analysis-mode")
        app.buttons["Listo"].tap()
        let start = app.buttons["begin-night"]
        for _ in 0..<4 { if start.isHittable {break}; app.swipeUp() }
        start.tap()
        let slider = app.descendants(matching:.any).matching(identifier:"finish-night").firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout:5)); shot("31-es-analysis-night")
        let bottom = slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.8))
        bottom.press(forDuration:0.1,thenDragTo:slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.6)))
        XCTAssertTrue(slider.exists)
        bottom.press(forDuration:0.1,thenDragTo:slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.05)))
        XCTAssertTrue(app.buttons["statistics"].waitForExistence(timeout:5))
        app.buttons["statistics"].tap(); XCTAssertTrue(app.navigationBars["Estadísticas"].waitForExistence(timeout:5)); shot("32-es-statistics")
        app.buttons["Listo"].tap()
        app.tabBars.buttons["Alarma"].tap()
        for _ in 0..<3 { if app.buttons["edit-alarm"].isHittable {break}; app.swipeDown() }
        app.buttons["edit-alarm"].tap(); app.buttons["Ventana inteligente"].tap(); shot("33-es-smart-mode")
        app.buttons["Listo"].tap()
        for _ in 0..<4 { if start.isHittable {break}; app.swipeUp() }
        start.tap(); XCTAssertTrue(slider.waitForExistence(timeout:5)); shot("34-es-smart-night")
        slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.8)).press(forDuration:0.1,thenDragTo:slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.05)))
        XCTAssertTrue(app.buttons["statistics"].waitForExistence(timeout:5))
    }
    func testJournalExamplesAndMoodCalendar() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--reset-test", "--spanish", "--design-fixture"]; app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ajustes"].tap()
        let mode = app.switches["developer-mode"]
        for _ in 0..<6 { if mode.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(mode.isHittable)
        // SwiftUI exposes this form row as one Switch; its centre is the label.
        // Hit the actual native switch on the trailing side of the observed row.
        if mode.value as? String != "1" { mode.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertEqual(mode.value as? String, "1")
        shot("24-es-developer-mode-enabled")
        app.tabBars.buttons["Diario"].tap()
        let examples = app.buttons["journal-examples"]
        XCTAssertTrue(examples.waitForExistence(timeout: 5)); examples.tap()
        XCTAssertTrue(app.buttons["example-scenario"].waitForExistence(timeout: 5)); shot("21-es-journal-examples")
        app.buttons["example-calendar"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar-day-'")).firstMatch.waitForExistence(timeout: 5))
        shot("22-es-mood-calendar")
        app.buttons["close-journal-calendar"].tap()
        app.buttons["close-journal-examples"].tap()
        XCTAssertTrue(app.buttons["feeling-3"].waitForExistence(timeout: 5))
        for _ in 0..<3 { if app.textViews["journal-note"].isHittable { break }; app.swipeUp() }
        XCTAssertTrue(app.textViews["journal-note"].value as? String == "Ejemplo de diseño: una mañana tranquila, luz en la ventana y un sueño junto al mar.")
        shot("23-es-journal-mood-week")
    }
    func testCompactNightControls() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--reset-test", "--spanish"]; app.launch()
        let start = app.buttons["begin-night"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        for _ in 0..<3 { if start.isHittable { break }; app.swipeUp() }
        start.tap()
        let end = app.descendants(matching:.any).matching(identifier:"finish-night").firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        for _ in 0..<3 { if end.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(end.isHittable); shot("20-es-compact-night-controls")
        end.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.8)).press(forDuration:0.1,thenDragTo:end.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.05)))
        XCTAssertTrue(app.textViews["journal-note"].waitForExistence(timeout: 5))
    }
    func testClipDetailPlaybackNavigationAndCorrection() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--reset-test", "--english", "--design-fixture", "--clip-fixture"]; app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10)); app.tabBars.buttons["Journal"].tap()
        let cough = app.buttons["clip-category-cough"]
        reveal(cough, in: app)
        XCTAssertEqual(cough.value as? String, "16 saved clips")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'clip-category-'")).count, 5)
        shot("40-en-sound-categories"); cough.tap()
        XCTAssertTrue(app.navigationBars["Cough"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["clip-position"].label, "1 / 16")
        XCTAssertFalse(app.buttons["previous-clip"].isEnabled)
        app.buttons["Play"].firstMatch.tap(); XCTAssertTrue(app.buttons["Stop"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["next-clip"].tap(); XCTAssertEqual(app.staticTexts["clip-position"].label, "2 / 16")
        XCTAssertTrue(app.buttons["Play"].firstMatch.exists)
        XCTAssertFalse(app.buttons["Stop"].firstMatch.exists)
        app.buttons["previous-clip"].tap(); shot("41-en-category-player")
        reveal(app.buttons["correct-clip-label"], in: app)
        app.buttons["correct-clip-label"].tap(); app.buttons["clip-label-snore"].tap()
        // Correcting a label moves that recording out of this category and keeps
        // its next neighbour open, instead of leaving an empty detail screen.
        XCTAssertTrue(app.buttons["correct-clip-label"].label.contains("Cough"))
        reveal(app.buttons["delete-clip"], in: app)
        app.buttons["delete-clip"].tap(); app.sheets.buttons["Delete"].tap()
        for _ in 0..<5 { if app.buttons["previous-clip"].isHittable { break }; app.swipeDown() }
        XCTAssertEqual(app.staticTexts["clip-position"].label, "1 / 14")
        app.buttons["Done"].tap(); reveal(cough, in: app)
        XCTAssertEqual(cough.value as? String, "14 saved clips")
        XCTAssertEqual(app.buttons["clip-category-snore"].value as? String, "8 saved clips")
        // Deleting a category's last clip returns to the diary and removes it.
        let other = app.buttons["clip-category-other"]; reveal(other, in: app); other.tap()
        XCTAssertTrue(app.navigationBars["Unlabelled"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["next-clip"].isEnabled)
        reveal(app.buttons["delete-clip"], in: app)
        app.buttons["delete-clip"].tap(); app.sheets.buttons["Delete"].tap()
        XCTAssertTrue(cough.waitForExistence(timeout: 5))
        XCTAssertFalse(other.exists)
    }
    func testSpanishClipDetail() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test", "--reset-test", "--spanish", "--design-fixture", "--clip-fixture", "--night-fixture"]; app.launch()
        XCTAssertTrue(app.buttons["begin-night"].waitForExistence(timeout: 10)); app.tabBars.buttons["Diario"].tap()
        let cough = app.buttons["clip-category-cough"]; reveal(cough, in: app)
        XCTAssertEqual(cough.value as? String, "16 fragmentos guardados"); shot("42-es-night-categories")
        cough.tap(); XCTAssertTrue(app.navigationBars["Tos"].waitForExistence(timeout: 5))
        app.buttons["next-clip"].tap(); XCTAssertEqual(app.staticTexts["clip-position"].label, "2 / 16"); shot("43-es-night-category-player")
        for _ in 0..<14 { app.buttons["next-clip"].tap() }
        XCTAssertEqual(app.staticTexts["clip-position"].label, "16 / 16")
        XCTAssertFalse(app.buttons["next-clip"].isEnabled)
        app.buttons["Listo"].tap()
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 { if element.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
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
        app.buttons["begin-night"].tap(); XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"finish-night").firstMatch.waitForExistence(timeout: 5)); shot("04-en-active-night")
        let slider = app.descendants(matching:.any).matching(identifier:"finish-night").firstMatch; slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.8)).press(forDuration:0.1,thenDragTo:slider.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.05)))
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
        app.tabBars.buttons["Settings"].tap(); app.switches["record-toggle"].tap(); app.tabBars.buttons["Alarm"].tap(); app.buttons["begin-night"].tap()
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let deny=springboard.buttons.matching(NSPredicate(format:"label CONTAINS[c] 'Allow' AND label != 'Allow'")).firstMatch
        if deny.waitForExistence(timeout:5) { deny.tap() }
        XCTAssertTrue(app.staticTexts["Microphone permission is off. Turn off sound analysis or allow the microphone in Settings."].waitForExistence(timeout:5))
        XCTAssertFalse(app.descendants(matching:.any).matching(identifier:"finish-night").firstMatch.exists)
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
