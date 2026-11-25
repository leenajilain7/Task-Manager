import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @AppStorage("taskflow.appearance") private var appearanceValue = AppAppearance.system.rawValue
    @AppStorage(NotificationService.reminderPreferenceKey) private var remindersEnabled = true
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
                    .font(.system(size: 12)).foregroundStyle(.secondary)

                switch authorization {
                case .notDetermined:
                    Button("Allow Notifications", action: requestPermission)
                        .accessibilityIdentifier("settings.requestNotifications")
                case .denied:
                    Text("Notifications are off for TaskFlow. You can change this in iOS Settings.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("Open Notification Settings", action: openNotificationSettings)
                        .accessibilityIdentifier("settings.openNotificationSettings")
                case .restricted:
                    Text("Notification access is restricted by this device’s settings.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                case .authorized, .provisional, .ephemeral:
                    Label("Task reminders can be delivered.", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12)).foregroundStyle(.green)
                }

                if let schedulingError = notificationService.lastSchedulingError {
                    Text("A reminder could not be scheduled: \(schedulingError)")
                        .font(.system(size: 12)).foregroundStyle(.red)
                }
            }

            Section("About") {
                HStack {
                    Label("TaskFlow", systemImage: "checklist")
                    Spacer()
                    Text("Version \(versionString)")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Text("A simple space to plan, focus, and keep track of what matters.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
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
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
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
