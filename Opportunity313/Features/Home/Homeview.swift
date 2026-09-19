import SwiftUI

private struct OpportunityCardSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    private var fill: Color {
        Opportunity313Brand.surface(for: colorScheme)
    }

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        colorScheme == .dark
                            ? Opportunity313Brand.accent.opacity(0.28)
                            : Color(.separator).opacity(0.30),
                        lineWidth: colorScheme == .dark ? 1.25 : 1
                    )
            }
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.35)
                    : Color.black.opacity(0.08),
                radius: colorScheme == .dark ? 8 : 5,
                y: 3
            )
    }
}

extension View {
    func opportunityCardSurface(cornerRadius: CGFloat = 20) -> some View {
        modifier(OpportunityCardSurface(cornerRadius: cornerRadius))
    }
}

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var profileService = YouthProfileService()
    @StateObject private var opportunityService = OpportunityService()
    @EnvironmentObject var savedService: SavedOpportunityService
    @State private var showUpdates = false
    var onSeeMore: () -> Void = {}
    var onDiscover: () -> Void = {}
    var onProfile: () -> Void = {}
    private let accent = Opportunity313Brand.accent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if let error = opportunityService.errorMessage {
                        Text(error).foregroundStyle(.secondary)
                        Button("Try Again") { Task { await opportunityService.fetchOpportunities() } }
                    }
                    featuredSection
                    interestSection
                    recommendedSection
                    deadlineSection
                }
                .padding(20)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            .background(Opportunity313Brand.canvas(for: colorScheme).opacity(colorScheme == .dark ? 1 : 0.34))
            .toolbar(.hidden, for: .navigationBar)
            .task { await reload() }
            .refreshable { await reload() }
            .sheet(isPresented: $showUpdates) {
                NavigationStack {
                    ScrollView { deadlineSection.padding(20) }
                        .background(
                            Opportunity313Brand.canvas(for: colorScheme)
                                .ignoresSafeArea()
                        )
                        .navigationTitle("Upcoming Deadlines")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showUpdates = false } } }
                }
                .opportunity313PageBackground()
            }
        }
    }

    private func reload() async {
        await profileService.fetchCurrentProfile()
        await opportunityService.fetchOpportunities()
        await savedService.loadSaves()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onProfile) {
                ZStack {
                    Circle().fill(accent.opacity(0.18))
                    Image(systemName: "person.crop.circle.fill").font(.system(size: 36)).foregroundStyle(accent)
                }.frame(width: 54, height: 54)
            }.accessibilityLabel("Open your profile")
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back").font(.subheadline).foregroundStyle(.secondary)
                Text(profileService.currentProfile?.firstName ?? "Opportunity313").font(.title3.bold())
            }
            Spacer(minLength: 4)
            headerButton("magnifyingglass", label: "Search opportunities", action: onDiscover)
            headerButton("bell", label: "View upcoming deadlines") { showUpdates = true }
        }
    }

    private func headerButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().stroke(Color(.separator).opacity(0.4)))
        }.accessibilityLabel(label)
    }

    private var featured: [Opportunity] {
        Array((recommendedOpportunities.isEmpty ? eligibleOpportunities : recommendedOpportunities).prefix(4))
    }

    @ViewBuilder private var featuredSection: some View {
        if opportunityService.isLoading && featured.isEmpty {
            ProgressView("Finding opportunities…").frame(maxWidth: .infinity)
        } else if !featured.isEmpty {
            TabView {
                ForEach(featured) { opportunity in
                    NavigationLink { OpportunityDetailView(opportunity: opportunity) } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DISCOVER OPPORTUNITIES").font(.caption.bold())
                                Text(opportunity.title)
                                    .font(.title2.bold())
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                                Text(opportunity.neighborhood ?? opportunity.city).font(.subheadline)
                                Text("Explore opportunity  →").font(.subheadline.bold())
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(.white.opacity(0.2), in: Capsule())
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.white).padding(24).padding(.bottom, 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .background {
                            GeometryReader { geometry in
                                Image(opportunityImage(opportunity.category)).resizable().scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                                    .overlay(LinearGradient(colors: [.black.opacity(0.80), .black.opacity(0.25)], startPoint: .leading, endPoint: .trailing))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    }.buttonStyle(.plain).padding(.horizontal, 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: featured.count > 1 ? .always : .never))
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 390 : 260)
            .accessibilityLabel("Featured opportunities")
        }
    }

    @ViewBuilder private var interestSection: some View {
        if let profile = profileService.currentProfile, !profile.interests.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Interests").font(.title2.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(profile.interests, id: \.self) { interest in
                            VStack(spacing: 10) {
                                Image(systemName: interestSymbol(interest)).font(.system(size: 25, weight: .medium))
                                    .foregroundStyle(accent).frame(width: 64, height: 64)
                                    .background(accent.opacity(0.08), in: Circle())
                                    .overlay(Circle().stroke(accent.opacity(0.15)))
                                Text(interest).font(.caption.weight(.medium)).multilineTextAlignment(.center).frame(width: 86)
                            }
                        }
                    }
                }
            }
        }
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recommended for You").font(.title2.bold())
                Spacer()
                Button("See more", action: onSeeMore).font(.subheadline).tint(accent)
                    .accessibilityIdentifier("seeMoreRecommendations")
            }
            if !opportunityService.isLoading && recommendedOpportunities.isEmpty {
                Text("More matches are coming. Explore Discover for other opportunities.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(recommendedOpportunities.prefix(3)) { opportunity in
                            RecommendationCard(opportunity: opportunity).frame(width: 270)
                        }
                    }.padding(.bottom, 2)
                }
            }
        }
    }

    private var deadlineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Deadlines Coming Up").font(.title2.bold())
            if upcomingDeadlines.isEmpty {
                Text("No upcoming deadlines right now.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(upcomingDeadlines.prefix(3)) { opportunity in
                            NavigationLink { OpportunityDetailView(opportunity: opportunity) } label: {
                                DeadlineCard(opportunity: opportunity).frame(width: 270)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.bottom, 2)
                }
            }
        }
    }

    private var recommendedOpportunities: [Opportunity] {
        eligibleOpportunities.filter { $0.matchesRecommendation(for: profileService.currentProfile) }
    }
    private var eligibleOpportunities: [Opportunity] {
        guard let profile = profileService.currentProfile else { return [] }
        return opportunityService.opportunities.filter { $0.matchesEligibility(for: profile) }
    }
    private var upcomingDeadlines: [Opportunity] {
        eligibleOpportunities.filter { ($0.deadline ?? .distantPast) > Date() }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }
}

