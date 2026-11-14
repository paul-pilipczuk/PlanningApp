import SwiftUI

@main
struct PlanningApp: App {
    @StateObject private var taskStore = TaskStore()
    @StateObject private var preferences = AppPreferences()

    var body: some Scene {
        WindowGroup {
            PlanningRootView()
                .environmentObject(taskStore)
                .environmentObject(preferences)
                .preferredColorScheme(preferences.appearance.colorScheme)
        }
    }
}
