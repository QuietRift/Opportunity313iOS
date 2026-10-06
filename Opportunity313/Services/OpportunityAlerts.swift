import SwiftUI
import Combine
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import Supabase

@MainActor
final class OpportunityAlerts: NSObject, ObservableObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = OpportunityAlerts()
    static let topic = "published_opportunities"
    @Published private(set) var configured = false
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "opportunity313.alertsEnabled")
    @Published private(set) var busy = false
    @Published private(set) var message = "Phone alerts are being set up. You can browse approved opportunities in Discover."
    private var connected = false
    @Published var openedOpportunityID: UUID?

    func configure() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        configured = true
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        Task { await refresh() }
    }

    func refresh() async {
        guard configured else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        message = !allowed ? "Allow notifications in iPhone Settings to receive alerts." : enabled ? (connected ? "You’ll receive alerts when new opportunities are approved." : "Connecting alerts…") : "Choose Enable alerts to hear about new approved opportunities."
        if allowed && enabled { UIApplication.shared.registerForRemoteNotifications() }
    }

    func enable() async {
        guard configured, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) else {
                message = "Allow notifications in iPhone Settings to receive alerts."
                return
            }
            // Subscribe after APNs registration and an FCM token arrive.
            enabled = true
            UserDefaults.standard.set(true, forKey: "opportunity313.alertsEnabled")
            Messaging.messaging().isAutoInitEnabled = true
            message = "Connecting alerts…"
            UIApplication.shared.registerForRemoteNotifications()
            if Messaging.messaging().apnsToken != nil { subscribe() }
        } catch { message = "Couldn’t enable alerts. Please try again." }
    }

    func disable() async {
        guard configured, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await Messaging.messaging().unsubscribe(fromTopic: Self.topic)
            enabled = false
            connected = false
            UserDefaults.standard.set(false, forKey: "opportunity313.alertsEnabled")
            Messaging.messaging().isAutoInitEnabled = false
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            message = "Alerts are off. You can still browse all approved opportunities."
        } catch { message = "Couldn’t turn off alerts. Try again, or turn them off in iPhone Settings." }
    }

    func registrationFailed() {
        enabled = false
        connected = false
        UserDefaults.standard.set(false, forKey: "opportunity313.alertsEnabled")
        message = "Couldn’t register this iPhone for alerts. Tap Enable alerts to retry."
    }

    func registered(token: Data) {
        guard configured else { return }
        Messaging.messaging().apnsToken = token
        if enabled { subscribe() }
    }

    private func subscribe() {
        guard enabled, configured, Messaging.messaging().apnsToken != nil else { return }
        Messaging.messaging().subscribe(toTopic: Self.topic) { error in
            Task { @MainActor in
                self.connected = error == nil
                self.message = error == nil ? "Alerts enabled for new approved opportunities." : "Couldn’t connect alerts. Tap Enable alerts to retry."
                if error != nil { self.enabled = false; UserDefaults.standard.set(false, forKey: "opportunity313.alertsEnabled") }
            }
        }
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in self.subscribe() }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await MainActor.run { self.enabled ? [.banner, .sound] : [] }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["opportunity_id"] as? String, let id = UUID(uuidString: raw) else { return }
        await MainActor.run { self.openedOpportunityID = id }
    }
}

final class OpportunityAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        OpportunityAlerts.shared.configure()
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) { OpportunityAlerts.shared.registered(token: deviceToken) }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        OpportunityAlerts.shared.registrationFailed()
    }
}

struct OpportunityAlertsView: View {
    @ObservedObject private var alerts = OpportunityAlerts.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Form {
            Section("New opportunity alerts") {
                Text("Receive a phone notification when an administrator approves a new opportunity.")
                Text(alerts.message).foregroundStyle(.secondary)
                if alerts.configured {
                    Button(alerts.enabled ? "Turn off alerts" : "Enable alerts") { Task { if alerts.enabled { await alerts.disable() } else { await alerts.enable() } } }.disabled(alerts.busy)
                    Button("Open iPhone Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                }
            }
        }
        .navigationTitle("Notifications")
        .task { await alerts.refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await alerts.refresh() } } }
    }
}

struct NotificationOpportunityView: View {
    let id: UUID
    @State private var opportunity: Opportunity?
    @State private var loading = true
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let opportunity { OpportunityDetailView(opportunity: opportunity) }
                else if loading { ProgressView("Loading opportunity…") }
                else { ContentUnavailableView("Opportunity unavailable", systemImage: "calendar.badge.exclamationmark", description: Text("It may no longer be accepting registrations. Browse Discover for current opportunities.")) }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                defer { loading = false }
                opportunity = try? await SupabaseManager.shared.client.from("opportunities").select().eq("id", value: id.uuidString).eq("status", value: "published").single().execute().value
            }
        }
    }
}
