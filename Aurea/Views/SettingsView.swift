import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]
    @Query private var transactions: [Transaction]
    @Query private var agendaItems: [AgendaItem]
    @Query private var goals: [Goal]
    @Query private var relationships: [Relationship]
    @Query private var budgets: [Budget]
    @Query private var recurringTransactions: [RecurringTransaction]

    @AppStorage("aurea.notifications.relationships") private var relationshipNotifications = true
    @AppStorage("aurea.notifications.recurring") private var recurringNotifications = true
    @AppStorage("aurea.notifications.budgets") private var budgetNotifications = true
    @AppStorage("aurea.agenda.showCompleted") private var showCompletedAgenda = true
    @AppStorage("aurea.agenda.defaultReminder") private var defaultReminder = 0
    @AppStorage("aurea.appearance") private var appearanceRaw = AppAppearance.system.rawValue

    @State private var showingFinance = false
    @State private var showingAgenda = false
    @State private var showingQuickAdd = false
    @State private var showingInsights = false
    @State private var showingOnboarding = false
    @State private var showingImporter = false
    @State private var showingRestoreConfirmation = false
    @State private var pendingRestore: BackupRestoreService.Payload?
    @State private var exportItem: ExportItem?
    @State private var statusMessage: String?

    private var openAgendaItems: Int { agendaItems.filter { !$0.isCompleted }.count }
    private var activeWallets: Int { wallets.filter { !$0.isArchived }.count }
    private var activeGoals: Int { goals.filter { !$0.isCompleted }.count }
    private var openRelationships: Int { relationships.filter { !$0.isClosed }.count }
    private var activeBudgets: Int { budgets.filter { !$0.isArchived }.count }
    private var activeRecurring: Int { recurringTransactions.filter { $0.isActive }.count }
    private var appearanceBinding: Binding<AppAppearance> {
        Binding(get: { AppAppearance(rawValue: appearanceRaw) ?? .system }, set: { appearanceRaw = $0.rawValue })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Analisi") {
                    navigationButton("Panoramica completa", icon: "rectangle.3.group") { showingInsights = true }
                    Button { runDiagnostics() } label: { Label("Verifica integrità dati", systemImage: "checkmark.shield") }
                }

                Section("Gestione") {
                    Button { showingQuickAdd = true } label: { Label("Aggiungi qualcosa", systemImage: "plus.circle") }
                    navigationButton("Centro finanziario", icon: "chart.pie") { showingFinance = true }
                    navigationButton("Agenda completa", icon: "calendar") { showingAgenda = true }
                }

                Section {
                    Toggle("Debiti e crediti", isOn: $relationshipNotifications)
                    Toggle("Movimenti ricorrenti", isOn: $recurringNotifications)
                    Toggle("Avvisi budget", isOn: $budgetNotifications)
                    Button { refreshReminders(); statusMessage = "Promemoria aggiornati." } label: {
                        Label("Aggiorna promemoria", systemImage: "bell.badge")
                    }
                } header: { Text("Notifiche") }
                footer: { Text("Le scadenze di debiti/crediti e ricorrenti vengono ricordate il giorno prima. I budget avvisano all'80% e quando vengono superati.") }

                Section {
                    Picker("Aspetto", selection: appearanceBinding) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Mostra completati in Agenda", isOn: $showCompletedAgenda)
                    Picker("Promemoria predefinito", selection: $defaultReminder) {
                        Text("Nessuno").tag(0)
                        Text("All'ora dell'impegno").tag(1)
                        Text("5 minuti prima").tag(5)
                        Text("15 minuti prima").tag(15)
                        Text("30 minuti prima").tag(30)
                        Text("1 ora prima").tag(60)
                    }
                    LabeledContent("Valuta principale", value: "EUR")
                } header: { Text("Preferenze") }
                footer: { Text("La valuta principale della v1 è EUR; i portafogli in altre valute usano il cambio configurato nel Centro finanziario.") }

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
                    Button { exportText(makeCSV(), filename: "Aurea-Movimenti.csv") } label: {
                        Label("Esporta movimenti CSV", systemImage: "tablecells")
                    }
                    Button { createFullBackup() } label: {
                        Label("Crea backup completo", systemImage: "externaldrive")
                    }
                    Button { showingImporter = true } label: {
                        Label("Ripristina backup", systemImage: "arrow.counterclockwise.circle")
                    }
                } header: { Text("Esportazione e backup") }
                footer: { Text("Il backup completo include portafogli, movimenti, agenda, obiettivi, debiti/crediti, budget, ricorrenti e categorie. Il ripristino sostituisce i dati presenti dopo una conferma esplicita.") }

                Section {
                    Button { showingOnboarding = true } label: { Label("Rivedi introduzione", systemImage: "play.rectangle") }
                } header: { Text("Aiuto") }

                Section {
                    LabeledContent("Archiviazione") { Label("Sul dispositivo", systemImage: "iphone").foregroundStyle(.secondary) }
                    LabeledContent("Aurea AI") { Text("Locale").foregroundStyle(.secondary) }
                    LabeledContent("Conferma azioni AI") { Text("Sempre attiva").foregroundStyle(.secondary) }
                } header: { Text("Privacy e funzionamento") }
                footer: { Text("Aurea usa i dati già presenti nell'app e chiede conferma prima delle azioni che modificano i dati.") }

                Section("Informazioni") {
                    LabeledContent("App", value: "Aurea")
                    LabeledContent("Versione", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                    LabeledContent("Stato", value: "v1 in preparazione")
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
            .sheet(isPresented: $showingInsights) { AureaInsightsView() }
            .sheet(isPresented: $showingFinance) { FinanceCenterView() }
            .sheet(isPresented: $showingAgenda) { AgendaView() }
            .sheet(isPresented: $showingQuickAdd) { GlobalQuickAddView() }
            .fullScreenCover(isPresented: $showingOnboarding) { OnboardingView() }
            .sheet(item: $exportItem) { item in ActivityView(activityItems: [item.url]) }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in handleImport(result) }
            .confirmationDialog("Ripristinare questo backup?", isPresented: $showingRestoreConfirmation, titleVisibility: .visible) {
                Button("Sostituisci i dati attuali", role: .destructive) { restorePendingBackup() }
                Button("Annulla", role: .cancel) { pendingRestore = nil }
            } message: { Text("Prima di procedere, crea un backup dei dati attuali se vuoi poter tornare indietro.") }
            .alert("Aurea", isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) {
                Button("OK") { statusMessage = nil }
            } message: { Text(statusMessage ?? "") }
            .onChange(of: relationshipNotifications) { _, _ in refreshReminders() }
            .onChange(of: recurringNotifications) { _, _ in refreshReminders() }
            .onChange(of: budgetNotifications) { _, _ in refreshReminders() }
        }
    }

    private var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1" }
    private var buildNumber: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }

    private func navigationButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack { Label(title, systemImage: icon); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) } }
    }

    private func refreshReminders() {
        AppNotificationManager.refresh(relationships: relationships, recurring: recurringTransactions, budgets: budgets, transactions: transactions)
    }

    private func dataRow(_ title: String, value: Int, icon: String) -> some View {
        HStack { Label(title, systemImage: icon); Spacer(); Text("\(value)").foregroundStyle(.secondary).monospacedDigit() }
    }

    private func exportText(_ text: String, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do { try text.write(to: url, atomically: true, encoding: .utf8); exportItem = ExportItem(url: url) }
        catch { statusMessage = "Esportazione non riuscita: \(error.localizedDescription)" }
    }

    private func createFullBackup() {
        do {
            let payload = try BackupRestoreService.makePayload(context: modelContext)
            exportText(try BackupRestoreService.encode(payload), filename: "Aurea-Backup-v2.json")
        } catch { statusMessage = "Backup non riuscito: \(error.localizedDescription)" }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessing = url.startAccessingSecurityScopedResource(); defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pendingRestore = try BackupRestoreService.decode(data)
            showingRestoreConfirmation = true
        } catch { statusMessage = "Backup non valido o non leggibile: \(error.localizedDescription)" }
    }

    private func restorePendingBackup() {
        guard let pendingRestore else { return }
        do {
            try BackupRestoreService.restore(pendingRestore, context: modelContext)
            self.pendingRestore = nil
            refreshReminders()
            statusMessage = "Backup ripristinato correttamente."
        } catch { statusMessage = "Ripristino non riuscito: \(error.localizedDescription)" }
    }

    private func runDiagnostics() {
        var issues: [String] = []
        let orphanMovements = transactions.filter { $0.wallet == nil }.count
        let missingRates = wallets.filter { !$0.isArchived && $0.currencyCode != "EUR" && $0.exchangeRateToEUR == nil }.count
        let invalidBudgets = budgets.filter { !$0.isArchived && $0.monthlyLimit <= 0 }.count
        let invalidRelationships = relationships.filter { !$0.isClosed && $0.amount <= 0 }.count
        if orphanMovements > 0 { issues.append("\(orphanMovements) movimenti senza portafoglio") }
        if missingRates > 0 { issues.append("\(missingRates) portafogli esteri senza cambio EUR") }
        if invalidBudgets > 0 { issues.append("\(invalidBudgets) budget con limite non valido") }
        if invalidRelationships > 0 { issues.append("\(invalidRelationships) debiti/crediti con importo non valido") }
        statusMessage = issues.isEmpty ? "Controllo completato: non risultano problemi evidenti nei dati." : "Da controllare: " + issues.joined(separator: "; ") + "."
    }

    private func makeCSV() -> String {
        var rows = ["Data,Tipo,Titolo,Categoria,Importo,Valuta,Portafoglio"]
        let formatter = ISO8601DateFormatter()
        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            let type: String
            switch transaction.type { case .expense: type = "Spesa"; case .income: type = "Entrata"; case .transfer: type = "Trasferimento" }
            let values = [formatter.string(from: transaction.date), type, transaction.title, transaction.category, NSDecimalNumber(decimal: transaction.amount).stringValue, transaction.wallet?.currencyCode ?? "EUR", transaction.wallet?.name ?? ""].map(csvEscape)
            rows.append(values.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
}

private struct ExportItem: Identifiable { let id = UUID(); let url: URL }

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
