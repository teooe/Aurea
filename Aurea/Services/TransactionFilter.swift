import Foundation
import SwiftData

enum TransactionPeriod: String, CaseIterable, Identifiable {
    case thisMonth, lastMonth, lastThreeMonths, thisYear, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisMonth: "Questo mese"
        case .lastMonth: "Mese scorso"
        case .lastThreeMonths: "Ultimi 3 mesi"
        case .thisYear: "Quest'anno"
        case .all: "Sempre"
        }
    }

    /// Intervallo coperto dal periodo; `nil` significa nessun limite.
    func interval(now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: now)
        case .lastMonth:
            guard let previous = calendar.date(byAdding: .month, value: -1, to: now) else { return nil }
            return calendar.dateInterval(of: .month, for: previous)
        case .lastThreeMonths:
            guard let current = calendar.dateInterval(of: .month, for: now),
                  let start = calendar.date(byAdding: .month, value: -2, to: current.start) else { return nil }
            return DateInterval(start: start, end: current.end)
        case .thisYear:
            return calendar.dateInterval(of: .year, for: now)
        case .all:
            return nil
        }
    }
}

enum TransactionKindFilter: String, CaseIterable, Identifiable {
    case all = "Tutti"
    case expenses = "Spese"
    case income = "Entrate"

    var id: String { rawValue }
}

/// Filtri della lista Movimenti. È un valore puro, così si può testare senza interfaccia.
struct TransactionFilter: Equatable {
    var kind: TransactionKindFilter = .all
    var period: TransactionPeriod = .all
    var category: String?
    var walletID: PersistentIdentifier?
    var searchText = ""

    /// Filtri aggiuntivi attivi oltre al tipo e alla ricerca (per l'indicatore nel menu).
    var activeRefinementCount: Int {
        (period == .all ? 0 : 1) + (category == nil ? 0 : 1) + (walletID == nil ? 0 : 1)
    }

    func apply(to transactions: [Transaction], now: Date = .now, calendar: Calendar = .current) -> [Transaction] {
        let interval = period.interval(now: now, calendar: calendar)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return transactions.filter { transaction in
            switch kind {
            case .all: break
            case .expenses: guard transaction.type == .expense && !transaction.isTransfer else { return false }
            case .income: guard transaction.type == .income && !transaction.isTransfer else { return false }
            }

            // DateInterval.contains include la fine: il primo istante del periodo successivo va escluso.
            if let interval, !(transaction.date >= interval.start && transaction.date < interval.end) { return false }

            if let category, transaction.isTransfer || transaction.category.caseInsensitiveCompare(category) != .orderedSame {
                return false
            }

            if let walletID, transaction.wallet?.persistentModelID != walletID { return false }

            guard !query.isEmpty else { return true }
            return transaction.title.localizedCaseInsensitiveContains(query) ||
                transaction.category.localizedCaseInsensitiveContains(query) ||
                (transaction.wallet?.name.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
}

extension Transaction {
    /// Può essere eliminato dalla lista: i trasferimenti solo se le due metà sono collegate.
    var canBeDeleted: Bool { !isTransfer || transferGroupID != nil }

    /// Elimina il movimento; per un trasferimento elimina anche l'altra metà.
    static func delete(_ transaction: Transaction, from all: [Transaction], in context: ModelContext) {
        if transaction.isTransfer, let groupID = transaction.transferGroupID {
            for item in all where item.transferGroupID == groupID {
                context.delete(item)
            }
        } else {
            context.delete(transaction)
        }
    }
}
