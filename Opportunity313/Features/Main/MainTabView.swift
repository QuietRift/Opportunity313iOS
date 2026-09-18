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

    @EnvironmentObject var savedService:
        SavedOpportunityService

    var body: some View {

        TabView {

            HomeView()
                .tabItem {

                    Label(
                        "Home",
                        systemImage:
                            "house.fill"
                    )
                }


            DiscoverView()
                .tabItem {

                    Label(
                        "Discover",
                        systemImage:
                            "safari.fill"
                    )
                }


            SavedView()
                .tabItem {

                    Label(
                        "Saved",
                        systemImage:
                            "bookmark.fill"
                    )
                }


            OpportunityCalendarView()
                .tabItem {

                    Label(
                        "Calendar",
                        systemImage:
                            "calendar"
                    )
                }


            ProfileView()
                .tabItem {

                    Label(
                        "Profile",
                        systemImage:
                            "person.crop.circle.fill"
                    )
                }
        }
        .task {

            await savedService
                .loadSaves()
        }
    }
}


// MARK: - Parent Tabs

struct ParentTabView: View {

    var body: some View {

        TabView {

            ParentHomeView()
                .tabItem {

                    Label(
                        "Home",
                        systemImage:
                            "house.fill"
                    )
                }


            DiscoverView()
                .tabItem {

                    Label(
                        "Discover",
                        systemImage:
                            "safari.fill"
                    )
                }


            ParentChildrenView()
                .tabItem {

                    Label(
                        "Children",
                        systemImage:
                            "person.2.fill"
                    )
                }


            ParentCalendarView()
                .tabItem {

                    Label(
                        "Calendar",
                        systemImage:
                            "calendar"
                    )
                }


            AccountView()
                .tabItem {

                    Label(
                        "Profile",
                        systemImage:
                            "person.crop.circle.fill"
                    )
                }
        }
    }
}


// MARK: - Provider Tabs

struct ProviderTabView: View {

    @StateObject private var providerService =
        ProviderService()

    var body: some View {

        Group {

            if providerService.isLoading &&
                providerService.organization == nil {

                ProgressView(
                    "Loading provider..."
                )

            } else if let organization =
                        providerService.organization {

                TabView {

                    ProviderHomeView()
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
                    .tabItem {

                        Label(
                            "Opportunities",
                            systemImage:
                                "list.bullet.rectangle"
                        )
                    }


                    ProviderEventsView()
                        .tabItem {

                            Label(
                                "Events",
                                systemImage:
                                    "calendar.badge.plus"
                            )
                        }


                    AccountView()
                        .tabItem {

                            Label(
                                "Profile",
                                systemImage:
                                    "person.crop.circle.fill"
                            )
                        }
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
    }
}
