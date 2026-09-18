//
//  EditYouthProfileView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct EditYouthProfileView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var profileService:
        YouthProfileService

    let profile: YouthProfile

    @State private var firstName: String
    @State private var ageBand: String
    @State private var grade: Int?

    @State private var selectedInterests:
        Set<String>

    @State private var accessibilityText: String

    private let ageBands = [
        "8–10",
        "11–13",
        "14–18"
    ]

    private let interests = [
        "Academic Support",
        "Arts",
        "Career Exploration",
        "Career Readiness",
        "College Readiness",
        "Culinary",
        "Entrepreneurship",
        "Financial Literacy",
        "Film",
        "Health",
        "Leadership",
        "Media",
        "Music",
        "Science",
        "Skilled Trades",
        "Sports",
        "Sustainability",
        "Technology"
    ]


    init(
        profile: YouthProfile,
        profileService:
            YouthProfileService
    ) {

        self.profile = profile
        self.profileService =
            profileService

        _firstName =
            State(
                initialValue:
                    profile.firstName
            )

        _ageBand =
            State(
                initialValue:
                    profile.ageBand
            )

        _grade =
            State(
                initialValue:
                    profile.grade
            )

        _selectedInterests =
            State(
                initialValue:
                    Set(
                        profile.interests
                    )
            )

        _accessibilityText =
            State(
                initialValue:
                    profile
                        .accessibilityPreferences
                        .joined(
                            separator: ", "
                        )
            )
    }


    var body: some View {

        NavigationStack {

            Form {

                Section("About You") {

                    TextField(
                        "First name",
                        text: $firstName
                    )

                    Picker(
                        "Age Group",
                        selection: $ageBand
                    ) {

                        ForEach(
                            ageBands,
                            id: \.self
                        ) { band in

                            Text(band)
                                .tag(band)
                        }
                    }

                    Picker(
                        "Grade",
                        selection: $grade
                    ) {

                        Text("Kindergarten")
                            .tag(0 as Int?)

                        ForEach(
                            1...12,
                            id: \.self
                        ) { grade in

                            Text(
                                "Grade \(grade)"
                            )
                            .tag(
                                grade as Int?
                            )
                        }
                    }
                }


                Section {

                    ForEach(
                        interests,
                        id: \.self
                    ) { interest in

                        Button {

                            toggleInterest(
                                interest
                            )

                        } label: {

                            HStack {

                                Text(interest)
                                    .foregroundStyle(
                                        .primary
                                    )

                                Spacer()

                                if selectedInterests
                                    .contains(
                                        interest
                                    ) {

                                    Image(
                                        systemName:
                                            "checkmark"
                                    )
                                }
                            }
                        }
                    }

                } header: {

                    Text("Interests")

                } footer: {

                    Text(
                        "These interests help Opportunity313 personalize recommendations."
                    )
                }


                Section(
                    "Accessibility Preferences"
                ) {

                    TextField(
                        "Optional preferences",
                        text:
                            $accessibilityText,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }


                if let error =
                    profileService.errorMessage {

                    Section {

                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button("Save") {

                        Task {
                            await save()
                        }
                    }
                    .disabled(
                        !formIsValid ||
                        profileService.isLoading
                    )
                }
            }
        }
    }


    // MARK: - Interest Toggle

    private func toggleInterest(
        _ interest: String
    ) {

        if selectedInterests
            .contains(interest) {

            selectedInterests
                .remove(interest)

        } else {

            selectedInterests
                .insert(interest)
        }
    }


    // MARK: - Save

    private func save() async {

        let accessibility =
            accessibilityText
                .split(separator: ",")
                .map {
                    $0.trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                }
                .filter {
                    !$0.isEmpty
                }

        do {

            try await profileService
                .updateProfile(
                    firstName:
                        firstName
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            ),
                    ageBand: ageBand,
                    grade: grade,
                    interests:
                        Array(
                            selectedInterests
                        )
                        .sorted(),
                    accessibilityPreferences:
                        accessibility
                )

            dismiss()

        } catch {
            // Service displays error.
        }
    }


    private var formIsValid: Bool {

        !firstName
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
        &&
        !ageBand.isEmpty
        &&
        grade != nil
    }
}
