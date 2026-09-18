//
//  ContentView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authService: AuthService

    var body: some View {

        Group {

            if !authService.isAuthenticated {

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
        .task {
            await authService.observeAuthState()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
