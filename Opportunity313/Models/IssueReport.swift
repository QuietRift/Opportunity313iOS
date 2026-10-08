import Foundation

enum IssueCategory: String, Codable, CaseIterable, Identifiable {
    case app, account, registration, opportunity, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .app: "App or website problem"
        case .account: "Account or profile"
        case .registration: "Registration or ticket"
        case .opportunity: "Opportunity information"
        case .other: "Something else"
        }
    }
}

enum IssueStatus: String, Codable, CaseIterable, Identifiable {
    case submitted, inReview = "in_review", resolved
    var id: String { rawValue }
    var title: String {
        switch self { case .submitted: "Submitted"; case .inReview: "In Review"; case .resolved: "Resolved" }
    }
}

struct IssueReport: Decodable, Identifiable {
    let id: UUID
    let category: IssueCategory
    let title: String
    let details: String
    let opportunityID: UUID?
    let opportunityName: String?
    let platform: String
    let appVersion: String?
    let status: IssueStatus
    let response: String
    let version: Int
    let createdAt: Date
    let updatedAt: Date
    var reference: String { "ISS-" + id.uuidString.prefix(8) }
    enum CodingKeys: String, CodingKey {
        case id, category, title, details, platform, status, response, version
        case opportunityID = "opportunity_id", opportunityName = "opportunity_name", appVersion = "app_version"
        case createdAt = "created_at", updatedAt = "updated_at"
    }
}

enum IssueReportValidation {
    static func message(title: String, details: String) -> String? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !(3...120).contains(title.count) { return "Enter a title between 3 and 120 characters." }
        if !(10...4000).contains(details.count) { return "Describe the issue using 10 to 4000 characters." }
        return nil
    }
}
