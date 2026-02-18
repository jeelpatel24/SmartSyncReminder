import SwiftUI

@main
struct SmartReminderApp: App {
    @State private var store = ReminderStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .onAppear {
                    store.requestNotificationPermission()
                }
        }
    }
}
