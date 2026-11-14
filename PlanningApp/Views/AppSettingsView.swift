import SwiftUI
import UserNotifications

struct AppSettingsView: View {
    let onScrollOffset: (CGFloat) -> Void
    @EnvironmentObject private var taskStore: TaskStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var notificationStatus = "Checking…"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                settingsSection("Appearance") {
                    VStack(spacing: 0) {
                        ForEach(AppAppearance.allCases) { option in
                            if option != AppAppearance.allCases.first { Divider().padding(.leading, 52) }
                            appearanceButton(option)
                        }
                    }
                }
                settingsSection("Accessibility") {
                    Toggle("Keep navigation expanded", isOn: $preferences.keepNavigationExpanded)
                        .accessibilityIdentifier("settings.keepNavigationExpanded")
                        .accessibilityHint("Keeps the tabs visible while scrolling. VoiceOver keeps them expanded automatically.")
                        .padding(16)
                }
                settingsSection("Interaction") {
                    Toggle("Haptic feedback", isOn: $preferences.hapticFeedback)
                        .accessibilityIdentifier("settings.hapticFeedback")
                        .accessibilityHint("Controls Planning’s feedback. Availability also depends on your iPhone’s settings and hardware.")
                        .padding(16)
                }
                settingsSection("Notifications") {
                    VStack(alignment: .leading, spacing: 12) {
                        settingsValue("Permission", value: notificationStatus)
                            .accessibilityIdentifier("settings.notificationStatus")
                        Divider()
                        Button("Settings", systemImage: "arrow.up.forward.app") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .frame(minHeight: 44)
                        .accessibilityLabel("Open iPhone Settings")
                        .accessibilityHint("Manage notification permission in iPhone Settings. Configure reminders in task details.")
                        .accessibilityIdentifier("settings.openSystemSettings")
                    }
                    .padding(16)
                }
                settingsSection("About") {
                    VStack(alignment: .leading, spacing: 12) {
                        settingsValue("Version", value: versionDescription)
                        Text("Plans are stored on this device. Archives stay until you delete them.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if taskStore.isSampleData {
                            Divider()
                            Text("Sample data — task changes reset when you relaunch.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                }
            }
            .padding(16)
            .padding(.bottom, 92)
            .background(TaskScrollContentReader())
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .modifier(TaskScrollObserver(onOffsetChange: onScrollOffset))
        .accessibilityIdentifier("settings.scroll")
        .task { await refreshNotificationStatus() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshNotificationStatus() } }
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).accessibilityAddTraits(.isHeader)
            content().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// Keep words intact when a larger text size cannot fit a label/value pair.
    private func settingsValue(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title).fixedSize()
                Spacer(minLength: 0)
                Text(value).foregroundStyle(.secondary).fixedSize()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                Text(value).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var versionDescription: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return "\(version) (\(build))"
    }

    private func appearanceButton(_ option: AppAppearance) -> some View {
        Button { preferences.appearance = option } label: {
            HStack(spacing: 12) {
                Label(option.title, systemImage: option.systemImage)
                Spacer(minLength: 12)
                if preferences.appearance == option { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .foregroundStyle(Color.accentColor)
            .frame(minHeight: 44)
            .padding(.horizontal, 16).padding(.vertical, 4).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("appearance.\(option.rawValue)")
        .accessibilityHint(option == .system ? "Uses your iPhone’s appearance." : "Applies throughout Planning.")
        .accessibilityAddTraits(preferences.appearance == option ? .isSelected : [])
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard !Task.isCancelled else { return }
        switch settings.authorizationStatus {
        case .notDetermined: notificationStatus = "Not requested"
        case .denied: notificationStatus = "Not allowed"
        case .authorized: notificationStatus = "Allowed"
        case .provisional: notificationStatus = "Quiet delivery"
        case .ephemeral: notificationStatus = "Temporary"
        @unknown default: notificationStatus = "Unknown"
        }
    }
}
