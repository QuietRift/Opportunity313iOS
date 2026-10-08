import Foundation
import Combine
import Supabase

extension Notification.Name {
    static let opportunityTicketsDidChange = Notification.Name("opportunityTicketsDidChange")
}

@MainActor
final class OpportunityTicketService: ObservableObject {
    @Published private(set) var tickets: [OpportunityTicket] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    private let client = SupabaseManager.shared.client
    private var loadVersion = 0

    func load() async {
        loadVersion += 1
        let version = loadVersion
        guard let user = client.auth.currentUser?.id else { tickets = []; return }
        isLoading = true
        errorMessage = nil
        defer { if version == loadVersion { isLoading = false } }
        do {
            let result: [OpportunityTicket] = try await client.rpc("native_my_registrations").execute().value
            guard user == client.auth.currentUser?.id, version == loadVersion else { return }
            tickets = result
        } catch {
            guard !Task.isCancelled, user == client.auth.currentUser?.id, version == loadVersion else { return }
            errorMessage = error.localizedDescription
        }
    }

    func cancel(registrationID: UUID) async -> OpportunityTicket? {
        guard !isWorking, let user = client.auth.currentUser?.id else { return nil }
        struct Params: Encodable { let registration_id_input: UUID }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let ticket: OpportunityTicket = try await client.rpc("native_cancel_opportunity_registration",
                params: Params(registration_id_input: registrationID)).execute().value
            guard user == client.auth.currentUser?.id else { return nil }
            tickets.removeAll { $0.id == ticket.id }
            tickets.insert(ticket, at: 0)
            NotificationCenter.default.post(name: .opportunityTicketsDidChange, object: nil)
            return ticket
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return nil
        }
    }

    func registerFamily(opportunityID: UUID, youthProfileIDs: [UUID], includeSelf: Bool) async -> [OpportunityTicket]? {
        guard !isWorking, let user = client.auth.currentUser?.id else { return nil }
        struct Params: Encodable {
            let opportunity_id_input: UUID
            let youth_profile_ids_input: [UUID]
            let include_self_input: Bool
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let result: [OpportunityTicket] = try await client.rpc("native_register_family", params:
                Params(opportunity_id_input: opportunityID, youth_profile_ids_input: youthProfileIDs, include_self_input: includeSelf)).execute().value
            guard user == client.auth.currentUser?.id else { return nil }
            tickets.removeAll { ticket in result.contains { $0.id == ticket.id } }
            tickets.insert(contentsOf: result, at: 0)
            NotificationCenter.default.post(name: .opportunityTicketsDidChange, object: nil)
            return result
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return nil
        }
    }

    func register(opportunityID: UUID, youthProfileID: UUID?) async -> OpportunityTicket? {
        guard !isWorking, let user = client.auth.currentUser?.id else { return nil }
        struct Params: Encodable {
            let opportunity_id_input: UUID
            let youth_profile_id_input: UUID?
        }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let ticket: OpportunityTicket = try await client.rpc("native_register_opportunity", params:
                Params(opportunity_id_input: opportunityID, youth_profile_id_input: youthProfileID)).execute().value
            guard user == client.auth.currentUser?.id else { return nil }
            tickets.removeAll { $0.id == ticket.id }
            tickets.insert(ticket, at: 0)
            NotificationCenter.default.post(name: .opportunityTicketsDidChange, object: nil)
            return ticket
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return nil
        }
    }
}
