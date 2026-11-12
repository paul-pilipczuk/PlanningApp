import SwiftUI

struct PlanningRootView: View {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: PlanningTab = .active
    @StateObject private var navigation = FloatingNavigationController()
    @State private var isAddingTask = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PlanningPageHeader(tab: selectedTab, isCompact: navigation.isHeaderCompact) {
                    isAddingTask = true
                }
                ZStack {
                    tabContent
                        .id(selectedTab)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // Anchor navigation to the window-sized stack, independently of page layout.
        .overlay(alignment: .bottom) {
            FloatingNavigationBar(selectedTab: selectedTab,
                                  isCollapsed: navigation.isCollapsed && !voiceOverEnabled,
                                  onSelect: selectTab,
                                  onExpand: { navigation.expand() })
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transaction { $0.animation = nil }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        let tab = selectedTab
        switch tab {
        case .active, .completed:
            TaskListView(tab: tab, isAddingTask: $isAddingTask, onScrollOffset: { offset in
                reportScroll(offset, from: tab)
            })
        case .archived:
            ContentUnavailableView("Coming soon", systemImage: "archivebox",
                                   description: Text("Archived plans will have a home here."))
        case .settings:
            AppSettingsView(onScrollOffset: { reportScroll($0, from: .settings) })
        }
    }

    private func reportScroll(_ offset: CGFloat, from tab: PlanningTab) {
        guard tab == selectedTab, !voiceOverEnabled else { return }
        navigation.updateScrollOffset(offset)
    }

    private func selectTab(_ tab: PlanningTab) {
        guard tab != selectedTab else { return }
        navigation.reset()
        withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22)) {
            selectedTab = tab
        }
    }
}

private struct PlanningPageHeader: View {
    let tab: PlanningTab
    let isCompact: Bool
    let onAdd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .largeTitle) private var expandedHeight = 52
    @ScaledMetric(relativeTo: .headline) private var compactHeight = 44

    var body: some View {
        HStack(spacing: 12) {
            if isCompact && tab == .active {
                Color.clear.frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            ZStack(alignment: isCompact ? .center : .leading) {
                if isCompact {
                    title.font(.headline).transition(.opacity)
                } else {
                    title.font(.largeTitle.bold()).transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCompact ? .center : .leading)
            if tab == .active {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .modifier(FloatingControlSurface(opaque: reduceTransparency, isInteractive: true))
                .accessibilityLabel("Add task")
                .accessibilityIdentifier("task.add")
            }
        }
        .frame(minHeight: isCompact ? compactHeight : expandedHeight)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22), value: isCompact)
    }

    private var title: some View {
        Text(tab.title)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("page.title")
    }
}
