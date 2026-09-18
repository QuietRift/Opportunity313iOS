//
//  YouthSetupView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct YouthSetupView: View {

    @EnvironmentObject var authService: AuthService

    @StateObject private var youthService =
        YouthProfileService()

    @State private var firstName = ""
    @State private var ageBand = ""
    @State private var grade: Int?

    @State private var selectedInterests: Set<String> = []

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
        "Film",
        "Financial Literacy",
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

            ScrollView {

                VStack(alignment: .leading, spacing: 28) {

                    header

                    personalInfo

                    interestsSection

                    if let error = youthService.errorMessage {

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    continueButton
                }
                .padding()
            }
            .navigationBarBackButtonHidden(true)
        }
    }


    // MARK: - Header

    private var header: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Tell us about you")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(
                "We'll use this to help you find opportunities that fit your interests."
            )
            .foregroundStyle(.secondary)
        }
    }


    // MARK: - Personal Information

    private var personalInfo: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("Your Information")
                .font(.title2)
                .fontWeight(.bold)

            TextField("First name", text: $firstName)
                .textContentType(.givenName)
                .padding()
                .background(
                    Color(.secondarySystemBackground)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 14)
                )

            Picker("Age Group", selection: $ageBand) {

                Text("Select age group")
                    .tag("")

                ForEach(ageBands, id: \.self) { band in
                    Text(band)
                        .tag(band)
                }
            }
            .pickerStyle(.menu)

            Picker("Grade", selection: $grade) {

                Text("Select grade")
                    .tag(nil as Int?)

                Text("Kindergarten")
                    .tag(0 as Int?)

                ForEach(1...12, id: \.self) { grade in

                    Text("Grade \(grade)")
                        .tag(grade as Int?)
                }
            }
            .pickerStyle(.menu)
        }
    }


    // MARK: - Interests

    private var interestsSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            Text("What are you interested in?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Choose as many as you want.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 140))
                ],
                spacing: 12
            ) {

                ForEach(interests, id: \.self) { interest in

                    InterestChip(
                        title: interest,
                        selected:
                            selectedInterests.contains(
                                interest
                            )
                    ) {

                        if selectedInterests.contains(
                            interest
                        ) {

                            selectedInterests.remove(
                                interest
                            )

                        } else {

                            selectedInterests.insert(
                                interest
                            )
                        }
                    }
                }
            }
        }
    }


    // MARK: - Continue

    private var continueButton: some View {

        Button {

            Task {

                do {

                    try await youthService.createProfile(
                        firstName:
                            firstName.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ),
                        ageBand: ageBand,
                        grade: grade,
                        interests:
                            Array(selectedInterests).sorted()
                    )

                    await authService.loadYouthProfile()

                } catch {
                    // Service displays error
                }
            }

        } label: {

            HStack {

                if youthService.isLoading {

                    ProgressView()

                } else {

                    Text("Finish Setup")
                        .fontWeight(.semibold)

                    Image(
                        systemName:
                            "arrow.right"
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                formIsValid
                    ? Color.primary
                    : Color.secondary.opacity(0.3)
            )
            .foregroundStyle(
                Color(.systemBackground)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 16)
            )
        }
        .disabled(
            !formIsValid ||
            youthService.isLoading
        )
    }


    private var formIsValid: Bool {

        !firstName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
        &&
        !ageBand.isEmpty
        &&
        grade != nil
    }
}


// MARK: - Interest Chip

struct InterestChip: View {

    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {

        Button(action: action) {

            HStack {

                Text(title)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)

                Spacer()

                if selected {

                    Image(
                        systemName:
                            "checkmark"
                    )
                }
            }
            .padding()
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                selected
                    ? Color.primary
                    : Color(.secondarySystemBackground)
            )
            .foregroundStyle(
                selected
                    ? Color(.systemBackground)
                    : Color.primary
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }
}
