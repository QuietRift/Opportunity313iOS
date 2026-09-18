//
//  CreateOpportunityView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct CreateOpportunityView: View {

    @Environment(\.dismiss)
    private var dismiss

    let organization: Organization

    @ObservedObject var opportunityService:
        ProviderOpportunityService

    @State private var title = ""
    @State private var summary = ""

    @State private var category =
        "Technology"

    @State private var opportunityType =
        "Workshop"

    @State private var gradeMin: Int?
    @State private var gradeMax: Int?

    @State private var startsAt =
        Date()
        .addingTimeInterval(
            86_400
        )

    @State private var endsAt =
        Date()
        .addingTimeInterval(
            93_600
        )

    @State private var hasDeadline =
        true

    @State private var deadline =
        Date().addingTimeInterval(43_200)

    @State private var locationName =
        ""

    @State private var neighborhood =
        ""

    @State private var transportation =
        ""

    @State private var mealsProvided =
        false

    @State private var accessibility =
        ""

    @State private var parentRequirements =
        ""

    @State private var registrationURL =
        ""

    @State private var capacityText =
        ""

    private let categories = [
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

    private let opportunityTypes = [
        "Workshop",
        "Program",
        "Camp",
        "Internship",
        "Event",
        "Clinic",
        "Competition"
    ]


    var body: some View {

        NavigationStack {

            Form {

                Section(
                    "Opportunity"
                ) {

                    TextField(
                        "Title",
                        text: $title
                    )

                    TextField(
                        "Describe the opportunity",
                        text: $summary,
                        axis: .vertical
                    )
                    .lineLimit(4...8)

                    Picker(
                        "Category",
                        selection:
                            $category
                    ) {

                        ForEach(
                            categories,
                            id: \.self
                        ) { category in

                            Text(category)
                                .tag(
                                    category
                                )
                        }
                    }

                    Picker(
                        "Type",
                        selection:
                            $opportunityType
                    ) {

                        ForEach(
                            opportunityTypes,
                            id: \.self
                        ) { type in

                            Text(type)
                                .tag(type)
                        }
                    }
                }


                Section(
                    "Eligibility"
                ) {

                    Picker(
                        "Minimum Grade",
                        selection:
                            $gradeMin
                    ) {

                        Text("Any")
                            .tag(
                                nil as Int?
                            )

                        Text(
                            "Kindergarten"
                        )
                        .tag(
                            0 as Int?
                        )

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

                    Picker(
                        "Maximum Grade",
                        selection:
                            $gradeMax
                    ) {

                        Text("Any")
                            .tag(
                                nil as Int?
                            )

                        Text(
                            "Kindergarten"
                        )
                        .tag(
                            0 as Int?
                        )

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


                Section(
                    "Schedule"
                ) {

                    DatePicker(
                        "Starts",
                        selection:
                            $startsAt
                    )

                    DatePicker(
                        "Ends",
                        selection:
                            $endsAt
                    )

                    Toggle(
                        "Registration Deadline",
                        isOn:
                            $hasDeadline
                    )

                    if hasDeadline {

                        DatePicker(
                            "Deadline",
                            selection:
                                $deadline
                        )
                    }
                }


                Section(
                    "Location"
                ) {

                    TextField(
                        "Location name",
                        text:
                            $locationName
                    )

                    TextField(
                        "Neighborhood",
                        text:
                            $neighborhood
                    )

                    TextField(
                        "Transportation support",
                        text:
                            $transportation
                    )
                }


                Section(
                    "Support"
                ) {

                    Toggle(
                        "Meals Provided",
                        isOn:
                            $mealsProvided
                    )

                    TextField(
                        "Accessibility information",
                        text:
                            $accessibility,
                        axis: .vertical
                    )

                    TextField(
                        "Parent / guardian requirements",
                        text:
                            $parentRequirements,
                        axis: .vertical
                    )
                }


                Section(
                    "Registration"
                ) {

                    TextField(
                        "Registration URL",
                        text:
                            $registrationURL
                    )
                    .textInputAutocapitalization(
                        .never
                    )

                    TextField(
                        "Capacity",
                        text:
                            $capacityText
                    )
                    .keyboardType(
                        .numberPad
                    )
                }


                Section {

                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {

                        Label(
                            "Submitted for Review",
                            systemImage:
                                "checkmark.shield"
                        )
                        .font(.headline)

                        Text(
                            "Opportunity313 reviews provider submissions before they become visible to youth and families."
                        )
                        .font(
                            .subheadline
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }


                if let error =
                    opportunityService
                        .errorMessage {

                    Section {

                        Text(error)
                            .foregroundStyle(
                                .red
                            )
                    }
                }
            }
            .navigationTitle(
                "New Opportunity"
            )
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

                    Button("Submit") {

                        Task {

                            await submit()
                        }
                    }
                    .disabled(
                        !formIsValid ||
                        opportunityService
                            .isLoading
                    )
                }
            }
        }
    }


    private func submit() async {

        do {

            try await opportunityService
                .createOpportunity(
                    organizationID:
                        organization.id,
                    title:
                        title,
                    summary:
                        summary,
                    category:
                        category,
                    opportunityType:
                        opportunityType,
                    ageMin:
                        nil,
                    ageMax:
                        nil,
                    gradeMin:
                        gradeMin,
                    gradeMax:
                        gradeMax,
                    startsAt:
                        startsAt,
                    endsAt:
                        endsAt,
                    deadline:
                        hasDeadline
                        ? deadline
                        : nil,
                    costCents:
                        0,
                    isFree:
                        true,
                    locationName:
                        locationName,
                    neighborhood:
                        neighborhood,
                    transportation:
                        transportation,
                    mealsProvided:
                        mealsProvided,
                    accessibility:
                        accessibility,
                    parentRequirements:
                        parentRequirements,
                    registrationUrl:
                        registrationURL,
                    capacity:
                        Int(
                            capacityText
                        )
                )

            dismiss()

        } catch {
            // Service displays error.
        }
    }


    private var formIsValid: Bool {

        let cleanTitle =
            title.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let cleanSummary =
            summary.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        let cleanLocation =
            locationName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard cleanTitle.count >= 3,
              cleanSummary.count >= 10,
              !cleanLocation.isEmpty,
              endsAt >= startsAt
        else {

            return false
        }

        if hasDeadline && (deadline <= Date() || deadline > startsAt) {
            return false
        }

        let cleanCapacity = capacityText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanCapacity.isEmpty && (Int(cleanCapacity) ?? 0) <= 0 { return false }
        let cleanURL = registrationURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.isEmpty {
            guard let url = URL(string: cleanURL),
                  ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.host != nil else { return false }
        }

        if let gradeMin,
           let gradeMax,
           gradeMin > gradeMax {

            return false
        }

        return true
    }
}
