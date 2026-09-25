import SwiftUI
import SwiftData

struct AureaInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \AgendaItem.date) private var agendaItems: [AgendaItem]
    @Query(sort: \Relationship.createdAt, order: .reverse) private var relationships: [Relationship]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }
    private var monthTransactions: [Transaction] {
        transactions.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }
    private var previousMonthTransactions: [Transaction] {
        guard let previous = Calendar.current.date(byAdding: .month, value: -1, to: .now) else { return [] }
        return transactions.filter { Calendar.current.isDate($0.date, equalTo: previous, toGranularity: .month) }
    }
    private var monthExpenses: Decimal { expenseTotal(monthTransactions) }
    private var previousMonthExpenses: Decimal { expenseTotal(previousMonthTransactions) }
    private var monthIncome: Decimal { incomeTotal(monthTransactions) }
    private var previousMonthIncome: Decimal { incomeTotal(previousMonthTransactions) }
    private var monthBalance: Decimal { monthIncome - monthExpenses }
    private var previousMonthBalance: Decimal { previousMonthIncome - previousMonthExpenses }
    private var openRelationships: [Relationship] { relationships.filter { !$0.isClosed && $0.remainingAmount > 0 } }
    private var openDebts: Decimal { openRelationships.filter { $0.type == .debt }.reduce(0) { $0 + $1.remainingAmount } }
    private var openCredits: Decimal { openRelationships.filter { $0.type == .credit }.reduce(0) { $0 + $1.remainingAmount } }
    private var upcomingAgenda: [AgendaItem] {
        agendaItems.filter { !$0.isCompleted && $0.date >= Calendar.current.startOfDay(for: .now) }.sorted { $0.date < $1.date }
    }
    private var activeGoals: [Goal] { goals.filter { !$0.isCompleted } }

    var body: some View {
        NavigationStack {
            List {
                Section("Situazione attuale") {
                    metric("Patrimonio", value: FinancialEngine.netWorth(wallets: activeWallets), icon: "eurosign.circle")
                    metric("Bilancio del mese", value: monthBalance, icon: "equal.circle")
                }

                Section("Questo mese") {
                    metric("Entrate", value: monthIncome, icon: "arrow.down.circle")
                    metric("Spese", value: monthExpenses, icon: "arrow.up.circle")
                    if let top = topExpenseCategory {
                        HStack {
                            Label("Categoria principale", systemImage: "tag")
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(top.name)
                                Text(top.amount.formatted(.currency(code: "EUR")))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Confronto con il mese scorso") {
                    comparisonRow("Entrate", current: monthIncome, previous: previousMonthIncome, icon: "arrow.down.circle")
                    comparisonRow("Spese", current: monthExpenses, previous: previousMonthExpenses, icon: "arrow.up.circle")
                    comparisonRow("Bilancio", current: monthBalance, previous: previousMonthBalance, icon: "equal.circle")
                }

                Section("Agenda") {
                    if upcomingAgenda.isEmpty {
                        Text("Nessun impegno aperto in programma")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(upcomingAgenda.prefix(4))) { item in
                            HStack(spacing: 12) {
                                Image(systemName: item.type.icon)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .fontWeight(.medium)
                                    Text(item.date.formatted(date: .abbreviated, time: item.hasTime ? .shortened : .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if item.priority == .high {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }

                Section("Debiti e crediti") {
                    metric("Da pagare", value: openDebts, icon: "arrow.up.right.circle")
                    metric("Da ricevere", value: openCredits, icon: "arrow.down.left.circle")
                }

                Section("Obiettivi") {
                    if activeGoals.isEmpty {
                        Text("Nessun obiettivo attivo")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(activeGoals.prefix(4))) { goal in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(goal.title).fontWeight(.medium)
                                    Spacer()
                                    if let target = goal.targetAmount, target > 0 {
                                        Text("\(Int(progress(goal) * 100))%")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if let target = goal.targetAmount, target > 0 {
                                    ProgressView(value: min(max(progress(goal), 0), 1))
                                } else if let date = goal.targetDate {
                                    Text("Scadenza: \(date.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Panoramica")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }

    private func metric(_ title: String, value: Decimal, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value.formatted(.currency(code: "EUR")))
                .fontWeight(.semibold)
        }
    }

    private func comparisonRow(_ title: String, current: Decimal, previous: Decimal, icon: String) -> some View {
        let delta = current - previous
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(current.formatted(.currency(code: "EUR")))
                    .fontWeight(.semibold)
            }
            HStack {
                Text("Mese scorso: \(previous.formatted(.currency(code: "EUR")))")
                Spacer()
                Text(deltaText(delta))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func valueInEUR(_ transaction: Transaction) -> Decimal {
        transaction.amount * (transaction.wallet?.effectiveExchangeRateToEUR ?? 1)
    }

    private func expenseTotal(_ source: [Transaction]) -> Decimal {
        source.filter { $0.type == .expense && !$0.isTransfer }.reduce(0) { $0 + valueInEUR($1) }
    }

    private func incomeTotal(_ source: [Transaction]) -> Decimal {
        source.filter { $0.type == .income && !$0.isTransfer }.reduce(0) { $0 + valueInEUR($1) }
    }

    private var topExpenseCategory: (name: String, amount: Decimal)? {
        let expenses = monthTransactions.filter { $0.type == .expense && !$0.isTransfer }
        let grouped = Dictionary(grouping: expenses, by: \Transaction.category)
        return grouped.map { key, value in
            (name: key, amount: value.reduce(0) { $0 + valueInEUR($1) })
        }.max { $0.amount < $1.amount }
    }

    private func deltaText(_ delta: Decimal) -> String {
        let absolute = delta < 0 ? -delta : delta
        if delta == 0 { return "Invariato" }
        return "\(absolute.formatted(.currency(code: "EUR"))) \(delta < 0 ? "in meno" : "in più")"
    }

    private func progress(_ goal: Goal) -> Double {
        guard let target = goal.targetAmount, target > 0 else { return 0 }
        return NSDecimalNumber(decimal: goal.currentAmount / target).doubleValue
    }
}
