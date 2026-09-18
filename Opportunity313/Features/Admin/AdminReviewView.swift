//
//  AdminReviewView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct AdminReviewView: View {

    @StateObject private var adminService =
        AdminService()

    var body: some View {

        NavigationStack {

            Group {

                if adminService.isLoading &&
                    adminService
                        .pendingOpportunities
                        .isEmpty {

                    ProgressView(
                        "Loading submissions..."
                    )

                } else if let error = adminService.errorMessage {
                    ContentUnavailableView("Unable to Load Submissions", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if adminService
                    .pendingOpportunities
                    .isEmpty {

                    ContentUnavailableView(
                        "Review Queue Clear",
                        systemImage:
                            "checkmark.circle",
                        description: Text(
                            "There are no provider opportunities waiting for review."
                        )
                    )

                } else {

                    List {

                        ForEach(
                            adminService
                                .pendingOpportunities
                        ) { opportunity in

                            NavigationLink {

                                AdminOpportunityDetailView(
                                    opportunity:
                                        opportunity,
                                    adminService:
                                        adminService
                                )

                            } label: {

                                AdminOpportunityCard(
                                    opportunity:
                                        opportunity
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(
                "Review Queue"
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button {

                        Task {

                            await adminService
                                .fetchPendingOpportunities()
                        }

                    } label: {

                        Image(
                            systemName:
                                "arrow.clockwise"
                        )
                    }
                }
            }
            .task {

                await adminService
                    .fetchPendingOpportunities()
            }
            .refreshable {

                await adminService
                    .fetchPendingOpportunities()
            }
            .safeAreaInset(
                edge: .bottom
            ) {

                if let success =
                    adminService
                        .successMessage {

                    Text(success)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding()
                        .frame(
                            maxWidth: .infinity
                        )
                        .background(
                            .regularMaterial
                        )
                }
            }
        }
    }
}


// MARK: - Admin Opportunity Card

struct AdminOpportunityCard: View {

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


                Text("PENDING REVIEW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(
                        .horizontal,
                        8
                    )
                    .padding(
                        .vertical,
                        4
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
            .foregroundStyle(
                .primary
            )


            Text(
                opportunity.summary
            )
            .font(.subheadline)
            .foregroundStyle(
                .secondary
            )
            .lineLimit(3)


            HStack(spacing: 14) {

                Label(
                    opportunity.startsAt
                        .formatted(
                            date:
                                .abbreviated,
                            time:
                                .shortened
                        ),
                    systemImage:
                        "calendar"
                )


                if let neighborhood =
                    opportunity.neighborhood {

                    Label(
                        neighborhood,
                        systemImage:
                            "mappin.and.ellipse"
                    )
                }
            }
            .font(.caption)
            .foregroundStyle(
                .secondary
            )


            HStack {

                Label(
                    "Review submission",
                    systemImage:
                        "doc.text.magnifyingglass"
                )
                .font(.caption)
                .fontWeight(.medium)

                Spacer()

                Image(
                    systemName:
                        "chevron.right"
                )
                .font(.caption)
            }
            .foregroundStyle(
                .secondary
            )
        }
        .padding(
            .vertical,
            6
        )
    }
}
