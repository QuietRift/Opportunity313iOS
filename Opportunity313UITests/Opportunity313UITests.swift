import XCTest

final class Opportunity313UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testLaunchResolvesExistingSessionOrShowsSignIn() {
        let app = XCUIApplication()
        app.launch()
        let resolved = NSPredicate { _, _ in
            app.buttons["Sign In"].exists || app.tabBars.firstMatch.exists ||
            app.staticTexts["Choose Your Role"].exists ||
            app.staticTexts["Unable to Load Account"].exists
        }
        expectation(for: resolved, evaluatedWith: nil)
        waitForExpectations(timeout: 30)
        XCTAssertFalse(app.staticTexts["Loading account..."].exists)
    }

    @MainActor
    func testExistingSessionCanSignOutAndOpenSignup() throws {
        let app = XCUIApplication()
        app.launch()
        if !app.buttons["Sign In"].waitForExistence(timeout: 5) {
            let tabs = app.tabBars.firstMatch
            XCTAssertTrue(tabs.waitForExistence(timeout: 30))
            let account = tabs.buttons["Account"]
            let profile = tabs.buttons["Profile"]
            if account.exists { account.tap() } else { profile.tap() }
            let signOut = app.buttons["Sign Out"]
            XCTAssertTrue(signOut.waitForExistence(timeout: 5))
            signOut.tap()
        }
        XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Sign In"].isEnabled)
        app.buttons["Create an Account"].tap()
        XCTAssertTrue(app.staticTexts["Create Your Account"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Create Account"].isEnabled)
    }
    // Credentials belong in an ignored local scheme, never in this file.
    // This test browses existing data. Write paths use rollback SQL checks.
    @MainActor
    func testConfiguredDemoAccountsReachTheirMVPFlows() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let password = environment["MVP_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("Local demo credentials are not configured.")
        }
        let app = XCUIApplication()
        app.launch()
        for role in ["youth", "parent", "provider", "admin"] {
            guard let email = environment["MVP_" + role.uppercased() + "_EMAIL"] else {
                XCTFail("Missing local demo account for " + role)
                return
            }
            XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 30))
            app.textFields["Email"].tap()
            app.textFields["Email"].typeText(email)
            app.secureTextFields["Password"].tap()
            app.secureTextFields["Password"].typeText(password)
            app.buttons["Sign In"].tap()
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30), role + " did not reach its dashboard")
            let tabs = app.tabBars.firstMatch
            switch role {
            case "youth":
                tabs.buttons["Discover"].tap()
                XCTAssertTrue(app.navigationBars["Discover"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                app.cells.firstMatch.tap()
                XCTAssertTrue(app.navigationBars["Opportunity"].waitForExistence(timeout: 10))
                tabs.buttons["Saved"].tap()
                XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 10))
                tabs.buttons["Calendar"].tap()
                XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 10))
                tabs.buttons["Profile"].tap()
            case "parent":
                tabs.buttons["Children"].tap()
                XCTAssertTrue(app.navigationBars["Children"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                app.cells.firstMatch.tap()
                XCTAssertTrue(app.staticTexts["Managed Youth Profile"].waitForExistence(timeout: 10))
                tabs.buttons["Discover"].tap()
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                tabs.buttons["Calendar"].tap()
                XCTAssertTrue(app.navigationBars["Family Calendar"].waitForExistence(timeout: 10))
                tabs.buttons["Profile"].tap()
            case "provider":
                tabs.buttons["Opportunities"].tap()
                XCTAssertTrue(app.navigationBars["Opportunities"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                tabs.buttons["Events"].tap()
                XCTAssertTrue(app.navigationBars["Events"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                tabs.buttons["Profile"].tap()
            default:
                XCTAssertTrue(app.navigationBars["Review Queue"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.staticTexts["Review Queue Clear"].waitForExistence(timeout: 15) || app.cells.firstMatch.exists)
                tabs.buttons["Account"].tap()
            }
            XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
            app.buttons["Sign Out"].tap()
            XCTAssertTrue(app.buttons["Sign In"].waitForExistence(timeout: 15))
        }
    }

}
