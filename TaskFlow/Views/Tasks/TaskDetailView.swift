import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationService.self) private var notificationService
    let task: TaskItem

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Label(task.category.rawValue, systemImage: "folder")
                        .foregroundStyle(task.category.color)
                    Text("·").foregroundStyle(.tertiary)
                    Label(task.priority.rawValue, systemImage: "flag.fill")
                        .foregroundStyle(task.priority.color)
                }
                .font(.system(size: 13, weight: .semibold))

                Text(task.title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("task.detailTitle")

                detailCard(title: "Description", symbol: "text.alignleft") {
                    Text(task.taskDescription.isEmpty ? "No description provided." : task.taskDescription)
                        .foregroundStyle(task.taskDescription.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                detailCard(title: "Due date", symbol: "calendar") {
                    Text(task.dueDate.formatted(date: .complete, time: .shortened))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let reminderDate = task.reminderDate {
                    detailCard(title: "Reminder", symbol: "bell.badge") {
                        Text(reminderDate.formatted(date: .complete, time: .shortened))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("task.reminderDetails")
                }

                detailCard(title: "Status", symbol: task.isComplete ? "checkmark.circle.fill" : "circle.dashed") {
                    HStack {
                        Text(task.isComplete ? "Completed" : "Pending")
                        Spacer()
                        if let completedAt = task.completedAt {
                            Text("\(completedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                }

                Button(action: toggleCompletion) {
                    Label(task.isComplete ? "Mark as pending" : "Mark as completed", systemImage: task.isComplete ? "arrow.uturn.backward" : "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(TaskFlowStyle.accent)
                .accessibilityIdentifier("task.toggleCompletion")
            }
            .padding(20)
        }
        .background(TaskFlowStyle.groupedBackground)
        .navigationTitle("Task details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit task", systemImage: "pencil") { showingEditor = true }
                    Button("Delete task", systemImage: "trash", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Task actions")
                .accessibilityIdentifier("task.actions")
            }
        }
        .sheet(isPresented: $showingEditor) {
            TaskComposerView(task: task)
        }
        .confirmationDialog("Delete this task?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete task", role: .destructive, action: deleteTask)
                .accessibilityIdentifier("task.confirmDelete")
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This task will be removed from TaskFlow.")
        }
        .alert("Couldn’t update task", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func detailCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content().font(.system(size: 15))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaskFlowStyle.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: TaskFlowStyle.cardRadius))
    }

    private func toggleCompletion() {
        do {
            try TaskViewModel(context: modelContext).toggleCompletion(for: task)
            TaskFlowHaptics.success()
            Task { await TaskReminderCoordinator(service: notificationService).completionDidChange(for: task) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTask() {
        do {
            try TaskViewModel(context: modelContext).delete(task)
            TaskFlowHaptics.impact()
            Task { await TaskReminderCoordinator(service: notificationService).taskWasDeleted(task) }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
