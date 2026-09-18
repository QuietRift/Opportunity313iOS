//
//  Opportunity.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import Foundation

struct Opportunity: Codable, Identifiable, Hashable {

    let id: UUID
    let organizationId: UUID

    let title: String
    let summary: String
    let category: String
    let opportunityType: String

    let ageMin: Int?
    let ageMax: Int?
    let gradeMin: Int?
    let gradeMax: Int?

    let startsAt: Date
    let endsAt: Date?
    let scheduleNote: String?
    let deadline: Date?
    let timezone: String

    let costCents: Int
    let isFree: Bool

    let locationName: String
    let street: String?
    let city: String
    let state: String
    let postalCode: String?
    let neighborhood: String?

    let transportation: String?
    let mealsProvided: Bool
    let accessibility: String?
    let parentRequirements: String?

    let registrationMethod: String
    let registrationUrl: String?
    let capacity: Int?

    let status: String
    let verificationStatus: String

    let publishedAt: Date?
    let isDemo: Bool

    enum CodingKeys: String, CodingKey {
        case id

        case organizationId = "organization_id"

        case title
        case summary
        case category
        case opportunityType = "opportunity_type"

        case ageMin = "age_min"
        case ageMax = "age_max"
        case gradeMin = "grade_min"
        case gradeMax = "grade_max"

        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case scheduleNote = "schedule_note"
        case deadline
        case timezone

        case costCents = "cost_cents"
        case isFree = "is_free"

        case locationName = "location_name"
        case street
        case city
        case state
        case postalCode = "postal_code"
        case neighborhood

        case transportation
        case mealsProvided = "meals_provided"
        case accessibility
        case parentRequirements = "parent_requirements"

        case registrationMethod = "registration_method"
        case registrationUrl = "registration_url"
        case capacity

        case status
        case verificationStatus = "verification_status"

        case publishedAt = "published_at"
        case isDemo = "is_demo"
    }
}


extension Opportunity {
    func matchesRecommendation(for profile: YouthProfile?) -> Bool {
        guard let profile, profile.interests.contains(where: {
            $0.localizedCaseInsensitiveCompare(category) == .orderedSame
        }) else { return false }
        guard let grade = profile.grade else { return true }
        return (gradeMin == nil || grade >= gradeMin!) &&
            (gradeMax == nil || grade <= gradeMax!)
    }
}
