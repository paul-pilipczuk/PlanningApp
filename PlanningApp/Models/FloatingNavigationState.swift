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
