//
//  OnboardingService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class OnboardingService: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    func claimRole(_ role: String) async throws {

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let _: String = try await supabase
                .rpc(
                    "claim_onboarding_role",
                    params: [
                        "requested_role": role
                    ]
                )
                .execute()
                .value

        } catch {

            errorMessage = error.localizedDescription
            throw error
        }
    }
}
