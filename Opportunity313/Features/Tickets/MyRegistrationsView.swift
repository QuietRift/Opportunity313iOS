import SwiftUI

struct MyRegistrationsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var service = OpportunityTicketService()
    @StateObject private var events = TicketService()
    @State private var phase: RegistrationPhase = .upcoming
    @State private var attendee = "all"

    private var attendees: [(key: String, name: String)] {
        Dictionary(service.tickets.map { ($0.attendeeKey, $0.attendeeName) }, uniquingKeysWith: { first, _ in first })
            .map { (key: $0.key, name: $0.value) }.sorted { $0.name < $1.name }
    }
    private var registrations: [OpportunityTicket] {
        service.tickets.filter {
            $0.registrationPhase(at: Date()) == phase && (attendee == "all" || $0.attendeeKey == attendee)
        }.sorted { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
    }
    private var eventRegistrations: [EventTicket] {
        events.tickets.filter { $0.registrationPhase(at: Date()) == phase }
    }

    var body: some View {
        List {
            NavigationLink { RegistrationUpdatesView() } label: { Label("Opportunity Updates", systemImage: "bell") }
            Section {
                Picker("Registration status", selection: $phase) {
                    ForEach(RegistrationPhase.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                    .accessibilityIdentifier("registrationStatusFilter")
                if attendees.count > 1 {
                    Picker("Opportunity attendee", selection: $attendee) {
                        Text("All attendees").tag("all")
                        ForEach(attendees, id: \.key) { Text($0.name).tag($0.key) }
                    }
                }
            }
            Section("Opportunity Registrations") {
                if service.isLoading && service.tickets.isEmpty { ProgressView("Loading registrations…") }
                if let error = service.errorMessage {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry Registrations") { Task { await service.load() } }
                }
                ForEach(registrations) { registration in
                    NavigationLink { OpportunityTicketDetailView(ticket: registration) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            if registration.isDemo { Text("Demo Registration").font(.caption.bold()) }
                            Text(registration.opportunityName).font(.headline)
                            Text("For: \(registration.attendeeName)")
                            Text(registration.dateText).font(.subheadline).foregroundStyle(.secondary)
                            Text(registration.registrationStatusText(at: Date())).font(.caption.bold())
                        }.padding(.vertical, 4)
                    }
                }
                if registrations.isEmpty && !service.isLoading && service.errorMessage == nil {
                    Text("No \(phase.rawValue.lowercased()) opportunity registrations.").foregroundStyle(.secondary)
                }
            }
            Section("Event Reservations") {
                if events.isLoading && events.tickets.isEmpty { ProgressView("Loading event reservations…") }
                if let error = events.errorMessage {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry Event Reservations") { Task { await events.loadTickets() } }
                }
                ForEach(eventRegistrations) { ticket in
                    NavigationLink { TicketDetailView(initialTicket: ticket, service: events) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            if ticket.isDemo { Text("Demo Reservation").font(.caption.bold()) }
                            Text(ticket.eventTitle).font(.headline)
                            if let name = ticket.assignedYouthName { Text("For: \(name)") }
                            Text(ticket.dateText).font(.subheadline).foregroundStyle(.secondary)
                            Text(ticket.statusText).font(.caption.bold())
                        }.padding(.vertical, 4)
                    }
                }
                if eventRegistrations.isEmpty && !events.isLoading && events.errorMessage == nil {
                    Text("No \(phase.rawValue.lowercased()) event reservations.").foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Registrations completed on a provider's website are managed by that provider and do not appear here automatically.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("My Registrations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden)
        .task { await reload() }
        .refreshable { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .opportunityTicketsDidChange)) { _ in Task { await reload() } }
        .onReceive(NotificationCenter.default.publisher(for: .managedYouthProfileDidChange)) { _ in Task { await reload() } }
        .onChange(of: scenePhase) { _, state in if state == .active { Task { await reload() } } }
        .opportunity313PageBackground()
    }

    private func reload() async {
        async let opportunityLoad: () = service.load()
        async let eventLoad: () = events.loadTickets()
        _ = await (opportunityLoad, eventLoad)
        if attendee != "all" && !attendees.contains(where: { $0.key == attendee }) { attendee = "all" }
    }
}