private func opportunityImage(_ category: String) -> String {
    switch category.lowercased() {
    case "technology", "skilled trades": return "OpportunityTechnology"
    case "arts", "media", "film": return "OpportunityArts"
    case "culinary": return "OpportunityCulinary"
    case "sports": return "OpportunitySports"
    default: return "OpportunityLearning"
    }
}

private func interestSymbol(_ category: String) -> String {
    switch category.lowercased() {
    case "arts": return "paintpalette.fill"
    case "technology": return "laptopcomputer"
    case "financial literacy": return "dollarsign.circle.fill"
    case "media", "film": return "film.fill"
    case "skilled trades": return "hammer.fill"
    case "culinary": return "fork.knife"
    case "academic support": return "book.fill"
    case "sports": return "sportscourt.fill"
    default: return "sparkles"
    }
}

struct RecommendationCard: View {
    @EnvironmentObject var savedService: SavedOpportunityService
    @EnvironmentObject var familySaveService: FamilySaveService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let opportunity: Opportunity
    var showsCategory = true
    var allowsSave = true
    var managedYouthProfileID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                NavigationLink {
                    OpportunityDetailView(
                        opportunity: opportunity,
                        managedYouthProfileID: managedYouthProfileID
                    )
                } label: {
                    GeometryReader { geometry in
                        Image(opportunityImage(opportunity.category)).resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: 150).clipped()
                            .accessibilityHidden(true)
                    }.frame(height: 150)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(opportunity.title)")
                .accessibilityHint("Opens opportunity details")
                if allowsSave {
                Button {
                    Task {
                        if let managedYouthProfileID {
                            await familySaveService.toggleSave(
                                opportunityID: opportunity.id,
                                for: managedYouthProfileID
                            )
                        } else {
                            await savedService.toggleSave(opportunityID: opportunity.id)
                        }
                    }
                } label: {
                    Image(systemName: cardIsSaved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(Opportunity313Brand.accent).frame(width: 44, height: 44)
                        .background(.background, in: Circle())
                }.buttonStyle(.plain).padding(10)
                    .accessibilityLabel(cardIsSaved ? "Unsave \(opportunity.title)" : "Save \(opportunity.title)")
                }
            }
            NavigationLink {
                OpportunityDetailView(
                    opportunity: opportunity,
                    managedYouthProfileID: managedYouthProfileID
                )
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    if showsCategory {
                        Text(opportunity.category).font(.caption.weight(.semibold)).foregroundStyle(Opportunity313Brand.accent)
                    }
                    Text(opportunity.title)
                        .font(.headline)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 64, alignment: .topLeading)
                    Label(opportunity.neighborhood ?? opportunity.city, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.82))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    HStack {
                        Text(opportunity.startDateDisplayText).font(.caption)
                        Spacer()
                        Text(opportunity.isFree ? "FREE" : (Double(opportunity.costCents) / 100).formatted(.currency(code: "USD")))
                            .font(.subheadline.bold())
                    }
                }.foregroundStyle(.primary).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
        }
        .opportunityCardSurface()
    }

    private var cardIsSaved: Bool {
        if let managedYouthProfileID {
            return familySaveService.isSaved(
                opportunityID: opportunity.id,
                for: managedYouthProfileID
            )
        }
        return savedService.isSaved(opportunity.id)
    }
}

// MARK: - Deadline Card

struct DeadlineCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let opportunity: Opportunity

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let daysRemaining = opportunity.deadline.map {
                Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: context.date),
                                                to: Calendar.current.startOfDay(for: $0)).day ?? 0
            }
            let urgent = opportunity.deadline.map { $0 > context.date } == true
                && daysRemaining.map { (0...5).contains($0) } == true

            VStack(alignment: .leading, spacing: 12) {
                Text(opportunity.category).font(.caption.weight(.semibold))
                    .foregroundStyle(urgent ? Color.red : Opportunity313Brand.accent)
                Text(opportunity.title)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 64, alignment: .topLeading)
                if let deadline = opportunity.deadline {
                    Text("Apply by \(deadline.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(urgent ? Color.red : Color.primary)
                }
                Text(opportunity.neighborhood ?? opportunity.city)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.82))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                HStack {
                    if let days = daysRemaining {
                        Text(days <= 0 ? "Due today" : "\(days) \(days == 1 ? "day" : "days") left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(urgent ? Color.red : Color.secondary)
                    }
                    Spacer()
                    Text(opportunity.isFree ? "FREE" : (Double(opportunity.costCents) / 100).formatted(.currency(code: "USD")))
                        .font(.subheadline.bold())
                }
            }
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(urgent ? Color.red.opacity(0.07) : Color.clear)
            .opportunityCardSurface()
            .overlay {
                if urgent {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red.opacity(0.55), lineWidth: 1.25)
                }
            }
        }
    }
}
