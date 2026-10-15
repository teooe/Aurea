import Foundation
import SwiftData

/// Stato di un budget nel periodo corrente (mese o settimana), riporto compreso.
struct BudgetStatus: Equatable {
    var interval: DateInterval
    /// Limite del periodo più l'eventuale riporto.
    var limit: Decimal
    var carriedOver: Decimal
    var spent: Decimal

    var remaining: Decimal { limit - spent }
    var ratio: Double {
        guard limit > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / limit).doubleValue
    }
    var isOver: Bool { spent > limit }
}

/// Unico punto in cui si calcolano i budget: Home, schermata Budget, Analisi, widget e notifiche lo usano tutti.
enum BudgetEngine {

    /// Periodo che contiene `date`. Le settimane iniziano sempre di lunedì, anche con il telefono in un'altra lingua.
    static func interval(for period: BudgetPeriod, containing date: Date, calendar: Calendar = .current) -> DateInterval {
        var calendar = calendar
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: period.component, for: date) ?? DateInterval(start: date, duration: 0)
    }

    static func spent(for budget: Budget, in interval: DateInterval, transactions: [Transaction]) -> Decimal {
        transactions
            .filter { transaction in
                transaction.type == .expense &&
                !transaction.isTransfer &&
                transaction.date >= interval.start && transaction.date < interval.end &&
                (budget.category == nil || transaction.category == budget.category)
            }
            .reduce(Decimal.zero) { $0 + FinancialEngine.amountInEUR(for: $1) }
    }

    /// Stato nel periodo corrente. Il riporto aggiunge solo il residuo positivo del periodo precedente
    /// (non si accumula oltre un periodo, e uno sforamento non riduce il limite successivo).
    static func status(for budget: Budget, transactions: [Transaction], now: Date = .now, calendar: Calendar = .current) -> BudgetStatus {
        let current = interval(for: budget.period, containing: now, calendar: calendar)
        var carried: Decimal = 0
        if budget.rollover,
           let previousDate = calendar.date(byAdding: budget.period.component, value: -1, to: current.start),
           calendar.startOfDay(for: budget.createdAt) < current.start {
            let previous = interval(for: budget.period, containing: previousDate, calendar: calendar)
            carried = max(budget.limit - spent(for: budget, in: previous, transactions: transactions), 0)
        }
        return BudgetStatus(
            interval: current,
            limit: budget.limit + carried,
            carriedOver: carried,
            spent: spent(for: budget, in: current, transactions: transactions)
        )
    }

    /// Quanto si può spendere al giorno fino alla fine del periodo (oggi compreso), arrotondato per difetto.
    static func dailyAllowance(for status: BudgetStatus, now: Date = .now, calendar: Calendar = .current) -> Decimal {
        guard status.remaining > 0 else { return 0 }
        let today = calendar.startOfDay(for: now)
        let days = max(calendar.dateComponents([.day], from: today, to: status.interval.end).day ?? 1, 1)
        var perDay = status.remaining / Decimal(days)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &perDay, 2, .down)
        return rounded
    }

    /// Chiave stabile del periodo, per ricordare quali avvisi sono già stati inviati.
    static func periodKey(for status: BudgetStatus) -> String {
        String(Int(status.interval.start.timeIntervalSince1970))
    }
}
