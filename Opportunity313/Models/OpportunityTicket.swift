import Foundation

enum TicketStatus: String, Codable {
    case upcoming, used, cancelled, expired
    var title: String { rawValue.capitalized }
}

struct OpportunityTicket: Decodable, Identifiable {
    let id: UUID
    let opportunityID: UUID
    let attendeeUserID: UUID?
    let youthProfileID: UUID?
    let attendeeName: String
    let opportunityName: String
    let startsAt: Date?
    let endsAt: Date?
    let timezone: String
    let location: String
    let address: String
    let status: TicketStatus
    let entryCode: String
    let isDemo: Bool
    var canCancel: Bool? = nil
    var attendedAt: Date? = nil
    var cancelledAt: Date? = nil

    func displayStatus(at date: Date) -> TicketStatus {
        if status == .upcoming, let end = endsAt ?? startsAt?.addingTimeInterval(86_400), end <= date { return .expired }
        return status
    }
    var dateText: String { startsAt.map { TicketDate.text($0, timezone: timezone) } ?? "Ongoing — confirm the schedule with the provider" }
    enum CodingKeys: String, CodingKey {
        case canCancel = "can_cancel", attendedAt = "attended_at", cancelledAt = "cancelled_at"
        case id, timezone, location, address, status
        case opportunityID = "opportunity_id", attendeeUserID = "attendee_user_id", youthProfileID = "youth_profile_id"
        case attendeeName = "attendee_name", opportunityName = "opportunity_name"
        case startsAt = "starts_at", endsAt = "ends_at", entryCode = "entry_code", isDemo = "is_demo"
    }
}

extension Opportunity {
    var offersInAppTickets: Bool { registrationMethod == "in_app" && isFree && costCents == 0 }
}

enum RegistrationPhase: String, CaseIterable, Identifiable {
    case upcoming = "Upcoming", completed = "Completed", cancelled = "Cancelled"
    var id: Self { self }
}

extension OpportunityTicket {
    func registrationPhase(at date: Date) -> RegistrationPhase {
        switch displayStatus(at: date) {
        case .upcoming: return .upcoming
        case .cancelled: return .cancelled
        case .used, .expired: return .completed
        }
    }
    func registrationStatusText(at date: Date) -> String {
        switch displayStatus(at: date) {
        case .upcoming: return "Registered"
        case .used: return "Attended"
        case .cancelled: return "Cancelled"
        case .expired: return "Completed — attendance not recorded"
        }
    }
    var attendeeKey: String { youthProfileID?.uuidString ?? attendeeUserID?.uuidString ?? id.uuidString }
}

extension EventTicket {
    func registrationPhase(at date: Date) -> RegistrationPhase {
        if status == "void" || eventStatus == "cancelled" { return .cancelled }
        if status == "scanned" || eventStatus == "completed" || startsAt.addingTimeInterval(86_400) <= date { return .completed }
        return .upcoming
    }
}
