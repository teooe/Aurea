import Foundation

/// Totali per etichetta: quanto è costato un viaggio o un progetto, qualunque sia la categoria delle spese.
enum TagEngine {

    struct Summary: Identifiable, Equatable {
        var id: String { name.lowercased() }
        var name: String
        var expenses: Decimal
        var income: Decimal
        var count: Int
        var firstDate: Date
        var lastDate: Date
        /// Spese per categoria, dalla più alta.
        var byCategory: [(category: String, amount: Decimal)]

        var net: Decimal { expenses - income }

        static func == (lhs: Summary, rhs: Summary) -> Bool {
            lhs.name == rhs.name && lhs.expenses == rhs.expenses && lhs.income == rhs.income && lhs.count == rhs.count
                && lhs.firstDate == rhs.firstDate && lhs.lastDate == rhs.lastDate
                && lhs.byCategory.map(\.category) == rhs.byCategory.map(\.category) && lhs.byCategory.map(\.amount) == rhs.byCategory.map(\.amount)
        }
    }

    /// Un riepilogo per etichetta (maiuscole ignorate), dal più recente.
    static func summaries(from transactions: [Transaction]) -> [Summary] {
        var groups: [String: (name: String, items: [Transaction])] = [:]
        for transaction in transactions where !transaction.isTransfer {
            for tag in transaction.tags {
                groups[tag.lowercased(), default: (tag, [])].items.append(transaction)
            }
        }
        return groups.values.compactMap { summary(named: $0.name, transactions: $0.items) }
            .sorted { $0.lastDate > $1.lastDate }
    }

    static func transactions(tagged tag: String, in transactions: [Transaction]) -> [Transaction] {
        transactions.filter { transaction in !transaction.isTransfer && transaction.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } }
    }

    private static func summary(named name: String, transactions: [Transaction]) -> Summary? {
        let dates = transactions.map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        let expenses = transactions.filter { $0.type == .expense }
        var categories: [String: Decimal] = [:]
        for expense in expenses { categories[expense.category, default: 0] += FinancialEngine.amountInEUR(for: expense) }
        return Summary(
            name: name,
            expenses: FinancialEngine.totalExpenses(from: transactions),
            income: FinancialEngine.totalIncome(from: transactions),
            count: transactions.count,
            firstDate: first,
            lastDate: last,
            byCategory: categories.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
        )
    }
}
