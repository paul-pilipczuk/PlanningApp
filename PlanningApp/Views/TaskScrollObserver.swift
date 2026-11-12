import SwiftUI

/// Native scroll geometry on iOS 18+, with a preference-based iOS 17 fallback.
struct TaskScrollObserver: ViewModifier {
    let onOffsetChange: (CGFloat) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                let maximum = max(0, geometry.contentSize.height + geometry.contentInsets.top
                                  + geometry.contentInsets.bottom - geometry.containerSize.height)
                return min(maximum, max(0, geometry.contentOffset.y + geometry.contentInsets.top))
            } action: { _, offset in
                onOffsetChange(offset)
            }
        } else {
            content
                .coordinateSpace(name: "taskScroll")
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: TaskScrollMetricsKey.self,
                                               value: TaskScrollMetrics(viewportHeight: proxy.size.height))
                    }
                }
                .onPreferenceChange(TaskScrollMetricsKey.self) { metrics in
                    let maximum = max(0, metrics.contentHeight - metrics.viewportHeight)
                    onOffsetChange(min(maximum, max(0, -metrics.contentMinY)))
                }
        }
    }
}

struct TaskScrollContentReader: View {
    var body: some View {
        if #unavailable(iOS 18.0) {
            GeometryReader { proxy in
                Color.clear.preference(key: TaskScrollMetricsKey.self,
                                       value: TaskScrollMetrics(contentHeight: proxy.size.height,
                                                                contentMinY: proxy.frame(in: .named("taskScroll")).minY))
            }
        }
    }
}

private struct TaskScrollMetrics: Equatable {
    var contentHeight: CGFloat = 0
    var contentMinY: CGFloat = 0
    var viewportHeight: CGFloat = 0
}

private struct TaskScrollMetricsKey: PreferenceKey {
    static var defaultValue = TaskScrollMetrics()

    static func reduce(value: inout TaskScrollMetrics, nextValue: () -> TaskScrollMetrics) {
        let next = nextValue()
        if next.contentHeight > 0 {
            value.contentHeight = next.contentHeight
            value.contentMinY = next.contentMinY
        }
        if next.viewportHeight > 0 { value.viewportHeight = next.viewportHeight }
    }
}
