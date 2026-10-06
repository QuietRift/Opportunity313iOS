import SwiftUI

struct SignUpView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var draft: SignupDraft
    @State private var didSendConfirmation = false
    @State private var resendMessage: String?
    @State private var showsPassword = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, email, password, confirmPassword }

    init(accountType: SignupAccountType = .parent) {
        _draft = State(initialValue: SignupDraft(accountType: accountType))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if didSendConfirmation { confirmationContent }
                    else { signupContent }
                }
                .frame(maxWidth: 560)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("nativeSignupScroll")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(didSendConfirmation ? "Confirm email" : "Sign up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { authService.clearError(); dismiss() }
                        .disabled(authService.isLoading)
                        .accessibilityIdentifier("closeSignup")
                }
            }
            .opportunity313PageBackground()
            .interactiveDismissDisabled(authService.isLoading)
        }
        .onAppear { authService.clearError() }
    }

    private var signupContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                (Text("Opportunity").foregroundStyle(.white) + Text("313").foregroundStyle(Opportunity313Brand.accent))
                    .font(.headline.bold())
                Label(draft.accountType.title, systemImage: draft.accountType.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(draft.accountType.signupTitle)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("signupHeading")
                Text(draft.accountType.detail)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Opportunity313Brand.heroGradient, in: RoundedRectangle(cornerRadius: 20))

            Picker("Account type", selection: $draft.accountType) {
                ForEach(SignupAccountType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("signupAccountType")
            .disabled(authService.isLoading)

            VStack(alignment: .leading, spacing: 20) {
                fieldLabel("Your name") {
                    TextField("Your name", text: $draft.name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .email }
                        .accessibilityIdentifier("signupName")
                }
                fieldLabel("Email address") {
                    TextField("Email address", text: $draft.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .password }
                        .accessibilityIdentifier("signupEmail")
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Password").font(.subheadline.weight(.semibold))
                        Spacer()
                        Button(showsPassword ? "Hide" : "Show") { showsPassword.toggle() }
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: 44)
                            .accessibilityLabel(showsPassword ? "Hide passwords" : "Show passwords")
                            .accessibilityIdentifier("signupShowPassword")
                    }
                    passwordField("Password", text: $draft.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }
                        .accessibilityIdentifier("signupPassword")
                    Text("Use at least 8 characters.").font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm password").font(.subheadline.weight(.semibold))
                    passwordField("Confirm password", text: $draft.confirmPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.done)
                        .onSubmit { if draft.isValid { Task { await createAccount() } } }
                        .accessibilityIdentifier("signupConfirmPassword")
                }
                if draft.passwordsDoNotMatch {
                    Text("Passwords do not match.")
                        .font(.subheadline).foregroundStyle(.red)
                        .accessibilityIdentifier("signupPasswordMismatch")
                }
                if draft.accountType == .youth {
                    Toggle("I am 18–24 years old", isOn: $draft.confirmsAdultAge)
                        .accessibilityIdentifier("signupAdultConfirmation")
                }
            }
            .disabled(authService.isLoading)

            errorContent

            Button { Task { await createAccount() } } label: {
                HStack {
                    if authService.isLoading { ProgressView().tint(.white) }
                    else { Text(draft.accountType == .parent ? "Create parent account" : "Create account"); Spacer(); Image(systemName: "arrow.right") }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!draft.isValid || authService.isLoading)
            .accessibilityIdentifier("submitSignup")

            VStack(alignment: .leading, spacing: 8) {
                Text(draft.accountType.nextStep).font(.subheadline)
                Text("Children under 18 don’t need their own account. A parent or guardian creates their profile and shares a private access code.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))

            Button("Already have an account? Sign in") { authService.clearError(); dismiss() }
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(authService.isLoading)
        }
    }

    private var confirmationContent: some View {
        Group {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 44)).foregroundStyle(Opportunity313Brand.accent)
                .accessibilityHidden(true)
            Text("Check your email").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Text("Check **\(draft.cleanEmail)** for your confirmation link. If you already have an account, sign in instead.")
            Text("Confirm your email, then return to the app and sign in.")
                .foregroundStyle(.secondary)
            Text(draft.accountType.nextStep).font(.subheadline)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
            if let resendMessage { Text(resendMessage).font(.subheadline).foregroundStyle(.secondary) }
            errorContent
            Button {
                authService.clearError(); dismiss()
            } label: {
                Text("Back to sign in").fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(authService.isLoading)
            Button {
                Task {
                    resendMessage = nil
                    if await authService.resendSignupConfirmation(email: draft.cleanEmail) {
                        resendMessage = "Confirmation email requested. Check your inbox and spam folder."
                    }
                }
            } label: {
                HStack {
                    if authService.isLoading { ProgressView() }
                    Text("Resend confirmation email")
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).controlSize(.large).disabled(authService.isLoading)
        }
    }

    @ViewBuilder private var errorContent: some View {
        if let error = authService.errorMessage {
            Text(error).font(.subheadline).foregroundStyle(.red)
                .accessibilityIdentifier("signupError")
        }
    }

    private func fieldLabel<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.semibold))
            content().padding(14)
                .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25)))
        }
    }

    @ViewBuilder private func passwordField(_ label: String, text: Binding<String>) -> some View {
        Group {
            if showsPassword { TextField(label, text: text) }
            else { SecureField(label, text: text) }
        }
        .textContentType(.newPassword)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .padding(14)
        .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25)))
    }

    private func createAccount() async {
        guard draft.isValid, !authService.isLoading else { return }
        focusedField = nil
        let outcome = await authService.signUp(draft: draft)
        guard let outcome else { return }
        draft.password = ""; draft.confirmPassword = ""; showsPassword = false
        switch outcome {
        case .confirmationRequired: didSendConfirmation = true
        case .signedIn: dismiss()
        }
    }
}
