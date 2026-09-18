import Foundation
import Testing
@testable import Opportunity313

struct Opportunity313Tests {
    @Test func parentManagedChildDecodesWithoutUserAccount() throws {
        let data = Data(#"{"id":"00000000-0000-0000-0000-000000000001","user_id":null,"first_name":"Demo","age_band":"13-17","grade":8,"interests":["Technology"],"accessibility_preferences":[],"account_type":"parent_managed"}"#.utf8)
        let child = try JSONDecoder().decode(YouthProfile.self, from: data)
        #expect(child.userId == nil)
        #expect(child.grade == 8)
        #expect(child.accountType == "parent_managed")
    }

    @Test func savePayloadUsesBackendColumnNames() throws {
        let youthID = UUID()
        let opportunityID = UUID()
        let payload = CreateOpportunitySave(youthProfileId: youthID, opportunityId: opportunityID)
        let encoded = try JSONEncoder().encode(payload)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: String])
        #expect(object["youth_profile_id"] == youthID.uuidString)
        #expect(object["opportunity_id"] == opportunityID.uuidString)
        #expect(object.count == 2)
    }

    @Test @MainActor func accountSwitchClearsYouthAndFamilySaves() {
        let opportunityID = UUID()
        let childID = UUID()
        let youth = SavedOpportunityService()
        let family = FamilySaveService()
        youth.savedOpportunityIDs = [opportunityID]
        family.savedByYouth = [childID: [opportunityID]]
        youth.errorMessage = "Old account error"
        family.errorMessage = "Old account error"
        youth.reset()
        family.reset()
        #expect(!youth.isSaved(opportunityID))
        #expect(!family.isSaved(opportunityID: opportunityID, for: childID))
        #expect(youth.errorMessage == nil)
        #expect(family.errorMessage == nil)
    }
}
