import SwiftUI
import SwiftData

struct WalletDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let wallet: Wallet

    @State private var selectedTransaction: Transaction?
    @State private var showingEdit = false

    private var transactions: [Transaction] {
        wallet.transactions.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Saldo") {
                    LabeledContent("Saldo attuale", value: FinancialEngine.balance(for: wallet).formatted(.currency(code: wallet.currencyCode)))
                    LabeledContent("Saldo iniziale", value: wallet.initialBalance.formatted(.currency(code: wallet.currencyCode)))
                    if wallet.currencyCode != "EUR" {
                        LabeledContent("Valore in EUR", value: FinancialEngine.balanceInEUR(for: wallet).formatted(.currency(code: "EUR")))
                    }
                }

                Section("Movimenti") {
                    if transactions.isEmpty {
                        Text("Nessun movimento").foregroundStyle(.secondary)
                    } else {
                        ForEach(transactions) { transaction in
                            Button {
                                selectedTransaction = transaction
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: icon(for: transaction)).frame(width: 24)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(transaction.title).foregroundStyle(.primary)
                                        Text("\(transaction.category) • \(transaction.date.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(signedAmount(for: transaction))
                                        .fontWeight(.medium)
                                        .foregroundStyle(amountColor(for: transaction))
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button { showingEdit = true } label: {
                        Label("Modifica portafoglio", systemImage: "pencil")
                    }
                    Button {
                        wallet.isArchived.toggle()
                    } label: {
                        Label(wallet.isArchived ? "Riattiva portafoglio" : "Archivia portafoglio", systemImage: wallet.isArchived ? "arrow.uturn.backward" : "archivebox")
                    }
                }
            }
            .navigationTitle(wallet.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction)
            }
            .sheet(isPresented: $showingEdit) {
                EditWalletView(wallet: wallet)
            }
        }
    }

    private func icon(for transaction: Transaction) -> String {
        if transaction.category == "Trasferimento" { return "arrow.left.arrow.right.circle" }
        switch transaction.type {
        case .expense: return "arrow.down.circle"
        case .income: return "arrow.up.circle"
        case .transfer: return "arrow.left.arrow.right.circle"
        }
    }

    private func signedAmount(for transaction: Transaction) -> String {
        let value = transaction.amount.formatted(.currency(code: wallet.currencyCode))
        switch transaction.type {
        case .expense: return "−\(value)"
        case .income: return "+\(value)"
        case .transfer: return value
        }
    }

    private func amountColor(for transaction: Transaction) -> Color {
        if transaction.category == "Trasferimento" { return .secondary }
        switch transaction.type {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .secondary
        }
    }
}

private struct EditWalletView: View {
    @Environment(\.dismiss) private var dismiss
    let wallet: Wallet

    @State private var name: String
    @State private var icon: String
    @State private var currencyCode: String
    @State private var rateText: String

    init(wallet: Wallet) {
        self.wallet = wallet
        _name = State(initialValue: wallet.name)
        _icon = State(initialValue: wallet.icon)
        _currencyCode = State(initialValue: wallet.currencyCode)
        _rateText = State(initialValue: wallet.exchangeRateToEUR.map { NSDecimalNumber(decimal: $0).stringValue } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome", text: $name)
                Picker("Icona", selection: $icon) {
                    ForEach(["creditcard", "building.columns", "banknote", "wallet.pass"], id: \.self) { value in
                        Label(value, systemImage: value).tag(value)
                    }
                }
                Picker("Valuta", selection: $currencyCode) {
                    Text("EUR").tag("EUR")
                    Text("USD").tag("USD")
                    Text("GBP").tag("GBP")
                    Text("CHF").tag("CHF")
                }
                if currencyCode != "EUR" {
                    TextField("Valore in EUR di 1 \(currencyCode)", text: $rateText).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Modifica portafoglio")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        wallet.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        wallet.icon = icon
                        wallet.currencyCode = currencyCode
                        wallet.exchangeRateToEUR = currencyCode == "EUR" ? nil : Decimal(string: rateText.replacingOccurrences(of: ",", with: "."))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
