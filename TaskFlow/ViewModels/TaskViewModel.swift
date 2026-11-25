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
        priority: TaskPriority,
        reminderDate: Date? = nil
    ) throws -> TaskItem {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw TaskValidationError.emptyTitle }
        try validateDueDate(dueDate)
        try validateReminderDate(reminderDate)
        let existingTasks = try context.fetch(FetchDescriptor<TaskItem>())
        guard !existingTasks.contains(where: { $0.title.localizedCaseInsensitiveCompare(cleanTitle) == .orderedSame }) else {
            throw TaskValidationError.duplicateTitle
        }

        let task = TaskItem(
            title: cleanTitle,
            taskDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: dueDate,
            category: category,
            priority: priority,
            reminderDate: reminderDate
        )
        context.insert(task)
        do {
            try context.save()
        } catch {
            context.delete(task)
            throw error
        }
        return task
    }

    func updateTask(
        _ task: TaskItem,
        title: String,
        description: String,
        dueDate: Date,
        category: TaskCategory,
        priority: TaskPriority,
        reminderDate: Date? = nil
    ) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw TaskValidationError.emptyTitle }
        try validateDueDate(dueDate)
        try validateReminderDate(reminderDate)
        guard let storedTask = try storedTask(withID: task.id) else { throw TaskOperationError.taskNotFound }
        let existingTasks = try context.fetch(FetchDescriptor<TaskItem>())
        guard !existingTasks.contains(where: {
            $0.id != storedTask.id && $0.title.localizedCaseInsensitiveCompare(cleanTitle) == .orderedSame
        }) else {
            throw TaskValidationError.duplicateTitle
        }

        let oldValues = (storedTask.title, storedTask.taskDescription, storedTask.dueDate, storedTask.category, storedTask.priority, storedTask.reminderDate)
        storedTask.title = cleanTitle
        storedTask.taskDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        storedTask.dueDate = dueDate
        storedTask.category = category
        storedTask.priority = priority
        storedTask.reminderDate = reminderDate
        do {
            try context.save()
        } catch {
            storedTask.title = oldValues.0
            storedTask.taskDescription = oldValues.1
            storedTask.dueDate = oldValues.2
            storedTask.category = oldValues.3
            storedTask.priority = oldValues.4
            storedTask.reminderDate = oldValues.5
            throw error
        }
    }

    func toggleCompletion(for task: TaskItem) throws {
        guard let storedTask = try storedTask(withID: task.id) else { throw TaskOperationError.taskNotFound }
        let wasComplete = storedTask.isComplete
        let previousCompletionDate = storedTask.completedAt
        storedTask.isComplete.toggle()
        storedTask.completedAt = storedTask.isComplete ? .now : nil
        do {
            try context.save()
        } catch {
            storedTask.isComplete = wasComplete
            storedTask.completedAt = previousCompletionDate
            throw error
        }
    }

    func delete(_ task: TaskItem) throws {
        guard let storedTask = try storedTask(withID: task.id) else { throw TaskOperationError.taskNotFound }
        context.delete(storedTask)
        do {
            try context.save()
        } catch {
            context.insert(storedTask)
            throw error
        }
    }

    func filteredTasks(
        _ tasks: [TaskItem],
        searchText: String,
        status: TaskListStatus,
        sort: TaskSortOption,
        priority: TaskPriority? = nil
    ) -> [TaskItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = tasks.filter { task in
            let matchesStatus = status == .all || task.isComplete == (status == .completed)
            let matchesSearch = query.isEmpty || task.title.localizedCaseInsensitiveContains(query)
            let matchesPriority = priority == nil || task.priority == priority
            return matchesStatus && matchesSearch && matchesPriority
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

    private func storedTask(withID id: UUID) throws -> TaskItem? {
        let taskID = id
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func validateDueDate(_ dueDate: Date) throws {
        guard dueDate.timeIntervalSince1970.isFinite else { throw TaskValidationError.invalidDueDate }
    }

    private func validateReminderDate(_ reminderDate: Date?) throws {
        guard let reminderDate else { return }
        guard TaskReminderDateValidator.isFuture(reminderDate) else {
            throw TaskValidationError.invalidReminderDate
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

enum TaskValidationError: LocalizedError, Equatable {
    case emptyTitle
    case duplicateTitle
    case invalidDueDate
    case invalidReminderDate

    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Add a title before saving this task."
        case .duplicateTitle: "A task with this title already exists. Choose a different title."
        case .invalidDueDate: "Choose a valid due date before saving this task."
        case .invalidReminderDate: "Choose a reminder time in the future."
        }
    }
}

enum TaskOperationError: LocalizedError, Equatable {
    case taskNotFound

    var errorDescription: String? { "This task is no longer available. Refresh the list and try again." }
}
