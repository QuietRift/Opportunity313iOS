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

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(
                string: "https://pinpurdjfbvxrwexzlre.supabase.co"
            )!,
            supabaseKey: "sb_publishable_SE20ynXjKObWJ7AeOwfw8A_8lSAJ83q"
        )
    }
}
