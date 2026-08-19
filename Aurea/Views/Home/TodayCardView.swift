import SwiftUI

struct TodayCardView: View {

    let transactions: [Transaction]
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            AureaCard(
                title: "Oggi",
                icon: "calendar"
            ) {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {

                    if transactions.isEmpty {
                        Text("Nessun movimento oggi")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    } else {
                        let visibleTransactions = isExpanded
                            ? transactions
                            : Array(transactions.prefix(2))

                        ForEach(visibleTransactions) { transaction in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(transaction.title)
                                        .fontWeight(.medium)

                                    Text(transaction.category)
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }

                                Spacer()

                                Text(formattedAmount(for: transaction))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(color(for: transaction))
                            }
                        }

                        if !isExpanded && transactions.count > 2 {
                            Text("+ \(transactions.count - 2) altri")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formattedAmount(for transaction: Transaction) -> String {
        let code = transaction.wallet?.currencyCode ?? "EUR"
        let amount = transaction.amount.formatted(.currency(code: code))

        switch transaction.type {
        case .expense:
            return "-\(amount)"
        case .income:
            return "+\(amount)"
        case .transfer:
            return amount
        }
    }

    private func color(for transaction: Transaction) -> Color {
        switch transaction.type {
        case .expense:
            return Theme.Colors.expense
        case .income:
            return Theme.Colors.income
        case .transfer:
            return Theme.Colors.primaryText
        }
    }
}
