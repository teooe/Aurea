import Foundation

/// Riconosce le spese molto più alte del solito per la loro categoria
/// (per esempio 120 € al bar quando di solito si spendono 2 €).
enum UnusualSpendingDetector {

    struct Finding: Equatable {
        var transactionID: UUID
        var title: String
        var category: String
        var amount: Decimal
        /// Spesa tipica (mediana) della categoria.
        var typical: Decimal
    }

    /// Servono almeno questi movimenti precedenti nella categoria per sapere cosa è "normale".
    static let minimumHistory = 5
    /// Una spesa è insolita se supera di tanto la mediana...
    static let factor: Decimal = 3
    /// ...e di almeno questa cifra: 3 € invece di 1 € al bar non merita un avviso.
    static let minimumDifference: Decimal = 30

    /// Spese insolite degli ultimi `days` giorni, dalla più recente.
    static func findings(in transactions: [Transaction], days: Int = 7, now: Date = .now, calendar: Calendar = .current) -> [Finding] {
        guard let recentStart = calendar.date(byAdding: .day, value: -days, to: now),
              let historyStart = calendar.date(byAdding: .month, value: -6, to: now) else { return [] }
        let expenses = transactions.filter { $0.type == .expense && !$0.isTransfer && $0.date <= now }
        let recent = expenses.filter { $0.date >= recentStart }.sorted { $0.date > $1.date }

        return recent.compactMap { transaction in
            let history = expenses
                .filter { $0.category == transaction.category && $0.date >= historyStart && $0.date < transaction.date && $0.id != transaction.id }
                .map { FinancialEngine.amountInEUR(for: $0) }
            guard history.count >= minimumHistory else { return nil }
            let typical = median(history)
            let amount = FinancialEngine.amountInEUR(for: transaction)
            guard amount >= typical * factor, amount - typical >= minimumDifference else { return nil }
            return Finding(transactionID: transaction.id, title: transaction.title, category: transaction.category, amount: amount, typical: typical)
        }
    }

    static func median(_ values: [Decimal]) -> Decimal {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
