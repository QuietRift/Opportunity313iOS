//
//  ParentCalendarView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ParentCalendarView: View {

    @StateObject private var childService =
        ParentManagedYouthService()

    @StateObject private var opportunityService =
        OpportunityService()

    @EnvironmentObject var familySaveService:
        FamilySaveService

    @State private var selectedDate = Date()
    @State private var didSetInitialDate = false

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 24
                ) {

                    DatePicker(
                        "Select Date",
                        selection:
                            $selectedDate,
                        displayedComponents:
                            .date
                    )
                    .datePickerStyle(
                        .graphical
                    )
                    .labelsHidden()


                    selectedDaySection


                    Divider()


                    upcomingSection
                }
                .padding()
            }
            .navigationTitle(
                "Family Calendar"
            )
            .task {

                await loadData()
            }
            .refreshable {

                await loadData()
            }
        }
    }


    // MARK: - Selected Day

    private var selectedDaySection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text(
                selectedDate
                    .formatted(
                        date:
                            .complete,
                        time:
                            .omitted
                    )
            )
            .font(.title2)
            .fontWeight(.bold)


            if selectedDayItems.isEmpty {

                VStack(spacing: 12) {

                    Image(
                        systemName:
                            "calendar"
                    )
                    .font(
                        .system(
                            size: 36
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        "Nothing scheduled"
                    )
                    .font(.headline)

                    Text(
                        "Saved opportunities and deadlines for your children will appear here."
                    )
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .center
                    )
                }
                .frame(
                    maxWidth: .infinity
                )
                .padding(
                    .vertical,
                    28
                )

            } else {

                ForEach(
                    selectedDayItems
                ) { item in

                    NavigationLink {

                        OpportunityDetailView(
                            opportunity:
                                item.opportunity
                        )

                    } label: {

                        ParentCalendarCard(
                            item: item
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    // MARK: - Upcoming

    private var upcomingSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Text("Coming Up")
                .font(.title2)
                .fontWeight(.bold)


            if upcomingItems.isEmpty {

                ContentUnavailableView(
                    "No Family Plans Yet",
                    systemImage:
                        "calendar.badge.plus",
                    description:
                        Text(
                            "Save an opportunity for a child and it will appear on the family calendar."
                        )
                )

            } else {

                ForEach(
                    Array(
                        upcomingItems
                            .prefix(12)
                    )
                ) { item in

                    NavigationLink {

                        OpportunityDetailView(
                            opportunity:
                                item.opportunity
                        )

                    } label: {

                        ParentCalendarCard(
                            item: item
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }


    // MARK: - Calendar Items

    private var calendarItems:
        [ParentCalendarItem] {

        var items:
            [ParentCalendarItem] = []

        for child in
            childService.children {

            let savedIDs =
                familySaveService
                    .savedByYouth[
                        child.id
                    ] ?? []

            let savedOpportunities =
                opportunityService
                    .opportunities
                    .filter {

                        savedIDs.contains(
                            $0.id
                        )
                    }

            for opportunity in
                savedOpportunities {

                items.append(
                    ParentCalendarItem(
                        id:
                            "\(child.id.uuidString)-\(opportunity.id.uuidString)-event",
                        child:
                            child,
                        opportunity:
                            opportunity,
                        type:
                            .event,
                        date:
                            opportunity
                                .startsAt
                    )
                )


                if let deadline =
                    opportunity.deadline {

                    items.append(
                        ParentCalendarItem(
                            id:
                                "\(child.id.uuidString)-\(opportunity.id.uuidString)-deadline",
                            child:
                                child,
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
        }

        return items.sorted {

            $0.date < $1.date
        }
    }


    // MARK: - Selected Day Items

    private var selectedDayItems:
        [ParentCalendarItem] {

        calendarItems.filter {

            Calendar.current
                .isDate(
                    $0.date,
                    inSameDayAs:
                        selectedDate
                )
        }
    }


    // MARK: - Upcoming Items

    private var upcomingItems:
        [ParentCalendarItem] {

        let today =
            Calendar.current
                .startOfDay(
                    for: Date()
                )

        return calendarItems
            .filter {

                $0.date >= today
            }
    }


    // MARK: - Load

    private func loadData() async {

        await childService
            .fetchChildren()

        await opportunityService
            .fetchOpportunities()

        let childIDs =
            childService.children
                .map {
                    $0.id
                }

        await familySaveService
            .loadSaves(
                for: childIDs
            )

        setInitialDate()
    }


    // MARK: - Initial Date

    private func setInitialDate() {

        guard !didSetInitialDate else {
            return
        }

        didSetInitialDate = true

        let today =
            Calendar.current
                .startOfDay(
                    for: Date()
                )

        if let firstUpcoming =
            calendarItems
                .first(
                    where: {
                        $0.date >= today
                    }
                ) {

            selectedDate =
                firstUpcoming.date
        }
    }
}


// MARK: - Family Calendar Item

struct ParentCalendarItem:
    Identifiable {

    let id: String
    let child: YouthProfile
    let opportunity: Opportunity
    let type:
        ParentCalendarItemType
    let date: Date
}


// MARK: - Item Type

enum ParentCalendarItemType {

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


// MARK: - Family Calendar Card

struct ParentCalendarCard: View {

    let item: ParentCalendarItem

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 14
        ) {

            VStack(spacing: 4) {

                Text(
                    item.date
                        .formatted(
                            .dateTime.day()
                        )
                )
                .font(.title2)
                .fontWeight(.bold)

                Text(
                    item.date
                        .formatted(
                            .dateTime
                                .month(
                                    .abbreviated
                                )
                        )
                        .uppercased()
                )
                .font(.caption)
                .fontWeight(
                    .semibold
                )
                .foregroundStyle(
                    .secondary
                )
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
                    .fontWeight(
                        .semibold
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    Text(
                        item.child.firstName
                    )
                    .font(.caption)
                    .fontWeight(
                        .semibold
                    )
                    .padding(
                        .horizontal,
                        9
                    )
                    .padding(
                        .vertical,
                        4
                    )
                    .background(
                        Color(
                            .tertiarySystemBackground
                        )
                    )
                    .clipShape(
                        Capsule()
                    )
                }


                Text(
                    item.opportunity
                        .title
                )
                .font(.headline)


                HStack(spacing: 14) {

                    Label(
                        item.date
                            .formatted(
                                date:
                                    .omitted,
                                time:
                                    .shortened
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
                .foregroundStyle(
                    .secondary
                )
            }


            Spacer()


            Image(
                systemName:
                    "chevron.right"
            )
            .font(.caption)
            .foregroundStyle(
                .tertiary
            )
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
