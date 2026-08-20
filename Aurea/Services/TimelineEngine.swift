import Foundation

enum TimelineEngine {

    static func transactionsForToday(
        from transactions: [Transaction],
        calendar: Calendar = .current
    ) -> [Transaction] {
        transactions.filter {
            calendar.isDateInToday($0.date)
        }
    }

    static func transactionsForCurrentMonth(
        from transactions: [Transaction],
        calendar: Calendar = .current
    ) -> [Transaction] {
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else {
            return []
        }

        return transactions.filter { interval.contains($0.date) }
    }
}
