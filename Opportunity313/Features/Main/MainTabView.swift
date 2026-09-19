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

    var body: some View {

        TabView {

            AdminReviewView()
                .tabItem {

                    Label(
                        "Review",
                        systemImage:
                            "checkmark.seal.fill"
                    )
                }


            AccountView()
                .tabItem {

                    Label(
                        "Account",
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
