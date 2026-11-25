import Foundation
import SwiftData

enum TaskCategory: String, CaseIterable, Identifiable {
    case personal = "Personal"
    case work = "Work"
    case study = "Study"
    case shopping = "Shopping"
    case health = "Health"
    case other = "Other"

    var id: String { rawValue }
}

enum TaskPriority: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var taskDescription: String
    var dueDate: Date
    var categoryValue: String
    var priorityValue: String
    var isComplete: Bool
    var createdAt: Date

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryValue) ?? .other }
        set { categoryValue = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityValue) ?? .medium }
        set { priorityValue = newValue.rawValue }
    }

    init(
        title: String,
        taskDescription: String = "",
        dueDate: Date = .now,
        category: TaskCategory = .personal,
        priority: TaskPriority = .medium,
        isComplete: Bool = false,
        createdAt: Date = .now,
        id: UUID = UUID()
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.dueDate = dueDate
        self.categoryValue = category.rawValue
        self.priorityValue = priority.rawValue
        self.isComplete = isComplete
        self.createdAt = createdAt
    }
}
