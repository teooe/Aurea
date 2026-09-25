import SwiftUI
import SwiftData

struct AureaAssistantView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \AgendaItem.date) private var agendaItems: [AgendaItem]
    @Query private var categories: [FinanceCategory]
    @Query private var budgets: [Budget]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \Relationship.createdAt, order: .reverse) private var relationships: [Relationship]
    @Query(sort: \RecurringTransaction.nextDate) private var recurringTransactions: [RecurringTransaction]

    @State private var text = ""
    @State private var messages: [AssistantMessage] = [
        AssistantMessage(role: .assistant, text: "Ciao. Ora posso incrociare finanze, budget, obiettivi, debiti e crediti, ricorrenti e Agenda. Le azioni che modificano i dati richiedono sempre conferma.")
    ]
    @State private var pendingAction: PendingAssistantAction?
    @State private var showingConfirmation = false

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }
    private var activeBudgets: [Budget] { budgets.filter { !$0.isArchived } }
    private var activeGoals: [Goal] { goals.filter { !$0.isCompleted } }
    private var openRelationships: [Relationship] { relationships.filter { !$0.isClosed && $0.remainingAmount > 0 } }
    private var activeRecurring: [RecurringTransaction] { recurringTransactions.filter { $0.isActive } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        quickOverview
                        ForEach(messages) { message in
                            messageBubble(message)
                        }
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
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
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
                        Button("Come sto andando?") { ask("Come sto andando questo mese?") }
                        Button("Dove posso risparmiare?") { ask("Dove potrei risparmiare?") }
                        Button("Stato budget") { ask("Come sono messo con i budget?") }
                        Button("Stato obiettivi") { ask("Come stanno andando i miei obiettivi?") }
                        Button("Debiti e crediti") { ask("Quali debiti e crediti ho aperti?") }
                        Button("Prossimi impegni") { ask("Cosa ho in agenda?") }
                    } label: {
                        Image(systemName: "lightbulb")
                    }
                }
            }
            .confirmationDialog("Conferma azione", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("Conferma") {
                    if let action = pendingAction { execute(action) }
                }
                Button("Annulla", role: .cancel) {
                    pendingAction = nil
                }
            } message: {
                Text(pendingAction?.summary ?? "")
            }
        }
    }

    private var quickOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                Text("Panoramica")
                    .fontWeight(.semibold)
                Spacer()
                Text(monthBalance >= 0 ? "Mese positivo" : "Mese negativo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                overviewMetric("Patrimonio", value: euro(netWorth))
                overviewMetric("Bilancio mese", value: euro(monthBalance))
            }

            HStack(spacing: 12) {
                overviewMetric("Budget", value: activeBudgets.isEmpty ? "—" : "\(budgetAlertsCount) da controllare")
                overviewMetric("Agenda", value: "\(upcomingAgenda.count) aperti")
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func overviewMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
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
                .frame(maxWidth: 330, alignment: message.role == .user ? .trailing : .leading)
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

        if let action = parseAction(question) {
            pendingAction = action
            messages.append(AssistantMessage(role: .assistant, text: "Ho preparato questa azione: \(action.summary) Confermala prima di salvarla."))
            showingConfirmation = true
        } else {
            messages.append(AssistantMessage(role: .assistant, text: answer(to: question)))
        }
    }

    // MARK: - Answers

    private func answer(to question: String) -> String {
        let q = normalized(question)

        if containsAny(q, ["posso permettermi", "posso spendere", "spendere questo weekend", "spendere nel weekend"]),
           let amount = extractAmount(from: q) {
            return affordabilityAnswer(for: amount)
        }

        if containsAny(q, ["media al giorno", "mediamente al giorno", "media giornaliera", "spendo al giorno"]) {
            let days = max(Calendar.current.component(.day, from: .now), 1)
            let average = monthExpenses / Decimal(days)
            return "Finora questo mese stai spendendo in media \(euro(average)) al giorno. Hai registrato \(euro(monthExpenses)) di spese in \(days) giorni di calendario."
        }

        if containsAny(q, ["dove posso risparmiare", "dove potrei risparmiare", "come risparmiare", "risparmiare di piu"]) {
            return savingsAnswer
        }

        if containsAny(q, ["come sto andando", "situazione finanziaria", "come sono messo", "riepilogo finanziario"]) && !q.contains("budget") {
            return financialHealthAnswer
        }

        if containsAny(q, ["budget", "limite di spesa"]) {
            return budgetAnswer(for: q)
        }

        if containsAny(q, ["obiettiv", "goal", "quanto mi manca"]) {
            return goalsAnswer(for: q)
        }

        if containsAny(q, ["debiti", "debito", "crediti", "credito", "devo pagare", "devo ricevere", "mi devono"]) {
            return relationshipsAnswer
        }

        if containsAny(q, ["ricorrent", "abbonament", "prossimi pagamenti", "pagamenti automatici"]) {
            return recurringAnswer
        }

        if containsAny(q, ["saldo portafoglio", "portafogli", "conto", "saldo di"]) {
            if let wallet = matchingWallet(in: q) {
                return "Il saldo attuale di \(wallet.name) è \(FinancialEngine.balance(for: wallet).formatted(.currency(code: wallet.currencyCode)))."
            }
            guard !activeWallets.isEmpty else { return "Non hai portafogli attivi." }
            return activeWallets.map { "\($0.name): \(FinancialEngine.balance(for: $0).formatted(.currency(code: $0.currencyCode)))" }.joined(separator: "; ") + "."
        }

        if containsAny(q, ["spesa piu alta", "spesa maggiore", "movimento piu alto"]) {
            guard let highest = currentMonthExpenses.max(by: { valueInEUR($0) < valueInEUR($1) }) else {
                return "Non risultano spese questo mese."
            }
            return "La spesa più alta del mese è \(highest.title): \(euro(valueInEUR(highest))) nella categoria \(highest.category)."
        }

        if containsAny(q, ["categoria", "ristor", "cibo", "trasport", "svago", "shopping"]) && containsAny(q, ["spes", "speso", "quanto"]) {
            if let requested = matchingCategory(in: q) {
                return "Questo mese hai speso \(euro(expensesThisMonth(category: requested))) in \(requested)."
            }
            guard let top = topExpenseCategory else { return "Non risultano spese questo mese." }
            return "La categoria in cui hai speso di più questo mese è \(top.name), con \(euro(top.amount))."
        }

        if containsAny(q, ["mese scorso", "rispetto", "confront"]) {
            let expenseDifference = monthExpenses - previousMonthExpenses
            let balanceDifference = monthBalance - previousMonthBalance
            return "Questo mese hai speso \(euro(monthExpenses)), \(differenceText(expenseDifference, lowerIsBetter: true)) rispetto al mese scorso. Il bilancio è \(euro(monthBalance)), \(differenceText(balanceDifference, lowerIsBetter: false))."
        }

        if containsAny(q, ["spes", "speso", "uscit"]) && containsAny(q, ["oggi", "giorno"]) {
            return "Oggi hai speso \(euro(todayExpenses))."
        }

        if containsAny(q, ["spes", "speso", "uscit"]) && containsAny(q, ["mese", "mensil"]) {
            return "Questo mese hai speso \(euro(monthExpenses))."
        }

        if containsAny(q, ["guadagn", "entrat", "incass"]) && containsAny(q, ["mese", "mensil"]) {
            return "Questo mese hai registrato \(euro(monthIncome)) di entrate."
        }

        if containsAny(q, ["agenda", "impegn", "appuntament", "scadenz", "prossim", "cosa devo fare"]) {
            guard !upcomingAgenda.isEmpty else { return "Non hai impegni aperti in programma." }
            return "I prossimi impegni sono: " + upcomingAgenda.prefix(5).map { item in
                let when = item.hasTime ? item.date.formatted(date: .abbreviated, time: .shortened) : item.date.formatted(date: .abbreviated, time: .omitted)
                return "\(item.title) – \(when)"
            }.joined(separator: "; ") + "."
        }

        if containsAny(q, ["patrimonio", "saldo totale", "soldi totali", "quanto possiedo"]) {
            return "Il tuo patrimonio attuale è \(euro(netWorth))."
        }

        return "Puoi chiedermi di patrimonio, spese, entrate, medie, categorie, budget, obiettivi, debiti e crediti, ricorrenti, portafogli e Agenda. Posso anche preparare azioni come «cena 24,50 euro ieri», «stipendio 900 euro oggi», «ricordami dentista venerdì alle 15» o «devo 40 euro a Luca», sempre con conferma."
    }

    private var financialHealthAnswer: String {
        var parts: [String] = []
        parts.append("Patrimonio: \(euro(netWorth)).")
        parts.append("Questo mese: \(euro(monthIncome)) di entrate, \(euro(monthExpenses)) di spese e bilancio \(euro(monthBalance)).")

        if previousMonthExpenses > 0 {
            let delta = monthExpenses - previousMonthExpenses
            parts.append("Le spese sono \(euro(absDecimal(delta))) \(delta > 0 ? "più alte" : delta < 0 ? "più basse" : "invariate") rispetto al mese scorso.")
        }
        if budgetAlertsCount > 0 {
            parts.append("Hai \(budgetAlertsCount) budget da controllare.")
        }
        if !openRelationships.isEmpty {
            parts.append("Restano aperti \(openRelationships.count) debiti/crediti.")
        }
        return parts.joined(separator: " ")
    }

    private var savingsAnswer: String {
        guard monthExpenses > 0 else { return "Non ho ancora abbastanza spese di questo mese per individuare aree di risparmio." }
        var suggestions: [String] = []
        if let top = topExpenseCategory {
            let share = decimalDouble(top.amount / monthExpenses)
            suggestions.append("La voce principale è \(top.name), con \(euro(top.amount)) (circa \(Int(share * 100))% delle spese del mese).")
        }
        if let highest = currentMonthExpenses.max(by: { valueInEUR($0) < valueInEUR($1) }) {
            suggestions.append("La singola spesa più alta è \(highest.title), \(euro(valueInEUR(highest))).")
        }
        if budgetAlertsCount > 0 {
            suggestions.append("Inoltre hai \(budgetAlertsCount) budget oltre l'80%, quindi partirei da quelli.")
        }
        suggestions.append("Questi sono segnali dai dati registrati, non una raccomandazione finanziaria personalizzata.")
        return suggestions.joined(separator: " ")
    }

    private func affordabilityAnswer(for amount: Decimal) -> String {
        let availableAfter = netWorth - amount
        let projectedRecurringExpenses = activeRecurring
            .filter { $0.type == .expense && $0.nextDate <= (Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now) }
            .reduce(Decimal.zero) { result, item in
                result + item.amount * (item.wallet?.effectiveExchangeRateToEUR ?? 1)
            }
        let openDebts = openRelationships.filter { $0.type == .debt }.reduce(Decimal.zero) { $0 + $1.remainingAmount }
        let knownCommitments = projectedRecurringExpenses + openDebts

        var response = "Dopo una spesa di \(euro(amount)), il patrimonio risultante sarebbe circa \(euro(availableAfter))."
        if knownCommitments > 0 {
            response += " Nei dati risultano inoltre circa \(euro(knownCommitments)) tra debiti aperti e ricorrenti in uscita nei prossimi 30 giorni."
        }
        if amount > netWorth {
            response += " L'importo supera il patrimonio registrato, quindi dai dati di Aurea non risulta sostenibile."
        } else if availableAfter < knownCommitments {
            response += " Ti lascerebbe sotto gli impegni finanziari già registrati, quindi sarebbe prudente evitarla o ridurla."
        } else if monthBalance < 0 {
            response += " È possibile rispetto al patrimonio, ma questo mese il bilancio è già negativo: la considererei con cautela."
        } else {
            response += " In base ai soli dati registrati sembra compatibile, mantenendo comunque un margine per spese non ancora inserite."
        }
        return response
    }

    private func budgetAnswer(for query: String) -> String {
        guard !activeBudgets.isEmpty else { return "Non hai budget attivi." }
        if let budget = activeBudgets.first(where: { query.contains(normalized($0.title)) || ($0.category.map { query.contains(normalized($0)) } ?? false) }) {
            return budgetDescription(budget)
        }
        return activeBudgets.map(budgetDescription).joined(separator: " ")
    }

    private func budgetDescription(_ budget: Budget) -> String {
        let spent = FinancialEngine.spentThisMonth(for: budget, transactions: transactions)
        let remaining = max(budget.monthlyLimit - spent, 0)
        let ratio = budget.monthlyLimit > 0 ? decimalDouble(spent / budget.monthlyLimit) : 0
        if ratio >= 1 {
            return "\(budget.title): hai speso \(euro(spent)) su \(euro(budget.monthlyLimit)), quindi il budget è superato di \(euro(spent - budget.monthlyLimit))."
        }
        return "\(budget.title): \(euro(spent)) su \(euro(budget.monthlyLimit)) (\(Int(ratio * 100))%), con \(euro(remaining)) disponibili."
    }

    private func goalsAnswer(for query: String) -> String {
        guard !activeGoals.isEmpty else { return "Non hai obiettivi attivi." }
        let matched = activeGoals.filter { query.contains(normalized($0.title)) }
        let source = matched.isEmpty ? activeGoals : matched
        return source.prefix(5).map { goal in
            var detail = "\(goal.title)"
            if let target = goal.targetAmount, target > 0 {
                let remaining = max(target - goal.currentAmount, 0)
                let percent = Int(min(max(decimalDouble(goal.currentAmount / target), 0), 1) * 100)
                detail += ": \(percent)% completato, mancano \(euro(remaining))"
            }
            if let date = goal.targetDate {
                detail += ", scadenza \(date.formatted(date: .abbreviated, time: .omitted))"
            }
            return detail + "."
        }.joined(separator: " ")
    }

    private var relationshipsAnswer: String {
        guard !openRelationships.isEmpty else { return "Non hai debiti o crediti aperti." }
        let debts = openRelationships.filter { $0.type == .debt }
        let credits = openRelationships.filter { $0.type == .credit }
        let debtTotal = debts.reduce(Decimal.zero) { $0 + $1.remainingAmount }
        let creditTotal = credits.reduce(Decimal.zero) { $0 + $1.remainingAmount }
        var answer = "Hai \(euro(debtTotal)) da pagare e \(euro(creditTotal)) da ricevere."
        let next = openRelationships.compactMap { item -> (Relationship, Date)? in item.dueDate.map { (item, $0) } }.sorted { $0.1 < $1.1 }.first
        if let next {
            answer += " La prossima scadenza è \(next.0.personName), \(euro(next.0.remainingAmount)), il \(next.1.formatted(date: .abbreviated, time: .omitted))."
        }
        return answer
    }

    private var recurringAnswer: String {
        guard !activeRecurring.isEmpty else { return "Non hai movimenti ricorrenti attivi." }
        return "I prossimi ricorrenti sono: " + activeRecurring.prefix(5).map { item in
            let code = item.wallet?.currencyCode ?? "EUR"
            return "\(item.title), \(item.amount.formatted(.currency(code: code))) il \(item.nextDate.formatted(date: .abbreviated, time: .omitted))"
        }.joined(separator: "; ") + "."
    }

    // MARK: - Actions

    private func parseAction(_ input: String) -> PendingAssistantAction? {
        let q = normalized(input)

        if let relationship = parseRelationshipAction(input, normalizedInput: q) {
            return relationship
        }

        if isAgendaCommand(q), let date = extractDate(from: q) {
            let hour = extractHour(from: q)
            let finalDate = hour.map { Calendar.current.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: date) ?? date } ?? date
            let title = cleanedAgendaTitle(input)
            guard !title.isEmpty else { return nil }
            return PendingAssistantAction(kind: .agenda(title: title, date: finalDate, hasTime: hour != nil))
        }

        if let amount = extractAmount(from: q), !isQuestionAboutAmount(q) {
            guard let wallet = matchingWallet(in: q) ?? activeWallets.first else { return nil }
            let date = extractDate(from: q) ?? .now
            let type: TransactionType = containsAny(q, ["stipendio", "entrata", "incasso", "ricevuto", "guadagnato", "rimborso"]) ? .income : .expense
            let title = cleanedTransactionTitle(input)
            guard !title.isEmpty else { return nil }
            let category = type == .income ? guessedIncomeCategory(for: q) : guessedCategory(for: q)
            return PendingAssistantAction(kind: .transaction(type: type, title: title, amount: amount, category: category, wallet: wallet, date: date))
        }

        return nil
    }

    private func parseRelationshipAction(_ input: String, normalizedInput q: String) -> PendingAssistantAction? {
        guard let amount = extractAmount(from: q) else { return nil }

        if q.contains("mi deve") || q.contains("mi devono") {
            let person = personName(from: input, around: "mi deve")
            guard !person.isEmpty else { return nil }
            return PendingAssistantAction(kind: .relationship(person: person, amount: amount, type: .credit))
        }

        if q.contains("devo") && containsAny(q, [" a ", "ad "]) && !containsAny(q, ["devo fare", "devo andare", "cosa devo"]) {
            let person = personAfterPreposition(in: input)
            guard !person.isEmpty else { return nil }
            return PendingAssistantAction(kind: .relationship(person: person, amount: amount, type: .debt))
        }

        return nil
    }

    private func execute(_ action: PendingAssistantAction) {
        switch action.kind {
        case let .transaction(type, title, amount, suggestedCategory, wallet, date):
            let category = CategoryService.resolve(suggestedCategory, type: type, in: modelContext)
            modelContext.insert(Transaction(type: type, amount: amount, date: date, category: category, title: title, wallet: wallet))
            let verb = type == .income ? "entrata" : "spesa"
            messages.append(AssistantMessage(role: .assistant, text: "Fatto: ho registrato l'\(verb) \(title), \(amount.formatted(.currency(code: wallet.currencyCode))), in \(category), con data \(date.formatted(date: .abbreviated, time: .omitted))."))

        case let .agenda(title, date, hasTime):
            let item = AgendaItem(title: title, type: .task, date: date, hasTime: hasTime)
            modelContext.insert(item)
            AgendaNotificationManager.schedule(for: item)
            messages.append(AssistantMessage(role: .assistant, text: "Fatto: ho aggiunto \(title) in Agenda per \(date.formatted(date: .abbreviated, time: hasTime ? .shortened : .omitted))."))

        case let .relationship(person, amount, type):
            modelContext.insert(Relationship(personName: person, amount: amount, type: type))
            messages.append(AssistantMessage(role: .assistant, text: type == .debt ? "Fatto: ho registrato un debito di \(euro(amount)) verso \(person)." : "Fatto: ho registrato un credito di \(euro(amount)) verso \(person)."))
        }

        pendingAction = nil
    }

    // MARK: - Data

    private var netWorth: Decimal { FinancialEngine.netWorth(wallets: activeWallets) }
    private var currentMonthTransactions: [Transaction] { transactions.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) } }
    private var previousMonthTransactions: [Transaction] {
        guard let previous = Calendar.current.date(byAdding: .month, value: -1, to: .now) else { return [] }
        return transactions.filter { Calendar.current.isDate($0.date, equalTo: previous, toGranularity: .month) }
    }
    private var currentMonthExpenses: [Transaction] { currentMonthTransactions.filter { $0.type == .expense && !$0.isTransfer } }
    private var monthExpenses: Decimal { currentMonthExpenses.reduce(0) { $0 + valueInEUR($1) } }
    private var monthIncome: Decimal { currentMonthTransactions.filter { $0.type == .income && !$0.isTransfer }.reduce(0) { $0 + valueInEUR($1) } }
    private var monthBalance: Decimal { monthIncome - monthExpenses }
    private var previousMonthExpenses: Decimal { previousMonthTransactions.filter { $0.type == .expense && !$0.isTransfer }.reduce(0) { $0 + valueInEUR($1) } }
    private var previousMonthIncome: Decimal { previousMonthTransactions.filter { $0.type == .income && !$0.isTransfer }.reduce(0) { $0 + valueInEUR($1) } }
    private var previousMonthBalance: Decimal { previousMonthIncome - previousMonthExpenses }
    private var todayExpenses: Decimal { transactions.filter { Calendar.current.isDateInToday($0.date) && $0.type == .expense && !$0.isTransfer }.reduce(0) { $0 + valueInEUR($1) } }
    private var upcomingAgenda: [AgendaItem] { agendaItems.filter { !$0.isCompleted && $0.date >= Calendar.current.startOfDay(for: .now) }.sorted { $0.date < $1.date } }
    private var topExpenseCategory: (name: String, amount: Decimal)? {
        let grouped = Dictionary(grouping: currentMonthExpenses, by: { $0.category })
        return grouped.map { name, items in (name: name, amount: items.reduce(Decimal.zero) { $0 + valueInEUR($1) }) }.max { $0.amount < $1.amount }
    }
    private var budgetAlertsCount: Int {
        activeBudgets.filter { budget in
            guard budget.monthlyLimit > 0 else { return false }
            return decimalDouble(FinancialEngine.spentThisMonth(for: budget, transactions: transactions) / budget.monthlyLimit) >= 0.8
        }.count
    }

    // MARK: - Parsing helpers

    private func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
    }

    private func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { text.contains($0) }
    }

    private func valueInEUR(_ transaction: Transaction) -> Decimal {
        FinancialEngine.amountInEUR(for: transaction)
    }

    private func euro(_ value: Decimal) -> String {
        value.formatted(.currency(code: "EUR"))
    }

    private func decimalDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private func absDecimal(_ value: Decimal) -> Decimal {
        value < 0 ? -value : value
    }

    private func differenceText(_ delta: Decimal, lowerIsBetter: Bool) -> String {
        if delta == 0 { return "invariato" }
        let direction = delta > 0 ? "in più" : "in meno"
        return "\(euro(absDecimal(delta))) \(direction)"
    }

    private func expensesThisMonth(category: String) -> Decimal {
        currentMonthExpenses.filter { normalized($0.category) == normalized(category) }.reduce(0) { $0 + valueInEUR($1) }
    }

    private func matchingCategory(in text: String) -> String? {
        let names = Set(categories.filter { !$0.isArchived && $0.type == .expense }.map(\.name) + transactions.filter { $0.type == .expense }.map(\.category))
        return names.first { text.contains(normalized($0)) }
    }

    private func matchingWallet(in text: String) -> Wallet? {
        activeWallets.first { text.contains(normalized($0.name)) }
    }

    private func guessedCategory(for text: String) -> String {
        if let exact = matchingCategory(in: text) { return exact }
        let rules: [(String, [String])] = [
            ("Cibo", ["pizza", "ristor", "pranzo", "cena", "bar", "caffe", "supermercato", "spesa"]),
            ("Trasporti", ["benzina", "treno", "bus", "taxi", "uber", "parcheggio", "autostrada"]),
            ("Svago", ["cinema", "concerto", "gioco", "aperitivo", "serata"]),
            ("Shopping", ["vestiti", "scarpe", "amazon", "shopping"]),
            ("Casa", ["affitto", "bolletta", "luce", "gas", "internet"])
        ]
        for (category, words) in rules where words.contains(where: { text.contains($0) }) { return category }
        return categories.first(where: { !$0.isArchived && $0.type == .expense })?.name ?? "Altro"
    }

    private func guessedIncomeCategory(for text: String) -> String {
        let incomeNames = categories.filter { !$0.isArchived && $0.type == .income }.map(\.name)
        if let exact = incomeNames.first(where: { text.contains(normalized($0)) }) { return exact }
        if text.contains("stipend") { return incomeNames.first(where: { normalized($0).contains("stipend") }) ?? "Stipendio" }
        return incomeNames.first ?? "Entrate"
    }

    private func extractAmount(from text: String) -> Decimal? {
        let pattern = #"(?:€\s*)?(\d+(?:[\.,]\d{1,2})?)(?:\s*(?:€|euro|eur))"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Decimal(string: String(text[range]).replacingOccurrences(of: ",", with: "."))
    }

    private func extractHour(from text: String) -> (hour: Int, minute: Int)? {
        let pattern = #"(?:alle|ore)\s+(\d{1,2})(?:(?::|\.)?(\d{2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let hour = Int(text[hourRange]),
              (0...23).contains(hour) else { return nil }
        var minute = 0
        if match.range(at: 2).location != NSNotFound,
           let minuteRange = Range(match.range(at: 2), in: text) {
            minute = Int(text[minuteRange]) ?? 0
        }
        guard (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    private func extractDate(from text: String) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        if text.contains("ieri") { return calendar.date(byAdding: .day, value: -1, to: today) }
        if text.contains("domani") { return calendar.date(byAdding: .day, value: 1, to: today) }
        if text.contains("dopodomani") { return calendar.date(byAdding: .day, value: 2, to: today) }
        if text.contains("oggi") { return today }

        let weekdays: [(String, Int)] = [("domenica", 1), ("lunedi", 2), ("martedi", 3), ("mercoledi", 4), ("giovedi", 5), ("venerdi", 6), ("sabato", 7)]
        for (name, weekday) in weekdays where text.contains(name) {
            let current = calendar.component(.weekday, from: today)
            var delta = weekday - current
            if delta <= 0 { delta += 7 }
            return calendar.date(byAdding: .day, value: delta, to: today)
        }
        return nil
    }

    private func isAgendaCommand(_ text: String) -> Bool {
        containsAny(text, ["ricordami", "aggiungi in agenda", "metti in agenda", "appuntamento", "impegno", "promemoria"]) || (extractHour(from: text) != nil && extractDate(from: text) != nil && !containsAny(text, ["euro", "€", "eur"]))
    }

    private func isQuestionAboutAmount(_ text: String) -> Bool {
        containsAny(text, ["quanto", "speso", "spese", "guadagnato", "patrimonio", "posso spendere", "posso permettermi", "budget", "manca"])
    }

    private func cleanedTransactionTitle(_ input: String) -> String {
        var value = input
        if let regex = try? NSRegularExpression(pattern: #"(?:€\s*)?\d+(?:[\.,]\d{1,2})?\s*(?:€|euro|eur)"#, options: [.caseInsensitive]) {
            value = regex.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: "")
        }
        let removable = ["oggi", "ieri", "domani", "ho speso", "spesa", "registra", "aggiungi", "entrata", "ho ricevuto"]
        for word in removable { value = value.replacingOccurrences(of: word, with: "", options: [.caseInsensitive]) }
        if let wallet = matchingWallet(in: normalized(value)) {
            value = value.replacingOccurrences(of: wallet.name, with: "", options: [.caseInsensitive])
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).capitalized
    }

    private func cleanedAgendaTitle(_ input: String) -> String {
        var value = normalized(input)
        let removable = ["aggiungi in agenda", "metti in agenda", "aggiungi", "ricordami di", "ricordami", "promemoria", "appuntamento", "impegno", "domani", "dopodomani", "oggi", "ieri", "lunedi", "martedi", "mercoledi", "giovedi", "venerdi", "sabato", "domenica"]
        for word in removable { value = value.replacingOccurrences(of: word, with: "") }
        if let regex = try? NSRegularExpression(pattern: #"(?:alle|ore)\s+\d{1,2}(?:(?::|\.)?\d{2})?"#) {
            value = regex.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: "")
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).capitalized
    }

    private func personAfterPreposition(in input: String) -> String {
        let normalizedInput = normalized(input)
        let pattern = #"(?:\sa\s|\sad\s)([a-zà-ÿ]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalizedInput, range: NSRange(normalizedInput.startIndex..., in: normalizedInput)),
              let range = Range(match.range(at: 1), in: normalizedInput) else { return "" }
        return String(normalizedInput[range]).capitalized
    }

    private func personName(from input: String, around marker: String) -> String {
        let q = normalized(input)
        guard let range = q.range(of: marker) else { return "" }
        let before = q[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let after = q[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        if !before.isEmpty, let last = before.split(separator: " ").last { return String(last).capitalized }
        if !after.isEmpty, let first = after.split(separator: " ").first { return String(first).capitalized }
        return ""
    }
}

private struct AssistantMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

private struct PendingAssistantAction: Identifiable {
    enum Kind {
        case transaction(type: TransactionType, title: String, amount: Decimal, category: String, wallet: Wallet, date: Date)
        case agenda(title: String, date: Date, hasTime: Bool)
        case relationship(person: String, amount: Decimal, type: RelationshipType)
    }

    let id = UUID()
    let kind: Kind

    var summary: String {
        switch kind {
        case let .transaction(type, title, amount, category, wallet, date):
            let label = type == .income ? "entrata" : "spesa"
            return "Registra una \(label): \(title), \(amount.formatted(.currency(code: wallet.currencyCode))), categoria \(category), portafoglio \(wallet.name), data \(date.formatted(date: .abbreviated, time: .omitted))."
        case let .agenda(title, date, hasTime):
            return "Aggiungi in Agenda \(title) per \(date.formatted(date: .abbreviated, time: hasTime ? .shortened : .omitted))."
        case let .relationship(person, amount, type):
            return type == .debt ? "Registra un debito di \(amount.formatted(.currency(code: "EUR"))) verso \(person)." : "Registra un credito di \(amount.formatted(.currency(code: "EUR"))) verso \(person)."
        }
    }
}
