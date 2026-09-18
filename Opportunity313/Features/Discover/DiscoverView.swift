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

    @StateObject private var profileService = YouthProfileService()
    @Binding var recommendedOnly: Bool
    @ScaledMetric private var categoryHeight = 56.0

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

                searchBar

                if authService.role == "youth" {
                    Picker("Discovery", selection: $recommendedOnly) {
                        Text("All Opportunities").tag(false)
                        Text("Recommended for You").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("discoveryMode")
                }
                categoryScroller
                    .frame(height: categoryHeight)
                    .accessibilityIdentifier("categorySelection")
                Divider()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
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

                await opportunityService.fetchOpportunities()
                if authService.role == "youth" { await profileService.fetchCurrentProfile() }
            }
        }
    }


    // Search stays outside the scrolling opportunity list.
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search opportunities", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("discoverSearch")
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                        recommendedOnly && profileService.currentProfile?.interests.isEmpty != false
                        ? "Choose interests in your profile to see recommendations."
                        : "Try changing your search or filters."
                    )
            )

            Spacer()

        } else {

            List {

                ForEach(resultCategories, id: \.self) { category in
                    Section {
                        ForEach(
                            groupedOpportunities[category] ?? []
                        ) { opportunity in

                            RecommendationCard(opportunity: opportunity,
                                               showsCategory: false,
                                               allowsSave: authService.role == "youth")
                                .accessibilityIdentifier("discoverOpportunityLink")
                                .frame(maxWidth: 760)
                                .frame(maxWidth: .infinity)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                        }
                    } header: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.orange).frame(width: 4, height: 24)
                            Text(category).font(.title3.bold()).foregroundStyle(.primary)
                            Spacer()
                        }
                        .textCase(nil)
                        .padding(.vertical, 12)
                    }
                }
            }
            .listStyle(.plain)
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
                        .fixedSize()
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
                            .fixedSize()
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
                    .accessibilityIdentifier("category_" + category)
                }
            }
            .padding(
                .horizontal
            )
            .frame(height: categoryHeight)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .clipped()
    }


    private var groupedOpportunities: [String: [Opportunity]] {
        Dictionary(grouping: filteredOpportunities, by: \.category)
    }

    private var resultCategories: [String] {
        groupedOpportunities.keys.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    // MARK: - Filtered Opportunities

    private var filteredOpportunities:
        [Opportunity] {

        opportunityService
            .opportunities
            .filter { opportunity in

                (!recommendedOnly || opportunity.matchesRecommendation(for: profileService.currentProfile))
                && matchesSearch(
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
