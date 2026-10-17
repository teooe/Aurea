import Foundation

/// Stima di come finirà il mese corrente.
///
/// - Le ricorrenze ancora da pagare entro fine mese si aggiungono così come sono.
/// - Le altre spese proseguono alla media giornaliera tenuta finora, escluse quelle già
///   registrate dalle ricorrenze (affitto, abbonamenti), che non si ripetono ogni giorno.
/// - Le entrate non si proiettano: contano solo quelle avvenute e le ricorrenti previste.
enum ForecastEngine {

    struct MonthForecast: Equatable {
        var incomeSoFar: Decimal
        var expensesSoFar: Decimal
        var upcomingIncome: Decimal
        var upcomingExpenses: Decimal
        /// Spese "libere" previste da qui a fine mese, alla media giornaliera attuale.
        var projectedVariableExpenses: Decimal
        var daysLeft: Int

        var projectedIncome: Decimal { incomeSoFar + upcomingIncome }
        var projectedExpenses: Decimal { expensesSoFar + upcomingExpenses + projectedVariableExpenses }
        var projectedBalance: Decimal { projectedIncome - projectedExpenses }
    }

    /// Con meno giorni la media giornaliera è poco affidabile: nessuna previsione.
    static let minimumElapsedDays = 3

    static func monthForecast(
        transactions: [Transaction],
        recurring: [RecurringTransaction],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> MonthForecast? {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        let elapsedDays = (calendar.dateComponents([.day], from: month.start, to: startOfToday).day ?? 0) + 1
        guard elapsedDays >= minimumElapsedDays else { return nil }
        let totalDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let daysLeft = max(totalDays - elapsedDays, 0)

        let monthTransactions = transactions.filter { month.contains($0.date) && $0.date <= now && !$0.isTransfer }
        let income = monthTransactions.filter { $0.type == .income }
        let expenses = monthTransactions.filter { $0.type == .expense }
        let incomeSoFar = income.reduce(Decimal.zero) { $0 + FinancialEngine.amountInEUR(for: $1) }
        let expensesSoFar = expenses.reduce(Decimal.zero) { $0 + FinancialEngine.amountInEUR(for: $1) }

        let active = recurring.filter(\.isActive)
        // Un movimento creato da una ricorrenza ne ripete titolo, importo e categoria.
        func isFromRecurring(_ transaction: Transaction) -> Bool {
            active.contains { $0.type == transaction.type && $0.title == transaction.title && $0.amount == transaction.amount && $0.category == transaction.category }
        }
        let recurringPaid = expenses.filter(isFromRecurring).reduce(Decimal.zero) { $0 + FinancialEngine.amountInEUR(for: $1) }

        var upcomingIncome = Decimal.zero
        var upcomingExpenses = Decimal.zero
        for item in active where item.type != .transfer {
            let rate = item.wallet?.effectiveExchangeRateToEUR ?? 1
            var date = item.nextDate
            // Le occorrenze già scadute vengono registrate all'apertura dell'app: si contano da adesso in poi.
            while date <= now { date = item.frequency.nextDate(after: date, calendar: calendar) }
            while date < month.end {
                if item.type == .income { upcomingIncome += item.amount * rate } else { upcomingExpenses += item.amount * rate }
                date = item.frequency.nextDate(after: date, calendar: calendar)
            }
        }

        let variableSoFar = max(expensesSoFar - recurringPaid, 0)
        var projected = variableSoFar / Decimal(elapsedDays) * Decimal(daysLeft)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &projected, 2, .plain)

        return MonthForecast(
            incomeSoFar: incomeSoFar,
            expensesSoFar: expensesSoFar,
            upcomingIncome: upcomingIncome,
            upcomingExpenses: upcomingExpenses,
            projectedVariableExpenses: rounded,
            daysLeft: daysLeft
        )
    }
}
