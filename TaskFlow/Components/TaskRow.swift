import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    let onOpen: () -> Void
    let onToggle: () -> Void

    init(task: TaskItem, onOpen: @escaping () -> Void = {}, onToggle: @escaping () -> Void) {
        self.task = task
        self.onOpen = onOpen
        self.onToggle = onToggle
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(task.isComplete ? Color.accentColor : Color.secondary.opacity(0.55))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isComplete ? "Mark \(task.title) incomplete" : "Mark \(task.title) complete")

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(task.isComplete ? .secondary : .primary)
                        .strikethrough(task.isComplete)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Circle().fill(task.category.color).frame(width: 6, height: 6)
                        Text(task.category.rawValue).font(.system(size: 10, weight: .medium))
                        Text("·").foregroundStyle(.tertiary)
                        Text(task.priority.rawValue).font(.system(size: 10, weight: .medium))
                        if !task.taskDescription.isEmpty {
                            Text("·").foregroundStyle(.tertiary)
                            Text(task.taskDescription).lineLimit(1)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Open task details")
            .accessibilityIdentifier("task.row.\(task.title)")
            .accessibilityIdentifier("task.row.\(task.title)")
            Spacer(minLength: 4)
            Text(task.dueDate.formatted(.dateTime.hour().minute()))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
