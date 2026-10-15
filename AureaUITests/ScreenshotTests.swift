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

        let finance = app.buttons["Centro finanziario"]
        if reveal(finance, in: app) {
            finance.tap()
            let budgets = app.buttons["Budget"].firstMatch
            if budgets.waitForExistence(timeout: 3) {
                budgets.tap()
                sleep(1)
                snapshot("08-Budget")
                let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Alimentari")).firstMatch
                if row.waitForExistence(timeout: 2) {
                    row.tap()
                    sleep(1)
                    snapshot("09-Modifica-budget")
                    app.buttons["Annulla"].firstMatch.tap()
                }
                app.navigationBars.buttons.firstMatch.tap()
            }
            let currencies = app.buttons["Valute e cambi"].firstMatch
            if currencies.waitForExistence(timeout: 3) {
                currencies.tap()
                sleep(1)
                snapshot("10-Valute")
                app.navigationBars.buttons.firstMatch.tap()
            }
            let close = app.buttons["Chiudi"].firstMatch
            if close.waitForExistence(timeout: 2) { close.tap() }
        }

        let bankImport = app.buttons["Importa movimenti dalla banca"]
        if reveal(bankImport, in: app) {
            bankImport.tap()
            if app.navigationBars["Importa dalla banca"].waitForExistence(timeout: 3) {
                sleep(1)
                snapshot("11-Import-banca")
                app.buttons["Annulla"].firstMatch.tap()
            }
        }
    }

    /// Scorre verso il basso finché l'elemento non è visibile e toccabile.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
