//
//  AdminService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class AdminService: ObservableObject {

    @Published var pendingOpportunities: [Opportunity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let supabase =
        SupabaseManager.shared.client


    // MARK: - Fetch Pending Opportunities

    func fetchPendingOpportunities() async {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let results: [Opportunity] =
                try await supabase
                    .from("opportunities")
                    .select()
                    .eq(
                        "status",
                        value: "pending_review"
                    )
                    .order(
                        "created_at",
                        ascending: true
                    )
                    .execute()
                    .value

            pendingOpportunities = results

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }


    // MARK: - Approve & Publish

    func approveAndPublish(
        _ opportunity: Opportunity
    ) async {

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {

            // First verify the provider organization.

            struct VerifyOrganizationParams:
                Encodable {

                let targetOrganizationId: UUID

                enum CodingKeys:
                    String,
                    CodingKey {

                    case targetOrganizationId =
                        "target_organization_id"
                }
            }


            let verifyParams =
                VerifyOrganizationParams(
                    targetOrganizationId:
                        opportunity.organizationId
                )


            let _: Organization =
                try await supabase
                    .rpc(
                        "verify_provider_organization",
                        params: verifyParams
                    )
                    .execute()
                    .value


            // Then publish the opportunity.

            struct PublishOpportunityParams:
                Encodable {

                let targetOpportunityId: UUID

                enum CodingKeys:
                    String,
                    CodingKey {

                    case targetOpportunityId =
                        "target_opportunity_id"
                }
            }


            let publishParams =
                PublishOpportunityParams(
                    targetOpportunityId:
                        opportunity.id
                )


            let _: Opportunity =
                try await supabase
                    .rpc(
                        "publish_opportunity",
                        params: publishParams
                    )
                    .execute()
                    .value


            // Remove it from the local review queue.

            pendingOpportunities
                .removeAll {
                    $0.id == opportunity.id
                }

            successMessage =
                "\(opportunity.title) is now published."

        } catch {

            errorMessage =
                error.localizedDescription
        }

        isLoading = false
    }


    // MARK: - Clear Messages

    func clearMessages() {

        errorMessage = nil
        successMessage = nil
    }
}
