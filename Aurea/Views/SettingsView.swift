import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var wallets: [Wallet]
    @Query private var transactions: [Transaction]
    @Query private var agendaItems: [AgendaItem]
    @Query private var goals: [Goal]
    @Query private var relationships: [Relationship]
    @Query private var budgets: [Budget]
    @Query private var recurringTransactions: [RecurringTransaction]

    @AppStorage("aurea.home.compact") private var compactHome = false
    @AppStorage("aurea.home.smartAlerts") private var smartAlertsEnabled = true
    @AppStorage("aurea.home.monthlyPulse") private var monthlyPulseEnabled = true
    @AppStorage("aurea.home.dayBrief") private var dayBriefEnabled = true
    @AppStorage("aurea.agenda.showCompleted") private var showCompletedAgenda = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Home") {
                    Toggle("Riepilogo della giornata", isOn: $dayBriefEnabled)
                    Toggle("Andamento del mese", isOn: $monthlyPulseEnabled)
                    Toggle("Avvisi intelligenti", isOn: $smartAlertsEnabled)
                    Toggle("Home compatta", isOn: $compactHome)
                } footer: {
                    Text("Puoi scegliere quanto rendere ricca o essenziale la schermata principale.")
                }

                Section("Agenda") {
                    Toggle("Mostra elementi completati", isOn: $showCompletedAgenda)
                }

                Section("I tuoi dati") {
                    dataRow("Portafogli", value: wallets.filter { !$0.isArchived }.count, icon: "wallet.pass")
                    dataRow("Movimenti", value: transactions.count, icon: "arrow.left.arrow.right")
                    dataRow("Impegni", value: agendaItems.count, icon: "calendar")
                    dataRow("Obiettivi", value: goals.filter { !$0.isCompleted }.count, icon: "target")
                    dataRow("Debiti e crediti", value: relationships.filter { !$0.isClosed }.count, icon: "person.2")
                    dataRow("Budget", value: budgets.filter { !$0.isArchived }.count, icon: "gauge")
                    dataRow("Ricorrenti", value: recurringTransactions.filter { $0.isActive }.count, icon: "repeat")
                }

                Section("Privacy") {
                    LabeledContent("Dati finanziari") {
                        Label("Sul dispositivo", systemImage: "iphone")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Aurea AI v2") {
                        Text("Locale")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("La versione attuale dell'assistente usa i dati già presenti in Aurea e non richiede un modello AI esterno.")
                }

                Section("Informazioni") {
                    LabeledContent("App", value: "Aurea")
                    LabeledContent("Versione", value: "0.1")
                    LabeledContent("Stato", value: "Sviluppo")
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }

    private func dataRow(_ title: String, value: Int, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text("\(value)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
