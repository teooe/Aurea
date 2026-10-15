import XCTest

/// Percorre le schermate principali con i dati di esempio (-DemoData) e salva uno screenshot
/// di ciascuna come allegato del risultato dei test. Il workflow "Screenshot" li estrae.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureMainScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-DemoData", "-AppleLanguages", "(it)", "-AppleLocale", "it_IT"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        sleep(1)
        snapshot("01-Home")

        app.swipeUp()
        sleep(1)
        snapshot("02-Home-sotto")

        app.tabBars.buttons["Movimenti"].tap()
        sleep(1)
        snapshot("03-Movimenti")

        app.tabBars.buttons["Analisi"].tap()
        sleep(1)
        snapshot("04-Analisi")

        let report = app.buttons["Report completo"]
        if report.waitForExistence(timeout: 3) {
            report.tap()
            sleep(2)
            snapshot("05-Report")
            app.navigationBars.buttons.firstMatch.tap()
        }

        app.tabBars.buttons["Aggiungi"].tap()
        if app.navigationBars["Nuovo movimento"].waitForExistence(timeout: 5) {
            sleep(1)
            snapshot("06-Nuovo-movimento")
            app.buttons["Annulla"].tap()
        }

        app.tabBars.buttons["Home"].tap()
        let settings = app.buttons["Impostazioni"]
        if settings.waitForExistence(timeout: 3) {
            settings.tap()
            sleep(1)
            snapshot("07-Impostazioni")
        }
    }

    @MainActor
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
