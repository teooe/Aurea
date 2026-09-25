import Foundation

/// Riepilogo che l'app scrive per il widget. Questo file va incluso sia nel target Aurea
/// sia nel target AureaWidget: è l'unico codice che i due condividono.
/// Il widget non apre il database SwiftData, legge solo questo riepilogo.
nonisolated struct WidgetSnapshot: Codable, Equatable {
    struct BudgetLine: Codable, Equatable {
        var title: String
        var spent: Decimal
        var limit: Decimal

        var ratio: Double {
            guard limit > 0 else { return 0 }
            return NSDecimalNumber(decimal: spent / limit).doubleValue
        }
    }

    /// Primo giorno del mese a cui si riferiscono i totali.
    var monthStart: Date
    var monthExpenses: Decimal
    var monthIncome: Decimal
    /// Giorno a cui si riferisce `todayExpenses`.
    var day: Date
    var todayExpenses: Decimal
    var budgets: [BudgetLine]
    var updatedAt: Date

    var monthBalance: Decimal { monthIncome - monthExpenses }

    /// Il riepilogo appartiene ancora al mese corrente? Se no, il widget invita ad aprire l'app.
    func isCurrentMonth(at date: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.isDate(monthStart, equalTo: date, toGranularity: .month)
    }

    /// Spese di oggi, oppure zero se il riepilogo è di un altro giorno.
    func expensesToday(at date: Date = .now, calendar: Calendar = .current) -> Decimal {
        calendar.isDate(day, inSameDayAs: date) ? todayExpenses : 0
    }

    static let placeholder = WidgetSnapshot(
        monthStart: .now,
        monthExpenses: 84230 / 100,
        monthIncome: 1850,
        day: .now,
        todayExpenses: 1850 / 100,
        budgets: [
            BudgetLine(title: "Alimentari", spent: 312, limit: 400),
            BudgetLine(title: "Svago", spent: 95, limit: 150),
        ],
        updatedAt: .now
    )
}

/// Lettura e scrittura del riepilogo nello spazio condiviso dell'App Group.
nonisolated enum WidgetSnapshotStore {
    /// Deve coincidere con l'App Group attivato in Xcode su entrambi i target.
    static let appGroupID = "group.com.aurea.Aurea"
    static let widgetKind = "AureaWidget"

    private static let key = "aurea.widget.snapshot"

    /// Senza App Group configurato si ricade sulle preferenze dell'app: nessun errore, ma il widget non vede i dati.
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
