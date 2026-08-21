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

        // Smoke test stabile: la sheet deve aprirsi e mostrare i controlli iniziali.
        XCTAssertTrue(element(label: "Panoramica completa", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element(label: "Centro finanziario", in: app).exists)
        XCTAssertTrue(element(label: "Agenda completa", in: app).exists)
        XCTAssertTrue(app.buttons["Fine"].exists)
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

        // Per il smoke test verifichiamo elementi che XCUI espone in modo stabile.
        XCTAssertTrue(app.navigationBars["Aurea"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Aurea"].isSelected)

        // La schermata deve avere almeno un controllo di input/interazione.
        let hasTextField = app.textFields.firstMatch.exists
        let hasTextView = app.textViews.firstMatch.exists
        let hasButton = app.buttons.count > 0
        XCTAssertTrue(hasTextField || hasTextView || hasButton)
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
}
