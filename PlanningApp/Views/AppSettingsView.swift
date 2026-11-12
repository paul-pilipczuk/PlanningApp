import SwiftUI

struct AppSettingsView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @AppStorage("appearance") private var appearance: AppAppearance = .dark

    var body: some View {
        Form {
            Section {
                ForEach(AppAppearance.allCases) { option in
                    Button {
                        appearance = option
                    } label: {
                        HStack(spacing: 12) {
                            Label(option.title, systemImage: option.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            if appearance == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("appearance.\(option.rawValue)")
                    .accessibilityAddTraits(appearance == option ? .isSelected : [])
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("System follows your iPhone’s appearance. Your choice applies throughout Planning.")
            }
            Section {
                LabeledContent("Planning", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                if taskStore.isSampleData {
                    Text("Sample data — changes reset when you relaunch.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Your plans stay on this device.")
            }
        }
    }
}
