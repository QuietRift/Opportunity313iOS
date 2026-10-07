import Foundation
import AuthenticationServices
import Supabase
import Testing
@testable import Opportunity313

// All HTTP calls are intercepted; no real signup, email, or backend write occurs.
@Suite(.serialized)
struct SignupAuthTests {
    @Test @MainActor func savedChildCanRetryCodeWithoutCreatingAnotherProfile() async throws {
        let (client, fixture) = makeClient("childRetry")
        try await client.auth.signIn(email: "fixture@example.org", password: "fixture-only-password")
        let children = ParentManagedYouthService(client: client)
        let id = try await children.createChild(firstName: "Fixture Child", ageBand: "9-12", grade: 4, gender: .girl, interests: ["Arts"], accessibilityPreferences: [], relationship: "Parent")
        let access = ChildAccessService(client: client)
        await access.generate(for: id)
        #expect(access.generatedCode == nil)
        #expect(access.errorMessage != nil)
        await access.generate(for: id)
        #expect(access.generatedCode == "O313-ABCD-EFGH-JKLM")
        #expect(access.expiresAt != nil)
        #expect(access.errorMessage == nil)
        let calls = SignupFixtureProtocol.recorder.requests(fixture)
        #expect(calls.filter { $0.url?.path == "/rest/v1/rpc/create_parent_managed_youth" }.count == 1)
        #expect(calls.filter { $0.url?.path == "/functions/v1/child-access" }.count == 2)
    }
    @Test @MainActor func malformedOrExpiredChildCodesAreNeverDisplayed() async {
        for scenario in ["childMalformed", "childExpired"] {
            let (client, _) = makeClient(scenario)
            let access = ChildAccessService(client: client)
            await access.generate(for: UUID())
            #expect(access.generatedCode == nil)
            #expect(access.expiresAt == nil)
            #expect(access.errorMessage != nil)
        }
    }

    @Test @MainActor func recoveryRequiresValidOTPBeforeChangingPassword() async throws {
        let (client, fixture) = makeClient("newParent")
        let service = AuthService(client: client)
        #expect(await service.finishPasswordReset(password: "new-password", confirmation: "new-password") == false)
        #expect(await service.requestPasswordReset(email: "fixture@example.org"))
        #expect(await service.verifyPasswordReset(email: "fixture@example.org", code: "123456"))
        #expect(service.isRecoveringPassword)
        #expect(await service.finishPasswordReset(password: "new-password", confirmation: "mismatch") == false)
        #expect(await service.finishPasswordReset(password: "new-password", confirmation: "new-password"))
        #expect(!service.isRecoveringPassword)
        #expect(SignupFixtureProtocol.recorder.requests(fixture).filter { $0.url?.path == "/auth/v1/user" && $0.httpMethod == "PUT" }.count == 1)
    }

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

    @Test @MainActor func googleSignupPreservesChosenParentOrProviderUsingPKCE() async throws {
        for type in [SignupAccountType.parent, .provider] {
            let (service, fixture) = await makeSocialService("socialNew")
            let success = await service.signInWithGoogle(accountType: type) { url in
                let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                #expect(items.first { $0.name == "provider" }?.value == "google")
                #expect(items.first { $0.name == "redirect_to" }?.value == SocialSignIn.callbackURL.absoluteString)
                #expect(items.first { $0.name == "code_challenge_method" }?.value == "s256")
                #expect(items.first { $0.name == "code_challenge" }?.value?.isEmpty == false)
                return URL(string: "com.kevin.opportunity313://auth/callback?code=fixture-code")!
            }
            #expect(success && service.isAuthenticated)
            #expect(service.role == type.rawValue)
            #expect(!service.isLoading)
            let calls = SignupFixtureProtocol.recorder.requests(fixture)
            let claim = try #require(calls.first { $0.url?.path.contains("claim_onboarding_role") == true })
            #expect((SignupFixtureProtocol.body(claim) as? [String: String])?["requested_role"] == type.rawValue)
            let token = try #require(calls.first { $0.url?.path == "/auth/v1/token" })
            #expect(token.url?.query == "grant_type=pkce")
            #expect((SignupFixtureProtocol.body(token) as? [String: String])?["code_verifier"]?.isEmpty == false)
        }
    }

