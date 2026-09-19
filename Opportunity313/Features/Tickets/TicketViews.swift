import SwiftUI
import CoreImage.CIFilterBuiltins
import Vision
import VisionKit
import AVFoundation

struct TicketHubView: View {
    var body: some View {
        List {
            NavigationLink { TicketEventsView() } label: {
                Label("Browse Events", systemImage: "calendar")
            }
            NavigationLink { MyTicketsView() } label: {
                Label("My Tickets", systemImage: "ticket")
            }
            NavigationLink { SchoolLinkSelectorView() } label: {
                Label("Student Schools", systemImage: "building.2")
            }
            Section {
                Text("Reserve free admission tickets, keep your confirmation here, and show your QR code at check-in.")
                Text("Demo events and tickets are labeled. A demo ticket does not grant admission to a real event.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Event Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) { TicketPersistentHeader(title: "Event Tickets") }
        .opportunity313PageBackground()
    }
}

struct TicketEventsView: View {
    var managedOnly = false
    @StateObject private var service = TicketService()
    var body: some View {
        List {
            if let error = service.errorMessage {
                Text(error).foregroundStyle(.red)
                Button("Try Again") { Task { await service.loadEvents(managedOnly: managedOnly) } }
            } else if service.isLoading && service.events.isEmpty {
                ProgressView("Loading events…")
            } else if service.events.isEmpty {
                ContentUnavailableView(managedOnly ? "No Assigned Events" : "No Upcoming Events", systemImage: "calendar",
                    description: Text(managedOnly ? "Events assigned to your staff account will appear here." : "Check back for new events offering tickets."))
            }
            ForEach(service.events) { event in
                NavigationLink {
                    if managedOnly { TicketCheckInView(event: event) }
                    else { TicketEventDetailView(event: event) }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        if event.isDemo { DemoTicketLabel() }
                        Text(event.title).font(.headline)
                        Text(event.dateText).font(.subheadline)
                        Text(event.venueName).font(.subheadline).foregroundStyle(.secondary)
                        Text(managedOnly ? "Manage Check-In" : "Free admission").font(.caption.weight(.semibold))
                    }.padding(.vertical, 6)
                }
            }
        }
        .navigationTitle(managedOnly ? "Event Check-In" : "Event Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) { TicketPersistentHeader(title: managedOnly ? "Event Check-In" : "Event Tickets") }
        .task { await service.loadEvents(managedOnly: managedOnly) }
        .refreshable { await service.loadEvents(managedOnly: managedOnly) }
        .opportunity313PageBackground()
    }
}

struct TicketEventDetailView: View {
    let event: TicketEvent
    @StateObject private var service = TicketService()
    @StateObject private var schoolProfiles = SchoolVerificationService()
    @State private var selectedAllocation: UUID?
    @State private var selectedYouthProfileID: UUID?
    @State private var quantity = 1
    @State private var reviewed = false
    @State private var confirmation = false
    private var current: TicketEvent { service.events.first { $0.id == event.id } ?? event }
    private var allocation: TicketAllocation? { current.allocations.first { $0.id == selectedAllocation } }
    private var maximum: Int { allocation?.maximumQuantity ?? 0 }
    private var allocationIsStudent: Bool { allocation?.requiresSchoolVerification == true }
    private var eligibleYouth: [SchoolProfileLink] {
        guard let schoolID = current.schoolID else { return [] }
        return schoolProfiles.profiles.filter { $0.schoolID == schoolID && $0.isVerified }
    }

    var body: some View {
        Form {
            Section {
                if current.isDemo { DemoTicketLabel() }
                Text(current.title).font(.title2.bold())
                Label(current.dateText, systemImage: "calendar")
                Label(current.venueName, systemImage: "mappin.and.ellipse")
                Text(current.address).foregroundStyle(.secondary)
                Text("Free admission").font(.headline)
            }
            TransitDirectionsSection(destination: current.address, venueName: current.venueName)
            if confirmation {
                Section("Reservation Confirmed") {
                    Label(service.notice ?? "Your tickets are ready.", systemImage: "checkmark.circle.fill")
                    NavigationLink("View My Tickets") { MyTicketsView() }
                }
            } else if let hold = service.hold {
                Section("Finish Your Reservation") {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = max(0, Int(ceil(hold.expiresAt.timeIntervalSince(context.date))))
                        VStack(alignment: .leading, spacing: 10) {
                            Label(String(format: "%d:%02d remaining", seconds / 60, seconds % 60), systemImage: "timer")
                                .font(.title2.bold())
                                .foregroundStyle(seconds == 0 ? .red : .primary)
                            Button("Confirm Reservation") {
                                Task { if await service.confirmHold() { confirmation = true } }
                            }
                            .disabled(service.isWorking || seconds == 0)
                            if seconds == 0 {
                                Text("This hold expired. Release it and start a new checkout.").foregroundStyle(.red)
                            }
                        }
                    }
                    Text("Your \(hold.quantity) spot\(hold.quantity == 1 ? " is" : "s are") held for five minutes. Confirm before the timer ends.")
                    if let youthID = hold.assignedYouthProfileID,
                       let youth = schoolProfiles.profiles.first(where: { $0.youthProfileID == youthID }) {
                        Label("Student: \(youth.youthName)", systemImage: "person.fill")
                    }
                    Button("Release Held Spots", role: .destructive) { Task { await service.releaseHold() } }
                        .disabled(service.isWorking)
                }
            } else {
                Section("Reserve Your Spots") {
                    if current.reservationsOpen(at: Date()) && service.events.contains(where: { $0.id == event.id }) {
                        if current.allocations.isEmpty {
                            Text("Ticket options are not available yet.")
                        } else {
                            Picker("Ticket Option", selection: $selectedAllocation) {
                                Text("Choose an option").tag(nil as UUID?)
                                ForEach(current.allocations) { Text($0.name).tag(Optional($0.id)) }
                            }
                            if let allocation {
                                Text("\(allocation.remaining) spots available · Limit \(allocation.limitPerUser) per account")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                if allocation.requiresSchoolVerification {
                                    Text("Student tickets are only for youth verified by \(current.schoolName ?? "this school").")
                                        .font(.footnote).foregroundStyle(.secondary)
                                    if eligibleYouth.isEmpty {
                                        Text("No youth on this account is verified for this school yet.")
                                            .foregroundStyle(.secondary)
                                        NavigationLink("Add or Verify a Student's School") { SchoolLinkSelectorView() }
                                    } else {
                                        Picker("Student", selection: $selectedYouthProfileID) {
                                            Text("Choose a verified student").tag(nil as UUID?)
                                            ForEach(eligibleYouth) { youth in
                                                Text(youth.youthName).tag(Optional(youth.youthProfileID))
                                            }
                                        }
                                    }
                                } else if maximum > 0 {
                                    Stepper("\(quantity) ticket\(quantity == 1 ? "" : "s")", value: $quantity, in: 1...max(1, maximum))
                                } else {
                                    Text(allocation.remaining == 0 ? "This ticket option is sold out." : "You have reached the ticket limit for this option.")
                                }
                            }
                            Toggle(current.isDemo ? "I understand these are demo tickets." : "I reviewed the event date and location.", isOn: $reviewed)
                            Button {
                                guard let selectedAllocation else { return }
                                Task { await service.startHold(allocationID: selectedAllocation, quantity: allocation?.requiresSchoolVerification == true ? 1 : quantity,
                                                               youthProfileID: allocation?.requiresSchoolVerification == true ? selectedYouthProfileID : nil) }
                            } label: {
                                HStack {
                                    if service.isWorking { ProgressView() }
                                    Text("Hold Spots for 5:00")
                                }
                            }
                            .disabled(!reviewed || maximum < 1 || (!allocationIsStudent && maximum < quantity) ||
                                      (allocationIsStudent && !eligibleYouth.contains(where: { $0.youthProfileID == selectedYouthProfileID })) ||
                                      service.isWorking || service.isLoading || service.errorMessage != nil)
                        }
                    } else {
                        Text("Reservations are currently closed for this event.")
                    }
                }
                Section {
                    Text("Each ticket admits one person. Spots are held for five minutes while you confirm.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let error = service.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                    Button("Refresh Availability") { Task { await service.loadEvents() } }.disabled(service.isWorking)
                }
            }
        }
        .navigationTitle("Reserve Tickets").navigationBarTitleDisplayMode(.inline)
        .task { await service.loadEvents(); await schoolProfiles.loadProfiles() }
        .refreshable {
            if !service.isWorking { await service.loadEvents() }
            await schoolProfiles.loadProfiles()
        }
        .onChange(of: selectedAllocation) { _, _ in quantity = 1; selectedYouthProfileID = nil }
        .onReceive(NotificationCenter.default.publisher(for: .schoolVerificationDidChange)) { _ in
            Task { await schoolProfiles.loadProfiles() }
        }
        .onChange(of: maximum) { _, value in quantity = max(1, min(quantity, value)) }
        .opportunity313PageBackground()
    }
}

struct MyTicketsView: View {
    @StateObject private var service = TicketService()
    var body: some View {
        List {
            if let error = service.errorMessage {
                Text(error).foregroundStyle(.red)
                Button("Try Again") { Task { await service.loadTickets() } }
            } else if service.isLoading && service.tickets.isEmpty {
                ProgressView("Loading tickets…")
            } else if service.tickets.isEmpty {
                ContentUnavailableView("No Tickets Yet", systemImage: "ticket", description: Text("Your confirmed reservations will appear here."))
                NavigationLink("Browse Events") { TicketEventsView() }
            }
            ForEach(service.tickets) { ticket in
                NavigationLink { TicketDetailView(initialTicket: ticket, service: service) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        if ticket.isDemo { DemoTicketLabel() }
                        Text(ticket.eventTitle).font(.headline)
                        Text(ticket.allocationName).font(.subheadline)
                        if let youth = ticket.assignedYouthName { Text("Student: \(youth)").font(.subheadline) }
                        Text(ticket.dateText).font(.caption).foregroundStyle(.secondary)
                        Text(ticket.statusText).font(.subheadline.weight(.semibold))
                    }.padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("My Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) { TicketPersistentHeader(title: "My Tickets") }
        .task { await service.loadTickets() }
        .refreshable { await service.loadTickets() }
        .opportunity313PageBackground()
    }
}

struct TicketDetailView: View {
    let initialTicket: EventTicket
    @ObservedObject var service: TicketService
    @State private var code: String?
    @State private var confirmCancel = false
    @State private var confirmReplace = false
    private var ticket: EventTicket { service.tickets.first { $0.id == initialTicket.id } ?? initialTicket }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if ticket.isDemo { DemoTicketLabel() }
                Text(ticket.eventTitle).font(.title.bold())
                Label(ticket.statusText, systemImage: ticket.canShowCode ? "checkmark.seal" : "ticket")
                    .font(.headline)
                Text(ticket.allocationName)
                if let youth = ticket.assignedYouthName { Label("Student: \(youth)", systemImage: "person.fill") }
                Label(ticket.dateText, systemImage: "calendar")
                Label(ticket.venueName, systemImage: "mappin.and.ellipse")
                Text(ticket.address).foregroundStyle(.secondary)
                Text("Ticket \(ticket.id.uuidString)").font(.caption).textSelection(.enabled)
                if ticket.canShowCode {
                    if let code {
                        TicketQRCode(token: code)
                        Text("Show this QR code at check-in. Each ticket can be checked in once.")
                            .font(.subheadline)
                        if ticket.assignedYouthName == nil {
                            ShareLink(item: TicketCode.prefix + code) { Label("Share Entry Code", systemImage: "square.and.arrow.up") }
                        } else {
                            Text("This student ticket is assigned to \(ticket.assignedYouthName ?? "the verified student").")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        DisclosureGroup("Full Entry Code") {
                            Text(code).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    } else {
                        Text("An entry code is not stored on this device. Generate a replacement for this confirmed ticket.")
                    }
                    Button(code == nil ? "Generate Entry Code" : "Replace Entry Code") { confirmReplace = true }
                        .disabled(service.isWorking)
                }
                if ticket.canCancel(at: Date()) {
                    Button("Cancel Ticket", role: .destructive) { confirmCancel = true }.disabled(service.isWorking)
                }
                if service.isWorking { ProgressView() }
                if let error = service.errorMessage { Text(error).foregroundStyle(.red) }
                if ticket.isDemo { Text("Demo only — not valid for admission to a real event.").font(.footnote) }
            }
            .padding().frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .navigationTitle("Ticket").navigationBarTitleDisplayMode(.inline)
        .onAppear { code = service.cachedCode(ticketID: ticket.id) }
        .refreshable { await service.loadTickets() }
        .confirmationDialog("Replace this ticket's entry code?", isPresented: $confirmReplace, titleVisibility: .visible) {
            Button("Generate Replacement") { Task { code = await service.replaceCode(ticketID: ticket.id) } }
        } message: { Text("Any previous QR code or shared entry code for this ticket will stop working.") }
        .confirmationDialog("Cancel this ticket?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel Ticket", role: .destructive) { Task { await service.cancel(ticketID: ticket.id) } }
        } message: { Text("This releases one spot and invalidates its entry code.") }
        .opportunity313PageBackground()
    }
}

private struct TicketQRCode: View {
    let token: String
    private var qrImage: CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data((TicketCode.prefix + token).utf8)
        guard let output = filter.outputImage else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
    var body: some View {
        if let qrImage {
            Image(decorative: qrImage, scale: 1)
                .interpolation(.none).resizable().scaledToFit().padding(20)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 300).frame(maxWidth: .infinity)
                .accessibilityLabel("Ticket QR code for staff check-in")
        }
    }
}

private struct DemoTicketLabel: View {
    var body: some View {
        Label("Demo Event", systemImage: "testtube.2").font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.orange.opacity(0.15), in: Capsule())
    }
}

struct TicketCheckInView: View {
    let event: TicketEvent
    @StateObject private var service = TicketService()
    @State private var entryCode = ""
    @State private var result: String?
    @State private var showScanner = false
    var body: some View {
        List {
            Section {
                if event.isDemo { DemoTicketLabel() }
                Text(event.title).font(.headline)
                Text(event.dateText)
            }
            if event.canManageCapacity {
                NavigationLink { SchoolTicketCapacityView(event: event) } label: {
                    Label("Manage Seats & Availability", systemImage: "seat.airplane")
                }
            }
            Section("Check In a Ticket") {
                Text("Student tickets are restricted to youth verified for this event's school.")
                    .font(.footnote).foregroundStyle(.secondary)
                TextField("Paste entry code", text: $entryCode, axis: .vertical)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Check In") { Task { await checkIn(entryCode) } }
                    .disabled(service.isWorking || TicketCode.token(from: entryCode) == nil)
                if DataScannerViewController.isSupported {
                    Button {
                        Task {
                            let granted = await AVCaptureDevice.requestAccess(for: .video)
                            if granted && DataScannerViewController.isAvailable { showScanner = true }
                            else { service.errorMessage = "Camera access is unavailable. Enable it in Settings, or paste the full entry code." }
                        }
                    } label: { Label("Scan QR Code", systemImage: "qrcode.viewfinder") }
                        .disabled(service.isWorking)
                } else {
                    Text("Camera scanning is unavailable on this device. Paste the ticket's full entry code above.").font(.caption).foregroundStyle(.secondary)
                }
                if service.isWorking { ProgressView("Checking ticket…") }
                if let result {
                    Label(result == "accepted" ? "Checked In — Admit One" : result == "duplicate" ? "Already Checked In — Do Not Admit Again" : "Invalid Ticket — Do Not Admit",
                          systemImage: result == "accepted" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(result == "accepted" ? Color.green : Color.red)
                    .accessibilityAddTraits(.updatesFrequently)
                }
                if let error = service.errorMessage { Text(error).foregroundStyle(.red) }
            }
            Section("Tickets · \(service.tickets.filter { $0.status == "scanned" }.count) Checked In") {
                if service.isLoading { ProgressView("Loading tickets…") }
                if service.tickets.isEmpty && !service.isLoading { Text("No tickets reserved yet.").foregroundStyle(.secondary) }
                ForEach(service.tickets) { ticket in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ticket.allocationName).font(.headline)
                        Text(ticket.statusText)
                        Text(ticket.id.uuidString).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("Event Check-In").navigationBarTitleDisplayMode(.inline)
        .task { await service.loadTickets(eventID: event.id) }
        .refreshable { await service.loadTickets(eventID: event.id) }
        .sheet(isPresented: $showScanner) {
            NavigationStack {
                TicketScanner { value in
                    showScanner = false
                    entryCode = value
                    Task { await checkIn(value) }
                }
                .navigationTitle("Scan Ticket")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showScanner = false } } }
            }
        }
        .opportunity313PageBackground()
    }
    private func checkIn(_ value: String) async {
        result = nil
        result = await service.checkIn(code: value, eventID: event.id)
        if result != nil { await service.loadTickets(eventID: event.id) }
    }
}

private struct TicketScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced, recognizesMultipleItems: false,
                                                isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        do { try scanner.startScanning() }
        catch { context.coordinator.showError(on: scanner) }
        return scanner
    }
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) { uiViewController.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var completed = false
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !completed else { return }
            for item in addedItems {
                if case let .barcode(barcode) = item, let value = barcode.payloadStringValue, TicketCode.token(from: value) != nil {
                    completed = true; dataScanner.stopScanning(); onScan(value); return
                }
            }
        }
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) { showError(on: dataScanner) }
        func showError(on controller: UIViewController) {
            let label = UILabel()
            label.text = "Camera scanning is unavailable. Close this screen and paste the entry code to check in."
            label.numberOfLines = 0; label.textAlignment = .center; label.backgroundColor = .systemBackground
            label.translatesAutoresizingMaskIntoConstraints = false
            controller.view.addSubview(label)
            NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor, constant: 24), label.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor, constant: -24), label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor)])
        }
    }
}

private struct TicketPersistentHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "ticket.fill")
            Text(title).font(.headline)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .foregroundStyle(.white)
        .background(Opportunity313Brand.heroGradient)
    }
}

