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
        addUIInterruptionMonitor(withDescription: "Password saving") { alert in
            let notNow = alert.buttons["Not Now"]
            guard notNow.exists else { return false }
            notNow.tap()
            return true
        }
        app.launch()
        if !app.buttons["Sign In"].waitForExistence(timeout: 5) {
            let tabs = app.tabBars.firstMatch
            XCTAssertTrue(tabs.waitForExistence(timeout: 30))
            let account = tabs.buttons["Account"]
            if account.exists { account.tap() } else { tabs.buttons["Profile"].tap() }
            XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
            app.buttons["Sign Out"].tap()
        }
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
            let passwordPrompt = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Not Now"]
            if passwordPrompt.waitForExistence(timeout: 5) { passwordPrompt.tap() }
            let appPrompt = app.buttons["Not Now"]
            if appPrompt.waitForExistence(timeout: 5) { appPrompt.tap() }
            let loadError = app.alerts["Unable to Update Saved Opportunity"]
            if loadError.waitForExistence(timeout: 5) {
                XCTFail(loadError.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " "))
            }
            let evidence = XCTAttachment(screenshot: app.screenshot())
            evidence.name = role + " dashboard"
            evidence.lifetime = .keepAlways
            add(evidence)
            let tabs = app.tabBars.firstMatch
            switch role {
            case "youth":
                let seeMore = app.buttons["seeMoreRecommendations"]
                XCTAssertTrue(seeMore.waitForExistence(timeout: 15))
                seeMore.tap()
                XCTAssertTrue(app.navigationBars["Discover"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.segmentedControls["discoveryMode"].buttons["Recommended for You"].isSelected)
                app.segmentedControls["discoveryMode"].buttons["All Opportunities"].tap()
                XCTAssertTrue(app.buttons["All"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.buttons["All"].isHittable)
                XCTAssertTrue(app.navigationBars["Discover"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                let link = app.descendants(matching: .any).matching(identifier: "discoverOpportunityLink").firstMatch
                XCTAssertTrue(link.waitForExistence(timeout: 10))
                link.tap()
                XCTAssertTrue(app.navigationBars["Opportunity"].waitForExistence(timeout: 10))
                tabs.buttons["Saved"].tap()
                XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 10))
                let savedResolved = NSPredicate { _, _ in
                    !app.staticTexts["Loading saved opportunities..."].exists &&
                    !app.staticTexts["Unable to Load Saved Opportunities"].exists
                }
                expectation(for: savedResolved, evaluatedWith: nil)
                waitForExpectations(timeout: 20)
                tabs.buttons["Discover"].tap()
                tabs.buttons["Saved"].tap()
                XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 10))
                tabs.buttons["Calendar"].tap()
                XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 10))
                let calendarFilter = app.segmentedControls["calendarFilter"]
                XCTAssertTrue(calendarFilter.buttons["Saved"].isHittable)
                calendarFilter.buttons["Saved"].tap()
                XCTAssertTrue(calendarFilter.buttons["Saved"].isSelected)
                calendarFilter.buttons["All Opportunities"].tap()
                let saveError = app.alerts["Unable to Update Saved Opportunity"]
                if saveError.waitForExistence(timeout: 3) {
                    XCTFail("Calendar could not load saved opportunities.")
                }
                tabs.buttons["Profile"].tap()
            case "parent":
                app.buttons["parentChildrenShortcut"].tap()
                XCTAssertTrue(app.navigationBars["Children"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                let childLink = app.descendants(matching: .any).matching(identifier: "managedChildLink").firstMatch
                XCTAssertTrue(childLink.waitForExistence(timeout: 10))
                childLink.tap()
                XCTAssertTrue(app.staticTexts["Managed Youth Profile"].waitForExistence(timeout: 10))
                tabs.buttons["Discover"].tap()
                XCTAssertTrue(app.buttons["All"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.buttons["All"].isHittable)
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                tabs.buttons["Home"].tap()
                app.buttons["parentSavedShortcut"].tap()
                XCTAssertTrue(app.navigationBars["Family Calendar"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.descendants(matching: .any)["familyCalendarLegend"].waitForExistence(timeout: 15))
                tabs.buttons["Home"].tap()
                app.buttons["parentDeadlinesShortcut"].tap()
                XCTAssertTrue(app.buttons["Deadlines"].isSelected)
                tabs.buttons["Profile"].tap()
            case "provider":
                app.buttons["providerOpportunitiesShortcut"].tap()
                XCTAssertTrue(app.navigationBars["Opportunities"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                tabs.buttons["Dashboard"].tap()
                app.buttons["providerEventsShortcut"].tap()
                XCTAssertTrue(app.navigationBars["Events"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 15))
                tabs.buttons["Dashboard"].tap()
                app.buttons["providerAccountShortcut"].tap()
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
