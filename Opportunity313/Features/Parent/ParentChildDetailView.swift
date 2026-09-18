//
//  ParentChildDetailView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ParentChildDetailView: View {

    let child: YouthProfile

    @StateObject private var opportunityService =
        OpportunityService()

    @StateObject private var childAccessService = ChildAccessService()

    @EnvironmentObject var familySaveService:
        FamilySaveService

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 28
            ) {

                // MARK: - Header

                VStack(spacing: 10) {

                    Image(
                        systemName:
                            "person.crop.circle.fill"
                    )
                    .font(
                        .system(size: 80)
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Text(child.firstName)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(
                        "Managed Youth Profile"
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                }
                .frame(
                    maxWidth: .infinity
                )


                // MARK: - Profile

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    Text("Profile")
                        .font(.title2)
                        .fontWeight(.bold)

                    ProfileInfoRow(
                        icon: "person.2",
                        title: "Age Group",
                        value: child.ageBand
                    )

                    if let grade =
                        child.grade {

                        ProfileInfoRow(
                            icon:
                                "graduationcap",
                            title: "Grade",
                            value:
                                grade == 0
                                ? "Kindergarten"
                                : "Grade \(grade)"
                        )
                    }
                }
                .padding()
                .background(
                    Color(
                        .secondarySystemBackground
                    )
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )

                VStack(alignment: .leading, spacing: 14) {
                    Text("Child Access").font(.title2.bold())
                    Text("Create a private sign-in code so \(child.firstName) can use this profile without creating an independent account.")
                        .font(.subheadline).foregroundStyle(.secondary)

                    if let code = childAccessService.generatedCode {
                        Text(code)
                            .font(.system(.title3, design: .monospaced).bold())
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                        Text("Save this code now. For security, it will not be shown again after leaving this screen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    HStack {
                        Button(childAccessService.generatedCode == nil ? "Create Access Code" : "Replace Code") {
                            Task { await childAccessService.generate(for: child.id) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Revoke", role: .destructive) {
                            Task { await childAccessService.revoke(for: child.id) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(childAccessService.isLoading)

                    if let error = childAccessService.errorMessage {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))


                // MARK: - Interests

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {

                    Text("Interests")
                        .font(.title2)
                        .fontWeight(.bold)

                    if child.interests.isEmpty {

                        Text(
                            "No interests selected yet."
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    } else {

                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(
                                        minimum: 130
                                    )
                                )
                            ],
                            spacing: 10
                        ) {

                            ForEach(
                                child.interests,
                                id: \.self
                            ) { interest in

                                Text(interest)
                                    .font(
                                        .subheadline
                                    )
                                    .fontWeight(
                                        .medium
                                    )
                                    .padding(
                                        .horizontal,
                                        12
                                    )
                                    .padding(
                                        .vertical,
                                        10
                                    )
                                    .frame(
                                        maxWidth:
                                            .infinity
                                    )
                                    .background(
                                        Color(
                                            .secondarySystemBackground
                                        )
                                    )
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius:
                                                12
                                        )
                                    )
                            }
                        }
                    }
                }


                Divider()


                // MARK: - Recommendations

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text(
                            "Recommended for \(child.firstName)"
                        )
                        .font(.title2)
                        .fontWeight(.bold)

                        Text(
                            "Based on interests and grade eligibility."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            .secondary
                        )
                    }


                    if opportunityService.isLoading {

                        ProgressView()

                    } else if recommendedOpportunities
                        .isEmpty {

                        ContentUnavailableView(
                            "No Matches Yet",
                            systemImage:
                                "sparkles",
                            description: Text(
                                "We'll show matching opportunities here as new programs are added."
                            )
                        )

                    } else {

                        ForEach(
                            Array(
                                recommendedOpportunities
                                    .prefix(8)
                            )
                        ) { opportunity in

                            HStack(
                                alignment: .center,
                                spacing: 12
                            ) {

                                NavigationLink {

                                    OpportunityDetailView(
                                        opportunity:
                                            opportunity
                                    )

                                } label: {

                                    ParentRecommendationCard(
                                        opportunity:
                                            opportunity
                                    )
                                }
                                .buttonStyle(.plain)


                                Button {

                                    Task {

                                        await familySaveService
                                            .toggleSave(
                                                opportunityID:
                                                    opportunity.id,
                                                for:
                                                    child.id
                                            )
                                    }

                                } label: {

                                    Image(
                                        systemName:
                                            familySaveService
                                                .isSaved(
                                                    opportunityID:
                                                        opportunity.id,
                                                    for:
                                                        child.id
                                                )
                                            ? "bookmark.fill"
                                            : "bookmark"
                                    )
                                    .font(.title3)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(
                                    familySaveService
                                        .isSaved(
                                            opportunityID:
                                                opportunity.id,
                                            for:
                                                child.id
                                        )
                                    ? "Remove from \(child.firstName)'s saved opportunities"
                                    : "Save for \(child.firstName)"
                                )
                            }
                        }
                    }
                }


                if let error =
                    familySaveService.errorMessage {

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }


                Spacer(minLength: 30)
            }
            .padding()
        }
        .navigationTitle(child.firstName)
        .navigationBarTitleDisplayMode(
            .inline
        )
        .task {

            await opportunityService
                .fetchOpportunities()

            await familySaveService
                .loadSaves(
                    for: [
                        child.id
                    ]
                )
        }
        .refreshable {

            await opportunityService
                .fetchOpportunities()

            await familySaveService
                .loadSaves(
                    for: [
                        child.id
                    ]
                )
        }
    }


    // MARK: - Recommendations

    private var recommendedOpportunities:
        [Opportunity] {

        opportunityService
            .opportunities
            .filter { opportunity in

                let interestMatch =
                    child.interests
                        .contains(
                            opportunity.category
                        )

                let gradeMatch =
                    matchesGrade(
                        opportunity
                    )

                return interestMatch &&
                    gradeMatch
            }
            .sorted {

                $0.startsAt <
                $1.startsAt
            }
    }


    // MARK: - Grade Match

    private func matchesGrade(
        _ opportunity: Opportunity
    ) -> Bool {

        guard let grade =
            child.grade else {

            return true
        }

        if let minimum =
            opportunity.gradeMin,
           grade < minimum {

            return false
        }

        if let maximum =
            opportunity.gradeMax,
           grade > maximum {

            return false
        }

        return true
    }
}


// MARK: - Parent Recommendation Card

struct ParentRecommendationCard: View {

    let opportunity: Opportunity

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
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

                if opportunity.isFree {

                    Text("FREE")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }


            Text(opportunity.title)
                .font(.headline)
                .foregroundStyle(.primary)


            Text(opportunity.summary)
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )
                .lineLimit(2)


            HStack {

                Label(
                    opportunity.startsAt
                        .formatted(
                            date:
                                .abbreviated,
                            time:
                                .omitted
                        ),
                    systemImage:
                        "calendar"
                )

                Spacer()

                Label(
                    opportunity.neighborhood
                        ?? opportunity.city,
                    systemImage:
                        "mappin.and.ellipse"
                )
            }
            .font(.caption)
            .foregroundStyle(
                .secondary
            )
        }
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }
}
