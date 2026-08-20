import SwiftUI
import SwiftData

struct RelationshipDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let relationship: Relationship

    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli") {
                    LabeledContent("Persona", value: relationship.personName)
                    LabeledContent(
                        relationship.type == .debt ? "Debito" : "Credito",
                        value: relationship.amount.formatted(.currency(code: "EUR"))
                    )

                    if !relationship.note.isEmpty {
                        LabeledContent("Nota", value: relationship.note)
                    }

                    LabeledContent(
                        "Creato",
                        value: relationship.createdAt.formatted(date: .abbreviated, time: .omitted)
                    )
                }

                Section {
                    Button {
                        relationship.isClosed = true
                        dismiss()
                    } label: {
                        Label("Segna come saldato", systemImage: "checkmark.circle")
                    }
                    .disabled(relationship.isClosed)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}
