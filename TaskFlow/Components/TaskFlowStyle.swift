import SwiftUI
import UIKit

enum TaskFlowStyle {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.68, blue: 1.00, alpha: 1)
            : UIColor(red: 0.32, green: 0.27, blue: 0.72, alpha: 1)
    })
    static let secondaryAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.83, green: 0.79, blue: 1.00, alpha: 1)
            : UIColor(red: 0.43, green: 0.36, blue: 0.83, alpha: 1)
    })
    static let heroStart = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.24, green: 0.19, blue: 0.49, alpha: 1)
            : UIColor(red: 0.29, green: 0.24, blue: 0.62, alpha: 1)
    })
    static let heroEnd = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.34, green: 0.27, blue: 0.65, alpha: 1)
            : UIColor(red: 0.40, green: 0.33, blue: 0.75, alpha: 1)
    })
    static let onAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.10, blue: 0.22, alpha: 1)
            : .white
    })

    static var groupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var surface: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var elevatedSurface: Color { Color(uiColor: .tertiarySystemGroupedBackground) }
    static var separator: Color { Color(uiColor: .separator).opacity(0.35) }
    static var success: Color { Color(uiColor: .systemGreen) }
    static var pending: Color { Color(uiColor: .secondaryLabel) }
    static var destructive: Color { Color(uiColor: .systemRed) }

    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24

    static let smallRadius: CGFloat = 12
    static let cardRadius: CGFloat = 18
    static let largeRadius: CGFloat = 24

    static let sectionTitle = Font.system(.title3, design: .rounded).weight(.bold)
    static let cardTitle = Font.headline
    static let body = Font.body
    static let secondaryText = Font.subheadline
    static let caption = Font.caption
    static let smallCaption = Font.footnote
}

extension View {
    func taskFlowCard(radius: CGFloat = TaskFlowStyle.cardRadius) -> some View {
        background(TaskFlowStyle.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(TaskFlowStyle.separator, lineWidth: 0.6)
            }
            .shadow(color: Color.primary.opacity(0.045), radius: 10, y: 3)
    }
}

extension TaskCategory {
    var color: Color {
        switch self {
        case .personal: Color(uiColor: .systemTeal)
        case .work: Color(uiColor: .systemOrange)
        case .study: TaskFlowStyle.accent
        case .shopping: Color(uiColor: .systemPink)
        case .health: Color(uiColor: .systemGreen)
        case .other: Color(uiColor: .systemBlue)
        }
    }
}

extension TaskPriority {
    var color: Color {
        switch self {
        case .low: Color(uiColor: .systemGreen)
        case .medium: Color(uiColor: .systemOrange)
        case .high: Color(uiColor: .systemRed)
        }
    }
}
