//
//  OpportunitySave.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import Foundation

struct OpportunitySaveRecord: Decodable {

    let opportunityId: UUID

    enum CodingKeys: String, CodingKey {
        case opportunityId = "opportunity_id"
    }
}


struct CreateOpportunitySave: Encodable {

    let youthProfileId: UUID
    let opportunityId: UUID

    enum CodingKeys: String, CodingKey {
        case youthProfileId = "youth_profile_id"
        case opportunityId = "opportunity_id"
    }
}
