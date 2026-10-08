import Foundation
import Combine
import Supabase

struct OpportunityAttendee: Decodable, Identifiable {
    let id: UUID
    let attendeeName: String
    let status: TicketStatus
    let registeredAt: Date
    let attendedAt: Date?
    let cancelledAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, status
        case attendeeName = "attendee_name", registeredAt = "registered_at"
        case attendedAt = "attended_at", cancelledAt = "cancelled_at"
    }
    var statusText: String {
        switch status {
        case .used: return "Attended"
        case .upcoming: return "Registered"
        case .cancelled: return "Cancelled"
        case .expired: return "Expired"
        }
    }
}

struct OpportunityRoster: Decodable {
    let opportunityID: UUID
    let capacity: Int?
    let registeredCount: Int
    let remaining: Int?
    let attendedCount: Int
    let cancelledCount: Int
    let attendees: [OpportunityAttendee]
    enum CodingKeys: String, CodingKey {
        case capacity, remaining, attendees
        case opportunityID = "opportunity_id", registeredCount = "registered_count"
        case attendedCount = "attended_count", cancelledCount = "cancelled_count"
    }
}

@MainActor
final class OpportunityAttendeeService: ObservableObject {
    @Published private(set) var roster: OpportunityRoster?
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    private let client = SupabaseManager.shared.client
    private var loadVersion = 0

    func load(opportunityID: UUID) async {
        loadVersion += 1
        let version = loadVersion
        guard let user = client.auth.currentUser?.id else { roster = nil; return }
        struct Params: Encodable { let opportunity_id_input: UUID }
        isLoading = true
        errorMessage = nil
        defer { if version == loadVersion { isLoading = false } }
        do {
            let result: OpportunityRoster = try await client.rpc("native_opportunity_attendees",
                params: Params(opportunity_id_input: opportunityID)).execute().value
            guard user == client.auth.currentUser?.id, version == loadVersion else { return }
            roster = result
        } catch {
            guard !Task.isCancelled, user == client.auth.currentUser?.id, version == loadVersion else { return }
            roster = nil
            errorMessage = error.localizedDescription
        }
    }

    func markAttended(registrationID: UUID, opportunityID: UUID) async {
        guard !isWorking, let user = client.auth.currentUser?.id else { return }
        struct Params: Encodable { let registration_id_input: UUID }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_mark_opportunity_attendance",
                params: Params(registration_id_input: registrationID)).execute()
            guard user == client.auth.currentUser?.id else { return }
            NotificationCenter.default.post(name: .opportunityTicketsDidChange, object: nil)
            await load(opportunityID: opportunityID)
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
        }
    }
}
