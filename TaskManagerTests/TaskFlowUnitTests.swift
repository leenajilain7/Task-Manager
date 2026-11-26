import Foundation
import SwiftData
import Testing
@testable import TaskManager

private struct InMemoryTaskStore {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: TaskItem.self, configurations: configuration)
        context = ModelContext(container)
    }
}

private enum TestDateError: Error {
    case invalidDate
}

private func isoDate(_ value: String) throws -> Date {
    guard let date = ISO8601DateFormatter().date(from: value) else { throw TestDateError.invalidDate }
    return date
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}

private enum TaskItemBeforeReminderSchema {
    @Model
    final class TaskItem {
        @Attribute(.unique) var id: UUID
        var title: String
        var taskDescription: String
        var dueDate: Date
        var categoryValue: String
        var priorityValue: String
        var isComplete: Bool
        var completedAt: Date?
        var createdAt: Date

        init(
            id: UUID,
            title: String,
            taskDescription: String,
            dueDate: Date,
            categoryValue: String,
            priorityValue: String,
            isComplete: Bool,
            completedAt: Date?,
            createdAt: Date
        ) {
            self.id = id
            self.title = title
            self.taskDescription = taskDescription
            self.dueDate = dueDate
            self.categoryValue = categoryValue
            self.priorityValue = priorityValue
            self.isComplete = isComplete
            self.completedAt = completedAt
            self.createdAt = createdAt
        }
    }
}

@Suite("TaskFlow preferences")
struct TaskFlowPreferencesTests {
    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "TaskFlowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func appearancePreferencePersistsAcrossInstances() {
        let defaults = isolatedDefaults()
        TaskFlowPreferences(defaults: defaults).appearance = .dark

        #expect(TaskFlowPreferences(defaults: defaults).appearance == .dark)
    }

    @Test func defaultPriorityAndCategoryPersist() {
        let defaults = isolatedDefaults()
        let preferences = TaskFlowPreferences(defaults: defaults)
        preferences.defaultPriority = .high
        preferences.defaultCategory = .study

        #expect(TaskFlowPreferences(defaults: defaults).defaultPriority == .high)
        #expect(TaskFlowPreferences(defaults: defaults).defaultCategory == .study)
    }

    @Test func reminderAndHapticPreferencesPersist() {
        let defaults = isolatedDefaults()
        let preferences = TaskFlowPreferences(defaults: defaults)
        preferences.defaultReminderEnabled = true
        preferences.remindersEnabled = false
        preferences.hapticsEnabled = false

        let restored = TaskFlowPreferences(defaults: defaults)
        #expect(restored.defaultReminderEnabled)
        #expect(!restored.remindersEnabled)
        #expect(!restored.hapticsEnabled)
    }

    @Test func weekStartPreferencePersistsAndConfiguresCalendar() {
        let defaults = isolatedDefaults()
        TaskFlowPreferences(defaults: defaults).weekStart = .monday
        let preferences = TaskFlowPreferences(defaults: defaults)
        var base = Calendar(identifier: .gregorian)
        base.firstWeekday = 7

        #expect(preferences.weekStart == .monday)
        #expect(preferences.weekStart.calendar(from: base).firstWeekday == 2)
        #expect(TaskFlowWeekStart.sunday.calendar(from: base).firstWeekday == 1)
        #expect(TaskFlowWeekStart.system.calendar(from: base).firstWeekday == 7)
    }
}

