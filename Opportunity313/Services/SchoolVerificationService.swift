import Foundation
import Combine
import Supabase

@MainActor
final class SchoolVerificationService: ObservableObject {
    @Published private(set) var profiles: [SchoolProfileLink] = []
    @Published private(set) var schools: [TicketSchool] = []
    @Published private(set) var queue: [SchoolVerificationRequest] = []
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var notice: String?
    private let client = SupabaseManager.shared.client

    func loadProfiles() async {
        guard !isWorking, let user = client.auth.currentUser?.id else { return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let result: [SchoolProfileLink] = try await client.rpc("native_my_school_profiles").execute().value
            guard user == client.auth.currentUser?.id else { return }
            profiles = result
        } catch { if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription } }
    }

    func loadSchools() async {
        guard !isWorking, let user = client.auth.currentUser?.id else { return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let result: [TicketSchool] = try await client.rpc("native_school_profile_catalog").execute().value
            guard user == client.auth.currentUser?.id else { return }
            schools = result
        } catch { if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription } }
    }

    func request(youthID: UUID, schoolID: UUID) async -> Bool {
        struct Params: Encodable { let youth_profile_id_input: UUID; let school_id_input: UUID }
        guard !isWorking, let user = client.auth.currentUser?.id else { return false }
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_request_school_verification", params: Params(youth_profile_id_input: youthID, school_id_input: schoolID)).execute()
            guard user == client.auth.currentUser?.id else { return false }
            let updated: [SchoolProfileLink] = try await client.rpc("native_my_school_profiles").execute().value
            profiles = updated
            notice = "School selected. Take one photo of the student's school ID to send a roster-check request."
            return true
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return false
        }
    }

    func submitIDPhotoRequest(youthID: UUID, schoolID: UUID) async -> Bool {
        struct Params: Encodable { let youth_profile_id_input: UUID; let school_id_input: UUID }
        guard !isWorking, let user = client.auth.currentUser?.id else { return false }
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_submit_school_roster_request", params: Params(youth_profile_id_input: youthID, school_id_input: schoolID)).execute()
            guard user == client.auth.currentUser?.id else { return false }
            profiles = try await client.rpc("native_my_school_profiles").execute().value
            notice = "Sent to the school. An admin will check its roster once; future student tickets will use the verified school link."
            return true
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return false
        }
    }


    func loadQueue() async {
        guard !isWorking, let user = client.auth.currentUser?.id else { return }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let result: [SchoolVerificationRequest] = try await client.rpc("native_school_verification_queue").execute().value
            guard user == client.auth.currentUser?.id else { return }
            queue = result
        } catch { if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription } }
    }

    func review(requestID: UUID, approve: Bool, rosterChecked: Bool) async -> Bool {
        struct Params: Encodable { let verification_id_input: UUID; let approve_input: Bool; let roster_checked_input: Bool }
        guard !isWorking, let user = client.auth.currentUser?.id else { return false }
        isWorking = true; errorMessage = nil; notice = nil
        defer { isWorking = false }
        do {
            try await client.rpc("native_review_school_roster", params: Params(verification_id_input: requestID, approve_input: approve, roster_checked_input: rosterChecked)).execute()
            guard user == client.auth.currentUser?.id else { return false }
            let result: [SchoolVerificationRequest] = try await client.rpc("native_school_verification_queue").execute().value
            queue = result
            notice = approve ? "School verified against the roster. Student tickets for this school are now available." : "School verification removed."
            return true
        } catch {
            if user == client.auth.currentUser?.id { errorMessage = error.localizedDescription }
            return false
        }
    }
}
