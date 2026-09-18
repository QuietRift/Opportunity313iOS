//
//  FamilySaveService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class FamilySaveService: ObservableObject {

    @Published var savedByYouth: [UUID: Set<UUID>] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var generation = 0
    private var savesInFlight: Set<UUID> = []

    private let supabase = SupabaseManager.shared.client


    // MARK: - Load Saves

    func loadSaves(
        for youthProfileIDs: [UUID]
    ) async {

        guard !youthProfileIDs.isEmpty else {
            savedByYouth = [:]
            return
        }

        let requestGeneration = generation
        isLoading = true
        errorMessage = nil

        defer {
            if requestGeneration == generation { isLoading = false }
        }

        do {

            var loadedSaves:
                [UUID: Set<UUID>] = [:]

            for youthID in youthProfileIDs {

                let saves:
                    [OpportunitySaveRecord] =
                    try await supabase
                        .from("opportunity_saves")
                        .select("opportunity_id")
                        .eq(
                            "youth_profile_id",
                            value: youthID
                        )
                        .execute()
                        .value

                loadedSaves[youthID] =
                    Set(
                        saves.map {
                            $0.opportunityId
                        }
                    )
            }

            guard requestGeneration == generation else { return }
            savedByYouth = loadedSaves

        } catch {

            guard requestGeneration == generation else { return }
            errorMessage =
                error.localizedDescription
        }
    }


    // MARK: - Is Saved

    func isSaved(
        opportunityID: UUID,
        for youthProfileID: UUID
    ) -> Bool {

        savedByYouth[
            youthProfileID
        ]?
        .contains(
            opportunityID
        ) ?? false
    }


    // MARK: - Toggle Save

    func toggleSave(
        opportunityID: UUID,
        for youthProfileID: UUID
    ) async {

        errorMessage = nil

        guard !savesInFlight.contains(opportunityID) else { return }
        savesInFlight.insert(opportunityID)
        defer { savesInFlight.remove(opportunityID) }

        let currentlySaved =
            isSaved(
                opportunityID:
                    opportunityID,
                for:
                    youthProfileID
            )

        let requestGeneration = generation
        do {

            if currentlySaved {

                try await supabase
                    .from(
                        "opportunity_saves"
                    )
                    .delete()
                    .eq(
                        "youth_profile_id",
                        value:
                            youthProfileID
                    )
                    .eq(
                        "opportunity_id",
                        value:
                            opportunityID
                    )
                    .execute()

                guard requestGeneration == generation else { return }
                savedByYouth[
                    youthProfileID
                ]?
                .remove(
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
                    .from(
                        "opportunity_saves"
                    )
                    .insert(newSave)
                    .execute()

                guard requestGeneration == generation else { return }
                if savedByYouth[
                    youthProfileID
                ] == nil {

                    savedByYouth[
                        youthProfileID
                    ] = []
                }

                savedByYouth[
                    youthProfileID
                ]?
                .insert(
                    opportunityID
                )
            }

        } catch {

            guard requestGeneration == generation else { return }
            errorMessage =
                error.localizedDescription
        }
    }


    // MARK: - Reset

    func reset() {
        generation += 1
        isLoading = false

        savedByYouth = [:]
        errorMessage = nil
    }
}
