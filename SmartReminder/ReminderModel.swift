import Foundation

// MARK: - Priority
enum Priority: String, Codable, CaseIterable, Sendable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"
}

// MARK: - Reminder
struct Reminder: Identifiable, Codable, Sendable {
    var id: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var isCompleted: Bool
    var priority: Priority
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date = Date().addingTimeInterval(3600),
        isCompleted: Bool = false,
        priority: Priority = .medium,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.priority = priority
        self.createdAt = createdAt
    }
}

extension Reminder: Equatable {
    static func == (lhs: Reminder, rhs: Reminder) -> Bool {
        lhs.id == rhs.id
    }
}
