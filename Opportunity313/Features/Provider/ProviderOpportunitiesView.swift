//
//  ProviderOpportunitiesView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ProviderOpportunitiesView: View {

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

                        ProviderOpportunityRow(
                            opportunity:
                                opportunity
                        )
                    }
                    .listStyle(.plain)
                }
            }
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

        switch opportunity.status {

        case "pending_review":
            return "Pending Review"

        case "published":
            return "Published"

        case "draft":
            return "Draft"

        case "paused":
            return "Paused"

        case "closed":
            return "Closed"

        default:
            return opportunity.status
                .replacingOccurrences(
                    of: "_",
                    with: " "
                )
                .capitalized
        }
    }
}
