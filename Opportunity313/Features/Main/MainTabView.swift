//
//  MainTabView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct MainTabView: View {

    @EnvironmentObject var authService:
        AuthService

    var body: some View {

        Group {

            switch authService.role {

            case "youth":

                YouthTabView()


            case "parent":

                ParentTabView()


            case "provider":

                ProviderTabView()


            case "athletics":
                EventStaffTabView()

            case "admin":

                AdminTabView()


            default:

                ProgressView(
                    "Loading account..."
                )
            }
        }
    }
}


// MARK: - Youth Tabs

struct YouthTabView: View {

    @Environment(\.colorScheme) private var colorScheme

    @EnvironmentObject var savedService:
        SavedOpportunityService

    @State private var selectedTab = 0
    @State private var recommendedOnly = false

    var body: some View {

        TabView(selection: $selectedTab) {

            HomeView(onSeeMore: { recommendedOnly = true; selectedTab = 1 },
                     onDiscover: { recommendedOnly = false; selectedTab = 1 },
                     onProfile: { selectedTab = 4 })
                .tag(0)
                .tabItem {

                    Label(
                        "Home",
                        systemImage:
                            "house.fill"
                    )
                }


            DiscoverView(recommendedOnly: $recommendedOnly)
                .tag(1)
                .tabItem {

                    Label(
                        "Discover",
                        systemImage:
                            "safari.fill"
                    )
                }


            SavedView()
                .tag(2)
                .tabItem {

                    Label(
                        "Saved",
                        systemImage:
                            "bookmark.fill"
                    )
                }


            OpportunityCalendarView()
                .tag(3)
                .tabItem {

                    Label(
                        "Calendar",
                        systemImage:
                            "calendar"
                    )
                }


            ProfileView()
                .tag(4)
                .tabItem {

                    Label(
                        "Profile",
                        systemImage:
                            "person.crop.circle.fill"
                    )
                }
        }
        .toolbarBackground(
            Opportunity313Brand.surface(for: colorScheme),
            for: .tabBar
        )
        .toolbarBackground(.visible, for: .tabBar)
        .task {

            await savedService
                .loadSaves()
        }
    }
}


// MARK: - Parent Tabs

struct ParentTabView: View {

    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTab = 0
    @State private var recommendedOnly = false
    @State private var deadlinesOnly = false

    var body: some View {

        TabView(selection: $selectedTab) {

            ParentHomeView(onChildren: { selectedTab = 2 }, onSaved: { deadlinesOnly = false; selectedTab = 3 }, onDeadlines: { deadlinesOnly = true; selectedTab = 3 })
                .tag(0)
                .tabItem {

                    Label(
                        "Home",
                        systemImage:
                            "house.fill"
                    )
                }


            DiscoverView(recommendedOnly: $recommendedOnly)
                .tag(1)
                .tabItem {

                    Label(
                        "Discover",
                        systemImage:
                            "safari.fill"
                    )
                }


            ParentChildrenView()
                .tag(2)
                .tabItem {

                    Label(
                        "Children",
                        systemImage:
                            "person.2.fill"
                    )
                }


            ParentCalendarView(deadlinesOnly: $deadlinesOnly)
                .tag(3)
                .tabItem {

                    Label(
                        "Calendar",
                        systemImage:
                            "calendar"
                    )
                }


            AccountView()
                .tag(4)
                .tabItem {

                    Label(
                        "Profile",
                        systemImage:
                            "person.crop.circle.fill"
                    )
                }
        }
        .toolbarBackground(
            Opportunity313Brand.surface(for: colorScheme),
            for: .tabBar
        )
        .toolbarBackground(.visible, for: .tabBar)
    }
}


// MARK: - Provider Tabs

struct ProviderTabView: View {

    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var providerService =
        ProviderService()

    @State private var selectedTab = 0

    var body: some View {

        Group {

            if providerService.isLoading &&
                providerService.organization == nil {

                ProgressView(
                    "Loading provider..."
                )

            } else if let organization =
                        providerService.organization {

                TabView(selection: $selectedTab) {

                    ProviderHomeView(onOpportunities: { selectedTab = 1 }, onEvents: { selectedTab = 2 }, onAccount: { selectedTab = 3 })
                        .tag(0)
                        .tabItem {

                            Label(
                                "Dashboard",
                                systemImage:
                                    "rectangle.grid.2x2.fill"
                            )
                        }


                    ProviderOpportunitiesView(
                        organization:
                            organization
                    )
                    .tag(1)
                    .tabItem {

                        Label(
                            "Opportunities",
                            systemImage:
                                "list.bullet.rectangle"
                        )
                    }


                    ProviderEventsView(organization: organization)
                        .tag(2)
                        .tabItem {

                            Label(
                                "Events",
                                systemImage:
                                    "calendar.badge.plus"
                            )
                        }


                    AccountView()
                        .tag(3)
                        .tabItem {

                            Label(
                                "Profile",
                                systemImage:
                                    "person.crop.circle.fill"
                            )
                        }
                }
                .toolbarBackground(
                    Opportunity313Brand.surface(for: colorScheme),
                    for: .tabBar
                )
                .toolbarBackground(.visible, for: .tabBar)

            } else if let error = providerService.errorMessage {
                VStack(spacing: 16) {
                    ContentUnavailableView("Unable to Load Provider", systemImage: "exclamationmark.triangle", description: Text(error))
                    Button("Try Again") { Task { await providerService.fetchOrganization() } }
                    AccountView()
                }
            } else {

                ProviderSetupView(
                    providerService:
                        providerService
                )
            }
        }
        .task {

            await providerService
                .fetchOrganization()
        }
    }
}


// MARK: - Admin Tabs

struct AdminTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var service = AdminService()
    @State private var selectedTab = 0
    @State private var opportunityFilter: AdminOpportunityFilter = .pending

    var body: some View {
        TabView(selection: $selectedTab) {
            AdminDashboardView(service: service, openOpportunities: { filter in
                opportunityFilter = filter
                selectedTab = 1
            }, openPeople: { selectedTab = 2 })
                .tag(0).tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2.fill") }
            AdminReviewView(adminService: service, filter: $opportunityFilter)
                .tag(1).tabItem { Label("Opportunities", systemImage: "checkmark.seal.fill") }
                .badge(service.pendingOpportunities.count)
            AdminPeopleView(service: service)
                .tag(2).tabItem { Label("People", systemImage: "person.2.fill") }
            SchoolTicketAdministrationView()
                .tag(3).tabItem { Label("Ticketing", systemImage: "ticket") }
            AccountView()
                .tag(4).tabItem { Label("Account", systemImage: "person.crop.circle.fill") }
        }
        .toolbarBackground(Opportunity313Brand.surface(for: colorScheme), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task { await service.refresh() }
    }
}

struct EventStaffTabView: View {
    @StateObject private var schoolRequests = SchoolVerificationService()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView {
            NavigationStack { TicketEventsView(managedOnly: true) }
                .tabItem { Label("Events", systemImage: "calendar") }
            SchoolVerificationQueueView(service: schoolRequests)
                .tabItem { Label("Requests", systemImage: "checkmark.seal") }
                .badge(schoolRequests.queue.filter { $0.status == "pending" }.count)
            AccountView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .task {
            while !Task.isCancelled {
                await schoolRequests.loadQueue()
                do { try await Task.sleep(for: .seconds(30)) }
                catch { break }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await schoolRequests.loadQueue() } }
        }
    }
}