@MainActor
@Suite("Task management, search, and filtering")
struct TaskViewModelTests {
    @Test func createTaskTrimsValuesAndAllowsAnEmptyDescription() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)

        let task = try model.createTask(
            title: "  Plan project  ", description: "  ", dueDate: .now,
            category: .work, priority: .high
        )

        #expect(task.title == "Plan project")
        #expect(task.taskDescription.isEmpty)
        #expect(task.category == .work)
        #expect(task.priority == .high)
        #expect(try store.context.fetch(FetchDescriptor<TaskItem>()).count == 1)
    }

    @Test func createRejectsAnEmptyTitle() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)

        #expect(throws: TaskValidationError.emptyTitle) {
            try model.createTask(title: "  \n", description: "", dueDate: .now, category: .personal, priority: .low)
        }
    }

    @Test func createRejectsAnInvalidDueDate() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)

        #expect(throws: TaskValidationError.invalidDueDate) {
            try model.createTask(title: "Task", description: "", dueDate: Date(timeIntervalSince1970: .nan), category: .personal, priority: .low)
        }
    }

    @Test func createRejectsDuplicateTitlesWithoutCaseSensitivity() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        _ = try model.createTask(title: "Read book", description: "", dueDate: .now, category: .personal, priority: .low)

        #expect(throws: TaskValidationError.duplicateTitle) {
            try model.createTask(title: "READ BOOK", description: "", dueDate: .now, category: .personal, priority: .low)
        }
    }

    @Test func editUpdatesTheExistingRecord() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let task = try model.createTask(title: "Draft", description: "Old", dueDate: .now, category: .work, priority: .low)
        let originalID = task.id
        let updatedDate = try isoDate("2026-12-01T10:00:00Z")

        try model.updateTask(task, title: "  Final draft ", description: " New ", dueDate: updatedDate, category: .study, priority: .high)

        let saved = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(saved.count == 1)
        #expect(saved[0].id == originalID)
        #expect(saved[0].title == "Final draft")
        #expect(saved[0].taskDescription == "New")
        #expect(saved[0].dueDate == updatedDate)
        #expect(saved[0].category == .study)
        #expect(saved[0].priority == .high)
    }

    @Test func editRejectsAnEmptyTitleAndDuplicateTitle() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let first = try model.createTask(title: "First", description: "", dueDate: .now, category: .personal, priority: .low)
        _ = try model.createTask(title: "Second", description: "", dueDate: .now, category: .personal, priority: .low)

        #expect(throws: TaskValidationError.emptyTitle) {
            try model.updateTask(first, title: " ", description: "", dueDate: .now, category: .personal, priority: .low)
        }
        #expect(throws: TaskValidationError.duplicateTitle) {
            try model.updateTask(first, title: "Second", description: "", dueDate: .now, category: .personal, priority: .low)
        }
    }

    @Test func deleteRemovesTaskAndRejectsAStaleRecord() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let task = try model.createTask(title: "Remove me", description: "", dueDate: .now, category: .personal, priority: .low)

        try model.delete(task)
        #expect(try store.context.fetch(FetchDescriptor<TaskItem>()).isEmpty)
        #expect(throws: TaskOperationError.taskNotFound) { try model.delete(task) }
    }

    @Test func completionCanBeMarkedAndReverted() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let task = try model.createTask(title: "Finish", description: "", dueDate: .now, category: .work, priority: .medium)

        try model.toggleCompletion(for: task)
        #expect(task.isComplete)
        #expect(task.completedAt != nil)

        try model.toggleCompletion(for: task)
        #expect(!task.isComplete)
        #expect(task.completedAt == nil)
    }

    @Test func searchMatchesTitlesAndIgnoresCase() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let tasks = [
            TaskItem(title: "Read Swift Guide", dueDate: .now),
            TaskItem(title: "Call family", dueDate: .now)
        ]

        #expect(model.filteredTasks(tasks, searchText: "sWiFt", status: .all, sort: .dueDate).map(\.title) == ["Read Swift Guide"])
        #expect(model.filteredTasks(tasks, searchText: " unknown ", status: .all, sort: .dueDate).isEmpty)
    }

    @Test func filtersAllPendingAndCompletedTasks() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let pending = TaskItem(title: "Pending", dueDate: .now)
        let completed = TaskItem(title: "Completed", dueDate: .now, isComplete: true)
        let tasks = [pending, completed]

        #expect(model.filteredTasks(tasks, searchText: "", status: .all, sort: .dueDate).count == 2)
        #expect(model.filteredTasks(tasks, searchText: "", status: .pending, sort: .dueDate).map(\.title) == ["Pending"])
        #expect(model.filteredTasks(tasks, searchText: "", status: .completed, sort: .dueDate).map(\.title) == ["Completed"])
    }

    @Test func filtersByPriority() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let tasks = [
            TaskItem(title: "Low", dueDate: .now, priority: .low),
            TaskItem(title: "High", dueDate: .now, priority: .high)
        ]

        #expect(model.filteredTasks(tasks, searchText: "", status: .all, sort: .dueDate, priority: .high).map(\.title) == ["High"])
    }

    @Test func sortsTasksByDueDate() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let late = TaskItem(title: "Later", dueDate: try isoDate("2026-12-03T10:00:00Z"))
        let early = TaskItem(title: "Sooner", dueDate: try isoDate("2026-11-26T10:00:00Z"))

        #expect(model.filteredTasks([late, early], searchText: "", status: .all, sort: .dueDate).map(\.title) == ["Sooner", "Later"])
    }

    @Test func sortsTasksByPriorityAndUsesDueDateAsTieBreaker() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let lateHigh = TaskItem(title: "Late high", dueDate: try isoDate("2026-12-03T10:00:00Z"), priority: .high)
        let earlyHigh = TaskItem(title: "Early high", dueDate: try isoDate("2026-11-26T10:00:00Z"), priority: .high)
        let medium = TaskItem(title: "Medium", dueDate: .now, priority: .medium)
        let low = TaskItem(title: "Low", dueDate: .now, priority: .low)

        #expect(model.filteredTasks([low, lateHigh, medium, earlyHigh], searchText: "", status: .all, sort: .priority).map(\.title) == ["Early high", "Late high", "Medium", "Low"])
    }

    @Test func rejectsOperationsForTasksThatAreNoLongerStored() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let task = try model.createTask(title: "Temporary", description: "", dueDate: .now, category: .personal, priority: .low)
        try model.delete(task)

        #expect(throws: TaskOperationError.taskNotFound) {
            try model.toggleCompletion(for: task)
        }
        #expect(throws: TaskOperationError.taskNotFound) {
            try model.updateTask(task, title: "Changed", description: "", dueDate: .now, category: .personal, priority: .low)
        }
    }

    @Test func equalSortKeysUseDeterministicTitleOrder() throws {
        let date = try isoDate("2026-12-03T10:00:00Z")
        let beta = TaskItem(title: "Beta", dueDate: date, priority: .high)
        let alpha = TaskItem(title: "Alpha", dueDate: date, priority: .high)
        let model = TaskViewModel(context: try InMemoryTaskStore().context)

        #expect(model.filteredTasks([beta, alpha], searchText: "", status: .all, sort: .dueDate).map(\.title) == ["Alpha", "Beta"])
        #expect(model.filteredTasks([beta, alpha], searchText: "", status: .all, sort: .priority).map(\.title) == ["Alpha", "Beta"])
    }

    @Test func searchAndStatisticsHandleLargeTaskCollections() throws {
        let tasks = (0..<1_200).map { index in
            TaskItem(
                title: index.isMultiple(of: 3) ? "Review milestone \(index)" : "Task \(index)",
                category: index.isMultiple(of: 2) ? .work : .study,
                priority: index.isMultiple(of: 5) ? .high : .low,
                isComplete: index.isMultiple(of: 4),
                completedAt: index.isMultiple(of: 4) ? Date.now : nil
            )
        }
        let model = TaskViewModel(context: try InMemoryTaskStore().context)
        let matches = model.filteredTasks(tasks, searchText: "MILESTONE", status: .all, sort: .dueDate)
        let stats = TaskStatisticsViewModel(tasks: tasks, calendar: utcCalendar())

        #expect(matches.count == 400)
        #expect(matches.allSatisfy { $0.title.localizedCaseInsensitiveContains("milestone") })
        #expect(stats.totalCount == 1_200)
        #expect(stats.completedCount == 300)
        #expect(stats.pendingCount == 900)
        #expect(stats.categoryDistribution.reduce(0) { $0 + $1.count } == 1_200)
    }
}

