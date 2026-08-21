import XCTest

final class AureaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMainTabsAndQuickAddOpen() throws {
        let app = launchApp()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.buttons["Movimenti"].exists)
        XCTAssertTrue(app.tabBars.buttons["Aggiungi"].exists)
        XCTAssertTrue(app.tabBars.buttons["Agenda"].exists)
        XCTAssertTrue(app.tabBars.buttons["Aurea"].exists)

        app.tabBars.buttons["Movimenti"].tap()
        XCTAssertTrue(app.navigationBars["Movimenti"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Agenda"].tap()
        XCTAssertTrue(app.navigationBars["Agenda"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Aurea"].tap()
        XCTAssertTrue(app.navigationBars["Aurea"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Home"].tap()
        app.tabBars.buttons["Aggiungi"].tap()

        // Verifichiamo il contenuto della sheet invece del tipo esatto di navigation bar,
        // che può cambiare nell'albero XCUI con SwiftUI.
        XCTAssertTrue(element(label: "Movimento", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element(label: "Impegno", in: app).exists)
        XCTAssertTrue(element(label: "Portafoglio", in: app).exists)
    }

    @MainActor
    func testSettingsOpenAndCoreSectionsExist() throws {
        let app = launchApp()

        let settingsButton = app.buttons["Impostazioni"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // "Panoramica completa" è un controllo reale e stabile nella prima sezione.
        XCTAssertTrue(element(label: "Panoramica completa", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element(label: "Centro finanziario", in: app).exists)
        XCTAssertTrue(element(label: "Agenda completa", in: app).exists)

        let notifications = element(label: "Notifiche", in: app)
        swipeUntilVisible(notifications, in: app)
        XCTAssertTrue(notifications.exists)

        let preferences = element(label: "Preferenze", in: app)
        swipeUntilVisible(preferences, in: app)
        XCTAssertTrue(preferences.exists)

        let backup = element(label: "Esportazione e backup", in: app)
        swipeUntilVisible(backup, in: app)
        XCTAssertTrue(backup.exists)
    }

    @MainActor
    func testAgendaSearchFieldExists() throws {
        let app = launchApp()
        app.tabBars.buttons["Agenda"].tap()

        XCTAssertTrue(app.navigationBars["Agenda"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 3))
    }

    @MainActor
    func testAssistantAcceptsAQuestion() throws {
        let app = launchApp()
        app.tabBars.buttons["Aurea"].tap()

        let field = app.textFields["Chiedi ad Aurea…"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Quanto e il mio patrimonio attuale?")

        // Il pulsante SF Symbol non ha sempre un identifier XCUI stabile.
        // Invio tramite Return, dato che il TextField usa submitLabel(.send) e onSubmit.
        field.typeText("\n")

        // Se la domanda è stata accettata, compare almeno il messaggio utente nella conversazione.
        let sentQuestion = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Quanto e il mio patrimonio")
        ).firstMatch
        XCTAssertTrue(sentQuestion.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-UITesting"]
            app.launch()
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
        app.launch()
        return app
    }

    @MainActor
    private func element(label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    @MainActor
    private func swipeUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }
}
