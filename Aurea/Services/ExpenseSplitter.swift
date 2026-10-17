import Foundation
import SwiftData

/// Divisione in parti uguali di una spesa pagata da te per più persone.
enum ExpenseSplitter {

    struct Split: Equatable {
        /// La tua quota: è la spesa che conta nei budget.
        var mine: Decimal
        /// La quota di ciascun'altra persona: diventa un credito verso di lei.
        var each: Decimal
        var others: Decimal { total - mine }
        var total: Decimal
    }

    /// Le quote degli altri sono arrotondate per difetto al centesimo; gli eventuali centesimi
    /// in più restano a te, così la somma torna sempre esattamente al totale.
    static func split(total: Decimal, otherPeople: Int) -> Split {
        guard otherPeople > 0, total > 0 else { return Split(mine: total, each: 0, total: total) }
        var share = total / Decimal(otherPeople + 1)
        var each = Decimal()
        NSDecimalRound(&each, &share, 2, .down)
        return Split(mine: total - each * Decimal(otherPeople), each: each, total: total)
    }

    /// Registra la spesa divisa: la tua quota come spesa, l'anticipo per gli altri come movimento
    /// escluso dai totali (esce dal conto ma non è una tua spesa) e un credito per ogni persona.
    /// Restituisce tutto ciò che ha creato, per poterlo annullare.
    @discardableResult
    static func record(
        total: Decimal, people: [String], title: String, category: String, date: Date, wallet: Wallet,
        in context: ModelContext
    ) -> [any PersistentModel] {
        let names = people.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let split = split(total: total, otherPeople: names.count)
        var created: [any PersistentModel] = []

        let mine = Transaction(type: .expense, amount: split.mine, date: date, category: category, title: title, wallet: wallet)
        context.insert(mine)
        created.append(mine)

        guard !names.isEmpty else { return created }

        let advance = Transaction(
            type: .expense, amount: split.others, date: date, category: Transaction.transferCategory,
            title: "Anticipo per \(names.joined(separator: ", ")) · \(title)", wallet: wallet, transferGroupID: UUID()
        )
        context.insert(advance)
        created.append(advance)

        let when = date.formatted(date: .abbreviated, time: .omitted)
        for name in names {
            let credit = Relationship(personName: name, amount: split.each, type: .credit, note: "Quota di \(title) del \(when)", createdAt: date)
            context.insert(credit)
            created.append(credit)
        }
        return created
    }
}
