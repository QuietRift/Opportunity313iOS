//
//  AdminOpportunityDetailView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct AdminOpportunityDetailView: View {

    @Environment(\.dismiss)
    private var dismiss

    let opportunity: Opportunity

    @ObservedObject var adminService:
        AdminService

    @State private var isApproving = false

    var body: some View {

        OpportunityDetailView(
            opportunity: opportunity
        )
        .safeAreaInset(
            edge: .bottom
        ) {

            VStack(spacing: 10) {

                Divider()

                Button {

                    Task {
                        await approveOpportunity()
                    }

                } label: {

                    HStack {

                        if isApproving {

                            ProgressView()
                                .tint(.white)

                        } else {

                            Image(
                                systemName:
                                    "checkmark.seal.fill"
                            )
                        }

                        Text(
                            isApproving
                            ? "Publishing..."
                            : "Approve & Publish"
                        )
                        .fontWeight(.semibold)
                    }
                    .frame(
                        maxWidth: .infinity
                    )
                    .padding(.vertical, 4)
                }
                .buttonStyle(
                    .borderedProminent
                )
                .controlSize(.large)
                .disabled(isApproving)


                Text(
                    "This will verify the provider organization and make this opportunity visible to youth and families."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)


                if let error =
                    adminService.errorMessage {

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(
                .regularMaterial
            )
        }
    }


    // MARK: - Approve

    private func approveOpportunity() async {

        isApproving = true

        await adminService
            .approveAndPublish(
                opportunity
            )

        isApproving = false


        // Only leave the detail screen if
        // publishing succeeded.

        if adminService.errorMessage == nil {

            dismiss()
        }
    }
}
