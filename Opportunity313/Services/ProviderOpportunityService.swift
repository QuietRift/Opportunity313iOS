//
//  ProviderOpportunityService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class ProviderOpportunityService: ObservableObject {

    @Published var opportunities: [Opportunity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase =
        SupabaseManager.shared.client


    // MARK: - Fetch Provider Opportunities

    func fetchOpportunities(
        organizationID: UUID
    ) async {

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
                        "organization_id",
                        value: organizationID
                    )
                    .order(
                        "created_at",
                        ascending: false
                    )
                    .execute()
                    .value

            opportunities = results

        } catch {

            errorMessage =
                error.localizedDescription
        }
    }


    // MARK: - Create Opportunity

    func createOpportunity(
        organizationID: UUID,
        title: String,
        summary: String,
        category: String,
        opportunityType: String,
        ageMin: Int?,
        ageMax: Int?,
        gradeMin: Int?,
        gradeMax: Int?,
        startsAt: Date,
        endsAt: Date?,
        deadline: Date?,
        costCents: Int,
        isFree: Bool,
        locationName: String,
        neighborhood: String?,
        transportation: String?,
        mealsProvided: Bool,
        accessibility: String?,
        parentRequirements: String?,
        registrationUrl: String?,
        capacity: Int?
    ) async throws {

        guard let userID =
                supabase.auth.currentUser?.id else {

            throw ProviderOpportunityError
                .notAuthenticated
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        let newOpportunity =
            CreateProviderOpportunity(
                organizationId:
                    organizationID,
                title:
                    title.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                summary:
                    summary.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                category:
                    category,
                opportunityType:
                    opportunityType,
                ageMin:
                    ageMin,
                ageMax:
                    ageMax,
                gradeMin:
                    gradeMin,
                gradeMax:
                    gradeMax,
                startsAt:
                    startsAt,
                endsAt:
                    endsAt,
                deadline:
                    deadline,
                costCents:
                    isFree ? 0 : costCents,
                isFree:
                    isFree,
                locationName:
                    locationName
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                neighborhood:
                    cleaned(
                        neighborhood
                    ),
                transportation:
                    cleaned(
                        transportation
                    ),
                mealsProvided:
                    mealsProvided,
                accessibility:
                    cleaned(
                        accessibility
                    ),
                parentRequirements:
                    cleaned(
                        parentRequirements
                    ),
                registrationMethod:
                    "provider_submission",
                registrationUrl:
                    cleaned(
                        registrationUrl
                    ),
                capacity:
                    capacity,
                status:
                    "pending_review",
                createdBy:
                    userID
            )

        do {

            try await supabase
                .from("opportunities")
                .insert(newOpportunity)
                .execute()

            await fetchOpportunities(
                organizationID:
                    organizationID
            )

        } catch {

            errorMessage =
                error.localizedDescription

            throw error
        }
    }


    // MARK: - Helpers

    private func cleaned(
        _ value: String?
    ) -> String? {

        guard let value else {
            return nil
        }

        let trimmed =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return trimmed.isEmpty
            ? nil
            : trimmed
    }
}


enum ProviderOpportunityError:
    LocalizedError {

    case notAuthenticated

    var errorDescription: String? {

        switch self {

        case .notAuthenticated:

            return
                "You must be signed in as a provider."
        }
    }
}
