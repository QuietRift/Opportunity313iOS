import Foundation
import Supabase
import Testing
@testable import Opportunity313

// All HTTP calls are intercepted; no real signup, email, or backend write occurs.
@Suite(.serialized)
struct SignupAuthTests {
    @Test @MainActor func confirmationRequiredSignupPreservesParentChoiceAndName() async throws {
        let (client, fixture) = makeClient("confirmation")
        let service = AuthService(client: client)
        let outcome = await service.signUp(draft: validDraft)
        #expect(outcome == .confirmationRequired)
        #expect(client.auth.currentSession == nil)
        let request = try #require(SignupFixtureProtocol.recorder.requests(fixture).first { $0.url?.path == "/auth/v1/signup" })
        let body = try #require(SignupFixtureProtocol.body(request) as? [String: Any])
        let metadata = try #require(body["data"] as? [String: String])
        #expect(metadata["signup_account_type"] == "parent")
        #expect(metadata["full_name"] == "Fixture Parent")
        #expect(metadata["display_name"] == "Fixture Parent")
        #expect(!SignupFixtureProtocol.recorder.requests(fixture).contains { $0.url?.path.contains("claim_onboarding_role") == true })
    }

    @Test @MainActor func immediateSessionDoesNotShowFalseConfirmationAndClaimsParentRole() async {
        let (client, fixture) = makeClient("newParent")
        let service = AuthService(client: client)
        #expect(await service.signUp(draft: validDraft) == .signedIn)
        await service.loadUserRole()
        #expect(service.role == "parent")
        #expect(!service.needsOnboarding)
        #expect(service.accountError == nil)
        #expect(SignupFixtureProtocol.recorder.requests(fixture).filter { $0.url?.path.contains("claim_onboarding_role") == true }.count == 1)
    }

    @Test @MainActor func confirmedParentReturnsToCorrectRoleAfterSigningInAgain() async throws {
        let (client, _) = makeClient("newParent")
        try await client.auth.signIn(email: "fixture@example.org", password: "fixture-only-password")
        let service = AuthService(client: client)
        await service.loadUserRole()
        #expect(service.role == "parent")
        #expect(!service.needsOnboarding)
    }

    @Test @MainActor func existingParentCannotBeConvertedBySignupPreference() async throws {
        let (client, fixture) = makeClient("existingParent")
        try await client.auth.signIn(email: "fixture@example.org", password: "fixture-only-password")
        let service = AuthService(client: client)
        await service.loadUserRole()
        #expect(service.role == "parent")
        #expect(!SignupFixtureProtocol.recorder.requests(fixture).contains { $0.url?.path.contains("claim_onboarding_role") == true })
    }

    @Test @MainActor func failedOnboardingCanRetryWithoutAnotherSignup() async {
        let (client, fixture) = makeClient("roleFailure")
        let service = AuthService(client: client)
        #expect(await service.signUp(draft: validDraft) == .signedIn)
        await service.loadUserRole()
        #expect(service.accountError != nil)
        #expect(service.role == nil)
        await service.loadUserRole()
        #expect(service.accountError == nil)
        #expect(service.role == "parent")
        #expect(SignupFixtureProtocol.recorder.requests(fixture).filter { $0.url?.path == "/auth/v1/signup" }.count == 1)
    }

    @Test @MainActor func unconfirmedOrUnsupportedPreferenceKeepsManualOnboarding() async throws {
        for scenario in ["unconfirmed", "unsupported"] {
            let (client, fixture) = makeClient(scenario)
            try await client.auth.signIn(email: "fixture@example.org", password: "fixture-only-password")
            let service = AuthService(client: client)
            await service.loadUserRole()
            #expect(service.role == nil)
            #expect(service.needsOnboarding)
            #expect(!SignupFixtureProtocol.recorder.requests(fixture).contains { $0.url?.path.contains("claim_onboarding_role") == true })
        }
    }

