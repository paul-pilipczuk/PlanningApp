import SwiftUI

struct AppSettingsView: View {
    let onScrollOffset: (CGFloat) -> Void

    @EnvironmentObject private var taskStore: TaskStore
    @AppStorage("appearance") private var appearance: AppAppearance = .dark

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.footnote)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(AppAppearance.allCases) { option in
                            if option != AppAppearance.allCases.first {
                                Divider().padding(.leading, 52)
                            }
                            appearanceButton(option)
                        }
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                    footer("System follows your iPhone’s appearance. Your choice applies throughout Planning.")
                }
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Planning", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        if taskStore.isSampleData {
                            Divider()
                            Text("Sample data — changes reset when you relaunch.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                    footer("Your plans stay on this device.")
                }
            }
            .padding(20)
            .padding(.bottom, 92)
            .background(TaskScrollContentReader())
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .modifier(TaskScrollObserver(onOffsetChange: onScrollOffset))
        .accessibilityIdentifier("settings.scroll")
    }

    private func appearanceButton(_ option: AppAppearance) -> some View {
        Button {
            appearance = option
        } label: {
            HStack(spacing: 12) {
                Label(option.title, systemImage: option.systemImage)
                Spacer(minLength: 12)
                if appearance == option {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Color.accentColor)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("appearance.\(option.rawValue)")
        .accessibilityAddTraits(appearance == option ? .isSelected : [])
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }
}
