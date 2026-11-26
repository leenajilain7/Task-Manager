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
        let existingIDs = Set(try context.fetch(FetchDescriptor<TaskItem>()).map(\.id))
        var importedIDs = existingIDs
        do {
            for legacy in legacyTasks where importedIDs.insert(legacy.id).inserted {
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
            // Mark completion only after SwiftData has durably saved the imported records.
            // Keeping the source payload until afterward makes a launch interruption retryable.
            defaults.set(true, forKey: completedKey)
            defaults.removeObject(forKey: tasksKey)
        } catch {
            context.rollback()
            throw error
        }
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
