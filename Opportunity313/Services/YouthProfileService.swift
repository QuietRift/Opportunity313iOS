//
//  YouthProfileService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class YouthProfileService: ObservableObject {

    // MARK: - Published State

    @Published var currentProfile: YouthProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?


    // MARK: - Supabase

    private let supabase = SupabaseManager.shared.client


    // MARK: - Load Current Profile

    func fetchCurrentProfile() async {

        guard let userID = supabase.auth.currentUser?.id else {

            currentProfile = nil
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let profile: YouthProfile? = try await supabase
                .from("youth_profiles")
                .select()
                .eq(
                    "user_id",
                    value: userID
                )
                .maybeSingle()
                .execute()
                .value

            currentProfile = profile

        } catch {

            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }


    // MARK: - Create Profile

    func createProfile(
        firstName: String,
        ageBand: String,
        grade: Int?,
        interests: [String]
    ) async throws {

        guard let userID = supabase.auth.currentUser?.id else {

            throw YouthProfileError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        let profile = CreateYouthProfile(
            userId: userID,
            firstName: firstName,
            ageBand: ageBand,
            grade: grade,
            interests: interests,
            accessibilityPreferences: [],
            accountType: "youth_account"
        )

        do {

            try await supabase
                .from("youth_profiles")
                .insert(profile)
                .execute()

            await fetchCurrentProfile()

        } catch {

            errorMessage = error.localizedDescription
            throw error
        }
    }


    // MARK: - Update Profile

    func updateProfile(
        firstName: String,
        ageBand: String,
        grade: Int?,
        interests: [String],
        accessibilityPreferences: [String]
    ) async throws {

        guard let userID = supabase.auth.currentUser?.id else {

            throw YouthProfileError.notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        let update = UpdateYouthProfile(
            firstName: firstName,
            ageBand: ageBand,
            grade: grade,
            interests: interests,
            accessibilityPreferences:
                accessibilityPreferences
        )

        do {

            try await supabase
                .from("youth_profiles")
                .update(update)
                .eq(
                    "user_id",
                    value: userID
                )
                .execute()

            await fetchCurrentProfile()

        } catch {

            errorMessage = error.localizedDescription
            throw error
        }
    }


    // MARK: - Clear Error

    func clearError() {

        errorMessage = nil
    }
}


// MARK: - Youth Profile Errors

enum YouthProfileError: LocalizedError {

    case notAuthenticated

    var errorDescription: String? {

        switch self {

        case .notAuthenticated:

            return "You must be signed in to manage a youth profile."
        }
    }
}
