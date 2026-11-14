import Combine
import Foundation

@MainActor
final class AppPreferences: ObservableObject {
    private let defaults: UserDefaults

    @Published var appearance: AppAppearance {
        didSet { if appearance != oldValue { defaults.set(appearance.rawValue, forKey: "appearance") } }
    }
    @Published var keepNavigationExpanded: Bool {
        didSet { if keepNavigationExpanded != oldValue { defaults.set(keepNavigationExpanded, forKey: "keepNavigationExpanded") } }
    }
    @Published var hapticFeedback: Bool {
        didSet { if hapticFeedback != oldValue { defaults.set(hapticFeedback, forKey: "hapticFeedback") } }
    }

    convenience init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            let name = "com.local.PlanningApp.UITests"
            guard let defaults = UserDefaults(suiteName: name) else { preconditionFailure("UI-test preferences unavailable") }
            if ProcessInfo.processInfo.arguments.contains("-reset-test-preferences") { defaults.removePersistentDomain(forName: name) }
            self.init(defaults: defaults)
            return
        }
        #endif
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        appearance = defaults.string(forKey: "appearance").flatMap(AppAppearance.init(rawValue:)) ?? .dark
        keepNavigationExpanded = defaults.bool(forKey: "keepNavigationExpanded")
        hapticFeedback = defaults.object(forKey: "hapticFeedback") as? Bool ?? true
    }
}
