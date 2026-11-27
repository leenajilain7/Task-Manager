import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @AppStorage(TaskFlowPreferences.appearanceKey) private var appearanceValue = AppAppearance.system.rawValue
    @AppStorage(NotificationService.reminderPreferenceKey) private var remindersEnabled = true
    @AppStorage(TaskFlowPreferences.defaultPriorityKey) private var defaultPriorityValue = TaskPriority.medium.rawValue
    @AppStorage(TaskFlowPreferences.defaultCategoryKey) private var defaultCategoryValue = TaskCategory.personal.rawValue
    @AppStorage(TaskFlowPreferences.defaultReminderKey) private var defaultReminderEnabled = false
    @AppStorage(TaskFlowPreferences.hapticsKey) private var hapticsEnabled = true
    @AppStorage(TaskFlowPreferences.weekStartKey) private var weekStartValue = TaskFlowWeekStart.system.rawValue
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.scenePhase) private var scenePhase
    @Query private var tasks: [TaskItem]
    @State private var authorization: TaskFlowNotificationAuthorization = .notDetermined
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearanceValue) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance.rawValue)
                    }
                }
                .accessibilityLabel("Appearance theme")
            }

            Section("New Task Defaults") {
                Picker("Default priority", selection: $defaultPriorityValue) {
                    ForEach(TaskPriority.allCases) { option in Text(option.rawValue).tag(option.rawValue) }
                }
                .accessibilityIdentifier("settings.defaultPriority")
                Picker("Default category", selection: $defaultCategoryValue) {
                    ForEach(TaskCategory.allCases) { option in Text(option.rawValue).tag(option.rawValue) }
                }
                .accessibilityIdentifier("settings.defaultCategory")
                Toggle("Enable reminders by default", isOn: $defaultReminderEnabled)
                    .accessibilityIdentifier("settings.defaultReminder")
            }

            Section("Calendar") {
                Picker("First day of the week", selection: $weekStartValue) {
                    ForEach(TaskFlowWeekStart.allCases) { option in Text(option.title).tag(option.rawValue) }
                }
                .accessibilityIdentifier("settings.weekStart")
                Text("This changes the weekly statistics chart. System Default follows your device calendar.")
                    .font(TaskFlowStyle.caption).foregroundStyle(.secondary)
            }

            Section("Interaction") {
                Toggle("Haptic feedback", isOn: $hapticsEnabled)
                    .accessibilityIdentifier("settings.hapticsEnabled")
            }

            Section("Notifications") {
                Toggle("Task reminders", isOn: $remindersEnabled)
                    .accessibilityIdentifier("settings.remindersEnabled")
                    .onChange(of: remindersEnabled) { _, isEnabled in
                        Task {
                            if isEnabled {
                                await TaskReminderCoordinator(service: notificationService).rescheduleAll(tasks)
                            } else {
                                await notificationService.cancelAllTaskFlowReminders()
                            }
                        }
                    }

                LabeledContent("Permission status", value: authorization.displayName)
                    .accessibilityIdentifier("settings.notificationStatus")

                Text("TaskFlow uses notifications to alert you at the reminder time you choose.")
                    .font(TaskFlowStyle.caption).foregroundStyle(.secondary)

                switch authorization {
                case .notDetermined:
                    Button("Allow Notifications", action: requestPermission)
                        .accessibilityIdentifier("settings.requestNotifications")
                case .denied:
                    Text("Notifications are off for TaskFlow. You can change this in iOS Settings.")
                        .font(TaskFlowStyle.caption).foregroundStyle(.secondary)
                    Button("Open Notification Settings", action: openNotificationSettings)
                        .accessibilityIdentifier("settings.openNotificationSettings")
                case .restricted:
                    Text("Notification access is restricted by this device’s settings.")
                        .font(TaskFlowStyle.caption).foregroundStyle(.secondary)
                case .authorized, .provisional, .ephemeral:
                    Label("Task reminders can be delivered.", systemImage: "checkmark.circle.fill")
                        .font(TaskFlowStyle.caption).foregroundStyle(.green)
                }

                if let schedulingError = notificationService.lastSchedulingError {
                    Text("A reminder could not be scheduled: \(schedulingError)")
                        .font(TaskFlowStyle.caption).foregroundStyle(.red)
                }
            }

            Section("About") {
                HStack {
                    Label("TaskFlow", systemImage: "checklist")
                    Spacer()
                    Text("Version \(versionString)")
                        .font(TaskFlowStyle.caption).foregroundStyle(.secondary)
                }
                Text("A simple space to plan, focus, and keep track of what matters.")
                    .font(TaskFlowStyle.secondaryText).foregroundStyle(.secondary)
                LabeledContent("Built with", value: "SwiftUI · SwiftData · Swift Charts")
                LabeledContent("Developer", value: "Leena Jilain")
            }
        }
        .navigationTitle("Settings")
        .task { await refreshAuthorization() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshAuthorization() }
        }
        .alert("Notifications", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        guard let build, !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }

    private func refreshAuthorization() async {
        authorization = await notificationService.currentAuthorizationStatus()
        if authorization.canSchedule, remindersEnabled {
            await TaskReminderCoordinator(service: notificationService).rescheduleAll(tasks)
        }
    }

    private func requestPermission() {
        Task {
            do {
                authorization = try await notificationService.requestAuthorizationIfNeeded()
                if authorization.canSchedule, remindersEnabled {
                    await TaskReminderCoordinator(service: notificationService).rescheduleAll(tasks)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        Task { await UIApplication.shared.open(url) }
    }
}
