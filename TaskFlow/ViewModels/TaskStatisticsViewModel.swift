import Foundation

struct TaskStatisticsViewModel {
    let tasks: [TaskItem]
    private let calendar: Calendar
    private let referenceDate: Date

    init(tasks: [TaskItem], calendar: Calendar = .current, referenceDate: Date = .now) {
        self.tasks = tasks
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    var totalCount: Int { tasks.count }
    var completedCount: Int { tasks.filter(\.isComplete).count }
    var pendingCount: Int { totalCount - completedCount }
    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var weeklyCompletions: [DailyCompletion] {
        let firstDay = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
            ?? calendar.startOfDay(for: referenceDate)
        let completionCountsByDay = tasks.reduce(into: [Date: Int]()) { counts, task in
            guard let completedAt = task.completedAt else { return }
            let day = calendar.startOfDay(for: completedAt)
            counts[day, default: 0] += 1
        }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            return DailyCompletion(date: date, count: completionCountsByDay[calendar.startOfDay(for: date), default: 0])
        }
    }

    var categoryDistribution: [CategoryTaskCount] {
        let countsByCategory = tasks.reduce(into: [TaskCategory: Int]()) { counts, task in
            counts[task.category, default: 0] += 1
        }
        return TaskCategory.allCases.map { category in
            CategoryTaskCount(category: category, count: countsByCategory[category, default: 0])
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
