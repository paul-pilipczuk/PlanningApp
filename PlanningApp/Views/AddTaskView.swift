import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem?
    let groups: [TaskGroup]
    let onSave: (String, String, UUID?, ReminderSettings) -> Void
    let onCreateGroup: (String) -> TaskGroup?
    let onRequestDelete: (() -> Void)?

    @State private var title: String
    @State private var description: String
    @State private var groupID: UUID?
    @State private var reminder: ReminderSettings
    @State private var newGroupName = ""
    @State private var editorGroups: [TaskGroup]

    init(task: TaskItem? = nil, groups: [TaskGroup], onSave: @escaping (String, String, UUID?, ReminderSettings) -> Void, onCreateGroup: @escaping (String) -> TaskGroup?, onRequestDelete: (() -> Void)? = nil) {
        self.task = task
        self.groups = groups
        self.onSave = onSave
        self.onCreateGroup = onCreateGroup
        self.onRequestDelete = onRequestDelete
        _title = State(initialValue: task?.title ?? "")
        _description = State(initialValue: task?.description ?? "")
        _groupID = State(initialValue: task?.groupID)
        _reminder = State(initialValue: task?.reminder ?? ReminderSettings())
        _editorGroups = State(initialValue: groups)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                    Picker("Group", selection: $groupID) {
                        Text("General").tag(UUID?.none)
                        ForEach(editorGroups) { group in Text(group.name).tag(Optional(group.id)) }
                    }
                    HStack {
                        TextField("New group", text: $newGroupName)
                        Button("Create") {
                            if let group = onCreateGroup(newGroupName) {
                                editorGroups.append(group)
                                groupID = group.id
                                newGroupName = ""
                            }
                        }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Section("Description") {
                    TextEditor(text: $description).frame(minHeight: 90)
                }
                Section("Notifications") {
                    Toggle("Notifications", isOn: $reminder.isEnabled)
                    if reminder.isEnabled {
                        Picker("Frequency", selection: $reminder.frequency) {
                            ForEach(ReminderFrequency.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        DatePicker("Time", selection: Binding(get: { reminder.time }, set: { reminder.setTime($0) }), displayedComponents: .hourAndMinute)
                        Toggle("Repeat until done", isOn: $reminder.repeatsUntilCompleted)
                    }
                }
                if task != nil {
                    Section {
                        Button("Delete Task", role: .destructive) {
                            dismiss()
                            onRequestDelete?()
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Task Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil ? "Add" : "Save") {
                        onSave(title, description, groupID, reminder)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
