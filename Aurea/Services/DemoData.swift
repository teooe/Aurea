#if DEBUG
import Foundation
import SwiftData

/// Dati di esempio per screenshot e prove sul simulatore. Si attivano solo nelle build Debug
/// avviate con il parametro `-DemoData`, e in quel caso il database è solo in memoria:
/// i dati veri non vengono mai letti né toccati.
enum DemoData {

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-DemoData")
    }

    static func seed(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let bank = Wallet(name: "Conto corrente", icon: "building.columns", initialBalance: 2400)
        let card = Wallet(name: "Carta", icon: "creditcard", initialBalance: 350)
        let cash = Wallet(name: "Contanti", icon: "banknote", initialBalance: 80)
        [bank, card, cash].forEach { context.insert($0) }

        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth) ?? now
        let today = calendar.component(.day, from: now)

        /// Giorno `day` del mese che inizia in `monthStart`, alle `hour`; nil se è nel futuro.
        func date(_ monthStart: Date, _ day: Int, _ hour: Int = 12) -> Date? {
            guard let value = calendar.date(byAdding: DateComponents(day: day - 1, hour: hour), to: monthStart),
                  value <= now else { return nil }
            return value
        }

        func add(_ type: TransactionType, _ amount: String, _ category: String, _ title: String, _ wallet: Wallet, _ when: Date?) {
            guard let when, let value = Decimal(string: amount) else { return }
            context.insert(Transaction(type: type, amount: value, date: when, category: category, title: title, wallet: wallet))
        }

        for month in [lastMonth, thisMonth] {
            let isCurrent = month == thisMonth
            add(.income, "1850", "Stipendio", "Stipendio", bank, date(month, 1, 9))
            add(.expense, "650", "Casa", "Affitto", bank, date(month, 3, 10))
            add(.expense, "62.40", "Alimentari", "Spesa Esselunga", card, date(month, 4, 18))
            add(.expense, "45", "Trasporti", "Benzina", card, date(month, 6, 8))
            add(.expense, "38.15", "Alimentari", "Spesa Coop", card, date(month, 9, 19))
            add(.expense, "18.50", "Salute", "Farmacia", cash, date(month, 11, 17))
            add(.expense, isCurrent ? "54" : "32", "Svago", "Cena fuori", card, date(month, 13, 21))
            add(.expense, "71.30", "Alimentari", "Spesa settimanale", card, date(month, 16, 18))
            add(.expense, "89.99", "Shopping", "Scarpe", card, date(month, 18, 16))
            add(.expense, isCurrent ? "42" : "28", "Svago", "Cinema e aperitivo", cash, date(month, 20, 20))
            add(.expense, "24.90", "Alimentari", "Frutta e verdura", cash, date(month, 23, 11))
            add(.expense, "60", "Casa", "Bolletta luce", bank, date(month, 25, 9))
        }

        // Movimenti di oggi, così la card "Oggi" non è vuota.
        add(.expense, "1.30", "Bar", "Caffè", cash, calendar.date(bySettingHour: 8, minute: 15, second: 0, of: now).flatMap { $0 <= now ? $0 : nil })
        add(.expense, "12.50", "Alimentari", "Pranzo", card, calendar.date(bySettingHour: 13, minute: 10, second: 0, of: now).flatMap { $0 <= now ? $0 : nil } ?? now)

        // Un trasferimento collegato, come lo crea il modulo rapido.
        if let when = date(thisMonth, max(today - 1, 1), 10) {
            let group = UUID()
            context.insert(Transaction(type: .expense, amount: 100, date: when, category: Transaction.transferCategory, title: "Prelievo → Contanti", wallet: bank, transferGroupID: group))
            context.insert(Transaction(type: .income, amount: 100, date: when, category: Transaction.transferCategory, title: "Prelievo ← Conto corrente", wallet: cash, transferGroupID: group))
        }

        context.insert(Budget(title: "Alimentari", category: "Alimentari", monthlyLimit: 300))
        context.insert(Budget(title: "Svago", category: "Svago", monthlyLimit: 120))
        context.insert(Budget(title: "Spese del mese", monthlyLimit: 1400))

        context.insert(Goal(title: "Vacanza estiva", type: .both, targetAmount: 1500, currentAmount: 620,
                            targetDate: calendar.date(byAdding: .month, value: 5, to: now)))
        context.insert(Goal(title: "Fondo emergenze", type: .economic, targetAmount: 3000, currentAmount: 1850))

        context.insert(Relationship(personName: "Luca", amount: 40, type: .credit, note: "Biglietti concerto",
                                    dueDate: calendar.date(byAdding: .day, value: 5, to: now)))
        context.insert(Relationship(personName: "Giulia", amount: 25, type: .debt, note: "Regalo per Marco",
                                    dueDate: calendar.date(byAdding: .day, value: -3, to: now)))

        if let netflix = calendar.date(byAdding: .day, value: 4, to: now),
           let gym = calendar.date(byAdding: .day, value: 10, to: now) {
            context.insert(RecurringTransaction(title: "Netflix", amount: Decimal(string: "13.99")!, category: "Svago", type: .expense, frequency: .monthly, nextDate: netflix, wallet: card))
            context.insert(RecurringTransaction(title: "Palestra", amount: 39, category: "Salute", type: .expense, frequency: .monthly, nextDate: gym, wallet: bank))
        }

        // Crea le categorie predefinite e registra quelle usate qui (es. "Bar").
        CategoryService.synchronize(in: context)
        try? context.save()
    }
}
#endif
