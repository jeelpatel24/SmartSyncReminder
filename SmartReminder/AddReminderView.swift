import SwiftUI

struct AddReminderView: View {
    @Environment(ReminderStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title    = ""
    @State private var notes    = ""
    @State private var dueDate  = Date().addingTimeInterval(3600)
    @State private var priority: Priority = .medium

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .accessibilityLabel("Reminder title")
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .accessibilityLabel("Reminder notes")
                }

                Section("Schedule") {
                    DatePicker(
                        "Due Date & Time",
                        selection: $dueDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityLabel("Due date and time")
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(Priority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let reminder = Reminder(
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            dueDate: dueDate,
            priority: priority
        )
        store.add(reminder)
        dismiss()
    }
}

#Preview {
    AddReminderView()
        .environment(ReminderStore.shared)
}
