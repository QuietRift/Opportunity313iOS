//
//  OpportunityDetailView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct OpportunityDetailView: View {

    @EnvironmentObject var savedService: SavedOpportunityService
    @EnvironmentObject var authService: AuthService

    let opportunity: Opportunity

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 24
            ) {

                // MARK: - Header

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {

                    Text(
                        opportunity.category
                            .uppercased()
                    )
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                    Text(opportunity.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(opportunity.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }


                Divider()


                // MARK: - Quick Info

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    DetailRow(
                        icon: "calendar",
                        title: "Starts",
                        value:
                            opportunity.startsAt
                                .formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                    )

                    if let endsAt =
                        opportunity.endsAt {

                        DetailRow(
                            icon:
                                "calendar.badge.clock",
                            title: "Ends",
                            value:
                                endsAt.formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                        )
                    }

                    if let deadline =
                        opportunity.deadline {

                        DetailRow(
                            icon: "clock",
                            title:
                                "Registration Deadline",
                            value:
                                deadline.formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                        )
                    }

                    if let scheduleNote =
                        opportunity.scheduleNote {

                        DetailRow(
                            icon:
                                "calendar.day.timeline.left",
                            title: "Schedule",
                            value:
                                scheduleNote
                        )
                    }

                    DetailRow(
                        icon:
                            "mappin.and.ellipse",
                        title: "Location",
                        value:
                            opportunity.locationName
                    )

                    if let street =
                        opportunity.street {

                        DetailRow(
                            icon: "location",
                            title: "Address",
                            value:
                                formattedAddress(
                                    street: street,
                                    city:
                                        opportunity.city,
                                    state:
                                        opportunity.state,
                                    postalCode:
                                        opportunity.postalCode
                                )
                        )
                    }

                    if let neighborhood =
                        opportunity.neighborhood {

                        DetailRow(
                            icon: "building.2",
                            title: "Neighborhood",
                            value:
                                neighborhood
                        )
                    }

                    DetailRow(
                        icon:
                            "dollarsign.circle",
                        title: "Cost",
                        value:
                            opportunity.isFree
                            ? "Free"
                            : formattedCost
                    )
                }


                Divider()


                // MARK: - Eligibility

                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {

                    Text("Who It's For")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let ageText {

                        DetailRow(
                            icon: "person.2",
                            title: "Ages",
                            value: ageText
                        )
                    }

                    if let gradeText {

                        DetailRow(
                            icon:
                                "graduationcap",
                            title: "Grades",
                            value: gradeText
                        )
                    }

                    DetailRow(
                        icon: "tag",
                        title: "Type",
                        value:
                            opportunity
                                .opportunityType
                    )
                }


                // MARK: - Support

                if hasSupportInformation {

                    Divider()

                    VStack(
                        alignment: .leading,
                        spacing: 16
                    ) {

                        Text(
                            "Support & Accessibility"
                        )
                        .font(.title2)
                        .fontWeight(.bold)

                        if let transportation =
                            opportunity
                                .transportation {

                            DetailRow(
                                icon: "bus",
                                title:
                                    "Transportation",
                                value:
                                    transportation
                            )
                        }

                        if opportunity
                            .mealsProvided {

                            DetailRow(
                                icon:
                                    "fork.knife",
                                title: "Meals",
                                value: "Provided"
                            )
                        }

                        if let accessibility =
                            opportunity
                                .accessibility {

                            DetailRow(
                                icon:
                                    "figure.roll",
                                title:
                                    "Accessibility",
                                value:
                                    accessibility
                            )
                        }
                    }
                }


                // MARK: - Parent Requirements

                if let requirements =
                    opportunity
                        .parentRequirements {

                    Divider()

                    VStack(
                        alignment: .leading,
                        spacing: 10
                    ) {

                        Text(
                            "Parent / Guardian Requirements"
                        )
                        .font(.title2)
                        .fontWeight(.bold)

                        Text(requirements)
                            .foregroundStyle(
                                .secondary
                            )
                    }
                }


                // MARK: - Capacity

                if let capacity =
                    opportunity.capacity {

                    Divider()

                    VStack(
                        alignment: .leading,
                        spacing: 16
                    ) {

                        Text("Availability")
                            .font(.title2)
                            .fontWeight(.bold)

                        DetailRow(
                            icon: "person.3",
                            title: "Capacity",
                            value:
                                "\(capacity) participants"
                        )
                    }
                }


                // MARK: - Registration

                Divider()

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {

                    Text("Registration")
                        .font(.title2)
                        .fontWeight(.bold)

                    DetailRow(
                        icon:
                            "square.and.pencil",
                        title: "Method",
                        value:
                            opportunity
                                .registrationMethod
                    )

                    if let registrationURL =
                        opportunity.registrationUrl,
                       let url =
                        URL(
                            string:
                                registrationURL
                        ) {

                        Link(
                            destination: url
                        ) {

                            HStack {

                                Spacer()

                                Text(
                                    "View Registration"
                                )
                                .fontWeight(
                                    .semibold
                                )

                                Image(
                                    systemName:
                                        "arrow.up.right"
                                )

                                Spacer()
                            }
                            .padding()
                            .background(
                                Color.primary
                            )
                            .foregroundStyle(
                                Color(
                                    .systemBackground
                                )
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 16
                                )
                            )
                        }
                    }
                }


                Spacer(
                    minLength: 30
                )
            }
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle("Opportunity")
        .navigationBarTitleDisplayMode(
            .inline
        )
        .toolbar {

            if authService.role == "youth" {

                ToolbarItem(
                    placement:
                        .topBarTrailing
                ) {

                    Button {

                        Task {

                            await savedService
                                .toggleSave(
                                    opportunityID:
                                        opportunity.id
                                )
                        }

                    } label: {

                        Image(
                            systemName:
                                savedService
                                    .isSaved(
                                        opportunity.id
                                    )
                                ? "bookmark.fill"
                                : "bookmark"
                        )
                    }
                    .accessibilityLabel(
                        savedService
                            .isSaved(
                                opportunity.id
                            )
                        ? "Remove from saved opportunities"
                        : "Save opportunity"
                    )
                }
            }
        }
    }


    // MARK: - Cost

    private var formattedCost: String {

        let dollars =
            Double(
                opportunity.costCents
            ) / 100

        return dollars.formatted(
            .currency(
                code: "USD"
            )
        )
    }


    // MARK: - Age

    private var ageText: String? {

        switch (
            opportunity.ageMin,
            opportunity.ageMax
        ) {

        case let (min?, max?):

            return "\(min)–\(max)"

        case let (min?, nil):

            return "\(min)+"

        case let (nil, max?):

            return "Up to \(max)"

        default:

            return nil
        }
    }


    // MARK: - Grade

    private var gradeText: String? {

        switch (
            opportunity.gradeMin,
            opportunity.gradeMax
        ) {

        case let (min?, max?):

            if min == 0 &&
                max == 0 {

                return "Kindergarten"
            }

            if min == 0 {

                return "Kindergarten–\(max)"
            }

            return "\(min)–\(max)"

        case let (min?, nil):

            if min == 0 {

                return "Kindergarten+"
            }

            return "\(min)+"

        case let (nil, max?):

            if max == 0 {

                return "Kindergarten"
            }

            return "Up to \(max)"

        default:

            return nil
        }
    }


    // MARK: - Support Check

    private var hasSupportInformation:
        Bool {

        opportunity.transportation != nil ||
        opportunity.mealsProvided ||
        opportunity.accessibility != nil
    }


    // MARK: - Address

    private func formattedAddress(
        street: String,
        city: String,
        state: String,
        postalCode: String?
    ) -> String {

        if let postalCode,
           !postalCode.isEmpty {

            return
                "\(street), \(city), \(state) \(postalCode)"
        }

        return
            "\(street), \(city), \(state)"
    }
}


// MARK: - Detail Row

struct DetailRow: View {

    let icon: String
    let title: String
    let value: String

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 14
        ) {

            Image(
                systemName: icon
            )
            .frame(width: 24)
            .foregroundStyle(
                .secondary
            )

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(title)
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                Text(value)
                    .font(.body)
                    .fontWeight(
                        .medium
                    )
            }

            Spacer()
        }
    }
}
