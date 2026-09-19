//
//  RoleSelectionView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct RoleSelectionView: View {

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authService: AuthService

    @StateObject private var onboardingService =
        OnboardingService()

    @State private var selectedRole: String?

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 28) {

                    VStack(alignment: .leading, spacing: 8) {

                        Text("How will you use Opportunity313?")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(
                            "Choose the experience that best fits you."
                        )
                        .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {

                        RoleCard(
                            title: "I'm a Young Adult (18–24)",
                            description:
                                "Create your own profile and discover age-appropriate opportunities.",
                            icon: "figure.and.child.holdinghands",
                            selected: selectedRole == "youth"
                        ) {
                            selectedRole = "youth"
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label("Under 18?", systemImage: "person.badge.key.fill")
                                .font(.headline)
                            Text("A parent or guardian creates your profile. Use the access code they give you to sign in.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

                        RoleCard(
                            title: "I'm a Parent or Guardian",
                            description:
                                "Find and manage opportunities for young people in your family.",
                            icon: "person.2.fill",
                            selected: selectedRole == "parent"
                        ) {
                            selectedRole = "parent"
                        }

                        RoleCard(
                            title: "I'm an Opportunity Provider",
                            description:
                                "Share programs and opportunities with Detroit youth.",
                            icon: "building.2.fill",
                            selected: selectedRole == "provider"
                        ) {
                            selectedRole = "provider"
                        }
                    }

                    if let error =
                        onboardingService.errorMessage {

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {

                        guard let selectedRole else {
                            return
                        }

                        Task {

                            do {

                                try await onboardingService
                                    .claimRole(selectedRole)

                                await authService
                                    .loadUserRole()

                            } catch {
                                // Error already displayed
                            }
                        }

                    } label: {

                        HStack {

                            if onboardingService.isLoading {

                                ProgressView()

                            } else {

                                Text("Continue")
                                    .fontWeight(.semibold)

                                Image(
                                    systemName:
                                        "arrow.right"
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedRole == nil ? Color.secondary.opacity(0.3) : Opportunity313Brand.accent)
                        .foregroundStyle(.white)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 16
                            )
                        )
                    }
                    .disabled(
                        selectedRole == nil ||
                        onboardingService.isLoading
                    )
                }
                .padding()
            }
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
        }
        .opportunity313PageBackground()
    }
}


struct RoleCard: View {

    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let description: String
    let icon: String
    let selected: Bool
    let action: () -> Void

    var body: some View {

        Button(action: action) {

            HStack(spacing: 16) {

                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 36)

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(title)
                        .font(.headline)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(
                    systemName:
                        selected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title2)
            }
            .padding()
            .background(Opportunity313Brand.surface(for: colorScheme))
            .overlay {

                RoundedRectangle(
                    cornerRadius: 18
                )
                .stroke(
                    selected
                        ? Color.primary
                        : Color.clear,
                    lineWidth: 2
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 18
                )
            )
        }
        .buttonStyle(.plain)
    }
}
