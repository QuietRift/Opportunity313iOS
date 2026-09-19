//
//  Opportunity313App.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

/// Shared visual language mirrored from opp313.kevincolston.com.
enum Opportunity313Brand {
    static let deepBlue = Color(red: 0.035, green: 0.125, blue: 0.220)
    static let blue = Color(red: 0.055, green: 0.225, blue: 0.350)
    static let accent = Color(red: 0.965, green: 0.310, blue: 0.105)
    static let warmSurface = Color(red: 0.975, green: 0.965, blue: 0.945)

    static let heroGradient = LinearGradient(
        colors: [deepBlue, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

@main
struct Opportunity313App: App {

    @StateObject private var authService =
        AuthService()

    @StateObject private var savedService =
        SavedOpportunityService()

    @StateObject private var familySaveService =
        FamilySaveService()

    var body: some Scene {

        WindowGroup {

            ContentView()
                .tint(Opportunity313Brand.accent)
                .environmentObject(
                    authService
                )
                .environmentObject(
                    savedService
                )
                .environmentObject(
                    familySaveService
                )
        }
    }
}
