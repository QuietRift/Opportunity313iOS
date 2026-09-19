import SwiftUI

struct AdminReviewView: View {
    @ObservedObject var adminService: AdminService
    @Binding var filter: AdminOpportunityFilter
    @State private var search = ""
    private var visible: [Opportunity] {
        adminService.opportunities.filter {
            filter.includes($0) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
                || $0.category.localizedCaseInsensitiveContains(search) || $0.summary.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Status", selection: $filter) {
                    ForEach(AdminOpportunityFilter.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).padding()
                if let error = adminService.errorMessage {
                    AdminLoadError(message: error) { Task { await adminService.refresh() } }.padding(.horizontal)
                }
                if adminService.isLoading && adminService.opportunities.isEmpty {
                    ProgressView("Loading opportunities…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visible.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "No \(filter.rawValue.lowercased()) opportunities" : "No matches",
                        systemImage: "doc.text.magnifyingglass", description: Text(search.isEmpty ? "Pull to refresh or choose another status." : "Try another title or category."))
                } else {
                    List(visible) { opportunity in
                        NavigationLink {
                            AdminOpportunityDetailView(opportunity: opportunity, adminService: adminService)
                        } label: { AdminOpportunityCard(opportunity: opportunity) }
                    }.listStyle(.plain).scrollContentBackground(.hidden)
                }
            }
            .opportunity313PageBackground()
            .navigationTitle("Opportunities")
            .searchable(text: $search, prompt: "Title, category, or description")
            .refreshable { await adminService.refresh() }
            .toolbar { Button("Refresh", systemImage: "arrow.clockwise") { Task { await adminService.refresh() } }.disabled(adminService.isLoading) }
            .safeAreaInset(edge: .bottom) {
                if let success = adminService.successMessage {
                    HStack {
                        Text(success).font(.caption)
                        Spacer()
                        Button("Dismiss", systemImage: "xmark") { adminService.successMessage = nil }.labelStyle(.iconOnly)
                    }.padding().background(.regularMaterial)
                }
            }
        }
    }
}

struct AdminOpportunityCard: View {
    let opportunity: Opportunity
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(opportunity.category.uppercased()).font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                Text(opportunity.adminStatus).font(.caption2.bold()).padding(6).background(.quaternary, in: Capsule())
            }
            Text(opportunity.title).font(.headline)
            Text(opportunity.summaryWithoutExternalURL).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            Label(opportunity.startDisplayText, systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 6)
    }
}
