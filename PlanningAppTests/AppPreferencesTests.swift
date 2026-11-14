import XCTest
@testable import PlanningApp

@MainActor
final class AppPreferencesTests: XCTestCase {
    func testDefaultsAndPersistedPreferencesKeepAppearanceCompatible() throws {
        let suite = "PlanningTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = AppPreferences(defaults: defaults)
        XCTAssertEqual(prefs.appearance, .dark)
        XCTAssertFalse(prefs.keepNavigationExpanded)
        XCTAssertTrue(prefs.hapticFeedback)
        prefs.appearance = .light
        prefs.keepNavigationExpanded = true
        prefs.hapticFeedback = false
        let reopened = AppPreferences(defaults: defaults)
        XCTAssertEqual(reopened.appearance, .light)
        XCTAssertTrue(reopened.keepNavigationExpanded)
        XCTAssertFalse(reopened.hapticFeedback)
        XCTAssertEqual(defaults.string(forKey: "appearance"), "light")
    }
}
