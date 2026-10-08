import Foundation
import Testing
@testable import Opportunity313

struct OpportunityTicketTests {
    @Test func ticketDecodesSharedAttendeeAndScheduleFields() throws {
        let ticket = try decode(status: "upcoming", start: 1000, end: 2000)
        #expect(ticket.attendeeName == "Child")
        #expect(ticket.youthProfileID != nil)
        #expect(ticket.attendeeUserID == nil)
        #expect(ticket.displayStatus(at: Date(timeIntervalSince1970: 1999)) == .upcoming)
        #expect(ticket.displayStatus(at: Date(timeIntervalSince1970: 2000)) == .expired)
    }

    @Test func usedAndCancelledTicketsKeepTerminalStatus() throws {
        for status in [TicketStatus.used, .cancelled] {
            let ticket = try decode(status: status.rawValue, start: 1000, end: 2000)
            #expect(ticket.displayStatus(at: Date(timeIntervalSince1970: 3000)) == status)
        }
    }

    @Test func missingEndAllowsEntryOnEventDayAndOngoingTicketsHaveNoInventedDate() throws {
        let scheduled = try decode(status: "upcoming", start: 1000, end: nil)
        #expect(scheduled.displayStatus(at: Date(timeIntervalSince1970: 1001)) == .upcoming)
        #expect(scheduled.displayStatus(at: Date(timeIntervalSince1970: 87400)) == .expired)
        let ongoing = try decode(status: "upcoming", start: nil, end: nil)
        #expect(ongoing.displayStatus(at: Date()) == .upcoming)
        #expect(ongoing.dateText.contains("Ongoing"))
    }

    @Test func registrationGroupsDistinguishAttendanceFromAnEndedProgram() throws {
        let future = Date(timeIntervalSince1970: 1500)
        let ended = Date(timeIntervalSince1970: 2500)
        let registered = try decode(status: "upcoming", start: 1000, end: 2000)
        #expect(registered.registrationPhase(at: future) == .upcoming)
        #expect(registered.registrationPhase(at: ended) == .completed)
        #expect(registered.registrationStatusText(at: ended).contains("attendance not recorded"))
        let attended = try decode(status: "used", start: 1000, end: 2000)
        #expect(attended.registrationPhase(at: future) == .completed)
        #expect(attended.registrationStatusText(at: future) == "Attended")
        let cancelled = try decode(status: "cancelled", start: 1000, end: 2000)
        #expect(cancelled.registrationPhase(at: future) == .cancelled)
    }

    @Test func cancellationPermissionComesFromServerAndDefaultsToUnavailable() throws {
        let legacy = try decode(status: "upcoming", start: 1000, end: 2000)
        #expect(legacy.canCancel == nil)
        let child = try decode(status: "upcoming", start: 1000, end: 2000, canCancel: false)
        #expect(child.canCancel == false)
        let parent = try decode(status: "upcoming", start: 1000, end: 2000, canCancel: true)
        #expect(parent.canCancel == true)
    }

    private func decode(status: String, start: Double?, end: Double?, canCancel: Bool? = nil) throws -> OpportunityTicket {
        var object: [String: Any] = [
            "id": UUID().uuidString, "opportunity_id": UUID().uuidString,
            "youth_profile_id": UUID().uuidString, "attendee_name": "Child",
            "opportunity_name": "Program", "timezone": "America/Detroit",
            "location": "Venue", "address": "Detroit", "status": status,
            "entry_code": String(repeating: "a1", count: 32), "is_demo": true
        ]
        object["can_cancel"] = canCancel
        object["starts_at"] = start
        object["ends_at"] = end
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(OpportunityTicket.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
