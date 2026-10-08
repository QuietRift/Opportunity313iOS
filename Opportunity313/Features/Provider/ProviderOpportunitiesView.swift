//
//  ProviderOpportunitiesView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ProviderOpportunitiesView: View {

    @Environment(\.colorScheme) private var colorScheme

    let organization: Organization

    @StateObject private var opportunityService =
        ProviderOpportunityService()

    @State private var showCreateOpportunity =
        false

    var body: some View {

        NavigationStack {

            Group {

                if opportunityService.isLoading &&
                    opportunityService
                        .opportunities.isEmpty {

                    ProgressView(
                        "Loading opportunities..."
                    )

                } else if let error = opportunityService.errorMessage {
                    ContentUnavailableView("Unable to Load Opportunities", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if opportunityService
                    .opportunities.isEmpty {

                    ContentUnavailableView(
                        "No Opportunities Yet",
                        systemImage:
                            "list.bullet.rectangle",
                        description: Text(
                            "Create your first youth opportunity and submit it for review."
                        )
                    )

                } else {

                    List(
                        opportunityService
                            .opportunities
                    ) { opportunity in

                        if opportunity.offersInAppTickets {
                            NavigationLink { OpportunityAttendeesView(opportunity: opportunity) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ProviderOpportunityRow(opportunity: opportunity)
                                    Label("View Attendees", systemImage: "person.2").font(.caption)
                                }
                            }
                        } else {
                            ProviderOpportunityRow(opportunity: opportunity)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
            .navigationTitle(
                "Opportunities"
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button {

                        showCreateOpportunity =
                            true

                    } label: {

                        Image(
                            systemName:
                                "plus"
                        )
                    }
                }
            }
            .task {

                await opportunityService
                    .fetchOpportunities(
                        organizationID:
                            organization.id
                    )
            }
            .refreshable {

                await opportunityService
                    .fetchOpportunities(
                        organizationID:
                            organization.id
                    )
            }
            .sheet(
                isPresented:
                    $showCreateOpportunity
            ) {

                CreateOpportunityView(
                    organization:
                        organization,
                    opportunityService:
                        opportunityService
                )
            }
        }
        .opportunity313PageBackground()
    }
}


// MARK: - Provider Opportunity Row

struct ProviderOpportunityRow: View {

    let opportunity: Opportunity

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack {

                Text(
                    opportunity.category
                        .uppercased()
                )
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(
                    .secondary
                )

                Spacer()

                Text(
                    statusLabel
                )
                .font(.caption)
                .fontWeight(.semibold)
                .padding(
                    .horizontal,
                    9
                )
                .padding(
                    .vertical,
                    5
                )
                .background(
                    Color(
                        .secondarySystemBackground
                    )
                )
                .clipShape(
                    Capsule()
                )
            }

            Text(
                opportunity.title
            )
            .font(.headline)

            Text(
                opportunity.summary
            )
            .font(.subheadline)
            .foregroundStyle(
                .secondary
            )
            .lineLimit(2)

            Label(
                opportunity.startDisplayText,
                systemImage:
                    "calendar"
            )
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .vertical,
            6
        )
    }


    private var statusLabel: String {

        opportunity.organizationApprovalStatus
    }
}
