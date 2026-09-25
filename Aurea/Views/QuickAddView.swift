import SwiftUI
import SwiftData

struct QuickAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \FinanceCategory.name) private var financeCategories: [FinanceCategory]

    @State private var type: TransactionType = .expense
    @State private var title = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var category = ""
    @State private var selectedWallet: Wallet?
    @State private var destinationWallet: Wallet?
    @State private var showingConfirmation = false

    private let fallbackExpenseCategories = ["Alimentari", "Trasporti", "Casa", "Svago", "Salute", "Shopping", "Altro"]
    private let fallbackIncomeCategories = ["Stipendio", "Regalo", "Rimborso", "Vendita", "Altro"]

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }

    private var suggestedCategories: [String] {
        if type == .transfer { return [Transaction.transferCategory] }
        let custom = financeCategories.filter { $0.type == type && !$0.isArchived }.map(\.name)
        if !custom.isEmpty { return custom }
        return type == .expense ? fallbackExpenseCategories : fallbackIncomeCategories
    }

    private var recentCategories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for transaction in transactions where transaction.type == type {
            let value = transaction.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !Transaction.isReservedCategory(value), !seen.contains(value) else { continue }
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
                            category = Transaction.transferCategory
                            if destinationWallet == nil || destinationWallet === selectedWallet {
                                destinationWallet = activeWallets.first { $0 !== selectedWallet }
                            }
                        } else if category == Transaction.transferCategory {
                            category = ""
                        }
                    }
                }

                Section("Movimento") {
                    TextField("Titolo", text: $title)
                    TextField("Importo", text: $amount).keyboardType(.decimalPad)
                    DatePicker("Data", selection: $date)

                    if type != .transfer {
                        TextField("Categoria", text: $category)

                        if Transaction.isReservedCategory(category) {
                            Text("“\(Transaction.transferCategory)” è riservata ai trasferimenti: scegli un'altra categoria.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if !recentCategories.isEmpty {
                            Text("Usate di recente").font(.caption).foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentCategories, id: \.self) { suggestion in
                                        Button(suggestion) { category = suggestion }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                    }
                                }
                            }
                        }

                        Text("Categorie").font(.caption).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestedCategories, id: \.self) { suggestion in
                                    Button(suggestion) { category = suggestion }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }
                    }
                }

                if type == .transfer {
                    Section("Trasferimento") {
                        if activeWallets.count < 2 {
                            Text("Servono almeno due portafogli attivi per effettuare un trasferimento.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Da", selection: $selectedWallet) {
                                ForEach(activeWallets) { wallet in
                                    Label(wallet.name, systemImage: wallet.icon).tag(wallet as Wallet?)
                                }
                            }
                            .onChange(of: selectedWallet) { _, newWallet in
                                if destinationWallet === newWallet {
                                    destinationWallet = activeWallets.first { $0 !== newWallet }
                                }
                            }

                            Picker("A", selection: $destinationWallet) {
                                ForEach(activeWallets.filter { $0 !== selectedWallet }) { wallet in
                                    Label(wallet.name, systemImage: wallet.icon).tag(wallet as Wallet?)
                                }
                            }

                            if let converted = convertedDestinationAmount,
                               let destinationWallet,
                               selectedWallet?.currencyCode != destinationWallet.currencyCode {
                                LabeledContent("Arriveranno", value: converted.formatted(.currency(code: destinationWallet.currencyCode)))
                            }
                        }
                    }
                } else {
                    Section("Portafoglio") {
                        if activeWallets.isEmpty {
                            Text("Nessun portafoglio disponibile").foregroundStyle(.secondary)
                        } else {
                            Picker("Portafoglio", selection: $selectedWallet) {
                                Text("Seleziona").tag(nil as Wallet?)
                                ForEach(activeWallets) { wallet in
                                    Label(wallet.name, systemImage: wallet.icon).tag(wallet as Wallet?)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Continua") { showingConfirmation = true }
                        .disabled(!canSave)
                }
            }
            .navigationTitle("Nuovo movimento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
            }
            .onAppear {
                if selectedWallet == nil { selectedWallet = activeWallets.first }
                if destinationWallet == nil { destinationWallet = activeWallets.first { $0 !== selectedWallet } }
            }
            .confirmationDialog("Conferma movimento", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("Salva") { saveTransaction() }
                Button("Annulla", role: .cancel) { }
            } message: {
                Text(confirmationText)
            }
        }
    }

    private var parsedAmount: Decimal? { Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) }

    private var convertedDestinationAmount: Decimal? {
        guard let amount = parsedAmount,
              let source = selectedWallet,
              let destination = destinationWallet else { return nil }
        let valueInEUR = amount * source.effectiveExchangeRateToEUR
        return valueInEUR / destination.effectiveExchangeRateToEUR
    }

    private var canSave: Bool {
        let baseValid = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (parsedAmount ?? 0) > 0 && selectedWallet != nil
        if type == .transfer {
            return baseValid && activeWallets.count >= 2 && destinationWallet != nil && destinationWallet !== selectedWallet
        }
        return baseValid && !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !Transaction.isReservedCategory(category)
    }

    private var confirmationText: String {
        let amountText = parsedAmount?.formatted(.currency(code: selectedWallet?.currencyCode ?? "EUR")) ?? ""
        if type == .transfer {
            let destinationText = convertedDestinationAmount?.formatted(.currency(code: destinationWallet?.currencyCode ?? "EUR")) ?? ""
            return "Trasferimento: \(title) • \(amountText) da \(selectedWallet?.name ?? "") • \(destinationText) a \(destinationWallet?.name ?? "")"
        }
        return "\(type == .expense ? "Spesa" : "Entrata"): \(title) • \(amountText) • \(category)"
    }

    private func saveTransaction() {
        guard let decimalAmount = parsedAmount, let wallet = selectedWallet else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if type == .transfer {
            guard let destinationWallet, destinationWallet !== wallet,
                  let destinationAmount = convertedDestinationAmount else { return }
            let groupID = UUID()
            let outgoing = Transaction(type: .expense, amount: decimalAmount, date: date, category: Transaction.transferCategory, title: "\(cleanTitle) → \(destinationWallet.name)", wallet: wallet, transferGroupID: groupID)
            let incoming = Transaction(type: .income, amount: destinationAmount, date: date, category: Transaction.transferCategory, title: "\(cleanTitle) ← \(wallet.name)", wallet: destinationWallet, transferGroupID: groupID)
            modelContext.insert(outgoing)
            modelContext.insert(incoming)
        } else {
            modelContext.insert(Transaction(type: type, amount: decimalAmount, date: date, category: category.trimmingCharacters(in: .whitespacesAndNewlines), title: cleanTitle, wallet: wallet))
        }

        dismiss()
    }
}

#Preview {
    QuickAddView()
        .modelContainer(for: [Wallet.self, Transaction.self, FinanceCategory.self], inMemory: true)
}