@MainActor
@Suite("Task statistics")
struct TaskStatisticsTests {
    @Test func calculatesCountsAndCompletionPercentage() {
        let tasks = [
            TaskItem(title: "One", isComplete: true),
            TaskItem(title: "Two", isComplete: false),
            TaskItem(title: "Three", isComplete: true),
            TaskItem(title: "Four", isComplete: false)
        ]
        let statistics = TaskStatisticsViewModel(tasks: tasks)

        #expect(statistics.totalCount == 4)
        #expect(statistics.completedCount == 2)
        #expect(statistics.pendingCount == 2)
        #expect(statistics.completionRate == 0.5)
    }

    @Test func emptyCollectionHasZeroCountsAndPercentage() {
        let statistics = TaskStatisticsViewModel(tasks: [])

        #expect(statistics.totalCount == 0)
        #expect(statistics.completedCount == 0)
        #expect(statistics.pendingCount == 0)
        #expect(statistics.completionRate == 0)
        #expect(statistics.weeklyCompletions.isEmpty == false)
        #expect(statistics.weeklyCompletions.allSatisfy { $0.count == 0 })
    }

    @Test func weeklyChartCountsOnlyCompletionsInTheReferenceWeek() throws {
        let calendar = utcCalendar()
        let reference = try isoDate("2026-11-25T12:00:00Z")
        let tasks = [
            TaskItem(title: "Monday", isComplete: true, completedAt: try isoDate("2026-11-23T08:00:00Z")),
            TaskItem(title: "Wednesday", isComplete: true, completedAt: try isoDate("2026-11-25T11:00:00Z")),
            TaskItem(title: "Previous week", isComplete: true, completedAt: try isoDate("2026-11-22T18:00:00Z")),
            TaskItem(title: "Pending", isComplete: false, completedAt: nil)
        ]
        let statistics = TaskStatisticsViewModel(tasks: tasks, calendar: calendar, referenceDate: reference)

        #expect(statistics.weeklyCompletions.count == 7)
        #expect(statistics.weeklyCompletions.map(\.count) == [1, 0, 1, 0, 0, 0, 0])
    }

