import XCTest

/// Opt-in live account smoke test. Password comes only from the runner environment.
final class StandardTestAccountUITests: XCTestCase {
    @MainActor
    func testStandardAccountsReachTheirExperiences() throws {
        continueAfterFailure = false
        guard let password = ProcessInfo.processInfo.environment["MVP_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_MVP_TEST_PASSWORD locally to run live account checks.")
        }
        let app = XCUIApplication()
        app.launch()
        func signOut() {
            let tabs = app.tabBars.firstMatch
            let account = tabs.buttons["Account"]
            for _ in 0..<3 {
                if account.exists { account.tap() } else { tabs.buttons["Profile"].tap() }
                if app.navigationBars["Profile"].waitForExistence(timeout: 5) { break }
            }
            let button = app.buttons["Sign Out"]
            for _ in 0..<6 {
                if button.waitForExistence(timeout: 2) && button.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(button.waitForExistence(timeout: 15))
            button.tap()
            XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 20))
        }
        if !app.buttons["Sign in"].waitForExistence(timeout: 10) {
            if app.buttons["Sign Out"].exists {
                app.buttons["Sign Out"].tap()
                XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 20))
            } else {
            print("INITIAL SCREEN:", app.debugDescription)
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30))
            signOut()
            }
        }
        for alias in ["parent", "child1", "child2", "provider", "admin", "athletics"] {
            let email = app.textFields["Email"]
            XCTAssertTrue(email.waitForExistence(timeout: 20))
            email.tap()
            email.typeText(alias + "@opportunity313.com")
            let passwordField = app.secureTextFields["Password"]
            passwordField.tap()
            passwordField.typeText(password)
            app.buttons["Sign in"].tap()
            let tabs = app.tabBars.firstMatch
            XCTAssertTrue(tabs.waitForExistence(timeout: 30), alias + " failed to reach dashboard")
            let systemPrompt = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Not Now"]
            if systemPrompt.waitForExistence(timeout: 2) { systemPrompt.tap() }
            if app.buttons["Not Now"].exists { app.buttons["Not Now"].tap() }
            let expectedTabs: [String]
            switch alias {
            case "parent":
                expectedTabs = ["Home", "Discover", "Children", "Calendar", "Profile"]
                let childrenShortcut = app.buttons["parentChildrenShortcut"]
                XCTAssertTrue(childrenShortcut.waitForExistence(timeout: 15))
                childrenShortcut.tap()
                XCTAssertTrue(app.navigationBars["Children"].waitForExistence(timeout: 15))
                let childLinks = app.descendants(matching: .any).matching(identifier: "managedChildLink")
                XCTAssertTrue(childLinks.firstMatch.waitForExistence(timeout: 15))
                XCTAssertGreaterThanOrEqual(childLinks.count, 2)
                XCTAssertFalse(app.staticTexts["Unable to Load Children"].exists)
            case "child1", "child2":
                expectedTabs = ["Home", "Discover", "Saved", "Calendar", "Profile"]
                let childName = alias == "child1" ? "Kevin" : "Sarai"
                XCTAssertTrue(app.staticTexts[childName].waitForExistence(timeout: 15), alias + " opened the wrong youth profile")
            case "provider":
                expectedTabs = ["Dashboard", "Opportunities", "Events", "Profile"]
            case "admin":
                expectedTabs = ["Dashboard", "Opportunities", "People", "Ticketing", "Account"]
            default:
                expectedTabs = ["Events", "Requests", "Profile"]
            }
            for label in expectedTabs { XCTAssertTrue(tabs.buttons[label].exists, alias + " missing " + label) }
            XCTAssertFalse(app.staticTexts["Unable to Load Account"].exists)
            XCTAssertFalse(app.staticTexts["Unable to Load Provider"].exists)
            let evidence = XCTAttachment(screenshot: app.screenshot())
            evidence.name = alias + " experience"
            evidence.lifetime = .keepAlways
            add(evidence)
            signOut()
        }
    }
}
