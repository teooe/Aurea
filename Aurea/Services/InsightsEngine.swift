import Foundation
import SwiftData

/// Un consiglio mostrato nel tab Analisi.
struct Insight: Identifiable, Equatable {
    enum Kind: Int, Comparable {
        case alert, warning, info, positive

        static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Chiave stabile (es. "budget-<id>") per le animazioni della lista.
    let id: String
    let kind: Kind
    let icon: String
    let title: String
    let detail: String
}

/// Calcola i consigli dai dati registrati, senza domande da scrivere: sostituisce la chat
/// dell'assistente con ciò che serviva davvero (budget, andamento, risparmio, scadenze).
enum InsightsEngine {

    struct Input {
        var transactions: [Transaction]
        var budgets: [Budget] = []
        var goals: [Goal] = []
        var relationships: [Relationship] = []
        var recurring: [RecurringTransaction] = []
    }

    static func insights(from input: Input, now: Date = .now, calendar: Calendar = .current) -> [Insight] {
        var result: [Insight] = []
        result += budgetInsights(input.budgets, transactions: input.transactions, now: now, calendar: calendar)
        result += paceInsights(input.transactions, now: now, calendar: calendar)
        result += relationshipInsights(input.relationships, now: now, calendar: calendar)
        result += goalInsights(input.goals, now: now, calendar: calendar)
        result += recurringInsights(input.recurring, now: now, calendar: calendar)

        if result.isEmpty {
            result.append(Insight(id: "all-good", kind: .positive, icon: "checkmark.seal", title: "Tutto sotto controllo", detail: "Nessun budget a rischio e nessuna scadenza in arrivo."))
        }
        // Stabile: a parità di gravità resta l'ordine delle sezioni.
        return result.enumerated().sorted { ($0.element.kind, $0.offset) < ($1.element.kind, $1.offset) }.map(\.element)
    }

    // MARK: - Budget

    static func budgetInsights(_ budgets: [Budget], transactions: [Transaction], now: Date, calendar: Calendar) -> [Insight] {
        let month = transactions.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        return budgets
            .filter { !$0.isArchived && $0.monthlyLimit > 0 }
            .compactMap { budget in
                let spent = FinancialEngine.spentThisMonth(for: budget, transactions: month, calendar: calendar)
                let ratio = double(spent / budget.monthlyLimit)
                if ratio >= 1 {
                    return Insight(id: "budget-\(budget.id)", kind: .alert, icon: "exclamationmark.octagon", title: "Budget \(budget.title) superato",
                                   detail: "Hai speso \(euro(spent)) su \(euro(budget.monthlyLimit)), \(euro(spent - budget.monthlyLimit)) oltre il limite.")
                }
                if ratio >= 0.8 {
                    return Insight(id: "budget-\(budget.id)", kind: .warning, icon: "gauge.with.dots.needle.67percent", title: "Budget \(budget.title): \(Int(ratio * 100))% usato",
                                   detail: "Restano \(euro(budget.monthlyLimit - spent)) fino a fine mese: \(euro(FinancialEngine.dailyAllowance(limit: budget.monthlyLimit, spent: spent, now: now, calendar: calendar))) al giorno.")
                }
                return nil
            }
    }

    // MARK: - Andamento e risparmio

    /// Confronta il mese in corso con lo stesso periodo del mese scorso (es. 1–25 con 1–25),
    /// così a metà mese il confronto non è falsato.
    static func paceInsights(_ transactions: [Transaction], now: Date, calendar: Calendar) -> [Insight] {
        guard let current = calendar.dateInterval(of: .month, for: now),
              let previousStart = calendar.date(byAdding: .month, value: -1, to: current.start),
              let previousMonth = calendar.dateInterval(of: .month, for: previousStart) else { return [] }

        let elapsed = now.timeIntervalSince(current.start)
        let previousEnd = min(previousMonth.start.addingTimeInterval(elapsed), previousMonth.end)
        let thisPeriod = transactions.filter { $0.date >= current.start && $0.date <= now }
        let lastPeriod = transactions.filter { $0.date >= previousMonth.start && $0.date < previousEnd }

        let expenses = FinancialEngine.totalExpenses(from: thisPeriod)
        let income = FinancialEngine.totalIncome(from: thisPeriod)
        let previousExpenses = FinancialEngine.totalExpenses(from: lastPeriod)
        var result: [Insight] = []

        if previousExpenses > 0 {
            let change = double((expenses - previousExpenses) / previousExpenses)
            let percent = Int((abs(change) * 100).rounded())
            if change >= 0.2 {
                result.append(Insight(id: "pace", kind: .warning, icon: "arrow.up.right.circle", title: "Stai spendendo di più",
                                      detail: "Finora \(euro(expenses)), il \(percent)% in più dello stesso periodo del mese scorso."))
            } else if change <= -0.1 {
                result.append(Insight(id: "pace", kind: .positive, icon: "arrow.down.right.circle", title: "Stai spendendo meno",
                                      detail: "Finora \(euro(expenses)), il \(percent)% in meno dello stesso periodo del mese scorso."))
            } else {
                result.append(Insight(id: "pace", kind: .info, icon: "equal.circle", title: "Spese in linea con il mese scorso",
                                      detail: "Finora \(euro(expenses)) contro \(euro(previousExpenses)) nello stesso periodo."))
            }
        }

        if expenses > income && income > 0 {
            result.append(Insight(id: "balance", kind: .warning, icon: "minus.circle", title: "Spese superiori alle entrate",
                                  detail: "Questo mese sei a \(euro(income - expenses))."))
        }

        if let saving = savingInsight(thisPeriod: thisPeriod, lastPeriod: lastPeriod, totalExpenses: expenses) {
            result.append(saving)
        }
        return result
    }

