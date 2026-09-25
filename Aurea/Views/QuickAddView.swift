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
    @FocusState private var amountFocused: Bool

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

    /// Categorie usate di recente per prime, poi le altre, senza duplicati.
    private var categoryChips: [String] {
        var seen = Set<String>()
        return (recentCategories + suggestedCategories).filter { seen.insert($0.lowercased()).inserted }
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedCategory: String { category.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
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

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(currencySymbol)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("0,00", text: $amount)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .accessibilityLabel("Importo")
                    }
                    .padding(.vertical, 4)
                }

                if type != .transfer {
                    Section("Categoria") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categoryChips, id: \.self) { chip in
                                    categoryChip(chip)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        TextField("Altra categoria", text: $category)

                        if Transaction.isReservedCategory(category) {
                            Text("“\(Transaction.transferCategory)” è riservata ai trasferimenti: scegli un'altra categoria.")
                                .font(.caption)
                                .foregroundStyle(.red)
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
                }

                Section("Dettagli") {
                    TextField("Descrizione (facoltativa)", text: $title)
                    DatePicker("Data", selection: $date)

                    if type != .transfer {
                        if activeWallets.isEmpty {
                            Text("Nessun portafoglio disponibile").foregroundStyle(.secondary)
                        } else {
                            Picker("Portafoglio", selection: $selectedWallet) {
                                ForEach(activeWallets) { wallet in
                                    Label(wallet.name, systemImage: wallet.icon).tag(wallet as Wallet?)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Nuovo movimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveTransaction() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if selectedWallet == nil { selectedWallet = activeWallets.first }
                if destinationWallet == nil { destinationWallet = activeWallets.first { $0 !== selectedWallet } }
                amountFocused = true
            }
        }
    }

    private func categoryChip(_ name: String) -> some View {
        let isSelected = trimmedCategory.caseInsensitiveCompare(name) == .orderedSame
        return Button {
            category = isSelected ? "" : name
        } label: {
            Text(name)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var currencySymbol: String {
        let code = selectedWallet?.currencyCode ?? "EUR"
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
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
        let baseValid = (parsedAmount ?? 0) > 0 && selectedWallet != nil
        if type == .transfer {
            return baseValid && activeWallets.count >= 2 && destinationWallet != nil && destinationWallet !== selectedWallet
        }
        return baseValid && !trimmedCategory.isEmpty && !Transaction.isReservedCategory(category)
    }

    private func saveTransaction() {
        guard canSave, let decimalAmount = parsedAmount, let wallet = selectedWallet else { return }

        if type == .transfer {
            guard let destinationWallet, destinationWallet !== wallet,
                  let destinationAmount = convertedDestinationAmount else { return }
            let groupID = UUID()
            let cleanTitle = trimmedTitle.isEmpty ? Transaction.transferCategory : trimmedTitle
            let outgoing = Transaction(type: .expense, amount: decimalAmount, date: date, category: Transaction.transferCategory, title: "\(cleanTitle) → \(destinationWallet.name)", wallet: wallet, transferGroupID: groupID)
            let incoming = Transaction(type: .income, amount: destinationAmount, date: date, category: Transaction.transferCategory, title: "\(cleanTitle) ← \(wallet.name)", wallet: destinationWallet, transferGroupID: groupID)
            modelContext.insert(outgoing)
            modelContext.insert(incoming)
        } else {
            // Senza descrizione il movimento prende il nome della categoria.
            let cleanTitle = trimmedTitle.isEmpty ? trimmedCategory : trimmedTitle
            modelContext.insert(Transaction(type: type, amount: decimalAmount, date: date, category: trimmedCategory, title: cleanTitle, wallet: wallet))
        }

        dismiss()
    }
}

#Preview {
    QuickAddView()
        .modelContainer(for: [Wallet.self, Transaction.self, FinanceCategory.self], inMemory: true)
}
