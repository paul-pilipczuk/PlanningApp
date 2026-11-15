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
    var archivedAt: Date?
    var progressMarkerID: UUID?

    var isArchived: Bool { archivedAt != nil }

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        groupID: UUID? = nil,
        isCompleted: Bool = false,
        reminder: ReminderSettings = ReminderSettings(),
        archivedAt: Date? = nil,
        progressMarkerID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.groupID = groupID
        self.isCompleted = isCompleted
        self.reminder = reminder
        self.archivedAt = archivedAt
        self.progressMarkerID = progressMarkerID
    }

    /// A copy is a new active draft; preparing it has no persistence or reminder effects.
    func newTaskDraft(in groups: [TaskGroup]) -> TaskItem {
        TaskItem(title: title, description: description,
                 groupID: groups.contains(where: { $0.id == groupID }) ? groupID : nil,
                 reminder: reminder)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, groupID, isCompleted, reminder, archivedAt, progressMarkerID
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        description = try values.decodeIfPresent(String.self, forKey: .description) ?? ""
        groupID = try values.decodeIfPresent(UUID.self, forKey: .groupID)
        isCompleted = try values.decode(Bool.self, forKey: .isCompleted)
        reminder = try values.decode(ReminderSettings.self, forKey: .reminder)
        archivedAt = try values.decodeIfPresent(Date.self, forKey: .archivedAt)
        progressMarkerID = try values.decodeIfPresent(UUID.self, forKey: .progressMarkerID)
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
    var progressSections: [TaskProgressSection] = []
    var progressRows: [TaskProgressRow] = []

    var id: UUID? { group?.id }
    var title: String { group?.name ?? "General" }
}

/// One stable identity domain keeps a dragged row alive when its label changes.
enum TaskProgressRow: Identifiable {
    case header(ProgressMarker, isEmpty: Bool)
    case task(TaskItem)

    enum ID: Hashable { case header(UUID), task(UUID) }
    var id: ID {
        switch self {
        case .header(let marker, _): .header(marker.id)
        case .task(let task): .task(task.id)
        }
    }
}

struct TaskProgressSection: Identifiable {
    let marker: ProgressMarker
    let tasks: [TaskItem]
    var id: UUID { marker.id }
}

struct PlanningData: Codable {
    var version: Int = 4
    var tasks: [TaskItem]
    var groups: [TaskGroup]
    var progressConfiguration = ProgressConfiguration()

    private enum CodingKeys: String, CodingKey { case version, tasks, groups, progressConfiguration }

    init(version: Int = 4, tasks: [TaskItem], groups: [TaskGroup], progressConfiguration: ProgressConfiguration = ProgressConfiguration()) {
        self.version = version
        self.tasks = tasks
        self.groups = groups
        self.progressConfiguration = progressConfiguration
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        tasks = try values.decode([TaskItem].self, forKey: .tasks)
        groups = try values.decode([TaskGroup].self, forKey: .groups)
        let progress = try values.decodeIfPresent(ProgressConfiguration.self, forKey: .progressConfiguration)
        if version == 4 && progress == nil {
            throw DecodingError.dataCorruptedError(forKey: .progressConfiguration, in: values,
                                                  debugDescription: "Progress configuration is missing.")
        }
        progressConfiguration = progress ?? ProgressConfiguration()
    }
}
