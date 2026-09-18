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

    @Published var role: String?
    @Published var needsOnboarding = false
    @Published var hasYouthProfile = false

    private let supabase =
        SupabaseManager.shared.client


    // MARK: - Observe Auth State

    func observeAuthState() async {

        for await (_, session) in
            supabase.auth.authStateChanges {

            isAuthenticated =
                session != nil

            if session != nil {

                await loadUserRole()

            } else {

                role = nil
                needsOnboarding = false
                hasYouthProfile = false
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


    // MARK: - Sign Up

    func signUp(
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
                .signUp(
                    email: email,
                    password: password
                )

        } catch {

            errorMessage =
                error.localizedDescription
        }
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

            role = nil
            needsOnboarding = false
            hasYouthProfile = false

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }


    // MARK: - Load User Role

    func loadUserRole() async {

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

                role = nil
                needsOnboarding = true
                hasYouthProfile = false
            }

        } catch {

            errorMessage =
                error.localizedDescription
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

            errorMessage =
                error.localizedDescription
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


    // MARK: - Clear Error

    func clearError() {

        errorMessage = nil
    }
}
