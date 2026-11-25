import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var tasks: [TaskItem]
    @AppStorage(TaskFlowPreferences.weekStartKey) private var weekStartValue = TaskFlowWeekStart.system.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var statistics: TaskStatisticsViewModel {
        let preference = TaskFlowWeekStart(rawValue: weekStartValue) ?? .system
        return TaskStatisticsViewModel(tasks: tasks, calendar: preference.calendar())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskFlowStyle.space5) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TaskFlowStyle.space3) {
                    MetricCard(title: "Total tasks", value: "\(statistics.totalCount)", symbol: "square.stack.3d.up", tint: TaskFlowStyle.accent)
                    MetricCard(title: "Completed", value: "\(statistics.completedCount)", symbol: "checkmark.circle.fill", tint: .green)
                    MetricCard(title: "Pending", value: "\(statistics.pendingCount)", symbol: "circle.dashed", tint: .orange)
                    MetricCard(title: "Completion", value: statistics.completionRate.formatted(.percent.precision(.fractionLength(0))), symbol: "chart.pie.fill", tint: .blue)
                }

                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No statistics yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Add tasks and mark them complete to see your progress here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 250)
                    .taskFlowCard(radius: TaskFlowStyle.largeRadius)
                } else {
                    weeklyChart
                    categoryChart
                }
            }
            .padding(20)
        }
        .background(TaskFlowStyle.groupedBackground)
        .navigationTitle("Statistics")
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: tasks.map(\.id))
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: TaskFlowStyle.space4) {
            VStack(alignment: .leading, spacing: TaskFlowStyle.space1) {
                Text("Weekly completions").font(TaskFlowStyle.sectionTitle)
                Text("Tasks completed this week").font(TaskFlowStyle.caption).foregroundStyle(.secondary)
            }

            Chart(statistics.weeklyCompletions) { day in
                BarMark(
                    x: .value("Day", day.weekday),
                    y: .value("Completed tasks", day.count)
                )
                .foregroundStyle(TaskFlowStyle.accent.gradient)
                .cornerRadius(5)
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 7)) }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic) }
            .chartLegend(.hidden)
            .frame(minHeight: 190)
            .accessibilityLabel("Weekly task completions chart")
            .accessibilityHint("Completed task count for each day of the selected week")
        }
        .padding(TaskFlowStyle.space4)
        .taskFlowCard(radius: TaskFlowStyle.largeRadius)
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: TaskFlowStyle.space4) {
            VStack(alignment: .leading, spacing: TaskFlowStyle.space1) {
                Text("Tasks by category").font(TaskFlowStyle.sectionTitle)
                Text("All saved tasks").font(TaskFlowStyle.caption).foregroundStyle(.secondary)
            }

            Chart(statistics.categoryDistribution) { item in
                BarMark(
                    x: .value("Tasks", item.count),
                    y: .value("Category", item.category.rawValue)
                )
                .foregroundStyle(item.category.color.gradient)
                .cornerRadius(4)
            }
            .chartXAxis { AxisMarks(position: .bottom, values: .automatic) }
            .chartLegend(.hidden)
            .frame(minHeight: 220)
            .accessibilityLabel("Task counts by category chart")
            .accessibilityHint("Distribution of saved tasks across categories")
        }
        .padding(TaskFlowStyle.space4)
        .taskFlowCard(radius: TaskFlowStyle.largeRadius)
    }
}

private struct MetricCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(tint)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .contentTransition(reduceMotion ? .identity : .numericText())
            Text(title).font(TaskFlowStyle.caption.weight(.medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TaskFlowStyle.space4)
        .taskFlowCard(radius: TaskFlowStyle.smallRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
