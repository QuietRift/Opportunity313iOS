//
//  YouthProfile.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import Foundation

enum ParticipantGender: String, Codable, CaseIterable, Identifiable {
    case boy
    case girl

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ProgramGenderEligibility: String, Codable, CaseIterable, Identifiable {
    case all
    case boys
    case girls

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All / Co-ed"
        case .boys: "Boys"
        case .girls: "Girls"
        }
    }
}

// MARK: - Youth Profile

struct YouthProfile: Codable, Identifiable {

    let id: UUID
    let userId: UUID?
    let firstName: String
    let ageBand: String
    let grade: Int?
    let gender: ParticipantGender?
    let interests: [String]
    let accessibilityPreferences: [String]
    let accountType: String

    enum CodingKeys: String, CodingKey {

        case id
        case userId = "user_id"
        case firstName = "first_name"
        case ageBand = "age_band"
        case grade
        case gender
        case interests

        case accessibilityPreferences =
            "accessibility_preferences"

        case accountType = "account_type"
    }
}


// MARK: - Create Youth Profile

struct CreateYouthProfile: Encodable {

    let userId: UUID
    let firstName: String
    let ageBand: String
    let grade: Int?
    let gender: ParticipantGender?
    let interests: [String]
    let accessibilityPreferences: [String]
    let accountType: String

    enum CodingKeys: String, CodingKey {

        case userId = "user_id"
        case firstName = "first_name"
        case ageBand = "age_band"
        case grade
        case gender
        case interests

        case accessibilityPreferences =
            "accessibility_preferences"

        case accountType = "account_type"
    }
}


// MARK: - Update Youth Profile

struct UpdateYouthProfile: Encodable {

    let firstName: String
    let ageBand: String
    let grade: Int?
    let gender: ParticipantGender?
    let interests: [String]
    let accessibilityPreferences: [String]

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(firstName, forKey: .firstName)
        try values.encode(ageBand, forKey: .ageBand)
        // Send null when an optional grade is cleared instead of omitting the update.
        try values.encode(grade, forKey: .grade)
        try values.encodeIfPresent(gender, forKey: .gender)
        try values.encode(interests, forKey: .interests)
        try values.encode(accessibilityPreferences, forKey: .accessibilityPreferences)
    }

    enum CodingKeys: String, CodingKey {

        case firstName = "first_name"
        case ageBand = "age_band"
        case grade
        case gender
        case interests

        case accessibilityPreferences =
            "accessibility_preferences"
    }
}
