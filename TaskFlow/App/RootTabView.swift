import SwiftUI

struct RootTabView: View {
    @AppStorage(TaskFlowPreferences.appearanceKey) private var appearanceValue = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceValue) ?? .system
    }

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Home", systemImage: "house.fill").accessibilityIdentifier("tab.home") }

            NavigationStack {
                AllTasksView()
            }
            .tabItem { Label("Tasks", systemImage: "checklist").accessibilityIdentifier("tab.tasks") }

            NavigationStack {
                StatisticsView()
            }
            .tabItem { Label("Statistics", systemImage: "chart.bar.fill").accessibilityIdentifier("tab.statistics") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill").accessibilityIdentifier("tab.settings") }
        }
        .tint(TaskFlowStyle.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(appearance.colorScheme)
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System Default"
        case .light: "Light Mode"
        case .dark: "Dark Mode"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
