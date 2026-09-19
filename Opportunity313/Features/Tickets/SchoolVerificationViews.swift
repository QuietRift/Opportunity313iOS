import SwiftUI
import UIKit
import AVFoundation
import Vision

struct SchoolProfileCard: View {
    let youthProfileID: UUID
    @StateObject private var service = SchoolVerificationService()
    private var profile: SchoolProfileLink? { service.profiles.first { $0.youthProfileID == youthProfileID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("School", systemImage: "building.2").font(.headline)
            if let profile {
                Text(profile.schoolName ?? "No school linked")
                Text(profile.status == "verified" ? "Verified for student tickets" :
                     profile.status == "pending" ? (profile.photoSubmitted ? "Waiting for school roster review" : "Take a school ID photo") :
                     profile.status == "not_linked" ? "Add a school for student ticket access" :
                     "Verification needed")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else if service.isWorking { ProgressView("Loading school…") }
            NavigationLink(profile?.schoolID == nil ? "Add School" : "View or Change School") {
                SchoolLinkView(youthProfileID: youthProfileID)
            }
            if let error = service.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .task { await service.loadProfiles() }
        .onReceive(NotificationCenter.default.publisher(for: .schoolVerificationDidChange)) { _ in
            Task { await service.loadProfiles() }
        }
    }
}

extension Notification.Name {
    static let schoolVerificationDidChange = Notification.Name("schoolVerificationDidChange")
}

struct SchoolLinkSelectorView: View {
    @StateObject private var service = SchoolVerificationService()
    var body: some View {
        List {
            if service.isWorking && service.profiles.isEmpty { ProgressView("Loading youth profiles…") }
            ForEach(service.profiles) { profile in
                NavigationLink { SchoolLinkView(youthProfileID: profile.youthProfileID) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.youthName).font(.headline)
                        Text(profile.schoolName ?? "No school linked")
                        Text(profile.status == "verified" ? "Verified" : profile.status == "pending" ?
                             (profile.photoSubmitted ? "Waiting for school roster review" : "ID photo needed") : "Not verified")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if service.profiles.isEmpty && !service.isWorking {
                Text("Add a youth profile before requesting school verification.").foregroundStyle(.secondary)
            }
            if let error = service.errorMessage { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Student Schools")
        .task { await service.loadProfiles() }
        .refreshable { await service.loadProfiles() }
        .onReceive(NotificationCenter.default.publisher(for: .schoolVerificationDidChange)) { _ in
            Task { await service.loadProfiles() }
        }
        .opportunity313PageBackground()
    }
}

struct SchoolLinkView: View {
    let youthProfileID: UUID
    @StateObject private var service = SchoolVerificationService()
    @State private var selectedSchool: UUID?
    @State private var showCamera = false
    @State private var image: UIImage?
    private var profile: SchoolProfileLink? { service.profiles.first { $0.youthProfileID == youthProfileID } }

    var body: some View {
        Form {
            Section("Student") {
                Text(profile?.youthName ?? "Youth Profile").font(.headline)
                if let grade = profile?.grade { Text("Grade \(grade)") }
            }
            Section("School") {
                Picker("School", selection: $selectedSchool) {
                    Text("Select a school").tag(nil as UUID?)
                    ForEach(service.schools) { school in
                        Text(school.name).tag(Optional(school.id))
                    }
                }
                if let profile {
                    Label(profile.status == "verified" ? "School verified" :
                          profile.status == "pending" ? (profile.photoSubmitted ? "Waiting for school roster review" : "School ID photo needed") :
                          "School not verified", systemImage: profile.isVerified ? "checkmark.seal.fill" : "clock")
                }
                Button(profile?.status == "verified" && profile?.schoolID == selectedSchool ? "School Verified" : "Select School") {
                    guard let selectedSchool else { return }
                    Task {
                        if await service.request(youthID: youthProfileID, schoolID: selectedSchool) {
                            NotificationCenter.default.post(name: .schoolVerificationDidChange, object: nil)
                        }
                    }
                }
                .disabled(service.isWorking || selectedSchool == nil ||
                          (profile?.status == "verified" && profile?.schoolID == selectedSchool) ||
                          (profile?.status == "pending" && profile?.schoolID == selectedSchool))
                if profile?.status == "pending" && profile?.schoolID == selectedSchool && profile?.photoSubmitted == false {
                    Button("Take School ID Photo") {
                        Task {
                            let granted = await AVCaptureDevice.requestAccess(for: .video)
                            if granted && UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
                            else { service.errorMessage = "Camera unavailable. Please try on a device with a camera." }
                        }
                    }
                    .disabled(service.isWorking)
                }
                Text("Take one photo of the student's school ID to send a request to that school's admin. The school checks the student against its roster. The photo is checked on this device, then cleared; it is not uploaded or saved. Once the school approves, future student tickets do not need another photo.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let notice = service.notice { Section { Text(notice).foregroundStyle(.green) } }
            if let error = service.errorMessage { Section { Text(error).foregroundStyle(.red) } }
        }
        .navigationTitle("Student School")
        .task {
            await service.loadProfiles()
            await service.loadSchools()
            selectedSchool = profile?.schoolID
        }
        .refreshable { await service.loadProfiles(); await service.loadSchools() }
        .sheet(isPresented: $showCamera, onDismiss: readCapturedID) { SchoolIDCamera(image: $image) }
        .onDisappear { image = nil }
        .opportunity313PageBackground()
    }

    private func readCapturedID() {
        guard let captured = image else { return }
        image = nil
        guard let schoolID = selectedSchool, let cgImage = captured.cgImage else {
            service.errorMessage = "Could not read that photo. Please try again."
            return
        }
        do {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: cgImage).perform([request])
            guard (request.results ?? []).contains(where: { $0.topCandidates(1).first != nil }) else {
                service.errorMessage = "Could not read the school ID. Retake the photo with the card in focus."
                return
            }
            Task {
                if await service.submitIDPhotoRequest(youthID: youthProfileID, schoolID: schoolID) {
                    NotificationCenter.default.post(name: .schoolVerificationDidChange, object: nil)
                }
            }
        } catch {
            service.errorMessage = "Could not read the school ID. Please try again."
        }
    }
}

struct SchoolVerificationQueueView: View {
    @ObservedObject var service: SchoolVerificationService
    private var pending: [SchoolVerificationRequest] { service.queue.filter { $0.status == "pending" } }
    private var verified: [SchoolVerificationRequest] { service.queue.filter { $0.status == "verified" } }
    var body: some View {
        NavigationStack {
            List {
                Section("New School Requests") {
                    if pending.isEmpty && !service.isWorking { Text("No students are waiting for verification.").foregroundStyle(.secondary) }
                    ForEach(pending) { request in
                        NavigationLink { SchoolVerificationReviewView(request: request, service: service) } label: { requestRow(request) }
                    }
                }
                Section("Verified Students") {
                    ForEach(verified) { request in
                        NavigationLink { SchoolVerificationReviewView(request: request, service: service) } label: { requestRow(request) }
                    }
                }
                Text("A student has taken a school ID photo on their device and requested school access. Compare their name and grade with your school's roster before approving. The ID photo is not uploaded or saved.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let error = service.errorMessage { Text(error).foregroundStyle(.red) }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("School Requests")
            .task { await service.loadQueue() }
            .refreshable { await service.loadQueue() }
            .opportunity313PageBackground()
        }
    }
    private func requestRow(_ request: SchoolVerificationRequest) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(request.youthName).font(.headline)
            Text(request.schoolName)
            if let grade = request.grade { Text("Grade \(grade)").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

private struct SchoolVerificationReviewView: View {
    let request: SchoolVerificationRequest
    @ObservedObject var service: SchoolVerificationService
    @Environment(\.dismiss) private var dismiss
    @State private var rosterChecked = false
    var body: some View {
        Form {
            Section("Student and School") {
                Text(request.youthName).font(.title3.bold())
                Text(request.schoolName)
                if let grade = request.grade { Text("Grade \(grade)") }
                Text(request.status == "verified" ? "Verified" : "Pending verification")
            }
            if request.status == "pending" {
                Section("School Roster Check") {
                    Text("Look up this student in your school's roster. Confirm their name and grade belong to the selected school before approval. The student's ID photo is not shared with this screen.")
                    Toggle("I found this student in the school roster", isOn: $rosterChecked)
                    Button("Approve School") {
                        Task { if await service.review(requestID: request.id, approve: true, rosterChecked: rosterChecked) { dismiss() } }
                    }
                    .disabled(!rosterChecked || service.isWorking)
                    Button("Reject Request", role: .destructive) {
                        Task { if await service.review(requestID: request.id, approve: false, rosterChecked: false) { dismiss() } }
                    }
                    .disabled(service.isWorking)
                }
            } else if request.status == "verified" {
                Section {
                    Button("Remove School Verification", role: .destructive) {
                        Task { if await service.review(requestID: request.id, approve: false, rosterChecked: false) { dismiss() } }
                    }
                    .disabled(service.isWorking)
                }
            }
            if let error = service.errorMessage { Section { Text(error).foregroundStyle(.red) } }
        }
        .navigationTitle("Roster Review")
        .onDisappear { rosterChecked = false }
        .opportunity313PageBackground()
    }
}

private struct SchoolIDCamera: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SchoolIDCamera
        init(_ parent: SchoolIDCamera) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
