import SwiftUI

struct OrganizationProfileView: View {
    @ObservedObject var service: ProviderService
    @State private var editing = false

    var body: some View {
        NavigationStack {
            Form {
                if let organization = service.organization {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "building.2.crop.circle.fill")
                                .font(.system(size: 72)).foregroundStyle(Opportunity313Brand.accent)
                                .accessibilityLabel("Organization logo placeholder")
                            Text(organization.name).font(.title2.bold())
                            Text(OrganizationProfileDraft.typeLabel(organization.organizationType)).foregroundStyle(.secondary)
                            Label(organization.verificationStatus.capitalized, systemImage: "checkmark.shield")
                        }.frame(maxWidth: .infinity).padding(.vertical)
                        Button("Edit Organization Profile") { editing = true }
                    }
                    Section("About") {
                        detail("Description", organization.description)
                        detail("Website", organization.website)
                    }
                    Section("Contact") {
                        detail("Contact name", organization.contactName)
                        detail("Email", organization.contactEmail)
                        detail("Phone", organization.contactPhone)
                    }
                    Section("Location & Service Area") {
                        detail("Service area", organization.serviceArea)
                        detail("Address", organization.address)
                        detail("City", organization.city)
                    }
                    Section("Organization Record") {
                        LabeledContent("Organization ID", value: organization.id.uuidString).textSelection(.enabled)
                        Text("Verification is managed by Opportunity313. All opportunity submissions require admin approval before publication.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if service.isLoading { ProgressView("Refreshing profile…") }
                if let error = service.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                        Button("Try Again") { Task { await service.fetchOrganization() } }
                    }
                }
                Section { NavigationLink("Account & Settings") { AccountView() } }
            }
            .navigationTitle("Organization Profile")
            .task { await service.fetchOrganization() }
            .refreshable { await service.fetchOrganization() }
            .sheet(isPresented: $editing) {
                OrganizationProfileEditor(service: service, organization: service.organization)
            }
        }.opportunity313PageBackground()
    }

    private func detail(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.flatMap { $0.isEmpty ? nil : $0 } ?? "Not provided").textSelection(.enabled)
        }
    }
}

struct OrganizationProfileEditor: View {
    @ObservedObject var service: ProviderService
    let organization: Organization?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var draft: OrganizationProfileDraft
    @State private var error: String?

    init(service: ProviderService, organization: Organization?) {
        self.service = service
        self.organization = organization
        _draft = State(initialValue: OrganizationProfileDraft(organization: organization))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Organization") {
                    Label("Organization logo placeholder", systemImage: "building.2.crop.circle.fill")
                        .foregroundStyle(Opportunity313Brand.accent)
                    TextField("Organization name (required)", text: $draft.name)
                    Picker("Organization type", selection: $draft.organizationType) {
                        ForEach(OrganizationProfileDraft.types, id: \.self) { type in
                            Text(OrganizationProfileDraft.typeLabel(type)).tag(type)
                        }
                    }
                    TextField("Description", text: $draft.description, axis: .vertical).lineLimit(3...8)
                    TextField("Website (https://…)", text: $draft.website)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Organization Contact") {
                    TextField("Contact name", text: $draft.contactName).textContentType(.name)
                    TextField("Contact email", text: $draft.contactEmail)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Contact phone", text: $draft.contactPhone).keyboardType(.phonePad)
                }
                Section("Location & Service Area") {
                    TextField("Service area (e.g. Detroit, East Side)", text: $draft.serviceArea)
                    TextField("Street address", text: $draft.address).textContentType(.streetAddressLine1)
                    TextField("City", text: $draft.city).textContentType(.addressCity)
                }
                Section {
                    Text("Use organization contact information. Verified organization profiles can be visible to families. Your verification status is controlled by Opportunity313; opportunities always require admin review.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let message = draft.validationMessage { Text(message).font(.footnote).foregroundStyle(.secondary) }
                    if let error { Text(error).foregroundStyle(.red) }
                    if service.isSaving { ProgressView("Saving organization…") }
                }
                if organization == nil {
                    Section { Button("Use a different account") { Task { await authService.signOut() } } }
                }
            }
            .disabled(service.isSaving)
            .navigationTitle(organization == nil ? "Set Up Organization" : "Edit Organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if organization != nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(service.isSaving) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(organization == nil ? "Create" : "Save") {
                        Task {
                            error = nil
                            do {
                                try await service.saveProfile(draft, organizationID: organization?.id)
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                        }
                    }.disabled(service.isSaving || draft.validationMessage != nil)
                }
            }
            .interactiveDismissDisabled(service.isSaving)
        }.opportunity313PageBackground()
    }
}
