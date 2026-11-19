import SwiftUI

struct TaskListView: View {
    let tab: PlanningTab
    @Binding var isAddingTask: Bool
    let onScrollOffset: (CGFloat) -> Void
    let onTaskCreated: () -> Void

    @EnvironmentObject private var taskStore: TaskStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var taskToEdit: TaskItem?
    @State private var taskPendingDeletion: TaskItem?
    @State private var editorDeletion: TaskItem?
    @State private var editorCopy: TaskItem?
    @State private var copyDraft: TaskItem?
    @State private var didCreateTask = false
    @State private var taskShowingDeleteID: UUID?
    @State private var draggedTaskID: UUID?
    @State private var dragGroupID: UUID?
    @State private var pendingDrop: PendingTaskDrop?
    @State private var dragPreviewFrame: CGRect?
    @State private var dragTranslation: CGSize = .zero
    @State private var hasPendingReorder = false
    @State private var reorderFeedback = 0
    @State private var taskFrames = TaskFrameCache()
    @ScaledMetric(relativeTo: .body) private var minimumCardContentHeight = TaskCardMetrics.minimumContentHeight

    var body: some View {
        ZStack(alignment: .topLeading) {
            if tab == .active && visibleTasks.isEmpty {
                emptyActiveCanvas
            } else {
                taskScrollView
            }
            dragPreview
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        // Keep touch locations and measured frames in one space. Resolve only
        // preview placement locally, avoiding iOS 17 lazy named-space offsets.
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: TaskListOriginPreferenceKey.self, value: proxy.frame(in: .global).origin)
            }
        }
        .onPreferenceChange(TaskListOriginPreferenceKey.self) { taskFrames.origin = $0 }
        .onPreferenceChange(TaskFramePreferenceKey.self) { taskFrames.rows = $0 }
        .onPreferenceChange(ProgressFramePreferenceKey.self) { taskFrames.replaceProgressFrames($0) }
        .sensoryFeedback(.selection, trigger: reorderFeedback) { _, _ in preferences.hapticFeedback }
        .onChange(of: tab) { _, _ in
            cancelDragging()
            taskShowingDeleteID = nil
            taskFrames.rows = [:]
            taskFrames.dropZones = []
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelDragging() }
        }
        .onDisappear(perform: cancelDragging)
        .sheet(isPresented: $isAddingTask) { editor(task: nil) }
        .sheet(item: $taskToEdit, onDismiss: {
            if let task = editorDeletion {
                editorDeletion = nil
                requestDeletion(task)
            } else if let draft = editorCopy {
                editorCopy = nil
                copyDraft = draft
            }
        }) { editor(task: $0) }
        .sheet(item: $copyDraft, onDismiss: {
            if didCreateTask { didCreateTask = false; onTaskCreated() }
        }) { draft in
            TaskEditorView(draft: draft, groups: taskStore.groups, onSave: { title, description, groupID, reminder, progressID in
                let saved = taskStore.add(title: title, description: description, groupID: groupID, reminder: reminder, progressMarkerID: progressID)
                didCreateTask = saved
                return saved
            }, onCreateGroup: { taskStore.createGroup(named: $0) })
        }
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

    private var taskScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if visibleTasks.isEmpty {
                    emptyState
                } else if tab == .active {
                    ForEach(taskStore.activeRows) { row in
                        switch row {
                        case .group(let group, let isEmpty): groupHeader(group, isEmpty: isEmpty)
                        case .progress(let groupID, let marker, let isEmpty): progressHeader(marker, groupID: groupID, isEmpty: isEmpty).padding(.leading, 8)
                        case .task(let task): taskRow(task).padding(.leading, taskStore.progressConfiguration.isEnabled ? 8 : 0)
                        }
                    }
                } else {
                    ForEach(taskStore.completedTasks) { task in taskRow(task) }
                }
                if tab == .active {
                    Color.clear.frame(height: 140)
                        .contentShape(Rectangle())
                        .onTapGesture { isAddingTask = true }
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
            .padding(.bottom, 92)
            .background(TaskScrollContentReader())
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: taskStore.taskRevision)
        }
        .modifier(TaskScrollObserver { offset in
            guard draggedTaskID == nil else { return }
            onScrollOffset(offset)
        })
        .accessibilityIdentifier("taskList.\(tab.rawValue)")
        .id(tab)
    }

    private func groupHeader(_ group: TaskGroup?, isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(group?.name ?? "General").font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary).accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("task.groupHeader.\(group?.id.uuidString ?? "general")")
            if isEmpty { Text("Drag a task here").font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, minHeight: isEmpty ? emptyDropHeight : 28, alignment: .leading)
        .padding(.top, 4)
        .background {
            if pendingDrop?.isGroupHeading == true && pendingDrop?.groupID == group?.id {
                RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.1))
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ProgressFramePreferenceKey.self,
                    value: [ProgressDropTarget(groupID: group?.id, markerID: nil): expandedDropFrame(proxy.frame(in: .global))])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task.groupDrop.\(group?.id.uuidString ?? "general")")
    }

    private func progressHeader(_ marker: ProgressMarker, groupID: UUID?, isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(marker.label).font(.caption.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("progress.section.\(groupID?.uuidString ?? "general").\(marker.id)")
            if isEmpty { Text("Drag a task here").font(.caption) }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: isEmpty ? emptyDropHeight : 24, alignment: .leading)
        .padding(.horizontal, isEmpty ? 10 : 0)
        .background {
            let isTarget = pendingDrop?.isGroupHeading == false && pendingDrop?.groupID == groupID && pendingDrop?.markerID == marker.id
            if isEmpty || isTarget {
                RoundedRectangle(cornerRadius: 14).fill(isTarget ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.04))
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ProgressFramePreferenceKey.self,
                    value: [ProgressDropTarget(groupID: groupID, markerID: marker.id): expandedDropFrame(proxy.frame(in: .global))])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progress.drop.\(groupID?.uuidString ?? "general").\(marker.id)")
    }

    private var emptyDropHeight: CGFloat {
        TaskCardMetrics.minimumHeight(contentHeight: minimumCardContentHeight,
                                      showsProgress: taskStore.progressConfiguration.isEnabled)
    }

    /// Compact headings still receive a forgiving 44-point vertical drop region.
    private func expandedDropFrame(_ frame: CGRect) -> CGRect {
        frame.insetBy(dx: 0, dy: -max(0, (44 - frame.height) / 2))
    }

    private var emptyActiveCanvas: some View {
        Button { isAddingTask = true } label: {
            VStack(spacing: 8) {
                Text("No plans yet").font(.title2.bold()).foregroundStyle(.primary)
                Text("Tap anywhere to add a plan.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task")
        .accessibilityValue("No plans yet")
        .accessibilityHint("Opens a new task.")
        .accessibilityIdentifier("task.emptyActive")
    }

    private var visibleTasks: [TaskItem] {
        tab == .completed ? taskStore.completedTasks : taskStore.incompleteTasks
    }

    private func requestDeletion(_ task: TaskItem) {
        guard let current = taskStore.tasks.first(where: { $0.id == task.id && !$0.isArchived }) else { return }
        taskPendingDeletion = current
    }

    private func editor(task: TaskItem?) -> TaskEditorView {
        TaskEditorView(task: task, groups: taskStore.groups, onSave: { title, description, groupID, reminder, progressID in
            if let task { taskStore.update(taskID: task.id, title: title, description: description, groupID: groupID, reminder: reminder, progressMarkerID: progressID) }
            else { taskStore.add(title: title, description: description, groupID: groupID, reminder: reminder, progressMarkerID: progressID) }
        }, onCreateGroup: { taskStore.createGroup(named: $0) }, onRequestDelete: task.map { savedTask in { editorDeletion = savedTask } }, onArchive: task.flatMap { savedTask in
            savedTask.isCompleted ? { taskStore.archive(taskID: savedTask.id) } : nil
        }, onRequestCopy: task.flatMap { savedTask in
            savedTask.isCompleted ? { editorCopy = savedTask.newTaskDraft(in: taskStore.groups) } : nil
        })
    }

    private func taskRow(_ task: TaskItem) -> some View {
        TaskRow(task: task, isDeleteVisible: taskShowingDeleteID == task.id,
                onComplete: { taskShowingDeleteID = nil; taskStore.toggleCompletion(for: task.id) },
                onTaskTap: { taskShowingDeleteID = nil; taskToEdit = task },
                onLongPress: { taskToEdit = task },
                onConfigure: { taskToEdit = task },
                onCopy: task.isCompleted ? { copyDraft = task.newTaskDraft(in: taskStore.groups) } : nil, onArchive: task.isCompleted ? {
                    let archived = taskStore.archive(taskID: task.id)
                    if archived { taskShowingDeleteID = nil }
                    return archived
                } : nil, onDelete: { requestDeletion(task) },
                onDragChanged: { drag in
                    guard tab == .active else { return }
                    beginDragging(task)
                    dragTranslation = drag.translation
                    updateTaskOrder(for: drag.location)
                }, onDragEnded: { _ in endDragging() }, onDragCancelled: cancelDragging)
            .background {
                if tab == .active { taskFrameReader(for: task) }
            }
            .accessibilityAction(named: "Task details") { taskToEdit = task }
            .opacity(draggedTaskID == task.id ? 0 : 1)
            .simultaneousGesture(swipeGesture(for: task))
    }

    private func taskFrameReader(for task: TaskItem) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: TaskFramePreferenceKey.self,
                value: [task.id: TaskRowGeometry(frame: proxy.frame(in: .global), groupID: taskStore.displayGroupID(for: task),
                    storedGroupID: task.groupID,
                    markerID: taskStore.progressConfiguration.isEnabled ? taskStore.progressMarker(for: task).id : nil)])
        }
    }

    @ViewBuilder private var dragPreview: some View {
        if let draggedTaskID, let task = taskStore.activeTasks(in: dragGroupID).first(where: { $0.id == draggedTaskID }), let dragPreviewFrame {
            TaskRow(task: previewTask(task), isDeleteVisible: false, onComplete: {}, onTaskTap: {}, onLongPress: {}, onConfigure: {}, onCopy: nil, onArchive: nil, onDelete: {}, onDragChanged: { _ in }, onDragEnded: { _ in }, onDragCancelled: {})
                .frame(width: dragPreviewFrame.width).scaleEffect(1.035).shadow(color: .black.opacity(0.45), radius: 14, y: 8)
                .offset(x: dragPreviewFrame.minX - taskFrames.origin.x, y: dragPreviewFrame.minY - taskFrames.origin.y + dragTranslation.height).allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private func swipeGesture(for task: TaskItem) -> some Gesture {
        DragGesture(minimumDistance: 20).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) else { return }
            if value.translation.width < -45 { taskShowingDeleteID = task.id }
            else if value.translation.width > 45 { taskShowingDeleteID = nil }
        }
    }

    private func beginDragging(_ task: TaskItem) {
        guard draggedTaskID == nil, let frame = taskFrames.rows[task.id]?.frame else { return }
        dragGroupID = task.groupID
        pendingDrop = nil
        withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.8)) {
            draggedTaskID = task.id
            dragPreviewFrame = frame
        }
        hasPendingReorder = false
    }

    private func updateTaskOrder(for location: CGPoint) {
        guard let draggedTaskID else { return }
        guard let current = taskStore.activeTasks(in: dragGroupID).first(where: { $0.id == draggedTaskID }) else { return }
        let currentMarker = taskStore.progressConfiguration.isEnabled ? taskStore.progressMarker(for: current).id : nil
        if let target = taskFrames.dropTarget(at: location) {
            let markerID = target.markerID ?? currentMarker
            if let pendingDrop, pendingDrop.groupID == target.groupID, pendingDrop.markerID == markerID,
               pendingDrop.isGroupHeading == (target.markerID == nil), pendingDrop.anchorRowID == nil { return }
            let destination = taskStore.displayedActiveTasks(in: target.groupID, progressMarkerID: markerID).first { $0.id != draggedTaskID }
            setPendingDrop(PendingTaskDrop(groupID: target.groupID, markerID: markerID, beforeID: destination?.id,
                                           isGroupHeading: target.markerID == nil))
            return
        }
        if let target = taskFrames.rows.first(where: { $0.key != draggedTaskID && $0.value.frame.contains(location) }),
           target.value.groupID != taskStore.displayGroupID(for: current) || target.value.storedGroupID != current.groupID || target.value.markerID != currentMarker {
            let placeAfter = location.y > target.value.frame.midY
            if let pendingDrop, pendingDrop.groupID == target.value.groupID, pendingDrop.markerID == target.value.markerID,
               pendingDrop.anchorRowID == target.key, pendingDrop.placeAfter == placeAfter { return }
            var beforeID: UUID? = target.key
            if placeAfter {
                let lane = taskStore.displayedActiveTasks(in: target.value.groupID, progressMarkerID: target.value.markerID)
                if let index = lane.firstIndex(where: { $0.id == target.key }) {
                    beforeID = lane.dropFirst(index + 1).first { $0.id != draggedTaskID }?.id
                }
            }
            setPendingDrop(PendingTaskDrop(groupID: target.value.groupID, markerID: target.value.markerID,
                                           beforeID: beforeID, isGroupHeading: false, anchorRowID: target.key, placeAfter: placeAfter))
            return
        }
        if pendingDrop != nil { pendingDrop = nil }
        let candidates = taskStore.activeTasks(in: dragGroupID, progressMarkerID: currentMarker)
        guard let currentIndex = candidates.firstIndex(where: { $0.id == draggedTaskID }) else { return }

        if currentIndex > 0,
           let previousFrame = taskFrames.rows[candidates[currentIndex - 1].id]?.frame,
           location.y < previousFrame.midY {
            if taskStore.move(taskID: draggedTaskID, before: candidates[currentIndex - 1].id, persist: false) {
                hasPendingReorder = true
                reorderFeedback += 1
            }
        } else if currentIndex < candidates.count - 1,
                  let nextFrame = taskFrames.rows[candidates[currentIndex + 1].id]?.frame,
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
    private func setPendingDrop(_ drop: PendingTaskDrop) {
        guard pendingDrop != drop else { return }
        pendingDrop = drop
        reorderFeedback += 1
    }

    private func previewTask(_ task: TaskItem) -> TaskItem {
        var preview = task
        if let markerID = pendingDrop?.markerID { preview.progressMarkerID = markerID }
        return preview
    }

    private func endDragging() {
        if let draggedTaskID, let drop = pendingDrop {
            let moved = taskStore.move(taskID: draggedTaskID, toGroup: drop.groupID, progressMarkerID: drop.markerID,
                                       before: drop.beforeID, persist: false)
            hasPendingReorder = hasPendingReorder || moved
        }
        if hasPendingReorder { taskStore.persistTaskOrder() }
        clearDragging()
    }

    private func cancelDragging() {
        guard draggedTaskID != nil || hasPendingReorder || pendingDrop != nil else { return }
        // A cancelled gesture never applies its pending group/progress destination.
        if hasPendingReorder { taskStore.cancelTaskOrderChanges() }
        clearDragging()
    }

    private func clearDragging() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { draggedTaskID = nil; dragGroupID = nil; pendingDrop = nil; dragPreviewFrame = nil; dragTranslation = .zero }
        hasPendingReorder = false
    }

    private var emptyState: some View {
        ContentUnavailableView("Nothing completed yet", systemImage: "checkmark.circle",
                               description: Text("Completed plans will appear here."))
            .frame(maxWidth: .infinity, minHeight: 230)
    }

}

