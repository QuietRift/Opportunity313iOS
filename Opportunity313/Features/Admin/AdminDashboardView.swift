import SwiftUI

struct AdminDashboardView: View {
    @ObservedObject var service: AdminService
    let openOpportunities: (AdminOpportunityFilter) -> Void
    let openPeople: () -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Opportunity313").font(.subheadline).foregroundStyle(.secondary)
                        Text("Admin Dashboard").font(.largeTitle.bold())
                        Text("Review opportunities. Support Detroit families.").foregroundStyle(.secondary)
                    }
                    if let error = service.errorMessage {
                        AdminLoadError(message: error) { Task { await service.refresh() } }
                    }
                    if let stats = service.stats {
                        Button { openOpportunities(.pending) } label: {
                            ProviderDashboardCard(title: "\(stats.pending) pending approval",
                                description: "Review provider submissions and make a decision.", icon: "checkmark.seal.fill")
                        }.buttonStyle(.plain)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 12) {
                            metric("Approved", value: stats.approved, icon: "checkmark.circle") { openOpportunities(.approved) }
                            metric("Rejected", value: stats.rejected, icon: "xmark.circle") { openOpportunities(.rejected) }
                            metric("Paused", value: stats.paused, icon: "pause.circle") { openOpportunities(.paused) }
                            metric("User accounts", value: stats.users, icon: "person.2") { openPeople() }
                            metric("Youth profiles", value: stats.youth, icon: "person.crop.circle") { openPeople() }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Community overview").font(.title2.bold())
                            LabeledContent("Organizations", value: "\(stats.organizations)")
                            LabeledContent("Parent-managed youth", value: "\(stats.parentManaged)")
                            Text("Counts include all stored records, including demo data. Approved means published; expired deadlines may hide an opportunity from discovery.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    } else if service.isLoading { ProgressView("Loading dashboard…").frame(maxWidth: .infinity) }
                    NavigationLink { SchoolTicketAdministrationView() } label: {
                        ProviderDashboardCard(title: "School Ticketing", description: "Manage existing school ticket operations.", icon: "ticket")
                    }.buttonStyle(.plain)
                }.padding().frame(maxWidth: 850).frame(maxWidth: .infinity)
            }
            .opportunity313PageBackground()
            .navigationTitle("Dashboard").navigationBarTitleDisplayMode(.inline)
            .refreshable { await service.refresh() }
            .toolbar { Button("Refresh", systemImage: "arrow.clockwise") { Task { await service.refresh() } }.disabled(service.isLoading) }
        }
    }
    private func metric(_ title: String, value: Int, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).foregroundStyle(.tint)
                Text(value.formatted()).font(.largeTitle.bold()).foregroundStyle(.primary)
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

struct AdminLoadError: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unable to refresh", systemImage: "exclamationmark.triangle").font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
            Button("Try Again", action: retry)
        }.padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
