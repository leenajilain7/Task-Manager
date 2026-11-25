import SwiftUI
import SwiftData

struct TaskComposerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var taskDescription = ""
    @State private var category: TaskCategory = .personal
    @State private var priority: TaskPriority = .medium
    @State private var dueDate = Date.now
    @State private var errorMessage: String?

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                    TextField("Description (optional)", text: $taskDescription, axis: .vertical)
                        .lineLimit(2...4)
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
            .navigationTitle("New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveTask() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func saveTask() {
        do {
            try TaskViewModel(context: modelContext).createTask(
                title: title,
                description: taskDescription,
                dueDate: dueDate,
                category: category,
                priority: priority
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
