//
//  AddChildView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct AddChildView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var childService:
        ParentManagedYouthService

    @State private var firstName = ""
    @State private var ageBand = ""
    @State private var grade: Int?
    @State private var gender: ParticipantGender?

    @State private var relationship =
        "Parent"

    @State private var selectedInterests:
        Set<String> = []

    @State private var accessibilityText = ""

    private let relationships = [
        "Parent",
        "Guardian",
        "Grandparent",
        "Other"
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


    var body: some View {

        NavigationStack {

            Form {

                Section("Child Information") {

                    TextField(
                        "First name",
                        text: $firstName
                    )

                    Picker(
                        "Age Group",
                        selection: $ageBand
                    ) {

                        Text("Select age group")
                            .tag("")

                        ForEach(
                            AgeGroup.child
                        ) { group in

                            Text("\(group.databaseValue) · \(group.title)")
                                .tag(group.databaseValue)
                        }
                    }

                    Picker(
                        "Grade (Optional)",
                        selection: $grade
                    ) {

                        Text("Not applicable")
                            .tag(nil as Int?)

                        Text("Kindergarten")
                            .tag(0 as Int?)

                        ForEach(
                            1...12,
                            id: \.self
                        ) { grade in

                            Text("Grade \(grade)")
                                .tag(
                                    grade as Int?
                                )
                        }
                    }

                    Picker("Gender", selection: $gender) {
                        Text("Select gender").tag(nil as ParticipantGender?)
                        ForEach(ParticipantGender.allCases) { option in
                            Text(option.title).tag(option as ParticipantGender?)
                        }
                    }
                }


                Section("Relationship") {

                    Picker(
                        "Relationship",
                        selection:
                            $relationship
                    ) {

                        ForEach(
                            relationships,
                            id: \.self
                        ) { relationship in

                            Text(relationship)
                                .tag(
                                    relationship
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
                        "These help Opportunity313 recommend programs that fit this child."
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
                    childService.errorMessage {

                    Section {

                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Child")
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

                    Button("Add") {

                        Task {
                            await addChild()
                        }
                    }
                    .disabled(
                        !formIsValid ||
                        childService.isLoading
                    )
                }
            }
        }
    }


    // MARK: - Toggle Interest

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


    // MARK: - Add Child

    private func addChild() async {

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

            try await childService
                .createChild(
                    firstName: firstName,
                    ageBand: ageBand,
                    grade: grade,
                    gender: gender!,
                    interests:
                        Array(
                            selectedInterests
                        )
                        .sorted(),
                    accessibilityPreferences:
                        accessibility,
                    relationship:
                        relationship
                )

            dismiss()

        } catch {
            // Error displayed by service.
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
        && gender != nil
    }
}
