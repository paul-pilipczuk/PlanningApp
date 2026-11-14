import SwiftUI

/// Use the same control-anchored native menu as Archive, rather than a
/// page-wide confirmation dialog whose popover can point into empty space.
struct TaskRemovalButton: View {
    let task: TaskItem
    let onArchive: (() -> Bool)?
    let onDelete: () -> Void

    var body: some View {
        if task.isCompleted {
            Menu {
                if let onArchive {
                    Button("Archive", systemImage: "archivebox") { _ = onArchive() }
                        .accessibilityIdentifier("task.archiveChoice")
                }
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    .accessibilityIdentifier("task.deleteChoice")
            } label: {
                Text("Remove")
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("task.remove.\(task.id)")
        } else {
            Button("Delete", role: .destructive, action: onDelete)
                .accessibilityIdentifier("task.remove.\(task.id)")
        }
    }
}