private enum TaskCardMetrics {
    static let minimumContentHeight: CGFloat = 44
    static let padding: CGFloat = 14
    static let spacing: CGFloat = 8
    static let progressHeight: CGFloat = 4

    static func minimumHeight(contentHeight: CGFloat, showsProgress: Bool) -> CGFloat {
        max(minimumContentHeight, contentHeight) + padding * 2 + (showsProgress ? spacing + progressHeight : 0)
    }
}

/// Geometry is an input to drag handling, not rendered state. Keep measurements
/// without invalidating the entire list every time the scroll position changes.
private final class TaskFrameCache {
    var origin: CGPoint = .zero
    var rows: [UUID: TaskRowGeometry] = [:]
    struct DropZone { let groupID: UUID?; let markerID: UUID?; let frame: CGRect }
    var dropZones: [DropZone] = []

    /// Expanded header regions can touch; choose the nearest heading deterministically.
    func dropTarget(at point: CGPoint) -> DropZone? {
        var nearest: DropZone?
        for zone in dropZones where zone.frame.contains(point) {
            if let current = nearest {
                let distance = abs(zone.frame.midY - point.y)
                let previous = abs(current.frame.midY - point.y)
                if distance < previous || (distance == previous && zone.markerID != nil && current.markerID == nil) { nearest = zone }
            } else { nearest = zone }
        }
        return nearest
    }

