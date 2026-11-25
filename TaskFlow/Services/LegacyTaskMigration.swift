import Foundation
import SwiftData

enum LegacyTaskMigration {
    private static let tasksKey = "task-manager.tasks.v1"
    private static let completedKey = "task-manager.swiftdata-migration.v1"

    static func migrateIfNeeded(in context: ModelContext) throws {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: completedKey) else { return }
        guard let data = defaults.data(forKey: tasksKey) else {
            defaults.set(true, forKey: completedKey)
            return
        }

        let legacyTasks = try JSONDecoder().decode([LegacyTask].self, from: data)
        for legacy in legacyTasks {
            let category = TaskCategory(rawValue: legacy.category) ?? .other
            context.insert(TaskItem(
                title: legacy.title,
                taskDescription: legacy.notes,
                dueDate: legacy.dueDate,
                category: category,
                isComplete: legacy.isComplete,
                id: legacy.id
            ))
        }
        try context.save()
        defaults.removeObject(forKey: tasksKey)
        defaults.set(true, forKey: completedKey)
    }
}

private struct LegacyTask: Decodable {
    let id: UUID
    let title: String
    let notes: String
    let category: String
    let dueDate: Date
    let isComplete: Bool
}
