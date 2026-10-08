import SwiftUI
import Supabase

struct RegistrationUpdate: Decodable, Identifiable {
    let id: UUID
    let opportunity_name: String
    let title: String
    let body: String
    let created_at: Date
    let read_at: Date?
}

struct RegistrationUpdatesView: View {
    @State private var updates: [RegistrationUpdate] = []
    @State private var loading = false
    @State private var error: String?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        List {
            if loading { ProgressView("Loading updates…") }
            if let error { Text(error).foregroundStyle(.red); Button("Try Again") { Task { await load() } } }
            if updates.isEmpty && !loading && error == nil {
                ContentUnavailableView("No Updates Yet", systemImage: "bell", description: Text("Messages from providers about your registered opportunities appear here."))
            }
            ForEach(updates) { update in
                NavigationLink {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(update.opportunity_name).font(.headline)
                            Text(update.title).font(.title2.bold())
                            Text(update.created_at, style: .date).foregroundStyle(.secondary)
                            Text(update.body)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading)
                    }.navigationTitle("Opportunity Update")
                    .task {
                        struct Params: Encodable { let notification_id_input: UUID }
                        _ = try? await SupabaseManager.shared.client.rpc("native_read_registration_update", params: Params(notification_id_input: update.id)).execute()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(update.opportunity_name).font(.caption).foregroundStyle(.secondary)
                        HStack { if update.read_at == nil { Image(systemName: "circle.fill").font(.caption2).foregroundStyle(Color.accentColor) }; Text(update.title).font(.headline) }
                        Text(update.body).lineLimit(2).font(.subheadline)
                        Text(update.created_at, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Opportunity Updates")
        .task { await load() }.refreshable { await load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
        .opportunity313PageBackground()
    }
    private func load() async {
        let client = SupabaseManager.shared.client
        guard let user = client.auth.currentUser?.id else { updates = []; return }
        loading = true; error = nil
        defer { loading = false }
        do {
            let result: [RegistrationUpdate] = try await client.from("registration_notifications").select().order("created_at", ascending: false).limit(200).execute().value
            guard client.auth.currentUser?.id == user else { updates = []; return }
            updates = result
        } catch { updates = []; self.error = error.localizedDescription }
    }
}

struct PublishOpportunityUpdateView: View {
    let opportunity: Opportunity
    @State private var title = ""
    @State private var message = ""
    @State private var requestID = UUID()
    @State private var busy = false
    @State private var error: String?
    @State private var sent: Int?
    @State private var confirm = false
    var body: some View {
        Form {
            Section { Text(opportunity.title).font(.headline) }
            if let sent {
                Section("Update Sent") { Text("Your message was delivered to \(sent) registered attendee and parent accounts.") }
            } else {
                Section("Message to Registered Families") {
                    TextField("Update title", text: $title)
                    TextField("What should attendees know?", text: $message, axis: .vertical).lineLimit(5...12)
                    Text("Share reminders, schedule changes, location details, or other important information. This sends a message; it does not edit the opportunity’s details.").font(.footnote)
                }.disabled(busy)
                Section {
                    if let error { Text(error).foregroundStyle(.red) }
                    Button("Send Update") { confirm = true }.disabled(busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 120 || message.count > 2000)
                    if busy { ProgressView("Sending update…") }
                }
            }
        }.navigationTitle("Send Opportunity Update")
        .onChange(of: title) { _, _ in requestID = UUID() }
        .onChange(of: message) { _, _ in requestID = UUID() }
        .confirmationDialog("Send this update to registered attendees and parents?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Send Update") { Task { await publish() } }
        }.opportunity313PageBackground()
    }
    private func publish() async {
        struct Params: Encodable { let opportunity_id_input: UUID; let title_input: String; let body_input: String; let request_id_input: UUID }
        busy = true; error = nil
        defer { busy = false }
        do {
            sent = try await SupabaseManager.shared.client.rpc("native_publish_opportunity_update", params: Params(opportunity_id_input: opportunity.id, title_input: title, body_input: message, request_id_input: requestID)).execute().value
        } catch { self.error = error.localizedDescription }
    }
}
