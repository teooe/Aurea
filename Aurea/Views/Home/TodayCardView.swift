import SwiftUI
import SwiftData

struct TodayCardView: View {

    let transactions: [Transaction]
    let isExpanded: Bool
    let onTap: () -> Void
    let onSelectTransaction: (Transaction) -> Void
    let onShowAll: () -> Void

    private var expenses: Decimal { FinancialEngine.totalExpenses(from: transactions) }
    private var income: Decimal { FinancialEngine.totalIncome(from: transactions) }

    var body: some View {
        AureaCard(
            title: "Oggi",
            icon: "calendar"
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Button {
                    onTap()
                } label: {
                    Group {
                        if transactions.isEmpty {
                            HStack {
                                Text("Nessun movimento oggi").foregroundStyle(Theme.Colors.secondaryText)
                                Spacer()
                            }
                        } else {
                            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                HStack(spacing: Theme.Spacing.medium) {
                                    summaryItem(title: "Entrate", amount: income, color: Theme.Colors.income)
                                    Divider().frame(height: 34)
                                    summaryItem(title: "Spese", amount: expenses, color: Theme.Colors.expense)
                                }
                                if !isExpanded {
                                    Text("\(transactions.count) \(transactions.count == 1 ? "movimento" : "movimenti")")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if !transactions.isEmpty {
                        Divider()
                        ForEach(transactions) { transaction in
                            Button { onSelectTransaction(transaction) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(transaction.title).fontWeight(.medium).foregroundStyle(.primary)
                                        HStack(spacing: 4) {
                                            Text(transaction.category)
                                            if let wallet = transaction.wallet {
                                                Text("•")
                                                Text(wallet.name)
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                    }
                                    Spacer()
                                    Text(formattedAmount(for: transaction))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(color(for: transaction))
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button { onShowAll() } label: {
                        Label("Tutti i movimenti", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func summaryItem(title: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(Theme.Colors.secondaryText)
            Text(amount, format: .currency(code: "EUR")).font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedAmount(for transaction: Transaction) -> String {
        let code = transaction.wallet?.currencyCode ?? "EUR"
        let amount = transaction.amount.formatted(.currency(code: code))
        switch transaction.type {
        case .expense: return "−\(amount)"
        case .income: return "+\(amount)"
        case .transfer: return amount
        }
    }

    private func color(for transaction: Transaction) -> Color {
        if transaction.isTransfer { return Theme.Colors.primaryText }
        switch transaction.type {
        case .expense: return Theme.Colors.expense
        case .income: return Theme.Colors.income
        case .transfer: return Theme.Colors.primaryText
        }
    }
}