    /// "Dove risparmiare": la categoria cresciuta di più, altrimenti quella che pesa di più.
    private static func savingInsight(thisPeriod: [Transaction], lastPeriod: [Transaction], totalExpenses: Decimal) -> Insight? {
        let current = expensesByCategory(thisPeriod)
        let previous = expensesByCategory(lastPeriod)

        let growth = current.compactMap { name, amount -> (name: String, amount: Decimal, delta: Decimal, ratio: Double)? in
            let before = previous[name] ?? 0
            guard before > 0 else { return nil }
            let delta = amount - before
            return (name, amount, delta, double(delta / before))
        }
        .filter { $0.ratio >= 0.25 && $0.delta >= 20 }
        .max { $0.delta < $1.delta }

        if let growth {
            return Insight(id: "saving", kind: .warning, icon: "lightbulb", title: "Dove risparmiare: \(growth.name)",
                           detail: "\(euro(growth.amount)) finora, +\(Int((growth.ratio * 100).rounded()))% (\(euro(growth.delta)) in più) rispetto allo stesso periodo del mese scorso.")
        }

        guard totalExpenses > 0, let top = current.max(by: { $0.value < $1.value }) else { return nil }
        let share = Int((double(top.value / totalExpenses) * 100).rounded())
        return Insight(id: "saving", kind: .info, icon: "chart.pie", title: "Voce principale: \(top.key)",
                       detail: "\(euro(top.value)), il \(share)% delle spese del mese.")
    }

    private static func expensesByCategory(_ transactions: [Transaction]) -> [String: Decimal] {
        transactions
            .filter { $0.type == .expense && !$0.isTransfer }
            .reduce(into: [:]) { $0[$1.category, default: 0] += FinancialEngine.amountInEUR(for: $1) }
    }

    // MARK: - Debiti e crediti

    static func relationshipInsights(_ relationships: [Relationship], now: Date, calendar: Calendar) -> [Insight] {
        let open = relationships.filter { !$0.isClosed && $0.remainingAmount > 0 }
        guard !open.isEmpty else { return [] }
        let today = calendar.startOfDay(for: now)
        var result: [Insight] = []

        for item in open.sorted(by: { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }) {
            guard let due = item.dueDate, due < today else { continue }
            let when = due.formatted(date: .abbreviated, time: .omitted)
            if item.type == .debt {
                result.append(Insight(id: "relationship-\(item.id)", kind: .alert, icon: "person.crop.circle.badge.exclamationmark",
                                      title: "Debito scaduto con \(item.personName)", detail: "\(euro(item.remainingAmount)) da restituire, scadenza \(when)."))
            } else {
                result.append(Insight(id: "relationship-\(item.id)", kind: .warning, icon: "person.crop.circle.badge.clock",
                                      title: "\(item.personName) ti deve \(euro(item.remainingAmount))", detail: "Scadenza superata il \(when)."))
            }
        }

        let debts = open.filter { $0.type == .debt }.reduce(Decimal.zero) { $0 + $1.remainingAmount }
        let credits = open.filter { $0.type == .credit }.reduce(Decimal.zero) { $0 + $1.remainingAmount }
        result.append(Insight(id: "relationships", kind: .info, icon: "person.2", title: "Debiti e crediti aperti",
                              detail: "\(euro(debts)) da pagare e \(euro(credits)) da ricevere."))
        return result
    }

    // MARK: - Obiettivi

    static func goalInsights(_ goals: [Goal], now: Date, calendar: Calendar) -> [Insight] {
        let soon = calendar.date(byAdding: .day, value: 30, to: now) ?? now
        return goals
            .filter { !$0.isCompleted }
            .compactMap { goal in
                let remaining = goal.targetAmount.map { max($0 - goal.currentAmount, 0) }
                let progress = goal.targetAmount.flatMap { $0 > 0 ? Int(min(double(goal.currentAmount / $0), 1) * 100) : nil }

                if let date = goal.targetDate, date <= soon, remaining.map({ $0 > 0 }) ?? true {
                    var detail = "Scadenza \(date.formatted(date: .abbreviated, time: .omitted))"
                    if let remaining { detail += ", mancano \(euro(remaining))" }
                    return Insight(id: "goal-\(goal.id)", kind: .warning, icon: "target", title: "Obiettivo \(goal.title) in scadenza", detail: detail + ".")
                }
                if let remaining, let progress, remaining > 0 {
                    return Insight(id: "goal-\(goal.id)", kind: .info, icon: "target", title: "Obiettivo \(goal.title): \(progress)%", detail: "Mancano \(euro(remaining)).")
                }
                return nil
            }
    }

    // MARK: - Ricorrenti

    static func recurringInsights(_ recurring: [RecurringTransaction], now: Date, calendar: Calendar) -> [Insight] {
        let limit = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        let upcoming = recurring
            .filter { $0.isActive && $0.type == .expense && $0.nextDate > now && $0.nextDate <= limit }
            .sorted { $0.nextDate < $1.nextDate }
        guard !upcoming.isEmpty else { return [] }

        let total = upcoming.reduce(Decimal.zero) { $0 + $1.amount * ($1.wallet?.effectiveExchangeRateToEUR ?? 1) }
        let names = upcoming.prefix(3).map(\.title).joined(separator: ", ")
        let title = upcoming.count == 1 ? "1 pagamento ricorrente in settimana" : "\(upcoming.count) pagamenti ricorrenti in settimana"
        return [Insight(id: "recurring", kind: .info, icon: "repeat", title: title, detail: "\(names): \(euro(total)) in totale.")]
    }

    // MARK: - Utilità

    private static func euro(_ value: Decimal) -> String {
        value.formatted(.currency(code: "EUR"))
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
