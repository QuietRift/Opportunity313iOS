//
//  OpportunityFilterView.swift
//  Opportunity313
//
//  Created by Kevin Colston on 9/17/26.
//

import SwiftUI

struct OpportunityFilterView: View {

    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.dismiss) private var dismiss

    @Binding var selectedAge: Int?
    @Binding var selectedGrade: Int?
    @Binding var selectedNeighborhood: String?

    @Binding var freeOnly: Bool
    @Binding var transportationOnly: Bool

    let neighborhoods: [String]

    var body: some View {

        NavigationStack {

            Form {

                Section("Eligibility") {

                    Picker(
                        "Age",
                        selection: $selectedAge
                    ) {

                        Text("Any Age")
                            .tag(nil as Int?)

                        ForEach(2...24, id: \.self) { age in
                            Text("\(age)")
                                .tag(age as Int?)
                        }
                    }

                    Picker(
                        "Grade",
                        selection: $selectedGrade
                    ) {

                        Text("Any Grade")
                            .tag(nil as Int?)

                        Text("Kindergarten")
                            .tag(0 as Int?)

                        ForEach(1...12, id: \.self) { grade in

                            Text("Grade \(grade)")
                                .tag(grade as Int?)
                        }
                    }
                }

                Section("Location") {

                    Picker(
                        "Neighborhood",
                        selection: $selectedNeighborhood
                    ) {

                        Text("All Neighborhoods")
                            .tag(nil as String?)

                        ForEach(
                            neighborhoods,
                            id: \.self
                        ) { neighborhood in

                            Text(neighborhood)
                                .tag(
                                    neighborhood as String?
                                )
                        }
                    }
                }

                Section("Preferences") {

                    Toggle(
                        "Free opportunities only",
                        isOn: $freeOnly
                    )

                    Toggle(
                        "Transportation available",
                        isOn: $transportationOnly
                    )
                }

                Section {

                    Button("Clear All Filters") {

                        selectedAge = nil
                        selectedGrade = nil
                        selectedNeighborhood = nil
                        freeOnly = false
                        transportationOnly = false
                    }
                    .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                Opportunity313Brand.canvas(for: colorScheme)
                    .ignoresSafeArea()
            )
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(
                    placement: .confirmationAction
                ) {

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .opportunity313PageBackground()
    }
}
