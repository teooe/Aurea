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
    
    var body: some View {
        NavigationStack {
            Form {
                
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        Text("Spesa")
                            .tag(TransactionType.expense)
                        
                        Text("Entrata")
                            .tag(TransactionType.income)
                        
                        Text("Trasferimento")
                            .tag(TransactionType.transfer)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Movimento") {
                    TextField("Titolo", text: $title)
                    
                    TextField("Importo", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    TextField("Categoria", text: $category)
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
                    Button("Conferma") {
                        saveTransaction()
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
        }
    }
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) != nil &&
        Decimal(string: amount.replacingOccurrences(of: ",", with: "."))! > 0 &&
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedWallet != nil
    }
    
    private func saveTransaction() {
        guard let decimalAmount = Decimal(
            string: amount.replacingOccurrences(of: ",", with: ".")
        ),
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
