import SwiftUI

@main
struct PlanningApp: App {
    @StateObject private var taskStore = TaskStore()
    @AppStorage("appearance") private var appearance: AppAppearance = .dark

    var body: some Scene {
        WindowGroup {
            PlanningRootView()
                .environmentObject(taskStore)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
