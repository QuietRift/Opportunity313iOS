//
//  OpportunityService.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import Foundation
import Combine
import Supabase

@MainActor
final class OpportunityService: ObservableObject {

    @Published var opportunities: [Opportunity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseManager.shared.client

    func fetchOpportunities() async {

        isLoading = true
        errorMessage = nil

        do {

            let response: [Opportunity] = try await supabase
                .from("opportunities")
                .select()
                .eq("status", value: "published")
                .order("starts_at", ascending: true)
                .execute()
                .value

            opportunities = response

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
