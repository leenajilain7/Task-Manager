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

    func updateTask(
        _ task: TaskItem,
        title: String,
        description: String,
        dueDate: Date,
        category: TaskCategory,
        priority: TaskPriority
    ) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw TaskValidationError.emptyTitle }
        let existingTasks = try context.fetch(FetchDescriptor<TaskItem>())
        guard !existingTasks.contains(where: {
            $0.id != task.id && $0.title.localizedCaseInsensitiveCompare(cleanTitle) == .orderedSame
        }) else {
            throw TaskValidationError.duplicateTitle
        }

        let oldValues = (task.title, task.taskDescription, task.dueDate, task.category, task.priority)
        task.title = cleanTitle
        task.taskDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueDate = dueDate
        task.category = category
        task.priority = priority
        do {
            try context.save()
        } catch {
            task.title = oldValues.0
            task.taskDescription = oldValues.1
            task.dueDate = oldValues.2
            task.category = oldValues.3
            task.priority = oldValues.4
            throw error
        }
    }

    func toggleCompletion(for task: TaskItem) throws {
        task.isComplete.toggle()
        task.completedAt = task.isComplete ? .now : nil
        try context.save()
    }

    func delete(_ task: TaskItem) throws {
        context.delete(task)
        try context.save()
    }

    func filteredTasks(
        _ tasks: [TaskItem],
        searchText: String,
        status: TaskListStatus,
        sort: TaskSortOption
    ) -> [TaskItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = tasks.filter { task in
            let matchesStatus = status == .all || task.isComplete == (status == .completed)
            let matchesSearch = query.isEmpty || task.title.localizedCaseInsensitiveContains(query)
            return matchesStatus && matchesSearch
        }

        switch sort {
        case .dueDate:
            return matching.sorted { $0.dueDate < $1.dueDate }
        case .priority:
            return matching.sorted {
                if $0.priority.sortOrder == $1.priority.sortOrder { return $0.dueDate < $1.dueDate }
                return $0.priority.sortOrder > $1.priority.sortOrder
            }
        }
    }
}

enum TaskListStatus: String, CaseIterable, Identifiable {
    case all, pending, completed
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum TaskSortOption: String, CaseIterable, Identifiable {
    case dueDate, priority
    var id: String { rawValue }
    var title: String { self == .dueDate ? "Due date" : "Priority" }
}

private extension TaskPriority {
    var sortOrder: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
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
