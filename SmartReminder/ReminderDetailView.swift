import SwiftUI

struct ReminderDetailView: View {
    @Environment(ReminderStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var reminder: Reminder
    @State private var isEditing = false

    init(reminder: Reminder) {
        _reminder = State(initialValue: reminder)
    }

    private var priorityColor: Color {
        switch reminder.priority {
        case .low:    return .green
        case .medium: return .orange
        case .high:   return .red
        }
    }

    var body: some View {
        Form {
            if isEditing {
                editingContent
            } else {
                readingContent
            }
        }
        .navigationTitle(isEditing ? "Edit Reminder" : reminder.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing { store.update(reminder) }
                    withAnimation { isEditing.toggle() }
                }
                .fontWeight(isEditing ? .semibold : .regular)
            }
            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let original = store.reminders.first(where: { $0.id == reminder.id }) {
                            reminder = original
                        }
                        withAnimation { isEditing = false }
                    }
                }
            }
        }
    }

    // MARK: - Read mode
    private var readingContent: some View {
        Group {
            Section("Details") {
                LabeledContent("Title", value: reminder.title)
                if !reminder.notes.isEmpty {
                    LabeledContent("Notes", value: reminder.notes)
                }
            }

            Section("Schedule") {
                LabeledContent("Due") {
                    Text(reminder.dueDate.formatted(date: .long, time: .shortened))
                        .foregroundStyle(
                            reminder.dueDate < Date() && !reminder.isCompleted ? .red : .primary
                        )
                }
                LabeledContent("Created", value: reminder.createdAt.formatted(date: .abbreviated, time: .omitted))
            }

            Section("Priority") {
                Label(reminder.priority.rawValue, systemImage: "flag.fill")
                    .foregroundStyle(priorityColor)
            }

            Section("Status") {
                Toggle("Completed", isOn: Binding(
                    get: { reminder.isCompleted },
                    set: { newValue in
                        reminder.isCompleted = newValue
                        store.update(reminder)
                    }
                ))
                .tint(.green)
            }

            Section {
                Button(role: .destructive) {
                    if let index = store.reminders.firstIndex(where: { $0.id == reminder.id }) {
                        store.delete(at: IndexSet([index]))
                    }
                    dismiss()
                } label: {
                    Label("Delete Reminder", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    // MARK: - Edit mode
    private var editingContent: some View {
        Group {
            Section("Details") {
                TextField("Title", text: $reminder.title)
                    .accessibilityLabel("Reminder title")
                TextField("Notes", text: $reminder.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityLabel("Reminder notes")
            }

            Section("Schedule") {
                DatePicker(
                    "Due Date",
                    selection: $reminder.dueDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("Priority") {
                Picker("Priority", selection: $reminder.priority) {
                    ForEach(Priority.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReminderDetailView(
            reminder: Reminder(title: "Sample Reminder", notes: "Some notes here", priority: .high)
        )
        .environment(ReminderStore.shared)
    }
}
