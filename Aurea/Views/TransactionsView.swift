import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var searchText = ""
    @State private var filter: MovementFilter = .all
    @State private var selectedTransaction: Transaction?

    private enum MovementFilter: String, CaseIterable, Identifiable {
        case all = "Tutti"
        case expenses = "Spese"
        case income = "Entrate"

        var id: String { rawValue }
    }

    private var filteredTransactions: [Transaction] {
        transactions.filter { transaction in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .expenses:
                matchesFilter = transaction.type == .expense && transaction.category != "Trasferimento"
            case .income:
                matchesFilter = transaction.type == .income && transaction.category != "Trasferimento"
            }

            guard matchesFilter else { return false }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }

            return transaction.title.localizedCaseInsensitiveContains(query) ||
                transaction.category.localizedCaseInsensitiveContains(query) ||
                (transaction.wallet?.name.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }

        return grouped
            .map { (date: $0.key, transactions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    private var totalExpenses: Decimal {
        filteredTransactions
            .filter { $0.type == .expense && $0.category != "Trasferimento" }
            .reduce(.zero) { $0 + $1.amount }
    }

    private var totalIncome: Decimal {
        filteredTransactions
            .filter { $0.type == .income && $0.category != "Trasferimento" }
            .reduce(.zero) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filtro", selection: $filter) {
                        ForEach(MovementFilter.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !filteredTransactions.isEmpty {
                    Section("Riepilogo") {
                        HStack {
                            summaryItem("Entrate", amount: totalIncome, color: Theme.Colors.income)
                            Divider()
                            summaryItem("Spese", amount: totalExpenses, color: Theme.Colors.expense)
                        }
                    }
                }

                if groupedTransactions.isEmpty {
                    Section {
                        ContentUnavailableView(
                            searchText.isEmpty ? "Nessun movimento" : "Nessun risultato",
                            systemImage: searchText.isEmpty ? "tray" : "magnifyingglass"
                        )
                    }
                } else {
                    ForEach(groupedTransactions, id: \.date) { group in
                        Section(group.date.formatted(date: .complete, time: .omitted)) {
                            ForEach(group.transactions) { transaction in
                                Button {
                                    selectedTransaction = transaction
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: icon(for: transaction))
                                            .frame(width: 24)
                                            .foregroundStyle(color(for: transaction))

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(transaction.title)
                                                .foregroundStyle(.primary)

                                            HStack(spacing: 4) {
                                                Text(transaction.category)
                                                if let wallet = transaction.wallet {
                                                    Text("•")
                                                    Text(wallet.name)
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(formattedAmount(for: transaction))
                                            .fontWeight(.medium)
                                            .foregroundStyle(color(for: transaction))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Cerca titolo, categoria o portafoglio")
            .navigationTitle("Movimenti")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
            }
        }
    }

    private func summaryItem(_ title: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount, format: .currency(code: "EUR"))
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func icon(for transaction: Transaction) -> String {
        if transaction.category == "Trasferimento" {
            return "arrow.left.arrow.right.circle"
        }
        return transaction.type == .expense ? "arrow.down.circle" : "arrow.up.circle"
    }

    private func color(for transaction: Transaction) -> Color {
        if transaction.category == "Trasferimento" {
            return Theme.Colors.primaryText
        }
        return transaction.type == .expense ? Theme.Colors.expense : Theme.Colors.income
    }

    private func formattedAmount(for transaction: Transaction) -> String {
        let code = transaction.wallet?.currencyCode ?? "EUR"
        let value = transaction.amount.formatted(.currency(code: code))
        return transaction.type == .expense ? "−\(value)" : "+\(value)"
    }
}
