import SwiftUI

struct PasswordRecoveryRequestView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var requested = false
    @State private var resendAfter = Date.distantPast

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Reset your password").font(.title2.bold())
                    Text(requested ? "If an account matches this email, you’ll receive a one-time reset code. Enter it below." : "Enter the email address for your Parent or Provider account.")
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().disabled(requested)
                    if requested {
                        TextField("Reset code from email", text: $code).keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        Button("Verify reset code") {
                            Task { if await authService.verifyPasswordReset(email: email, code: code) { dismiss() } }
                        }.disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Button(requested ? "Resend reset code" : "Send reset code") {
                        Task {
                            if await authService.requestPasswordReset(email: email) {
                                requested = true; resendAfter = Date().addingTimeInterval(60)
                            }
                        }
                    }.disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (requested && Date() < resendAfter))
                    if requested {
                        Button("Use a different email") { requested = false; code = ""; authService.clearError() }
                    }
                }
                if authService.isLoading { ProgressView() }
                if let error = authService.errorMessage { Text(error).foregroundStyle(.red) }
            }.disabled(authService.isLoading)
                .navigationTitle("Account recovery").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { authService.clearError(); dismiss() }.disabled(authService.isLoading) } }
        }.interactiveDismissDisabled(authService.isLoading).onAppear { authService.clearError() }
            .task(id: resendAfter) {
                let remaining = resendAfter.timeIntervalSinceNow
                guard remaining > 0 else { return }
                do { try await Task.sleep(for: .seconds(remaining)); resendAfter = .distantPast }
                catch { }
            }
    }
}

struct PasswordResetView: View {
    @EnvironmentObject var authService: AuthService
    @State private var password = ""
    @State private var confirmation = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose a new password").font(.title2.bold())
                    SecureField("New password", text: $password).textContentType(.newPassword)
                    SecureField("Confirm new password", text: $confirmation).textContentType(.newPassword)
                    Text("Use at least 8 characters.").font(.caption)
                    if !confirmation.isEmpty && confirmation != password { Text("Passwords do not match.").foregroundStyle(.red) }
                    Button("Save new password") {
                        Task { _ = await authService.finishPasswordReset(password: password, confirmation: confirmation) }
                    }.disabled(password.count < 8 || confirmation != password)
                }
                if authService.isLoading { ProgressView() }
                if let error = authService.errorMessage { Text(error).foregroundStyle(.red) }
            }.disabled(authService.isLoading)
                .navigationTitle("Reset password")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Sign out") { Task { await authService.signOut() } }.disabled(authService.isLoading) } }
        }
    }
}
