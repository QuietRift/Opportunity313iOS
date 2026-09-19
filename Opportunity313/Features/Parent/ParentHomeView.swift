//
//  ParentHomeView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ParentHomeView: View {

    @Environment(\.colorScheme) private var colorScheme

    var onChildren: () -> Void = {}
    var onSaved: () -> Void = {}
    var onDeadlines: () -> Void = {}

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {

                    dashboardHeader

                    Button(action: onChildren) {
                        ParentDashboardCard(
                            title: "Your Children",
                            description:
                                "Manage youth profiles and interests.",
                            icon: "person.2.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("parentChildrenShortcut")

                    Button(action: onSaved) {
                        ParentDashboardCard(
                            title: "Saved Opportunities",
                            description:
                                "Keep track of programs your family is considering.",
                            icon: "bookmark.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("parentSavedShortcut")

                    Button(action: onDeadlines) {
                        ParentDashboardCard(
                            title: "Upcoming Deadlines",
                            description:
                                "Stay ahead of registrations and important dates.",
                            icon:
                                "calendar.badge.exclamationmark"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("parentDeadlinesShortcut")
                }
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(Opportunity313Brand.canvas(for: colorScheme))
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BUILT FOR DETROIT FAMILIES")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(Opportunity313Brand.accent)

            Text("Parent Dashboard")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Help your family discover what's next.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Opportunity313Brand.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Opportunity313Brand.accent.opacity(0.35))
        }
    }
}


struct ParentDashboardCard: View {

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
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Opportunity313Brand.accent.opacity(0.16))
        }
        .shadow(color: Opportunity313Brand.deepBlue.opacity(0.08), radius: 12, y: 6)
    }
}
