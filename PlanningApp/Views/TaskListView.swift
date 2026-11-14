import SwiftUI

struct TaskListView: View {
    let tab: PlanningTab
    @Binding var isAddingTask: Bool
    let onScrollOffset: (CGFloat) -> Void

    @EnvironmentObject private var taskStore: TaskStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taskToEdit: TaskItem?
    @State private var taskPendingDeletion: TaskItem?
    @State private var taskPendingRemoval: TaskItem?
    @State private var editorRemoval: TaskItem?
    @State private var taskShowingDeleteID: UUID?
    @State private var draggedTaskID: UUID?
    @State private var dragPreviewFrame: CGRect?
    @State private var dragTranslation: CGSize = .zero
    @State private var hasPendingReorder = false
    @State private var reorderFeedback = 0
    @State private var taskFrames = TaskFrameCache()

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if visibleTasks.isEmpty {
                        emptyState
                    } else if tab == .active {
                        ForEach(taskStore.activeSections.filter { !$0.tasks.isEmpty }) { section in
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(section.tasks) { task in taskRow(task) }
                        }
                    } else {
                        ForEach(taskStore.completedTasks) { task in taskRow(task) }
                    }
                    if tab == .active {
                        Color.clear.frame(minHeight: visibleTasks.isEmpty ? 260 : 140)
                            .contentShape(Rectangle())
                            .onTapGesture { isAddingTask = true }
                            .accessibilityHidden(true)
                    }
                }
                .padding(16)
                .padding(.bottom, 92)
                .background(TaskScrollContentReader())
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: taskStore.tasks)
            }
            .modifier(TaskScrollObserver { offset in
                guard draggedTaskID == nil else { return }
                onScrollOffset(offset)
            })
            .accessibilityIdentifier("taskList.\(tab.rawValue)")
            .id(tab)
            dragPreview
        }
        .background(Color(uiColor: .systemBackground))
        .coordinateSpace(name: "taskList")
        .onPreferenceChange(TaskFramePreferenceKey.self) { taskFrames.frames = $0 }
        .sensoryFeedback(.selection, trigger: reorderFeedback) { _, _ in preferences.hapticFeedback }
        .onChange(of: tab) { _, _ in
            endDragging()
            taskShowingDeleteID = nil
            taskFrames.frames = [:]
        }
        .sheet(isPresented: $isAddingTask) { editor(task: nil) }
        .sheet(item: $taskToEdit, onDismiss: {
            if let task = editorRemoval { editorRemoval = nil; requestRemoval(task) }
        }) { editor(task: $0) }
        .confirmationDialog("Remove Completed Task?", isPresented: Binding(get: { taskPendingRemoval != nil }, set: { if !$0 { taskPendingRemoval = nil } }), titleVisibility: .visible) {
            if let task = taskPendingRemoval {
                Button("Archive") { taskStore.archive(taskID: task.id); taskShowingDeleteID = nil }
                Button("Delete", role: .destructive) { taskPendingDeletion = task }
            }
            Button("Cancel", role: .cancel) { taskPendingRemoval = nil }
        } message: { Text(taskPendingRemoval?.title ?? "") }
        .alert("Delete Task?", isPresented: Binding(
            get: { taskPendingDeletion != nil },
            set: { if !$0 { taskPendingDeletion = nil } }
        ), presenting: taskPendingDeletion) { task in
            Button("Delete", role: .destructive) { taskStore.delete(taskID: task.id) }
            Button("Cancel", role: .cancel) { }
        } message: { task in
            Text("“\(task.title)” will be removed from this device. This can’t be undone.")
        }

    }

    private var visibleTasks: [TaskItem] {
        tab == .completed ? taskStore.completedTasks : taskStore.incompleteTasks
    }

    private func requestRemoval(_ task: TaskItem) {
        guard let current = taskStore.tasks.first(where: { $0.id == task.id && !$0.isArchived }) else { return }
        if current.isCompleted { taskPendingRemoval = current }
        else { taskPendingDeletion = current }
    }

    private func editor(task: TaskItem?) -> TaskEditorView {
        TaskEditorView(task: task, groups: taskStore.groups, onSave: { title, description, groupID, reminder in
            if let task { taskStore.update(taskID: task.id, title: title, description: description, groupID: groupID, reminder: reminder) }
            else { taskStore.add(title: title, description: description, groupID: groupID, reminder: reminder) }
        }, onCreateGroup: { taskStore.createGroup(named: $0) }, onRequestDelete: task.map { savedTask in { editorRemoval = savedTask } }, onArchive: task.flatMap { savedTask in
            savedTask.isCompleted ? { taskStore.archive(taskID: savedTask.id) } : nil
        })
    }

    private func taskRow(_ task: TaskItem) -> some View {
        TaskRow(task: task, isDeleteVisible: taskShowingDeleteID == task.id,
                onComplete: { taskStore.toggleCompletion(for: task.id) },
                onTaskTap: { if taskShowingDeleteID == task.id { taskShowingDeleteID = nil } else { taskStore.toggleCompletion(for: task.id) } },
                onLongPress: { taskToEdit = task },
                onConfigure: { taskToEdit = task }, onDelete: { requestRemoval(task) },
                onDragChanged: { drag in
                    guard tab == .active else { return }
                    beginDragging(task)
                    dragTranslation = drag.translation
                    updateTaskOrder(for: drag.location)
                }, onDragEnded: { _ in endDragging() })
            .background {
                if tab == .active { taskFrameReader(for: task.id) }
            }
            .accessibilityAction(named: task.isCompleted ? "Remove" : "Delete") { requestRemoval(task) }
            .accessibilityAction(named: "Task details") { taskToEdit = task }
            .opacity(draggedTaskID == task.id ? 0 : 1)
            .simultaneousGesture(swipeGesture(for: task))
    }

    private func taskFrameReader(for taskID: UUID) -> some View { GeometryReader { proxy in Color.clear.preference(key: TaskFramePreferenceKey.self, value: [taskID: proxy.frame(in: .named("taskList"))]) } }

    @ViewBuilder private var dragPreview: some View {
        if let draggedTaskID, let task = taskStore.tasks.first(where: { $0.id == draggedTaskID && !$0.isCompleted }), let dragPreviewFrame {
            TaskRow(task: task, isDeleteVisible: false, onComplete: {}, onTaskTap: {}, onLongPress: {}, onConfigure: {}, onDelete: {}, onDragChanged: { _ in }, onDragEnded: { _ in })
                .frame(width: dragPreviewFrame.width).scaleEffect(1.035).shadow(color: .black.opacity(0.45), radius: 14, y: 8)
                .offset(x: dragPreviewFrame.minX, y: dragPreviewFrame.minY + dragTranslation.height).allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private func swipeGesture(for task: TaskItem) -> some Gesture {
        DragGesture(minimumDistance: 20).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            if value.translation.width < -45 { taskShowingDeleteID = task.id }
            else if value.translation.width > 45 { taskShowingDeleteID = nil }
        }
    }

    private func beginDragging(_ task: TaskItem) { guard draggedTaskID == nil, let frame = taskFrames.frames[task.id] else { return }; withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.8)) { draggedTaskID = task.id; dragPreviewFrame = frame }; hasPendingReorder = false }
    private func updateTaskOrder(for location: CGPoint) {
        guard let draggedTaskID, let dragged = taskStore.tasks.first(where: { $0.id == draggedTaskID && !$0.isCompleted }) else { return }
        let candidates = taskStore.tasks.filter { !$0.isCompleted && $0.groupID == dragged.groupID }
        guard let currentIndex = candidates.firstIndex(where: { $0.id == draggedTaskID }) else { return }

        if currentIndex > 0,
           let previousFrame = taskFrames.frames[candidates[currentIndex - 1].id],
           location.y < previousFrame.midY {
            if taskStore.move(taskID: draggedTaskID, before: candidates[currentIndex - 1].id, persist: false) {
                hasPendingReorder = true
                reorderFeedback += 1
            }
        } else if currentIndex < candidates.count - 1,
                  let nextFrame = taskFrames.frames[candidates[currentIndex + 1].id],
                  location.y > nextFrame.midY {
            let moved: Bool
            if currentIndex + 1 == candidates.count - 1 {
                moved = taskStore.moveToEnd(taskID: draggedTaskID, persist: false)
            } else {
                moved = taskStore.move(taskID: draggedTaskID, before: candidates[currentIndex + 2].id, persist: false)
            }
            if moved {
                hasPendingReorder = true
                reorderFeedback += 1
            }
        }
    }
    private func endDragging() {
        if hasPendingReorder { taskStore.persistTaskOrder() }
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { draggedTaskID = nil; dragPreviewFrame = nil; dragTranslation = .zero }
        hasPendingReorder = false
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(tab == .completed ? "Nothing completed yet" : "No plans yet",
                  systemImage: tab == .completed ? "checkmark.circle" : "checklist")
        } description: {
            Text(tab == .completed ? "Completed plans will appear here." : "Tap the plus or the empty space to add a plan.")
        } actions: {
            if tab == .active {
                Button("Add a plan") { isAddingTask = true }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 230)
    }

}

