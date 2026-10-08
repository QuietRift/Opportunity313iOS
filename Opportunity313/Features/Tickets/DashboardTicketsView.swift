import SwiftUI

struct DashboardTicketsListView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var service = OpportunityTicketService()
    @StateObject private var eventService = TicketService()
    var body: some View {
        List {
            Section("Opportunity Tickets") {
                if service.isLoading { ProgressView() }
                if let error = service.errorMessage {
                    Text(error).foregroundStyle(.secondary)
                    Button("Try Again") { Task { await service.load() } }
                }
                ForEach(service.tickets) { ticket in
                    NavigationLink { OpportunityTicketDetailView(ticket: ticket) } label: {
                        OpportunityTicketRow(ticket: ticket)
                    }
                }
                if service.tickets.isEmpty && !service.isLoading { Text("No opportunity tickets yet.").foregroundStyle(.secondary) }
            }
            Section("Event Tickets") {
                if eventService.isLoading { ProgressView("Loading event tickets…") }
                if let error = eventService.errorMessage {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry Event Tickets") { Task { await eventService.loadTickets() } }
                }
                ForEach(eventService.tickets) { ticket in
                    NavigationLink { TicketDetailView(initialTicket: ticket, service: eventService) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            if ticket.isDemo { Text("Demo Ticket").font(.caption.bold()) }
                            Text(ticket.eventTitle).font(.headline)
                            if let attendee = ticket.assignedYouthName { Text("For: \(attendee)").font(.subheadline) }
                            Text(ticket.dateText).font(.subheadline).foregroundStyle(.secondary)
                            Text(ticket.statusText).font(.caption.bold())
                        }.padding(.vertical, 4)
                    }
                }
                if eventService.tickets.isEmpty && !eventService.isLoading {
                    Text("No event tickets yet.").foregroundStyle(.secondary)
                }
            }
            NavigationLink("Get Event Tickets") { TicketEventsView() }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("My Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await reload() }
        .refreshable { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .opportunityTicketsDidChange)) { _ in Task { await reload() } }
        .onReceive(NotificationCenter.default.publisher(for: .managedYouthProfileDidChange)) { _ in Task { await reload() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await reload() } } }
        .opportunity313PageBackground()
    }
    private func reload() async {
        async let opportunities: () = service.load()
        async let events: () = eventService.loadTickets()
        _ = await (opportunities, events)
    }
}

