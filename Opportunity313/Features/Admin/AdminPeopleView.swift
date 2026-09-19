import SwiftUI

struct AdminPeopleView: View {
    @ObservedObject var service: AdminService
    @State private var search = ""
    @State private var showYouth = true
    private var youth: [YouthProfile] {
        service.youth.filter { search.isEmpty || $0.firstName.localizedCaseInsensitiveContains(search) || $0.id.uuidString.localizedCaseInsensitiveContains(search) }
    }
    private var users: [AdminUserProfile] {
        service.users.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.id.uuidString.localizedCaseInsensitiveContains(search) || service.roleNames(for: $0.id).localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Profiles", selection: $showYouth) {
                    Text("Youth").tag(true)
                    Text("Users").tag(false)
                }.pickerStyle(.segmented).padding()
                if let error = service.peopleError {
                    AdminLoadError(message: error) { Task { await service.loadPeople() } }.padding(.horizontal)
                }
                List {
                    Section {
                        Text("Read-only oversight of existing profiles and account roles.").font(.caption).foregroundStyle(.secondary)
                    }
                    if showYouth {
                        ForEach(youth) { profile in
                            NavigationLink {
                                AdminYouthProfileView(profile: profile)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(profile.firstName).font(.headline)
                                    Text("\(profile.ageBand) • \(profile.accountType == "parent_managed" ? "Parent managed" : "Youth account")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        ForEach(users) { user in
                            NavigationLink {
                                Form {
                                    Section("Account") {
                                        LabeledContent("Name", value: user.name)
                                        LabeledContent("Roles", value: service.roleNames(for: user.id))
                                        if let neighborhood = user.neighborhood { LabeledContent("Neighborhood", value: neighborhood) }
                                        LabeledContent("Joined", value: user.created_at.formatted(date: .abbreviated, time: .omitted))
                                        Text(user.id.uuidString).font(.caption).textSelection(.enabled)
                                    }
                                    Section("Linked youth profile") {
                                        let linked = service.youth.filter { $0.userId == user.id }
                                        if linked.isEmpty { Text("No directly linked youth profile.").foregroundStyle(.secondary) }
                                        ForEach(linked) { profile in
                                            NavigationLink(profile.firstName) { AdminYouthProfileView(profile: profile) }
                                        }
                                    }
                                }.navigationTitle(user.name)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(user.name).font(.headline)
                                    Text(service.roleNames(for: user.id)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if (showYouth ? youth.isEmpty : users.isEmpty) && !service.isLoadingPeople {
                        ContentUnavailableView("No profiles found", systemImage: "person.crop.circle.badge.questionmark",
                            description: Text(search.isEmpty ? "Refresh to load profiles." : "Try another name or account ID."))
                    }
                }.scrollContentBackground(.hidden)
            }
            .overlay { if service.isLoadingPeople { ProgressView("Loading profiles…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
            .opportunity313PageBackground()
            .navigationTitle("People")
            .searchable(text: $search, prompt: showYouth ? "Youth name or profile ID" : "Name, role, or account ID")
            .task { await service.loadPeople() }
            .refreshable { await service.loadPeople() }
            .toolbar { Button("Refresh", systemImage: "arrow.clockwise") { Task { await service.loadPeople() } }.disabled(service.isLoadingPeople) }
        }
    }
}

struct AdminYouthProfileView: View {
    let profile: YouthProfile
    var body: some View {
        Form {
            Section("Youth profile") {
                LabeledContent("First name", value: profile.firstName)
                LabeledContent("Age group", value: profile.ageBand)
                LabeledContent("Grade", value: profile.grade.map { $0 == 0 ? "Kindergarten" : String($0) } ?? "Not provided")
                LabeledContent("Account type", value: profile.accountType == "parent_managed" ? "Parent managed" : "Youth account")
            }
            Section("Interests") { Text(profile.interests.isEmpty ? "None provided" : profile.interests.joined(separator: ", ")) }
            Section("Accessibility preferences") { Text(profile.accessibilityPreferences.isEmpty ? "None provided" : profile.accessibilityPreferences.joined(separator: ", ")) }
            Section("Record identifiers") {
                Text(profile.id.uuidString).font(.caption).textSelection(.enabled)
                if let id = profile.userId { LabeledContent("Linked account", value: id.uuidString).font(.caption) }
            }
        }.navigationTitle(profile.firstName)
    }
}
