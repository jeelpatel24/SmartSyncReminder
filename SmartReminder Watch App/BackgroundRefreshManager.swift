import WatchKit
import ClockKit

/// Manages WatchOS background refresh tasks.
/// Schedules periodic wakes every 30 minutes to reload complication timelines.
/// watchOS may defer or skip refreshes — this is expected and battery-friendly.
final class BackgroundRefreshManager: NSObject, Sendable {
    static let shared = BackgroundRefreshManager()

    private override init() { super.init() }

    // MARK: - Schedule next background refresh (30 min)
    func scheduleBackgroundRefresh() {
        let fireDate = Date().addingTimeInterval(30 * 60)
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: fireDate,
            userInfo: nil
        ) { error in
            // System may reject or adjust the date — both are acceptable
            if let error { print("[BG] Schedule failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Handle all background task types
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                // Reload complications then reschedule
                reloadComplications()
                scheduleBackgroundRefresh()
                refreshTask.setTaskCompletedWithSnapshot(false)

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: .distantFuture,
                    userInfo: nil
                )

            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                connectivityTask.setTaskCompletedWithSnapshot(false)

            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                urlSessionTask.setTaskCompletedWithSnapshot(false)

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    // MARK: - Reload all active complications
    private func reloadComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
    }
}
