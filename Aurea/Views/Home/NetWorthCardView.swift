import SwiftUI
import SwiftData

struct NetWorthCardView: View {

    let totalNetWorth: Decimal
    let wallets: [Wallet]
    let monthlyTransactions: [Transaction]
    let transactionCount: Int
    let isExpanded: Bool
    let onTap: () -> Void

    private var monthlyIncome: Decimal { FinancialEngine.totalIncome(from: monthlyTransactions) }
    private var monthlyExpenses: Decimal { FinancialEngine.totalExpenses(from: monthlyTransactions) }
    private var monthlyCashFlow: Decimal { FinancialEngine.cashFlow(from: monthlyTransactions) }

    var body: some View {
        Button {
            onTap()
        } label: {
            AureaCard(title: "Patrimonio", icon: "wallet.pass") {
                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                    Text(totalNetWorth, format: .currency(code: "EUR"))
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack {
                        Text("Patrimonio totale").font(.subheadline).foregroundStyle(Theme.Colors.secondaryText)
                        Spacer()
                        if !monthlyTransactions.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: monthlyCashFlow >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(monthlyCashFlow, format: .currency(code: "EUR"))
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(monthlyCashFlow >= 0 ? Theme.Colors.income : Theme.Colors.expense)
                        }
                    }

                    if isExpanded {
                        Divider()
                        HStack(spacing: Theme.Spacing.medium) {
                            metric(title: "Entrate mese", value: monthlyIncome, color: Theme.Colors.income)
                            Divider().frame(height: 36)
                            metric(title: "Spese mese", value: monthlyExpenses, color: Theme.Colors.expense)
                        }

                        if !wallets.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                Text("Distribuzione").font(.caption.weight(.semibold)).foregroundStyle(Theme.Colors.secondaryText)
                                ForEach(wallets) { wallet in
                                    HStack {
                                        Label(wallet.name, systemImage: wallet.icon).foregroundStyle(.primary)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 1) {
                                            Text(FinancialEngine.balance(for: wallet), format: .currency(code: wallet.currencyCode))
                                                .fontWeight(.medium).foregroundStyle(.primary)
                                            if wallet.currencyCode != "EUR" {
                                                Text(FinancialEngine.balanceInEUR(for: wallet), format: .currency(code: "EUR"))
                                                    .font(.caption2).foregroundStyle(Theme.Colors.secondaryText)
                                            }
                                        }
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }

                        HStack {
                            Label("\(wallets.count)", systemImage: "creditcard")
                            Spacer()
                            Label("\(transactionCount)", systemImage: "arrow.left.arrow.right")
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func metric(title: String, value: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(Theme.Colors.secondaryText)
            Text(value, format: .currency(code: "EUR")).font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
