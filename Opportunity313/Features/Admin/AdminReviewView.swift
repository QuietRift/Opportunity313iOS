//
//  AdminReviewView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct AdminReviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var adminService = AdminService()
    @State private var selectedOpportunityID: UUID?

    var body: some View {
        NavigationSplitView {
            Group {
                if adminService.isLoading && adminService.pendingOpportunities.isEmpty {
                    ProgressView("Loading submissions...")
                } else if let error = adminService.errorMessage {
                    VStack(spacing: 16) {
                        ContentUnavailableView("Unable to Load Submissions", systemImage: "exclamationmark.triangle", description: Text(error))
                        Button("Try Again") { Task { await adminService.fetchPendingOpportunities() } }
                    }
                } else if adminService.pendingOpportunities.isEmpty {
                    ContentUnavailableView("Review Queue Clear", systemImage: "checkmark.circle", description: Text("There are no provider opportunities waiting for review."))
                } else {
                    List(selection: $selectedOpportunityID) {
                        ForEach(adminService.pendingOpportunities) { opportunity in
                            NavigationLink(value: opportunity.id) {
                                AdminOpportunityCard(opportunity: opportunity)
                            }
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
            .navigationTitle("Review Queue")
            .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 440)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await adminService.fetchPendingOpportunities() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh review queue")
                }
            }
            .refreshable { await adminService.fetchPendingOpportunities() }
        } detail: {
            if let opportunity = adminService.pendingOpportunities.first(where: { $0.id == selectedOpportunityID }) {
                AdminOpportunityDetailView(opportunity: opportunity, adminService: adminService)
                    .id(opportunity.id)
            } else {
                ContentUnavailableView("Select a Submission", systemImage: "doc.text.magnifyingglass", description: Text("Choose an opportunity from the review queue to inspect its details."))
            }
        }
        .opportunity313PageBackground()
        .navigationSplitViewStyle(.balanced)
        .task { await adminService.fetchPendingOpportunities() }
        .onChange(of: adminService.pendingOpportunities.map(\.id)) { _, ids in
            if let selectedOpportunityID, !ids.contains(selectedOpportunityID) { self.selectedOpportunityID = nil }
        }
        .safeAreaInset(edge: .bottom) {
            if let success = adminService.successMessage {
                Text(success).font(.subheadline).fontWeight(.medium)
                    .padding().frame(maxWidth: .infinity).background(.regularMaterial)
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
                    opportunity.startDisplayText,
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
