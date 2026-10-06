//
//  ProviderHomeView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ProviderHomeView: View {

    @Environment(\.colorScheme) private var colorScheme

    let organization: Organization
    @StateObject private var submissions = ProviderOpportunityService()
    @State private var showSubmit = false

    var onOpportunities: () -> Void = {}
    var onEvents: () -> Void = {}
    var onAccount: () -> Void = {}

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {

                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {

                        Text("Opportunity313")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Organization Dashboard")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(
                            organization.name
                        )
                        .foregroundStyle(.secondary)
                    }

                    Label("Verification: \(organization.verificationStatus.capitalized)", systemImage: "checkmark.shield")
                    Text("Every submission is reviewed by an administrator before it becomes public.")
                        .foregroundStyle(.secondary)
                    Button { showSubmit = true } label: {
                        Label("Submit Opportunity", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity).padding(8)
                    }.buttonStyle(.borderedProminent)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Submission Status").font(.headline)
                        if submissions.isLoading { ProgressView("Loading submissions…") }
                        else if let error = submissions.errorMessage {
                            Text(error).foregroundStyle(.red)
                            Button("Try Again") { Task { await reload() } }
                        } else {
                            ForEach(["Pending", "Approved", "Rejected"], id: \.self) { status in
                                LabeledContent(status, value: "\(submissions.opportunities.filter { $0.organizationApprovalStatus == status }.count)")
                            }
                        }
                    }
                    Button(action: onOpportunities) {
                        ProviderDashboardCard(
                            title: "Opportunities",
                            description:
                                "Create and manage youth programs.",
                            icon:
                                "list.bullet.rectangle"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("providerOpportunitiesShortcut")

                    Button(action: onEvents) {
                        ProviderDashboardCard(
                            title: "Events",
                            description:
                                "Manage upcoming events and activities.",
                            icon: "calendar"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("providerEventsShortcut")

                    Button(action: onAccount) {
                        ProviderDashboardCard(
                            title: "Organization Profile",
                            description:
                                "View and edit your organization’s information.",
                            icon:
                                "person.crop.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("providerAccountShortcut")
                }
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
        }
        .opportunity313PageBackground()
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showSubmit) {
            CreateOpportunityView(organization: organization, opportunityService: submissions)
        }
    }
    private func reload() async { await submissions.fetchOpportunities(organizationID: organization.id) }
}


struct ProviderDashboardCard: View {

    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let description: String
    let icon: String

    var body: some View {

        HStack(spacing: 16) {

            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Opportunity313Brand.accent)
                .frame(width: 44, height: 44)
                .background(Opportunity313Brand.accent.opacity(0.12), in: Circle())

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Opportunity313Brand.surface(for: colorScheme))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Opportunity313Brand.accent.opacity(0.16))
        }
    }
}
