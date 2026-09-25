import Foundation
import SwiftData
import WidgetKit

/// Calcola il riepilogo per il widget dai dati dell'app e chiede a WidgetKit di aggiornarsi.
enum WidgetSnapshotBuilder {

    static func make(transactions: [Transaction], budgets: [Budget], now: Date = .now, calendar: Calendar = .current) -> WidgetSnapshot {
        let month = transactions.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        let today = month.filter { calendar.isDate($0.date, inSameDayAs: now) }

        let budgetLines = budgets
            .filter { !$0.isArchived && $0.monthlyLimit > 0 }
            .map { budget in
                WidgetSnapshot.BudgetLine(
                    title: budget.title,
                    spent: FinancialEngine.spentThisMonth(for: budget, transactions: month, calendar: calendar),
                    limit: budget.monthlyLimit
                )
            }
            .sorted { $0.ratio > $1.ratio }

        return WidgetSnapshot(
            monthStart: calendar.dateInterval(of: .month, for: now)?.start ?? now,
            monthExpenses: FinancialEngine.totalExpenses(from: month),
            monthIncome: FinancialEngine.totalIncome(from: month),
            day: calendar.startOfDay(for: now),
            todayExpenses: FinancialEngine.totalExpenses(from: today),
            budgets: Array(budgetLines.prefix(3)),
            updatedAt: now
        )
    }

    /// Rilegge i dati dal contesto, salva il riepilogo e aggiorna il widget se qualcosa è cambiato.
    static func refresh(in context: ModelContext) {
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        var snapshot = make(transactions: transactions, budgets: budgets)

        if let previous = WidgetSnapshotStore.load() {
            // Confronta ignorando l'orario di aggiornamento, per non ridisegnare il widget senza motivo.
            snapshot.updatedAt = previous.updatedAt
            if snapshot == previous { return }
            snapshot.updatedAt = .now
        }

        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.widgetKind)
    }
}
