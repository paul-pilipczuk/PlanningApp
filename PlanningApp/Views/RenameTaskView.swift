import SwiftUI

struct RenameTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String

    let task: TaskItem
    let onSave: (String) -> Void

    init(task: TaskItem, onSave: @escaping (String) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Task name", text: $title)
                    .textInputAutocapitalization(.sentences)
            }
            .navigationTitle("Rename Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