private struct OpportunityTicketRow: View {
    let ticket: OpportunityTicket
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if ticket.isDemo { Text("Demo Ticket").font(.caption.bold()) }
            Text(ticket.opportunityName).font(.headline)
            Text("For: \(ticket.attendeeName)").font(.subheadline)
            Text(ticket.dateText).font(.subheadline).foregroundStyle(.secondary)
            Text(ticket.displayStatus(at: Date()).title).font(.caption.bold())
            Label("View Ticket", systemImage: "qrcode").font(.subheadline.bold())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OpportunityTicketDetailView: View {
    let initialTicket: OpportunityTicket
    @StateObject private var service = OpportunityTicketService()
    @State private var hasLoaded = false
    @State private var confirmCancel = false
    private var ticket: OpportunityTicket { service.tickets.first { $0.id == initialTicket.id } ?? initialTicket }

    init(ticket: OpportunityTicket) { initialTicket = ticket }

    var body: some View {
        Group {
            if hasLoaded && service.errorMessage == nil && !service.tickets.contains(where: { $0.id == initialTicket.id }) {
                ContentUnavailableView("Registration Unavailable", systemImage: "ticket",
                    description: Text("This registration is no longer available to your account."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if ticket.isDemo { Text("Demo — not valid for admission").font(.headline) }
                        Text("Opportunity 313 Ticket").font(.subheadline).foregroundStyle(.secondary)
                        Text(ticket.opportunityName).font(.largeTitle.bold())
                        Label(ticket.attendeeName, systemImage: "person.fill")
                        Label(ticket.dateText, systemImage: "calendar")
                        Label(ticket.location, systemImage: "mappin.and.ellipse")
                        Text(ticket.address).foregroundStyle(.secondary)
                        Label(ticket.registrationStatusText(at: Date()), systemImage: "ticket")
                        if let attendedAt = ticket.attendedAt {
                            Text("Attendance recorded \(TicketDate.text(attendedAt, timezone: ticket.timezone))").font(.subheadline)
                        }
                        if ticket.displayStatus(at: Date()) == .upcoming && service.errorMessage == nil {
                            TicketQRCode(token: ticket.entryCode, prefix: "opportunity313:opportunity-ticket:")
                            Text("Show this ticket to the opportunity provider.").font(.subheadline)
                        }
                        Text("Ticket ID: \(ticket.id.uuidString)").font(.caption).textSelection(.enabled)
                        if ticket.canCancel == true && ticket.status == .upcoming {
                            Button("Cancel Registration", role: .destructive) { confirmCancel = true }
                                .disabled(service.isWorking || service.isLoading)
                                .accessibilityIdentifier("cancelOpportunityRegistration")
                        }
                        if service.isWorking { ProgressView("Cancelling registration…") }
                        if let error = service.errorMessage {
                            Text(error).foregroundStyle(.red)
                            Button("Refresh Registration") { Task { await reload() } }
                        }
                    }.padding().frame(maxWidth: 650).frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Registration").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await reload() }
        .refreshable { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .opportunityTicketsDidChange)) { _ in Task { await reload() } }
        .confirmationDialog("Cancel this registration?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel Registration", role: .destructive) { Task { _ = await service.cancel(registrationID: ticket.id) } }
        } message: { Text("This releases the attendee's spot and makes this ticket invalid.") }
        .opportunity313PageBackground()
    }

    private func reload() async {
        await service.load()
        hasLoaded = true
    }
}

struct OpportunityRegistrationView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var family = ParentManagedYouthService()
    @StateObject private var profile = YouthProfileService()
    @StateObject private var service = OpportunityTicketService()
    let opportunity: Opportunity
    var initialYouthProfileID: UUID?
    @State private var selectedYouthProfileID: UUID?
    @State private var ready = false
    @State private var confirmedTickets: [OpportunityTicket]?
    @State private var selectedChildren: Set<UUID> = []
    @State private var includeSelf = true

    var body: some View {
        NavigationStack {
            Group {
                if let confirmedTickets {
                    List {
                        Section("Registration Confirmed") {
                            Text("Your selected attendees are registered. Each attendee has their own ticket.")
                            ForEach(confirmedTickets) { ticket in
                                NavigationLink { OpportunityTicketDetailView(ticket: ticket) } label: {
                                    VStack(alignment: .leading) { Text(ticket.attendeeName).font(.headline); Text(ticket.opportunityName) }
                                }
                            }
                        }
                    }.navigationTitle("Your Registrations")
                } else {
                    Form {
                        Section { Text(opportunity.title).font(.headline); Text(opportunity.startDisplayText) }
                        Section("Attendee") {
                            if !ready { ProgressView("Loading attendees…") }
                            else if authService.role == "parent" {
                                Toggle("Myself", isOn: $includeSelf)
                                ForEach(family.children.filter { opportunity.matchesEligibility(for: $0) }) { child in
                                    Toggle(child.firstName, isOn: Binding(
                                        get: { selectedChildren.contains(child.id) },
                                        set: { if $0 { selectedChildren.insert(child.id) } else { selectedChildren.remove(child.id) } }
                                    ))
                                }
                                Text("Choose everyone attending. All selected spots are reserved together.").font(.footnote)
                            } else if let youth = profile.currentProfile {
                                Text(youth.firstName)
                            } else { Text("Your profile could not be loaded.") }
                            if let error = family.errorMessage ?? profile.errorMessage {
                                Text(error).foregroundStyle(.red)
                                Button("Reload Attendees") { Task { await loadAttendees() } }
                            }
                        }
                        Section {
                            Text("Confirm registration to create a ticket. It will appear in My Tickets for the attendee and their linked parent.")
                            if let error = service.errorMessage { Text(error).foregroundStyle(.red) }
                            Button("Confirm Registration") {
                                Task {
                                    let ids = authService.role == "parent" ? Array(selectedChildren) : [selectedYouthProfileID].compactMap { $0 }
                                    confirmedTickets = await service.registerFamily(opportunityID: opportunity.id, youthProfileIDs: ids, includeSelf: authService.role == "parent" && includeSelf)
                                }
                            }
                            .disabled(!ready || service.isWorking || (authService.role == "parent" ? (!includeSelf && selectedChildren.isEmpty) : profile.currentProfile == nil))
                            .accessibilityIdentifier("confirmOpportunityRegistration")
                            if service.isWorking { ProgressView("Registering…") }
                        }
                    }.navigationTitle("Get Ticket")
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await loadAttendees() }
        }
    }

    private func loadAttendees() async {
        ready = false
        if authService.role == "parent" {
            await family.fetchChildren()
            selectedYouthProfileID = family.children.first { $0.id == initialYouthProfileID && opportunity.matchesEligibility(for: $0) }?.id
            selectedChildren = Set([selectedYouthProfileID].compactMap { $0 })
            includeSelf = selectedYouthProfileID == nil
        } else {
            await profile.fetchCurrentProfile()
            selectedYouthProfileID = profile.currentProfile?.id
        }
        ready = family.errorMessage == nil && profile.errorMessage == nil
    }
}
