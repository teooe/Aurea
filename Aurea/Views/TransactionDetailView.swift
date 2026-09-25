import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransactions: [Transaction]

    let transaction: Transaction

    @State private var showingDeleteConfirmation = false
    @State private var showingEdit = false

    private var isTransfer: Bool {
        transaction.isTransfer
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movimento") {
                    LabeledContent("Titolo", value: transaction.title)
                    LabeledContent("Categoria", value: transaction.category)
                    LabeledContent("Tipo", value: typeTitle)
                    LabeledContent("Importo", value: signedAmount)
                    LabeledContent("Data", value: transaction.date.formatted(date: .abbreviated, time: .shortened))
                    if let wallet = transaction.wallet {
                        LabeledContent("Portafoglio", value: wallet.name)
                    }
                }

                if isTransfer {
                    Section {
                        Label("Questo movimento fa parte di un trasferimento tra portafogli.", systemImage: "arrow.left.arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if transaction.transferGroupID != nil {
                        Section {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Elimina trasferimento", systemImage: "trash")
                            }
                        }
                    }
                } else {
                    Section {
                        Button { showingEdit = true } label: {
                            Label("Modifica movimento", systemImage: "pencil")
                        }
                    }

                    Section {
                        Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                            Label("Elimina movimento", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Dettaglio movimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
            }
            .sheet(isPresented: $showingEdit) {
                EditTransactionView(transaction: transaction)
            }
            .confirmationDialog(isTransfer ? "Eliminare l’intero trasferimento?" : "Eliminare questo movimento?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Elimina", role: .destructive) { deleteMovement() }
                Button("Annulla", role: .cancel) { }
            }
        }
    }

    private func deleteMovement() {
        if isTransfer, let groupID = transaction.transferGroupID {
            for item in allTransactions where item.transferGroupID == groupID {
                modelContext.delete(item)
            }
        } else {
            modelContext.delete(transaction)
        }
        dismiss()
    }

    private var typeTitle: String {
        if isTransfer { return "Trasferimento" }
        switch transaction.type {
        case .expense: return "Spesa"
        case .income: return "Entrata"
        case .transfer: return "Trasferimento"
        }
    }

    private var signedAmount: String {
        let code = transaction.wallet?.currencyCode ?? "EUR"
        let amount = transaction.amount.formatted(.currency(code: code))
        switch transaction.type {
        case .expense: return "−\(amount)"
        case .income: return "+\(amount)"
        case .transfer: return amount
        }
    }
}

private struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]

    let transaction: Transaction

    @State private var title: String
    @State private var amount: String
    @State private var category: String
    @State private var type: TransactionType
    @State private var selectedWallet: Wallet?
    @State private var date: Date

    init(transaction: Transaction) {
        self.transaction = transaction
        _title = State(initialValue: transaction.title)
        _amount = State(initialValue: NSDecimalNumber(decimal: transaction.amount).stringValue)
        _category = State(initialValue: transaction.category)
        _type = State(initialValue: transaction.type)
        _selectedWallet = State(initialValue: transaction.wallet)
        _date = State(initialValue: transaction.date)
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amount.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !Transaction.isReservedCategory(category) &&
        (parsedAmount ?? 0) > 0 &&
        selectedWallet != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        Text("Spesa").tag(TransactionType.expense)
                        Text("Entrata").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Movimento") {
                    TextField("Titolo", text: $title)
                    TextField("Importo", text: $amount).keyboardType(.decimalPad)
                    TextField("Categoria", text: $category)
                    DatePicker("Data", selection: $date)
                }

                Section("Portafoglio") {
                    Picker("Portafoglio", selection: $selectedWallet) {
                        ForEach(wallets.filter { !$0.isArchived }) { wallet in
                            Label(wallet.name, systemImage: wallet.icon).tag(wallet as Wallet?)
                        }
                    }
                }
            }
            .navigationTitle("Modifica movimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let parsedAmount, let selectedWallet else { return }
        transaction.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.amount = parsedAmount
        transaction.category = CategoryService.resolve(category, type: type, in: modelContext)
        transaction.type = type
        transaction.wallet = selectedWallet
        transaction.date = date
        dismiss()
    }
}