/// Geometry is an input to drag handling, not rendered state. Keep measurements
/// without invalidating the entire list every time the scroll position changes.
private final class TaskFrameCache {
    var frames: [UUID: CGRect] = [:]
}

private struct TaskFramePreferenceKey: PreferenceKey { static var defaultValue: [UUID: CGRect] = [:]; static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) } }

private struct TaskRow: View {
    let task: TaskItem; let isDeleteVisible: Bool; let onComplete: () -> Void; let onTaskTap: () -> Void; let onLongPress: () -> Void; let onConfigure: () -> Void; let onDelete: () -> Void; let onDragChanged: (DragGesture.Value) -> Void; let onDragEnded: (DragGesture.Value) -> Void
    @State private var touchBeganAt: Date?
    @State private var isReordering = false

    var body: some View {
        HStack(spacing: 12) {
            primaryInteraction
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(task.isCompleted ? "Mark \(task.title) active" : "Complete \(task.title)")
                .accessibilityValue(task.description)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onTaskTap() }
                .accessibilityAction(named: "Task details", onLongPress)
            if isDeleteVisible {
                Button(task.isCompleted ? "Remove" : "Delete", role: task.isCompleted ? nil : .destructive, action: onDelete)
                    .buttonStyle(.bordered)
                    .tint(task.isCompleted ? .accentColor : .red)
            } else {
                Button(action: onConfigure) {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Details for \(task.title)")
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var primaryInteraction: some View {
        if task.isCompleted {
            taskContent
                .onTapGesture(perform: onTaskTap)
                .onLongPressGesture(perform: onLongPress)
        } else {
            taskContent
        .gesture(isDeleteVisible ? nil : DragGesture(minimumDistance: 0, coordinateSpace: .named("taskList")).onChanged { value in
            if touchBeganAt == nil { touchBeganAt = Date() }
            let translation = value.translation
            let isVerticalMove = abs(translation.height) > abs(translation.width)
            guard isVerticalMove, abs(translation.height) >= 12 else { return }
            isReordering = true
            onDragChanged(value)
        }.onEnded { value in
            defer {
                touchBeganAt = nil
                isReordering = false
            }
            if isReordering {
                onDragEnded(value)
                return
            }
            let translation = value.translation
            if abs(translation.width) > abs(translation.height), abs(translation.width) >= 45 { return }
            if Date().timeIntervalSince(touchBeganAt ?? Date()) >= 0.45 { onLongPress() }
            else { onTaskTap() }
        })
        }
    }

    private var taskContent: some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 3) { Text(task.title).strikethrough(task.isCompleted).foregroundStyle(task.isCompleted ? Color.secondary : Color.primary); if !task.description.isEmpty { Text(task.description).lineLimit(1).font(.subheadline).foregroundStyle(.secondary) } }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

}
