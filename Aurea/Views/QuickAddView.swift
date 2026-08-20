import SwiftUI
import SwiftData

struct QuickAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var wallets: [Wallet]

    @State private var type: TransactionType = .expense
    @State private var title = ""
    @State private var amount = ""
    @State private var category = ""
    @State private var selectedWallet: Wallet?
    @State private var showingConfirmation = false

    private let expenseCategories = [
        "Alimentari", "Trasporti", "Casa", "Svago", "Salute", "Shopping", "Altro"
    ]

    private let incomeCategories = [
        "Stipendio", "Regalo", "Rimborso", "Vendita", "Altro"
    ]

    private var suggestedCategories: [String] {
        switch type {
        case .expense:
            expenseCategories
        case .income:
            incomeCategories
        case .transfer:
            ["Trasferimento"]
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        Text("Spesa").tag(TransactionType.expense)
                        Text("Entrata").tag(TransactionType.income)
                        Text("Trasferimento").tag(TransactionType.transfer)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, newValue in
                        if newValue == .transfer {
                            category = "Trasferimento"
                        } else if category == "Trasferimento" {
                            category = ""
                        }
                    }
                }

                Section("Movimento") {
                    TextField("Titolo", text: $title)

                    TextField("Importo", text: $amount)
                        .keyboardType(.decimalPad)

                    TextField("Categoria", text: $category)

                    if type != .transfer {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedCategories, id: \.self) { suggestion in
                                    Button(suggestion) {
                                        category = suggestion
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }

                Section("Portafoglio") {
                    if wallets.isEmpty {
                        Text("Nessun portafoglio disponibile")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Portafoglio", selection: $selectedWallet) {
                            Text("Seleziona")
                                .tag(nil as Wallet?)

                            ForEach(wallets) { wallet in
                                Label(wallet.name, systemImage: wallet.icon)
                                    .tag(wallet as Wallet?)
                            }
                        }
                    }
                }

                Section {
                    Button("Continua") {
                        showingConfirmation = true
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Nuovo movimento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if selectedWallet == nil {
                    selectedWallet = wallets.first
                }
            }
            .confirmationDialog(
                "Conferma movimento",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Salva") {
                    saveTransaction()
                }
                Button("Annulla", role: .cancel) { }
            } message: {
                Text(confirmationText)
            }
        }
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amount.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (parsedAmount ?? 0) > 0 &&
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedWallet != nil
    }

    private var confirmationText: String {
        let typeText: String
        switch type {
        case .expense: typeText = "Spesa"
        case .income: typeText = "Entrata"
        case .transfer: typeText = "Trasferimento"
        }

        let amountText = parsedAmount?.formatted(.currency(code: selectedWallet?.currencyCode ?? "EUR")) ?? ""
        return "\(typeText): \(title) • \(amountText) • \(category)"
    }

    private func saveTransaction() {
        guard let decimalAmount = parsedAmount,
              let wallet = selectedWallet else {
            return
        }

        let transaction = Transaction(
            type: type,
            amount: decimalAmount,
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            wallet: wallet
        )

        modelContext.insert(transaction)
        dismiss()
    }
}

#Preview {
    QuickAddView()
        .modelContainer(
            for: [Wallet.self, Transaction.self],
            inMemory: true
        )
}
