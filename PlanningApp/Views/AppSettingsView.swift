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
            VStack(alignment: .leading, spacing: 28) {
                settingsSection("Appearance", footer: "System follows your iPhone’s appearance. Your choice applies throughout Planning.") {
                    VStack(spacing: 0) {
                        ForEach(AppAppearance.allCases) { option in
                            if option != AppAppearance.allCases.first { Divider().padding(.leading, 52) }
                            appearanceButton(option)
                        }
                    }
                }
                settingsSection("Accessibility", footer: "Planning follows your iPhone’s text size, Bold Text, contrast, Reduce Motion, and Reduce Transparency preferences. VoiceOver keeps navigation expanded.") {
                    Toggle("Keep navigation expanded", isOn: $preferences.keepNavigationExpanded)
                        .accessibilityIdentifier("settings.keepNavigationExpanded")
                        .padding(16)
                }
                settingsSection("Interaction", footer: "Control feedback from Planning. Availability also depends on your iPhone’s settings and hardware.") {
                    Toggle("Haptic feedback", isOn: $preferences.hapticFeedback)
                        .accessibilityIdentifier("settings.hapticFeedback")
                        .padding(16)
                }
                settingsSection("Notifications", footer: "Configure reminders in each task. Delivery also depends on your iPhone’s notification and Focus settings.") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Permission", value: notificationStatus)
                            .accessibilityIdentifier("settings.notificationStatus")
                        Divider()
                        Button("Open iPhone Settings", systemImage: "arrow.up.forward.app") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .frame(minHeight: 44)
                    }
                    .padding(16)
                }
                settingsSection("About", footer: "Your plans are stored on this device. Archived tasks remain until you permanently delete them. Device backups are managed separately by iOS.") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Planning", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
                        if taskStore.isSampleData {
                            Divider()
                            Text("Sample data — task changes reset when you relaunch.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                }
            }
            .padding(20)
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

    private func settingsSection<Content: View>(_ title: String, footer: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote).textCase(.uppercase).foregroundStyle(.secondary)
                .padding(.horizontal, 16).accessibilityAddTraits(.isHeader)
            content().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            Text(footer).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
        }
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
