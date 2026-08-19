import SwiftUI
import SwiftData

struct AddWalletView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var icon = "creditcard"
    @State private var currencyCode = "EUR"
    @State private var initialBalance = ""
    
    private let icons = [
        "creditcard",
        "building.columns",
        "banknote",
        "wallet.pass"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Portafoglio") {
                    TextField("Nome", text: $name)
                    
                    Picker("Icona", selection: $icon) {
                        ForEach(icons, id: \.self) { iconName in
                            Label(iconName, systemImage: iconName)
                                .tag(iconName)
                        }
                    }
                }
                
                Section("Valuta") {
                    Picker("Valuta", selection: $currencyCode) {
                        Text("Euro (€)")
                            .tag("EUR")
                        
                        Text("Dollaro ($)")
                            .tag("USD")
                        
                        Text("Sterlina (£)")
                            .tag("GBP")
                        
                        Text("Franco svizzero")
                            .tag("CHF")
                    }
                }
                
                Section("Saldo iniziale") {
                    TextField("0,00", text: $initialBalance)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button("Crea portafoglio") {
                        createWallet()
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .navigationTitle("Nuovo portafoglio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createWallet() {
        let balance = Decimal(
            string: initialBalance.replacingOccurrences(of: ",", with: ".")
        ) ?? 0
        
        let wallet = Wallet(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            currencyCode: currencyCode,
            initialBalance: balance
        )
        
        modelContext.insert(wallet)
        dismiss()
    }
}

#Preview {
    AddWalletView()
        .modelContainer(
            for: [Wallet.self, Transaction.self],
            inMemory: true
        )
}
