import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
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

    private var completedCount: Int { tasks.filter(\.isComplete).count }
    private var pendingCount: Int { tasks.count - completedCount }
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
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarHidden(true)
            .overlay(alignment: .bottomTrailing) {
                Button { showingComposer = true } label: {
                    Label("Add task", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 18).frame(height: 54)
                        .foregroundStyle(.white)
                        .background(TaskFlowStyle.accent, in: Capsule())
                        .shadow(color: TaskFlowStyle.accent.opacity(0.28), radius: 14, y: 7)
                }
                .accessibilityLabel("Add task")
                .padding(.trailing, 20).padding(.bottom, 16)
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
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Text("\(timeGreeting)!")
                    .font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(.primary)
                Text("Let’s make today count.")
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 19, weight: .semibold))
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
                Text(todayTasks.isEmpty ? "A fresh start." : "You’re making\nsteady progress.")
                    .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(todayTasks.isEmpty ? "Add a task to get started" : "\(todayTasks.filter { !$0.isComplete }.count) tasks left today")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(.white.opacity(0.23), lineWidth: 6)
                Circle().trim(from: 0, to: todayProgress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(Int(todayProgress * 100))%")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("DONE").font(.system(size: 8, weight: .bold)).tracking(0.8)
                }.foregroundStyle(.white)
            }
            .frame(width: 62, height: 62)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [TaskFlowStyle.accent, Color(red: 0.59, green: 0.48, blue: 0.94)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
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
                Text("Today").font(.system(size: 19, weight: .bold, design: .rounded))
                Text("\(todayTasks.filter { !$0.isComplete }.count) left")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
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
                        .font(.system(size: 12, weight: .semibold))
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search by task title", text: $searchText)
                    .font(.system(size: 14)).autocorrectionDisabled()
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13))

            if let categoryFilter {
                HStack(spacing: 6) {
                    Text(categoryFilter.rawValue).font(.system(size: 11, weight: .semibold))
                    Button { self.categoryFilter = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear category filter")
                }
                .foregroundStyle(TaskFlowStyle.accent)
            }

            if visibleTasks.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "Nothing scheduled today" : "No matching tasks",
                    systemImage: searchText.isEmpty ? "checkmark.circle" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "Tap Add task to put something on your list." : "Try another title or filter.")
                )
                .frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 17))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleTasks.enumerated()), id: \.element.id) { index, task in
                        TaskRow(task: task) {
                            do { try TaskViewModel(context: modelContext).toggleCompletion(for: task) }
                            catch { errorMessage = error.localizedDescription }
                        }
                        if index < visibleTasks.count - 1 { Divider().padding(.leading, 54) }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 17))
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
                        Text("Coming up").font(.system(size: 19, weight: .bold, design: .rounded))
                        Spacer()
                        Text("\(upcoming.count)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    ForEach(upcoming.prefix(3)) { task in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 2).fill(task.category.color).frame(width: 3, height: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                                Text(task.category.rawValue).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(task.dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        }
                        .padding(13)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
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
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            Text("\(count)").font(.system(size: 23, weight: .bold, design: .rounded)).contentTransition(.numericText())
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