    @Test func weeklyChartStartsOnPreferredWeekday() throws {
        let reference = try isoDate("2026-11-25T12:00:00Z")
        let monday = TaskStatisticsViewModel(tasks: [], calendar: TaskFlowWeekStart.monday.calendar(from: utcCalendar()), referenceDate: reference)
        let sunday = TaskStatisticsViewModel(tasks: [], calendar: TaskFlowWeekStart.sunday.calendar(from: utcCalendar()), referenceDate: reference)
        let expectedMonday = try isoDate("2026-11-23T00:00:00Z")
        let expectedSunday = try isoDate("2026-11-22T00:00:00Z")

        #expect(monday.weeklyCompletions.first?.date == expectedMonday)
        #expect(sunday.weeklyCompletions.first?.date == expectedSunday)
    }

    @Test func categoryDistributionIncludesEachStoredCategory() {
        let tasks = [
            TaskItem(title: "Work 1", category: .work),
            TaskItem(title: "Work 2", category: .work),
            TaskItem(title: "Study", category: .study)
        ]
        let distribution = TaskStatisticsViewModel(tasks: tasks).categoryDistribution

        #expect(distribution.first(where: { $0.category == .work })?.count == 2)
        #expect(distribution.first(where: { $0.category == .study })?.count == 1)
        #expect(distribution.filter { $0.category != .work && $0.category != .study }.allSatisfy { $0.count == 0 })
    }
}

