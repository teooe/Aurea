import SwiftUI
import SwiftData

struct AureaAssistantView: View {
    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \AgendaItem.date) private var agendaItems: [AgendaItem]

    @State private var text = ""
    @State private var messages: [AssistantMessage] = [
        AssistantMessage(role: .assistant, text: "Ciao. Posso leggere i dati di Aurea e aiutarti con finanze e agenda.")
    ]

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        quickOverview
                        ForEach(messages) { message in messageBubble(message) }
                    }
                    .padding()
                }

                Divider()

                HStack(spacing: 10) {
                    TextField("Chiedi ad Aurea…", text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .submitLabel(.send)
                        .onSubmit(send)

                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Aurea")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Quanto ho speso questo mese?") { ask("Quanto ho speso questo mese?") }
                        Button("Quanto ho guadagnato questo mese?") { ask("Quanto ho guadagnato questo mese?") }
                        Button("Qual è il mio patrimonio?") { ask("Qual è il mio patrimonio?") }
                        Button("Quanto ho speso oggi?") { ask("Quanto ho speso oggi?") }
                        Button("Cosa ho in agenda?") { ask("Cosa ho in agenda?") }
                    } label: { Image(systemName: "lightbulb") }
                }
            }
        }
    }

    private var quickOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "sparkles"); Text("Panoramica").fontWeight(.semibold) }
            HStack(spacing: 12) {
                overviewMetric("Patrimonio", value: FinancialEngine.netWorth(wallets: activeWallets).formatted(.currency(code: "EUR")))
                overviewMetric("Spese mese", value: monthExpenses.formatted(.currency(code: "EUR")))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func overviewMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func messageBubble(_ message: AssistantMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: 320, alignment: message.role == .user ? .trailing : .leading)
            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        text = ""
        ask(trimmed)
    }

    private func ask(_ question: String) {
        messages.append(AssistantMessage(role: .user, text: question))
        messages.append(AssistantMessage(role: .assistant, text: answer(to: question)))
    }

    private func answer(to question: String) -> String {
        let q = normalized(question)

        // Importante: controlliamo prima gli intenti specifici. In precedenza
        // "quanto ho speso..." veniva catturato dal generico "quanto ho".
        if containsAny(q, ["spes", "speso", "spendo", "uscit"]) && containsAny(q, ["oggi", "giorno"]) {
            return "Oggi hai speso \(todayExpenses.formatted(.currency(code: "EUR")))."
        }

        if containsAny(q, ["spes", "speso", "spendo", "uscit"]) && containsAny(q, ["mese", "mensil", "questo mese"]) {
            return "Questo mese hai speso \(monthExpenses.formatted(.currency(code: "EUR")))."
        }

        if containsAny(q, ["guadagn", "entrat", "incass"]) && containsAny(q, ["mese", "mensil", "questo mese"]) {
            return "Questo mese hai registrato \(monthIncome.formatted(.currency(code: "EUR"))) di entrate."
        }

        if containsAny(q, ["agenda", "impegn", "appuntament", "scadenz", "prossim", "cosa devo fare"]) {
            let upcoming = upcomingAgenda
            guard !upcoming.isEmpty else { return "Non hai impegni aperti nei prossimi giorni." }
            let preview = upcoming.prefix(3).map { item in
                let when = item.hasTime ? item.date.formatted(date: .abbreviated, time: .shortened) : item.date.formatted(date: .abbreviated, time: .omitted)
                return "\(item.title) – \(when)"
            }.joined(separator: "; ")
            return "I prossimi impegni sono: \(preview)."
        }

        if containsAny(q, ["patrimonio", "saldo totale", "soldi totali", "quanto possiedo", "disponibilita totale"]) {
            let value = FinancialEngine.netWorth(wallets: activeWallets)
            return "Il tuo patrimonio attuale è \(value.formatted(.currency(code: "EUR")))."
        }

        return "Posso già rispondere a domande come: quanto hai speso oggi o questo mese, quanto hai guadagnato questo mese, qual è il tuo patrimonio e quali sono i prossimi impegni."
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
    }

    private func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { text.contains($0) }
    }

    private var currentMonthTransactions: [Transaction] {
        transactions.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }

    private var monthExpenses: Decimal {
        currentMonthTransactions
            .filter { $0.type == .expense && $0.category != "Trasferimento" }
            .reduce(Decimal.zero) { $0 + $1.amount * ($1.wallet?.effectiveExchangeRateToEUR ?? 1) }
    }

    private var monthIncome: Decimal {
        currentMonthTransactions
            .filter { $0.type == .income && $0.category != "Trasferimento" }
            .reduce(Decimal.zero) { $0 + $1.amount * ($1.wallet?.effectiveExchangeRateToEUR ?? 1) }
    }

    private var todayExpenses: Decimal {
        transactions
            .filter { Calendar.current.isDateInToday($0.date) && $0.type == .expense && $0.category != "Trasferimento" }
            .reduce(Decimal.zero) { $0 + $1.amount * ($1.wallet?.effectiveExchangeRateToEUR ?? 1) }
    }

    private var upcomingAgenda: [AgendaItem] {
        agendaItems
            .filter { !$0.isCompleted && $0.date >= Calendar.current.startOfDay(for: .now) }
            .sorted { $0.date < $1.date }
    }
}

private struct AssistantMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}