    @Test @MainActor func socialSignupCannotChangeExistingParentRole() async {
        let (service, fixture) = await makeSocialService("existingParent")
        #expect(await service.signInWithGoogle(accountType: .provider) { _ in
            URL(string: "com.kevin.opportunity313://auth/callback?code=fixture-code")!
        })
        #expect(service.role == "parent")
        #expect(!SignupFixtureProtocol.recorder.requests(fixture).contains { $0.url?.path.contains("claim_onboarding_role") == true })
    }

    @Test @MainActor func socialLoginWithoutSignupChoiceKeepsManualOnboarding() async {
        let (service, _) = await makeSocialService("socialNew")
        #expect(await service.signInWithGoogle { _ in URL(string: "com.kevin.opportunity313://auth/callback?code=fixture-code")! })
        #expect(service.role == nil && service.needsOnboarding)
    }

    @Test @MainActor func cancelledGoogleOrAppleSignInDoesNotShowAnErrorOrCreateAccount() async throws {
        let (service, fixture) = await makeSocialService("socialNew")
        #expect(await service.signInWithGoogle(accountType: .parent) { _ in
            throw ASWebAuthenticationSessionError(.canceledLogin)
        } == false)
        #expect(!service.isAuthenticated && !service.isLoading && service.errorMessage == nil)
        let nonce = try #require(service.prepareAppleSignIn(accountType: .provider, confirmsAdultAge: false))
        await service.completeAppleSignIn(.failure(ASAuthorizationError(.canceled)), nonce: nonce)
        #expect(!service.isAuthenticated && !service.isLoading && service.errorMessage == nil)
        #expect(SignupFixtureProtocol.recorder.requests(fixture).isEmpty)
    }

    @Test @MainActor func socialSignupRequiresYouthAgeConfirmation() async {
        let (service, fixture) = await makeSocialService("socialNew")
        #expect(await service.signInWithGoogle(accountType: .youth) { _ in
            Issue.record("Must not launch before age confirmation")
            return SocialSignIn.callbackURL
        } == false)
        #expect(service.prepareAppleSignIn(accountType: .youth, confirmsAdultAge: false) == nil)
        #expect(service.errorMessage != nil && !service.isLoading)
        #expect(SignupFixtureProtocol.recorder.requests(fixture).isEmpty)
    }

    @Test @MainActor func failedOrUnexpectedGoogleResponseDoesNotAuthenticate() async {
        for scenario in ["socialTokenFailure", "socialBadCallback"] {
            let (service, _) = await makeSocialService(scenario)
            let success = await service.signInWithGoogle(accountType: .parent) { _ in
                URL(string: scenario == "socialBadCallback" ? "com.kevin.opportunity313://other/callback?code=fixture-code" : "com.kevin.opportunity313://auth/callback?code=fixture-code")!
            }
            #expect(!success && !service.isAuthenticated && !service.isLoading)
            #expect(service.errorMessage != nil)
        }
    }

    @Test @MainActor func appleExchangesRawNonceAndSavesFirstAuthorizationName() async throws {
        let (service, fixture) = await makeSocialService("socialApple")
        let nonce = try #require(service.prepareAppleSignIn(accountType: .parent, confirmsAdultAge: false))
        try await service.exchangeAppleToken("fixture-apple-identity", nonce: nonce, fullName: "First Apple Name")
        #expect(service.role == "parent" && service.displayName == "First Apple Name")
        let calls = SignupFixtureProtocol.recorder.requests(fixture)
        let token = try #require(calls.first { $0.url?.path == "/auth/v1/token" })
        let body = try #require(SignupFixtureProtocol.body(token) as? [String: Any])
        #expect(body["provider"] as? String == "apple")
        #expect(body["nonce"] as? String == nonce)
        #expect(body["id_token"] as? String == "fixture-apple-identity")
        #expect(calls.contains { $0.url?.path == "/auth/v1/user" && $0.httpMethod == "PUT" })
    }

    @Test @MainActor func unavailableProvidersDoNotLaunchSignIn() async {
        let (client, fixture) = makeClient("socialNew")
        let service = AuthService(client: client, socialProviderLoader: { .init(external: [:]) })
        await service.refreshSocialProviders()
        #expect(service.socialProviders?.google == false && service.socialProviders?.apple == false)
        #expect(service.socialProviderMessage != nil)
        #expect(await service.signInWithGoogle { _ in Issue.record("Disabled provider launched"); return SocialSignIn.callbackURL } == false)
        #expect(SignupFixtureProtocol.recorder.requests(fixture).isEmpty)
    }

    @Test func providerSettingsRequestUsesTheProjectKeyAndParsesAvailability() async throws {
        let fixture = UUID().uuidString
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SignupFixtureProtocol.self]
        config.httpAdditionalHeaders = ["X-Signup-Fixture": fixture, "X-Signup-Scenario": "settings"]
        let providers = try await SupabaseManager.shared.loadSocialProviders(session: URLSession(configuration: config))
        #expect(providers.apple && !providers.google)
        let request = try #require(SignupFixtureProtocol.recorder.requests(fixture).first)
        #expect(request.value(forHTTPHeaderField: "apikey") == SupabaseManager.publishableKey)
        #expect(request.url?.path == "/auth/v1/settings")
    }

    @Test func appleNonceIsRandomAndHashIsDeterministic() throws {
        let first = try SocialSignIn.nonce(), second = try SocialSignIn.nonce()
        #expect(first.count == 64 && first != second)
        #expect(SocialSignIn.hash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @MainActor private func makeSocialService(_ scenario: String) async -> (AuthService, String) {
        let (client, fixture) = makeClient(scenario)
        let service = AuthService(client: client, socialProviderLoader: { .init(external: ["apple": true, "google": true]) })
        await service.refreshSocialProviders()
        return (service, fixture)
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
        if scenario.hasPrefix("social") { user["user_metadata"] = [:] }
        if request.httpMethod == "PUT", let body = Self.body(request) as? [String: Any], let data = body["data"] {
            user["user_metadata"] = data
        }
        if scenario != "unconfirmed" { user["email_confirmed_at"] = "2026-10-01T12:00:00Z" }
        let session: [String: Any] = ["access_token": "fixture-token", "refresh_token": "fixture-refresh", "token_type": "bearer", "expires_in": 3600, "expires_at": Int(Date().timeIntervalSince1970) + 3600, "user": user]
        var status = 200; let payload: Any
        switch request.url?.path {
        case "/auth/v1/signup": payload = scenario == "confirmation" ? user : session
        case "/auth/v1/token", "/auth/v1/verify":
            if scenario == "socialTokenFailure" { status = 400; payload = ["error": "invalid_grant", "error_description": "Fixture exchange failed"] }
            else { payload = session }
        case "/auth/v1/settings": payload = ["external": ["apple": true, "google": false]]
        case "/auth/v1/recover": payload = [:]
        case "/auth/v1/user": payload = user
        case "/rest/v1/rpc/create_parent_managed_youth": payload = "00000000-0000-0000-0000-000000000041"
        case "/rest/v1/guardian_relationships": payload = []
        case "/functions/v1/child-access":
            let count = Self.recorder.requests(fixture).filter { $0.url?.path == "/functions/v1/child-access" }.count
            if scenario == "childRetry" && count == 1 { status = 500; payload = ["error": "Fixture service unavailable"] }
            else { payload = ["code": scenario == "childMalformed" ? "invalid" : "O313-ABCD-EFGH-JKLM", "expiresAt": scenario == "childExpired" ? "2020-01-01T00:00:00Z" : "2099-01-01T00:00:00Z"] }
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
