//
//  ProfileView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var authService: AuthService

    @StateObject private var profileService =
        YouthProfileService()

    @State private var showEditProfile = false

    var body: some View {

        NavigationStack {

            Group {

                if profileService.isLoading &&
                    profileService.currentProfile == nil {

                    ProgressView("Loading profile...")

                } else if let profile =
                    profileService.currentProfile {

                    ScrollView {

                        VStack(spacing: 24) {

                            profileHeader(profile)

                            profileDetails(profile)

                            interestsSection(profile)

                            accountSection
                        }
                        .padding()
                    }

                } else {

                    ContentUnavailableView(
                        "Profile Unavailable",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text(
                            "We couldn't load your Opportunity313 profile."
                        )
                    )
                }
            }
            .navigationTitle("Profile")
            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    if profileService.currentProfile != nil {

                        Button("Edit") {
                            showEditProfile = true
                        }
                    }
                }
            }
            .task {
                await profileService.fetchCurrentProfile()
            }
            .refreshable {
                await profileService.fetchCurrentProfile()
            }
            .sheet(
                isPresented: $showEditProfile
            ) {

                if let profile =
                    profileService.currentProfile {

                    EditYouthProfileView(
                        profile: profile,
                        profileService:
                            profileService
                    )
                }
            }
        }
    }


    // MARK: - Header

    private func profileHeader(
        _ profile: YouthProfile
    ) -> some View {

        VStack(spacing: 12) {

            Image(
                systemName:
                    "person.crop.circle.fill"
            )
            .font(.system(size: 82))
            .foregroundStyle(.secondary)

            Text(profile.firstName)
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Opportunity313 Youth")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }


    // MARK: - Details

    private func profileDetails(
        _ profile: YouthProfile
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 16
        ) {

            Text("About You")
                .font(.title2)
                .fontWeight(.bold)

            ProfileInfoRow(
                icon: "person.2",
                title: "Age Group",
                value: profile.ageBand
            )

            if let grade = profile.grade {

                ProfileInfoRow(
                    icon: "graduationcap",
                    title: "Grade",
                    value: grade == 0
                        ? "Kindergarten"
                        : "Grade \(grade)"
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding()
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18
            )
        )
    }


    // MARK: - Interests

    private func interestsSection(
        _ profile: YouthProfile
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text("Your Interests")
                .font(.title2)
                .fontWeight(.bold)

            if profile.interests.isEmpty {

                Text(
                    "You haven't selected any interests yet."
                )
                .foregroundStyle(.secondary)

            } else {

                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: 130
                            )
                        )
                    ],
                    spacing: 10
                ) {

                    ForEach(
                        profile.interests,
                        id: \.self
                    ) { interest in

                        Text(interest)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(
                                .horizontal,
                                12
                            )
                            .padding(
                                .vertical,
                                10
                            )
                            .frame(
                                maxWidth: .infinity
                            )
                            .background(
                                Color(
                                    .secondarySystemBackground
                                )
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 12
                                )
                            )
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }


    // MARK: - Account

    private var accountSection: some View {

        VStack(spacing: 14) {

            Divider()

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
                .frame(
                    maxWidth: .infinity
                )
                .padding()
            }
            .buttonStyle(.bordered)
        }
    }
}


// MARK: - Profile Row

struct ProfileInfoRow: View {

    let icon: String
    let title: String
    let value: String

    var body: some View {

        HStack(spacing: 14) {

            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.secondary)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .fontWeight(.medium)
            }

            Spacer()
        }
    }
}
