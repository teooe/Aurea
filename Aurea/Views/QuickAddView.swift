import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Valori iniziali del modulo, per "Ripeti" su un movimento già registrato.
struct QuickAddPrefill {
    var type: TransactionType
    var amount: Decimal
    var category: String
    var title: String
    var wallet: Wallet?

    init(repeating transaction: Transaction) {
        type = transaction.type
        amount = transaction.amount
        category = transaction.category
        // Se il titolo era solo la categoria (descrizione vuota), non va ripetuto come descrizione.
        title = transaction.title == transaction.category ? "" : transaction.title
        wallet = transaction.wallet
    }
}

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
    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isReadingReceipt = false
    @State private var receiptNote: String?

    /// Con un precompilato la data resta "adesso": ripetere significa registrare di nuovo oggi.
    init(prefill: QuickAddPrefill? = nil) {
        guard let prefill else { return }
        _type = State(initialValue: prefill.type)
        _amount = State(initialValue: prefill.amount.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(Locale(identifier: "it_IT"))))
        _category = State(initialValue: prefill.category)
        _title = State(initialValue: prefill.title)
        _selectedWallet = State(initialValue: prefill.wallet?.isArchived == false ? prefill.wallet : nil)
    }

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }

    private var suggestedCategories: [String] {
        if type == .transfer { return [Transaction.transferCategory] }
        return financeCategories.filter { $0.type == type && !$0.isArchived }.map(\.name)
    }

    private var recentCategories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for transaction in transactions where transaction.type == type && !transaction.isTransfer {
            let value = transaction.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !Transaction.isReservedCategory(value), !seen.contains(value),
                  CategoryService.find(value, type: type, in: financeCategories)?.isArchived != true else { continue }
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

                    if type == .expense {
                        receiptButton
                        if let receiptNote {
                            Text(receiptNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
            .fullScreenCover(isPresented: $showingScanner) {
                DocumentScannerView { images in
                    showingScanner = false
                    readReceipt(images)
                } onCancel: {
                    showingScanner = false
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        receiptNote = "Non riesco ad aprire questa foto."
                        return
                    }
                    readReceipt([image])
                }
            }
        }
    }

    private var receiptButton: some View {
        Menu {
            if DocumentScannerView.isSupported {
                Button("Scatta foto", systemImage: "camera") { showingScanner = true }
            }
            Button("Scegli dalla libreria", systemImage: "photo.on.rectangle") { showingPhotoPicker = true }
        } label: {
            HStack {
                Label(isReadingReceipt ? "Lettura dello scontrino…" : "Leggi da scontrino", systemImage: "doc.text.viewfinder")
                if isReadingReceipt {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .disabled(isReadingReceipt)
    }

    /// Legge lo scontrino e precompila importo, data e descrizione. Non salva: l'utente controlla prima.
    private func readReceipt(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        isReadingReceipt = true
        receiptNote = nil
        amountFocused = false
        Task {
            defer { isReadingReceipt = false }
            do {
                let lines = try await ReceiptScanner.lines(from: images)
                apply(ReceiptParser.parse(lines))
            } catch {
                receiptNote = "Non sono riuscito a leggere lo scontrino. Inserisci i dati a mano."
            }
        }
    }

    private func apply(_ result: ReceiptParser.Result) {
        var found: [String] = []
        if let value = result.amount {
            // Senza separatore delle migliaia: parsedAmount sostituisce solo la virgola.
            amount = value.formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(Locale(identifier: "it_IT")))
            found.append("importo")
        }
        if let receiptDate = result.date {
            // Lo scontrino dà il giorno; l'ora resta quella scelta nel modulo.
            let calendar = Calendar.current
            let time = calendar.dateComponents([.hour, .minute], from: date)
            date = calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: 0, of: receiptDate) ?? receiptDate
            found.append("data")
        }
        if let merchant = result.merchant, trimmedTitle.isEmpty {
            title = merchant
            found.append("negozio")
        }

        if result.amount == nil {
            receiptNote = found.isEmpty
                ? "Non ho trovato dati utili: inseriscili a mano."
                : "Letti \(found.joined(separator: " e ")), ma non il totale: inseriscilo a mano."
            amountFocused = true
        } else {
            receiptNote = "Letti \(found.joined(separator: ", ")) dallo scontrino: controlla prima di salvare."
        }
    }

    private func categoryChip(_ name: String) -> some View {
        let isSelected = trimmedCategory.caseInsensitiveCompare(name) == .orderedSame
        return Button {
            category = isSelected ? "" : name
        } label: {
            Label(name, systemImage: CategoryService.find(name, type: type, in: financeCategories)?.icon ?? "tag")
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
            let sent = decimalAmount.formatted(.currency(code: wallet.currencyCode))
            UndoBanner.shared.post([outgoing, incoming], message: "Trasferimento registrato · \(sent) · \(wallet.name) → \(destinationWallet.name)")
        } else {
            // Senza descrizione il movimento prende il nome della categoria.
            let resolvedCategory = CategoryService.resolve(trimmedCategory, type: type, in: modelContext)
            let cleanTitle = trimmedTitle.isEmpty ? resolvedCategory : trimmedTitle
            let transaction = Transaction(type: type, amount: decimalAmount, date: date, category: resolvedCategory, title: cleanTitle, wallet: wallet)
            modelContext.insert(transaction)
            let kind = type == .income ? "Entrata registrata" : "Spesa registrata"
            let value = decimalAmount.formatted(.currency(code: wallet.currencyCode))
            UndoBanner.shared.post([transaction], message: "\(kind) · \(value) · \(resolvedCategory)")
        }

        dismiss()
    }
}

#Preview {
    QuickAddView()
        .modelContainer(for: [Wallet.self, Transaction.self, FinanceCategory.self], inMemory: true)
}
