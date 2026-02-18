import SwiftUI
import WatchKit

@main
struct SmartReminder_Watch_AppApp: App {
    // @Observable store works with @State in Swift 5.9+ / Xcode 15+
    @State private var store = WatchReminderStore.shared
    private let bgManager = BackgroundRefreshManager.shared

    @SceneBuilder var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(store)
        }
        WKNotificationScene(controller: NotificationController.self, category: "reminder")
    }

    init() {
        DispatchQueue.main.async { [bgManager] in
            bgManager.scheduleBackgroundRefresh()
        }
    }
}

// MARK: - Notification UI shown on Apple Watch
final class NotificationController: WKUserNotificationHostingController<NotificationView> {
    override var body: NotificationView { NotificationView() }
}

struct NotificationView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("Reminder Due")
                .font(.headline)
        }
    }
}
