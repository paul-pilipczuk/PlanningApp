import SwiftUI

struct ArchiveView: View {
    let onScrollOffset: (CGFloat) -> Void
    @EnvironmentObject private var taskStore: TaskStore
    @State private var selectedTask: TaskItem?
    @State private var pendingDeletion: TaskItem?

    var body: some View {
        let archivedTasks = taskStore.archivedTasks
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if archivedTasks.isEmpty {
                        ContentUnavailableView("No Archived Tasks", systemImage: "archivebox",
                                               description: Text("Archive completed tasks to keep them here. You can restore them at any time."))
                            .frame(minHeight: max(0, proxy.size.height - 124))
                    } else {
                        ForEach(archivedTasks) { task in
                            HStack(spacing: 12) {
                                Button { selectedTask = task } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "archivebox").font(.title2).foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(task.title).foregroundStyle(.primary)
                                            Text(taskStore.groupName(for: task)).font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Archived task: \(task.title)")
                                Menu {
                                    Button("Restore to Completed", systemImage: "arrow.uturn.backward") { taskStore.restore(taskID: task.id) }
                                    Button("Delete Permanently…", systemImage: "trash", role: .destructive) { pendingDeletion = task }
                                } label: {
                                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Actions for \(task.title)")
                            }
                            .padding(14)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityAction(named: "Restore to Completed") { taskStore.restore(taskID: task.id) }
                            .accessibilityAction(named: "Delete Permanently") { pendingDeletion = task }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 92)
                .background(TaskScrollContentReader())
            }
            .modifier(TaskScrollObserver(onOffsetChange: onScrollOffset))
            .accessibilityIdentifier("archived.scroll")
        }
        .sheet(item: $selectedTask) { task in ArchivedTaskDetails(taskID: task.id) }
        .alert("Delete Task Permanently?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { task in
            Button("Delete Permanently", role: .destructive) { taskStore.delete(taskID: task.id) }
            Button("Cancel", role: .cancel) { }
        } message: { task in
            Text("“\(task.title)” will be removed from this device. This can’t be undone.")
        }

    }
}

private struct ArchivedTaskDetails: View {
    let taskID: UUID
    @EnvironmentObject private var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDeletion = false

    private var task: TaskItem? { taskStore.tasks.first { $0.id == taskID && $0.isArchived } }

    var body: some View {
        NavigationStack {
            Form {
                if let task {
                    Section("Task") {
                        Text(task.title).font(.headline)
                        LabeledContent("Group", value: taskStore.groupName(for: task))
                        if let date = task.archivedAt { LabeledContent("Archived", value: date.formatted(date: .abbreviated, time: .shortened)) }
                    }
                    if !task.description.isEmpty { Section("Description") { Text(task.description) } }
                    Section {
                        Button("Restore to Completed", systemImage: "arrow.uturn.backward") {
                            if taskStore.restore(taskID: taskID) { dismiss() }
                        }
                        Button("Delete Permanently…", role: .destructive) { confirmingDeletion = true }
                    } footer: { Text("Archived tasks don’t send reminders. Restoring keeps this task completed.") }
                    if let error = taskStore.errorMessage { Section { Text(error).foregroundStyle(.red) } }
                } else {
                    Text("This task is no longer archived.")
                }
            }
            .navigationTitle("Archived Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Delete Task Permanently?", isPresented: $confirmingDeletion, presenting: task) { task in
                Button("Delete Permanently", role: .destructive) {
                    if taskStore.delete(taskID: task.id) { dismiss() }
                }
                Button("Cancel", role: .cancel) { }
            } message: { task in
                Text("“\(task.title)” will be removed from this device. This can’t be undone.")
            }

        }
    }
}
