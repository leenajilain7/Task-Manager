import SwiftUI
import SwiftData

struct AllTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @State private var searchText = ""
    @State private var status: TaskListStatus = .all
    @State private var sort: TaskSortOption = .dueDate
    @State private var priorityFilter: TaskPriority?
    @State private var taskForDetails: TaskItem?
    @State private var errorMessage: String?

    private var viewModel: TaskViewModel { TaskViewModel(context: modelContext) }
    private var visibleTasks: [TaskItem] {
        viewModel.filteredTasks(tasks, searchText: searchText, status: status, sort: sort, priority: priorityFilter)
    }

    private var dateGroups: [TaskDateGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleTasks) { calendar.startOfDay(for: $0.dueDate) }
        return grouped.keys.sorted().map { date in
            TaskDateGroup(date: date, tasks: grouped[date] ?? [])
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Task status", selection: $status) {
                    ForEach(TaskListStatus.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("tasks.statusFilter")
                .listRowBackground(Color.clear)
            }

            if visibleTasks.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? emptyTitle : "No matching tasks",
                    systemImage: searchText.isEmpty ? "checkmark.circle" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? emptyDescription : "Try a different search or status filter.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(dateGroups) { group in
                    Section(group.date.formatted(date: .complete, time: .omitted)) {
                        ForEach(group.tasks) { task in
                            TaskRow(task: task, onOpen: { taskForDetails = task }) {
                                toggle(task)
                            }
                            .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("All Tasks")
        .searchable(text: $searchText, prompt: "Search task titles")
        .accessibilityIdentifier("tasks.search")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Priority", selection: $priorityFilter) {
                        Text("All priorities").tag(nil as TaskPriority?)
                        ForEach(TaskPriority.allCases) { option in
                            Text(option.rawValue).tag(option as TaskPriority?)
                        }
                    }
                    Divider()
                    Picker("Sort tasks", selection: $sort) {
                        ForEach(TaskSortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("Sort tasks")
                .accessibilityIdentifier("tasks.options")
            }
        }
        .sheet(item: $taskForDetails) { task in
            NavigationStack { TaskDetailView(task: task) }
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

    private var emptyTitle: String {
        switch status {
        case .all: "No tasks yet"
        case .pending: "No pending tasks"
        case .completed: "No completed tasks"
        }
    }

    private var emptyDescription: String {
        status == .all ? "Tasks you add will show up here." : "Change the filter or add a task."
    }

    private func toggle(_ task: TaskItem) {
        do { try viewModel.toggleCompletion(for: task) }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct TaskDateGroup: Identifiable {
    let date: Date
    let tasks: [TaskItem]
    var id: Date { date }
}
