import XCTest

final class AureaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMainTabsAndQuickAddOpen() throws {
        let app = launchApp()

        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
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
        XCTAssertTrue(app.staticTexts["Aggiungi"].waitForExistence(timeout: 3) || app.navigationBars["Aggiungi"].exists)
    }

    @MainActor
    func testSettingsOpenAndCoreSectionsExist() throws {
        let app = launchApp()

        let settingsButton = app.buttons["Impostazioni"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        XCTAssertTrue(app.navigationBars["Aurea"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Analisi"].exists)
        XCTAssertTrue(app.staticTexts["Gestione"].exists)

        swipeUntilVisible(app.staticTexts["Notifiche"], in: app)
        XCTAssertTrue(app.staticTexts["Notifiche"].exists)

        swipeUntilVisible(app.staticTexts["Preferenze"], in: app)
        XCTAssertTrue(app.staticTexts["Preferenze"].exists)

        swipeUntilVisible(app.staticTexts["Esportazione e backup"], in: app)
        XCTAssertTrue(app.staticTexts["Esportazione e backup"].exists)
    }

    @MainActor
    func testAgendaSearchFieldExists() throws {
        let app = launchApp()
        app.tabBars.buttons["Agenda"].tap()

        XCTAssertTrue(app.navigationBars["Agenda"].waitForExistence(timeout: 3))
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
    }

    @MainActor
    func testAssistantAcceptsAQuestion() throws {
        let app = launchApp()
        app.tabBars.buttons["Aurea"].tap()

        let field = app.textFields["Chiedi ad Aurea…"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Quanto e il mio patrimonio attuale?")
        app.buttons.matching(identifier: "arrow.up.circle.fill").firstMatch.tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "patrimonio attuale")).firstMatch.waitForExistence(timeout: 3))
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
    private func swipeUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        var attempts = 0
        while !element.exists && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }
}
