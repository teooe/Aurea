import Foundation
import SwiftData

enum RecurringEngine {

    /// Crea i movimenti delle ricorrenze attive scaduti fino a `now` e sposta in avanti la loro prossima data.
    /// Se l'app non viene aperta per un po', recupera tutte le occorrenze perse.
    @discardableResult
    static func generateDueTransactions(
        from recurring: [RecurringTransaction],
        in context: ModelContext,
        now: Date = .now
    ) -> [Transaction] {
        var created: [Transaction] = []
        for item in recurring where item.isActive && item.nextDate <= now {
            guard let wallet = item.wallet else { continue }
            var date = item.nextDate
            while date <= now {
                let transaction = Transaction(type: item.type, amount: item.amount, date: date, category: item.category, title: item.title, wallet: wallet)
                context.insert(transaction)
                created.append(transaction)
                date = item.frequency.nextDate(after: date)
            }
            item.nextDate = date
        }
        return created
    }
}
