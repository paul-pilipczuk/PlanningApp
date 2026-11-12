import SwiftUI

struct FloatingNavigationBar: View {
    let selectedTab: PlanningTab
    let isCollapsed: Bool
    let onSelect: (PlanningTab) -> Void
    let onExpand: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                if isCollapsed {
                    Button(action: onExpand) {
                        Image(systemName: selectedTab.systemImage)
                            .font(.system(size: 23, weight: .medium))
                            .frame(width: 60, height: 60)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Expand navigation")
                    .accessibilityValue(selectedTab.title)
                    .accessibilityHint("Shows Active, Completed, Archived, and Settings.")
                    .accessibilityIdentifier("navigation.expand")
                    .transition(.opacity)
                } else {
                    HStack(spacing: 2) {
                        ForEach(PlanningTab.allCases) { tab in
                            tabButton(tab)
                        }
                    }
                    .padding(6)
                    .frame(width: proxy.size.width, height: 72)
                    .background(alignment: .leading) {
                        let tabWidth = (proxy.size.width - 18) / 4
                        let index = PlanningTab.allCases.firstIndex(of: selectedTab) ?? 0
                        Capsule()
                            .fill(Color.primary.opacity(0.10))
                            .frame(width: tabWidth, height: 60)
                            .offset(x: 6 + CGFloat(index) * (tabWidth + 2))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: isCollapsed ? 60 : proxy.size.width, height: isCollapsed ? 60 : 72)
            .modifier(NavigationSurface(opaque: reduceTransparency))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: selectedTab)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.86), value: isCollapsed)
        }
        // Keep overlay bounds stable while the visible bar changes shape.
        .frame(height: 76)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navigation")
    }

    private func tabButton(_ tab: PlanningTab) -> some View {
        Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 21, weight: .medium))
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(tab.title)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())

        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
        .accessibilityIdentifier("tab.\(tab.rawValue)")
        .accessibilityShowsLargeContentViewer {
            Label(tab.title, systemImage: tab.systemImage)
        }
    }
}

private struct NavigationSurface: ViewModifier {
    let opaque: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if opaque {
            content.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                .overlay { Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5) }
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5) }
        }
    }
}
