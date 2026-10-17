import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransactions: [Transaction]

    let transaction: Transaction

    @State private var showingDeleteConfirmation = false
    @State private var showingEdit = false
    @State private var showingRepeat = false
    @State private var showingReceipt = false
    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showingRemoveReceipt = false

    private var receiptImage: UIImage? {
        transaction.receiptImageData.flatMap(UIImage.init(data:))
    }

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
                    if !transaction.tags.isEmpty {
                        LabeledContent("Etichette", value: transaction.tags.joined(separator: ", "))
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
                    receiptSection

                    Section {
                        Button { showingEdit = true } label: {
                            Label("Modifica movimento", systemImage: "pencil")
                        }
                        Button { showingRepeat = true } label: {
                            Label("Registra di nuovo", systemImage: "arrow.clockwise")
                        }
                    }

                    Section {
                        Button(role: .destructive) { showingDeleteConfirmation = true } label: {
                            Label("Elimina movimento", systemImage: "trash")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingReceipt) {
                if let receiptImage { ReceiptImageViewer(image: receiptImage) }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                DocumentScannerView { images in
                    showingScanner = false
                    if let image = images.first { attach(image) }
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
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        attach(image)
                    }
                }
            }
            .confirmationDialog("Rimuovere la foto dello scontrino?", isPresented: $showingRemoveReceipt, titleVisibility: .visible) {
                Button("Rimuovi foto", role: .destructive) { transaction.receiptImageData = nil }
                Button("Annulla", role: .cancel) { }
            }
            .navigationTitle("Dettaglio movimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
            }
            .sheet(isPresented: $showingEdit) {
                EditTransactionView(transaction: transaction)
            }
            .sheet(isPresented: $showingRepeat) {
                QuickAddView(prefill: QuickAddPrefill(repeating: transaction))
            }
            .confirmationDialog(isTransfer ? "Eliminare l’intero trasferimento?" : "Eliminare questo movimento?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Elimina", role: .destructive) { deleteMovement() }
                Button("Annulla", role: .cancel) { }
            }
        }
    }

    @ViewBuilder private var receiptSection: some View {
        Section("Scontrino") {
            if let receiptImage {
                Button { showingReceipt = true } label: {
                    HStack(spacing: 12) {
                        Image(uiImage: receiptImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text("Vedi la foto")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button("Rimuovi foto", role: .destructive) { showingRemoveReceipt = true }
            } else {
                Menu {
                    if DocumentScannerView.isSupported {
                        Button("Scatta foto", systemImage: "camera") { showingScanner = true }
                    }
                    Button("Scegli dalla libreria", systemImage: "photo.on.rectangle") { showingPhotoPicker = true }
                } label: {
                    Label("Aggiungi la foto dello scontrino", systemImage: "doc.text.image")
                }
            }
        }
    }

    private func attach(_ image: UIImage) {
        transaction.receiptImageData = ReceiptImage.jpegData(from: image)
    }

    private func deleteMovement() {
        Transaction.delete(transaction, from: allTransactions, in: modelContext)
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
    @State private var tagsText: String

    init(transaction: Transaction) {
        self.transaction = transaction
        _title = State(initialValue: transaction.title)
        _amount = State(initialValue: NSDecimalNumber(decimal: transaction.amount).stringValue)
        _category = State(initialValue: transaction.category)
        _type = State(initialValue: transaction.type)
        _selectedWallet = State(initialValue: transaction.wallet)
        _date = State(initialValue: transaction.date)
        _tagsText = State(initialValue: transaction.tags.joined(separator: ", "))
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
                    TagField(text: $tagsText, suggestions: [])
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
        transaction.tags = Transaction.parseTags(tagsText)
        dismiss()
    }
}
