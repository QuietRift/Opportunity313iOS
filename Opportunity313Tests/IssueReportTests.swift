import Foundation
import Testing
@testable import Opportunity313

struct IssueReportTests {
    @Test func validationRejectsBlankShortAndOversizedReports() {
        #expect(IssueReportValidation.message(title: "   ", details: "A useful description") != nil)
        #expect(IssueReportValidation.message(title: "Ticket issue", details: "short") != nil)
        #expect(IssueReportValidation.message(title: String(repeating: "x", count: 121), details: "A useful description") != nil)
        #expect(IssueReportValidation.message(title: "Ticket issue", details: String(repeating: "x", count: 4001)) != nil)
        #expect(IssueReportValidation.message(title: " Ticket issue ", details: "  The ticket will not open.  ") == nil)
    }
    @Test func reportContractPreservesResponseAndOpportunityContext() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000123","category":"registration","title":"Ticket issue","details":"The ticket page will not load.","opportunity_id":"00000000-0000-0000-0000-000000000456","opportunity_name":"Community Workshop","platform":"ios","app_version":"1.0 (1)","status":"in_review","response":"We are checking the issue.","version":2,"created_at":"2026-10-08T04:00:00Z","updated_at":"2026-10-08T04:05:00Z"}
        """
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let report = try decoder.decode(IssueReport.self, from: Data(json.utf8))
        #expect(report.category == .registration)
        #expect(report.status == .inReview)
        #expect(report.response == "We are checking the issue.")
        #expect(report.opportunityName == "Community Workshop")
        #expect(report.version == 2)
        #expect(report.reference == "ISS-00000000")
        #expect(report.updatedAt > report.createdAt)
    }
}
