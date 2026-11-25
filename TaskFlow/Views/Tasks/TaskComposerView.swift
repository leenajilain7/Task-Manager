import SwiftUI
import SwiftData

struct TaskComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem?
    @State private var title: String
    @State private var taskDescription: String
    @State private var category: TaskCategory
    @State private var priority: TaskPriority
    @State private var dueDate: Date
    @State private var errorMessage: String?

    init(task: TaskItem? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _taskDescription = State(initialValue: task?.taskDescription ?? "")
        _category = State(initialValue: task?.category ?? .personal)
        _priority = State(initialValue: task?.priority ?? .medium)
        _dueDate = State(initialValue: task?.dueDate ?? .now)
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("task.title")
                        .accessibilityIdentifier("task.title")
                    TextField("Description (optional)", text: $taskDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("task.description")
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
                        .accessibilityIdentifier("task.save")
                }
            }
        }
    }

    private func saveTask() {
        do {
            let viewModel = TaskViewModel(context: modelContext)
            if let task {
                try viewModel.updateTask(
                    task,
                    title: title,
                    description: taskDescription,
                    dueDate: dueDate,
                    category: category,
                    priority: priority
                )
            } else {
                try viewModel.createTask(
                    title: title,
                    description: taskDescription,
                    dueDate: dueDate,
                    category: category,
                    priority: priority
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
