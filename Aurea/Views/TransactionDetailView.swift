import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let transaction: Transaction

    @State private var showingDeleteConfirmation = false

    private var isTransfer: Bool {
        transaction.category == "Trasferimento"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movimento") {
                    LabeledContent("Titolo", value: transaction.title)
                    LabeledContent("Categoria", value: transaction.category)
                    LabeledContent("Tipo", value: typeTitle)
                    LabeledContent(
                        "Importo",
                        value: signedAmount
                    )
                    LabeledContent(
                        "Data",
                        value: transaction.date.formatted(date: .abbreviated, time: .shortened)
                    )

                    if let wallet = transaction.wallet {
                        LabeledContent("Portafoglio", value: wallet.name)
                    }
                }

                if isTransfer {
                    Section {
                        Label(
                            "Questo movimento fa parte di un trasferimento tra portafogli.",
                            systemImage: "arrow.left.arrow.right"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Elimina movimento", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Dettaglio movimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .confirmationDialog(
                "Eliminare questo movimento?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Elimina", role: .destructive) {
                    modelContext.delete(transaction)
                    dismiss()
                }
                Button("Annulla", role: .cancel) { }
            }
        }
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

        if isTransfer {
            return transaction.type == .expense ? "−\(amount)" : "+\(amount)"
        }

        switch transaction.type {
        case .expense: return "−\(amount)"
        case .income: return "+\(amount)"
        case .transfer: return amount
        }
    }
}
