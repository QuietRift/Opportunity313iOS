import SwiftUI

struct ProviderAttendeeDirectoryView: View {
    let organization: Organization
    @StateObject private var service = ProviderOpportunityService()
    private var opportunities: [Opportunity] { service.opportunities.filter { $0.offersInAppTickets } }
    var body: some View {
        List {
            if service.isLoading && opportunities.isEmpty { ProgressView("Loading opportunities…") }
            if let error = service.errorMessage {
                Text(error).foregroundStyle(.secondary)
                Button("Try Again") { Task { await service.fetchOpportunities(organizationID: organization.id) } }
            }
            ForEach(opportunities) { opportunity in
                NavigationLink { OpportunityAttendeesView(opportunity: opportunity) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(opportunity.title).font(.headline)
                        Text(opportunity.startDisplayText).font(.subheadline).foregroundStyle(.secondary)
                        Text(opportunity.organizationApprovalStatus).font(.caption)
                    }
                }
            }
            if opportunities.isEmpty && !service.isLoading && service.errorMessage == nil {
                ContentUnavailableView("No In-App Registrations Yet", systemImage: "person.3",
                    description: Text("Attendees appear here for opportunities that accept registration in Opportunity 313."))
            }
            Text("Registrations on outside websites are managed by their providers.").font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Attendees")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden)
        .task { await service.fetchOpportunities(organizationID: organization.id) }
        .refreshable { await service.fetchOpportunities(organizationID: organization.id) }
        .opportunity313PageBackground()
    }
}

struct OpportunityAttendeesView: View {
    let opportunity: Opportunity
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var service = OpportunityAttendeeService()
    @State private var pendingAttendance: OpportunityAttendee?

    var body: some View {
        List {
            Section {
                Text(opportunity.title).font(.headline)
                Text(opportunity.startDisplayText).foregroundStyle(.secondary)
                if opportunity.isDemo { Text("Demo Opportunity").font(.caption.bold()) }
            }
            if opportunity.status == "published" || opportunity.status == "closed" {
                NavigationLink { PublishOpportunityUpdateView(opportunity: opportunity) } label: { Label("Send Opportunity Update", systemImage: "bell.badge") }
            }
            if service.isLoading && service.roster == nil { ProgressView("Loading attendees…") }
            if let error = service.errorMessage {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button("Try Again") { Task { await service.load(opportunityID: opportunity.id) } }
                }
            }
            if let roster = service.roster {
                Section("Registration Summary") {
                    LabeledContent("Registered", value: "\(roster.registeredCount)")
                    LabeledContent("Attended", value: "\(roster.attendedCount)")
                    LabeledContent("Cancelled", value: "\(roster.cancelledCount)")
                    if let remaining = roster.remaining, let capacity = roster.capacity {
                        LabeledContent("Remaining spots", value: "\(remaining) of \(capacity)")
                    } else { Text("No seat limit set").foregroundStyle(.secondary) }
                }
                Section("Attendees") {
                    if roster.attendees.isEmpty { Text("No registrations yet.").foregroundStyle(.secondary) }
                    ForEach(roster.attendees) { attendee in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(attendee.attendeeName).font(.headline)
                            Text(attendee.statusText).font(.subheadline.weight(.semibold))
                            Text("Registered \(TicketDate.text(attendee.registeredAt, timezone: opportunity.timezone))")
                                .font(.caption).foregroundStyle(.secondary)
                            if let attendedAt = attendee.attendedAt {
                                Text("Attendance recorded \(TicketDate.text(attendedAt, timezone: opportunity.timezone))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if attendee.status == .upcoming {
                                Button("Mark Attended") { pendingAttendance = attendee }
                                    .disabled(service.isWorking || service.isLoading)
                                    .accessibilityLabel("Mark \(attendee.attendeeName) attended")
                            }
                        }.padding(.vertical, 4)
                    }
                }
            }
            if service.isWorking { ProgressView("Recording attendance…") }
        }
        .navigationTitle("Attendees")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollContentBackground(.hidden)
        .task { await service.load(opportunityID: opportunity.id) }
        .refreshable { await service.load(opportunityID: opportunity.id) }
        .onChange(of: scenePhase) { _, state in if state == .active { Task { await service.load(opportunityID: opportunity.id) } } }
        .onReceive(NotificationCenter.default.publisher(for: .opportunityTicketsDidChange)) { _ in
            if !service.isWorking { Task { await service.load(opportunityID: opportunity.id) } }
        }
        .confirmationDialog("Record attendance?", isPresented: Binding(
            get: { pendingAttendance != nil }, set: { if !$0 { pendingAttendance = nil } }
        ), titleVisibility: .visible) {
            if let attendee = pendingAttendance {
                Button("Mark \(attendee.attendeeName) Attended") {
                    Task { await service.markAttended(registrationID: attendee.id, opportunityID: opportunity.id) }
                }
            }
        } message: { Text("This marks the registration as attended and uses its ticket.") }
        .opportunity313PageBackground()
    }
}
