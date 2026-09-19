import Foundation
import Combine
import Supabase
import Security

@MainActor
final class TicketService: ObservableObject {
    @Published private(set) var events: [TicketEvent] = []
    @Published private(set) var tickets: [EventTicket] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published private(set) var hold: TicketHold?
    private let client = SupabaseManager.shared.client
    private var loadVersion = 0

    func loadEvents(managedOnly: Bool = false) async {
        struct Params: Encodable { let managed_only: Bool }
        let user = client.auth.currentUser?.id
        guard user != nil else { events = []; return }
        loadVersion += 1
        let version = loadVersion
        isLoading = true; errorMessage = nil
        defer { if version == loadVersion { isLoading = false } }
        do {
            let result: [TicketEvent] = try await client.rpc("native_ticket_events", params: Params(managed_only: managedOnly)).execute().value
            guard user == client.auth.currentUser?.id, version == loadVersion else { return }
            events = result
        } catch {
            guard !Task.isCancelled, user == client.auth.currentUser?.id, version == loadVersion else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadTickets(eventID: UUID? = nil) async {
        struct Params: Encodable { let event_id_input: UUID? }
        let user = client.auth.currentUser?.id
        guard user != nil else { tickets = []; return }
        loadVersion += 1
        let version = loadVersion
        isLoading = true; errorMessage = nil
        defer { if version == loadVersion { isLoading = false } }
        do {
            let result: [EventTicket] = try await client.rpc("native_ticket_wallet", params: Params(event_id_input: eventID)).execute().value
            guard user == client.auth.currentUser?.id, version == loadVersion else { return }
            tickets = result
        } catch {
            guard !Task.isCancelled, user == client.auth.currentUser?.id, version == loadVersion else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func holdKey(user: UUID, allocation: UUID, quantity: Int, youthProfileID: UUID?) -> String {
        "opportunity313.ticketHold.\(user).\(allocation).\(quantity).\(youthProfileID?.uuidString ?? "guest")"
    }

    func startHold(allocationID: UUID, quantity: Int, youthProfileID: UUID?) async {
        guard !isWorking, let user = client.auth.currentUser?.id else { return }
        struct Params: Encodable { let requested_allocation_id: UUID; let requested_quantity: Int; let requested_idempotency_key: String; let youth_profile_id_input: UUID? }
        let key = holdKey(user: user, allocation: allocationID, quantity: quantity, youthProfileID: youthProfileID)
        let requestID = UserDefaults.standard.string(forKey: key) ?? UUID().uuidString
        UserDefaults.standard.set(requestID, forKey: key)
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            let result: TicketHold = try await client.rpc("native_create_ticket_hold", params: Params(requested_allocation_id: allocationID, requested_quantity: quantity, requested_idempotency_key: "checkout:" + user.uuidString + ":" + requestID, youth_profile_id_input: youthProfileID)).execute().value
            guard user == client.auth.currentUser?.id else { return }
            if result.isActive { hold = result }
            else {
                hold = nil
                UserDefaults.standard.removeObject(forKey: key)
                errorMessage = "That hold expired. Start a new five-minute checkout."
            }
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
        }
    }

    func confirmHold() async -> Bool {
        guard !isWorking, let user = client.auth.currentUser?.id, let currentHold = hold else { return false }
        guard currentHold.isActive else { errorMessage = "The five-minute hold expired. Start a new checkout."; hold = nil; return false }
        struct Params: Encodable { let requested_hold_id: UUID }
        struct Issued: Decodable { let ticket_id: UUID; let token: String }
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            let issued: [Issued] = try await client.rpc("issue_ticket", params: Params(requested_hold_id: currentHold.id)).execute().value
            guard user == client.auth.currentUser?.id else { return false }
            var stored = true
            for ticket in issued where !TicketTokenStore.save(ticket.token, userID: user, ticketID: ticket.ticket_id) { stored = false }
            UserDefaults.standard.removeObject(forKey: holdKey(user: user, allocation: currentHold.allocationID, quantity: currentHold.quantity, youthProfileID: currentHold.assignedYouthProfileID))
            hold = nil
            notice = issued.isEmpty ? "Already confirmed. Your tickets are in My Tickets." : "\(issued.count) ticket\(issued.count == 1 ? "" : "s") confirmed."
            if !stored { notice = "Confirmed. Open My Tickets to generate an entry code on this device." }
            return true
        } catch {
            guard user == client.auth.currentUser?.id else { return false }
            errorMessage = error.localizedDescription
            if let failure = error as? PostgrestError, failure.message.contains("not active") {
                UserDefaults.standard.removeObject(forKey: holdKey(user: user, allocation: currentHold.allocationID, quantity: currentHold.quantity, youthProfileID: currentHold.assignedYouthProfileID))
                hold = nil
            }
            return false
        }
    }

    func releaseHold() async {
        guard !isWorking, let user = client.auth.currentUser?.id, let currentHold = hold else { return }
        struct Params: Encodable { let hold_id_input: UUID }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_release_ticket_hold", params: Params(hold_id_input: currentHold.id)).execute()
            guard user == client.auth.currentUser?.id else { return }
            UserDefaults.standard.removeObject(forKey: holdKey(user: user, allocation: currentHold.allocationID, quantity: currentHold.quantity, youthProfileID: currentHold.assignedYouthProfileID))
            hold = nil
            notice = "Those spots are available again."
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
        }
    }

    func cachedCode(ticketID: UUID) -> String? {
        guard let user = client.auth.currentUser?.id else { return nil }
        return TicketTokenStore.read(userID: user, ticketID: ticketID)
    }

    func replaceCode(ticketID: UUID) async -> String? {
        guard !isWorking, let user = client.auth.currentUser?.id else { return nil }
        struct Params: Encodable { let ticket_id_input: UUID }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let token: String = try await client.rpc("native_replace_ticket_code", params: Params(ticket_id_input: ticketID)).execute().value
            guard user == client.auth.currentUser?.id else { return nil }
            if !TicketTokenStore.save(token, userID: user, ticketID: ticketID) {
                errorMessage = "Your code is ready, but could not be stored on this device. Keep this screen open for check-in."
            }
            return token
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return nil
        }
    }

