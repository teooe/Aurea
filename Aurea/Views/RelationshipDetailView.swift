import SwiftUI
import SwiftData

struct RelationshipDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let relationship: Relationship
    @State private var showingPayment = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    LabeledContent("Persona", value: relationship.personName)
                    LabeledContent(relationship.type == .debt ? "Debito" : "Credito", value: relationship.amount.formatted(.currency(code: "EUR")))
                    LabeledContent("Già saldato", value: relationship.repaid.formatted(.currency(code: "EUR")))
                    LabeledContent("Residuo", value: relationship.remainingAmount.formatted(.currency(code: "EUR")))

                    if !relationship.note.isEmpty {
                        LabeledContent("Nota", value: relationship.note)
                    }
                    if let dueDate = relationship.dueDate {
                        LabeledContent("Scadenza", value: dueDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    LabeledContent("Creato", value: relationship.createdAt.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Stato", value: relationship.isClosed ? "Saldato" : "Aperto")
                }

                if !relationship.isClosed {
                    Section {
                        Button { showingPayment = true } label: {
                            Label("Registra pagamento parziale", systemImage: "eurosign.circle")
                        }
                        Button {
                            relationship.paidAmount = relationship.amount
                            relationship.isClosed = true
                        } label: {
                            Label("Segna come saldato", systemImage: "checkmark.circle")
                        }
                    }
                } else {
                    Section {
                        Button {
                            relationship.isClosed = false
                        } label: {
                            Label("Riapri", systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        modelContext.delete(relationship)
                        dismiss()
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Dettaglio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
            }
            .sheet(isPresented: $showingPayment) {
                AddRelationshipPaymentView(relationship: relationship)
            }
        }
    }
}

private struct AddRelationshipPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    let relationship: Relationship
    @State private var amountText = ""

    private var amount: Decimal? { Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Importo", text: $amountText).keyboardType(.decimalPad)
                Text("Residuo: \(relationship.remainingAmount.formatted(.currency(code: "EUR")))")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Pagamento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard let amount, amount > 0 else { return }
                        relationship.paidAmount = min(relationship.repaid + amount, relationship.amount)
                        if relationship.remainingAmount <= 0 { relationship.isClosed = true }
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
        }
    }
}
