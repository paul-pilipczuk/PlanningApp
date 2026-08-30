import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @State private var isAddingTask = false
    @State private var taskToEdit: TaskItem?
    @State private var taskPendingDeletion: TaskItem?
    @State private var taskShowingDeleteID: UUID?
    @State private var draggedTaskID: UUID?
    @State private var dragPreviewFrame: CGRect?
    @State private var dragTranslation: CGSize = .zero
    @State private var hasPendingReorder = false
    @State private var reorderFeedback = 0
    @State private var isCompletedExpanded = false
    @State private var showsCompletedTasks = false
    @State private var taskFrames: [UUID: CGRect] = [:]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if taskStore.incompleteTasks.isEmpty && taskStore.completedTasks.isEmpty { emptyState }
                        else {
                            ForEach(taskStore.activeSections) { section in
                                Text(section.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                ForEach(section.tasks) { task in taskRow(task) }
                            }
                        }
                        Color.clear.frame(minHeight: taskStore.incompleteTasks.isEmpty ? 260 : 140)
                            .contentShape(Rectangle()).onTapGesture { isAddingTask = true }
                    }.padding(16)
                }.background(Color.black)
                dragPreview
            }
            .coordinateSpace(name: "taskList")
            .onPreferenceChange(TaskFramePreferenceKey.self) { taskFrames = $0 }
            .sensoryFeedback(.selection, trigger: reorderFeedback)
            .overlay { GeometryReader { proxy in
                VStack { Spacer(minLength: 0); if !taskStore.completedTasks.isEmpty { completedSection(maxHeight: proxy.size.height * 0.5).padding(.bottom, 12) } }
            }}
            .navigationTitle("Tasks")
        }
        .sheet(isPresented: $isAddingTask) { editor(task: nil) }
        .sheet(item: $taskToEdit) { editor(task: $0) }
        .alert("Delete Task?", isPresented: Binding(get: { taskPendingDeletion != nil }, set: { if !$0 { taskPendingDeletion = nil } })) {
            Button("Delete", role: .destructive) { if let taskPendingDeletion { taskStore.delete(taskID: taskPendingDeletion.id) }; taskPendingDeletion = nil }
            Button("Cancel", role: .cancel) { taskPendingDeletion = nil }
        } message: { Text("This task will be removed permanently.") }
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

    private func completedSection(maxHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            Button { toggleCompletedSection() } label: { HStack(alignment: .firstTextBaseline) { Text("Completed").font(.largeTitle.weight(.bold)); Spacer(); Image(systemName: isCompletedExpanded ? "chevron.up" : "chevron.down").font(.headline.weight(.semibold)) }.foregroundStyle(.primary).padding(.horizontal, 16) }.buttonStyle(.plain)
            if showsCompletedTasks { ScrollView { LazyVStack(spacing: 10) { ForEach(taskStore.completedTasks) { task in TaskRow(task: task, isDeleteVisible: false, onComplete: { taskStore.toggleCompletion(for: task.id) }, onTaskTap: { taskStore.toggleCompletion(for: task.id) }, onLongPress: { taskToEdit = task }, onConfigure: { taskToEdit = task }, onDelete: { taskPendingDeletion = task }, onDragChanged: { _ in }, onDragEnded: { _ in }) } }.padding(.horizontal, 16).padding(.bottom, 10) }.frame(maxHeight: maxHeight - 76).transition(.opacity) }
        }.padding(.top, 8).frame(maxWidth: .infinity).frame(height: isCompletedExpanded ? maxHeight : nil, alignment: .top).background(Color.black.opacity(0.98))
    }
    private func toggleCompletedSection() { if isCompletedExpanded { withAnimation(.easeOut(duration: 0.12)) { showsCompletedTasks = false }; Task { @MainActor in try? await Task.sleep(for: .milliseconds(120)); guard !showsCompletedTasks else { return }; withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) { isCompletedExpanded = false } } } else { withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) { isCompletedExpanded = true }; Task { @MainActor in try? await Task.sleep(for: .milliseconds(150)); guard isCompletedExpanded else { return }; withAnimation(.easeOut(duration: 0.16)) { showsCompletedTasks = true } } } }
    private var emptyState: some View { VStack(spacing: 10) { Image(systemName: "checklist").font(.system(size: 38)).foregroundStyle(.secondary); Text("No plans yet").font(.headline); Text("Tap the empty space to add one.").font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, minHeight: 230).contentShape(Rectangle()).onTapGesture { isAddingTask = true } }
}

private struct TaskFramePreferenceKey: PreferenceKey { static var defaultValue: [UUID: CGRect] = [:]; static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) } }

private struct TaskRow: View {
    let task: TaskItem; let isDeleteVisible: Bool; let onComplete: () -> Void; let onTaskTap: () -> Void; let onLongPress: () -> Void; let onConfigure: () -> Void; let onDelete: () -> Void; let onDragChanged: (DragGesture.Value) -> Void; let onDragEnded: (DragGesture.Value) -> Void
    @State private var touchBeganAt: Date?
    @State private var isReordering = false

    var body: some View { HStack(spacing: 12) {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 3) { Text(task.title).strikethrough(task.isCompleted).foregroundStyle(task.isCompleted ? Color.secondary : Color.primary); if !task.description.isEmpty { Text(task.description).lineLimit(1).font(.subheadline).foregroundStyle(.secondary) } }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
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
        if isDeleteVisible { Button("Delete", role: .destructive, action: onDelete).buttonStyle(.bordered).tint(.red) } else { Button(action: onConfigure) { Image(systemName: "gearshape").font(.body).foregroundStyle(.secondary).frame(width: 32, height: 32) }.buttonStyle(.plain) }
    }.padding(14).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14)) }
}
