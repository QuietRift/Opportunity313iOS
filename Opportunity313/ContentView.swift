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

    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

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
            showSaveError = false
        }
        .task {
            await authService.observeAuthState()
        }
        .onChange(of: savedService.errorMessage) { _, error in
            if let error { saveErrorMessage = error; showSaveError = true }
        }
        .onChange(of: familySaveService.errorMessage) { _, error in
            if let error { saveErrorMessage = error; showSaveError = true }
        }
        .alert("Unable to Update Saved Opportunity", isPresented: $showSaveError) {
            Button("OK") { savedService.errorMessage = nil; familySaveService.errorMessage = nil }
        } message: {
            Text(saveErrorMessage)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(SavedOpportunityService())
        .environmentObject(FamilySaveService())
}
