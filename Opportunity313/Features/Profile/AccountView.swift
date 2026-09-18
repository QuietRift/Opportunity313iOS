//
//  AccountView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct AccountView: View {

    @EnvironmentObject var authService: AuthService

    var body: some View {

        NavigationStack {

            List {

                Section("Opportunity313") {

                    HStack {

                        Label(
                            "Account Type",
                            systemImage:
                                "person.crop.circle"
                        )

                        Spacer()

                        Text(
                            displayRole
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                Section {

                    Button(role: .destructive) {

                        Task {
                            await authService.signOut()
                        }

                    } label: {

                        Label(
                            "Sign Out",
                            systemImage:
                                "rectangle.portrait.and.arrow.right"
                        )
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }


    private var displayRole: String {

        switch authService.role {

        case "parent":
            return "Parent / Guardian"

        case "provider":
            return "Provider"

        case "athletics":
            return "Athletics"

        case "admin":
            return "Administrator"

        default:
            return "User"
        }
    }
}
