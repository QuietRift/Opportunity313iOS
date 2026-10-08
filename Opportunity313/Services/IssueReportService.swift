import Foundation
import Combine
import Supabase

@MainActor
final class IssueReportService: ObservableObject {
    @Published private(set) var reports: [IssueReport] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    private let client = SupabaseManager.shared.client
    private var loadVersion = 0

    func load(isAdmin: Bool = false, status: IssueStatus? = nil) async {
        loadVersion += 1
        let version = loadVersion
        guard let user = client.auth.currentUser?.id else { reports = []; return }
        isLoading = true; errorMessage = nil
        defer { if loadVersion == version { isLoading = false } }
        do {
            var query = client.from("issue_reports").select()
            if !isAdmin { query = query.eq("reporter_id", value: user.uuidString) }
            if let status { query = query.eq("status", value: status.rawValue) }
            let result: [IssueReport] = try await query.order("created_at", ascending: false).limit(200).execute().value
            guard client.auth.currentUser?.id == user, version == loadVersion else { return }
            reports = result
        } catch {
            guard client.auth.currentUser?.id == user, version == loadVersion, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    func submit(id: UUID, category: IssueCategory, title: String, details: String, opportunityID: UUID?) async -> IssueReport? {
        guard !isWorking, let user = client.auth.currentUser?.id else { return nil }
        if let error = IssueReportValidation.message(title: title, details: details) { errorMessage = error; return nil }
        struct Params: Encodable {
            let request_id_input: UUID; let category_input: String; let title_input: String; let details_input: String
            let platform_input = "ios"; let opportunity_id_input: UUID?; let app_version_input: String
        }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        do {
            let report: IssueReport = try await client.rpc("native_submit_issue_report", params: Params(request_id_input: id, category_input: category.rawValue, title_input: title, details_input: details, opportunity_id_input: opportunityID, app_version_input: "\(version) (\(build))")).execute().value
            guard client.auth.currentUser?.id == user else { return nil }
            return report
        } catch { if client.auth.currentUser?.id == user { errorMessage = error.localizedDescription }; return nil }
    }

    func fetch(id: UUID) async -> IssueReport? {
        guard let user = client.auth.currentUser?.id else { return nil }
        errorMessage = nil
        do {
            let report: IssueReport = try await client.from("issue_reports").select().eq("id", value: id.uuidString).single().execute().value
            guard client.auth.currentUser?.id == user else { return nil }
            return report
        } catch { if client.auth.currentUser?.id == user { errorMessage = error.localizedDescription }; return nil }
    }

    func review(report: IssueReport, status: IssueStatus, response: String) async -> IssueReport? {
        guard !isWorking, let user = client.auth.currentUser?.id else { return nil }
        struct Params: Encodable { let report_id_input: UUID; let status_input: String; let response_input: String; let expected_version_input: Int }
        isWorking = true; errorMessage = nil
        defer { isWorking = false }
        do {
            let result: IssueReport = try await client.rpc("native_review_issue_report", params: Params(report_id_input: report.id, status_input: status.rawValue, response_input: response, expected_version_input: report.version)).execute().value
            guard client.auth.currentUser?.id == user else { return nil }
            return result
        } catch { if client.auth.currentUser?.id == user { errorMessage = error.localizedDescription }; return nil }
    }
}
