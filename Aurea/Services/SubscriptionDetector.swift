import Foundation

/// Trova nello storico le spese che si ripetono ogni mese (stesso nome, importo quasi uguale)
/// e che non sono ancora tra i movimenti ricorrenti: probabili abbonamenti da aggiungere.
enum SubscriptionDetector {

    struct Candidate: Identifiable, Equatable {
        var id: String { key }
        /// Nome normalizzato usato per riconoscere le ripetizioni.
        var key: String
        var title: String
        var category: String
        /// Importo dell'ultimo addebito.
        var amount: Decimal
        var lastDate: Date
        /// In quanti mesi diversi è stato trovato.
        var months: Int
        var walletName: String?

        var yearlyCost: Decimal { amount * 12 }
    }

    /// Mesi consecutivi richiesti per proporre un abbonamento.
    static let minimumMonths = 3
    /// Quanto può variare l'importo tra un mese e l'altro (10%).
    static let tolerance: Decimal = Decimal(string: "0.1")!

    static func candidates(
        transactions: [Transaction],
        recurring: [RecurringTransaction],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Candidate] {
        guard let windowStart = calendar.date(byAdding: .month, value: -7, to: now) else { return [] }
        let known = Set(recurring.map { normalized($0.title) })
        let expenses = transactions.filter { $0.type == .expense && !$0.isTransfer && $0.date >= windowStart && $0.date <= now }

        var result: [Candidate] = []
        for (key, group) in Dictionary(grouping: expenses, by: { normalized($0.title) }) where !key.isEmpty && !known.contains(key) {
            let sorted = group.sorted { $0.date < $1.date }
            guard let last = sorted.last else { continue }
            // Un addebito per mese: se ce ne sono di più nello stesso mese non è un abbonamento.
            let byMonth = Dictionary(grouping: sorted) { calendar.dateComponents([.year, .month], from: $0.date) }
            guard byMonth.count >= minimumMonths, byMonth.values.allSatisfy({ $0.count == 1 }) else { continue }
            guard consecutiveMonths(Array(byMonth.keys), calendar: calendar) >= minimumMonths else { continue }
            // Ultimo addebito non più vecchio di ~40 giorni: altrimenti l'abbonamento è probabilmente chiuso.
            guard let staleLimit = calendar.date(byAdding: .day, value: -40, to: now), last.date >= staleLimit else { continue }
            let amounts = sorted.map(\.amount)
            guard let low = amounts.min(), let high = amounts.max(), low > 0, (high - low) / low <= tolerance else { continue }

            result.append(Candidate(
                key: key,
                title: last.title,
                category: last.category,
                amount: last.amount,
                lastDate: last.date,
                months: byMonth.count,
                walletName: last.wallet?.name
            ))
        }
        return result.sorted { $0.yearlyCost > $1.yearlyCost }
    }

    /// Costo annuo delle spese ricorrenti attive, in EUR.
    static func yearlyCost(of recurring: [RecurringTransaction]) -> Decimal {
        recurring.filter { $0.isActive && $0.type == .expense }.reduce(Decimal.zero) { total, item in
            let perYear: Decimal = switch item.frequency {
            case .weekly: 52
            case .monthly: 12
            case .yearly: 1
            }
            return total + item.amount * (item.wallet?.effectiveExchangeRateToEUR ?? 1) * perYear
        }
    }

    static func normalized(_ title: String) -> String {
        title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !$0.allSatisfy(\.isNumber) }
            .joined(separator: " ")
    }

    /// La serie più lunga di mesi consecutivi.
    private static func consecutiveMonths(_ months: [DateComponents], calendar: Calendar) -> Int {
        let indexes = months.compactMap { c -> Int? in
            guard let year = c.year, let month = c.month else { return nil }
            return year * 12 + month
        }.sorted()
        var best = 0, run = 0, previous: Int?
        for index in indexes {
            run = (previous.map { index == $0 + 1 } ?? false) ? run + 1 : 1
            best = max(best, run)
            previous = index
        }
        return best
    }
}
