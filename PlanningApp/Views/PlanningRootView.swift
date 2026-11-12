import SwiftUI

struct PlanningRootView: View {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: PlanningTab = .active
    @State private var navigation = FloatingNavigationState()

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .active, .completed:
                    TaskListView(tab: selectedTab, onScrollOffset: { offset in
                        guard !voiceOverEnabled else { return }
                        navigation.updateScrollOffset(offset)
                    })
                case .archived:
                    ContentUnavailableView("Coming soon", systemImage: "archivebox",
                                           description: Text("Archived plans will have a home here."))
                case .settings:
                    AppSettingsView()
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(selectedTab.title)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingNavigationBar(selectedTab: selectedTab,
                                      isCollapsed: navigation.isCollapsed && !voiceOverEnabled,
                                      onSelect: selectTab,
                                      onExpand: { navigation.expand() })
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
    }

    private func selectTab(_ tab: PlanningTab) {
        guard tab != selectedTab else { return }
        navigation.reset()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            selectedTab = tab
        }
    }
}
