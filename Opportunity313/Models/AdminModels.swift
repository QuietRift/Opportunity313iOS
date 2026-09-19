import Foundation

enum AdminOpportunityFilter: String, CaseIterable, Identifiable {
    case pending = "Pending", approved = "Approved", rejected = "Rejected", paused = "Paused"
    var id: String { rawValue }
    func includes(_ opportunity: Opportunity) -> Bool {
        switch self {
        case .pending: opportunity.status == "pending_review"
        case .approved: opportunity.status == "published"
        case .rejected: opportunity.verificationStatus == "rejected"
        case .paused: opportunity.status == "paused" && opportunity.verificationStatus != "rejected"
        }
    }
}

enum AdminDecision: String, Identifiable {
    case approve, reject, pause, requeue
    var id: String { rawValue }
    var title: String {
        switch self {
        case .approve: "Approve & Publish"
        case .reject: "Reject Opportunity"
        case .pause: "Pause Publication"
        case .requeue: "Return to Review"
        }
    }
    var explanation: String {
        switch self {
        case .approve: "Verify the provider organization and make this opportunity visible to youth and families."
        case .reject: "Keep this opportunity out of discovery and record why it was rejected."
        case .pause: "Remove this opportunity from discovery. Existing records will be retained."
        case .requeue: "Return this opportunity to the pending queue for a fresh review."
        }
    }
    var requiresReason: Bool { self == .reject || self == .pause }
}

struct AdminStats: Decodable {
    let pending: Int
    let approved: Int
    let rejected: Int
    let paused: Int
    let users: Int
    let youth: Int
    let organizations: Int
    let parentManaged: Int
}

struct AdminUserProfile: Decodable, Identifiable {
    let user_id: UUID
    let display_name: String?
    let neighborhood: String?
    let created_at: Date
    var id: UUID { user_id }
    var name: String { display_name.flatMap { $0.isEmpty ? nil : $0 } ?? "Unnamed account" }
}

struct AdminUserRole: Decodable {
    let user_id: UUID
    let role: String
}

struct AdminReviewEvent: Decodable, Identifiable {
    let id: UUID
    let action: String
    let reason: String?
    let created_at: Date
}

extension Opportunity {
    var adminStatus: String {
        if verificationStatus == "rejected" { return "Rejected" }
        switch status {
        case "pending_review": return "Pending review"
        case "published": return "Approved"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    var adminDecisions: [AdminDecision] {
        if status == "pending_review" { return [.approve, .reject] }
        if status == "published" { return [.pause] }
        if status == "paused" || verificationStatus == "rejected" { return [.requeue] }
        return []
    }
}
