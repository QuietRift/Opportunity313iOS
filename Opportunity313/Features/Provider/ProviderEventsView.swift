import SwiftUI

struct ProviderEventsView: View {
    let organization: Organization
    @StateObject private var opportunityService = ProviderOpportunityService()

    private var scheduledOpportunities: [Opportunity] {
        opportunityService.opportunities.sorted { $0.startsAt < $1.startsAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if opportunityService.isLoading && scheduledOpportunities.isEmpty {
                    ProgressView("Loading events...")
                } else if let error = opportunityService.errorMessage {
                    ContentUnavailableView("Unable to Load Events", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if scheduledOpportunities.isEmpty {
                    ContentUnavailableView("No Events Yet", systemImage: "calendar", description: Text("Submit an opportunity from the Opportunities tab to see its schedule here."))
                } else {
                    List(scheduledOpportunities) { opportunity in
                        NavigationLink {
                            OpportunityDetailView(opportunity: opportunity)
                        } label: {
                            ProviderOpportunityRow(opportunity: opportunity)
                        }
                    }
                }
            }
            .navigationTitle("Events")
            .task { await loadEvents() }
            .refreshable { await loadEvents() }
        }
    }

    private func loadEvents() async {
        await opportunityService.fetchOpportunities(organizationID: organization.id)
    }
}
