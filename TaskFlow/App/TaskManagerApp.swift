import SwiftUI
import SwiftData

@main
struct TaskManagerApp: App {
    private let container: ModelContainer?
    private let startupError: String?

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
        do {
            container = try ModelContainer(for: TaskItem.self, configurations: configuration)
            startupError = nil
        } catch {
            container = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootTabView()
                        .modelContainer(container)
                        .task {
                            do {
                                try LegacyTaskMigration.migrateIfNeeded(in: container.mainContext)
                            } catch {
                                print("Unable to import older tasks: \(error.localizedDescription)")
                            }
                        }
                } else {
                    ContentUnavailableView(
                        "TaskFlow couldn’t open",
                        systemImage: "externaldrive.badge.exclamationmark",
                        description: Text(startupError ?? "The task database could not be opened.")
                    )
                    .accessibilityIdentifier("app.startupError")
                }
            }
        }
    }
}
