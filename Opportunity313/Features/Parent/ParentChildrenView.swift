//
//  ParentChildrenView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/18/26.
//

import SwiftUI

struct ParentChildrenView: View {

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

                    List(
                        childService.children
                    ) { child in

                        NavigationLink {

                            ParentChildDetailView(
                                child: child
                            )

                        } label: {

                            ParentChildRow(
                                child: child
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
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
