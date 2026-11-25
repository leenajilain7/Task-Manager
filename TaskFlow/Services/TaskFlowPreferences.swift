import Foundation
import SwiftUI
import UIKit

enum TaskFlowWeekStart: String, CaseIterable, Identifiable {
    case system
    case monday
    case sunday

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System Default"
        case .monday: "Monday"
        case .sunday: "Sunday"
        }
    }

    func calendar(from base: Calendar = .current) -> Calendar {
        var calendar = base
        switch self {
        case .system: break
        case .monday: calendar.firstWeekday = 2
        case .sunday: calendar.firstWeekday = 1
        }
        return calendar
    }
}

/// UserDefaults-backed preferences kept separate from task records.
struct TaskFlowPreferences {
    static let appearanceKey = "taskflow.appearance"
    static let defaultPriorityKey = "taskflow.defaultPriority"
    static let defaultCategoryKey = "taskflow.defaultCategory"
    static let defaultReminderKey = "taskflow.defaultReminderEnabled"
    static let hapticsKey = "taskflow.hapticsEnabled"
    static let weekStartKey = "taskflow.weekStart"
    static let remindersEnabledKey = NotificationService.reminderPreferenceKey

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var appearance: AppAppearance {
        get { AppAppearance(rawValue: defaults.string(forKey: Self.appearanceKey) ?? "system") ?? .system }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.appearanceKey) }
    }

    var defaultPriority: TaskPriority {
        get { TaskPriority(rawValue: defaults.string(forKey: Self.defaultPriorityKey) ?? "Medium") ?? .medium }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.defaultPriorityKey) }
    }

    var defaultCategory: TaskCategory {
        get { TaskCategory(rawValue: defaults.string(forKey: Self.defaultCategoryKey) ?? "Personal") ?? .personal }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.defaultCategoryKey) }
    }

    var defaultReminderEnabled: Bool {
        get { defaults.object(forKey: Self.defaultReminderKey) as? Bool ?? false }
        nonmutating set { defaults.set(newValue, forKey: Self.defaultReminderKey) }
    }

    var hapticsEnabled: Bool {
        get { defaults.object(forKey: Self.hapticsKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.hapticsKey) }
    }

    var weekStart: TaskFlowWeekStart {
        get { TaskFlowWeekStart(rawValue: defaults.string(forKey: Self.weekStartKey) ?? "system") ?? .system }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.weekStartKey) }
    }

    var remindersEnabled: Bool {
        get { defaults.object(forKey: Self.remindersEnabledKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.remindersEnabledKey) }
    }
}

enum TaskFlowHaptics {
    static func success(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: TaskFlowPreferences.hapticsKey) as? Bool ?? true else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func impact(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: TaskFlowPreferences.hapticsKey) as? Bool ?? true else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
