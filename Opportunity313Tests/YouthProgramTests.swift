import Foundation
import Testing
@testable import Opportunity313

struct YouthProgramTests {
    private func opportunity(method: String, gradeMin: Int? = nil, gradeMax: Int? = nil) -> Opportunity {
        Opportunity(id: UUID(), organizationId: UUID(), title: "Youth program", summary: "Details",
                    category: "Technology", opportunityType: "resource", ageMin: nil, ageMax: nil,
                    gradeMin: gradeMin, gradeMax: gradeMax, genderEligibility: .all,
                    startsAt: nil, endsAt: nil, scheduleNote: nil, deadline: nil,
                    timezone: "America/Detroit", costCents: 0, isFree: true,
                    locationName: "Detroit", street: nil, city: "Detroit", state: "MI",
                    postalCode: nil, neighborhood: nil, transportation: nil, mealsProvided: false,
                    accessibility: nil, parentRequirements: nil, registrationMethod: method,
                    registrationUrl: "https://gdyt.org/youth", capacity: nil, status: "published",
                    verificationStatus: "verified", publishedAt: nil, isDemo: false)
    }

    @Test func closedResourcesDoNotInviteRegistrationOrAppearOngoing() {
        let resource = opportunity(method: "registration_closed")
        #expect(resource.registrationActionTitle == "View Program")
        #expect(resource.registrationMethodDisplayText == "Registration closed")
        #expect(resource.startDisplayText == "Registration closed")
        #expect(resource.startDateDisplayText == "Registration closed")
    }

    @Test func existingExternalRegistrationRetainsItsBehavior() {
        let resource = opportunity(method: "external_url")
        #expect(resource.registrationActionTitle == "View Registration")
        #expect(resource.registrationMethodDisplayText == nil)
        #expect(resource.startDisplayText == "Ongoing")
    }

    @Test func gradeOnlyProgramUsesSameEligibilityForManagedAndIndependentProfiles() {
        let program = opportunity(method: "external_url", gradeMin: 1, gradeMax: 8)
        for accountType in ["parent_managed", "independent"] {
            for grade in [0, 1, 8, 9] {
                let profile = YouthProfile(id: UUID(), userId: nil, firstName: "Test",
                    ageBand: "11–13", grade: grade, gender: nil, interests: ["Technology"],
                    accessibilityPreferences: [], accountType: accountType)
                #expect(program.matchesEligibility(for: profile) == (1...8).contains(grade))
                #expect(program.matchesRecommendation(for: profile) == (1...8).contains(grade))
            }
        }
    }
}
