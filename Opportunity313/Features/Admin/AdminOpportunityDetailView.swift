import SwiftUI

struct AdminOpportunityDetailView: View {
    let opportunity: Opportunity
    @ObservedObject var adminService: AdminService
    @State private var organization: Organization?
    @State private var history: [AdminReviewEvent] = []
    @State private var contextError: String?
    @State private var showReview = false
    private var current: Opportunity { adminService.opportunities.first { $0.id == opportunity.id } ?? opportunity }

    var body: some View {
        OpportunityDetailView(opportunity: current)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(current.adminStatus).font(.headline)
                        Text(organization?.name ?? "Provider details in review").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Review & History") { showReview = true }.buttonStyle(.borderedProminent)
                }.padding().background(.regularMaterial)
            }
            .task(id: opportunity.id) { await loadContext() }
            .sheet(isPresented: $showReview, onDismiss: { Task { await loadContext() } }) {
                AdminDecisionSheet(opportunity: current, organization: organization, history: history,
                    contextError: contextError, service: adminService)
            }
    }
    private func loadContext() async {
        contextError = nil
        do {
            organization = try await adminService.organization(for: current)
            history = try await adminService.history(for: current)
        } catch { contextError = error.localizedDescription }
    }
}

struct AdminDecisionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let opportunity: Opportunity
    let organization: Organization?
    let history: [AdminReviewEvent]
    let contextError: String?
    @ObservedObject var service: AdminService
    @State private var reason = ""
    @State private var selectedDecision: AdminDecision?
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Opportunity") {
                    Text(opportunity.title).font(.headline)
                    LabeledContent("Status", value: opportunity.adminStatus)
                    LabeledContent("Verification", value: opportunity.verificationStatus.capitalized)
                    LabeledContent("Registration", value: opportunity.registrationMethod)
                    if let url = opportunity.registrationUrl { Text(url).font(.caption).textSelection(.enabled) }
                    if opportunity.startsAt == nil {
                        Label("A start date is required by the current publication rules.", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                if let organization {
                    Section("Provider") {
                        Text(organization.name).font(.headline)
                        LabeledContent("Verification", value: organization.verificationStatus.capitalized)
                        if let value = organization.description { Text(value) }
                        if let value = organization.contactName { LabeledContent("Contact", value: value) }
                        if let value = organization.contactEmail { LabeledContent("Email", value: value) }
                        if let value = organization.website { LabeledContent("Website", value: value) }
                    }
                }
                if let contextError { Section { Text(contextError).foregroundStyle(.red) } }
                if !opportunity.adminDecisions.isEmpty {
                    Section {
                        TextField("Review note", text: $reason, axis: .vertical).lineLimit(3...6)
                        Text("A reason is required for rejection or pausing. Notes are visible to administrators.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(opportunity.adminDecisions) { action in
                            Button(action.title, role: action == .reject ? .destructive : nil) { selectedDecision = action }
                                .disabled(service.isSaving || reason.count > 2000 ||
                                    (action.requiresReason && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
                                    (action == .approve && (opportunity.startsAt == nil || organization == nil)))
                        }
                        if service.isSaving { ProgressView("Saving decision…") }
                        if let error { Text(error).foregroundStyle(.red) }
                    } header: { Text("Decision") } footer: { Text("\(reason.count) / 2,000 characters") }
                }
                Section("Recent decision history") {
                    if history.isEmpty { Text("No recorded admin decisions yet.").foregroundStyle(.secondary) }
                    ForEach(history) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AdminDecision(rawValue: event.action)?.title ?? event.action.capitalized).font(.headline)
                            if let note = event.reason { Text(note) }
                            Text(event.created_at.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Review Opportunity").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() }.disabled(service.isSaving) }
            .interactiveDismissDisabled(service.isSaving)
            .confirmationDialog(selectedDecision?.title ?? "Confirm decision", isPresented: Binding(
                get: { selectedDecision != nil }, set: { if !$0 { selectedDecision = nil } }
            ), titleVisibility: .visible) {
                if let action = selectedDecision {
                    Button(action.title, role: action == .reject ? .destructive : nil) {
                        Task {
                            error = nil
                            do {
                                try await service.decide(action, opportunity: opportunity, reason: reason)
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }
                }
            } message: { Text(selectedDecision?.explanation ?? "") }
        }
    }
}
