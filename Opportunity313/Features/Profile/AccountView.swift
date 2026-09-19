//
//  AccountView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct AccountView: View {

    @EnvironmentObject var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("opportunity313.colorway") private var colorway = AppColorway.light.rawValue

    var body: some View {

        NavigationStack {

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Opportunity313")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label("Account Type", systemImage: "person.crop.circle")
                        Spacer()
                        Text(displayRole)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))

                    Text("Appearance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    Picker("Colorway", selection: $colorway) {
                        ForEach(AppColorway.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(14)
                    .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))

                    Button(role: .destructive) {
                        Task {
                            await authService.signOut()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
            }
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
            .navigationTitle("Profile")
        }
        .opportunity313PageBackground()
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
