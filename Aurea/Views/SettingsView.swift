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
    @State private var showingInsights = false
    @State private var showingReports = false

    private var openAgendaItems: Int { agendaItems.filter { !$0.isCompleted }.count }
    private var activeWallets: Int { wallets.filter { !$0.isArchived }.count }
    private var activeGoals: Int { goals.filter { !$0.isCompleted }.count }
    private var openRelationships: Int { relationships.filter { !$0.isClosed }.count }
    private var activeBudgets: Int { budgets.filter { !$0.isArchived }.count }
    private var activeRecurring: Int { recurringTransactions.filter { $0.isActive }.count }

    var body: some View {
        NavigationStack {
            Form {
                Section("Analisi") {
                    Button { showingInsights = true } label: { navigationRow("Panoramica completa", icon: "rectangle.3.group") }
                    Button { showingReports = true } label: { navigationRow("Report e statistiche", icon: "chart.bar.xaxis") }
                }

                Section("Gestione") {
                    Button { showingQuickAdd = true } label: { Label("Aggiungi qualcosa", systemImage: "plus.circle") }
                    Button { showingFinance = true } label: { navigationRow("Centro finanziario", icon: "chart.pie") }
                    Button { showingAgenda = true } label: { navigationRow("Agenda completa", icon: "calendar") }
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

                Section {
                    ShareLink(item: summaryText) { Label("Condividi riepilogo Aurea", systemImage: "square.and.arrow.up") }
                } header: { Text("Condivisione") } footer: { Text("Il riepilogo contiene solo conteggi generali e non include l'elenco completo dei movimenti.") }

                Section {
                    LabeledContent("Archiviazione") { Label("Sul dispositivo", systemImage: "iphone").foregroundStyle(.secondary) }
                    LabeledContent("Aurea AI v2") { Text("Locale").foregroundStyle(.secondary) }
                    LabeledContent("Conferma azioni AI") { Text("Sempre attiva").foregroundStyle(.secondary) }
                } header: { Text("Privacy e funzionamento") } footer: { Text("Nella versione attuale Aurea AI analizza i dati già presenti nell'app e chiede conferma prima di creare movimenti o impegni.") }

                Section("Informazioni") {
                    LabeledContent("App", value: "Aurea")
                    LabeledContent("Versione", value: "0.1")
                    LabeledContent("Stato", value: "Sviluppo")
                }
            }
            .navigationTitle("Aurea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
            .sheet(isPresented: $showingInsights) { AureaInsightsView() }
            .sheet(isPresented: $showingReports) { ReportsView() }
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

    private func navigationRow(_ title: String, icon: String) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
    }
    private func dataRow(_ title: String, value: Int, icon: String) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Text("\(value)").foregroundStyle(.secondary).monospacedDigit() }
    }
}
