import SwiftUI
import SwiftData

struct QuickAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]

    @State private var type: TransactionType = .expense
    @State private var title = ""
    @State private var amount = ""
    @State private var category = ""
    @State private var selectedWallet: Wallet?
    @State private var destinationWallet: Wallet?
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

    private var recentCategories: [String] {
        var seen = Set<String>()
        var result: [String] = []

        for transaction in transactions where transaction.type == type {
            let value = transaction.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty,
                  value != "Trasferimento",
                  !seen.contains(value) else { continue }

            seen.insert(value)
            result.append(value)

            if result.count == 3 { break }
        }

        return result
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
                            if destinationWallet == nil || destinationWallet === selectedWallet {
                                destinationWallet = wallets.first { $0 !== selectedWallet }
                            }
                        } else if category == "Trasferimento" {
                            category = ""
                        }
                    }
                }

                Section("Movimento") {
                    TextField("Titolo", text: $title)
                        .textInputAutocapitalization(.sentences)

                    TextField("Importo", text: $amount)
                        .keyboardType(.decimalPad)

                    if type != .transfer {
                        TextField("Categoria", text: $category)

                        if !recentCategories.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Usate di recente")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(recentCategories, id: \.self) { suggestion in
                                            Button(suggestion) {
                                                category = suggestion
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                        }
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Categorie")
                                .font(.caption)
                                .foregroundStyle(.secondary)

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
                }

                if type == .transfer {
                    Section("Trasferimento") {
                        if wallets.count < 2 {
                            Text("Servono almeno due portafogli per effettuare un trasferimento.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Da", selection: $selectedWallet) {
                                ForEach(wallets) { wallet in
                                    Label(wallet.name, systemImage: wallet.icon)
                                        .tag(wallet as Wallet?)
                                }
                            }
                            .onChange(of: selectedWallet) { _, newWallet in
                                if destinationWallet === newWallet {
                                    destinationWallet = wallets.first { $0 !== newWallet }
                                }
                            }

                            Picker("A", selection: $destinationWallet) {
                                ForEach(wallets.filter { $0 !== selectedWallet }) { wallet in
                                    Label(wallet.name, systemImage: wallet.icon)
                                        .tag(wallet as Wallet?)
                                }
                            }
                        }
                    }
                } else {
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
                if destinationWallet == nil {
                    destinationWallet = wallets.first { $0 !== selectedWallet }
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
        let baseValid = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            (parsedAmount ?? 0) > 0 &&
            selectedWallet != nil

        if type == .transfer {
            return baseValid &&
                wallets.count >= 2 &&
                destinationWallet != nil &&
                destinationWallet !== selectedWallet
        }

        return baseValid &&
            !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var confirmationText: String {
        let amountText = parsedAmount?.formatted(.currency(code: selectedWallet?.currencyCode ?? "EUR")) ?? ""

        if type == .transfer {
            let source = selectedWallet?.name ?? ""
            let destination = destinationWallet?.name ?? ""
            return "Trasferimento: \(title) • \(amountText) • da \(source) a \(destination)"
        }

        let typeText = type == .expense ? "Spesa" : "Entrata"
        return "\(typeText): \(title) • \(amountText) • \(category)"
    }

    private func saveTransaction() {
        guard let decimalAmount = parsedAmount,
              let wallet = selectedWallet else {
            return
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if type == .transfer {
            guard let destinationWallet,
                  destinationWallet !== wallet else {
                return
            }

            let outgoing = Transaction(
                type: .expense,
                amount: decimalAmount,
                category: "Trasferimento",
                title: "\(cleanTitle) → \(destinationWallet.name)",
                wallet: wallet
            )

            let incoming = Transaction(
                type: .income,
                amount: decimalAmount,
                category: "Trasferimento",
                title: "\(cleanTitle) ← \(wallet.name)",
                wallet: destinationWallet
            )

            modelContext.insert(outgoing)
            modelContext.insert(incoming)
        } else {
            let transaction = Transaction(
                type: type,
                amount: decimalAmount,
                category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                title: cleanTitle,
                wallet: wallet
            )

            modelContext.insert(transaction)
        }

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
