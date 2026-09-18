import Foundation
import Combine
import Supabase

@MainActor
final class ChildAccessService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var generatedCode: String?
    @Published var expiresAt: Date?

    private let supabase = SupabaseManager.shared.client

    func generate(for youthProfileID: UUID) async {
        await perform(action: "generate", youthProfileID: youthProfileID)
    }

    func revoke(for youthProfileID: UUID) async {
        await perform(action: "revoke", youthProfileID: youthProfileID)
    }

    private func perform(action: String, youthProfileID: UUID) async {
        struct Request: Encodable { let action: String; let youthProfileId: UUID }
        struct Response: Decodable { let code: String?; let expiresAt: Date?; let revoked: Bool? }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: Response = try await supabase.functions.invoke(
                "child-access",
                options: FunctionInvokeOptions(body: Request(action: action, youthProfileId: youthProfileID))
            )
            generatedCode = response.code
            expiresAt = response.expiresAt
            if action == "revoke" { generatedCode = nil; expiresAt = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
