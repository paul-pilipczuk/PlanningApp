import Foundation

enum ReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

struct ReminderSettings: Codable, Equatable {
    var isEnabled = false
    var frequency: ReminderFrequency = .daily
    var hour = Calendar.current.component(.hour, from: Date())
    var minute = Calendar.current.component(.minute, from: Date())
    var weekday = Calendar.current.component(.weekday, from: Date())
    var repeatsUntilCompleted = true

    var time: Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }

    mutating func setTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        hour = components.hour ?? Calendar.current.component(.hour, from: Date())
        minute = components.minute ?? Calendar.current.component(.minute, from: Date())
    }
}

struct TaskItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var reminder: ReminderSettings

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        reminder: ReminderSettings = ReminderSettings()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.reminder = reminder
    }
}
