import SwiftUI

struct AccountView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var familySaveService: FamilySaveService
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var children = ParentManagedYouthService()
    @StateObject private var editService = YouthProfileService()
    @State private var showAdd = false
    @State private var showEdit = false
    @State private var editingChild: YouthProfile?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80)).foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(authService.displayName.isEmpty ? displayRole : authService.displayName)
                            .font(.title.bold())
                        Text(authService.email).foregroundStyle(.secondary).textSelection(.enabled)
                        Text(displayRole).font(.subheadline.weight(.medium))
                        Button("Edit Profile") { showEdit = true }.buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))

                    if authService.role == "parent" || authService.role == "youth" {
                        NavigationLink { TicketHubView() } label: { row("Event Tickets", icon: "ticket", subtitle: "Browse events and reserve spots") }
                    }
                    if authService.role == "parent" {
                        youthProfiles
                        NavigationLink {
                            FamilySavedProfileView(children: children)
                        } label: { row("Saved Opportunities", icon: "bookmark", subtitle: "Your family's saved programs") }
                        NavigationLink {
                            MyTicketsView()
                        } label: { row("My Activity", icon: "list.bullet.rectangle", subtitle: "Confirmed event tickets") }
                    }
                    if authService.role == "admin" || authService.role == "athletics" {
                        NavigationLink { TicketEventsView(managedOnly: true) } label: { row("Event Check-In", icon: "qrcode.viewfinder") }
                    }
                    NavigationLink {
                        ProfileMessageView(title: "Notifications", icon: "bell", message: "There are no in-app notifications available yet. Check your calendar for saved opportunity dates and deadlines.")
                    } label: { row("Notifications", icon: "bell") }
                    NavigationLink { ProfileHelpView() } label: { row("Help & Support", icon: "questionmark.circle") }
                    NavigationLink { ProfileSettingsView() } label: { row("Account Settings", icon: "gearshape") }
                    if let error = authService.errorMessage {
                        Text(error).font(.subheadline).foregroundStyle(.red)
                    }
                    Button(role: .destructive) {
                        Task { await authService.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity).padding()
                    }
                    .buttonStyle(.bordered).disabled(authService.isLoading)
                }
                .padding(16).frame(maxWidth: 800).frame(maxWidth: .infinity)
            }
            .navigationTitle("Profile")
            .background(Opportunity313Brand.canvas(for: colorScheme).ignoresSafeArea())
            .task { await reload() }
            .refreshable { await reload() }
            .onReceive(NotificationCenter.default.publisher(for: .managedYouthProfileDidChange)) { _ in
                Task { await reload() }
            }
            .sheet(isPresented: $showAdd) { AddChildView(childService: children) }
            .sheet(isPresented: $showEdit) { EditAccountProfileView() }
            .sheet(item: $editingChild) { child in
                EditYouthProfileView(profile: child, profileService: editService) { name, age, grade, interests, accessibility in
                    try await children.updateChild(child, firstName: name, ageBand: age, grade: grade,
                                                   interests: interests, accessibility: accessibility)
                }
            }
        }
        .opportunity313PageBackground()
    }

    private var youthProfiles: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("My Youth Profiles").font(.title2.bold())
            if children.isLoading && children.children.isEmpty {
                ProgressView("Loading youth profiles…")
            } else if let error = children.errorMessage {
                Text(error).foregroundStyle(.red)
                Button("Try Again") { Task { await reload() } }
            } else if children.children.isEmpty {
                Text("Add a youth profile to find opportunities for your family.").foregroundStyle(.secondary)
            }
            ForEach(children.children) { child in
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink {
                        ParentChildDetailView(child: child, childService: children)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            ParentChildRow(child: child)
                            Label("View Profile", systemImage: "chevron.right").font(.subheadline)
                        }
                    }
                    .buttonStyle(.plain)
                    Button("Edit") { editingChild = child }.buttonStyle(.bordered)
                        .accessibilityLabel("Edit \(child.firstName)'s profile")
                }
                .padding(16)
                .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))
            }
            Button { showAdd = true } label: {
                Label("Add Youth Profile", systemImage: "plus").frame(maxWidth: .infinity).padding(6)
            }.buttonStyle(.borderedProminent)
        }
    }

    private func row(_ title: String, icon: String, subtitle: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 26).foregroundStyle(Opportunity313Brand.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary).padding(16)
        .background(Opportunity313Brand.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))
    }

    private func reload() async {
        if authService.role == "parent" { await children.fetchChildren() }
    }

    private var displayRole: String {
        switch authService.role {
        case "parent": "Parent / Guardian"
        case "provider": "Provider"
        case "athletics": "Athletics"
        case "admin": "Administrator"
        default: "User"
        }
    }
}

