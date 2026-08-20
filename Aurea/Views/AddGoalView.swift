import SwiftUI
import SwiftData

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var type: GoalType = .economic
    @State private var targetAmountText = ""
    @State private var currentAmountText = ""
    @State private var targetDate = Date()

    private var needsAmount: Bool {
        type == .economic || type == .both
    }

    private var needsDate: Bool {
        type == .temporal || type == .both
    }

    private var targetAmount: Decimal? {
        Decimal(string: targetAmountText.replacingOccurrences(of: ",", with: "."))
    }

    private var currentAmount: Decimal {
        Decimal(string: currentAmountText.replacingOccurrences(of: ",", with: ".")) ?? .zero
    }

    private var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if needsAmount {
            guard let targetAmount, targetAmount > 0 else { return false }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Obiettivo") {
                    TextField("Nome", text: $title)

                    Picker("Tipo", selection: $type) {
                        ForEach(GoalType.allCases) { goalType in
                            Text(goalType.title).tag(goalType)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if needsAmount {
                    Section("Importo") {
                        TextField("Importo obiettivo", text: $targetAmountText)
                            .keyboardType(.decimalPad)

                        TextField("Già raggiunto", text: $currentAmountText)
                            .keyboardType(.decimalPad)
                    }
                }

                if needsDate {
                    Section("Scadenza") {
                        DatePicker(
                            "Data obiettivo",
                            selection: $targetDate,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle("Nuovo obiettivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveGoal()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func saveGoal() {
        let goal = Goal(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            targetAmount: needsAmount ? targetAmount : nil,
            currentAmount: needsAmount ? currentAmount : .zero,
            targetDate: needsDate ? targetDate : nil
        )

        modelContext.insert(goal)
        dismiss()
    }
}
