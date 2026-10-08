import SwiftUI

struct ReportIssueView: View {
    let opportunityID: UUID?
    let opportunityName: String?
    @State private var category: IssueCategory
    @State private var title = ""
    @State private var details = ""
    @State private var requestID = UUID()
    @State private var submitted: IssueReport?
    @StateObject private var service = IssueReportService()

    init(opportunityID: UUID? = nil, opportunityName: String? = nil, initialCategory: IssueCategory = .app) {
        self.opportunityID = opportunityID; self.opportunityName = opportunityName
        _category = State(initialValue: initialCategory)
    }
    var body: some View {
        Form {
            if let submitted {
                Section {
                    Label("Report Submitted", systemImage: "checkmark.circle.fill").font(.headline)
                    Text("The Opportunity313 team can now review your report. Check My Reports for its status and response.")
                    Text(submitted.reference).font(.headline).textSelection(.enabled)
                    NavigationLink { IssueReportsView() } label: { Text("My Reports") }
                }
            } else {
                Section("What went wrong?") {
                    Picker("Category", selection: $category) { ForEach(IssueCategory.allCases) { Text($0.title).tag($0) } }
                    if let opportunityName { LabeledContent("Opportunity", value: opportunityName) }
                    TextField("Short title", text: $title)
                    TextField("Describe what happened and what you expected", text: $details, axis: .vertical).lineLimit(6...15)
                    Text("\(details.count) / 4,000 characters").font(.caption).foregroundStyle(.secondary)
                }.disabled(service.isWorking)
                Section {
                    Text("Include the steps that led to the problem. Please leave out passwords, access codes, ticket QR codes, and payment information.").font(.footnote).foregroundStyle(.secondary)
                    if let error = service.errorMessage { Text(error).foregroundStyle(.red) }
                    Button("Submit Report") {
                        Task { submitted = await service.submit(id: requestID, category: category, title: title, details: details, opportunityID: opportunityID) }
                    }.disabled(service.isWorking || IssueReportValidation.message(title: title, details: details) != nil)
                    .accessibilityIdentifier("submitIssueReport")
                    if service.isWorking { ProgressView("Submitting report…") }
                }
            }
        }.navigationTitle("Report an Issue")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: category) { _, _ in requestID = UUID() }
        .onChange(of: title) { _, _ in requestID = UUID() }
        .onChange(of: details) { _, _ in requestID = UUID() }
        .opportunity313PageBackground()
    }
}

struct IssueReportsView: View {
    var isAdmin = false
    @StateObject private var service = IssueReportService()
    @State private var status: IssueStatus?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        List {
            Section {
                Picker("Status", selection: $status) {
                    Text("All").tag(nil as IssueStatus?)
                    ForEach(IssueStatus.allCases) { Text($0.title).tag(Optional($0)) }
                }
            }
            if service.isLoading { ProgressView("Loading reports…") }
            if let error = service.errorMessage { Text(error).foregroundStyle(.red); Button("Try Again") { Task { await load() } } }
            ForEach(service.reports) { report in
                NavigationLink { IssueReportDetailView(initialReport: report, isAdmin: isAdmin) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(report.title).font(.headline)
                        Text("\(report.category.title) · \(report.status.title)").font(.subheadline)
                        if let name = report.opportunityName { Text(name).font(.caption).foregroundStyle(.secondary) }
                        Text(report.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
            }
            if service.reports.isEmpty && !service.isLoading && service.errorMessage == nil {
                ContentUnavailableView("No Reports", systemImage: "text.bubble", description: Text(isAdmin ? "Submitted issues will appear here for review." : "Your submitted issues and the team’s responses appear here."))
            }
            if !isAdmin { NavigationLink { ReportIssueView() } label: { Label("Report an Issue", systemImage: "exclamationmark.bubble") } }
            if service.reports.count == 200 { Text("Showing the latest 200 reports. Choose a status to narrow the list.").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle(isAdmin ? "Issue Reports" : "My Reports")
        .task { await load() }.refreshable { await load() }
        .onChange(of: status) { _, _ in Task { await load() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
        .opportunity313PageBackground()
    }
    private func load() async { await service.load(isAdmin: isAdmin, status: status) }
}

struct IssueReportDetailView: View {
    let initialReport: IssueReport
    var isAdmin = false
    @State private var report: IssueReport?
    @State private var status: IssueStatus = .submitted
    @State private var response = ""
    @State private var ready = false
    @State private var saved = false
    @StateObject private var service = IssueReportService()
    var body: some View {
        Form {
            if let report {
                Section {
                    Text(report.title).font(.headline)
                    LabeledContent("Reference", value: report.reference)
                    LabeledContent("Category", value: report.category.title)
                    LabeledContent("Status", value: report.status.title)
                    if let name = report.opportunityName { LabeledContent("Opportunity", value: name) }
                    LabeledContent("Submitted", value: report.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Text(report.details).textSelection(.enabled)
                    if isAdmin { Text("Source: \(report.platform)\(report.appVersion.map { " · " + $0 } ?? "")").font(.caption).foregroundStyle(.secondary) }
                }
                if isAdmin {
                    Section("Review") {
                        Picker("Status", selection: $status) { ForEach(IssueStatus.allCases) { Text($0.title).tag($0) } }
                        TextField("Response visible to the person who reported this issue", text: $response, axis: .vertical).lineLimit(5...12)
                        Text("This response appears in the user’s My Reports screen.").font(.footnote)
                        Button("Save Review") { Task { await save(report) } }
                            .disabled(service.isWorking || !ready || response.count > 2000 || (status == .resolved && response.trimmingCharacters(in: .whitespacesAndNewlines).count < 5))
                    }.disabled(service.isWorking)
                    if saved && status == report.status && response == report.response { Label("Review saved", systemImage: "checkmark.circle") }
                } else if !report.response.isEmpty {
                    Section("Response from Opportunity313") { Text(report.response).textSelection(.enabled) }
                }
            } else if !ready { ProgressView("Loading report…") }
            if let error = service.errorMessage { Text(error).foregroundStyle(.red); Button("Refresh Report") { Task { await load() } }.disabled(service.isWorking) }
        }.navigationTitle("Issue Report").navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { if !service.isWorking { await load() } }
        .opportunity313PageBackground()
    }
    private func load() async {
        ready = false; saved = false
        if let result = await service.fetch(id: initialReport.id) {
            report = result; status = result.status; response = result.response
        } else { report = nil }
        ready = true
    }
    private func save(_ current: IssueReport) async {
        saved = false
        if let result = await service.review(report: current, status: status, response: response) {
            report = result; status = result.status; response = result.response; saved = true
        }
    }
}
