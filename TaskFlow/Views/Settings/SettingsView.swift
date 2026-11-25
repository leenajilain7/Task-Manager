import SwiftUI

struct SettingsView: View {
    @AppStorage("taskflow.appearance") private var appearanceValue = AppAppearance.system.rawValue

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
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Task reminders")
                        Text("Reminder preferences will be available in a later update.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(TaskFlowStyle.accent)
                }
                .padding(.vertical, 4)
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
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        guard let build, !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }
}
