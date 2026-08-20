import SwiftUI
import SwiftData

struct AureaAssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \AgendaItem.date) private var agendaItems: [AgendaItem]
    @Query private var categories: [FinanceCategory]

    @State private var text = ""
    @State private var messages: [AssistantMessage] = [AssistantMessage(role: .assistant, text: "Ciao. Posso leggere i dati di Aurea, analizzarli e preparare semplici azioni da confermare.")]
    @State private var pendingAction: PendingAssistantAction?
    @State private var showingConfirmation = false

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        quickOverview
                        ForEach(messages) { message in messageBubble(message) }
                    }.padding()
                }
                Divider()
                HStack(spacing: 10) {
                    TextField("Chiedi ad Aurea…", text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(1...4).submitLabel(.send).onSubmit(send)
                    Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding().background(.bar)
            }
            .navigationTitle("Aurea")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Spesa più alta del mese") { ask("Qual è stata la mia spesa più alta questo mese?") }
                        Button("Spese per categoria") { ask("In quale categoria ho speso di più questo mese?") }
                        Button("Confronta col mese scorso") { ask("Come sto andando rispetto al mese scorso?") }
                        Button("Prossimi impegni") { ask("Cosa ho in agenda?") }
                    } label: { Image(systemName: "lightbulb") }
                }
            }
            .confirmationDialog("Conferma azione", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("Conferma") {
                    if let action = pendingAction { execute(action) }
                }
                Button("Annulla", role: .cancel) { pendingAction = nil }
            } message: {
                Text(pendingAction?.summary ?? "")
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
        }.padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func overviewMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.headline).minimumScaleFactor(0.7).lineLimit(1) }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func messageBubble(_ message: AssistantMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            Text(message.text).padding(.horizontal, 14).padding(.vertical, 10).background(message.role == .user ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).frame(maxWidth: 320, alignment: message.role == .user ? .trailing : .leading)
            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    private func send() { let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines); guard !trimmed.isEmpty else { return }; text = ""; ask(trimmed) }

    private func ask(_ question: String) {
        messages.append(AssistantMessage(role: .user, text: question))
        if let action = parseAction(question) {
            pendingAction = action
            messages.append(AssistantMessage(role: .assistant, text: "Ho capito questa azione: \(action.summary). Te la faccio confermare prima di salvare."))
            showingConfirmation = true
        } else { messages.append(AssistantMessage(role: .assistant, text: answer(to: question))) }
    }

    private func answer(to question: String) -> String {
        let q = normalized(question)
        if containsAny(q, ["spesa piu alta", "spesa maggiore", "speso di piu", "movimento piu alto"]) {
            guard let highest = currentMonthTransactions.filter({ $0.type == .expense && $0.category != "Trasferimento" }).max(by: { valueInEUR($0) < valueInEUR($1) }) else { return "Non risultano spese questo mese." }
            return "La spesa più alta del mese è \(highest.title): \(valueInEUR(highest).formatted(.currency(code: "EUR"))) nella categoria \(highest.category)."
        }
        if containsAny(q, ["categoria", "ristor", "cibo", "trasport", "svago", "shopping"]) && containsAny(q, ["spes", "speso", "quanto"]) {
            if let requested = matchingCategory(in: q) { return "Questo mese hai speso \(expensesThisMonth(category: requested).formatted(.currency(code: "EUR"))) in \(requested)." }
            let grouped = Dictionary(grouping: currentMonthTransactions.filter { $0.type == .expense && $0.category != "Trasferimento" }, by: { $0.category })
            guard let top = grouped.map({ ($0.key, $0.value.reduce(Decimal.zero) { $0 + valueInEUR($1) }) }).max(by: { $0.1 < $1.1 }) else { return "Non risultano spese questo mese." }
            return "La categoria in cui hai speso di più questo mese è \(top.0), con \(top.1.formatted(.currency(code: "EUR")))."
        }
        if containsAny(q, ["mese scorso", "rispetto", "confront", "andando"]) && containsAny(q, ["spes", "mese", "andando"]) {
            let difference = monthExpenses - previousMonthExpenses
            if difference == 0 { return "Le spese di questo mese sono uguali a quelle del mese scorso: \(monthExpenses.formatted(.currency(code: "EUR")))." }
            return "Questo mese hai speso \(monthExpenses.formatted(.currency(code: "EUR"))), cioè \(absDecimal(difference).formatted(.currency(code: "EUR"))) \(difference > 0 ? "in più" : "in meno") rispetto al mese scorso."
        }
        if containsAny(q, ["spes", "speso", "spendo", "uscit"]) && containsAny(q, ["oggi", "giorno"]) { return "Oggi hai speso \(todayExpenses.formatted(.currency(code: "EUR")))." }
        if containsAny(q, ["spes", "speso", "spendo", "uscit"]) && containsAny(q, ["mese", "mensil"]) { return "Questo mese hai speso \(monthExpenses.formatted(.currency(code: "EUR")))." }
        if containsAny(q, ["guadagn", "entrat", "incass"]) && containsAny(q, ["mese", "mensil"]) { return "Questo mese hai registrato \(monthIncome.formatted(.currency(code: "EUR"))) di entrate." }
        if containsAny(q, ["agenda", "impegn", "appuntament", "scadenz", "prossim", "cosa devo fare"]) {
            guard !upcomingAgenda.isEmpty else { return "Non hai impegni aperti nei prossimi giorni." }
            return "I prossimi impegni sono: " + upcomingAgenda.prefix(4).map { item in let when = item.hasTime ? item.date.formatted(date: .abbreviated, time: .shortened) : item.date.formatted(date: .abbreviated, time: .omitted); return "\(item.title) – \(when)" }.joined(separator: "; ") + "."
        }
        if containsAny(q, ["patrimonio", "saldo totale", "soldi totali", "quanto possiedo"]) { return "Il tuo patrimonio attuale è \(FinancialEngine.netWorth(wallets: activeWallets).formatted(.currency(code: "EUR")))." }
        return "Posso analizzare patrimonio, spese, entrate, categorie, confronti mensili e agenda. Posso anche preparare azioni semplici, per esempio «pizza 18 euro» o «palestra domani alle 18», sempre chiedendoti conferma."
    }

    private func parseAction(_ input: String) -> PendingAssistantAction? {
        let q = normalized(input)
        if containsAny(q, ["domani", "oggi"]) && (containsAny(q, ["alle", "ore", "appuntamento", "impegno", "ricordami", "aggiungi"]) || extractHour(from: q) != nil) {
            var date = Calendar.current.startOfDay(for: .now); if q.contains("domani") { date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date }
            let hour = extractHour(from: q); if let hour { date = Calendar.current.date(bySettingHour: hour.hour, minute: hour.minute, second: 0, of: date) ?? date }
            let title = cleanedAgendaTitle(input); guard !title.isEmpty else { return nil }
            return PendingAssistantAction(kind: .agenda(title: title, date: date, hasTime: hour != nil))
        }
        if let amount = extractAmount(from: q), !containsAny(q, ["quanto", "speso", "spese", "guadagnato", "patrimonio"]) {
            guard let wallet = activeWallets.first else { return nil }; let title = cleanedTransactionTitle(input); guard !title.isEmpty else { return nil }
            return PendingAssistantAction(kind: .expense(title: title, amount: amount, category: guessedCategory(for: q), wallet: wallet))
        }
        return nil
    }

    private func execute(_ action: PendingAssistantAction) {
        switch action.kind {
        case let .expense(title, amount, category, wallet):
            modelContext.insert(Transaction(type: .expense, amount: amount, category: category, title: title, wallet: wallet))
            messages.append(AssistantMessage(role: .assistant, text: "Fatto: ho registrato \(title), \(amount.formatted(.currency(code: wallet.currencyCode))), in \(category)."))
        case let .agenda(title, date, hasTime):
            modelContext.insert(AgendaItem(title: title, type: .task, date: date, hasTime: hasTime))
            messages.append(AssistantMessage(role: .assistant, text: "Fatto: ho aggiunto \(title) in agenda per \(date.formatted(date: .abbreviated, time: hasTime ? .shortened : .omitted))."))
        }
        pendingAction = nil
    }

    private func normalized(_ value: String) -> String { value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased() }
    private func containsAny(_ text: String, _ terms: [String]) -> Bool { terms.contains { text.contains($0) } }
    private func valueInEUR(_ transaction: Transaction) -> Decimal { transaction.amount * (transaction.wallet?.effectiveExchangeRateToEUR ?? 1) }
    private func absDecimal(_ value: Decimal) -> Decimal { value < 0 ? -value : value }
    private var currentMonthTransactions: [Transaction] { transactions.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) } }
    private var previousMonthTransactions: [Transaction] { guard let previous = Calendar.current.date(byAdding: .month, value: -1, to: .now) else { return [] }; return transactions.filter { Calendar.current.isDate($0.date, equalTo: previous, toGranularity: .month) } }
    private var monthExpenses: Decimal { currentMonthTransactions.filter { $0.type == .expense && $0.category != "Trasferimento" }.reduce(0) { $0 + valueInEUR($1) } }
    private var previousMonthExpenses: Decimal { previousMonthTransactions.filter { $0.type == .expense && $0.category != "Trasferimento" }.reduce(0) { $0 + valueInEUR($1) } }
    private var monthIncome: Decimal { currentMonthTransactions.filter { $0.type == .income && $0.category != "Trasferimento" }.reduce(0) { $0 + valueInEUR($1) } }
    private var todayExpenses: Decimal { transactions.filter { Calendar.current.isDateInToday($0.date) && $0.type == .expense && $0.category != "Trasferimento" }.reduce(0) { $0 + valueInEUR($1) } }
    private var upcomingAgenda: [AgendaItem] { agendaItems.filter { !$0.isCompleted && $0.date >= Calendar.current.startOfDay(for: .now) }.sorted { $0.date < $1.date } }
    private func expensesThisMonth(category: String) -> Decimal { currentMonthTransactions.filter { $0.type == .expense && normalized($0.category) == normalized(category) }.reduce(0) { $0 + valueInEUR($1) } }
    private func matchingCategory(in text: String) -> String? { let names = Set(categories.filter { !$0.isArchived && $0.type == .expense }.map(\.name) + transactions.filter { $0.type == .expense }.map(\.category)); return names.first { text.contains(normalized($0)) } }
    private func guessedCategory(for text: String) -> String { if let exact = matchingCategory(in: text) { return exact }; let rules: [(String,[String])] = [("Cibo",["pizza","ristor","pranzo","cena","bar","caffe","spesa supermercato"]),("Trasporti",["benzina","treno","bus","taxi","uber","parcheggio"]),("Svago",["cinema","concerto","gioco","aperitivo"]),("Shopping",["vestiti","scarpe","amazon","shopping"])]; for (category, words) in rules where words.contains(where: { text.contains($0) }) { return category }; return categories.first(where: { !$0.isArchived && $0.type == .expense })?.name ?? "Altro" }
    private func extractAmount(from text: String) -> Decimal? { let pattern = #"(?:€\s*)?(\d+(?:[\.,]\d{1,2})?)(?:\s*(?:€|euro|eur))"#; guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range(at: 1), in: text) else { return nil }; return Decimal(string: String(text[range]).replacingOccurrences(of: ",", with: ".")) }
    private func extractHour(from text: String) -> (hour: Int, minute: Int)? { let pattern = #"(?:alle|ore)\s+(\d{1,2})(?:(?::|\.)?(\d{2}))?"#; guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let hourRange = Range(match.range(at: 1), in: text), let hour = Int(text[hourRange]), (0...23).contains(hour) else { return nil }; var minute = 0; if match.range(at: 2).location != NSNotFound, let minuteRange = Range(match.range(at: 2), in: text) { minute = Int(text[minuteRange]) ?? 0 }; guard (0...59).contains(minute) else { return nil }; return (hour, minute) }
    private func cleanedTransactionTitle(_ input: String) -> String { var value = input; if let regex = try? NSRegularExpression(pattern: #"(?:€\s*)?\d+(?:[\.,]\d{1,2})?\s*(?:€|euro|eur)"#, options: [.caseInsensitive]) { value = regex.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: "") }; return value.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
    private func cleanedAgendaTitle(_ input: String) -> String { var value = normalized(input); value = value.replacingOccurrences(of: "aggiungi", with: "").replacingOccurrences(of: "ricordami", with: "").replacingOccurrences(of: "domani", with: "").replacingOccurrences(of: "oggi", with: ""); if let regex = try? NSRegularExpression(pattern: #"(?:alle|ore)\s+\d{1,2}(?:(?::|\.)?\d{2})?"#) { value = regex.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: "") }; return value.trimmingCharacters(in: .whitespacesAndNewlines).capitalized }
}

private struct AssistantMessage: Identifiable { enum Role { case user, assistant }; let id = UUID(); let role: Role; let text: String }
private struct PendingAssistantAction: Identifiable {
    enum Kind { case expense(title: String, amount: Decimal, category: String, wallet: Wallet); case agenda(title: String, date: Date, hasTime: Bool) }
    let id = UUID(); let kind: Kind
    var summary: String { switch kind { case let .expense(title, amount, category, wallet): return "Registra una spesa: \(title), \(amount.formatted(.currency(code: wallet.currencyCode))), categoria \(category), dal portafoglio \(wallet.name)."; case let .agenda(title, date, hasTime): return "Aggiungi in agenda \(title) per \(date.formatted(date: .abbreviated, time: hasTime ? .shortened : .omitted))." } }
}
