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
}
