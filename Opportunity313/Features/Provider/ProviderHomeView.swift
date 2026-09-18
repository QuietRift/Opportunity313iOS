//
//  ProviderHomeView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ProviderHomeView: View {

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

                        Text("Provider Dashboard")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(
                            "Connect Detroit youth with opportunities."
                        )
                        .foregroundStyle(.secondary)
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
                            title: "Account",
                            description:
                                "View your profile and account settings.",
                            icon:
                                "person.crop.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("providerAccountShortcut")
                }
                .padding()
            }
        }
    }
}


struct ProviderDashboardCard: View {

    let title: String
    let description: String
    let icon: String

    var body: some View {

        HStack(spacing: 16) {

            Image(systemName: icon)
                .font(.title2)
                .frame(width: 38)

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
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }
}
