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

    private var generation = 0
    private var loadVersion = 0
    private var savesInFlight: Set<UUID> = []

    private let supabase = SupabaseManager.shared.client

    private var youthProfileID: UUID?


    // MARK: - Load Saves

    func loadSaves() async {

        guard let userID = supabase.auth.currentUser?.id else {
            savedOpportunityIDs = []
            youthProfileID = nil
            return
        }

        loadVersion += 1
        let requestVersion = loadVersion
        let requestGeneration = generation
        isLoading = true
        errorMessage = nil

        defer {
            if requestGeneration == generation && requestVersion == loadVersion { isLoading = false }
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

            guard requestGeneration == generation, requestVersion == loadVersion, !Task.isCancelled else { return }
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

            guard requestGeneration == generation, requestVersion == loadVersion, !Task.isCancelled else { return }
            savedOpportunityIDs = Set(
                saves.map {
                    $0.opportunityId
                }
            )

        } catch {

            guard requestGeneration == generation, requestVersion == loadVersion, !Task.isCancelled else { return }
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

        guard !savesInFlight.contains(opportunityID) else { return }
        savesInFlight.insert(opportunityID)
        defer { savesInFlight.remove(opportunityID) }

        let requestGeneration = generation
        if youthProfileID == nil {
            await loadSaves()
        }
        guard requestGeneration == generation else { return }

        guard let youthProfileID else {

            guard requestGeneration == generation else { return }
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

                guard requestGeneration == generation else { return }
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

                guard requestGeneration == generation else { return }
                savedOpportunityIDs.insert(
                    opportunityID
                )
            }

        } catch {

            guard requestGeneration == generation, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }


    // MARK: - Reset

    func reset() {
        generation += 1
        isLoading = false

        savedOpportunityIDs = []
        youthProfileID = nil
        errorMessage = nil
    }
}
