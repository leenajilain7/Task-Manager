import SwiftUI

struct TaskRow: View {
    let task: TaskItem
    let onOpen: () -> Void
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(task: TaskItem, onOpen: @escaping () -> Void = {}, onToggle: @escaping () -> Void) {
        self.task = task
        self.onOpen = onOpen
        self.onToggle = onToggle
    }

    var body: some View {
        HStack(alignment: .top, spacing: TaskFlowStyle.space2) {
            Button(action: onToggle) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isComplete ? TaskFlowStyle.success : TaskFlowStyle.pending)
                    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: task.isComplete)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isComplete ? "Mark \(task.title) incomplete" : "Mark \(task.title) complete")
            .accessibilityHint("Changes the completion status")

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: TaskFlowStyle.space2) {
                    Text(task.title)
                        .font(TaskFlowStyle.cardTitle)
                        .foregroundStyle(task.isComplete ? .secondary : .primary)
                        .strikethrough(task.isComplete)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: TaskFlowStyle.space2) {
                            categoryBadge
                            priorityBadge
                        }
                        VStack(alignment: .leading, spacing: TaskFlowStyle.space2) {
                            categoryBadge
                            priorityBadge
                        }
                    }

                    if !task.taskDescription.isEmpty {
                        Text(task.taskDescription)
                            .font(TaskFlowStyle.secondaryText)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: TaskFlowStyle.space2) {
                            dueDateLabel
                            Spacer(minLength: TaskFlowStyle.space2)
                            completionLabel
                        }
                        VStack(alignment: .leading, spacing: TaskFlowStyle.space2) {
                            dueDateLabel
                            completionLabel
                        }
                    }

                    if let reminderDate = task.reminderDate {
                        Label("Reminder · \(reminderDate.formatted(date: .omitted, time: .shortened))", systemImage: "bell.badge")
                            .font(TaskFlowStyle.caption.weight(.medium))
                            .foregroundStyle(TaskFlowStyle.accent)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Reminder \(reminderDate.formatted(date: .complete, time: .shortened))")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(task.title), \(task.category.rawValue), \(task.priority.rawValue)")
            .accessibilityValue(task.isComplete ? "Completed" : "Pending")
            .accessibilityHint("Open task details")
            .accessibilityIdentifier("task.row.\(task.title)")
        }
        .padding(.horizontal, TaskFlowStyle.space3)
        .padding(.vertical, TaskFlowStyle.space2)
        .contentShape(Rectangle())
    }

    private var categoryBadge: some View {
        Label(task.category.rawValue, systemImage: "folder.fill")
            .font(TaskFlowStyle.caption.weight(.medium))
            .foregroundStyle(task.category.color)
            .lineLimit(1)
            .padding(.horizontal, TaskFlowStyle.space2)
            .padding(.vertical, TaskFlowStyle.space1)
            .background(task.category.color.opacity(0.11), in: Capsule())
    }

    private var priorityBadge: some View {
        Label(task.priority.rawValue, systemImage: "flag.fill")
            .font(TaskFlowStyle.caption.weight(.medium))
            .foregroundStyle(task.priority.color)
            .lineLimit(1)
            .padding(.horizontal, TaskFlowStyle.space2)
            .padding(.vertical, TaskFlowStyle.space1)
            .background(task.priority.color.opacity(0.11), in: Capsule())
    }

    private var dueDateLabel: some View {
        Label(task.dueDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
            .font(TaskFlowStyle.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Due \(task.dueDate.formatted(date: .complete, time: .shortened))")
    }

    private var completionLabel: some View {
        Label(task.isComplete ? "Completed" : "Pending", systemImage: task.isComplete ? "checkmark.circle.fill" : "circle.dashed")
            .font(TaskFlowStyle.caption.weight(.semibold))
            .foregroundStyle(task.isComplete ? TaskFlowStyle.success : TaskFlowStyle.pending)
            .lineLimit(1)
    }
}
