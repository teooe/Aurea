import SwiftUI
import SwiftData

/// Tab "Analisi": panoramica del mese e consigli calcolati in automatico da InsightsEngine.
/// Ha preso il posto della chat dell'assistente.
struct AnalysisView: View {
    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \Relationship.createdAt, order: .reverse) private var relationships: [Relationship]
    @Query(sort: \RecurringTransaction.nextDate) private var recurring: [RecurringTransaction]

    private var monthTransactions: [Transaction] { TimelineEngine.transactionsForCurrentMonth(from: transactions) }
    private var monthIncome: Decimal { FinancialEngine.totalIncome(from: monthTransactions) }
    private var monthExpenses: Decimal { FinancialEngine.totalExpenses(from: monthTransactions) }

    private var insights: [Insight] {
        InsightsEngine.insights(from: .init(
            transactions: transactions,
            budgets: budgets,
            goals: goals,
            relationships: relationships,
            recurring: recurring
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Grid(horizontalSpacing: 12, verticalSpacing: 14) {
                        GridRow {
                            metric("Patrimonio", FinancialEngine.netWorth(wallets: wallets))
                            metric("Bilancio del mese", monthIncome - monthExpenses)
                        }
                        GridRow {
                            metric("Entrate", monthIncome)
                            metric("Spese", monthExpenses)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(Date.now.formatted(.dateTime.month(.wide).year()).capitalized)
                }

                Section("Da sapere") {
                    ForEach(insights) { insight in
                        insightRow(insight)
                    }
                }

                Section {
                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label("Report completo", systemImage: "chart.bar.xaxis")
                    }
                } footer: {
                    Text("Indicazioni calcolate dai movimenti registrati, non consulenza finanziaria.")
                }
            }
            .navigationTitle("Analisi")
            .animation(.default, value: insights.map(\.id))
        }
    }

    private func metric(_ title: String, _ value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: "EUR")))
                .font(.headline)
                .foregroundStyle(value < 0 ? .red : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func insightRow(_ insight: Insight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.title3)
                .foregroundStyle(color(for: insight.kind))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title).font(.subheadline.weight(.semibold))
                Text(insight.detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func color(for kind: Insight.Kind) -> Color {
        switch kind {
        case .alert: .red
        case .warning: .orange
        case .info: .accentColor
        case .positive: .green
        }
    }
}

#Preview {
    AnalysisView()
        .modelContainer(for: [Wallet.self, Transaction.self, Budget.self, Goal.self, Relationship.self, RecurringTransaction.self], inMemory: true)
}
