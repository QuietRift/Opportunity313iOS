//
//  AddChildView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct AddChildView: View {

    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject var childService:
        ParentManagedYouthService

    @StateObject private var accessService = ChildAccessService()
    @State private var createdChildID: UUID?

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

            Group {
            if let createdChildID { childCreatedContent(childID: createdChildID) }
            else { Form {

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
            }
            }
            .scrollContentBackground(.hidden)
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
            .navigationTitle(createdChildID == nil ? "Add Child" : "Child Added")
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {

                    Button(createdChildID == nil ? "Cancel" : "Done") {
                        dismiss()
                    }
                    .disabled(childService.isLoading || accessService.isLoading)
                }

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    if createdChildID == nil { Button("Add") {

                        Task {
                            await addChild()
                        }
                    }
                    .disabled(
                        !formIsValid ||
                        childService.isLoading || accessService.isLoading
                    )
                    }
                }
            }
        }
        .opportunity313PageBackground()
        .interactiveDismissDisabled(childService.isLoading || accessService.isLoading)
    }


    private func childCreatedContent(childID: UUID) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Label("\(firstName.trimmingCharacters(in: .whitespacesAndNewlines))’s profile is saved", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold())
                Text("Use this private code to sign in from the Under 18 access-code option. The child does not need an email address or a separate signup.")
                if accessService.isLoading {
                    ProgressView("Creating the child’s access code…")
                } else if let code = accessService.generatedCode {
                    Text(code).font(.system(.title2, design: .monospaced).bold())
                        .textSelection(.enabled).accessibilityIdentifier("newChildAccessCode")
                        .frame(maxWidth: .infinity).padding()
                        .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
                    if let expiration = accessService.expiresAt {
                        Text("Valid until \(expiration.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ShareLink(item: code) { Label("Share access code", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.borderedProminent)
                    Text("Save or share this code now. It is shown only here; you can replace or revoke it later from the child’s profile.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("The child’s profile was saved, but the access code could not be created.")
                    if let error = accessService.errorMessage { Text(error).foregroundStyle(.red) }
                    Button("Retry access code") {
                        Task { await accessService.generate(for: childID) }
                    }.buttonStyle(.borderedProminent)
                    Text("Retry creates a code for this saved profile. You do not need to add the child again.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }.padding(24).frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
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

            let childID = try await childService
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

            createdChildID = childID
            await accessService.generate(for: childID)

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
