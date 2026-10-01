import Foundation
import Combine
import Supabase

@MainActor
final class SchoolTicketService: ObservableObject {
    @Published private(set) var schools: [TicketSchool] = []
    @Published private(set) var admins: [SchoolTicketAdmin] = []
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var notice: String?
    private let client = SupabaseManager.shared.client

    func loadStaff() async {
        guard !isWorking else { return }
        let user = client.auth.currentUser?.id
        guard user != nil else { schools = []; admins = []; return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let loadedSchools: [TicketSchool] = try await client.rpc("native_school_catalog").execute().value
            let loadedAdmins: [SchoolTicketAdmin] = try await client.rpc("native_school_ticket_admins").execute().value
            guard user == client.auth.currentUser?.id else { return }
            schools = loadedSchools; admins = loadedAdmins
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
        }
    }

    func assign(schoolID: UUID, email: String) async -> Bool {
        struct Params: Encodable { let school_id_input: UUID; let email_input: String }
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isWorking, !normalized.isEmpty else { return false }
        let user = client.auth.currentUser?.id
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_assign_school_ticket_admin", params: Params(school_id_input: schoolID, email_input: normalized)).execute()
            guard user == client.auth.currentUser?.id else { return false }
            notice = "School ticket admin assigned. They can sign in to manage ticket availability."
            let loaded: [SchoolTicketAdmin] = try await client.rpc("native_school_ticket_admins").execute().value
            admins = loaded
            return true
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return false
        }
    }

    func revoke(membershipID: UUID) async {
        struct Params: Encodable { let membership_id_input: UUID }
        guard !isWorking else { return }
        let user = client.auth.currentUser?.id
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_revoke_school_ticket_admin", params: Params(membership_id_input: membershipID)).execute()
            guard user == client.auth.currentUser?.id else { return }
            admins.removeAll { $0.id == membershipID }
            notice = "School ticket admin access removed."
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
        }
    }

    func saveSeatLimits(eventID: UUID, venue: Int, event: Int, reason: String) async -> Bool {
        struct Params: Encodable { let event_id_input: UUID; let venue_capacity_input: Int; let event_capacity_input: Int; let reason_input: String }
        guard !isWorking else { return false }
        let user = client.auth.currentUser?.id
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_update_seat_limits", params: Params(event_id_input: eventID, venue_capacity_input: venue, event_capacity_input: event, reason_input: reason)).execute()
            guard user == client.auth.currentUser?.id else { return false }
            notice = "Seat limits updated."
            return true
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return false
        }
    }

    func saveAllocation(id: UUID, capacity: Int, reason: String) async -> Bool {
        struct Params: Encodable { let allocation_id_input: UUID; let capacity_input: Int; let reason_input: String }
        guard !isWorking else { return false }
        let user = client.auth.currentUser?.id
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_update_ticket_allocation", params: Params(allocation_id_input: id, capacity_input: capacity, reason_input: reason)).execute()
            guard user == client.auth.currentUser?.id else { return false }
            notice = "Ticket allocation updated."
            return true
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return false
        }
    }

    func setSales(eventID: UUID, open: Bool) async -> Bool {
        struct Params: Encodable { let event_id_input: UUID; let open_input: Bool }
        guard !isWorking else { return false }
        let user = client.auth.currentUser?.id
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_set_ticket_sales", params: Params(event_id_input: eventID, open_input: open)).execute()
            guard user == client.auth.currentUser?.id else { return false }
            notice = open ? "Ticket reservations are open." : "New ticket reservations are paused."
            return true
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return false
        }
    }
}
