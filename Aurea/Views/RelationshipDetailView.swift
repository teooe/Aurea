import SwiftUI
import SwiftData

struct RelationshipDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RelationshipPayment.date, order: .reverse) private var payments: [RelationshipPayment]

    let relationship: Relationship
    @State private var showingPayment = false
    @State private var showingDeleteConfirmation = false

    private var relationshipPayments: [RelationshipPayment] { payments.filter { $0.relationshipID == relationship.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    LabeledContent("Persona", value: relationship.personName)
                    LabeledContent(relationship.type == .debt ? "Debito" : "Credito", value: relationship.amount.formatted(.currency(code: "EUR")))
                    LabeledContent("Già saldato", value: relationship.repaid.formatted(.currency(code: "EUR")))
                    LabeledContent("Residuo", value: relationship.remainingAmount.formatted(.currency(code: "EUR")))
                    if !relationship.note.isEmpty { LabeledContent("Nota", value: relationship.note) }
                    if let dueDate = relationship.dueDate { LabeledContent("Scadenza", value: dueDate.formatted(date: .abbreviated, time: .omitted)) }
                    LabeledContent("Creato", value: relationship.createdAt.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Stato", value: relationship.isClosed ? "Saldato" : "Aperto")
                }

                if !relationshipPayments.isEmpty {
                    Section("Pagamenti") {
                        ForEach(relationshipPayments) { payment in
                            HStack { Text(payment.date.formatted(date: .abbreviated, time: .omitted)); Spacer(); Text(payment.amount, format: .currency(code: "EUR")) }
                            .swipeActions {
                                Button("Elimina", role: .destructive) {
                                    relationship.paidAmount = max(relationship.repaid - payment.amount, 0)
                                    relationship.isClosed = false
                                    modelContext.delete(payment)
                                }
                            }
                        }
                    }
                }

                if !relationship.isClosed {
                    Section {
                        Button { showingPayment = true } label: { Label("Registra pagamento parziale", systemImage: "eurosign.circle") }
                        Button {
                            let remaining = relationship.remainingAmount
                            if remaining > 0 { modelContext.insert(RelationshipPayment(relationshipID: relationship.id, amount: remaining)) }
                            relationship.paidAmount = relationship.amount
                            relationship.isClosed = true
                        } label: { Label("Segna come saldato", systemImage: "checkmark.circle") }
                    }
                } else {
                    Section { Button { relationship.isClosed = false } label: { Label("Riapri", systemImage: "arrow.uturn.backward.circle") } }
                }

                Section { Button(role: .destructive) { showingDeleteConfirmation = true } label: { Label("Elimina", systemImage: "trash") } }
            }
            .navigationTitle("Dettaglio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
            .sheet(isPresented: $showingPayment) { AddRelationshipPaymentView(relationship: relationship) }
            .confirmationDialog("Eliminare \(relationship.type == .debt ? "questo debito" : "questo credito")?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Elimina", role: .destructive) { deleteRelationship() }
                Button("Annulla", role: .cancel) { }
            } message: { Text("Verrà eliminato anche lo storico dei pagamenti collegati.") }
        }
    }

    private func deleteRelationship() {
        for payment in relationshipPayments { modelContext.delete(payment) }
        modelContext.delete(relationship)
        dismiss()
    }
}

private struct AddRelationshipPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let relationship: Relationship
    @State private var amountText = ""
    @State private var date = Date()

    private var amount: Decimal? { Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Importo", text: $amountText).keyboardType(.decimalPad)
                DatePicker("Data", selection: $date, displayedComponents: .date)
                Text("Residuo: \(relationship.remainingAmount.formatted(.currency(code: "EUR")))").foregroundStyle(.secondary)
            }
            .navigationTitle("Pagamento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard let amount, amount > 0 else { return }
                        let applied = min(amount, relationship.remainingAmount)
                        modelContext.insert(RelationshipPayment(relationshipID: relationship.id, amount: applied, date: date))
                        relationship.paidAmount = min(relationship.repaid + applied, relationship.amount)
                        if relationship.remainingAmount <= 0 { relationship.isClosed = true }
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
        }
    }
}
