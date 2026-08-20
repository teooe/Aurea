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

                    LabeledContent(
                        "Stato",
                        value: relationship.isClosed ? "Saldato" : "Aperto"
                    )
                }

                Section {
                    if relationship.isClosed {
                        Button {
                            relationship.isClosed = false
                            dismiss()
                        } label: {
                            Label("Riapri", systemImage: "arrow.uturn.backward.circle")
                        }
                    } else {
                        Button {
                            relationship.isClosed = true
                            dismiss()
                        } label: {
                            Label("Segna come saldato", systemImage: "checkmark.circle")
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}
