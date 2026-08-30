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
    var description: String
    var groupID: UUID?
    var isCompleted: Bool
    var reminder: ReminderSettings

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        groupID: UUID? = nil,
        isCompleted: Bool = false,
        reminder: ReminderSettings = ReminderSettings()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.groupID = groupID
        self.isCompleted = isCompleted
        self.reminder = reminder
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, groupID, isCompleted, reminder
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        description = try values.decodeIfPresent(String.self, forKey: .description) ?? ""
        groupID = try values.decodeIfPresent(UUID.self, forKey: .groupID)
        isCompleted = try values.decode(Bool.self, forKey: .isCompleted)
        reminder = try values.decode(ReminderSettings.self, forKey: .reminder)
    }
}

struct TaskGroup: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct TaskSection: Identifiable {
    let group: TaskGroup?
    let tasks: [TaskItem]

    var id: UUID? { group?.id }
    var title: String { group?.name ?? "General" }
}

struct PlanningData: Codable {
    var version: Int = 2
    var tasks: [TaskItem]
    var groups: [TaskGroup]
}
