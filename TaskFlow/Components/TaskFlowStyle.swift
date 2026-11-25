import SwiftUI

enum TaskFlowStyle {
    static let accent = Color(red: 0.42, green: 0.34, blue: 0.88)
    static let cardRadius: CGFloat = 18

    static var groupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var secondaryGroupedBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }
}

extension TaskCategory {
    var color: Color {
        switch self {
        case .personal: .teal
        case .work: .orange
        case .study: TaskFlowStyle.accent
        case .shopping: .pink
        case .health: .green
        case .other: .blue
        }
    }
}

extension TaskPriority {
    var color: Color {
        switch self {
        case .low: .green
        case .medium: .orange
        case .high: .red
        }
    }
}
