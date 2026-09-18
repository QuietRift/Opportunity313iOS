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

    private let supabase = SupabaseManager.shared.client


    // MARK: - Load Saves

    func loadSaves(
        for youthProfileIDs: [UUID]
    ) async {

        guard !youthProfileIDs.isEmpty else {
            savedByYouth = [:]
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
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

            savedByYouth = loadedSaves

        } catch {

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

        let currentlySaved =
            isSaved(
                opportunityID:
                    opportunityID,
                for:
                    youthProfileID
            )

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

            errorMessage =
                error.localizedDescription
        }
    }


    // MARK: - Reset

    func reset() {

        savedByYouth = [:]
        errorMessage = nil
    }
}
