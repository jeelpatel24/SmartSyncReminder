import SwiftUI

// MARK: - Main Watch List
struct WatchContentView: View {
    @Environment(WatchReminderStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                if store.upcomingReminders.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No reminders.\nAdd from iPhone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.upcomingReminders) { reminder in
                        NavigationLink(destination: WatchDetailView(reminder: reminder)) {
                            WatchReminderRow(reminder: reminder)
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
        }
    }
}

// MARK: - Row
struct WatchReminderRow: View {
    let reminder: Reminder

    private var priorityColor: Color {
        switch reminder.priority {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
                .accessibilityLabel("Priority: \(reminder.priority.rawValue)")

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(reminder.dueDate, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Detail
struct WatchDetailView: View {
    @Environment(WatchReminderStore.self) private var store
    let reminder: Reminder

    // Always read live state from store
    private var current: Reminder {
        store.reminders.first(where: { $0.id == reminder.id }) ?? reminder
    }

    private var priorityColor: Color {
        switch current.priority {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(current.title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if !current.notes.isEmpty {
                    Text(current.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Label(current.dueDate.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "clock")
                    .font(.footnote)
                    .accessibilityLabel("Due: \(current.dueDate.formatted(date: .abbreviated, time: .shortened))")

                Label(current.priority.rawValue, systemImage: "flag.fill")
                    .font(.footnote)
                    .foregroundStyle(priorityColor)

                Divider()

                Button {
                    store.toggleCompleted(current)
                } label: {
                    Label(
                        current.isCompleted ? "Reopen" : "Mark Done",
                        systemImage: current.isCompleted
                            ? "arrow.uturn.backward.circle"
                            : "checkmark.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(current.isCompleted ? .orange : .green)
                .accessibilityLabel(current.isCompleted ? "Mark as incomplete" : "Mark as complete")
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    WatchContentView()
        .environment(WatchReminderStore.shared)
}
