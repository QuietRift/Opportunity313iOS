//
//  ProviderSetupView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ProviderSetupView: View {

    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var providerService: ProviderService

    @State private var organizationName = ""
    @State private var organizationType = "nonprofit"
    @State private var description = ""

    private let organizationTypes = [
        OrganizationTypeOption(
            label: "Nonprofit",
            value: "nonprofit"
        ),
        OrganizationTypeOption(
            label: "Community Provider",
            value: "community_provider"
        ),
        OrganizationTypeOption(
            label: "School",
            value: "school"
        ),
        OrganizationTypeOption(
            label: "Youth League",
            value: "youth_league"
        ),
        OrganizationTypeOption(
            label: "Little League",
            value: "little_league"
        ),
        OrganizationTypeOption(
            label: "Athletics Host",
            value: "athletics_host"
        ),
        OrganizationTypeOption(
            label: "City Program",
            value: "city_program"
        )
    ]

    var body: some View {

        NavigationStack {

            Form {

                Section("Organization") {

                    TextField(
                        "Organization name",
                        text: $organizationName
                    )

                    Picker(
                        "Organization Type",
                        selection: $organizationType
                    ) {

                        ForEach(
                            organizationTypes
                        ) { type in

                            Text(type.label)
                                .tag(type.value)
                        }
                    }
                }


                Section("Description") {

                    TextField(
                        "Tell us about your organization",
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                }


                Section {

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Label(
                            "Provider Verification",
                            systemImage: "checkmark.shield"
                        )
                        .font(.headline)

                        Text(
                            "Your organization will begin in pending status while Opportunity313 reviews and verifies provider information."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }


                if let error =
                    providerService.errorMessage {

                    Section {

                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
            .navigationTitle(
                "Set Up Organization"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .safeAreaInset(
                edge: .bottom
            ) {

                Button {

                    Task {
                        await createOrganization()
                    }

                } label: {

                    if providerService.isLoading {

                        ProgressView()
                            .frame(
                                maxWidth: .infinity
                            )

                    } else {

                        Text(
                            "Create Organization"
                        )
                        .fontWeight(.semibold)
                        .frame(
                            maxWidth: .infinity
                        )
                    }
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(.large)
                .disabled(
                    !formIsValid ||
                    providerService.isLoading
                )
                .padding()
                .background(
                    .regularMaterial
                )
            }
        }
        .opportunity313PageBackground()
    }


    // MARK: - Create Organization

    private func createOrganization() async {

        do {

            try await providerService
                .registerOrganization(
                    name: organizationName,
                    type: organizationType,
                    description: description
                )

        } catch {
            // ProviderService displays the error.
        }
    }


    // MARK: - Validation

    private var formIsValid: Bool {

        organizationName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .count >= 3
    }
}


// MARK: - Organization Type

struct OrganizationTypeOption: Identifiable {

    let label: String
    let value: String

    var id: String {
        value
    }
}
