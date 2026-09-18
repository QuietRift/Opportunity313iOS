//
//  ContentView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authService: AuthService

    @EnvironmentObject private var savedService: SavedOpportunityService
    @EnvironmentObject private var familySaveService: FamilySaveService

    var body: some View {

        Group {

            if authService.isResolvingAccount {
                ProgressView("Loading account...")
            } else if let error = authService.accountError {
                VStack(spacing: 16) {
                    ContentUnavailableView("Unable to Load Account", systemImage: "exclamationmark.triangle", description: Text(error))
                    Button("Try Again") { Task { await authService.refreshUserState() } }
                    Button("Sign Out") { Task { await authService.signOut() } }
                }
            } else if !authService.isAuthenticated {

                LoginView()

            } else if authService.needsOnboarding {

                RoleSelectionView()

            } else if authService.role == "youth"
                        && !authService.hasYouthProfile {

                YouthSetupView()

            } else {

                MainTabView()
            }
        }
        .id(authService.userID)
        .onChange(of: authService.userID) {
            savedService.reset()
            familySaveService.reset()
        }
        .task {
            await authService.observeAuthState()
        }
        .alert("Unable to Update Saved Opportunity", isPresented: Binding(
            get: { savedService.errorMessage != nil || familySaveService.errorMessage != nil },
            set: { if !$0 { savedService.errorMessage = nil; familySaveService.errorMessage = nil } }
        )) {
            Button("OK") { savedService.errorMessage = nil; familySaveService.errorMessage = nil }
        } message: {
            Text(savedService.errorMessage ?? familySaveService.errorMessage ?? "Please try again.")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(SavedOpportunityService())
        .environmentObject(FamilySaveService())
}