@MainActor
@Suite("SwiftData persistence")
struct TaskPersistenceTests {
    @Test func savedTaskCanBeFetchedFromAnotherContext() throws {
        let store = try InMemoryTaskStore()
        let created = try TaskViewModel(context: store.context).createTask(
            title: "Stored task", description: "Saved", dueDate: .now, category: .health, priority: .medium
        )
        let otherContext = ModelContext(store.container)
        let fetched = try otherContext.fetch(FetchDescriptor<TaskItem>())

        #expect(fetched.count == 1)
        #expect(fetched.first?.id == created.id)
        #expect(fetched.first?.taskDescription == "Saved")
    }

    @Test func updateAndDeletePersistAcrossContexts() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let task = try model.createTask(title: "Before", description: "", dueDate: .now, category: .personal, priority: .low)
        try model.updateTask(task, title: "After", description: "Updated", dueDate: .now, category: .work, priority: .high)
        let reader = ModelContext(store.container)

        #expect(try reader.fetch(FetchDescriptor<TaskItem>()).first?.title == "After")
        try model.delete(task)
        #expect(try reader.fetch(FetchDescriptor<TaskItem>()).isEmpty)
    }

    @Test func completionStatusPersistsAndCanReturnToPending() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)
        let task = try model.createTask(title: "Complete", description: "", dueDate: .now, category: .personal, priority: .low)
        let reader = ModelContext(store.container)

        try model.toggleCompletion(for: task)
        var fetched = try reader.fetch(FetchDescriptor<TaskItem>())
        #expect(fetched.first?.isComplete == true)
        #expect(fetched.first?.completedAt != nil)

        try model.toggleCompletion(for: task)
        fetched = try reader.fetch(FetchDescriptor<TaskItem>())
        #expect(fetched.first?.isComplete == false)
        #expect(fetched.first?.completedAt == nil)
    }

    @Test func reminderDatePersistsWithTheTask() throws {
        let store = try InMemoryTaskStore()
        let reminder = Date.now.addingTimeInterval(3600)
        let task = try TaskViewModel(context: store.context).createTask(
            title: "Reminder persistence", description: "", dueDate: .now,
            category: .personal, priority: .medium, reminderDate: reminder
        )
        let reader = ModelContext(store.container)
        let saved = try reader.fetch(FetchDescriptor<TaskItem>())

        #expect(saved.first?.id == task.id)
        #expect(saved.first?.reminderDate == reminder)
    }
}

@MainActor
@Suite("SwiftData schema migration")
struct TaskSchemaMigrationTests {
    @Test func existingOnDiskTasksGainAnEmptyReminderWithoutLosingValues() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TaskFlowMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Tasks.store")
        let taskID = UUID()
        let dueDate = try isoDate("2026-12-04T09:30:00Z")
        let completionDate = try isoDate("2026-11-24T15:45:00Z")
        let createdDate = try isoDate("2026-11-20T08:00:00Z")

        do {
            let oldSchema = Schema([TaskItemBeforeReminderSchema.TaskItem.self])
            let oldConfiguration = ModelConfiguration("BeforeReminder", schema: oldSchema, url: storeURL)
            let oldContainer = try ModelContainer(for: oldSchema, configurations: oldConfiguration)
            let oldContext = ModelContext(oldContainer)
            oldContext.insert(TaskItemBeforeReminderSchema.TaskItem(
                id: taskID,
                title: "Existing completed task",
                taskDescription: "Keep this note",
                dueDate: dueDate,
                categoryValue: TaskCategory.work.rawValue,
                priorityValue: TaskPriority.high.rawValue,
                isComplete: true,
                completedAt: completionDate,
                createdAt: createdDate
            ))
            oldContext.insert(TaskItemBeforeReminderSchema.TaskItem(
                id: UUID(),
                title: "Existing pending task",
                taskDescription: "",
                dueDate: dueDate,
                categoryValue: TaskCategory.study.rawValue,
                priorityValue: TaskPriority.low.rawValue,
                isComplete: false,
                completedAt: nil,
                createdAt: createdDate
            ))
            try oldContext.save()
        }

