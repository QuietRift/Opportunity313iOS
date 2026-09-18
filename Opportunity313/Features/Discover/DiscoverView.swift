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
    @StateObject private var childService = ParentManagedYouthService()
    @Binding var recommendedOnly: Bool
    @ScaledMetric private var categoryHeight = 50.0

    @State private var searchText = ""

    @State private var selectedCategory: String?
    @State private var selectedAge: Int?
    @State private var selectedGrade: Int?
    @State private var selectedNeighborhood: String?

    @State private var freeOnly = false
    @State private var transportationOnly = false

    @State private var showFilters = false
    @State private var selectedChildID: UUID?


    var body: some View {

        NavigationStack {

            VStack(spacing: 0) {

                discoverHeader
                if authService.role == "parent" { childSelector }
                searchBar

                if authService.role == "youth" {
                    HStack(spacing: 4) {
                        discoveryModeButton("All Opportunities", recommended: false)
                        discoveryModeButton("Recommended for You", recommended: true)
                    }
                    .padding(4)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("discoveryMode")
                }
                categoryScroller
                    .frame(height: categoryHeight)
                    .accessibilityIdentifier("categorySelection")
                Divider()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar(.hidden, for: .navigationBar)
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
                if authService.role == "parent" {
                    await childService.fetchChildren()
                    if selectedChildID == nil { selectedChildID = childService.children.first?.id }
                }
            }
        }
    }

    @ViewBuilder
    private var childSelector: some View {
        if childService.children.isEmpty {
            Label("Add a child profile to see tailored opportunities", systemImage: "person.badge.plus")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text("Showing opportunities for").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Picker("Child", selection: $selectedChildID) {
                    ForEach(childService.children) { child in
                        Text(child.firstName).tag(child.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }


    private func discoveryModeButton(_ title: String, recommended: Bool) -> some View {
        Button { recommendedOnly = recommended } label: {
            Text(title).font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(recommendedOnly == recommended ? Color.white : Color.primary)
                .background(recommendedOnly == recommended ? Color.orange : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(recommendedOnly == recommended ? .isSelected : [])
    }

    private var discoverHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Discover").font(.title2.bold())
                Text("Find what's next in Detroit.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button { showFilters = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(hasActiveFilters ? Color.white : Color.orange)
                    .frame(width: 44, height: 44)
                    .background(hasActiveFilters ? Color.orange : Color.orange.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(Color.orange.opacity(0.2)))
            }
            .accessibilityLabel(hasActiveFilters ? "Filters applied. Edit filters" : "Filter opportunities")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator).opacity(0.15)))
        .padding(.horizontal)
        .padding(.vertical, 4)
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
                        if selectedCategory != nil {
                            ForEach(groupedOpportunities[category] ?? []) { opportunity in
                                RecommendationCard(opportunity: opportunity,
                                                   showsCategory: false,
                                                   allowsSave: authService.role == "youth")
                                    .accessibilityIdentifier("discoverOpportunityLink")
                                    .frame(maxWidth: 760)
                                    .frame(maxWidth: .infinity)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(groupedOpportunities[category] ?? []) { opportunity in
                                    RecommendationCard(opportunity: opportunity,
                                                       showsCategory: false,
                                                       allowsSave: authService.role == "youth")
                                        .accessibilityIdentifier("discoverOpportunityLink")
                                        .frame(width: 270)
                                }
                            }.padding(.vertical, 2)
                        }
                        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
                        }
                    } header: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.orange).frame(width: 4, height: 24)
                            Text(category).font(.title3.bold()).foregroundStyle(.primary)
                            Spacer()
                            if selectedCategory == nil {
                            Button {
                                selectedCategory = category
                            } label: {
                                Text("See all").font(.subheadline).foregroundStyle(.orange)
                            }
                            .accessibilityLabel("See all \(category) opportunities")
                            }
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
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button { selectedCategory = nil } label: {
                        categoryLabel("All", selected: selectedCategory == nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedCategory == nil ? .isSelected : [])
                    ForEach(categories, id: \.self) { category in
                        Button { selectedCategory = category } label: {
                            categoryLabel(category, selected: selectedCategory == category)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                        .id(category)
                        .accessibilityIdentifier("category_" + category)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: categoryHeight)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .clipped()
            .onChange(of: selectedCategory) { _, category in
                if let category { withAnimation { proxy.scrollTo(category, anchor: .center) } }
            }
        }
    }

    private func categoryLabel(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.subheadline.weight(selected ? .semibold : .medium))
            .fixedSize()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? Color.orange : Color(.secondarySystemBackground), in: Capsule())
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

                (activeProfile.map { opportunity.matchesEligibility(for: $0) } ?? (authService.role != "parent"))
                && (!recommendedOnly || opportunity.matchesRecommendation(for: activeProfile))
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

    private var activeProfile: YouthProfile? {
        if authService.role == "parent" {
            return childService.children.first { $0.id == selectedChildID }
        }
        return profileService.currentProfile
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
