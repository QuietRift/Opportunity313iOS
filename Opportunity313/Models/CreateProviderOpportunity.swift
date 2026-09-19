//
//  CreateProviderOpportunity.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation

struct CreateProviderOpportunity: Encodable {

    let organizationId: UUID
    let title: String
    let summary: String
    let category: String
    let opportunityType: String

    let ageMin: Int?
    let ageMax: Int?
    let gradeMin: Int?
    let gradeMax: Int?
    let genderEligibility: ProgramGenderEligibility

    let startsAt: Date
    let endsAt: Date?
    let deadline: Date?

    let costCents: Int
    let isFree: Bool

    let locationName: String
    let neighborhood: String?

    let transportation: String?
    let mealsProvided: Bool
    let accessibility: String?
    let parentRequirements: String?

    let registrationMethod: String
    let registrationUrl: String?

    let capacity: Int?

    let status: String
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {

        case organizationId = "organization_id"
        case title
        case summary
        case category

        case opportunityType =
            "opportunity_type"

        case ageMin = "age_min"
        case ageMax = "age_max"

        case gradeMin = "grade_min"
        case gradeMax = "grade_max"
        case genderEligibility = "gender_eligibility"

        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case deadline

        case costCents = "cost_cents"
        case isFree = "is_free"

        case locationName =
            "location_name"

        case neighborhood
        case transportation

        case mealsProvided =
            "meals_provided"

        case accessibility

        case parentRequirements =
            "parent_requirements"

        case registrationMethod =
            "registration_method"

        case registrationUrl =
            "registration_url"

        case capacity
        case status

        case createdBy =
            "created_by"
    }
}
