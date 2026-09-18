//
//  ProviderEventsView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ProviderEventsView: View {

    var body: some View {

        NavigationStack {

            ContentUnavailableView(
                "Provider Events",
                systemImage:
                    "calendar.badge.plus",
                description: Text(
                    "Your organization's events will appear here."
                )
            )
            .navigationTitle("Events")
        }
    }
}
