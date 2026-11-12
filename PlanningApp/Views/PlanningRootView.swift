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
                pageHeader
                ZStack {
                    tabContent
                        .id(selectedTab)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            // Keep the bar outside the changing screen's identity so its selection survives.
            .overlay(alignment: .bottom) {
                FloatingNavigationBar(selectedTab: selectedTab,
                                      isCollapsed: navigation.isCollapsed && !voiceOverEnabled,
                                      onSelect: selectTab,
                                      onExpand: { navigation.expand() })
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(selectedTab.title)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("page.title")
            Spacer(minLength: 12)
            if selectedTab == .active {
                Button {
                    isAddingTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Add task")
                .accessibilityIdentifier("task.add")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .active, .completed:
            TaskListView(tab: selectedTab, isAddingTask: $isAddingTask, onScrollOffset: { offset in
                guard !voiceOverEnabled else { return }
                navigation.updateScrollOffset(offset)
            })
        case .archived:
            ContentUnavailableView("Coming soon", systemImage: "archivebox",
                                   description: Text("Archived plans will have a home here."))
        case .settings:
            AppSettingsView()
                .safeAreaPadding(.bottom, 92)
        }
    }

    private func selectTab(_ tab: PlanningTab) {
        guard tab != selectedTab else { return }
        navigation.reset()
        withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22)) {
            selectedTab = tab
        }
    }
}
