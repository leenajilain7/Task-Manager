import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var tasks: [TaskItem]

    private var statistics: TaskStatisticsViewModel { TaskStatisticsViewModel(tasks: tasks) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
                    .background(TaskFlowStyle.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 20))
                } else {
                    weeklyChart
                    categoryChart
                }
            }
            .padding(20)
        }
        .background(TaskFlowStyle.groupedBackground)
        .navigationTitle("Statistics")
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly completions").font(.system(size: 17, weight: .bold, design: .rounded))
                Text("Tasks completed this week").font(.system(size: 12)).foregroundStyle(.secondary)
            }

            Chart(statistics.weeklyCompletions) { day in
                BarMark(
                    x: .value("Day", day.weekday),
                    y: .value("Completed tasks", day.count)
                )
                .foregroundStyle(TaskFlowStyle.accent.gradient)
                .cornerRadius(5)
            }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic) }
            .chartLegend(.hidden)
            .frame(height: 190)
            .accessibilityLabel("Weekly task completions chart")
        }
        .padding(18)
        .background(TaskFlowStyle.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tasks by category").font(.system(size: 17, weight: .bold, design: .rounded))
                Text("All saved tasks").font(.system(size: 12)).foregroundStyle(.secondary)
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
            .frame(height: 220)
            .accessibilityLabel("Task counts by category chart")
        }
        .padding(18)
        .background(TaskFlowStyle.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
            Text(value).font(.system(size: 25, weight: .bold, design: .rounded)).contentTransition(.numericText())
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(TaskFlowStyle.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 17))
    }
}
