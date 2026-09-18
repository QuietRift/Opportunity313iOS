//
//  ParentManagedYouthService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class ParentManagedYouthService: ObservableObject {

    @Published var children: [YouthProfile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared.client


    // MARK: - Load Children

    func fetchChildren() async {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        guard let userID = supabase.auth.currentUser?.id else {
            children = []
            return
        }

        do {

            struct RelationshipRow: Decodable {

                let youthProfileId: UUID

                enum CodingKeys: String, CodingKey {
                    case youthProfileId = "youth_profile_id"
                }
            }

            let relationships: [RelationshipRow] = try await supabase
                .from("guardian_relationships")
                .select("youth_profile_id")
                .eq("guardian_user_id", value: userID)
                .eq("status", value: "active")
                .execute()
                .value

            let ids = relationships.map {
                $0.youthProfileId
            }

            guard !ids.isEmpty else {
                children = []
                return
            }

            var loadedChildren: [YouthProfile] = []

            for id in ids {

                let child: YouthProfile? = try await supabase
                    .from("youth_profiles")
                    .select()
                    .eq("id", value: id)
                    .maybeSingle()
                    .execute()
                    .value

                if let child {
                    loadedChildren.append(child)
                }
            }

            children = loadedChildren.sorted {
                $0.firstName < $1.firstName
            }

        } catch {

            errorMessage = error.localizedDescription
        }
    }


    // MARK: - Create Parent Managed Youth

    func createChild(
        firstName: String,
        ageBand: String,
        grade: Int?,
        interests: [String],
        accessibilityPreferences: [String],
        relationship: String
    ) async throws {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        struct Params: Encodable {

            let firstNameInput: String
            let ageBandInput: String
            let gradeInput: Int?
            let interestsInput: [String]
            let accessibilityPreferencesInput: [String]
            let relationshipInput: String

            enum CodingKeys: String, CodingKey {
                case firstNameInput = "first_name_input"
                case ageBandInput = "age_band_input"
                case gradeInput = "grade_input"
                case interestsInput = "interests_input"

                case accessibilityPreferencesInput =
                    "accessibility_preferences_input"

                case relationshipInput =
                    "relationship_input"
            }
        }

        let params = Params(
            firstNameInput:
                firstName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            ageBandInput: ageBand,
            gradeInput: grade,
            interestsInput: interests,
            accessibilityPreferencesInput:
                accessibilityPreferences,
            relationshipInput:
                relationship
        )

        do {

            let _: UUID = try await supabase
                .rpc(
                    "create_parent_managed_youth",
                    params: params
                )
                .execute()
                .value

            await fetchChildren()

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
