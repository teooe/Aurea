import SwiftUI
import SwiftData

struct AddRelationshipView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var personName = ""
    @State private var amountText = ""
    @State private var type: RelationshipType = .debt
    @State private var note = ""

    private var amount: Decimal? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private var canSave: Bool {
        !personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (amount ?? 0) > 0
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

                    TextField("Importo", text: $amountText)
                        .keyboardType(.decimalPad)

                    TextField("Nota (opzionale)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Nuovo debito o credito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveRelationship()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func saveRelationship() {
        guard let amount, amount > 0 else { return }

        let relationship = Relationship(
            personName: personName.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            type: type,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(relationship)
        dismiss()
    }
}