private struct EditAccountProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name).textContentType(.name)
                    LabeledContent("Email", value: authService.email)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saving = true
                        Task {
                            defer { saving = false }
                            do { try await authService.updateDisplayName(name); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                    }.disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { name = authService.displayName }
            .interactiveDismissDisabled(saving)
        }
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage("opportunity313.colorway") private var colorway = AppColorway.light.rawValue
    var body: some View {
        Form {
            Section("Account") { LabeledContent("Email", value: authService.email) }
            Section("Appearance") {
                Picker("Colorway", selection: $colorway) {
                    ForEach(AppColorway.allCases) { Text($0.title).tag($0.rawValue) }
                }.pickerStyle(.segmented)
            }
            Section("Youth Privacy") {
                Text("Youth profiles use age groups instead of birth dates. School and transportation details are not collected. Accessibility preferences are optional.")
            }
        }.navigationTitle("Account Settings")
    }
}

struct ProfileMessageView: View {
    let title: String
    let icon: String
    let message: String
    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(message))
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .opportunity313PageBackground()
    }
}

struct ProfileHelpView: View {
    var body: some View {
        List {
            Section("Managing Youth Profiles") {
                Text("Use Add Youth Profile to create a managed profile. Tap a youth's card to review their details, edit interests, or manage their access code.")
            }
            Section("Saving Opportunities") {
                Text("Save a program for a youth from its details. Saved programs appear in your family calendar; saving does not register a participant.")
            }
            Section("Event Tickets") {
                Text("Use Event Tickets to reserve free admission and open My Tickets for your QR code. An unused ticket can be cancelled before the event starts. Demo tickets are clearly labeled and are not valid for real admission.")
            }
            Section("Applications & Program Support") {
                Text("Open the opportunity and use the provider's registration link or contact details for eligibility, transportation, accessibility, and application questions.")
            }
        }.navigationTitle("Help & Support")
    }
}

private struct FamilySavedProfileView: View {
    @ObservedObject var children: ParentManagedYouthService
    @EnvironmentObject private var saves: FamilySaveService
    @StateObject private var opportunities = OpportunityService()

    var body: some View {
        List {
            if opportunities.isLoading || saves.isLoading {
                ProgressView("Loading saved opportunities…")
            } else if let error = opportunities.errorMessage ?? saves.errorMessage {
                Text(error).foregroundStyle(.red)
                Button("Try Again") { Task { await reload() } }
            } else if saves.savedByYouth.values.allSatisfy({ $0.isEmpty }) {
                ContentUnavailableView("No Saved Opportunities", systemImage: "bookmark", description: Text("Save opportunities for a youth to find them here."))
            } else {
                ForEach(children.children) { child in
                    Section(child.firstName) {
                        let matches = opportunities.opportunities.filter { saves.isSaved(opportunityID: $0.id, for: child.id) }
                        ForEach(matches) { opportunity in
                            NavigationLink {
                                OpportunityDetailView(opportunity: opportunity, managedYouthProfileID: child.id)
                            } label: { Text(opportunity.title) }
                        }
                        if matches.isEmpty { Text("No currently available saved opportunities.").foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .navigationTitle("Saved Opportunities")
        .task { await reload() }.refreshable { await reload() }
    }
    private func reload() async {
        await opportunities.fetchOpportunities()
        await saves.loadSaves(for: children.children.map(\.id))
    }
}
