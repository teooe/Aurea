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

    @State private var showingFinance = false
    @State private var showingAgenda = false
    @State private var showingQuickAdd = false

    private var openAgendaItems: Int { agendaItems.filter { !$0.isCompleted }.count }
    private var activeWallets: Int { wallets.filter { !$0.isArchived }.count }
    private var activeGoals: Int { goals.filter { !$0.isCompleted }.count }
    private var openRelationships: Int { relationships.filter { !$0.isClosed }.count }
    private var activeBudgets: Int { budgets.filter { !$0.isArchived }.count }
    private var activeRecurring: Int { recurringTransactions.filter { $0.isActive }.count }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gestione") {
                    Button { showingQuickAdd = true } label: {
                        Label("Aggiungi qualcosa", systemImage: "plus.circle")
                    }
                    Button { showingFinance = true } label: {
                        HStack {
                            Label("Centro finanziario", systemImage: "chart.pie")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    Button { showingAgenda = true } label: {
                        HStack {
                            Label("Agenda completa", systemImage: "calendar")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Panoramica dati") {
                    dataRow("Portafogli attivi", value: activeWallets, icon: "wallet.pass")
                    dataRow("Movimenti", value: transactions.count, icon: "arrow.left.arrow.right")
                    dataRow("Impegni aperti", value: openAgendaItems, icon: "calendar.badge.clock")
                    dataRow("Obiettivi attivi", value: activeGoals, icon: "target")
                    dataRow("Debiti e crediti aperti", value: openRelationships, icon: "person.2")
                    dataRow("Budget attivi", value: activeBudgets, icon: "gauge")
                    dataRow("Ricorrenti attive", value: activeRecurring, icon: "repeat")
                }

                Section("Condivisione") {
                    ShareLink(item: summaryText) {
                        Label("Condividi riepilogo Aurea", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Il riepilogo contiene solo conteggi generali e non include l'elenco completo dei movimenti.")
                }

                Section("Privacy e funzionamento") {
                    LabeledContent("Archiviazione") {
                        Label("Sul dispositivo", systemImage: "iphone")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Aurea AI v2") {
                        Text("Locale")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Conferma azioni AI") {
                        Text("Sempre attiva")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Nella versione attuale Aurea AI analizza i dati già presenti nell'app e chiede conferma prima di creare movimenti o impegni.")
                }

                Section("Informazioni") {
                    LabeledContent("App", value: "Aurea")
                    LabeledContent("Versione", value: "0.1")
                    LabeledContent("Stato", value: "Sviluppo")
                }
            }
            .navigationTitle("Aurea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
            .sheet(isPresented: $showingFinance) { FinanceCenterView() }
            .sheet(isPresented: $showingAgenda) { AgendaView() }
            .sheet(isPresented: $showingQuickAdd) { GlobalQuickAddView() }
        }
    }

    private var summaryText: String {
        """
        Aurea — riepilogo
        Portafogli attivi: \(activeWallets)
        Movimenti: \(transactions.count)
        Impegni aperti: \(openAgendaItems)
        Obiettivi attivi: \(activeGoals)
        Debiti e crediti aperti: \(openRelationships)
        Budget attivi: \(activeBudgets)
        Ricorrenti attive: \(activeRecurring)
        """
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
