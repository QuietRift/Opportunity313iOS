import Foundation
import Testing
@testable import Opportunity313

struct AdminTests {
    private func opportunity(status: String, verification: String) throws -> Opportunity {
        let object: [String: Any] = [
            "id": UUID().uuidString, "organization_id": UUID().uuidString,
            "title": "Youth workshop", "summary": "Learn useful skills", "category": "Technology",
            "opportunity_type": "Workshop", "timezone": "America/Detroit", "cost_cents": 0,
            "is_free": true, "location_name": "Community Center", "city": "Detroit", "state": "MI",
            "meals_provided": false, "registration_method": "provider_submission", "status": status,
            "verification_status": verification, "is_demo": true
        ]
        return try JSONDecoder().decode(Opportunity.self, from: JSONSerialization.data(withJSONObject: object))
    }
    @Test func rejectedRecordsRemainSeparateFromApprovedAndPaused() throws {
        let rejected = try opportunity(status: "closed", verification: "rejected")
        #expect(AdminOpportunityFilter.rejected.includes(rejected))
        #expect(!AdminOpportunityFilter.approved.includes(rejected))
        #expect(!AdminOpportunityFilter.pending.includes(rejected))
        #expect(rejected.adminStatus == "Rejected")
        #expect(rejected.adminDecisions == [.requeue])
    }
    @Test func onlyPendingSubmissionsCanBeApprovedOrRejected() throws {
        #expect(try opportunity(status: "pending_review", verification: "pending").adminDecisions == [.approve, .reject])
        #expect(try opportunity(status: "published", verification: "verified").adminDecisions == [.pause])
        #expect(try opportunity(status: "paused", verification: "verified").adminDecisions == [.requeue])
        #expect(try opportunity(status: "closed", verification: "verified").adminDecisions.isEmpty)
    }
    @Test func dashboardDecodesExactServerCounts() throws {
        let data = Data(#"{"pending":1201,"approved":25,"rejected":3,"paused":1,"users":1500,"youth":1600,"organizations":35,"parentManaged":200}"#.utf8)
        let stats = try JSONDecoder().decode(AdminStats.self, from: data)
        #expect(stats.pending == 1201)
        #expect(stats.users == 1500)
        #expect(stats.parentManaged == 200)
    }
}
