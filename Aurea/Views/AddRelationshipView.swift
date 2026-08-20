import SwiftUI
import SwiftData

struct AddRelationshipView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var personName = ""
    @State private var amountText = ""
    @State private var type: RelationshipType = .debt
    @State private var note = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (amount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        Text("Devo io").tag(RelationshipType.debt)
                        Text("Devono a me").tag(RelationshipType.credit)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Dettagli") {
                    TextField("Persona", text: $personName)
                    TextField("Importo", text: $amountText).keyboardType(.decimalPad)
                    TextField("Nota (opzionale)", text: $note, axis: .vertical).lineLimit(2...4)
                }

                Section("Scadenza") {
                    Toggle("Imposta scadenza", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Data", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Nuovo debito o credito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveRelationship() }.disabled(!canSave)
                }
            }
        }
    }

    private func saveRelationship() {
        guard let amount, amount > 0 else { return }
        modelContext.insert(Relationship(
            personName: personName.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            type: type,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: hasDueDate ? dueDate : nil
        ))
        dismiss()
    }
}
