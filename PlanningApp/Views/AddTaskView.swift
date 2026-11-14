import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var taskStore: TaskStore
    let task: TaskItem?
    let groups: [TaskGroup]
    let onSave: (String, String, UUID?, ReminderSettings) -> Bool
    let onCreateGroup: (String) -> TaskGroup?
    let onRequestDelete: (() -> Void)?
    let onArchive: (() -> Bool)?
    let onRequestCopy: (() -> Void)?

    @State private var title: String
    @State private var description: String
    @State private var groupID: UUID?
    @State private var reminder: ReminderSettings
    @State private var newGroupName = ""
    @State private var editorGroups: [TaskGroup]

    init(task: TaskItem? = nil, draft: TaskItem? = nil, groups: [TaskGroup], onSave: @escaping (String, String, UUID?, ReminderSettings) -> Bool, onCreateGroup: @escaping (String) -> TaskGroup?, onRequestDelete: (() -> Void)? = nil, onArchive: (() -> Bool)? = nil, onRequestCopy: (() -> Void)? = nil) {
        self.task = task
        self.groups = groups
        self.onSave = onSave
        self.onCreateGroup = onCreateGroup
        self.onRequestDelete = onRequestDelete
        self.onArchive = onArchive
        self.onRequestCopy = onRequestCopy
        let initial = task ?? draft
        _title = State(initialValue: initial?.title ?? "")
        _description = State(initialValue: initial?.description ?? "")
        _groupID = State(initialValue: initial?.groupID)
        _reminder = State(initialValue: initial?.reminder ?? ReminderSettings())
        _editorGroups = State(initialValue: groups)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("task.title")
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
                        .accessibilityIdentifier("task.description")
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
                        if let onArchive {
                            Button("Archive", systemImage: "archivebox") {
                                if onArchive() { dismiss() }
                            }
                            .disabled(hasChanges)
                        }
                        if let onRequestCopy {
                            Button("Copy", systemImage: "doc.on.doc") {
                                onRequestCopy()
                                dismiss()
                            }
                            .disabled(hasChanges)
                        }
                        Button("Delete", role: .destructive) {
                            onRequestDelete?()
                            dismiss()
                        }
                        .disabled(hasChanges)
                    } footer: {
                        if hasChanges { Text("Save or cancel your edits before copying, archiving, or removing this task.") }
                    }
                }
                if let error = taskStore.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle(task == nil ? "New Task" : "Task Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil ? "Add" : "Save") {
                        if onSave(title, description, groupID, reminder) { dismiss() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("task.save")
                }
            }
        }
    }

    private var hasChanges: Bool {
        guard let task else { return false }
        return title != task.title || description != task.description || groupID != task.groupID || reminder != task.reminder
    }

}
