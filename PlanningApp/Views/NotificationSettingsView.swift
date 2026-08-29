import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabled: Bool
    @State private var frequency: ReminderFrequency
    @State private var time: Date
    @State private var weekday: Int
    @State private var repeatsUntilCompleted: Bool

    let task: TaskItem
    let onSave: (ReminderSettings) -> Void

    init(task: TaskItem, onSave: @escaping (ReminderSettings) -> Void) {
        self.task = task
        self.onSave = onSave
        _isEnabled = State(initialValue: task.reminder.isEnabled)
        _frequency = State(initialValue: task.reminder.frequency)
        _time = State(initialValue: task.reminder.time)
        _weekday = State(initialValue: task.reminder.weekday)
        _repeatsUntilCompleted = State(initialValue: task.reminder.repeatsUntilCompleted)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Notifications", isOn: $isEnabled)
                }

                if isEnabled {
                    Section("Schedule") {
                        Picker("Frequency", selection: $frequency) {
                            ForEach(ReminderFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)

                        if frequency == .weekly {
                            Picker("Day", selection: $weekday) {
                                ForEach(1...7, id: \.self) { day in
                                    Text(weekdayName(for: day)).tag(day)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)

                        Button {
                            repeatsUntilCompleted.toggle()
                        } label: {
                            HStack {
                                Image(systemName: repeatsUntilCompleted ? "checkmark.square.fill" : "square")
                                Text("Repeat until done")
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Repeat until done")
                        .accessibilityValue(repeatsUntilCompleted ? "On" : "Off")
                    }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        var reminder = ReminderSettings()
                        reminder.isEnabled = isEnabled
                        reminder.frequency = frequency
                        reminder.weekday = weekday
                        reminder.repeatsUntilCompleted = repeatsUntilCompleted
                        reminder.setTime(time)
                        onSave(reminder)
                        dismiss()
                    }
                }
            }
        }
    }

    private func weekdayName(for weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }
}