    func replaceProgressFrames(_ frames: [ProgressDropTarget: CGRect]) {
        dropZones = frames.map { DropZone(groupID: $0.key.groupID, markerID: $0.key.markerID, frame: $0.value) }
    }
}

private struct PendingTaskDrop: Equatable {
    let groupID: UUID?
    let markerID: UUID?
    let beforeID: UUID?
    let isGroupHeading: Bool
    var anchorRowID: UUID? = nil
    var placeAfter = false
}

private struct TaskRowGeometry: Equatable {
    let frame: CGRect
    let groupID: UUID?
    let storedGroupID: UUID?
    let markerID: UUID?
}

private struct ProgressDropTarget: Hashable {
    let groupID: UUID?
    let markerID: UUID?
}

private struct ProgressFramePreferenceKey: PreferenceKey {
    static var defaultValue: [ProgressDropTarget: CGRect] = [:]
    static func reduce(value: inout [ProgressDropTarget: CGRect], nextValue: () -> [ProgressDropTarget: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TaskFramePreferenceKey: PreferenceKey { static var defaultValue: [UUID: TaskRowGeometry] = [:]; static func reduce(value: inout [UUID: TaskRowGeometry], nextValue: () -> [UUID: TaskRowGeometry]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) } }

private struct TaskRow: View {
    let task: TaskItem
    let isDeleteVisible: Bool
    let onComplete: () -> Void
    let onTaskTap: () -> Void
    let onLongPress: () -> Void
    let onConfigure: () -> Void
    let onCopy: (() -> Void)?
    let onArchive: (() -> Bool)?
    let onDelete: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    let onDragCancelled: () -> Void
    @EnvironmentObject private var taskStore: TaskStore
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var isTouchActive = false
    @State private var touchBeganAt: Date?
    @State private var isReordering = false
    @ScaledMetric(relativeTo: .body) private var minimumContentHeight = TaskCardMetrics.minimumContentHeight

    var body: some View {
        VStack(alignment: .leading, spacing: TaskCardMetrics.spacing) {
            HStack(spacing: 12) {
                Button(action: onComplete) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Mark \(task.title) active" : "Complete \(task.title)")
                .accessibilityValue(task.isCompleted ? "Completed" : "Active")
                primaryInteraction
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Task details: \(task.title)")
                    .accessibilityValue(task.description)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onTaskTap() }
                    .accessibilityAction(named: "Task details", onLongPress)
                    .accessibilityActions {
                        if let onCopy { Button("Copy", action: onCopy) }
                        if let onArchive { Button("Archive") { _ = onArchive() } }
                        Button("Delete", role: .destructive, action: onDelete)
                    }
                if isDeleteVisible {
                    TaskRemovalButton(task: task, onArchive: onArchive, onDelete: onDelete)
                        .buttonStyle(.bordered)
                        .tint(task.isCompleted ? .accentColor : .red)
                } else if task.isCompleted {
                    Menu {
                        Button("Edit", systemImage: "pencil", action: onConfigure)
                        if let onCopy { Button("Copy", systemImage: "doc.on.doc", action: onCopy) }
                        if let onArchive { Button("Archive", systemImage: "archivebox") { _ = onArchive() } }
                        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Actions for \(task.title)")
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
            if taskStore.progressConfiguration.isEnabled {
                TaskProgressIndicator(task: task).frame(height: TaskCardMetrics.progressHeight)
            }
        }
        .padding(TaskCardMetrics.padding)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("task.card.\(task.title)")
        .onChange(of: isTouchActive) { _, isActive in
            if !isActive { cancelInteraction() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { cancelInteraction() }
        }
        .onDisappear(perform: cancelInteraction)
    }

    @ViewBuilder
    private var primaryInteraction: some View {
        if task.isCompleted || isDeleteVisible {
            taskContent
                .onTapGesture(perform: onTaskTap)
                .onLongPressGesture(perform: onLongPress)
        } else {
            taskContent
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .updating($isTouchActive) { _, isActive, _ in isActive = true }
                .onChanged { value in
                    guard scenePhase == .active else { cancelInteraction(); return }
                    if touchBeganAt == nil { touchBeganAt = Date() }
                    let translation = value.translation
                    let isVerticalMove = abs(translation.height) > abs(translation.width)
                    guard isVerticalMove, abs(translation.height) >= 12 else { return }
                    isReordering = true
                    onDragChanged(value)
                }.onEnded { value in
                    guard scenePhase == .active, let beganAt = touchBeganAt else {
                        cancelInteraction()
                        return
                    }
                    let wasReordering = isReordering
                    let duration = Date().timeIntervalSince(beganAt)
                    touchBeganAt = nil
                    isReordering = false
                    // Clear local state before success can move/remove this row.
                    if wasReordering {
                        onDragEnded(value)
                        return
                    }
                    let translation = value.translation
                    if abs(translation.width) > abs(translation.height), abs(translation.width) >= 45 { return }
                    if duration >= 0.45 { onLongPress() }
                    else { onTaskTap() }
                })
        }
    }

    private func cancelInteraction() {
        let wasReordering = isReordering
        touchBeganAt = nil
        isReordering = false
        if wasReordering { onDragCancelled() }
    }

    private var taskContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(task.title).strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
            if !task.description.isEmpty {
                Text(task.description).lineLimit(1).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: max(TaskCardMetrics.minimumContentHeight, minimumContentHeight), alignment: .leading)
        .contentShape(Rectangle())
    }

}

private struct TaskListOriginPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { value = nextValue() }
}