        let currentConfiguration = ModelConfiguration("Current", url: storeURL, cloudKitDatabase: .none)
        let currentContainer = try ModelContainer(for: TaskItem.self, configurations: currentConfiguration)
        let migratedTasks = try ModelContext(currentContainer).fetch(FetchDescriptor<TaskItem>())

        #expect(migratedTasks.count == 2)
        let completed = try #require(migratedTasks.first { $0.id == taskID })
        #expect(completed.title == "Existing completed task")
        #expect(completed.taskDescription == "Keep this note")
        #expect(completed.dueDate == dueDate)
        #expect(completed.category == .work)
        #expect(completed.priority == .high)
        #expect(completed.isComplete)
        #expect(completed.completedAt == completionDate)
        #expect(completed.createdAt == createdDate)
        #expect(completed.reminderDate == nil)
        let pending = try #require(migratedTasks.first { $0.title == "Existing pending task" })
        #expect(!pending.isComplete)
        #expect(pending.category == .study)
        #expect(pending.priority == .low)
        #expect(pending.reminderDate == nil)
    }
}

@MainActor
private final class MockTaskReminderService: TaskReminderScheduling {
    struct ScheduledReminder: Equatable {
        let title: String
        let date: Date
    }

    var isReminderPreferenceEnabled = true
    var status: TaskFlowNotificationAuthorization = .authorized
    var scheduled: [UUID: ScheduledReminder] = [:]
    var cancelledTaskIDs: [UUID] = []
    var scheduleCallCount = 0
    var cancelAllCallCount = 0

    func currentAuthorizationStatus() async -> TaskFlowNotificationAuthorization { status }

    func requestAuthorizationIfNeeded() async throws -> TaskFlowNotificationAuthorization {
        if status == .notDetermined { status = .authorized }
        return status
    }

    func scheduleReminder(taskID: UUID, title: String, date: Date) async {
        scheduleCallCount += 1
        scheduled[taskID] = ScheduledReminder(title: title, date: date)
    }

    func cancelReminder(taskID: UUID) async {
        cancelledTaskIDs.append(taskID)
        scheduled.removeValue(forKey: taskID)
    }

    func cancelAllTaskFlowReminders() async {
        cancelAllCallCount += 1
        scheduled.removeAll()
    }
}

@MainActor
@Suite("Task reminders")
struct TaskReminderTests {
    @Test func schedulesAnAuthorizedFutureReminder() async {
        let service = MockTaskReminderService()
        let task = TaskItem(title: "Read", reminderDate: .now.addingTimeInterval(3600))

        await TaskReminderCoordinator(service: service).synchronize(task)

        #expect(service.scheduled[task.id]?.title == "Read")
        #expect(service.scheduled[task.id]?.date == task.reminderDate)
    }

    @Test func cancelsWhenReminderIsCleared() async {
        let service = MockTaskReminderService()
        let task = TaskItem(title: "Read")
        service.scheduled[task.id] = .init(title: task.title, date: .now.addingTimeInterval(600))

        await TaskReminderCoordinator(service: service).synchronize(task)

        #expect(service.scheduled[task.id] == nil)
        #expect(service.cancelledTaskIDs == [task.id])
    }

