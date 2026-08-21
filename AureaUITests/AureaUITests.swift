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

        // Verifica che la sheet Impostazioni si sia realmente aperta.
        XCTAssertTrue(element(label: "Panoramica completa", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element(label: "Centro finanziario", in: app).exists)
        XCTAssertTrue(element(label: "Agenda completa", in: app).exists)

        // I titoli Section di SwiftUI non sono sempre esposti come elementi XCUI.
        // Verifichiamo quindi controlli interattivi reali delle sezioni successive.
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 3))

        let relationshipToggle = app.switches["Debiti e crediti"]
        scrollUntilVisible(relationshipToggle, in: table)
        XCTAssertTrue(relationshipToggle.exists)

        let completedToggle = app.switches["Mostra completati in Agenda"]
        scrollUntilVisible(completedToggle, in: table)
        XCTAssertTrue(completedToggle.exists)

        let csvButton = app.buttons["Esporta movimenti CSV"]
        scrollUntilVisible(csvButton, in: table)
        XCTAssertTrue(csvButton.exists)
    }

    @MainActor
    func testAgendaCoreControlsExist() throws {
        let app = launchApp()
        app.tabBars.buttons["Agenda"].tap()

        XCTAssertTrue(app.navigationBars["Agenda"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(label: "Oggi", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element(label: "Filtro", in: app).exists)
        XCTAssertTrue(app.datePickers.firstMatch.exists)
    }

    @MainActor
    func testAssistantScreenIsInteractive() throws {
        let app = launchApp()
        app.tabBars.buttons["Aurea"].tap()

        XCTAssertTrue(app.navigationBars["Aurea"].waitForExistence(timeout: 5))

        // Il TextField multilinea SwiftUI può essere esposto come textField o textView
        // a seconda della versione iOS. Accettiamo entrambe le rappresentazioni.
        let textField = app.textFields["Chiedi ad Aurea…"]
        let textView = app.textViews["Chiedi ad Aurea…"]
        XCTAssertTrue(textField.waitForExistence(timeout: 2) || textView.waitForExistence(timeout: 2))

        XCTAssertTrue(element(label: "Panoramica", in: app).exists)
        XCTAssertTrue(element(label: "Patrimonio", in: app).exists)
        XCTAssertTrue(element(label: "Spese mese", in: app).exists)
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
    private func scrollUntilVisible(_ element: XCUIElement, in container: XCUIElement, maxSwipes: Int = 10) {
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            container.swipeUp()
            attempts += 1
        }
    }
}
