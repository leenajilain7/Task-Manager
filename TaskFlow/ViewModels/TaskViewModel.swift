import Foundation
import SwiftData

@MainActor
final class TaskViewModel {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func createTask(
        title: String,
        description: String,
        dueDate: Date,
        category: TaskCategory,
        priority: TaskPriority
    ) throws -> TaskItem {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw TaskValidationError.emptyTitle }
        let existingTasks = try context.fetch(FetchDescriptor<TaskItem>())
        guard !existingTasks.contains(where: { $0.title.localizedCaseInsensitiveCompare(cleanTitle) == .orderedSame }) else {
            throw TaskValidationError.duplicateTitle
        }

        let task = TaskItem(
            title: cleanTitle,
            taskDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            category: category,
            priority: priority
        )
        context.insert(task)
        try context.save()
        return task
    }

    func toggleCompletion(for task: TaskItem) throws {
        task.isComplete.toggle()
        try context.save()
    }

    func delete(_ task: TaskItem) throws {
        context.delete(task)
        try context.save()
    }
}

enum TaskValidationError: LocalizedError {
    case emptyTitle
    case duplicateTitle

    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Add a title before saving this task."
        case .duplicateTitle: "A task with this title already exists. Choose a different title."
        }
    }
}
