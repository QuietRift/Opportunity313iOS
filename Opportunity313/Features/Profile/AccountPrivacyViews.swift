import SwiftUI
import AuthenticationServices

struct EmailPreferencesView: View {
    @StateObject private var preferences = EmailPreferencesService()
    @State private var wantsUpdates = true

    var body: some View {
        Form {
            Section {
                if preferences.enabled != nil {
                    Toggle("Optional email updates", isOn: $wantsUpdates)
                    Button("Save Email Preferences") { Task { await preferences.save(enabled: wantsUpdates) } }
                        .disabled(preferences.isLoading)
                } else if preferences.isLoading {
                    ProgressView("Loading email preferences…")
                } else {
                    Button("Try Again") { Task { await load() } }
                }
                if let error = preferences.errorMessage { Text(error).foregroundStyle(.red) }
                if let status = preferences.statusMessage { Text(status).foregroundStyle(.secondary) }
            } footer: {
                Text("Includes welcome emails and child-profile, organization, and submission updates. Security notices and sign-in or password-reset emails you request will continue. Each optional email also includes an unsubscribe link.")
            }
        }
        .navigationTitle("Email Preferences")
        .task { await load() }
    }

    private func load() async {
        await preferences.load()
        wantsUpdates = preferences.enabled ?? true
    }
}

struct AccountDeletionView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var confirmation = ""
    @State private var appleError: String?
    private var confirmed: Bool { confirmation == "DELETE" }

    var body: some View {
        Form {
            Section("Delete My Account") {
                Text("This permanently deletes your Opportunity313 account and personal profile information. You will be signed out and cannot undo this action.")
                Text("Child profiles managed only by you, their saves, changes, and tickets will be deleted. Profiles shared with another active guardian stay with that guardian. Your tickets are removed.")
                if auth.role == "provider" {
                    Text("If you are the organization’s last member, its profile details and submitted opportunities will be removed. Shared organization information stays with the remaining members; your matching contact details are cleared. Event records may remain for other participants.")
                }
                Text("To stop a child from signing in while keeping their work, return to their profile and choose Revoke Child Access.")
            }
            Section("Type DELETE to confirm") {
                TextField("DELETE", text: $confirmation)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .accessibilityIdentifier("confirmAccountDeletion")
                if auth.requiresAppleDeletionConfirmation {
                    Text("Confirm with the Apple account linked to this profile to revoke its authorization and permanently delete your account.")
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = []
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                  let codeData = credential.authorizationCode,
                                  let code = String(data: codeData, encoding: .utf8) else {
                                appleError = "Apple confirmation was not returned. Try again."
                                return
                            }
                            Task { _ = await auth.deleteAccount(appleAuthorizationCode: code) }
                        case .failure(let error):
                            if (error as? ASAuthorizationError)?.code != .canceled { appleError = "Apple confirmation failed. Try again." }
                        }
                    }
                    .frame(height: 50).disabled(!confirmed || auth.isLoading)
                } else {
                    Button("Permanently Delete My Account", role: .destructive) {
                        Task { _ = await auth.deleteAccount() }
                    }
                    .disabled(!confirmed || auth.isLoading)
                    .accessibilityIdentifier("permanentlyDeleteAccount")
                }
                if auth.isLoading { ProgressView("Deleting your account…") }
                if let error = appleError ?? auth.errorMessage { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(auth.isLoading)
        .interactiveDismissDisabled(auth.isLoading)
    }
}

struct ChildProfileDeletionView: View {
    let child: YouthProfile
    let onDeleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var access = ChildAccessService()
    @State private var confirmation = ""

    var body: some View {
        Form {
            Section("Permanently Delete \(child.firstName)’s Profile") {
                Text("This removes the child’s profile, saved opportunities, interests, school verification, changes, and assigned tickets for every linked guardian. It cannot be undone.")
                Text("Want to keep their work? Cancel and choose Revoke Child Access. That stops sign-in and keeps the profile available to you.")
            }
            Section("Type DELETE to confirm") {
                TextField("DELETE", text: $confirmation)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .accessibilityIdentifier("confirmChildDeletion")
                Button("Permanently Delete Child Profile", role: .destructive) {
                    Task { if await access.deleteProfile(for: child.id) { onDeleted() } }
                }
                .disabled(confirmation != "DELETE" || access.isLoading)
                if access.isLoading { ProgressView("Deleting child profile…") }
                if let error = access.errorMessage { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Delete Child Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(access.isLoading) } }
        .interactiveDismissDisabled(access.isLoading)
    }
}
