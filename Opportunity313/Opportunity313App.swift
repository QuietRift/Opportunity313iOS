//
//  Opportunity313App.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

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
