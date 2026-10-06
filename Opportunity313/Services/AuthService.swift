//
//  AuthService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class AuthService: ObservableObject {

    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var displayName = ""
    @Published var email = ""
    @Published private(set) var isRecoveringPassword = false
    @Published var role: String?
    @Published var needsOnboarding = false
    @Published var hasYouthProfile = false
    @Published private(set) var userID: UUID?
    @Published private(set) var isResolvingAccount = true
    @Published private(set) var accountError: String?

    private let supabase: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        supabase = client
    }


    // MARK: - Observe Auth State

    func observeAuthState() async {

        for await (event, session) in
            supabase.auth.authStateChanges {

            if event == .passwordRecovery { isRecoveringPassword = true }
            if event == .signedOut { isRecoveringPassword = false }
            let shouldLoadAccount = userID != session?.user.id || role == nil
            userID = session?.user.id
            displayName = session?.user.userMetadata["full_name"]?.stringValue ?? ""
            email = session?.user.email ?? ""
            isAuthenticated = session != nil

            if session != nil {
                if shouldLoadAccount { await loadUserRole() }

            } else {

                role = nil
                needsOnboarding = false
                hasYouthProfile = false
                accountError = nil
                isResolvingAccount = false
            }
        }
    }


    // MARK: - Sign In

    func signIn(
        email: String,
        password: String
    ) async {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            try await supabase.auth
                .signIn(
                    email: email,
                    password: password
                )

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }

    func signInWithChildAccessCode(_ code: String) async {
        struct Request: Encodable { let action = "redeem"; let code: String }
        struct Credentials: Decodable { let email: String; let password: String }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let credentials: Credentials = try await supabase.functions.invoke(
                "child-access",
                options: FunctionInvokeOptions(body: Request(code: code))
            )
            try await supabase.auth.signIn(email: credentials.email, password: credentials.password)
        } catch {
            errorMessage = "That access code is invalid, expired, or temporarily unavailable."
        }
    }


    // MARK: - Sign Up

    enum SignupOutcome: Equatable {
        case confirmationRequired
        case signedIn
    }

    func signUp(draft: SignupDraft) async -> SignupOutcome? {
        guard !isLoading else { return nil }
        guard draft.isValid else {
            errorMessage = "Check your name, email, and matching passwords before continuing."
            return nil
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let data: [String: AnyJSON] = draft.metadata.mapValues { .string($0) }
            let result = try await supabase.auth.signUp(
                email: draft.cleanEmail,
                password: draft.password,
                data: data
            )
            return result.session == nil ? .confirmationRequired : .signedIn
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }


    // Password recovery uses the one-time code in the configured recovery email.
    func requestPasswordReset(email: String) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.resetPasswordForEmail(email.trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func verifyPasswordReset(email: String, code: String) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await supabase.auth.verifyOTP(email: email.trimmingCharacters(in: .whitespacesAndNewlines), token: code.trimmingCharacters(in: .whitespacesAndNewlines), type: .recovery)
            guard response.session != nil else { errorMessage = "The reset code did not open a recovery session."; return false }
            isRecoveringPassword = true
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func finishPasswordReset(password: String, confirmation: String) async -> Bool {
        guard !isLoading, isRecoveringPassword, password.count >= 8, password == confirmation else { return false }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            try await supabase.auth.update(user: UserAttributes(password: password))
            isRecoveringPassword = false
            await refreshUserState()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    // MARK: - Resend Confirmation

    func resendSignupConfirmation(
        email: String
    ) async -> Bool {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            try await supabase.auth
                .resend(
                    email: email,
                    type: .signup
                )

            return true

        } catch {

            errorMessage =
                error.localizedDescription

            return false
        }
    }


    // MARK: - Sign Out

    func signOut() async {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            try await supabase.auth
                .signOut()

            userID = nil
            isAuthenticated = false
            role = nil
            needsOnboarding = false
            hasYouthProfile = false

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }

    /// Clear this device's session when an account was removed or the user
    /// wants to use a different login. This does not sign out other devices.
    func switchAccount() async {
        // The Auth client removes its stored session before contacting the
        // server, so a deleted account can still be cleared on this device.
        try? await supabase.auth.signOut(scope: .local)
        userID = nil
        isAuthenticated = false
        role = nil
        needsOnboarding = false
        hasYouthProfile = false
        accountError = nil
        errorMessage = nil
        isResolvingAccount = false
    }


    // MARK: - Load User Role

    func loadUserRole() async {
        isResolvingAccount = true
        accountError = nil
        defer { isResolvingAccount = false }

        guard let userID =
            supabase.auth.currentUser?.id else {

            role = nil
            needsOnboarding = false
            hasYouthProfile = false

            return
        }

        do {

            struct UserRole:
                Decodable {

                let role: String
            }


            let roles:
                [UserRole] =
                try await supabase
                    .from("user_roles")
                    .select("role")
                    .eq(
                        "user_id",
                        value: userID
                    )
                    .limit(1)
                    .execute()
                    .value


            if let userRole =
                roles.first {

                role = userRole.role
                needsOnboarding = false

                if userRole.role ==
                    "youth" {

                    await loadYouthProfile()

                } else {

                    hasYouthProfile = false
                }

            } else {
                // A cached token from a deleted account can still make a
                // role query return zero rows. Verify the Auth user before
                // treating this as a new signup.
                do {
                    let account = try await supabase.auth.user()
                    guard account.id == userID else {
                        await switchAccount()
                        return
                    }
                    // Signup metadata only records the user's requested experience.
                    // Authorization still comes from user_roles and the authenticated RPC.
                    if account.emailConfirmedAt != nil,
                       let choice = SignupAccountType.onboardingChoice(
                           existingRoles: roles.map(\.role),
                           preference: account.userMetadata["signup_account_type"]?.stringValue
                       ) {
                        let _: String = try await supabase
                            .rpc("claim_onboarding_role", params: ["requested_role": choice.rawValue])
                            .execute().value
                        role = choice.rawValue
                        needsOnboarding = false
                        if choice == .youth { await loadYouthProfile() }
                        else { hasYouthProfile = false }
                    } else {
                        role = nil
                        needsOnboarding = true
                        hasYouthProfile = false
                    }
                } catch let error as AuthError {
                    switch error {
                    case .sessionMissing:
                        await switchAccount()
                    case .api(_, _, _, let response)
                        where [401, 403, 404].contains(response.statusCode):
                        await switchAccount()
                    default:
                        accountError = error.localizedDescription
                    }
                } catch {
                    accountError = error.localizedDescription
                }
            }

        } catch {

            accountError = error.localizedDescription
        }
    }


    // MARK: - Load Youth Profile

    func loadYouthProfile() async {

        guard let userID =
            supabase.auth.currentUser?.id else {

            hasYouthProfile = false
            return
        }

        do {

            struct ProfileID:
                Decodable {

                let id: UUID
            }


            let profile:
                ProfileID? =
                try await supabase
                    .from("youth_profiles")
                    .select("id")
                    .eq(
                        "user_id",
                        value: userID
                    )
                    .maybeSingle()
                    .execute()
                    .value


            hasYouthProfile =
                profile != nil

        } catch {

            hasYouthProfile = false

            accountError = error.localizedDescription
        }
    }


    // MARK: - Refresh State

    func refreshUserState() async {

        guard supabase.auth
            .currentUser != nil else {

            isAuthenticated = false
            role = nil
            needsOnboarding = false
            hasYouthProfile = false

            return
        }


        isAuthenticated = true

        await loadUserRole()
    }


    func updateDisplayName(_ name: String) async throws {
        let user = try await supabase.auth.update(user: UserAttributes(
            data: ["full_name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines))]
        ))
        displayName = user.userMetadata["full_name"]?.stringValue ?? ""
    }

    // MARK: - Clear Error

    func clearError() {

        errorMessage = nil
    }
}
