import Foundation
import Observation
import WatchConnectivity
import UserNotifications
import ClockKit

// MARK: - WatchReminderStore
// Uses @Observable (Swift 5.9+) which is compatible with Swift 6 strict concurrency.
// WCSession bridging is handled by a separate WatchSessionManager to avoid
// the MainActor / WCSessionDelegate conformance conflict.
@Observable
@MainActor
final class WatchReminderStore {
    static let shared = WatchReminderStore()

    var reminders: [Reminder] = []

    private let saveKey = "SmartSyncReminder.watch.reminders"
    private var sessionManager: WatchSessionManager?

    init() {
        load()
        requestNotificationPermission()
        let manager = WatchSessionManager { [weak self] updated in
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
        reloadComplications()
        scheduleAllNotifications()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([Reminder].self, from: data)
        else { return }
        reminders = decoded
    }

    // MARK: - Actions
    func toggleCompleted(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index].isCompleted.toggle()
        save()
        sendToPhone()
    }

    // MARK: - Computed
    var upcomingReminders: [Reminder] {
        reminders
            .filter { !$0.isCompleted && $0.dueDate > Date() }
            .sorted { $0.dueDate < $1.dueDate }
    }
    var nextReminder: Reminder? { upcomingReminders.first }
    var pendingCount: Int { upcomingReminders.count }

    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func scheduleAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for reminder in upcomingReminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.notes.isEmpty ? "Reminder due now!" : reminder.notes
            content.sound = .default
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: reminder.dueDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminder.id.uuidString, content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - Complications
    private func reloadComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
    }

    // MARK: - Send updates back to iPhone
    private func sendToPhone() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        sessionManager?.send(data: data)
    }
}

// MARK: - WatchSessionManager (non-isolated WCSessionDelegate wrapper)
// Kept separate from WatchReminderStore so WCSessionDelegate methods
// (called on arbitrary threads by WatchConnectivity) don't conflict
// with @MainActor/@Observable on the store.
final class WatchSessionManager: NSObject, WCSessionDelegate {
    private let onReceive: ([Reminder]) -> Void

    init(onReceive: @escaping ([Reminder]) -> Void) {
        self.onReceive = onReceive
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()

        // After activation completes the delegate will call requestReminders,
        // but also attempt a lightweight request shortly after init in case
        // activation completed synchronously.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.requestRemindersFromPhone()
        }
    }

    func send(data: Data) {
        guard WCSession.default.activationState == .activated else { return }
        let b64 = data.base64EncodedString()
        print("[WC][Watch] send called — reachable:\(WCSession.default.isReachable) activated:\(WCSession.default.activationState.rawValue) size:\(b64.count) bytes")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["reminders": b64], replyHandler: nil) { error in
                print("[WC][Watch] sendMessage error: \(error.localizedDescription) — falling back to transferUserInfo")
                WCSession.default.transferUserInfo(["reminders": b64])
            }
        } else {
            WCSession.default.transferUserInfo(["reminders": b64])
        }
    }

    // MARK: WCSessionDelegate
    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        // When activated, proactively request the current reminders from the phone
        // isPaired and isWatchAppInstalled are unavailable on watchOS — avoid referencing them here.
        print("[WC][Watch] activationDidCompleteWith state=\(state.rawValue) reachable=\(WCSession.default.isReachable)")
        if state == .activated {
            requestRemindersFromPhone()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    // Support message replies from phone when we ask for reminders
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handle(message)
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext context: [String: Any]) {
        handle(context)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        // If the phone becomes reachable, request an immediate sync
        if session.isReachable {
            requestRemindersFromPhone()
        }
    }

    private func requestRemindersFromPhone() {
        // Try an on-demand message request if the phone is reachable
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["request": "reminders"], replyHandler: { [weak self] reply in
                guard let self = self else { return }
                // Accept either base64 String or Data
                if let b64 = reply["reminders"] as? String, let data = Data(base64Encoded: b64), let updated = try? JSONDecoder().decode([Reminder].self, from: data) {
                    print("[WC][Watch] received reply with b64 data (\(b64.count) bytes)")
                    self.onReceive(updated)
                    return
                }
                if let data = reply["reminders"] as? Data, let updated = try? JSONDecoder().decode([Reminder].self, from: data) {
                    print("[WC][Watch] received reply with Data (\(data.count) bytes)")
                    self.onReceive(updated)
                    return
                }
                print("[WC][Watch] reply did not contain reminders payload or failed to decode")
            }, errorHandler: { [weak self] error in
                // Fallback: if the immediate message fails, try to use the last received application context
                print("[WC] requestRemindersFromPhone sendMessage error: \(error.localizedDescription)")
                self?.useReceivedApplicationContextIfAvailable()
            })
        } else {
            // Not reachable — try to use applicationContext which may already contain the latest state
            useReceivedApplicationContextIfAvailable()
        }
    }

    private func useReceivedApplicationContextIfAvailable() {
        let ctx = WCSession.default.receivedApplicationContext
        if let b64 = ctx["reminders"] as? String {
            if let data = Data(base64Encoded: b64), let updated = try? JSONDecoder().decode([Reminder].self, from: data) {
                print("[WC][Watch] used receivedApplicationContext b64 (\(b64.count) bytes)")
                onReceive(updated)
            } else {
                print("[WC][Watch] receivedApplicationContext b64 failed to decode")
            }
            return
        }

        guard let data = ctx["reminders"] as? Data, let updated = try? JSONDecoder().decode([Reminder].self, from: data) else {
            print("[WC][Watch] Application context data is nil or not recognized")
            return
        }
        print("[WC][Watch] used receivedApplicationContext Data (\(data.count) bytes)")
        onReceive(updated)
    }

    private func handle(_ payload: [String: Any]) {
        // Accept base64 string or raw Data
        if let b64 = payload["reminders"] as? String {
            if let data = Data(base64Encoded: b64), let updated = try? JSONDecoder().decode([Reminder].self, from: data) {
                onReceive(updated)
                return
            } else {
                print("[WC][Watch] Failed to decode base64 payload")
                return
            }
        }
        if let data = payload["reminders"] as? Data, let updated = try? JSONDecoder().decode([Reminder].self, from: data) {
            onReceive(updated)
            return
        }
        print("[WC][Watch] received reminders payload but it was empty or unrecognized type")
    }
}
