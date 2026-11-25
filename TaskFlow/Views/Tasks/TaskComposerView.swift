import SwiftUI
import SwiftData

struct TaskComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationService.self) private var notificationService
    let task: TaskItem?
    @State private var title: String
    @State private var taskDescription: String
    @State private var category: TaskCategory
    @State private var priority: TaskPriority
    @State private var dueDate: Date
    @State private var reminderEnabled: Bool
    @State private var reminderDate: Date
    @State private var errorMessage: String?

    init(task: TaskItem? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _taskDescription = State(initialValue: task?.taskDescription ?? "")
        _category = State(initialValue: task?.category ?? TaskFlowPreferences().defaultCategory)
        _priority = State(initialValue: task?.priority ?? TaskFlowPreferences().defaultPriority)
        _dueDate = State(initialValue: task?.dueDate ?? .now)
        _reminderEnabled = State(initialValue: task.map { $0.reminderDate != nil } ?? TaskFlowPreferences().defaultReminderEnabled)
        _reminderDate = State(initialValue: task?.reminderDate ?? Date.now.addingTimeInterval(3600))
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("task.title")
                    TextField("Description (optional)", text: $taskDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("task.description")
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases) { option in Text(option.rawValue).tag(option) }
                    }
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { option in Text(option.rawValue).tag(option) }
                    }
                }
                Section("Schedule") {
                    DatePicker("Due date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    Toggle("Enable reminder", isOn: $reminderEnabled)
                        .accessibilityIdentifier("task.reminderEnabled")
                    if reminderEnabled {
                        DatePicker("Remind me", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                            .accessibilityIdentifier("task.reminderDate")
                        Button("Clear reminder", role: .destructive) { reminderEnabled = false }
                            .accessibilityIdentifier("task.clearReminder")
                        if !TaskReminderDateValidator.isFuture(reminderDate) {
                            Label("Choose a reminder time in the future.", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 12)).foregroundStyle(.red)
                                .accessibilityIdentifier("task.invalidReminder")
                        }
                        if !notificationService.isReminderPreferenceEnabled {
                            Text("Task reminders are turned off in Settings.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil ? "Add" : "Save") { saveTask() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("task.save")
                }
            }
        }
    }

    private func saveTask() {
        guard !reminderEnabled || TaskReminderDateValidator.isFuture(reminderDate) else {
            errorMessage = TaskValidationError.invalidReminderDate.localizedDescription
            return
        }

        do {
            let viewModel = TaskViewModel(context: modelContext)
            let savedTask: TaskItem
            if let task {
                try viewModel.updateTask(
                    task,
                    title: title,
                    description: taskDescription,
                    dueDate: dueDate,
                    category: category,
                    priority: priority,
                    reminderDate: reminderEnabled ? reminderDate : nil
                )
                savedTask = task
            } else {
                savedTask = try viewModel.createTask(
                    title: title,
                    description: taskDescription,
                    dueDate: dueDate,
                    category: category,
                    priority: priority,
                    reminderDate: reminderEnabled ? reminderDate : nil
                )
            }
            TaskFlowHaptics.success()
            dismiss()
            Task {
                await TaskReminderCoordinator(service: notificationService).synchronize(savedTask)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
