//
//  ProviderService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class ProviderService: ObservableObject {

    @Published var organization: Organization?
    @Published var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let supabase =
        SupabaseManager.shared.client


    // MARK: - Fetch Provider Organization

    func fetchOrganization() async {

        guard let userID =
            supabase.auth.currentUser?.id else {

            organization = nil
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            struct Membership: Decodable {

                let organizationId: UUID

                enum CodingKeys:
                    String,
                    CodingKey {

                    case organizationId =
                        "organization_id"
                }
            }


            let membership:
                Membership? =
                try await supabase
                    .from("org_members")
                    .select(
                        "organization_id"
                    )
                    .eq(
                        "user_id",
                        value: userID
                    )
                    .eq(
                        "status",
                        value: "active"
                    )
                    .limit(1)
                    .maybeSingle()
                    .execute()
                    .value


            guard let membership else {

                organization = nil
                return
            }


            let result:
                Organization? =
                try await supabase
                    .from("organizations")
                    .select()
                    .eq(
                        "id",
                        value:
                            membership.organizationId
                    )
                    .maybeSingle()
                    .execute()
                    .value


            organization = result

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }


    // A single transaction creates the organization/membership or updates its editable fields.
    func saveProfile(_ draft: OrganizationProfileDraft, organizationID: UUID? = nil) async throws {
        if let message = draft.validationMessage { throw OrganizationProfileError.invalid(message) }
        isSaving = true
        defer { isSaving = false }
        struct Params: Encodable {
            let target_organization_id: UUID?
            let profile: OrganizationProfileDraft
            enum CodingKeys: String, CodingKey { case target_organization_id, profile }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(target_organization_id, forKey: .target_organization_id)
                try container.encode(profile, forKey: .profile)
            }
        }
        do {
            organization = try await supabase.rpc("save_organization_profile", params: Params(
                target_organization_id: organizationID, profile: draft.cleaned
            )).execute().value
        } catch {
            throw error
        }
    }

    // MARK: - Clear Error

    func clearError() {

        errorMessage = nil
    }
}
