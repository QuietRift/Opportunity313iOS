import XCTest

final class NativeSignupUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testParentSignupValidatesWithoutCreatingAnAccount() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["createParentAccount"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["continueWithApple"].exists)
        XCTAssertTrue(app.buttons["continueWithGoogle"].exists)
        app.buttons["createParentAccount"].tap()
        XCTAssertTrue(app.staticTexts["signupHeading"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["signupHeading"].label, "Create your parent account")
        XCTAssertFalse(app.buttons["submitSignup"].isEnabled)
        XCTAssertTrue(app.buttons["continueWithApple"].exists)
        XCTAssertTrue(app.buttons["continueWithGoogle"].exists)
        attach(app, "Parent signup")
        app.buttons["signupShowPassword"].tap()

        fill(app.textFields["signupName"], with: "Fixture Parent", in: app)
        fill(app.textFields["signupEmail"], with: "fixture@example.org", in: app)
        XCTAssertEqual(app.textFields["signupName"].value as? String, "Fixture Parent")
        XCTAssertEqual(app.textFields["signupEmail"].value as? String, "fixture@example.org")
        fill(app.textFields["signupPassword"], with: "fixture-password", in: app)
        fill(app.textFields["signupConfirmPassword"], with: "different-password", in: app)
        reveal(app.buttons["submitSignup"], in: app)
        XCTAssertFalse(app.buttons["submitSignup"].isEnabled)
        XCTAssertTrue(app.staticTexts["signupPasswordMismatch"].exists)
        // Replace only the fixture confirmation, then verify readiness. Never submit.
        let confirm = app.textFields["signupConfirmPassword"]
        reveal(confirm, in: app); confirm.tap()
        confirm.press(forDuration: 1.2)
        if app.menuItems["Select All"].waitForExistence(timeout: 2) { app.menuItems["Select All"].tap(); confirm.typeText("fixture-password") }
        else { confirm.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "different-password".count)); confirm.typeText("fixture-password") }
        XCTAssertEqual(confirm.value as? String, "fixture-password")
        XCTAssertEqual(app.textFields["signupPassword"].value as? String, "fixture-password")
        reveal(app.buttons["submitSignup"], in: app)
        XCTAssertTrue(app.buttons["submitSignup"].isEnabled)
        attach(app, "Parent signup ready")
        XCTAssertFalse(app.staticTexts["signupPasswordMismatch"].exists)
    }

    @MainActor
    func testOrganizationSignupIsAvailableFromLogin() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["otherSignupAccountTypes"].waitForExistence(timeout: 30))
        app.buttons["otherSignupAccountTypes"].tap()
        app.buttons["Provider / Organization"].tap()
        XCTAssertTrue(app.staticTexts["signupHeading"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["signupHeading"].label, "Create your organization account")
        XCTAssertFalse(app.buttons["submitSignup"].isEnabled)
        attach(app, "Organization signup")
    }

    @MainActor private func fill(_ element: XCUIElement, with text: String, in app: XCUIApplication) {
        reveal(element, in: app); element.tap(); element.typeText(text)
        if app.keyboards.buttons["Next"].exists { app.keyboards.buttons["Next"].tap() }
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.maxY
            let visibleBottom = min(app.frame.maxY - 40, keyboardTop - 16)
            if element.isHittable && element.frame.minY >= 130 && element.frame.maxY <= visibleBottom { return }
            let scroll = app.scrollViews["nativeSignupScroll"]
            // Start above the keyboard; a full-view swipe can hit the keyboard instead.
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
        }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