    @Test func rejectsPastReminderDates() throws {
        let store = try InMemoryTaskStore()
        let model = TaskViewModel(context: store.context)

        #expect(throws: TaskValidationError.invalidReminderDate) {
            try model.createTask(
                title: "Past reminder", description: "", dueDate: .now,
                category: .personal, priority: .medium,
                reminderDate: .now.addingTimeInterval(-60)
            )
        }
        #expect(throws: TaskValidationError.invalidReminderDate) {
            try model.createTask(
                title: "Invalid reminder", description: "", dueDate: .now,
                category: .personal, priority: .medium,
                reminderDate: Date(timeIntervalSince1970: .nan)
            )
        }
    }

    @Test func validatesTheMinuteUsedForNotificationDelivery() throws {
        let calendar = utcCalendar()
        let now = try isoDate("2026-11-25T14:30:30Z")
        let reminderWithinTheCurrentMinute = try isoDate("2026-11-25T14:30:45Z")
        let nextMinute = try isoDate("2026-11-25T14:31:00Z")

        #expect(!TaskReminderDateValidator.isFuture(reminderWithinTheCurrentMinute, now: now, calendar: calendar))
        #expect(TaskReminderDateValidator.isFuture(nextMinute, now: now, calendar: calendar))
    }

    @Test func updatingReminderReplacesTheExistingRequest() async {
        let service = MockTaskReminderService()
        let task = TaskItem(title: "Read", reminderDate: .now.addingTimeInterval(3600))
        let coordinator = TaskReminderCoordinator(service: service)
        await coordinator.synchronize(task)
        let updatedDate = Date.now.addingTimeInterval(7200)
        task.reminderDate = updatedDate

        await coordinator.synchronize(task)

        #expect(service.scheduled.count == 1)
        #expect(service.scheduled[task.id]?.date == updatedDate)
        #expect(service.scheduleCallCount == 2)
    }

    @Test func repeatedSchedulingUsesOneTaskRequest() async {
        let service = MockTaskReminderService()
        let task = TaskItem(title: "Read", reminderDate: .now.addingTimeInterval(3600))
        let coordinator = TaskReminderCoordinator(service: service)

        await coordinator.synchronize(task)
        await coordinator.synchronize(task)

        #expect(service.scheduled.count == 1)
        #expect(service.scheduled[task.id] != nil)
        #expect(NotificationService.notificationIdentifier(for: task.id) == "\(NotificationService.identifierPrefix)\(task.id.uuidString)")
    }

    @Test func completingTaskCancelsItsReminder() async {
        let service = MockTaskReminderService()
        let task = TaskItem(title: "Read", isComplete: true, reminderDate: .now.addingTimeInterval(3600))
        service.scheduled[task.id] = .init(title: task.title, date: task.reminderDate ?? .now)

        await TaskReminderCoordinator(service: service).completionDidChange(for: task)

        #expect(service.scheduled[task.id] == nil)
        #expect(service.cancelledTaskIDs == [task.id])
    }

    @Test func deletingTaskCancelsItsReminder() async {
        let service = MockTaskReminderService()
        let task = TaskItem(title: "Read", reminderDate: .now.addingTimeInterval(3600))
        service.scheduled[task.id] = .init(title: task.title, date: task.reminderDate ?? .now)

        await TaskReminderCoordinator(service: service).taskWasDeleted(task)

        #expect(service.scheduled[task.id] == nil)
        #expect(service.cancelledTaskIDs == [task.id])
    }

    @Test func deniedAndDisabledPreferencesDoNotScheduleReminders() async {
        let service = MockTaskReminderService()
        let task = TaskItem(title: "Read", reminderDate: .now.addingTimeInterval(3600))
        let coordinator = TaskReminderCoordinator(service: service)

        service.status = .denied
        await coordinator.synchronize(task)
        #expect(service.scheduled[task.id] == nil)

        service.status = .authorized
        service.isReminderPreferenceEnabled = false
        await coordinator.synchronize(task)
        #expect(service.scheduled[task.id] == nil)
    }

    @Test func authorizationStatusesIdentifySchedulingAvailability() {
        #expect(!TaskFlowNotificationAuthorization.notDetermined.canSchedule)
        #expect(TaskFlowNotificationAuthorization.authorized.canSchedule)
        #expect(TaskFlowNotificationAuthorization.provisional.canSchedule)
        #expect(TaskFlowNotificationAuthorization.ephemeral.canSchedule)
        #expect(!TaskFlowNotificationAuthorization.denied.canSchedule)
        #expect(!TaskFlowNotificationAuthorization.restricted.canSchedule)
    }
}
