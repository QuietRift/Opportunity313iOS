//
//  OpportunityCalendarView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct OpportunityCalendarView: View {

    @StateObject private var opportunityService =
        OpportunityService()

    @EnvironmentObject var savedService:
        SavedOpportunityService

    @State private var selectedDate = Date()
    @State private var savedOnly = false
    @State private var didSetInitialDate = false

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: 24) {

                    if let error = opportunityService.errorMessage {
                        ContentUnavailableView("Unable to Load Calendar", systemImage: "exclamationmark.triangle", description: Text(error))
                    }

                    // MARK: Calendar

                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)


                    // MARK: Selected Day

                    selectedDaySection


                    Divider()


                    // MARK: Upcoming

                    upcomingSection
                }
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .safeAreaInset(edge: .top) {
                Picker("Calendar Filter", selection: $savedOnly) {
                    Text("All Opportunities").tag(false)
                    Text("Saved").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.background)
                .accessibilityIdentifier("calendarFilter")
            }
            .onChange(of: savedOnly) {
                if selectedDayItems.isEmpty, let next = upcomingItems.first { selectedDate = next.date }
            }
            .navigationTitle("Calendar")
            .task {

                await opportunityService
                    .fetchOpportunities()

                await savedService
                    .loadSaves()

                setInitialDate()
            }
            .refreshable {

                await opportunityService
                    .fetchOpportunities()

                await savedService
                    .loadSaves()
            }
        }
    }


    // MARK: - Selected Day

    private var selectedDaySection: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text(
                selectedDate.formatted(
                    date: .complete,
                    time: .omitted
                )
            )
            .font(.title2)
            .fontWeight(.bold)

            if selectedDayItems.isEmpty {

                VStack(spacing: 12) {

                    Image(
                        systemName: "calendar"
                    )
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)

                    Text("Nothing scheduled")
                        .font(.headline)

                    Text(
                        savedOnly
                        ? "You don't have any saved opportunities or deadlines on this date."
                        : "There are no Opportunity313 events or deadlines on this date."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(
                    maxWidth: .infinity
                )
                .padding(.vertical, 28)

            } else {

                ForEach(selectedDayItems) { item in

                    NavigationLink {

                        OpportunityDetailView(
                            opportunity:
                                item.opportunity
                        )

                    } label: {

                        CalendarOpportunityCard(
                            item: item
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    // MARK: - Upcoming

    private var upcomingSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                Text(
                    savedOnly
                    ? "Upcoming Saved"
                    : "Coming Up"
                )
                .font(.title2)
                .fontWeight(.bold)

                Spacer()
            }

            if upcomingItems.isEmpty {

                Text(
                    savedOnly
                    ? "Save opportunities and they'll appear here."
                    : "No upcoming opportunities are available."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

            } else {

                ForEach(
                    Array(upcomingItems.prefix(8))
                ) { item in

                    NavigationLink {

                        OpportunityDetailView(
                            opportunity:
                                item.opportunity
                        )

                    } label: {

                        CalendarOpportunityCard(
                            item: item
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    // MARK: - Visible Opportunities

    private var visibleOpportunities:
        [Opportunity] {

        if savedOnly {

            return opportunityService
                .opportunities
                .filter {

                    savedService
                        .savedOpportunityIDs
                        .contains($0.id)
                }
        }

        return opportunityService
            .opportunities
    }


    // MARK: - Calendar Items

    private var calendarItems:
        [OpportunityCalendarItem] {

        var items:
            [OpportunityCalendarItem] = []

        for opportunity in visibleOpportunities {

            // Actual opportunity date

            if let startsAt = opportunity.startsAt {
                items.append(
                    OpportunityCalendarItem(
                        id:
                            "\(opportunity.id.uuidString)-event",
                        opportunity:
                            opportunity,
                        type:
                            .event,
                        date: startsAt
                    )
                )
            }

            // Registration deadline

            if let deadline =
                opportunity.deadline {

                items.append(
                    OpportunityCalendarItem(
                        id:
                            "\(opportunity.id.uuidString)-deadline",
                        opportunity:
                            opportunity,
                        type:
                            .deadline,
                        date:
                            deadline
                    )
                )
            }
        }

        return items.sorted {
            $0.date < $1.date
        }
    }


    // MARK: - Selected Date Items

    private var selectedDayItems:
        [OpportunityCalendarItem] {

        calendarItems.filter {

            Calendar.current.isDate(
                $0.date,
                inSameDayAs:
                    selectedDate
            )
        }
    }


    // MARK: - Upcoming Items

    private var upcomingItems:
        [OpportunityCalendarItem] {

        let today =
            Calendar.current.startOfDay(
                for: Date()
            )

        return calendarItems.filter {

            $0.date >= today
        }
    }


    // MARK: - Initial Date

    private func setInitialDate() {

        guard !didSetInitialDate else {
            return
        }

        didSetInitialDate = true

        let today =
            Calendar.current.startOfDay(
                for: Date()
            )

        if let firstUpcoming =
            calendarItems.first(
                where: {
                    $0.date >= today
                }
            ) {

            selectedDate =
                firstUpcoming.date
        }
    }
}


// MARK: - Calendar Item Model

struct OpportunityCalendarItem:
    Identifiable {

    let id: String

    let opportunity:
        Opportunity

    let type:
        OpportunityCalendarItemType

    let date:
        Date
}


// MARK: - Calendar Item Type

enum OpportunityCalendarItemType {

    case event
    case deadline

    var title: String {

        switch self {

        case .event:
            return "Opportunity"

        case .deadline:
            return "Deadline"
        }
    }

    var icon: String {

        switch self {

        case .event:
            return "calendar"

        case .deadline:
            return "clock.badge.exclamationmark"
        }
    }
}


// MARK: - Calendar Card

struct CalendarOpportunityCard: View {

    @EnvironmentObject var savedService:
        SavedOpportunityService

    let item:
        OpportunityCalendarItem

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 14
        ) {

            VStack(spacing: 4) {

                Text(
                    item.date.formatted(
                        .dateTime.day()
                    )
                )
                .font(.title2)
                .fontWeight(.bold)

                Text(
                    item.date.formatted(
                        .dateTime.month(
                            .abbreviated
                        )
                    )
                    .uppercased()
                )
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            }
            .frame(width: 48)


            VStack(
                alignment: .leading,
                spacing: 7
            ) {

                HStack {

                    Label(
                        item.type.title,
                        systemImage:
                            item.type.icon
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                    Spacer()

                    if savedService.isSaved(
                        item.opportunity.id
                    ) {

                        Image(
                            systemName:
                                "bookmark.fill"
                        )
                        .font(.caption)
                    }
                }

                Text(
                    item.opportunity.title
                )
                .font(.headline)

                HStack(spacing: 14) {

                    Label(
                        item.date.formatted(
                            date: .omitted,
                            time: .shortened
                        ),
                        systemImage:
                            "clock"
                    )

                    if let neighborhood =
                        item.opportunity
                            .neighborhood {

                        Label(
                            neighborhood,
                            systemImage:
                                "mappin"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(
                systemName:
                    "chevron.right"
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            Color(
                .secondarySystemBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16
            )
        )
    }
}
