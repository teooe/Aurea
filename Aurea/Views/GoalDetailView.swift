import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let goal: Goal

    @State private var showingAddProgress = false

    private var progress: Double {
        guard let target = goal.targetAmount,
              target > 0 else {
            return goal.isCompleted ? 1 : 0
        }

        let current = NSDecimalNumber(decimal: goal.currentAmount).doubleValue
        let total = NSDecimalNumber(decimal: target).doubleValue
        return min(max(current / total, 0), 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Obiettivo") {
                    LabeledContent("Nome", value: goal.title)
                    LabeledContent("Tipo", value: goal.type.title)

                    if let target = goal.targetAmount {
                        LabeledContent(
                            "Raggiunto",
                            value: goal.currentAmount.formatted(.currency(code: "EUR"))
                        )
                        LabeledContent(
                            "Traguardo",
                            value: target.formatted(.currency(code: "EUR"))
                        )
                        ProgressView(value: progress)
                    }

                    if let date = goal.targetDate {
                        LabeledContent(
                            "Scadenza",
                            value: date.formatted(date: .abbreviated, time: .omitted)
                        )
                    }

                    LabeledContent(
                        "Stato",
                        value: goal.isCompleted ? "Completato" : "In corso"
                    )
                }

                if goal.targetAmount != nil && !goal.isCompleted {
                    Section {
                        Button {
                            showingAddProgress = true
                        } label: {
                            Label("Aggiungi risparmio", systemImage: "plus.circle")
                        }
                    }
                }

                Section {
                    Button {
                        goal.isCompleted.toggle()
                    } label: {
                        Label(
                            goal.isCompleted ? "Riapri obiettivo" : "Segna come completato",
                            systemImage: goal.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle"
                        )
                    }
                }

                Section {
                    Button(role: .destructive) {
                        modelContext.delete(goal)
                        dismiss()
                    } label: {
                        Label("Elimina obiettivo", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Dettaglio obiettivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddProgress) {
                AddGoalProgressView(goal: goal)
            }
        }
    }
}

private struct AddGoalProgressView: View {
    @Environment(\.dismiss) private var dismiss

    let goal: Goal

    @State private var amountText = ""

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let amount else { return false }
        return amount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nuovo risparmio") {
                    TextField("Importo", text: $amountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Aggiungi risparmio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Aggiungi") {
                        guard let amount else { return }
                        goal.currentAmount += amount

                        if let target = goal.targetAmount,
                           goal.currentAmount >= target {
                            goal.currentAmount = target
                            goal.isCompleted = true
                        }

                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
