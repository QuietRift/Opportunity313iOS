import Foundation
import Combine
import Supabase

@MainActor
final class EmailPreferencesService: ObservableObject {
    @Published private(set) var enabled: Bool?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?
    private let client: SupabaseClient
    init(client: SupabaseClient = SupabaseManager.shared.client) { self.client = client }

    private struct Preference: Codable {
        let user_id: UUID
        let updates_enabled: Bool
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let session = try await client.auth.session
            let preference: Preference? = try await client.from("email_preferences")
                .select("user_id,updates_enabled").eq("user_id", value: session.user.id)
                .maybeSingle().execute().value
            enabled = preference?.updates_enabled ?? true
        } catch { errorMessage = "Couldn’t load your email preferences. Try again." }
    }

    func save(enabled requested: Bool) async {
        guard !isLoading, enabled != nil else { return }
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer { isLoading = false }
        do {
            let session = try await client.auth.session
            let saved: Preference = try await client.from("email_preferences")
                .upsert(Preference(user_id: session.user.id, updates_enabled: requested))
                .select("user_id,updates_enabled").single().execute().value
            enabled = saved.updates_enabled
            statusMessage = enabled == true ? "Optional email updates are on." : "Optional email updates are off. Security and requested sign-in emails continue."
        } catch { errorMessage = "Couldn’t save your email preferences. Try again." }
    }
}
