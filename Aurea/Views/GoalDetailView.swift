import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]

    let goal: Goal

    @State private var showingAddProgress = false
    @State private var showingWalletPicker = false
    @State private var showingDeleteConfirmation = false

    private var progress: Double {
        guard let target = goal.targetAmount, target > 0 else { return goal.isCompleted ? 1 : 0 }
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
                        LabeledContent("Raggiunto", value: goal.currentAmount.formatted(.currency(code: "EUR")))
                        LabeledContent("Traguardo", value: target.formatted(.currency(code: "EUR")))
                        ProgressView(value: progress)
                    }
                    if let date = goal.targetDate { LabeledContent("Scadenza", value: date.formatted(date: .abbreviated, time: .omitted)) }
                    LabeledContent("Stato", value: goal.isCompleted ? "Completato" : "In corso")
                }

                if goal.targetAmount != nil {
                    Section("Collegamento reale") {
                        if let wallet = goal.linkedWallet {
                            LabeledContent("Portafoglio", value: wallet.name)
                            LabeledContent("Saldo portafoglio", value: FinancialEngine.balanceInEUR(for: wallet).formatted(.currency(code: "EUR")))
                            Button { syncFromWallet() } label: { Label("Sincronizza dal saldo", systemImage: "arrow.triangle.2.circlepath") }
                            Button(role: .destructive) { goal.linkedWallet = nil } label: { Text("Scollega portafoglio") }
                        } else {
                            Button { showingWalletPicker = true } label: { Label("Collega un portafoglio", systemImage: "link") }
                        }
                    }
                }

                if goal.targetAmount != nil && !goal.isCompleted {
                    Section { Button { showingAddProgress = true } label: { Label("Aggiungi risparmio manuale", systemImage: "plus.circle") } }
                }

                Section { Button { goal.isCompleted.toggle() } label: { Label(goal.isCompleted ? "Riapri obiettivo" : "Segna come completato", systemImage: goal.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle") } }

                Section { Button(role: .destructive) { showingDeleteConfirmation = true } label: { Label("Elimina obiettivo", systemImage: "trash") } }
            }
            .navigationTitle("Dettaglio obiettivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
            .sheet(isPresented: $showingAddProgress) { AddGoalProgressView(goal: goal) }
            .sheet(isPresented: $showingWalletPicker) { GoalWalletPicker(goal: goal, wallets: wallets.filter { !$0.isArchived }) }
            .confirmationDialog("Eliminare questo obiettivo?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Elimina", role: .destructive) { modelContext.delete(goal); dismiss() }
                Button("Annulla", role: .cancel) { }
            } message: { Text("Questa operazione non può essere annullata.") }
        }
    }

    private func syncFromWallet() {
        guard let wallet = goal.linkedWallet else { return }
        let value = max(FinancialEngine.balanceInEUR(for: wallet), 0)
        if let target = goal.targetAmount { goal.currentAmount = min(value, target); goal.isCompleted = goal.currentAmount >= target }
        else { goal.currentAmount = value }
    }
}

private struct GoalWalletPicker: View {
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    let wallets: [Wallet]
    var body: some View {
        NavigationStack {
            List(wallets) { wallet in
                Button {
                    goal.linkedWallet = wallet
                    let value = max(FinancialEngine.balanceInEUR(for: wallet), 0)
                    if let target = goal.targetAmount { goal.currentAmount = min(value, target); goal.isCompleted = goal.currentAmount >= target }
                    dismiss()
                } label: {
                    HStack { Label(wallet.name, systemImage: wallet.icon); Spacer(); Text(FinancialEngine.balance(for: wallet), format: .currency(code: wallet.currencyCode)) }
                }
            }
            .navigationTitle("Collega portafoglio")
            .toolbar { Button("Chiudi") { dismiss() } }
        }
    }
}

private struct AddGoalProgressView: View {
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    @State private var amountText = ""
    private var amount: Decimal? { Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) }
    var body: some View {
        NavigationStack {
            Form { Section("Nuovo risparmio") { TextField("Importo", text: $amountText).keyboardType(.decimalPad) } }
                .navigationTitle("Aggiungi risparmio").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Aggiungi") { guard let amount, amount > 0 else { return }; goal.currentAmount += amount; if let target = goal.targetAmount, goal.currentAmount >= target { goal.currentAmount = target; goal.isCompleted = true }; dismiss() }.disabled((amount ?? 0) <= 0)
                    }
                }
        }
    }
}
