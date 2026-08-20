import SwiftUI

struct GlobalQuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingTransaction = false
    @State private var showingAgendaItem = false
    @State private var showingWallet = false
    @State private var showingGoal = false
    @State private var showingRelationship = false

    var body: some View {
        NavigationStack {
            List {
                Section("Più usati") {
                    quickRow(title: "Movimento", subtitle: "Spesa, entrata o trasferimento", icon: "eurosign.circle.fill") { showingTransaction = true }
                    quickRow(title: "Impegno", subtitle: "Attività, evento o scadenza", icon: "calendar.badge.plus") { showingAgendaItem = true }
                }

                Section("Finanze") {
                    quickRow(title: "Portafoglio", subtitle: "Conto, contanti o altro patrimonio", icon: "wallet.pass") { showingWallet = true }
                    quickRow(title: "Obiettivo", subtitle: "Economico, temporale o entrambi", icon: "target") { showingGoal = true }
                    quickRow(title: "Debito o credito", subtitle: "Registra un rapporto con una persona", icon: "person.2") { showingRelationship = true }
                }
            }
            .navigationTitle("Nuovo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
            .sheet(isPresented: $showingTransaction) { QuickAddView() }
            .sheet(isPresented: $showingAgendaItem) { AddAgendaItemView() }
            .sheet(isPresented: $showingWallet) { AddWalletView() }
            .sheet(isPresented: $showingGoal) { AddGoalView() }
            .sheet(isPresented: $showingRelationship) { AddRelationshipView() }
        }
    }

    private func quickRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
