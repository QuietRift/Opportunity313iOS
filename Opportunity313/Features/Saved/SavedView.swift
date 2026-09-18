//
//  SavedView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct SavedView: View {

    @EnvironmentObject var savedService:
        SavedOpportunityService

    @StateObject private var opportunityService =
        OpportunityService()

    var body: some View {

        NavigationStack {

            Group {

                if opportunityService.isLoading ||
                    savedService.isLoading {

                    ProgressView(
                        "Loading saved opportunities..."
                    )

                } else if savedOpportunities.isEmpty {

                    ContentUnavailableView(
                        "Nothing Saved Yet",
                        systemImage: "bookmark",
                        description: Text(
                            "Save opportunities you're interested in and they'll appear here."
                        )
                    )

                } else {

                    List(
                        savedOpportunities
                    ) { opportunity in

                        NavigationLink {

                            OpportunityDetailView(
                                opportunity:
                                    opportunity
                            )

                        } label: {

                            OpportunityRow(
                                opportunity:
                                    opportunity
                            )
                        }
                        .swipeActions {

                            Button(
                                role: .destructive
                            ) {

                                Task {

                                    await savedService
                                        .toggleSave(
                                            opportunityID:
                                                opportunity.id
                                        )
                                }

                            } label: {

                                Label(
                                    "Remove",
                                    systemImage:
                                        "bookmark.slash"
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Saved")
            .task {

                await opportunityService
                    .fetchOpportunities()

                await savedService
                    .loadSaves()
            }
            .refreshable {

                await opportunityService
                    .fetchOpportunities()

                await savedService
                    .loadSaves()
            }
        }
    }


    private var savedOpportunities:
        [Opportunity] {

        opportunityService.opportunities
            .filter {

                savedService
                    .savedOpportunityIDs
                    .contains($0.id)
            }
    }
}
