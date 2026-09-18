//
//  Organization.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation

struct Organization: Codable, Identifiable {

    let id: UUID
    let name: String
    let organizationType: String
    let description: String?

    let contactName: String?
    let contactEmail: String?
    let contactPhone: String?
    let website: String?

    let verificationStatus: String
    let verifiedAt: Date?

    let isDemo: Bool

    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {

        case id
        case name

        case organizationType =
            "organization_type"

        case description

        case contactName =
            "contact_name"

        case contactEmail =
            "contact_email"

        case contactPhone =
            "contact_phone"

        case website

        case verificationStatus =
            "verification_status"

        case verifiedAt =
            "verified_at"

        case isDemo =
            "is_demo"

        case createdAt =
            "created_at"

        case updatedAt =
            "updated_at"
    }
}
