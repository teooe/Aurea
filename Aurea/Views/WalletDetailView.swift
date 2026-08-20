import SwiftUI
import SwiftData

struct WalletDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let wallet: Wallet

    private var transactions: [Transaction] {
        wallet.transactions.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Saldo") {
                    HStack {
                        Text("Saldo attuale")
                        Spacer()
                        Text(
                            FinancialEngine.balance(for: wallet),
                            format: .currency(code: wallet.currencyCode)
                        )
                        .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Saldo iniziale")
                        Spacer()
                        Text(
                            wallet.initialBalance,
                            format: .currency(code: wallet.currencyCode)
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Movimenti") {
                    if transactions.isEmpty {
                        Text("Nessun movimento")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(transactions) { transaction in
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: transaction))
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(transaction.title)
                                    Text("\(transaction.category) • \(transaction.date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(signedAmount(for: transaction))
                                    .fontWeight(.medium)
                                    .foregroundStyle(amountColor(for: transaction))
                            }
                        }
                        .onDelete(perform: deleteTransactions)
                    }
                }
            }
            .navigationTitle(wallet.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    private func icon(for transaction: Transaction) -> String {
        switch transaction.type {
        case .expense: return "arrow.down.circle"
        case .income: return "arrow.up.circle"
        case .transfer: return "arrow.left.arrow.right.circle"
        }
    }

    private func signedAmount(for transaction: Transaction) -> String {
        let value = transaction.amount.formatted(.currency(code: wallet.currencyCode))
        switch transaction.type {
        case .expense: return "−\(value)"
        case .income: return "+\(value)"
        case .transfer: return value
        }
    }

    private func amountColor(for transaction: Transaction) -> Color {
        switch transaction.type {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .secondary
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(transactions[index])
        }
    }
}
