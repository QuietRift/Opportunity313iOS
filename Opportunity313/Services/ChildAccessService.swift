import Foundation
import Combine
import Supabase

@MainActor
final class ChildAccessService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var generatedCode: String?
    @Published var expiresAt: Date?

    private let supabase: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) { supabase = client }

    func generate(for youthProfileID: UUID) async {
        await perform(action: "generate", youthProfileID: youthProfileID)
    }

    func revoke(for youthProfileID: UUID) async {
        await perform(action: "revoke", youthProfileID: youthProfileID)
    }

    func deleteProfile(for youthProfileID: UUID) async -> Bool {
        guard !isLoading else { return false }
        await perform(action: "delete", youthProfileID: youthProfileID)
        return errorMessage == nil && statusMessage != nil
    }

    private func perform(action: String, youthProfileID: UUID) async {
        struct Request: Encodable { let action: String; let youthProfileId: UUID }
        struct Response: Decodable { let code: String?; let expiresAt: String?; let revoked: Bool?; let deleted: Bool? }

        guard !isLoading else { return }
        isLoading = true
        generatedCode = nil
        expiresAt = nil
        errorMessage = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            let response: Response = try await supabase.functions.invoke(
                "child-access",
                options: FunctionInvokeOptions(body: Request(action: action, youthProfileId: youthProfileID))
            )
            let expiration: Date? = response.expiresAt.flatMap { value in
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: value) { return date }
                formatter.formatOptions = [.withInternetDateTime]
                return formatter.date(from: value)
            }
            if action == "generate" {
                guard let code = response.code, code.range(of: #"^O313-[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$"#, options: .regularExpression) != nil,
                      let expiration, expiration > Date() else {
                    errorMessage = "A valid access code was not returned. Try again."
                    return
                }
            }
            generatedCode = response.code
            expiresAt = expiration
            if action == "delete" {
                guard response.deleted == true else {
                    errorMessage = "The profile could not be deleted. Try again."
                    return
                }
                statusMessage = "Child profile permanently deleted."
                NotificationCenter.default.post(name: .managedYouthProfileDidChange, object: nil)
            }
            if action == "revoke" {
                guard response.revoked == true else {
                    errorMessage = "Access could not be revoked. Try again."
                    return
                }
                generatedCode = nil
                expiresAt = nil
                statusMessage = "Child access is off. Their profile, changes, and saved opportunities are kept in your account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
