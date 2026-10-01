import Foundation

struct TicketEvent: Decodable, Identifiable {
    let id: UUID
    let title: String
    let sport: String?
    let startsAt: Date
    let timezone: String
    let salesOpenAt: Date
    let salesCloseAt: Date
    let eventStatus: String
    let isDemo: Bool
    let venueName: String
    let schoolName: String?
    let schoolID: UUID?
    let venueID: UUID
    let venuePhysicalCapacity: Int
    let operationalCapacity: Int
    let canManageCapacity: Bool
    let address: String
    let canManage: Bool
    let allocations: [TicketAllocation]
    enum CodingKeys: String, CodingKey {
        case id, title, sport, timezone, address, allocations
        case startsAt = "starts_at", salesOpenAt = "sales_open_at", salesCloseAt = "sales_close_at"
        case eventStatus = "event_status", isDemo = "is_demo", venueName = "venue_name", canManage = "can_manage"
        case schoolName = "school_name", schoolID = "school_id", venueID = "venue_id"
        case venuePhysicalCapacity = "venue_physical_capacity", operationalCapacity = "operational_capacity"
        case canManageCapacity = "can_manage_capacity"
    }
    func reservationsOpen(at date: Date) -> Bool {
        eventStatus == "on_sale" && date >= salesOpenAt && date < salesCloseAt && date < startsAt
    }
    var dateText: String { TicketDate.text(startsAt, timezone: timezone) }
}

struct TicketAllocation: Decodable, Identifiable {
    let id: UUID
    let name: String
    let limitPerUser: Int
    let capacity: Int
    let eligibilityKind: String
    var requiresSchoolVerification: Bool { eligibilityKind == "student" }
    let remaining: Int
    let myRemaining: Int
    var maximumQuantity: Int { max(0, min(20, remaining, myRemaining)) }
    enum CodingKeys: String, CodingKey {
        case id, name, capacity, remaining
        case eligibilityKind = "eligibility_kind"
        case limitPerUser = "limit_per_user", myRemaining = "my_remaining"
    }
}

struct EventTicket: Decodable, Identifiable {
    let id: UUID
    let eventID: UUID
    let eventTitle: String
    let allocationName: String
    let assignedYouthName: String?
    let startsAt: Date
    let timezone: String
    let venueName: String
    let address: String
    let status: String
    let eventStatus: String
    let isDemo: Bool
    let issuedAt: Date
    var canShowCode: Bool { status == "issued" && !["cancelled", "completed", "draft"].contains(eventStatus) }
    func canCancel(at date: Date) -> Bool { status == "issued" && date < startsAt }
    var statusText: String {
        if eventStatus == "cancelled" { return "Event Cancelled" }
        if status == "void" { return "Cancelled" }
        if status == "scanned" { return "Checked In" }
        if eventStatus == "completed" { return "Event Completed" }
        return "Confirmed"
    }
    var dateText: String { TicketDate.text(startsAt, timezone: timezone) }
    enum CodingKeys: String, CodingKey {
        case id, timezone, address, status
        case eventID = "event_id", eventTitle = "event_title", allocationName = "allocation_name"
        case startsAt = "starts_at", venueName = "venue_name", eventStatus = "event_status", isDemo = "is_demo", issuedAt = "issued_at"
        case assignedYouthName = "assigned_youth_name"
    }
}

enum TicketDate {
    static func text(_ date: Date, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: timezone) ?? TimeZone(identifier: "America/Detroit")
        return formatter.string(from: date) + " (" + (formatter.timeZone.abbreviation(for: date) ?? timezone) + ")"
    }
}

enum TicketCode {
    static let prefix = "opportunity313:ticket:"
    static func token(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.hasPrefix(prefix) ? String(trimmed.dropFirst(prefix.count)) : trimmed
        guard candidate.utf8.count == 64, candidate.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        return candidate
    }
}

struct TicketHold: Decodable, Identifiable {
    let id: UUID
    let allocationID: UUID
    let quantity: Int
    let assignedYouthProfileID: UUID?
    let expiresAt: Date
    let status: String
    var isActive: Bool { status == "active" && expiresAt > Date() }
    enum CodingKeys: String, CodingKey {
        case id, quantity, status
        case allocationID = "allocation_id", expiresAt = "expires_at", assignedYouthProfileID = "assigned_youth_profile_id"
    }
}

struct TicketSchool: Decodable, Identifiable {
    let id: UUID
    let name: String
    let district: String?
}

struct SchoolTicketAdmin: Decodable, Identifiable {
    let id: UUID
    let schoolID: UUID
    let email: String
    let status: String
    enum CodingKeys: String, CodingKey { case id, email, status; case schoolID = "school_id" }
}
