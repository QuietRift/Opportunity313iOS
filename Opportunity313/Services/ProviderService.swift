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


    // MARK: - Register Organization

    func registerOrganization(
        name: String,
        type: String,
        description: String
    ) async throws {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }


        struct Params: Encodable {

            let organizationName: String
            let requestedType: String
            let organizationDescription: String?

            enum CodingKeys:
                String,
                CodingKey {

                case organizationName =
                    "organization_name"

                case requestedType =
                    "requested_type"

                case organizationDescription =
                    "organization_description"
            }
        }


        let cleanName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleanDescription =
            description
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )


        let params = Params(
            organizationName: cleanName,
            requestedType: type,
            organizationDescription:
                cleanDescription.isEmpty
                ? nil
                : cleanDescription
        )


        do {

            let createdOrganization:
                Organization =
                try await supabase
                    .rpc(
                        "register_provider_organization",
                        params: params
                    )
                    .execute()
                    .value


            organization =
                createdOrganization

        } catch {

            errorMessage =
                error.localizedDescription

            throw error
        }
    }


    // MARK: - Clear Error

    func clearError() {

        errorMessage = nil
    }
}
