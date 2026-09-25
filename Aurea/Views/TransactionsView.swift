import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]
    @Query(sort: \Wallet.name) private var wallets: [Wallet]

    /// Mostra "Chiudi" quando la lista è aperta come foglio (dalla Home), non come tab.
    var showsCloseButton = false

    @State private var filter = TransactionFilter()
    @State private var selectedTransaction: Transaction?
    @State private var pendingDeletion: Transaction?
    @State private var exportItem: ExportItem?
    @State private var exportError: String?

    private var filteredTransactions: [Transaction] {
        filter.apply(to: transactions)
    }

    /// Categorie proposte nel filtro, in base al tipo selezionato.
    private var filterCategories: [String] {
        let types: [TransactionType] = switch filter.kind {
        case .all: [.expense, .income]
        case .expenses: [.expense]
        case .income: [.income]
        }
        var seen = Set<String>()
        return categories
            .filter { types.contains($0.type) && !$0.isArchived }
            .map(\.name)
            .filter { seen.insert($0.lowercased()).inserted }
    }

    private var selectedWalletName: String? {
        guard let id = filter.walletID else { return nil }
        return wallets.first { $0.persistentModelID == id }?.name
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
        FinancialEngine.totalExpenses(from: filteredTransactions)
    }

    private var totalIncome: Decimal {
        FinancialEngine.totalIncome(from: filteredTransactions)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filtro", selection: $filter.kind) {
                        ForEach(TransactionKindFilter.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if filter.activeRefinementCount > 0 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if filter.period != .all {
                                    activeFilterChip(filter.period.title) { filter.period = .all }
                                }
                                if let category = filter.category {
                                    activeFilterChip(category) { filter.category = nil }
                                }
                                if let walletName = selectedWalletName {
                                    activeFilterChip(walletName) { filter.walletID = nil }
                                }
                            }
                        }
                    }
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
                            isFiltered ? "Nessun risultato" : "Nessun movimento",
                            systemImage: isFiltered ? "magnifyingglass" : "tray"
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
                                .swipeActions(edge: .trailing) {
                                    if transaction.canBeDeleted {
                                        Button("Elimina", systemImage: "trash") { pendingDeletion = transaction }
                                            .tint(.red)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $filter.searchText, prompt: "Cerca titolo, categoria o portafoglio")
            .navigationTitle("Movimenti")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
                if showsCloseButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Chiudi") { dismiss() }
                    }
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
            }
            .sheet(item: $exportItem) { item in ActivityView(activityItems: [item.url]) }
            .alert("Esportazione non riuscita", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportError ?? "")
            }
            .onChange(of: filter.kind) { _, _ in
                // Una categoria di spesa non ha senso filtrando solo le entrate, e viceversa.
                if let category = filter.category,
                   !filterCategories.contains(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) {
                    filter.category = nil
                }
            }
            .confirmationDialog(
                pendingDeletion?.isTransfer == true ? "Eliminare l’intero trasferimento?" : "Eliminare questo movimento?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { transaction in
                Button("Elimina", role: .destructive) {
                    Transaction.delete(transaction, from: transactions, in: modelContext)
                    pendingDeletion = nil
                }
                Button("Annulla", role: .cancel) { pendingDeletion = nil }
            } message: { transaction in
                Text("\(transaction.title) · \(formattedAmount(for: transaction))")
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Periodo", selection: $filter.period) {
                ForEach(TransactionPeriod.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)

            Picker("Categoria", selection: $filter.category) {
                Text("Tutte le categorie").tag(nil as String?)
                ForEach(filterCategories, id: \.self) { Text($0).tag($0 as String?) }
            }
            .pickerStyle(.menu)

            Picker("Portafoglio", selection: $filter.walletID) {
                Text("Tutti i portafogli").tag(nil as PersistentIdentifier?)
                ForEach(wallets) { Text($0.name).tag($0.persistentModelID as PersistentIdentifier?) }
            }
            .pickerStyle(.menu)

            if filter.activeRefinementCount > 0 {
                Button("Azzera filtri", role: .destructive) {
                    filter.period = .all
                    filter.category = nil
                    filter.walletID = nil
                }
            }

            Divider()

            Button {
                exportFilteredCSV()
            } label: {
                Label(isFiltered ? "Esporta risultati in CSV" : "Esporta tutto in CSV", systemImage: "tablecells")
            }
            .disabled(filteredTransactions.isEmpty)
        } label: {
            Image(systemName: filter.activeRefinementCount > 0
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filtri")
    }

    private var isFiltered: Bool {
        filter.kind != .all || filter.activeRefinementCount > 0 || !filter.searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Esporta esattamente ciò che la lista mostra, filtri e ricerca compresi.
    private func exportFilteredCSV() {
        do { exportItem = ExportItem(url: try CSVExporter.writeFile(for: filteredTransactions)) }
        catch { exportError = error.localizedDescription }
    }

    private func activeFilterChip(_ title: String, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "xmark.circle.fill")
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rimuovi filtro \(title)")
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
        if transaction.isTransfer {
            return "arrow.left.arrow.right.circle"
        }
        return transaction.type == .expense ? "arrow.down.circle" : "arrow.up.circle"
    }

    private func color(for transaction: Transaction) -> Color {
        if transaction.isTransfer {
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