    func cancel(ticketID: UUID) async {
        guard !isWorking, let user = client.auth.currentUser?.id else { return }
        struct Params: Encodable { let ticket_id_input: UUID }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_cancel_ticket", params: Params(ticket_id_input: ticketID)).execute()
            guard user == client.auth.currentUser?.id else { return }
            TicketTokenStore.remove(userID: user, ticketID: ticketID)
            await loadTickets()
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
        }
    }

    func checkIn(code: String, eventID: UUID) async -> String? {
        guard !isWorking, let user = client.auth.currentUser?.id else { return nil }
        guard let token = TicketCode.token(from: code) else { errorMessage = "Scan a ticket QR code or paste its full entry code."; return nil }
        struct Params: Encodable { let presented_token: String; let requested_event_id: UUID; let id_checked_input: Bool }
        struct Scan: Decodable { let result: String }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let results: [Scan] = try await client.rpc("native_staff_check_in", params: Params(presented_token: token, requested_event_id: eventID, id_checked_input: false)).execute().value
            guard user == client.auth.currentUser?.id else { return nil }
            return results.first?.result
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return nil
        }
    }
}

// Entry tokens stay in this device's Keychain, scoped to the signed-in owner.
// Supabase retains only hashes. A lost code can be explicitly replaced by its owner.
enum TicketTokenStore {
    private static func query(userID: UUID, ticketID: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "Opportunity313.EventTickets",
         kSecAttrAccount as String: "\(userID).\(ticketID)"]
    }
    static func save(_ token: String, userID: UUID, ticketID: UUID) -> Bool {
        let base = query(userID: userID, ticketID: ticketID)
        let data = Data(token.utf8)
        let result = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if result == errSecSuccess { return true }
        guard result == errSecItemNotFound else { return false }
        var insert = base
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }
    static func read(userID: UUID, ticketID: UUID) -> String? {
        var request = query(userID: userID, ticketID: ticketID)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func remove(userID: UUID, ticketID: UUID) { SecItemDelete(query(userID: userID, ticketID: ticketID) as CFDictionary) }
}
