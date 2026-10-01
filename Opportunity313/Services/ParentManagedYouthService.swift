//
//  ParentManagedYouthService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation
import Combine
import Supabase

extension Notification.Name {
    static let managedYouthProfileDidChange = Notification.Name(
        "managedYouthProfileDidChange"
    )
}

@MainActor
final class ParentManagedYouthService: ObservableObject {

    @Published var relationships: [UUID: String] = [:]
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
                let relationship: String

                enum CodingKeys: String, CodingKey {
                    case youthProfileId = "youth_profile_id"
                    case relationship
                }
            }

            let relationships: [RelationshipRow] = try await supabase
                .from("guardian_relationships")
                .select("youth_profile_id, relationship")
                .eq("guardian_user_id", value: userID)
                .eq("status", value: "active")
                .execute()
                .value

            self.relationships = Dictionary(relationships.map { ($0.youthProfileId, $0.relationship) }, uniquingKeysWith: { first, _ in first })

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

            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }


    // MARK: - Create Parent Managed Youth

    func createChild(
        firstName: String,
        ageBand: String,
        grade: Int?,
        gender: ParticipantGender,
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
            let genderInput: String
            let interestsInput: [String]
            let accessibilityPreferencesInput: [String]
            let relationshipInput: String

            enum CodingKeys: String, CodingKey {
                case firstNameInput = "first_name_input"
                case ageBandInput = "age_band_input"
                case gradeInput = "grade_input"
                case genderInput = "gender_input"
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
            genderInput: gender.rawValue,
            interestsInput: interests,
            accessibilityPreferencesInput:
                accessibilityPreferences,
            relationshipInput:
                relationship
        )

        do {

            let newYouthID: UUID = try await supabase
                .rpc(
                    "create_parent_managed_youth",
                    params: params
                )
                .execute()
                .value

            await fetchChildren()
            NotificationCenter.default.post(
                name: .managedYouthProfileDidChange,
                object: nil,
                userInfo: ["youthProfileID": newYouthID]
            )

        } catch {

            errorMessage = error.localizedDescription
            throw error
        }
    }

    func updateChildGender(
        childID: UUID,
        gender: ParticipantGender
    ) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        struct Params: Encodable {
            let youthProfileIdInput: UUID
            let genderInput: String

            enum CodingKeys: String, CodingKey {
                case youthProfileIdInput = "youth_profile_id_input"
                case genderInput = "gender_input"
            }
        }

        do {
            try await supabase
                .rpc(
                    "update_parent_managed_youth_gender",
                    params: Params(
                        youthProfileIdInput: childID,
                        genderInput: gender.rawValue
                    )
                )
                .execute()
            await fetchChildren()
            NotificationCenter.default.post(
                name: .managedYouthProfileDidChange,
                object: nil,
                userInfo: ["youthProfileID": childID]
            )
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }


    func updateChild(_ child: YouthProfile, firstName: String, ageBand: String,
                     grade: Int?, interests: [String], accessibility: [String]) async throws {
        guard children.contains(where: { $0.id == child.id }) else {
            throw YouthProfileError.notAuthenticated
        }
        let update = UpdateYouthProfile(firstName: firstName, ageBand: ageBand, grade: grade,
                                        gender: child.gender, interests: interests,
                                        accessibilityPreferences: accessibility)
        // RLS enforces the active guardian relationship; require a returned row.
        let updated: YouthProfile = try await supabase.from("youth_profiles")
            .update(update).eq("id", value: child.id).select().single().execute().value
        if let index = children.firstIndex(where: { $0.id == updated.id }) {
            children[index] = updated
        }
        NotificationCenter.default.post(name: .managedYouthProfileDidChange, object: nil)
    }

    // MARK: - Clear Error

    func clearError() {
        errorMessage = nil
    }
}
