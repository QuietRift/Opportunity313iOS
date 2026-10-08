import Foundation
import Testing
@testable import Opportunity313

struct OrganizationTests {
    @Test func legacyOrganizationStillDecodes() throws {
        let data = Data(#"{"id":"00000000-0000-0000-0000-000000000001","name":"Detroit School","organization_type":"school","verification_status":"pending","is_demo":false}"#.utf8)
        let organization = try JSONDecoder().decode(Organization.self, from: data)
        #expect(organization.serviceArea == nil)
        #expect(organization.city == nil)
        let draft = OrganizationProfileDraft(organization: organization)
        #expect(draft.name == "Detroit School")
        #expect(draft.validationMessage == nil)
    }

    @Test func editablePayloadExcludesVerificationAndIdentity() throws {
        var draft = OrganizationProfileDraft()
        draft.name = "  Detroit Learning  "
        draft.serviceArea = " Detroit "
        draft.city = "Detroit"
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(draft.cleaned)) as? [String: Any])
        #expect(object["name"] as? String == "Detroit Learning")
        #expect(object["service_area"] as? String == "Detroit")
        #expect(object["contact_email"] as? String == "") // clearing is sent explicitly
        #expect(object["id"] == nil)
        #expect(object["verification_status"] == nil)
        #expect(object["verified_at"] == nil)
    }

    @Test func profileValidationRejectsUnsafeURLsAndInvalidContacts() {
        var draft = OrganizationProfileDraft()
        #expect(draft.validationMessage != nil)
        draft.name = "Detroit Learning"
        draft.website = "javascript:alert(1)"
        #expect(draft.validationMessage != nil)
        draft.website = "https://example.org"
        draft.contactEmail = "not an email"
        #expect(draft.validationMessage != nil)
        draft.contactEmail = "contact@example.org"
        #expect(draft.validationMessage == nil)
    }
}
