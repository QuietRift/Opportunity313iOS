import SwiftUI

struct SchoolTicketAdministrationView: View {
    @EnvironmentObject private var authService: AuthService
    var body: some View {
        NavigationStack {
            List {
                Section("Ticketing") {
                    NavigationLink { TicketEventsView(managedOnly: true) } label: {
                        Label("Event Seats & Check-In", systemImage: "ticket")
                    }
                    if authService.role == "admin" {
                        NavigationLink { SchoolTicketAdminsView() } label: {
                            Label("School Ticket Admins", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                }
                Section {
                    Text("A platform admin assigns a confirmed staff account to a school. That school's ticket admin controls event seats and ticket availability; other event staff can check tickets at the gate.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Ticketing")
            .opportunity313PageBackground()
        }
    }
}

struct SchoolTicketAdminsView: View {
    @StateObject private var service = SchoolTicketService()
    @State private var selectedSchool: UUID?
    @State private var email = ""
    @State private var toRevoke: SchoolTicketAdmin?
    var body: some View {
        Form {
            Section("Assign School Ticket Admin") {
                Picker("School", selection: $selectedSchool) {
                    Text("Choose a school").tag(nil as UUID?)
                    ForEach(service.schools) { school in Text(school.name).tag(Optional(school.id)) }
                }
                TextField("Confirmed staff account email", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Assign Ticket Admin") {
                    guard let selectedSchool else { return }
                    Task { if await service.assign(schoolID: selectedSchool, email: email) { email = "" } }
                }
                .disabled(service.isWorking || selectedSchool == nil || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Use a separate confirmed staff account. This gives ticket control only for the selected school.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Current School Admins") {
                if service.isWorking && service.schools.isEmpty { ProgressView("Loading schools…") }
                if service.admins.isEmpty && !service.isWorking { Text("No school ticket admins assigned yet.").foregroundStyle(.secondary) }
                ForEach(service.admins) { admin in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(admin.email).font(.headline)
                        Text(service.schools.first { $0.id == admin.schoolID }?.name ?? "School")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Remove Access", role: .destructive) { toRevoke = admin }
                    }.padding(.vertical, 4)
                }
            }
            if let notice = service.notice { Section { Label(notice, systemImage: "checkmark.circle") } }
            if let error = service.errorMessage {
                Section { Text(error).foregroundStyle(.red)
                    Button("Try Again") { Task { await service.loadStaff() } }
                }
            }
        }
        .navigationTitle("School Ticket Admins")
        .task { await service.loadStaff() }
        .refreshable { await service.loadStaff() }
        .confirmationDialog("Remove school ticket access?", isPresented: Binding(get: { toRevoke != nil }, set: { if !$0 { toRevoke = nil } }), titleVisibility: .visible) {
            Button("Remove Access", role: .destructive) {
                guard let admin = toRevoke else { return }
                toRevoke = nil
                Task { await service.revoke(membershipID: admin.id) }
            }
        } message: { Text("Their existing tickets remain with their account, but they can no longer control seats or check tickets for this school.") }
        .opportunity313PageBackground()
    }
}

struct SchoolTicketCapacityView: View {
    let initialEvent: TicketEvent
    @StateObject private var tickets = TicketService()
    @StateObject private var school = SchoolTicketService()
    @State private var venueSeats: Int
    @State private var eventSeats: Int
    @State private var reason = ""
    private var current: TicketEvent { tickets.events.first { $0.id == initialEvent.id } ?? initialEvent }

    init(event: TicketEvent) {
        initialEvent = event
        _venueSeats = State(initialValue: event.venuePhysicalCapacity)
        _eventSeats = State(initialValue: event.operationalCapacity)
    }

    var body: some View {
        Form {
            Section("Event") {
                Text(current.title).font(.headline)
                if let schoolName = current.schoolName { Label(schoolName, systemImage: "building.2") }
                Text(current.venueName).foregroundStyle(.secondary)
                Text("Current status: \(current.eventStatus.replacingOccurrences(of: "_", with: " ").capitalized)")
            }
            Section("Venue and Event Seats") {
                LabeledContent("Venue seats") {
                    TextField("Venue seats", value: $venueSeats, format: .number)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                }
                LabeledContent("Event seat limit") {
                    TextField("Event seats", value: $eventSeats, format: .number)
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                }
                Text("The event limit cannot exceed venue seating. Student and guest allocations must fit within the event limit.")
                    .font(.footnote).foregroundStyle(.secondary)
                TextField("Reason for seat change", text: $reason)
                Button("Save Seat Limits") {
                    Task {
                        if await school.saveSeatLimits(eventID: current.id, venue: venueSeats, event: eventSeats, reason: reason) { await refresh() }
                    }
                }
                .disabled(school.isWorking || venueSeats<1 || eventSeats<1 || eventSeats>venueSeats || reason.trimmingCharacters(in: .whitespacesAndNewlines).count<3)
            }
            Section("Student, Guest & Other Spots") {
                ForEach(current.allocations) { allocation in
                    TicketAllocationEditor(allocation: allocation, isWorking: school.isWorking, reason: reason) { capacity in
                        if await school.saveAllocation(id: allocation.id, capacity: capacity, reason: reason) { await refresh() }
                    }
                }
                Text("Each allocation reserves part of the event seat limit. Lowering a category below confirmed tickets or active holds is blocked.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Reservation Availability") {
                Text("Sales window: \(TicketDate.text(current.salesOpenAt, timezone: current.timezone)) to \(TicketDate.text(current.salesCloseAt, timezone: current.timezone))")
                    .font(.subheadline)
                if current.eventStatus == "on_sale" {
                    Button("Pause New Reservations") {
                        Task { if await school.setSales(eventID: current.id, open: false) { await refresh() } }
                    }
                } else if ["published", "paused", "sold_out"].contains(current.eventStatus) {
                    Button("Open Reservations") {
                        Task { if await school.setSales(eventID: current.id, open: true) { await refresh() } }
                    }.disabled(Date() < current.salesOpenAt || Date() >= current.salesCloseAt || Date() >= current.startsAt)
                }
                Text("Pausing new reservations does not invalidate confirmed tickets.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let notice = school.notice { Section { Label(notice, systemImage: "checkmark.circle") } }
            if let error = school.errorMessage { Section { Text(error).foregroundStyle(.red) } }
            if let error = tickets.errorMessage { Section { Text(error).foregroundStyle(.red) } }
        }
        .navigationTitle("Seats & Availability")
        .task { await tickets.loadEvents(managedOnly: true) }
        .refreshable { await refresh() }
        .opportunity313PageBackground()
    }

    private func refresh() async {
        await tickets.loadEvents(managedOnly: true)
        if let updated = tickets.events.first(where: { $0.id == initialEvent.id }) {
            venueSeats = updated.venuePhysicalCapacity
            eventSeats = updated.operationalCapacity
        }
    }
}

private struct TicketAllocationEditor: View {
    let allocation: TicketAllocation
    let isWorking: Bool
    let reason: String
    let save: (Int) async -> Void
    @State private var capacity: Int
    init(allocation: TicketAllocation, isWorking: Bool, reason: String, save: @escaping (Int) async -> Void) {
        self.allocation = allocation
        self.isWorking = isWorking
        self.reason = reason
        self.save = save
        _capacity = State(initialValue: allocation.capacity)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(allocation.name).font(.headline)
            Text("\(allocation.remaining) available · \(allocation.capacity) allocated")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack {
                TextField("Allocated seats", value: $capacity, format: .number)
                    .keyboardType(.numberPad)
                Button("Save") { Task { await save(capacity) } }
                    .disabled(isWorking || capacity<1 || reason.trimmingCharacters(in: .whitespacesAndNewlines).count<3)
            }
        }.padding(.vertical, 4)
    }
}
