//
//  Homeview.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct HomeView: View {

    @StateObject private var profileService =
        YouthProfileService()

    @StateObject private var opportunityService =
        OpportunityService()

    @EnvironmentObject var savedService:
        SavedOpportunityService

    var onSeeMore: () -> Void = {}

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 28
                ) {

                    header

                    interestSection

                    recommendedSection

                    deadlineSection

                    Spacer(minLength: 30)
                }
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationBarHidden(true)
            .task {

                await profileService
                    .fetchCurrentProfile()

                await opportunityService
                    .fetchOpportunities()
            }
            .refreshable {

                await profileService
                    .fetchCurrentProfile()

                await opportunityService
                    .fetchOpportunities()

                await savedService
                    .loadSaves()
            }
        }
    }


    // MARK: - Header

    private var header: some View {

        VStack(
            alignment: .leading,
            spacing: 6
        ) {

            Text(greeting)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(
                profileService.currentProfile == nil
                    ? "Opportunity313"
                    : "Hey, \(profileService.currentProfile!.firstName)"
            )
            .font(.largeTitle)
            .fontWeight(.bold)

            Text("Find what's next in Detroit.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }


    // MARK: - Interests

    @ViewBuilder
    private var interestSection: some View {

        if let profile =
            profileService.currentProfile,
           !profile.interests.isEmpty {

            VStack(
                alignment: .leading,
                spacing: 12
            ) {

                Text("Your Interests")
                    .font(.title2)
                    .fontWeight(.bold)

                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {

                    HStack(spacing: 10) {

                        ForEach(
                            profile.interests,
                            id: \.self
                        ) { interest in

                            Text(interest)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(
                                    .horizontal,
                                    14
                                )
                                .padding(
                                    .vertical,
                                    8
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
                    }
                }
            }
        }
    }


    // MARK: - Recommended

    private var recommendedSection: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            HStack {

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text("Recommended for You")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(
                        "Based on your interests"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                Button("See more", action: onSeeMore)
                    .accessibilityIdentifier("seeMoreRecommendations")
            }

            if opportunityService.isLoading {

                ProgressView()

            } else if recommendedOpportunities.isEmpty {

                ContentUnavailableView(
                    "More Opportunities Coming",
                    systemImage: "sparkles",
                    description: Text(
                        "We couldn't find a current match for your selected interests."
                    )
                )

            } else {

                ForEach(
                    recommendedOpportunities.prefix(3)
                ) { opportunity in

                    NavigationLink {

                        OpportunityDetailView(
                            opportunity:
                                opportunity
                        )

                    } label: {

                        RecommendationCard(
                            opportunity:
                                opportunity
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    // MARK: - Deadlines

    private var deadlineSection: some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text("Deadlines Coming Up")
                .font(.title2)
                .fontWeight(.bold)

            if upcomingDeadlines.isEmpty {

                Text(
                    "No upcoming deadlines right now."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

            } else {

                ForEach(
                    upcomingDeadlines.prefix(3)
                ) { opportunity in

                    NavigationLink {

                        OpportunityDetailView(
                            opportunity:
                                opportunity
                        )

                    } label: {

                        DeadlineCard(
                            opportunity:
                                opportunity
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    // MARK: - Recommendations

    private var recommendedOpportunities:
        [Opportunity] {

        opportunityService.opportunities.filter {
            $0.matchesRecommendation(for: profileService.currentProfile)
        }
    }


    // MARK: - Upcoming Deadlines

    private var upcomingDeadlines:
        [Opportunity] {

        opportunityService.opportunities
            .filter {

                guard let deadline =
                    $0.deadline else {

                    return false
                }

                return deadline > Date()
            }
            .sorted {

                guard let first =
                    $0.deadline,
                      let second =
                    $1.deadline else {

                    return false
                }

                return first < second
            }
    }


    // MARK: - Greeting

    private var greeting: String {

        let hour =
            Calendar.current.component(
                .hour,
                from: Date()
            )

        switch hour {

        case 5..<12:
            return "Good morning"

        case 12..<17:
            return "Good afternoon"

        default:
            return "Good evening"
        }
    }
}


// MARK: - Recommendation Card

struct RecommendationCard: View {

    @EnvironmentObject var savedService:
        SavedOpportunityService

    let opportunity: Opportunity

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                Text(
                    opportunity.category.uppercased()
                )
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)

                Spacer()

                Button {

                    Task {

                        await savedService
                            .toggleSave(
                                opportunityID:
                                    opportunity.id
                            )
                    }

                } label: {

                    Image(
                        systemName:
                            savedService.isSaved(
                                opportunity.id
                            )
                            ? "bookmark.fill"
                            : "bookmark"
                    )
                }
                .buttonStyle(.borderless)
            }

            Text(opportunity.title)
                .font(.headline)

            Text(opportunity.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {

                Label(
                    opportunity.neighborhood
                        ?? opportunity.city,
                    systemImage:
                        "mappin.and.ellipse"
                )

                Spacer()

                if opportunity.isFree {

                    Text("FREE")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            .font(.caption)
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


// MARK: - Deadline Card

struct DeadlineCard: View {

    let opportunity: Opportunity

    var body: some View {

        HStack(spacing: 14) {

            Image(
                systemName:
                    "calendar.badge.exclamationmark"
            )
            .font(.title2)
            .frame(width: 32)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(opportunity.title)
                    .font(.headline)

                if let deadline =
                    opportunity.deadline {

                    Text(
                        "Apply by \(deadline.formatted(date: .abbreviated, time: .omitted))"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(
                systemName: "chevron.right"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }
}
