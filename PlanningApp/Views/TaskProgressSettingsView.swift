import SwiftUI

/// Draft editing keeps label removal/reordering reversible until one atomic save.
struct TaskProgressSettingsView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProgressConfiguration
    @State private var editingLabel: ProgressMarker?
    @State private var isAddingLabel = false
    @State private var editMode: EditMode = .inactive
    private let original: ProgressConfiguration

    init(configuration: ProgressConfiguration) {
        original = configuration
        _draft = State(initialValue: configuration)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(draft.markers) { marker in
                        Group {
                            if editMode.isEditing {
                                Text(marker.label).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            } else {
                                Button { editingLabel = marker } label: {
                                    Text(marker.label)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Edit \(marker.label)")
                            }
                        }
                        .deleteDisabled(draft.markers.count == 1)
                        .accessibilityIdentifier("progress.label.\(marker.id)")
                        .accessibilityActions {
                            Button("Move up") { move(marker, by: -1) }
                            Button("Move down") { move(marker, by: 1) }
                            if draft.markers.count > 1 {
                                Button("Remove label") { draft.markers.removeAll { $0.id == marker.id } }
                            }
                        }
                    }
                    .onDelete { offsets in
                        guard draft.markers.count > offsets.count else { return }
                        draft.markers.remove(atOffsets: offsets)
                    }
                    .onMove { draft.markers.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    HStack { Text("Labels"); Spacer(); EditButton() }.textCase(nil)
                } footer: {
                    Text("Tap a label to rename it. Edit to reorder or remove labels. The first label starts new tasks. Removed labels move their tasks to the first remaining label when saved. Keep at least one label.")
                }
                Section {
                    Button("Add label", systemImage: "plus") { isAddingLabel = true }
                        .accessibilityIdentifier("progress.addLabel")
                }
                if let error = taskStore.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Progress labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if taskStore.updateProgressConfiguration(draft) { dismiss() }
                    }
                    .disabled(!draft.isValid || draft == original)
                    .accessibilityIdentifier("progress.saveLabels")
                }
            }
        }
        .sheet(item: $editingLabel) { marker in
            ProgressLabelEditor(marker: marker, labels: draft.markers) { name in
                if let index = draft.markers.firstIndex(where: { $0.id == marker.id }) {
                    draft.markers[index].label = name
                }
            }
        }
        .sheet(isPresented: $isAddingLabel) {
            ProgressLabelEditor(labels: draft.markers) { name in
                draft.markers.append(ProgressMarker(label: name))
            }
        }
    }

    private func move(_ marker: ProgressMarker, by offset: Int) {
        guard let index = draft.markers.firstIndex(where: { $0.id == marker.id }),
              draft.markers.indices.contains(index + offset) else { return }
        draft.markers.move(fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? index + 2 : index - 1)
    }
}

private struct ProgressLabelEditor: View {
    let marker: ProgressMarker?
    let labels: [ProgressMarker]
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @FocusState private var isFocused: Bool

    init(marker: ProgressMarker? = nil, labels: [ProgressMarker], onSave: @escaping (String) -> Void) {
        self.marker = marker
        self.labels = labels
        self.onSave = onSave
        _name = State(initialValue: marker?.label ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDuplicate: Bool {
        labels.contains { $0.id != marker?.id && ProgressConfiguration.nameKey($0.label) == ProgressConfiguration.nameKey(trimmedName) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit { isFocused = false }
                        .accessibilityIdentifier("progress.labelName")
                } footer: {
                    if isDuplicate { Text("A label with this name already exists.") }
                }
            }
            .navigationTitle(marker == nil ? "New label" : "Edit label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(trimmedName); dismiss() }
                        .disabled(trimmedName.isEmpty || isDuplicate)
                        .accessibilityIdentifier("progress.saveLabel")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if isFocused { Spacer(); KeyboardDismissButton { isFocused = false } }
                }
            }
            .task { isFocused = true }
        }
    }
}

/// This indicates an ordered label, not an estimate of work or time remaining.
struct TaskProgressIndicator: View {
    let task: TaskItem
    @EnvironmentObject private var taskStore: TaskStore

    var body: some View {
        let labels = taskStore.progressConfiguration.markers
        let marker = taskStore.progressMarker(for: task)
        VStack(alignment: .leading, spacing: 6) {
            Text(task.isCompleted ? "Completed" : marker.label).font(.caption).foregroundStyle(.secondary)
            ProgressView(value: taskStore.progressFraction(for: task))
                .tint(.accentColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress for \(task.title)")
        .accessibilityValue(task.isCompleted ? "Completed" : marker.label)
        .accessibilityIdentifier("task.progress.\(task.id)")
        .accessibilityActions {
            if !task.isCompleted {
                ForEach(labels) { label in
                    Button("Set progress to \(label.label)") {
                        taskStore.setProgress(taskID: task.id, markerID: label.id)
                    }
                }
            }
        }
    }
}

struct TaskProgressSlider: View {
    @Binding var markerID: UUID?
    @EnvironmentObject private var taskStore: TaskStore

    private var selectedIndex: Int {
        taskStore.progressConfiguration.markers.firstIndex { $0.id == markerID } ?? 0
    }

    var body: some View {
        let labels = taskStore.progressConfiguration.markers
        Text(labels[selectedIndex].label)
            .accessibilityIdentifier("task.progressLabel")
        if labels.count > 1 {
            Slider(value: Binding(get: { Double(selectedIndex) }, set: { markerID = labels[Int($0.rounded())].id }),
                   in: 0...Double(labels.count - 1), step: 1)
                .accessibilityLabel("Task progress")
                .accessibilityValue(labels[selectedIndex].label)
                .accessibilityIdentifier("task.progressSlider")
        }
    }
}
