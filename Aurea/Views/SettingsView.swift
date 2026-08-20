import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
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
    @AppStorage("aurea.onboarding.completed") private var onboardingCompleted = true

    @State private var showingFinance = false
    @State private var showingAgenda = false
    @State private var showingQuickAdd = false
    @State private var showingInsights = false
    @State private var showingReports = false
    @State private var showingOnboarding = false
    @State private var exportCSV = false
    @State private var exportBackup = false
    @State private var csvDocument = AureaTextDocument(text: "")
    @State private var backupDocument = AureaTextDocument(text: "")

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
                    navigationButton("Panoramica completa", icon: "rectangle.3.group") { showingInsights = true }
                    navigationButton("Report e statistiche", icon: "chart.xyaxis.line") { showingReports = true }
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
                    Button {
                        AppNotificationManager.refresh(relationships: relationships, recurring: recurringTransactions, budgets: budgets, transactions: transactions)
                    } label: {
                        Label("Aggiorna promemoria", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Notifiche")
                } footer: {
                    Text("Le scadenze di debiti/crediti e ricorrenti vengono ricordate il giorno prima. I budget avvisano all'80% e quando vengono superati.")
                }

                Section {
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
                } header: {
                    Text("Preferenze")
                } footer: {
                    Text("La valuta principale della v1 è EUR; i portafogli in altre valute usano il cambio configurato nel Centro finanziario.")
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
                    Button {
                        csvDocument = AureaTextDocument(text: makeCSV())
                        exportCSV = true
                    } label: {
                        Label("Esporta movimenti CSV", systemImage: "tablecells")
                    }
                    Button {
                        backupDocument = AureaTextDocument(text: makeBackupJSON())
                        exportBackup = true
                    } label: {
                        Label("Crea backup JSON", systemImage: "externaldrive")
                    }
                } header: {
                    Text("Esportazione e backup")
                } footer: {
                    Text("Il CSV contiene i movimenti. Il backup JSON conserva una copia leggibile dei dati principali di Aurea; non modifica i dati presenti nell'app.")
                }

                Section {
                    Button {
                        showingOnboarding = true
                    } label: {
                        Label("Rivedi introduzione", systemImage: "play.rectangle")
                    }
                } header: {
                    Text("Aiuto")
                }

                Section {
                    LabeledContent("Archiviazione") { Label("Sul dispositivo", systemImage: "iphone").foregroundStyle(.secondary) }
                    LabeledContent("Aurea AI v2") { Text("Locale").foregroundStyle(.secondary) }
                    LabeledContent("Conferma azioni AI") { Text("Sempre attiva").foregroundStyle(.secondary) }
                } header: {
                    Text("Privacy e funzionamento")
                } footer: {
                    Text("Aurea AI usa i dati già presenti nell'app e chiede conferma prima di creare movimenti o impegni.")
                }

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
            .sheet(isPresented: $showingReports) { AureaReportsView() }
            .sheet(isPresented: $showingFinance) { FinanceCenterView() }
            .sheet(isPresented: $showingAgenda) { AgendaView() }
            .sheet(isPresented: $showingQuickAdd) { GlobalQuickAddView() }
            .fullScreenCover(isPresented: $showingOnboarding) { OnboardingView() }
            .fileExporter(isPresented: $exportCSV, document: csvDocument, contentType: .commaSeparatedText, defaultFilename: "Aurea-Movimenti") { _ in }
            .fileExporter(isPresented: $exportBackup, document: backupDocument, contentType: .json, defaultFilename: "Aurea-Backup") { _ in }
            .onChange(of: relationshipNotifications) { _, _ in refreshReminders() }
            .onChange(of: recurringNotifications) { _, _ in refreshReminders() }
            .onChange(of: budgetNotifications) { _, _ in refreshReminders() }
        }
    }

    private func navigationButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private func refreshReminders() {
        AppNotificationManager.refresh(relationships: relationships, recurring: recurringTransactions, budgets: budgets, transactions: transactions)
    }

    private func dataRow(_ title: String, value: Int, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text("\(value)").foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func makeCSV() -> String {
        var rows = ["Data,Tipo,Titolo,Categoria,Importo,Valuta,Portafoglio"]
        let formatter = ISO8601DateFormatter()
        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            let type = transaction.type == .expense ? "Spesa" : "Entrata"
            let values = [
                formatter.string(from: transaction.date),
                type,
                transaction.title,
                transaction.category,
                NSDecimalNumber(decimal: transaction.amount).stringValue,
                transaction.wallet?.currencyCode ?? "EUR",
                transaction.wallet?.name ?? ""
            ].map(csvEscape)
            rows.append(values.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func makeBackupJSON() -> String {
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "version": 1,
            "createdAt": formatter.string(from: .now),
            "wallets": wallets.map { ["name": $0.name, "currency": $0.currencyCode, "balance": NSDecimalNumber(decimal: $0.balance).stringValue, "archived": $0.isArchived] },
            "transactions": transactions.map { ["date": formatter.string(from: $0.date), "type": $0.type.rawValue, "title": $0.title, "category": $0.category, "amount": NSDecimalNumber(decimal: $0.amount).stringValue, "wallet": $0.wallet?.name ?? ""] },
            "agenda": agendaItems.map { ["title": $0.title, "type": $0.type.rawValue, "date": formatter.string(from: $0.date), "completed": $0.isCompleted, "priority": $0.priority.rawValue] },
            "goals": goals.map { ["title": $0.title, "type": $0.type.rawValue, "currentAmount": NSDecimalNumber(decimal: $0.currentAmount).stringValue, "targetAmount": $0.targetAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? "", "completed": $0.isCompleted] },
            "relationships": relationships.map { ["person": $0.personName, "type": $0.type.rawValue, "amount": NSDecimalNumber(decimal: $0.amount).stringValue, "remaining": NSDecimalNumber(decimal: $0.remainingAmount).stringValue, "closed": $0.isClosed] },
            "budgets": budgets.map { ["title": $0.title, "category": $0.category ?? "", "monthlyLimit": NSDecimalNumber(decimal: $0.monthlyLimit).stringValue, "archived": $0.isArchived] },
            "recurring": recurringTransactions.map { ["title": $0.title, "type": $0.type.rawValue, "amount": NSDecimalNumber(decimal: $0.amount).stringValue, "category": $0.category, "frequency": $0.frequency.rawValue, "nextDate": formatter.string(from: $0.nextDate), "active": $0.isActive] }
        ]
        guard JSONSerialization.isValidJSONObject(payload), let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

struct AureaTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .commaSeparatedText, .json] }
    var text: String

    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = configuration.file.regularFileContents.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
