import SwiftUI
import UIKit

struct PlanningRootView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var taskStore: TaskStore
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: PlanningTab = .active
    @StateObject private var navigation = FloatingNavigationController()
    @State private var isAddingTask = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    PlanningPageHeader(tab: selectedTab, isCompact: navigation.isHeaderCompact) {
                        isAddingTask = true
                    }
                    .disabled(taskStore.hasLoadFailure)
                    if !taskStore.hasLoadFailure, let message = taskStore.errorMessage ?? taskStore.feedbackMessage {
                        HStack(alignment: .top) {
                            Text(message).font(.footnote).lineLimit(3).accessibilityLabel(message)
                            Spacer(minLength: 8)
                            Button {
                                taskStore.dismissError()
                                taskStore.feedbackMessage = nil
                            } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }
                            .accessibilityLabel("Dismiss message")
                        }
                        .padding(.horizontal, 16)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .accessibilityIdentifier("task.feedback")
                    }
                }
                .background(pageBackground)
                .overlay(alignment: .bottom) {
                    HeaderScrollEdge(background: pageBackground)
                        .frame(height: 24)
                        .offset(y: 24)
                        .opacity(navigation.isHeaderCompact ? 1 : 0)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .zIndex(1)
                ZStack {
                    tabContent
                        .id(selectedTab)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(pageBackground)
            .toolbar(.hidden, for: .navigationBar)
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            taskStore.releasePresentationCaches()
        }
        .onChange(of: preferences.keepNavigationExpanded) { _, _ in navigation.expand() }
        .onChange(of: taskStore.feedbackMessage) { _, message in
            if let message { UIAccessibility.post(notification: .announcement, argument: message) }
        }
        // Anchor navigation to the window-sized stack, independently of page layout.
        .overlay(alignment: .bottom) {
            FloatingNavigationBar(selectedTab: selectedTab,
                                  isCollapsed: navigation.isCollapsed && !voiceOverEnabled && !preferences.keepNavigationExpanded,
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
        if taskStore.hasLoadFailure && tab != .settings {
            ContentUnavailableView {
                Label("Couldn’t Load Plans", systemImage: "exclamationmark.triangle")
            } description: {
                Text(taskStore.errorMessage ?? "Your saved file has been left untouched.")
            } actions: {
                Button("Try Again") { taskStore.reload() }.buttonStyle(.bordered)
            }
        } else {
            switch tab {
            case .active, .completed:
                TaskListView(tab: tab, isAddingTask: $isAddingTask, onScrollOffset: { reportScroll($0, from: tab) }, onTaskCreated: { selectTab(.active) })
            case .archived:
                ArchiveView(onScrollOffset: { reportScroll($0, from: .archived) }, onTaskCreated: { selectTab(.active) })
            case .settings:
                AppSettingsView(onScrollOffset: { reportScroll($0, from: .settings) })
            }
        }
    }

    private var pageBackground: Color {
        Color(uiColor: selectedTab == .settings ? .systemGroupedBackground : .systemBackground)
    }

    private func reportScroll(_ offset: CGFloat, from tab: PlanningTab) {
        guard tab == selectedTab else { return }
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
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .largeTitle) private var expandedHeight = 52
    @ScaledMetric(relativeTo: .headline) private var compactHeight = 44

    var body: some View {
        ZStack(alignment: isCompact ? .center : .leading) {
            if isCompact {
                title.font(.headline).transition(.opacity)
            } else {
                title.font(.largeTitle.bold()).transition(.opacity)
            }
        }
        .padding(.horizontal, isCompact && tab == .active ? 56 : 0)
        .padding(.trailing, !isCompact && tab == .active ? 56 : 0)
        .frame(maxWidth: .infinity, minHeight: isCompact ? compactHeight : expandedHeight,
               alignment: isCompact ? .center : .leading)
        .overlay(alignment: .trailing) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background {
            if isCompact && !reduceTransparency && contrast != .increased {
                Rectangle().fill(.regularMaterial)
            } else {
                Color(uiColor: tab == .settings ? .systemGroupedBackground : .systemBackground)
            }
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22), value: isCompact)
    }

    private var title: some View {
        Text(tab.title)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("page.title")
    }
}

/// A small, static material surface feathers moving content into the header.
/// It does not blur or snapshot the full list, and never intercepts touches.
private struct HeaderScrollEdge: View {
    let background: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if reduceTransparency || contrast == .increased {
            background
        } else {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom))
                background
                    .mask(LinearGradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white.opacity(0.85), location: 0.2),
                        .init(color: .clear, location: 1)
                    ], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}
