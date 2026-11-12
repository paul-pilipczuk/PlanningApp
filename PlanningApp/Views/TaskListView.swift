import SwiftUI

struct TaskListView: View {
    let tab: PlanningTab
    @Binding var isAddingTask: Bool
    let onScrollOffset: (CGFloat) -> Void

    @EnvironmentObject private var taskStore: TaskStore
    @State private var taskToEdit: TaskItem?
    @State private var taskPendingDeletion: TaskItem?
    @State private var taskShowingDeleteID: UUID?
    @State private var draggedTaskID: UUID?
    @State private var dragPreviewFrame: CGRect?
    @State private var dragTranslation: CGSize = .zero
    @State private var hasPendingReorder = false
    @State private var reorderFeedback = 0
    @State private var taskFrames: [UUID: CGRect] = [:]

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
                .background(TaskScrollContentReader())
            }
            .contentMargins(.bottom, 92, for: .scrollContent)
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
        .onPreferenceChange(TaskFramePreferenceKey.self) { taskFrames = $0 }
        .sensoryFeedback(.selection, trigger: reorderFeedback)
        .onChange(of: tab) { _, _ in
            endDragging()
            taskShowingDeleteID = nil
            taskFrames = [:]
        }
        .sheet(isPresented: $isAddingTask) { editor(task: nil) }
        .sheet(item: $taskToEdit) { editor(task: $0) }
        .alert("Delete Task?", isPresented: Binding(get: { taskPendingDeletion != nil }, set: { if !$0 { taskPendingDeletion = nil } })) {
            Button("Delete", role: .destructive) { if let taskPendingDeletion { taskStore.delete(taskID: taskPendingDeletion.id) }; taskPendingDeletion = nil }
            Button("Cancel", role: .cancel) { taskPendingDeletion = nil }
        } message: { Text("This task will be removed permanently.") }
    }

    private var visibleTasks: [TaskItem] {
        tab == .completed ? taskStore.completedTasks : taskStore.incompleteTasks
    }

    private func editor(task: TaskItem?) -> TaskEditorView {
        TaskEditorView(task: task, groups: taskStore.groups, onSave: { title, description, groupID, reminder in
            if let task { taskStore.update(taskID: task.id, title: title, description: description, groupID: groupID, reminder: reminder) }
            else { taskStore.add(title: title, description: description, groupID: groupID, reminder: reminder) }
        }, onCreateGroup: { taskStore.createGroup(named: $0) }, onRequestDelete: task.map { savedTask in { taskPendingDeletion = savedTask } })
    }

    private func taskRow(_ task: TaskItem) -> some View {
        TaskRow(task: task, isDeleteVisible: taskShowingDeleteID == task.id,
                onComplete: { taskStore.toggleCompletion(for: task.id) },
                onTaskTap: { if taskShowingDeleteID == task.id { taskShowingDeleteID = nil } else { taskStore.toggleCompletion(for: task.id) } },
                onLongPress: { taskToEdit = task },
                onConfigure: { taskToEdit = task }, onDelete: { taskPendingDeletion = task },
                onDragChanged: { drag in
                    guard tab == .active else { return }
                    beginDragging(task)
                    dragTranslation = drag.translation
                    updateTaskOrder(for: drag.location)
                }, onDragEnded: { _ in endDragging() })
            .background(taskFrameReader(for: task.id))
            .opacity(draggedTaskID == task.id ? 0 : 1)
            .simultaneousGesture(swipeGesture(for: task))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: taskStore.tasks)
    }

    private func taskFrameReader(for taskID: UUID) -> some View { GeometryReader { proxy in Color.clear.preference(key: TaskFramePreferenceKey.self, value: [taskID: proxy.frame(in: .named("taskList"))]) } }

    @ViewBuilder private var dragPreview: some View {
        if let draggedTaskID, let task = taskStore.incompleteTasks.first(where: { $0.id == draggedTaskID }), let dragPreviewFrame {
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

    private func beginDragging(_ task: TaskItem) { guard draggedTaskID == nil, let frame = taskFrames[task.id] else { return }; withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) { draggedTaskID = task.id; dragPreviewFrame = frame }; hasPendingReorder = false }
    private func updateTaskOrder(for location: CGPoint) {
        guard let draggedTaskID, let dragged = taskStore.incompleteTasks.first(where: { $0.id == draggedTaskID }) else { return }
        let candidates = taskStore.incompleteTasks.filter { $0.groupID == dragged.groupID }
        guard let currentIndex = candidates.firstIndex(where: { $0.id == draggedTaskID }) else { return }

        if currentIndex > 0,
           let previousFrame = taskFrames[candidates[currentIndex - 1].id],
           location.y < previousFrame.midY {
            if taskStore.move(taskID: draggedTaskID, before: candidates[currentIndex - 1].id, persist: false) {
                hasPendingReorder = true
                reorderFeedback += 1
            }
        } else if currentIndex < candidates.count - 1,
                  let nextFrame = taskFrames[candidates[currentIndex + 1].id],
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { draggedTaskID = nil; dragPreviewFrame = nil; dragTranslation = .zero }
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
                Button("Delete", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
                    .tint(.red)
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
