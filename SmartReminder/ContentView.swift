import SwiftUI

struct ContentView: View {
    @Environment(ReminderStore.self) private var store
    @State private var showingAdd = false
    @State private var filter: FilterOption = .upcoming

    enum FilterOption: String, CaseIterable {
        case upcoming  = "Upcoming"
        case completed = "Completed"
        case all       = "All"
    }

    private var displayedReminders: [Reminder] {
        switch filter {
        case .upcoming:  return store.upcoming
        case .completed: return store.completed
        case .all:       return store.reminders.sorted { $0.dueDate < $1.dueDate }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if displayedReminders.isEmpty {
                    emptyState
                } else {
                    reminderList
                }
            }
            .navigationTitle("SmartReminder")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Add Reminder")
                }
            }
            .safeAreaInset(edge: .bottom) {
                filterPicker
            }
            .sheet(isPresented: $showingAdd) {
                AddReminderView()
                    .environment(store)
            }
        }
    }

    // MARK: - Reminder list
    private var reminderList: some View {
        List {
            ForEach(displayedReminders) { reminder in
                NavigationLink(destination:
                    ReminderDetailView(reminder: reminder)
                        .environment(store)
                ) {
                    ReminderRowView(reminder: reminder)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        store.toggleCompleted(reminder)
                    } label: {
                        Label(
                            reminder.isCompleted ? "Reopen" : "Done",
                            systemImage: reminder.isCompleted ? "arrow.uturn.backward" : "checkmark"
                        )
                    }
                    .tint(reminder.isCompleted ? .orange : .green)
                }
            }
            .onDelete(perform: store.delete)
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: displayedReminders.map(\.id))
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: filter == .completed ? "checkmark.circle" : "bell.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(filter == .completed ? "No completed reminders" : "No reminders yet")
                .font(.title3.bold())
            if filter == .upcoming {
                Text("Tap + to create your first reminder.\nIt will sync instantly to your Apple Watch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: - Filter picker
    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(FilterOption.allCases, id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

// MARK: - Row View
struct ReminderRowView: View {
    let reminder: Reminder

    private var priorityColor: Color {
        switch reminder.priority {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(priorityColor)
                .frame(width: 10, height: 10)
                .accessibilityLabel("Priority: \(reminder.priority.rawValue)")

            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.body)
                    .strikethrough(reminder.isCompleted, color: .secondary)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(reminder.dueDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if reminder.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Completed")
            } else if reminder.dueDate < Date() {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Overdue")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .environment(ReminderStore.shared)
}
