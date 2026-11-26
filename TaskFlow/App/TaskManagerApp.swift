import SwiftUI
import SwiftData

@MainActor
@main
struct TaskManagerApp: App {
    private let container: ModelContainer?
    private let startupError: String?
    private let notificationService = NotificationService()
    @State private var migrationError: String?

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
                        .environment(notificationService)
                        .task {
                            do {
                                try LegacyTaskMigration.migrateIfNeeded(in: container.mainContext)
                            } catch {
                                migrationError = error.localizedDescription
                            }
                        }
                        .alert("Couldn’t import older tasks", isPresented: Binding(
                            get: { migrationError != nil },
                            set: { if !$0 { migrationError = nil } }
                        )) {
                            Button("OK", role: .cancel) { migrationError = nil }
                        } message: {
                            Text(migrationError ?? "Please restart TaskFlow and try again.")
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
