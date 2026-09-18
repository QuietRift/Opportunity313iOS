//
//  ParentHomeView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ParentHomeView: View {

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

                        Text("Parent Dashboard")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(
                            "Help your family discover what's next."
                        )
                        .foregroundStyle(.secondary)
                    }

                    ParentDashboardCard(
                        title: "Your Children",
                        description:
                            "Manage youth profiles and interests.",
                        icon: "person.2.fill"
                    )

                    ParentDashboardCard(
                        title: "Saved Opportunities",
                        description:
                            "Keep track of programs your family is considering.",
                        icon: "bookmark.fill"
                    )

                    ParentDashboardCard(
                        title: "Upcoming Deadlines",
                        description:
                            "Stay ahead of registrations and important dates.",
                        icon:
                            "calendar.badge.exclamationmark"
                    )
                }
                .padding()
            }
        }
    }
}


struct ParentDashboardCard: View {

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
