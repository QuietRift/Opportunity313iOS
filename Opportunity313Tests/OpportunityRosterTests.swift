import Foundation
import Testing
@testable import Opportunity313

struct OpportunityRosterTests {
    @Test func rosterDecodesAttendanceHistoryAndUnlimitedCapacity() throws {
        let id = UUID()
        let object: [String: Any] = [
            "opportunity_id": id.uuidString,
            "registered_count": 1, "attended_count": 1, "cancelled_count": 0,
            "attendees": [["id": UUID().uuidString, "attendee_name": "Attendee",
                           "status": "used", "registered_at": 1000, "attended_at": 2000]]
        ]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let roster = try decoder.decode(OpportunityRoster.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(roster.opportunityID == id)
        #expect(roster.capacity == nil)
        #expect(roster.remaining == nil)
        #expect(roster.attendedCount == 1)
        #expect(roster.attendees.first?.attendedAt == Date(timeIntervalSince1970: 2000))
        #expect(roster.attendees.first?.cancelledAt == nil)
    }
}
