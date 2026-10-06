import Testing
@testable import Opportunity313

struct SignupTests {
    @Test func existingAccountsKeepTheirBackendRoles() {
        #expect(SignupAccountType.onboardingChoice(existingRoles: ["parent"], preference: "provider") == nil)
        #expect(SignupAccountType.onboardingChoice(existingRoles: ["admin"], preference: "parent") == nil)
        #expect(SignupAccountType.onboardingChoice(existingRoles: ["youth"], preference: "parent") == nil)
    }

    @Test func newAccountPreferenceCannotChoosePrivilegedRoles() {
        #expect(SignupAccountType.onboardingChoice(existingRoles: [], preference: "parent") == .parent)
        #expect(SignupAccountType.onboardingChoice(existingRoles: [], preference: "provider") == .provider)
        #expect(SignupAccountType.onboardingChoice(existingRoles: [], preference: "admin") == nil)
        #expect(SignupAccountType.onboardingChoice(existingRoles: [], preference: "athletics") == nil)
        #expect(SignupAccountType.onboardingChoice(existingRoles: [], preference: nil) == nil)
    }

    @Test func signupRequiresNameValidEmailAndMatchingPasswords() {
        var draft = SignupDraft(name: "  Parent Name  ", email: " parent@example.org ", password: "fixture-password", confirmPassword: "fixture-password")
        #expect(draft.isValid)
        #expect(draft.cleanName == "Parent Name")
        #expect(draft.metadata["full_name"] == "Parent Name")
        #expect(draft.metadata["display_name"] == "Parent Name")
        #expect(draft.metadata["signup_account_type"] == "parent")
        draft.confirmPassword = "different"
        #expect(!draft.isValid)
        #expect(draft.passwordsDoNotMatch)
        draft.confirmPassword = draft.password
        draft.name = "   "
        #expect(!draft.isValid)
        draft.name = "Parent"
        draft.email = "parent@"
        #expect(!draft.isValid)
        draft.email = "parent@example.org"
        draft.password = "short"; draft.confirmPassword = "short"
        #expect(!draft.isValid)
    }

    @Test func youngAdultSignupRequiresAgeConfirmation() {
        var draft = SignupDraft(name: "Young Adult", email: "adult@example.org", password: "fixture-password", confirmPassword: "fixture-password", accountType: .youth)
        #expect(!draft.isValid)
        draft.confirmsAdultAge = true
        #expect(draft.isValid)
        draft.accountType = .parent; draft.confirmsAdultAge = false
        #expect(draft.isValid)
    }
}
