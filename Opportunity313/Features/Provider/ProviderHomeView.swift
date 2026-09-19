//
//  ProviderHomeView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ProviderHomeView: View {

    @Environment(\.colorScheme) private var colorScheme

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
    }
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
