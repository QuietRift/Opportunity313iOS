//
//  SupabaseManager.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//


import Foundation
import Supabase

final class SupabaseManager {

    static let shared = SupabaseManager()

    static let publishableKey = "sb_publishable_SE20ynXjKObWJ7AeOwfw8A_8lSAJ83q"
    static let projectURL = URL(string: "https://pinpurdjfbvxrwexzlre.supabase.co")!

    let client: SupabaseClient

    func loadSocialProviders(session: URLSession = .shared) async throws -> SocialProviderAvailability {
        var request = URLRequest(url: Self.projectURL.appendingPathComponent("auth/v1/settings"))
        request.setValue(Self.publishableKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SocialSignIn.Failure(message: "Unable to check sign-in options.")
        }
        return try JSONDecoder().decode(SocialProviderAvailability.self, from: data)
    }

    private init() {
        client = SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.publishableKey
        )
    }
}
