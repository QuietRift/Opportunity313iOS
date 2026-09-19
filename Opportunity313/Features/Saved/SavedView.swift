//
//  SavedView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct SavedView: View {

    @Environment(\.colorScheme) private var colorScheme

    @EnvironmentObject var savedService:
        SavedOpportunityService

    @StateObject private var opportunityService =
        OpportunityService()

    var body: some View {

        NavigationStack {

            Group {

                if (opportunityService.isLoading || savedService.isLoading) &&
                    opportunityService.opportunities.isEmpty {

                    ProgressView(
                        "Loading saved opportunities..."
                    )

                } else if let error = opportunityService.errorMessage ?? savedService.errorMessage {
                    VStack(spacing: 16) {
                        ContentUnavailableView("Unable to Load Saved Opportunities", systemImage: "exclamationmark.triangle", description: Text(error))
                        Button("Try Again") { Task { await loadData() } }
                    }
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
                        .listRowBackground(Opportunity313Brand.surface(for: colorScheme))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
            .navigationTitle("Saved")
            .task { await loadData() }
            .refreshable { await loadData() }
        }
        .opportunity313PageBackground()
    }


    private func loadData() async {
        async let opportunities: Void = opportunityService.fetchOpportunities()
        async let saves: Void = savedService.loadSaves()
        _ = await (opportunities, saves)
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