    @Test @MainActor func providerPreferenceUsesExistingOrganizationRole() async throws {
        let (client, _) = makeClient("newProvider")
        try await client.auth.signIn(email: "fixture@example.org", password: "fixture-only-password")
        let service = AuthService(client: client)
        await service.loadUserRole()
        #expect(service.role == "provider")
        #expect(!service.needsOnboarding)
    }

    private var validDraft: SignupDraft {
        SignupDraft(name: " Fixture Parent ", email: "fixture@example.org", password: "fixture-only-password", confirmPassword: "fixture-only-password")
    }
    private func makeClient(_ scenario: String) -> (SupabaseClient, String) {
        let fixture = UUID().uuidString
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SignupFixtureProtocol.self]
        let client = SupabaseClient(supabaseURL: URL(string: "https://signup-fixture.invalid")!, supabaseKey: "fixture-publishable", options: .init(
            auth: .init(storage: SignupFixtureStorage(), storageKey: fixture, autoRefreshToken: false),
            global: .init(headers: ["X-Signup-Fixture": fixture, "X-Signup-Scenario": scenario], session: URLSession(configuration: configuration))
        ))
        return (client, fixture)
    }
}

private final class SignupFixtureStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}
private final class SignupFixtureRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: [URLRequest]] = [:]
    func append(_ request: URLRequest, fixture: String) { lock.withLock { values[fixture, default: []].append(request) } }
    func requests(_ fixture: String) -> [URLRequest] { lock.withLock { values[fixture] ?? [] } }
}
private final class SignupFixtureProtocol: URLProtocol, @unchecked Sendable {
    static let recorder = SignupFixtureRecorder()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    static func body(_ request: URLRequest) -> Any? {
        if let data = request.httpBody { return try? JSONSerialization.jsonObject(with: data) }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(buffer, count: count) }
        return try? JSONSerialization.jsonObject(with: data)
    }
    override func startLoading() {
        let fixture = request.value(forHTTPHeaderField: "X-Signup-Fixture") ?? "unknown"
        let scenario = request.value(forHTTPHeaderField: "X-Signup-Scenario") ?? "unknown"
        Self.recorder.append(request, fixture: fixture)
        let preference = scenario == "existingParent" || scenario == "newProvider" ? "provider" : scenario == "unsupported" ? "admin" : "parent"
        var user: [String: Any] = ["id": "00000000-0000-0000-0000-000000000031", "aud": "authenticated", "role": "authenticated", "email": "fixture@example.org", "user_metadata": ["full_name": "Fixture Parent", "signup_account_type": preference], "app_metadata": [:], "created_at": "2026-10-01T12:00:00Z", "updated_at": "2026-10-01T12:00:00Z", "identities": []]
        if scenario != "unconfirmed" { user["email_confirmed_at"] = "2026-10-01T12:00:00Z" }
        let session: [String: Any] = ["access_token": "fixture-token", "refresh_token": "fixture-refresh", "token_type": "bearer", "expires_in": 3600, "expires_at": Int(Date().timeIntervalSince1970) + 3600, "user": user]
        var status = 200; let payload: Any
        switch request.url?.path {
        case "/auth/v1/signup": payload = scenario == "confirmation" ? user : session
        case "/auth/v1/token": payload = session
        case "/auth/v1/user": payload = user
        case "/rest/v1/user_roles": payload = scenario == "existingParent" ? [["role": "parent"]] : []
        case "/rest/v1/rpc/claim_onboarding_role":
            let count = Self.recorder.requests(fixture).filter { $0.url?.path.contains("claim_onboarding_role") == true }.count
            if scenario == "roleFailure" && count == 1 { status = 500; payload = ["message": "Fixture role save unavailable", "code": "XX000", "details": "", "hint": ""] }
            else { payload = preference }
        default: status = 500; payload = ["message": "Unexpected fixture path"]
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
}
