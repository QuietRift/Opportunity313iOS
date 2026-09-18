//
//  YouthProfile.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import Foundation


// MARK: - Youth Profile

struct YouthProfile: Codable, Identifiable {

    let id: UUID
    let userId: UUID?
    let firstName: String
    let ageBand: String
    let grade: Int?
    let interests: [String]
    let accessibilityPreferences: [String]
    let accountType: String

    enum CodingKeys: String, CodingKey {

        case id
        case userId = "user_id"
        case firstName = "first_name"
        case ageBand = "age_band"
        case grade
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
    let interests: [String]
    let accessibilityPreferences: [String]
    let accountType: String

    enum CodingKeys: String, CodingKey {

        case userId = "user_id"
        case firstName = "first_name"
        case ageBand = "age_band"
        case grade
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
    let interests: [String]
    let accessibilityPreferences: [String]

    enum CodingKeys: String, CodingKey {

        case firstName = "first_name"
        case ageBand = "age_band"
        case grade
        case interests

        case accessibilityPreferences =
            "accessibility_preferences"
    }
}
