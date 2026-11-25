import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \TaskItem.dueDate) private var tasks: [TaskItem]
    @State private var searchText = ""
    @State private var statusFilter: TaskStatusFilter = .all
    @State private var categoryFilter: TaskCategory?
    @State private var showingComposer = false
    @State private var errorMessage: String?

    private var todayTasks: [TaskItem] {
        tasks.filter { Calendar.current.isDateInToday($0.dueDate) }
    }

    private var visibleTasks: [TaskItem] {
        todayTasks.filter { task in
            let matchesStatus = statusFilter == .all || task.isComplete == (statusFilter == .completed)
            let matchesCategory = categoryFilter == nil || task.category == categoryFilter
            let matchesSearch = searchText.isEmpty || task.title.localizedCaseInsensitiveContains(searchText)
            return matchesStatus && matchesCategory && matchesSearch
        }
    }

    private var statistics: TaskStatisticsViewModel { TaskStatisticsViewModel(tasks: tasks) }
    private var completedCount: Int { statistics.completedCount }
    private var pendingCount: Int { statistics.pendingCount }
    private var todayProgress: Double {
        guard !todayTasks.isEmpty else { return 0 }
        return Double(todayTasks.filter(\.isComplete).count) / Double(todayTasks.count)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    greeting
                    progressCard
                    summaryCards
                    todaySection
                    upcomingSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
                .background(TaskFlowStyle.groupedBackground)
                .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: visibleTasks.map(\.id))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: todayProgress)
            .navigationBarHidden(true)
            .overlay(alignment: .bottomTrailing) {
                if !usesInlineEmptyAction {
                    Button { showingComposer = true } label: {
                        Label("Add task", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 18).frame(height: 54)
                            .foregroundStyle(TaskFlowStyle.onAccent)
                            .background(TaskFlowStyle.accent, in: Capsule())
                            .shadow(color: TaskFlowStyle.accent.opacity(0.28), radius: 14, y: 7)
                    }
                    .accessibilityLabel("Add task")
                    .accessibilityHint("Create a task with a title, due date, and optional reminder")
                    .accessibilityIdentifier("dashboard.addTask")
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.trailing, 20).padding(.bottom, 16)
                }
            }
            .sheet(isPresented: $showingComposer) {
                TaskComposerView()
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

    private var greeting: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(TaskFlowStyle.secondaryText.weight(.medium)).foregroundStyle(.secondary)
                Text("\(timeGreeting)!")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold)).foregroundStyle(.primary)
                Text("Let’s make today count.")
                    .font(TaskFlowStyle.body).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(TaskFlowStyle.accent)
                .frame(width: 46, height: 46)
                .background(TaskFlowStyle.accent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
        }
    }

    private var progressCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Today’s focus")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.78))
                Text(progressHeadline)
                    .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(progressSummary)
                    .font(TaskFlowStyle.caption.weight(.medium)).foregroundStyle(.white.opacity(0.86))
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(.white.opacity(0.23), lineWidth: 6)
                Circle().trim(from: 0, to: todayProgress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(Int(todayProgress * 100))%")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    Text("DONE").font(.system(.caption2, design: .rounded).weight(.bold)).tracking(0.6)
                }.foregroundStyle(.white)
            }
            .frame(width: 62, height: 62)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [TaskFlowStyle.heroStart, TaskFlowStyle.heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: TaskFlowStyle.largeRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today’s focus")
        .accessibilityValue("\(todayTasks.filter { $0.isComplete }.count) of \(todayTasks.count) tasks complete, \(Int(todayProgress * 100)) percent")
    }

    private var summaryCards: some View {
        HStack(spacing: 10) {
            SummaryCard(title: "Total", count: tasks.count, symbol: "square.stack.3d.up", tint: TaskFlowStyle.accent)
            SummaryCard(title: "Pending", count: pendingCount, symbol: "circle.dashed", tint: .orange)
            SummaryCard(title: "Done", count: completedCount, symbol: "checkmark.circle", tint: .green)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today").font(TaskFlowStyle.sectionTitle)
                Text("\(todayTasks.filter { !$0.isComplete }.count) left")
                    .font(TaskFlowStyle.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Picker("Status", selection: $statusFilter) {
                        ForEach(TaskStatusFilter.allCases) { filter in Text(filter.title).tag(filter) }
                    }
                    Menu("Category") {
                        Button("All categories") { categoryFilter = nil }
                        ForEach(TaskCategory.allCases) { category in
                            Button(category.rawValue) { categoryFilter = category }
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "slider.horizontal.3")
                        .font(TaskFlowStyle.smallCaption.weight(.semibold))
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search by task title", text: $searchText)
                    .font(TaskFlowStyle.body).autocorrectionDisabled()
                    .accessibilityIdentifier("dashboard.search")
            }
            .padding(.horizontal, 14).frame(height: 44)
            .taskFlowCard(radius: TaskFlowStyle.smallRadius)

            if let categoryFilter {
                HStack(spacing: 6) {
                    Text(categoryFilter.rawValue).font(TaskFlowStyle.caption.weight(.semibold))
                    Button { self.categoryFilter = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear category filter")
                }
                .foregroundStyle(TaskFlowStyle.accent)
            }

            if visibleTasks.isEmpty {
                if usesInlineEmptyAction {
                    Button("Add task", systemImage: "plus") { showingComposer = true }
                        .buttonStyle(.borderedProminent)
                        .tint(TaskFlowStyle.accent)
                        .accessibilityIdentifier("dashboard.addTask")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                ContentUnavailableView(
                    searchText.isEmpty ? "Nothing scheduled today" : "No matching tasks",
                    systemImage: searchText.isEmpty ? "sun.max" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Your day is open. Add a task whenever you’re ready." : "Try another title or filter.")
                )
                .frame(maxWidth: .infinity).padding(.vertical, TaskFlowStyle.space4)
                .taskFlowCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleTasks.enumerated()), id: \.element.id) { index, task in
                        TaskRow(task: task) {
                            do {
                                try TaskViewModel(context: modelContext).toggleCompletion(for: task)
                                TaskFlowHaptics.success()
                                Task { await TaskReminderCoordinator(service: notificationService).completionDidChange(for: task) }
                            }
                            catch { errorMessage = error.localizedDescription }
                        }
                        if index < visibleTasks.count - 1 { Divider().padding(.leading, 54) }
                    }
                }
                .taskFlowCard()
            }
        }
    }

    private var upcomingSection: some View {
        let upcoming = tasks.filter { !Calendar.current.isDateInToday($0.dueDate) && !$0.isComplete }
            .sorted { $0.dueDate < $1.dueDate }
        return Group {
            if !upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Coming up").font(TaskFlowStyle.sectionTitle)
                        Spacer()
                        Text("\(upcoming.count)").font(TaskFlowStyle.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    ForEach(upcoming.prefix(3)) { task in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2).fill(task.category.color).frame(width: 3, height: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).font(TaskFlowStyle.cardTitle).foregroundStyle(.primary).lineLimit(2)
                                Text(task.category.rawValue).font(TaskFlowStyle.caption.weight(.medium)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(task.dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .font(TaskFlowStyle.caption.weight(.medium)).foregroundStyle(.secondary)
                                .accessibilityLabel("Due \(task.dueDate.formatted(date: .complete, time: .shortened))")
                        }
                        .padding(13)
                        .taskFlowCard(radius: TaskFlowStyle.smallRadius)
                    }
                }
            }
        }
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    private var progressHeadline: String {
        if todayTasks.isEmpty { "A fresh start." }
        else if todayProgress >= 1 { "Everything is done." }
        else { "One step at a time." }
    }

    private var progressSummary: String {
        let remaining = todayTasks.filter { !$0.isComplete }.count
        if todayTasks.isEmpty { return "Add a task to get started" }
        if remaining == 0 { return "You’ve finished today’s tasks" }
        return "\(remaining) \(remaining == 1 ? "task" : "tasks") left today"
    }

    private var showingFirstTaskEmptyState: Bool {
        todayTasks.isEmpty && searchText.isEmpty && statusFilter == .all && categoryFilter == nil
    }

    private var usesInlineEmptyAction: Bool {
        showingFirstTaskEmptyState
    }
}

private enum TaskStatusFilter: String, CaseIterable, Identifiable {
    case all, pending, completed
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct SummaryCard: View {
    let title: String
    let count: Int
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(tint)
            Text("\(count)").font(.system(.title2, design: .rounded).weight(.bold)).contentTransition(.numericText())
            Text(title).font(TaskFlowStyle.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TaskFlowStyle.space3)
        .taskFlowCard(radius: TaskFlowStyle.smallRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) tasks")
        .accessibilityValue("\(count)")
    }
}

