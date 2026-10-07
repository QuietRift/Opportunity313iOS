import Foundation

enum SignupAccountType: String, CaseIterable, Identifiable {
    case parent
    case provider
    case youth

    var id: String { rawValue }
    var title: String {
        switch self {
        case .parent: "Parent or guardian"
        case .provider: "Provider / Organization"
        case .youth: "Young adult (18–24)"
        }
    }
    var signupTitle: String {
        switch self {
        case .parent: "Create your parent account"
        case .provider: "Create your organization account"
        case .youth: "Create your young adult account"
        }
    }
    var detail: String {
        switch self {
        case .parent: "Create profiles for your children, save opportunities, and manage your family’s deadlines."
        case .provider: "Set up your organization and submit opportunities for admin review."
        case .youth: "Build your own profile and find opportunities matched to your interests."
        }
    }
    var symbol: String {
        switch self {
        case .parent: "person.2.fill"
        case .provider: "building.2.fill"
        case .youth: "person.fill"
        }
    }
    var nextStep: String {
        switch self {
        case .parent: "Once your account is ready, you can add your children from the Children tab."
        case .provider: "Once your account is ready, you’ll finish your organization profile. Every opportunity requires admin approval."
        case .youth: "Once your account is ready, you’ll set up your profile and interests."
        }
    }

    // This preference is an onboarding request, never an authorization claim.
    // Existing backend roles always take precedence. Admin/staff are not signup choices.
    static func onboardingChoice(existingRoles: [String], preference: String?) -> Self? {
        guard existingRoles.isEmpty, let preference else { return nil }
        return Self(rawValue: preference)
    }
}

struct SignupDraft {
    var name = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    var accountType: SignupAccountType = .parent
    var confirmsAdultAge = false

    var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var cleanEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    var passwordsDoNotMatch: Bool { !confirmPassword.isEmpty && password != confirmPassword }
    var isValid: Bool {
        !cleanName.isEmpty && cleanName.count <= 200 &&
        cleanEmail.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil &&
        password.count >= 8 && password == confirmPassword &&
        (accountType != .youth || confirmsAdultAge)
    }
    var metadata: [String: String] {
        ["full_name": cleanName, "display_name": cleanName, "signup_account_type": accountType.rawValue]
    }
}
