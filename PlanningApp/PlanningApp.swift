import SwiftUI

@main
struct PlanningApp: App {
    @StateObject private var taskStore = TaskStore()

    var body: some Scene {
        WindowGroup {
            TaskListView()
                .environmentObject(taskStore)
                .preferredColorScheme(.dark)
        }
    }
}
