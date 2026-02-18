import Foundation
import SwiftUI
import Observation
import WatchConnectivity
import UserNotifications

// MARK: - ReminderStore (iOS)
// @Observable avoids the @MainActor + NSObject + WCSessionDelegate conformance conflict
// present in Swift 6 strict-concurrency mode (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor).
// WCSession bridging lives in the separate iOSSessionManager class below.
@Observable
@MainActor
final class ReminderStore {
    static let shared = ReminderStore()

    var reminders: [Reminder] = []

    private let saveKey = "SmartSyncReminder.reminders"
    private var sessionManager: iOSSessionManager?

    init() {
        load()
        let manager = iOSSessionManager { [weak self] updated in
            Task { @MainActor [weak self] in
                self?.reminders = updated
                self?.save()
            }
        }
        self.sessionManager = manager
    }

    // MARK: - Persistence
    func save() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data)
        else { return }
        reminders = decoded
    }

    // MARK: - CRUD
    func add(_ reminder: Reminder) {
        reminders.append(reminder)
        save()
        syncToWatch()
        scheduleNotification(for: reminder)
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        save()
        syncToWatch()
        cancelNotification(for: reminder)
        if !reminder.isCompleted { scheduleNotification(for: reminder) }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets { cancelNotification(for: reminders[index]) }
        reminders.remove(atOffsets: offsets)
        save()
        syncToWatch()
    }

    func toggleCompleted(_ reminder: Reminder) {
        var updated = reminder
        updated.isCompleted.toggle()
        update(updated)
    }

    // MARK: - Computed
    var upcoming: [Reminder] {
        reminders.filter { !$0.isCompleted && $0.dueDate > Date() }
                 .sorted { $0.dueDate < $1.dueDate }
    }

    var completed: [Reminder] {
        reminders.filter { $0.isCompleted }
                 .sorted { $0.dueDate > $1.dueDate }
    }

    // MARK: - Notifications
    func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotification(for reminder: Reminder) {
        guard reminder.dueDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.notes.isEmpty ? "Your reminder is due." : reminder.notes
        content.sound = .default
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: reminder.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
    }

    // MARK: - Sync to Watch
    func syncToWatch() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        sessionManager?.sync(data: data)
    }
}

// MARK: - iOSSessionManager (non-isolated WCSessionDelegate wrapper)
// Plain NSObject, NOT @MainActor, so WCSessionDelegate methods can be
// called freely from WatchConnectivity's background threads.
final class iOSSessionManager: NSObject, WCSessionDelegate {
    private let onReceive: ([Reminder]) -> Void

    init(onReceive: @escaping ([Reminder]) -> Void) {
        self.onReceive = onReceive
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sync(data: Data) {
        let b64 = data.base64EncodedString()
        print("[WC][iOS] sync called — paired:\(WCSession.default.isPaired) installed:\(WCSession.default.isWatchAppInstalled) activation:\(WCSession.default.activationState.rawValue) size:\(b64.count) bytes")

        // Try to update application context (small latest-state). Use base64 string to avoid plist encoding issues.
        do {
            try WCSession.default.updateApplicationContext(["reminders": b64])
            print("[WC][iOS] updateApplicationContext succeeded (\(b64.count) bytes)")
        } catch {
            print("[WC][iOS] updateApplicationContext failed: \(error.localizedDescription)")
        }

        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["reminders": b64], replyHandler: nil) { error in
                print("[WC][iOS] sendMessage error: \(error.localizedDescription) — falling back to transferUserInfo")
                WCSession.default.transferUserInfo(["reminders": b64])
            }
        } else {
            WCSession.default.transferUserInfo(["reminders": b64])
        }
    }

    // Support incoming message requests that ask for the current reminders (replyHandler)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        if let request = message["request"] as? String, request == "reminders" {
            if let data = UserDefaults.standard.data(forKey: "SmartSyncReminder.reminders") {
                let b64 = data.base64EncodedString()
                replyHandler(["reminders": b64])
            } else {
                replyHandler([:])
            }
            return
        }
        handle(message)
    }

    // MARK: WCSessionDelegate
    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        if state == .activated {
            // Re-sync after activation so Watch has latest data
            if let data = UserDefaults.standard.data(forKey: "SmartSyncReminder.reminders") {
                sync(data: data)
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext context: [String: Any]) {
        handle(context)
    }

    private func handle(_ payload: [String: Any]) {
        // Accept either base64 String or raw Data for backwards compatibility.
        if let b64 = payload["reminders"] as? String {
            if let data = Data(base64Encoded: b64), let updated = try? JSONDecoder().decode([Reminder].self, from: data) {
                onReceive(updated)
            } else {
                print("[WC][iOS] Failed to decode base64 applicationContext payload")
            }
            return
        }

        if let data = payload["reminders"] as? Data, let updated = try? JSONDecoder().decode([Reminder].self, from: data) {
            onReceive(updated)
            return
        }

        print("[WC][iOS] received reminders payload but it was empty or unrecognized type")
    }
}
