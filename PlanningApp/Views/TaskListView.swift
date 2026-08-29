import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @State private var isAddingTask = false
    @State private var taskToRename: TaskItem?
    @State private var taskToConfigure: TaskItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if taskStore.tasks.isEmpty {
                        emptyState
                    } else {
                        ForEach(taskStore.tasks) { task in
                            TaskRow(
                                task: task,
                                onComplete: { taskStore.toggleCompletion(for: task.id) },
                                onRename: { taskToRename = task },
                                onConfigure: { taskToConfigure = task }
                            )
                        }
                    }

                    Color.clear
                        .frame(minHeight: taskStore.tasks.isEmpty ? 260 : 140)
                        .contentShape(Rectangle())
                        .onTapGesture { isAddingTask = true }
                }
                .padding(16)
            }
            .background(Color.black)
            .navigationTitle("Plans")
        }
        .sheet(isPresented: $isAddingTask) {
            AddTaskView { title in
                taskStore.add(title: title)
            }
        }
        .sheet(item: $taskToRename) { task in
            RenameTaskView(task: task) { title in
                taskStore.rename(taskID: task.id, to: title)
            }
        }
        .sheet(item: $taskToConfigure) { task in
            NotificationSettingsView(task: task) { reminder in
                taskStore.updateReminder(reminder, for: task.id)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("No plans yet")
                .font(.headline)
            Text("Tap the empty space to add one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 230)
        .contentShape(Rectangle())
        .onTapGesture { isAddingTask = true }
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let onComplete: () -> Void
    let onRename: () -> Void
    let onConfigure: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")

            Button(action: onRename) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rename \(task.title)")

            Button(action: onConfigure) {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notification settings for \(task.title)")
        }
        .padding(14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
