import Combine
import Foundation

enum PlanningTab: String, CaseIterable, Identifiable {
    case active, completed, archived, settings

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .active: "checklist"
        case .completed: "checkmark.circle"
        case .archived: "archivebox"
        case .settings: "gearshape"
        }
    }
}

/// Geometry used by the floating bar, including transient presentation proposals.
struct FloatingNavigationLayout {
    static let padding: CGFloat = 6
    static let spacing: CGFloat = 2
    let containerWidth: CGFloat

    init(containerWidth: CGFloat) {
        // Sheet presentation can briefly propose zero or otherwise unusable geometry.
        self.containerWidth = containerWidth.isFinite ? max(0, containerWidth) : 0
    }

    var selectionWidth: CGFloat {
        let availableWidth = containerWidth - Self.padding * 2 - Self.spacing * CGFloat(PlanningTab.allCases.count - 1)
        return max(0, availableWidth) / CGFloat(PlanningTab.allCases.count)
    }

    func selectionOffset(for tab: PlanningTab) -> CGFloat {
        let index = PlanningTab.allCases.firstIndex(of: tab) ?? 0
        let offset = Self.padding + CGFloat(index) * (selectionWidth + Self.spacing)
        return min(offset, max(0, containerWidth - selectionWidth))
    }
}

/// Tracks actual content movement, independently of how the scroll view reports it.
struct FloatingNavigationState {
    private(set) var isCollapsed = false
    private let collapseThreshold: CGFloat
    private var lastOffset: CGFloat?
    private var downwardStart: CGFloat?

    init(collapseThreshold: CGFloat = 36) {
        self.collapseThreshold = max(1, collapseThreshold)
    }

    mutating func updateScrollOffset(_ offset: CGFloat) {
        guard offset.isFinite else { return }
        let offset = max(0, offset)
        defer { lastOffset = offset }
        guard let lastOffset, let start = downwardStart else {
            downwardStart = offset
            return
        }
        guard !isCollapsed else { return }
        if offset < lastOffset {
            downwardStart = offset
        } else if offset - start >= collapseThreshold {
            isCollapsed = true
        }
    }

    mutating func expand() {
        isCollapsed = false
        downwardStart = lastOffset
    }

    mutating func reset() {
        isCollapsed = false
        lastOffset = nil
        downwardStart = nil
    }
}

/// Publish only visible navigation changes; pixel-by-pixel scroll history stays private.
@MainActor
final class FloatingNavigationController: ObservableObject {
    @Published private(set) var isCollapsed = false
    @Published private(set) var isHeaderCompact = false
    private var state = FloatingNavigationState()

    func updateScrollOffset(_ offset: CGFloat) {
        guard offset.isFinite else { return }
        state.updateScrollOffset(offset)
        // Separate thresholds prevent the header's height change from causing
        // repeated compact/expanded transitions near the top of the list.
        if !isHeaderCompact && offset >= 36 {
            isHeaderCompact = true
        } else if isHeaderCompact && offset <= 4 {
            isHeaderCompact = false
        }
        publishVisibleChange()
    }

    func expand() {
        state.expand()
        publishVisibleChange()
    }

    func reset() {
        state.reset()
        if isHeaderCompact { isHeaderCompact = false }
        publishVisibleChange()
    }

    private func publishVisibleChange() {
        guard isCollapsed != state.isCollapsed else { return }
        isCollapsed = state.isCollapsed
    }
}
