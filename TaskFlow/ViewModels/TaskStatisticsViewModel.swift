import Foundation

struct TaskStatisticsViewModel {
    let tasks: [TaskItem]

    var totalCount: Int { tasks.count }
    var completedCount: Int { tasks.filter(\.isComplete).count }
    var pendingCount: Int { totalCount - completedCount }
    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var weeklyCompletions: [DailyCompletion] {
        let calendar = Calendar.current
        let firstDay = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
            ?? calendar.startOfDay(for: .now)
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            let count = tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: date)
            }.count
            return DailyCompletion(date: date, count: count)
        }
    }

    var categoryDistribution: [CategoryTaskCount] {
        TaskCategory.allCases.map { category in
            CategoryTaskCount(category: category, count: tasks.filter { $0.category == category }.count)
        }
    }
}

struct DailyCompletion: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
    var weekday: String { date.formatted(.dateTime.weekday(.narrow)) }
}

struct CategoryTaskCount: Identifiable {
    let category: TaskCategory
    let count: Int
    var id: String { category.rawValue }
}
