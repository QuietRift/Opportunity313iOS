//
//  DiscoverView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct DiscoverView: View {

    @StateObject private var opportunityService =
        OpportunityService()

    @EnvironmentObject private var savedService:
        SavedOpportunityService

    @EnvironmentObject private var authService:
        AuthService

    @State private var searchText = ""

    @State private var selectedCategory: String?
    @State private var selectedAge: Int?
    @State private var selectedGrade: Int?
    @State private var selectedNeighborhood: String?

    @State private var freeOnly = false
    @State private var transportationOnly = false

    @State private var showFilters = false


    var body: some View {

        NavigationStack {

            VStack(spacing: 0) {

                categoryScroller

                Divider()

                content
            }
            .navigationTitle("Discover")
            .searchable(
                text: $searchText,
                prompt: "Search opportunities"
            )
            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button {

                        showFilters = true

                    } label: {

                        Image(
                            systemName:
                                hasActiveFilters
                                ? "line.3.horizontal.decrease.circle.fill"
                                : "line.3.horizontal.decrease.circle"
                        )
                    }
                }
            }
            .sheet(
                isPresented: $showFilters
            ) {

                OpportunityFilterView(
                    selectedAge: $selectedAge,
                    selectedGrade: $selectedGrade,
                    selectedNeighborhood:
                        $selectedNeighborhood,
                    freeOnly: $freeOnly,
                    transportationOnly:
                        $transportationOnly,
                    neighborhoods:
                        neighborhoods
                )
            }
            .task {

                await opportunityService
                    .fetchOpportunities()
            }
            .refreshable {

                await opportunityService
                    .fetchOpportunities()

                if authService.role == "youth" {

                    await savedService
                        .loadSaves()
                }
            }
        }
    }


    // MARK: - Main Content

    @ViewBuilder
    private var content: some View {

        if opportunityService.isLoading {

            Spacer()

            ProgressView(
                "Finding opportunities..."
            )

            Spacer()

        } else if let error =
                    opportunityService.errorMessage {

            Spacer()

            ContentUnavailableView(
                "Unable to Load Opportunities",
                systemImage:
                    "exclamationmark.triangle",
                description:
                    Text(error)
            )

            Spacer()

        } else if filteredOpportunities.isEmpty {

            Spacer()

            ContentUnavailableView(
                "No Opportunities Found",
                systemImage:
                    "magnifyingglass",
                description:
                    Text(
                        "Try changing your search or filters."
                    )
            )

            Spacer()

        } else {

            List {

                ForEach(
                    filteredOpportunities
                ) { opportunity in

                    HStack(
                        alignment: .top,
                        spacing: 12
                    ) {

                        NavigationLink {

                            OpportunityDetailView(
                                opportunity:
                                    opportunity
                            )

                        } label: {

                            OpportunityRow(
                                opportunity:
                                    opportunity
                            )
                        }
                        .accessibilityIdentifier("discoverOpportunityLink")


                        // Youth accounts can save directly.
                        if authService.role == "youth" {

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
                                        savedService
                                            .isSaved(
                                                opportunity.id
                                            )
                                        ? "bookmark.fill"
                                        : "bookmark"
                                )
                                .font(.title3)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(
                                savedService
                                    .isSaved(
                                        opportunity.id
                                    )
                                ? "Remove saved opportunity"
                                : "Save opportunity"
                            )
                        }
                    }
                    .padding(
                        .vertical,
                        4
                    )
                }
            }
            .listStyle(.plain)
        }
    }


    // MARK: - Category Scroller

    private var categoryScroller: some View {

        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {

            HStack(spacing: 10) {

                Button {

                    selectedCategory = nil

                } label: {

                    Text("All")
                        .font(.subheadline)
                        .fontWeight(
                            selectedCategory == nil
                            ? .semibold
                            : .regular
                        )
                        .padding(
                            .horizontal,
                            14
                        )
                        .padding(
                            .vertical,
                            8
                        )
                        .background(
                            selectedCategory == nil
                            ? Color.primary
                            : Color(
                                .secondarySystemBackground
                            )
                        )
                        .foregroundStyle(
                            selectedCategory == nil
                            ? Color(
                                .systemBackground
                            )
                            : Color.primary
                        )
                        .clipShape(
                            Capsule()
                        )
                }
                .buttonStyle(.plain)


                ForEach(
                    categories,
                    id: \.self
                ) { category in

                    Button {

                        selectedCategory =
                            category

                    } label: {

                        Text(category)
                            .font(
                                .subheadline
                            )
                            .fontWeight(
                                selectedCategory ==
                                    category
                                ? .semibold
                                : .regular
                            )
                            .padding(
                                .horizontal,
                                14
                            )
                            .padding(
                                .vertical,
                                8
                            )
                            .background(
                                selectedCategory ==
                                    category
                                ? Color.primary
                                : Color(
                                    .secondarySystemBackground
                                )
                            )
                            .foregroundStyle(
                                selectedCategory ==
                                    category
                                ? Color(
                                    .systemBackground
                                )
                                : Color.primary
                            )
                            .clipShape(
                                Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(
                .horizontal
            )
            .padding(
                .vertical,
                10
            )
        }
    }


    // MARK: - Filtered Opportunities

    private var filteredOpportunities:
        [Opportunity] {

        opportunityService
            .opportunities
            .filter { opportunity in

                matchesSearch(
                    opportunity
                )
                &&
                matchesCategory(
                    opportunity
                )
                &&
                matchesAge(
                    opportunity
                )
                &&
                matchesGrade(
                    opportunity
                )
                &&
                matchesNeighborhood(
                    opportunity
                )
                &&
                matchesFree(
                    opportunity
                )
                &&
                matchesTransportation(
                    opportunity
                )
            }
    }


    // MARK: - Search

    private func matchesSearch(
        _ opportunity: Opportunity
    ) -> Bool {

        let query =
            searchText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !query.isEmpty else {
            return true
        }

        let searchableValues: [String] = [

            opportunity.title,
            opportunity.summary,
            opportunity.category,
            opportunity.opportunityType,
            opportunity.locationName,
            opportunity.city,
            opportunity.neighborhood ?? ""
        ]

        return searchableValues
            .contains { value in

                value.localizedCaseInsensitiveContains(
                    query
                )
            }
    }


    // MARK: - Category

    private func matchesCategory(
        _ opportunity: Opportunity
    ) -> Bool {

        guard let selectedCategory else {
            return true
        }

        return opportunity.category ==
            selectedCategory
    }


    // MARK: - Age

    private func matchesAge(
        _ opportunity: Opportunity
    ) -> Bool {

        guard let selectedAge else {
            return true
        }

        if let minimum =
            opportunity.ageMin,
           selectedAge < minimum {

            return false
        }

        if let maximum =
            opportunity.ageMax,
           selectedAge > maximum {

            return false
        }

        return true
    }


    // MARK: - Grade

    private func matchesGrade(
        _ opportunity: Opportunity
    ) -> Bool {

        guard let selectedGrade else {
            return true
        }

        if let minimum =
            opportunity.gradeMin,
           selectedGrade < minimum {

            return false
        }

        if let maximum =
            opportunity.gradeMax,
           selectedGrade > maximum {

            return false
        }

        return true
    }


    // MARK: - Neighborhood

    private func matchesNeighborhood(
        _ opportunity: Opportunity
    ) -> Bool {

        guard let selectedNeighborhood else {
            return true
        }

        return opportunity.neighborhood ==
            selectedNeighborhood
    }


    // MARK: - Free

    private func matchesFree(
        _ opportunity: Opportunity
    ) -> Bool {

        guard freeOnly else {
            return true
        }

        return opportunity.isFree
    }


    // MARK: - Transportation

    private func matchesTransportation(
        _ opportunity: Opportunity
    ) -> Bool {

        guard transportationOnly else {
            return true
        }

        guard let transportation =
                opportunity.transportation else {

            return false
        }

        return !transportation
            .localizedCaseInsensitiveContains(
                "no transportation"
            )
    }


    // MARK: - Categories

    private var categories: [String] {

        Array(
            Set(
                opportunityService
                    .opportunities
                    .map {
                        $0.category
                    }
            )
        )
        .sorted()
    }


    // MARK: - Neighborhoods

    private var neighborhoods:
        [String] {

        Array(
            Set(
                opportunityService
                    .opportunities
                    .compactMap {
                        $0.neighborhood
                    }
            )
        )
        .sorted()
    }


    // MARK: - Active Filters

    private var hasActiveFilters: Bool {

        selectedAge != nil ||
        selectedGrade != nil ||
        selectedNeighborhood != nil ||
        freeOnly ||
        transportationOnly
    }
}


// MARK: - Opportunity Row

struct OpportunityRow: View {

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

                if opportunity.isFree {

                    Text("FREE")
                        .font(.caption)
                        .fontWeight(.bold)
                }
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
            .lineLimit(2)


            HStack(spacing: 14) {

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
        }
        .padding(
            .vertical,
            6
        )
    }
}
