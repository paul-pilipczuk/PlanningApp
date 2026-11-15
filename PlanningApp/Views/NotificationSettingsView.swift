import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reminder: ReminderSettings

    let task: TaskItem
    let onSave: (ReminderSettings) -> Void

    init(task: TaskItem, onSave: @escaping (ReminderSettings) -> Void) {
        self.task = task
        self.onSave = onSave
        _reminder = State(initialValue: task.reminder)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") { ReminderScheduleFields(reminder: $reminder) }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(reminder); dismiss() }
                }
            }
        }
    }
}

/// Keep the task editor and standalone reminder form on the same schedule controls.
struct ReminderScheduleFields: View {
    @Binding var reminder: ReminderSettings
    @Environment(\.calendar) private var calendar

    private var weekdays: [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    var body: some View {
        Toggle("Notifications", isOn: $reminder.isEnabled)
            .accessibilityIdentifier("reminder.enabled")
        if reminder.isEnabled {
            Picker("Frequency", selection: $reminder.frequency) {
                ForEach(ReminderFrequency.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("reminder.frequency")
            if reminder.frequency == .weekly {
                Picker("Day", selection: $reminder.weekday) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(calendar.weekdaySymbols[day - 1]).tag(day)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("reminder.weekday")
            }
            DatePicker("Time", selection: Binding(get: { reminder.time }, set: { reminder.setTime($0) }),
                       displayedComponents: .hourAndMinute)
                .accessibilityIdentifier("reminder.time")
            Toggle("Repeat until done", isOn: $reminder.repeatsUntilCompleted)
                .accessibilityIdentifier("reminder.repeat")
        }
    }
}
