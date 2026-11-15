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
    @State private var editorGroups: [TaskGroup]
    @State private var isCreatingGroup = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case title, description }
    private enum GroupChoice: Hashable { case general, existing(UUID), create }

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
                        .focused($focusedField, equals: .title)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                        .accessibilityIdentifier("task.title")
                    Picker("Group", selection: groupChoice) {
                        Text("General").tag(GroupChoice.general)
                        ForEach(editorGroups) { group in
                            Text(group.name).tag(GroupChoice.existing(group.id))
                        }
                        Divider()
                        Label("New group", systemImage: "plus").tag(GroupChoice.create)
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("task.group")
                }
                Section("Description") {
                    TextEditor(text: $description).frame(minHeight: 90)
                        .focused($focusedField, equals: .description)
                        .accessibilityIdentifier("task.description")
                }
                Section("Notifications") {
                    ReminderScheduleFields(reminder: $reminder)
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
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(task == nil ? "New Task" : "Task Details")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        KeyboardDismissButton { focusedField = nil }
                    }
                }
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
        .sheet(isPresented: $isCreatingGroup) {
            NewGroupEditorView(groups: editorGroups) { name in
                guard let group = onCreateGroup(name) else { return false }
                editorGroups.append(group)
                groupID = group.id
                return true
            }
        }
    }

    private var groupChoice: Binding<GroupChoice> {
        Binding(get: {
            if let groupID, editorGroups.contains(where: { $0.id == groupID }) {
                return .existing(groupID)
            }
            return .general
        }, set: { choice in
            focusedField = nil
            switch choice {
            case .general: groupID = nil
            case .existing(let id): groupID = id
            case .create: isCreatingGroup = true
            }
        })
    }

    private var hasChanges: Bool {
        guard let task else { return false }
        return title != task.title || description != task.description || groupID != task.groupID || reminder != task.reminder
    }

}

struct KeyboardDismissButton: View {
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            Image(systemName: "keyboard.chevron.compact.down")
                .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Dismiss keyboard")
        .accessibilityIdentifier("keyboard.dismiss")
    }
}

private struct NewGroupEditorView: View {
    let groups: [TaskGroup]
    let onCreate: (String) -> Bool
    @EnvironmentObject private var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saveError: String?
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDuplicate: Bool {
        groups.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit { isNameFocused = false }
                        .accessibilityIdentifier("group.name")
                } footer: {
                    if isDuplicate { Text("A group with this name already exists.") }
                }
                if let saveError { Section { Text(saveError).foregroundStyle(.red) } }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if onCreate(trimmedName) { dismiss() }
                        else { saveError = taskStore.errorMessage ?? "This group couldn’t be created. Please try again." }
                    }
                    .disabled(trimmedName.isEmpty || isDuplicate)
                    .accessibilityIdentifier("group.create")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if isNameFocused {
                        Spacer()
                        KeyboardDismissButton { isNameFocused = false }
                    }
                }
            }
            .task { isNameFocused = true }
            .onChange(of: name) { _, _ in saveError = nil }
        }
    }
}
