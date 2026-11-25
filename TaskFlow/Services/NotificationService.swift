import Foundation
import Observation
import UserNotifications

enum TaskFlowNotificationAuthorization: String, Equatable {
    case notDetermined
    case authorized
    case provisional
    case ephemeral
    case denied
    case restricted

    var canSchedule: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined, .denied, .restricted: false
        }
    }

    var displayName: String {
        switch self {
        case .notDetermined: "Not requested"
        case .authorized: "Allowed"
        case .provisional: "Allowed quietly"
        case .ephemeral: "Temporary access"
        case .denied: "Denied"
        case .restricted: "Restricted"
        }
    }
}

enum TaskReminderDateValidator {
    static func isFuture(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard date.timeIntervalSince1970.isFinite else { return false }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let deliveryDate = calendar.date(from: components) else { return false }
        return deliveryDate > now
    }
}

@MainActor
protocol TaskReminderScheduling {
    var isReminderPreferenceEnabled: Bool { get }
    func currentAuthorizationStatus() async -> TaskFlowNotificationAuthorization
    func requestAuthorizationIfNeeded() async throws -> TaskFlowNotificationAuthorization
    func scheduleReminder(taskID: UUID, title: String, date: Date) async
    func cancelReminder(taskID: UUID) async
    func cancelAllTaskFlowReminders() async
}

@MainActor
@Observable
final class NotificationService: TaskReminderScheduling {
    static let reminderPreferenceKey = "taskflow.remindersEnabled"
    static let identifierPrefix = "taskflow.task."

    private(set) var authorization: TaskFlowNotificationAuthorization = .notDetermined
    private(set) var lastSchedulingError: String?
    @ObservationIgnored private let center: UNUserNotificationCenter
    @ObservationIgnored private let defaults: UserDefaults

    var isReminderPreferenceEnabled: Bool {
        defaults.object(forKey: Self.reminderPreferenceKey) as? Bool ?? true
    }

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
    }

    func currentAuthorizationStatus() async -> TaskFlowNotificationAuthorization {
        let settings = await center.notificationSettings()
        let current: TaskFlowNotificationAuthorization
        switch settings.authorizationStatus {
        case .notDetermined: current = .notDetermined
        case .denied: current = .denied
        case .authorized: current = .authorized
        case .provisional: current = .provisional
        case .ephemeral: current = .ephemeral
        @unknown default: current = .restricted
        }
        authorization = current
        return current
    }

    func requestAuthorizationIfNeeded() async throws -> TaskFlowNotificationAuthorization {
        let current = await currentAuthorizationStatus()
        guard current == .notDetermined else { return current }
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        return await currentAuthorizationStatus()
    }

    func scheduleReminder(taskID: UUID, title: String, date: Date) async {
        guard isReminderPreferenceEnabled,
              TaskReminderDateValidator.isFuture(date),
              (await currentAuthorizationStatus()).canSchedule else { return }

        let identifier = Self.notificationIdentifier(for: taskID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "TaskFlow reminder"
        content.body = title
        content.sound = .default
        content.userInfo = ["taskID": taskID.uuidString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            lastSchedulingError = nil
        } catch {
            lastSchedulingError = error.localizedDescription
        }
    }

    func cancelReminder(taskID: UUID) async {
        let identifier = Self.notificationIdentifier(for: taskID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func cancelAllTaskFlowReminders() async {
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        let delivered = await center.deliveredNotifications()
            .map(\.request.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }

    static func notificationIdentifier(for taskID: UUID) -> String {
        "\(identifierPrefix)\(taskID.uuidString)"
    }
}

@MainActor
struct TaskReminderCoordinator {
    private let service: any TaskReminderScheduling

    init(service: any TaskReminderScheduling) {
        self.service = service
    }

    func synchronize(_ task: TaskItem) async {
        await service.cancelReminder(taskID: task.id)
        guard !task.isComplete,
              service.isReminderPreferenceEnabled,
              let reminderDate = task.reminderDate,
              TaskReminderDateValidator.isFuture(reminderDate) else { return }

        guard (await service.currentAuthorizationStatus()).canSchedule else { return }
        await service.scheduleReminder(taskID: task.id, title: task.title, date: reminderDate)
    }

    func completionDidChange(for task: TaskItem) async {
        await synchronize(task)
    }

    func taskWasDeleted(_ task: TaskItem) async {
        await service.cancelReminder(taskID: task.id)
    }

    func rescheduleAll(_ tasks: [TaskItem]) async {
        await service.cancelAllTaskFlowReminders()
        for task in tasks where !task.isComplete {
            await synchronize(task)
        }
    }
}
