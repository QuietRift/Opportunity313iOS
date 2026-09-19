//
//  ParentChildrenView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ParentChildrenView: View {

    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var childService =
        ParentManagedYouthService()

    @State private var showAddChild = false

    var body: some View {

        NavigationStack {

            Group {

                if childService.isLoading &&
                    childService.children.isEmpty {

                    ProgressView("Loading children...")

                } else if let error = childService.errorMessage {
                    ContentUnavailableView("Unable to Load Children", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if childService.children.isEmpty {

                    ContentUnavailableView(
                        "No Youth Profiles Yet",
                        systemImage:
                            "person.2.badge.plus",
                        description: Text(
                            "Add a child to begin finding and managing opportunities for them."
                        )
                    )

                } else {

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(childService.children) { child in
                                NavigationLink {
                                    ParentChildDetailView(
                                        child: child,
                                        childService: childService
                                    )
                                } label: {
                                    HStack(spacing: 12) {
                                        ParentChildRow(child: child)

                                        Image(systemName: "chevron.right")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(16)
                                    .background(
                                        Opportunity313Brand.surface(for: colorScheme),
                                        in: RoundedRectangle(cornerRadius: 18)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Opportunity313Brand.accent.opacity(0.14))
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("managedChildLink")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
            .navigationTitle("Children")
            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button {

                        showAddChild = true

                    } label: {

                        Image(
                            systemName:
                                "person.badge.plus"
                        )
                    }
                }
            }
            .task {

                await childService
                    .fetchChildren()
            }
            .refreshable {

                await childService
                    .fetchChildren()
            }
            .sheet(
                isPresented: $showAddChild
            ) {

                AddChildView(
                    childService:
                        childService
                )
            }
        }
        .opportunity313PageBackground()
    }
}


// MARK: - Child Row

struct ParentChildRow: View {

    let child: YouthProfile

    var body: some View {

        HStack(spacing: 14) {

            Image(
                systemName:
                    "person.crop.circle.fill"
            )
            .font(.system(size: 38))
            .foregroundStyle(.secondary)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {

                Text(child.firstName)
                    .font(.headline)

                HStack(spacing: 8) {

                    Text(child.ageBand)

                    if let grade =
                        child.grade {

                        Text("•")

                        Text(
                            grade == 0
                            ? "Kindergarten"
                            : "Grade \(grade)"
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
