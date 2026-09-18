//
//  SavedOpportunityService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class SavedOpportunityService: ObservableObject {

    @Published var savedOpportunityIDs: Set<UUID> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    private var youthProfileID: UUID?


    // MARK: - Load Saves

    func loadSaves() async {

        guard let userID = supabase.auth.currentUser?.id else {
            savedOpportunityIDs = []
            youthProfileID = nil
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            struct YouthID: Decodable {
                let id: UUID
            }

            let profile: YouthID? = try await supabase
                .from("youth_profiles")
                .select("id")
                .eq("user_id", value: userID)
                .maybeSingle()
                .execute()
                .value

            guard let profile else {
                savedOpportunityIDs = []
                youthProfileID = nil
                return
            }

            youthProfileID = profile.id

            let saves: [OpportunitySaveRecord] = try await supabase
                .from("opportunity_saves")
                .select("opportunity_id")
                .eq(
                    "youth_profile_id",
                    value: profile.id
                )
                .execute()
                .value

            savedOpportunityIDs = Set(
                saves.map {
                    $0.opportunityId
                }
            )

        } catch {

            errorMessage = error.localizedDescription
        }
    }


    // MARK: - Check Save

    func isSaved(
        _ opportunityID: UUID
    ) -> Bool {

        savedOpportunityIDs.contains(
            opportunityID
        )
    }


    // MARK: - Toggle Save

    func toggleSave(
        opportunityID: UUID
    ) async {

        errorMessage = nil

        if youthProfileID == nil {
            await loadSaves()
        }

        guard let youthProfileID else {

            errorMessage =
                "A youth profile is required to save opportunities."

            return
        }

        do {

            if savedOpportunityIDs.contains(
                opportunityID
            ) {

                try await supabase
                    .from("opportunity_saves")
                    .delete()
                    .eq(
                        "youth_profile_id",
                        value: youthProfileID
                    )
                    .eq(
                        "opportunity_id",
                        value: opportunityID
                    )
                    .execute()

                savedOpportunityIDs.remove(
                    opportunityID
                )

            } else {

                let newSave =
                    CreateOpportunitySave(
                        youthProfileId:
                            youthProfileID,
                        opportunityId:
                            opportunityID
                    )

                try await supabase
                    .from("opportunity_saves")
                    .insert(newSave)
                    .execute()

                savedOpportunityIDs.insert(
                    opportunityID
                )
            }

        } catch {

            errorMessage = error.localizedDescription
        }
    }


    // MARK: - Reset

    func reset() {

        savedOpportunityIDs = []
        youthProfileID = nil
        errorMessage = nil
    }
}
