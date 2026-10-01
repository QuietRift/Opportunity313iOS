import Foundation
import Combine
import Supabase

@MainActor
final class AdminService: ObservableObject {
    @Published private(set) var opportunities: [Opportunity] = []
    @Published private(set) var stats: AdminStats?
    @Published private(set) var users: [AdminUserProfile] = []
    @Published private(set) var youth: [YouthProfile] = []
    @Published private(set) var roles: [AdminUserRole] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingPeople = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published var peopleError: String?
    @Published var successMessage: String?
    private let supabase = SupabaseManager.shared.client
    var pendingOpportunities: [Opportunity] { opportunities.filter { $0.status == "pending_review" } }

    // Page through every row; default API limits must not silently truncate queues.
    private func allRows<T: Decodable>(_ table: String, order: String) async throws -> [T] {
        var result: [T] = []
        while true {
            let page: [T] = try await supabase.from(table).select()
                .order(order).range(from: result.count, to: result.count + 499).execute().value
            result += page
            if page.count < 500 { return result }
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // This endpoint explicitly checks the server-side admin role.
            let counts: AdminStats = try await supabase.rpc("admin_dashboard_stats").execute().value
            let rows: [Opportunity] = try await allRows("opportunities", order: "id")
            opportunities = rows.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            stats = counts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPeople() async {
        guard !isLoadingPeople else { return }
        isLoadingPeople = true
        peopleError = nil
        defer { isLoadingPeople = false }
        do {
            let _: AdminStats = try await supabase.rpc("admin_dashboard_stats").execute().value
            let accounts: [AdminUserProfile] = try await allRows("profiles", order: "user_id")
            let participants: [YouthProfile] = try await allRows("youth_profiles", order: "id")
            let userRoles: [AdminUserRole] = try await allRows("user_roles", order: "user_id")
            users = accounts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            youth = participants.sorted { $0.firstName.localizedStandardCompare($1.firstName) == .orderedAscending }
            roles = userRoles
        } catch { peopleError = error.localizedDescription }
    }

    func organization(for opportunity: Opportunity) async throws -> Organization {
        try await supabase.from("organizations").select().eq("id", value: opportunity.organizationId)
            .single().execute().value
    }

    func history(for opportunity: Opportunity) async throws -> [AdminReviewEvent] {
        try await supabase.from("opportunity_admin_reviews").select()
            .eq("opportunity_id", value: opportunity.id).order("created_at", ascending: false)
            .limit(50).execute().value
    }

    func decide(_ action: AdminDecision, opportunity: Opportunity, reason: String) async throws {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        struct Params: Encodable {
            let target_opportunity_id: UUID
            let expected_status: String
            let decision: String
            let review_reason: String
        }
        let updated: Opportunity = try await supabase.rpc("admin_review_opportunity", params: Params(
            target_opportunity_id: opportunity.id, expected_status: opportunity.status,
            decision: action.rawValue, review_reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )).execute().value
        if let index = opportunities.firstIndex(where: { $0.id == updated.id }) { opportunities[index] = updated }
        successMessage = "\(updated.title): \(updated.adminStatus.lowercased())."
        await refresh()
    }

    func roleNames(for userID: UUID) -> String {
        let names = roles.filter { $0.user_id == userID }.map { $0.role.capitalized }.sorted()
        return names.isEmpty ? "No role assigned" : names.joined(separator: ", ")
    }
}
