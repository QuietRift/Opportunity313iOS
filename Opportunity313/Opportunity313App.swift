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
    static let darkSurface = Color(red: 0.055, green: 0.165, blue: 0.260)

    static func canvas(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? deepBlue : warmSurface
    }

    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkSurface : .white
    }

    static let heroGradient = LinearGradient(
        colors: [deepBlue, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct Opportunity313PageBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
            .toolbarBackground(
                Opportunity313Brand.canvas(for: colorScheme),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func opportunity313PageBackground() -> some View {
        modifier(Opportunity313PageBackground())
    }
}

enum AppColorway: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String { self == .light ? "sun.max.fill" : "moon.stars.fill" }
    var colorScheme: ColorScheme { self == .light ? .light : .dark }
}

@main
struct Opportunity313App: App {

    @AppStorage("opportunity313.colorway") private var colorway = AppColorway.light.rawValue

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
                .preferredColorScheme(
                    AppColorway(rawValue: colorway)?.colorScheme ?? .light
                )
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
