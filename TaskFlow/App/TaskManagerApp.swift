import SwiftUI
import SwiftData

@main
struct TaskManagerApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: TaskItem.self)
        } catch {
            fatalError("Unable to create the task database: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .modelContainer(container)
                .task {
                    do {
                        try LegacyTaskMigration.migrateIfNeeded(in: container.mainContext)
                    } catch {
                        print("Unable to import older tasks: \(error.localizedDescription)")
                    }
                }
        }
    }
}
