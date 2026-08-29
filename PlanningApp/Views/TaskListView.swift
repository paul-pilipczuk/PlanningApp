import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @State private var isAddingTask = false
    @State private var taskToRename: TaskItem?
    @State private var taskToConfigure: TaskItem?
    @State private var draggedTaskID: UUID?
    @State private var dragPreviewFrame: CGRect?
    @State private var dragTranslation: CGSize = .zero
    @State private var lastReorderTargetID: UUID?
    @State private var isReorderedToEnd = false
    @State private var reorderFeedback = 0
    @State private var isCompletedExpanded = false
    @State private var showsCompletedTasks = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if taskStore.incompleteTasks.isEmpty && taskStore.completedTasks.isEmpty {
                            emptyState
                        } else {
                            ForEach(taskStore.incompleteTasks) { task in
                                TaskRow(
                                    task: task,
                                    onComplete: { taskStore.toggleCompletion(for: task.id) },
                                    onRename: { taskToRename = task },
                                    onConfigure: { taskToConfigure = task }
                                )
                                .background(taskFrameReader(for: task.id))
                                .opacity(draggedTaskID == task.id ? 0 : 1)
                                .highPriorityGesture(reorderGesture(for: task))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: taskStore.tasks)
                            }
                        }

                        Color.clear
                            .frame(minHeight: taskStore.incompleteTasks.isEmpty ? 260 : 140)
                            .contentShape(Rectangle())
                            .onTapGesture { isAddingTask = true }

                    }
                    .padding(16)
                }
                .background(Color.black)

                dragPreview
            }
            .coordinateSpace(name: "taskList")
            .onPreferenceChange(TaskFramePreferenceKey.self) { frames in
                taskFrames = frames
            }
            .sensoryFeedback(.selection, trigger: reorderFeedback)
            .overlay {
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        if !taskStore.completedTasks.isEmpty {
                            completedSection(maxHeight: proxy.size.height * 0.5)
                                .padding(.bottom, 12)
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
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

    @State private var taskFrames: [UUID: CGRect] = [:]

    private func taskFrameReader(for taskID: UUID) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: TaskFramePreferenceKey.self,
                value: [taskID: proxy.frame(in: .named("taskList"))]
            )
        }
    }

    @ViewBuilder
    private var dragPreview: some View {
        if let draggedTaskID,
           let task = taskStore.incompleteTasks.first(where: { $0.id == draggedTaskID }),
           let dragPreviewFrame {
            TaskRow(task: task, onComplete: {}, onRename: {}, onConfigure: {})
                .frame(width: dragPreviewFrame.width)
                .scaleEffect(1.035)
                .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
                .offset(
                    x: dragPreviewFrame.minX,
                    y: dragPreviewFrame.minY + dragTranslation.height
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func reorderGesture(for task: TaskItem) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(coordinateSpace: .named("taskList")))
            .onChanged { value in
                switch value {
                case .first(true):
                    beginDragging(task)
                case .second(true, let drag?):
                    beginDragging(task)
                    dragTranslation = drag.translation
                    updateTaskOrder(for: drag.location)
                default:
                    break
                }
            }
            .onEnded { _ in
                endDragging()
            }
    }

    private func beginDragging(_ task: TaskItem) {
        guard draggedTaskID == nil, let frame = taskFrames[task.id] else { return }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
            draggedTaskID = task.id
            dragPreviewFrame = frame
        }
        lastReorderTargetID = nil
        isReorderedToEnd = false
    }

    private func updateTaskOrder(for location: CGPoint) {
        guard let draggedTaskID else { return }

        let destination = taskStore.incompleteTasks.first { task in
            task.id != draggedTaskID && (taskFrames[task.id]?.midY ?? .greatestFiniteMagnitude) > location.y
        }

        if let destination {
            guard lastReorderTargetID != destination.id || isReorderedToEnd else { return }

            if taskStore.move(taskID: draggedTaskID, before: destination.id) {
                reorderFeedback += 1
            }
            lastReorderTargetID = destination.id
            isReorderedToEnd = false
        } else {
            guard !isReorderedToEnd else { return }

            if taskStore.moveToEnd(taskID: draggedTaskID) {
                reorderFeedback += 1
            }
            lastReorderTargetID = nil
            isReorderedToEnd = true
        }
    }

    private func endDragging() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            draggedTaskID = nil
            dragPreviewFrame = nil
            dragTranslation = .zero
        }
        lastReorderTargetID = nil
        isReorderedToEnd = false
    }

    private func completedSection(maxHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            Button {
                toggleCompletedSection()
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Completed")
                        .font(.largeTitle.weight(.bold))
                    Spacer()
                    Image(systemName: isCompletedExpanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Completed")
            .accessibilityValue(isCompletedExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows completed tasks")

            if showsCompletedTasks {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(taskStore.completedTasks) { task in
                            TaskRow(
                                task: task,
                                onComplete: { taskStore.toggleCompletion(for: task.id) },
                                onRename: { taskToRename = task },
                                onConfigure: { taskToConfigure = task }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: maxHeight - 76)
                .transition(.opacity)
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
        .frame(height: isCompletedExpanded ? maxHeight : nil, alignment: .top)
        .background(Color.black.opacity(0.98))
    }

    private func toggleCompletedSection() {
        if isCompletedExpanded {
            withAnimation(.easeOut(duration: 0.12)) {
                showsCompletedTasks = false
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                guard !showsCompletedTasks else { return }

                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                    isCompletedExpanded = false
                }
            }
        } else {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                isCompletedExpanded = true
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                guard isCompletedExpanded else { return }

                withAnimation(.easeOut(duration: 0.16)) {
                    showsCompletedTasks = true
                }
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

private struct TaskFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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
