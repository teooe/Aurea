import Foundation
import SwiftData

/// `FinanceCategory` è l'elenco ufficiale delle categorie. Movimenti, ricorrenti e budget
/// salvano il nome della categoria: questo servizio li tiene allineati all'elenco.
enum CategoryService {

    static let defaultExpenseCategories: [(name: String, icon: String)] = [
        ("Alimentari", "cart"), ("Trasporti", "car"), ("Casa", "house"), ("Svago", "gamecontroller"),
        ("Salute", "heart"), ("Shopping", "bag"), ("Altro", "tag"),
    ]

    static let defaultIncomeCategories: [(name: String, icon: String)] = [
        ("Stipendio", "briefcase"), ("Regalo", "gift"), ("Rimborso", "arrow.uturn.backward"),
        ("Vendita", "banknote"), ("Altro", "tag"),
    ]

    /// Categoria dello stesso tipo con lo stesso nome, senza distinguere maiuscole e spazi.
    static func find(_ name: String, type: TransactionType, in categories: [FinanceCategory]) -> FinanceCategory? {
        let key = normalizedKey(name)
        return categories.first { $0.type == type && normalizedKey($0.name) == key }
    }

    /// Restituisce il nome ufficiale della categoria, creandola se non esiste.
    /// Una categoria archiviata viene riattivata, perché l'utente la sta usando di nuovo.
    @discardableResult
    static func resolve(_ name: String, type: TransactionType, in context: ModelContext) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Transaction.isReservedCategory(trimmed) else { return trimmed }

        let categories = (try? context.fetch(FetchDescriptor<FinanceCategory>())) ?? []
        if let existing = find(trimmed, type: type, in: categories) {
            existing.isArchived = false
            return existing.name
        }
        context.insert(FinanceCategory(name: trimmed, type: type))
        return trimmed
    }

    /// Rinomina la categoria e aggiorna movimenti, ricorrenti e budget che la usano.
    /// Se esiste già un'altra categoria con il nuovo nome, le due vengono unite.
    static func rename(_ category: FinanceCategory, to newName: String, in context: ModelContext) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Transaction.isReservedCategory(trimmed) else { return }

        let categories = try context.fetch(FetchDescriptor<FinanceCategory>())
        let target = find(trimmed, type: category.type, in: categories.filter { $0 !== category })
        let finalName = target?.name ?? trimmed
        let oldKey = normalizedKey(category.name)

        for transaction in try context.fetch(FetchDescriptor<Transaction>())
        where !transaction.isTransfer && transaction.type == category.type && normalizedKey(transaction.category) == oldKey {
            transaction.category = finalName
        }
        for item in try context.fetch(FetchDescriptor<RecurringTransaction>())
        where item.type == category.type && normalizedKey(item.category) == oldKey {
            item.category = finalName
        }
        if category.type == .expense {
            for budget in try context.fetch(FetchDescriptor<Budget>())
            where budget.category.map(normalizedKey) == oldKey {
                budget.category = finalName
            }
        }

        if let target {
            target.isArchived = false
            context.delete(category)
        } else {
            category.name = finalName
        }
    }

    /// Numero di movimenti (esclusi i trasferimenti) che usano la categoria.
    static func usageCount(of category: FinanceCategory, in transactions: [Transaction]) -> Int {
        let key = normalizedKey(category.name)
        return transactions.filter { !$0.isTransfer && $0.type == category.type && normalizedKey($0.category) == key }.count
    }

    /// Porta i dati esistenti nell'elenco ufficiale: crea le categorie predefinite se mancano,
    /// registra le categorie scritte a mano nei movimenti e uniforma le varianti ("cibo" → "Cibo").
    /// È idempotente, quindi si può eseguire a ogni avvio.
    static func synchronize(in context: ModelContext) {
        guard let categories = try? context.fetch(FetchDescriptor<FinanceCategory>()) else { return }

        var byKey: [String: FinanceCategory] = [:]
        for category in categories {
            let key = lookupKey(category.name, category.type)
            if byKey[key] == nil { byKey[key] = category }
        }

        for (type, defaults) in [(TransactionType.expense, defaultExpenseCategories), (.income, defaultIncomeCategories)]
        where !categories.contains(where: { $0.type == type }) {
            for item in defaults {
                let category = FinanceCategory(name: item.name, type: type, icon: item.icon)
                context.insert(category)
                byKey[lookupKey(item.name, type)] = category
            }
        }

        func canonicalName(_ name: String, _ type: TransactionType) -> String? {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !Transaction.isReservedCategory(trimmed) else { return nil }
            let key = lookupKey(trimmed, type)
            if let existing = byKey[key] { return existing.name }
            let category = FinanceCategory(name: trimmed, type: type)
            context.insert(category)
            byKey[key] = category
            return trimmed
        }

        for transaction in (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        where !transaction.isTransfer && transaction.type != .transfer {
            if let name = canonicalName(transaction.category, transaction.type), name != transaction.category {
                transaction.category = name
            }
        }
        for item in (try? context.fetch(FetchDescriptor<RecurringTransaction>())) ?? [] where item.type != .transfer {
            if let name = canonicalName(item.category, item.type), name != item.category {
                item.category = name
            }
        }
        for budget in (try? context.fetch(FetchDescriptor<Budget>())) ?? [] {
            if let current = budget.category, let name = canonicalName(current, .expense), name != current {
                budget.category = name
            }
        }
    }

    private static func normalizedKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func lookupKey(_ name: String, _ type: TransactionType) -> String {
        "\(type.rawValue)|\(normalizedKey(name))"
    }
}
