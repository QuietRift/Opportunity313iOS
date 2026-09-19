import Foundation

struct SchoolProfileLink: Decodable, Identifiable {
    let youthProfileID: UUID
    let youthName: String
    let grade: Int?
    let verificationID: UUID?
    let schoolID: UUID?
    let schoolName: String?
    let status: String
    let photoSubmitted: Bool
    var id: UUID { youthProfileID }
    var isVerified: Bool { status == "verified" }
    enum CodingKeys: String, CodingKey {
        case status, grade
        case youthProfileID = "youth_profile_id", youthName = "youth_name"
        case verificationID = "verification_id", schoolID = "school_id", schoolName = "school_name"
        case photoSubmitted = "photo_submitted"
    }
}

struct SchoolVerificationRequest: Decodable, Identifiable {
    let id: UUID
    let youthProfileID: UUID
    let youthName: String
    let grade: Int?
    let schoolID: UUID
    let schoolName: String
    let status: String
    let requestedAt: Date
    enum CodingKeys: String, CodingKey {
        case id, grade, status
        case youthProfileID = "youth_profile_id", youthName = "youth_name"
        case schoolID = "school_id", schoolName = "school_name", requestedAt = "requested_at"
    }
}
