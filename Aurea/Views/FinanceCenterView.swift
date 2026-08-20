import SwiftUI
import SwiftData

struct FinanceCenterView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Pianificazione") {
                    NavigationLink {
                        BudgetsView()
                    } label: {
                        Label("Budget", systemImage: "gauge.with.dots.needle.50percent")
                    }

                    NavigationLink {
                        RecurringTransactionsView()
                    } label: {
                        Label("Movimenti ricorrenti", systemImage: "repeat")
                    }
                }

                Section("Analisi") {
                    NavigationLink {
                        FinanceStatisticsView()
                    } label: {
                        Label("Statistiche", systemImage: "chart.bar.xaxis")
                    }
                }

                Section("Organizzazione") {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("Categorie", systemImage: "tag")
                    }

                    NavigationLink {
                        CurrencySettingsView()
                    } label: {
                        Label("Valute e cambi", systemImage: "eurosign.arrow.circlepath")
                    }
                }
            }
            .navigationTitle("Finanza")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}

private struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]
    @State private var showingAdd = false

    var body: some View {
        List {
            ForEach([TransactionType.expense, .income], id: \.rawValue) { type in
                Section(type == .expense ? "Spese" : "Entrate") {
                    let matching = categories.filter { $0.type == type && !$0.isArchived }
                    if matching.isEmpty {
                        Text("Nessuna categoria personalizzata")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matching) { category in
                            HStack {
                                Label(category.name, systemImage: category.icon)
                                Spacer()
                                Button {
                                    category.isArchived = true
                                } label: {
                                    Image(systemName: "archivebox")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Categorie")
        .toolbar {
            Button {
                showingAdd = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddCategoryView()
        }
    }
}

private struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var type: TransactionType = .expense
    @State private var icon = "tag"

    private let icons = ["tag", "fork.knife", "car", "house", "cart", "heart", "gamecontroller", "gift", "briefcase", "banknote"]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $type) {
                    Text("Spesa").tag(TransactionType.expense)
                    Text("Entrata").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)

                TextField("Nome", text: $name)

                Picker("Icona", selection: $icon) {
                    ForEach(icons, id: \.self) { value in
                        Label(value, systemImage: value).tag(value)
                    }
                }
            }
            .navigationTitle("Nuova categoria")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        modelContext.insert(FinanceCategory(name: name.trimmingCharacters(in: .whitespacesAndNewlines), type: type, icon: icon))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct BudgetsView: View {
    @Query(sort: \Budget.createdAt, order: .reverse) private var budgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAdd = false

    var body: some View {
        List {
            if budgets.filter({ !$0.isArchived }).isEmpty {
                Text("Nessun budget attivo")
                    .foregroundStyle(.secondary)
            }

            ForEach(budgets.filter { !$0.isArchived }) { budget in
                let spent = FinancialEngine.spentThisMonth(for: budget, transactions: transactions)
                let ratio = NSDecimalNumber(decimal: budget.monthlyLimit > 0 ? spent / budget.monthlyLimit : 0).doubleValue

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(budget.title).fontWeight(.semibold)
                            Text(budget.category ?? "Tutte le spese")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(spent.formatted(.currency(code: "EUR"))) / \(budget.monthlyLimit.formatted(.currency(code: "EUR")))")
                            .font(.caption)
                    }

                    ProgressView(value: min(max(ratio, 0), 1))
                        .tint(ratio > 1 ? .red : nil)

                    if ratio >= 0.8 {
                        Text(ratio > 1 ? "Budget superato" : "Sei vicino al limite")
                            .font(.caption)
                            .foregroundStyle(ratio > 1 ? .red : .orange)
                    }
                }
                .swipeActions {
                    Button("Archivia") { budget.isArchived = true }
                        .tint(.orange)
                }
            }
        }
        .navigationTitle("Budget")
        .toolbar {
            Button { showingAdd = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingAdd) { AddBudgetView() }
    }
}

private struct AddBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]

    @State private var title = ""
    @State private var amount = ""
    @State private var selectedCategory = ""

    private var parsedAmount: Decimal? { Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome budget", text: $title)
                TextField("Limite mensile", text: $amount).keyboardType(.decimalPad)
                Picker("Categoria", selection: $selectedCategory) {
                    Text("Tutte le spese").tag("")
                    ForEach(categories.filter { $0.type == .expense && !$0.isArchived }) { category in
                        Text(category.name).tag(category.name)
                    }
                }
            }
            .navigationTitle("Nuovo budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard let parsedAmount, parsedAmount > 0 else { return }
                        modelContext.insert(Budget(title: title.trimmingCharacters(in: .whitespacesAndNewlines), category: selectedCategory.isEmpty ? nil : selectedCategory, monthlyLimit: parsedAmount))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (parsedAmount ?? 0) <= 0)
                }
            }
        }
    }
}

private struct FinanceStatisticsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    private var thisMonth: [Transaction] {
        transactions.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }

    private var lastMonth: [Transaction] {
        guard let date = Calendar.current.date(byAdding: .month, value: -1, to: .now) else { return [] }
        return transactions.filter { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .month) }
    }

    private var categoryTotals: [(String, Decimal)] {
        let expenses = thisMonth.filter { $0.type == .expense && $0.category != "Trasferimento" }
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped.map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }.sorted { $0.1 > $1.1 }
    }

    var body: some View {
        List {
            Section("Questo mese") {
                metric("Entrate", FinancialEngine.totalIncome(from: thisMonth))
                metric("Spese", FinancialEngine.totalExpenses(from: thisMonth))
                metric("Flusso netto", FinancialEngine.cashFlow(from: thisMonth))
            }

            Section("Confronto con il mese scorso") {
                metric("Spese mese scorso", FinancialEngine.totalExpenses(from: lastMonth))
                let delta = FinancialEngine.totalExpenses(from: thisMonth) - FinancialEngine.totalExpenses(from: lastMonth)
                LabeledContent("Differenza spese", value: delta.formatted(.currency(code: "EUR")))
            }

            Section("Spese per categoria") {
                if categoryTotals.isEmpty {
                    Text("Nessuna spesa questo mese").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(categoryTotals.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.0)
                            Spacer()
                            Text(item.1, format: .currency(code: "EUR"))
                        }
                    }
                }
            }
        }
        .navigationTitle("Statistiche")
    }

    private func metric(_ title: String, _ value: Decimal) -> some View {
        LabeledContent(title, value: value.formatted(.currency(code: "EUR")))
    }
}

private struct RecurringTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringTransaction.nextDate) private var recurring: [RecurringTransaction]
    @State private var showingAdd = false

    var body: some View {
        List {
            Section {
                Button {
                    generateDueTransactions()
                } label: {
                    Label("Registra movimenti dovuti", systemImage: "arrow.clockwise")
                }
            } footer: {
                Text("Crea i movimenti ricorrenti con scadenza fino a oggi e aggiorna automaticamente la prossima data.")
            }

            ForEach(recurring) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.title).fontWeight(.semibold)
                        Spacer()
                        Text(item.amount, format: .currency(code: item.wallet?.currencyCode ?? "EUR"))
                    }
                    Text("\(item.frequency.title) • prossima: \(item.nextDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .opacity(item.isActive ? 1 : 0.5)
                .swipeActions {
                    Button(item.isActive ? "Pausa" : "Riprendi") { item.isActive.toggle() }
                        .tint(.orange)
                    Button("Elimina", role: .destructive) { modelContext.delete(item) }
                }
            }
        }
        .navigationTitle("Ricorrenti")
        .toolbar { Button { showingAdd = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showingAdd) { AddRecurringView() }
    }

    private func generateDueTransactions() {
        let now = Date()
        for item in recurring where item.isActive && item.nextDate <= now {
            guard let wallet = item.wallet else { continue }
            var date = item.nextDate
            while date <= now {
                modelContext.insert(Transaction(type: item.type, amount: item.amount, date: date, category: item.category, title: item.title, wallet: wallet))
                date = item.frequency.nextDate(after: date)
            }
            item.nextDate = date
        }
    }
}

private struct AddRecurringView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]

    @State private var title = ""
    @State private var amount = ""
    @State private var category = ""
    @State private var type: TransactionType = .expense
    @State private var frequency: RecurringFrequency = .monthly
    @State private var nextDate = Date()
    @State private var wallet: Wallet?

    private var parsedAmount: Decimal? { Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $type) {
                    Text("Spesa").tag(TransactionType.expense)
                    Text("Entrata").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                TextField("Titolo", text: $title)
                TextField("Importo", text: $amount).keyboardType(.decimalPad)
                TextField("Categoria", text: $category)
                Picker("Frequenza", selection: $frequency) {
                    ForEach(RecurringFrequency.allCases) { value in Text(value.title).tag(value) }
                }
                DatePicker("Prossima data", selection: $nextDate, displayedComponents: .date)
                Picker("Portafoglio", selection: $wallet) {
                    Text("Seleziona").tag(nil as Wallet?)
                    ForEach(wallets.filter { !$0.isArchived }) { value in Text(value.name).tag(value as Wallet?) }
                }
            }
            .navigationTitle("Nuovo ricorrente")
            .onAppear { wallet = wallet ?? wallets.first(where: { !$0.isArchived }) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard let parsedAmount, let wallet else { return }
                        modelContext.insert(RecurringTransaction(title: title.trimmingCharacters(in: .whitespacesAndNewlines), amount: parsedAmount, category: category.trimmingCharacters(in: .whitespacesAndNewlines), type: type, frequency: frequency, nextDate: nextDate, wallet: wallet))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (parsedAmount ?? 0) <= 0 || wallet == nil)
                }
            }
        }
    }
}

private struct CurrencySettingsView: View {
    @Query private var wallets: [Wallet]

    var body: some View {
        List {
            Section {
                Text("Il patrimonio principale è espresso in EUR. Per portafogli in altre valute inserisci manualmente quanti euro vale 1 unità della valuta.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(wallets) { wallet in
                CurrencyRateRow(wallet: wallet)
            }
        }
        .navigationTitle("Valute e cambi")
    }
}

private struct CurrencyRateRow: View {
    let wallet: Wallet
    @State private var rateText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(wallet.name, systemImage: wallet.icon)
                Spacer()
                Text(wallet.currencyCode).foregroundStyle(.secondary)
            }

            if wallet.currencyCode == "EUR" {
                Text("1 EUR = 1 EUR").font(.caption).foregroundStyle(.secondary)
            } else {
                TextField("Valore in EUR di 1 \(wallet.currencyCode)", text: $rateText)
                    .keyboardType(.decimalPad)
                    .onSubmit { save() }
                Button("Salva cambio") { save() }
                    .font(.caption)
            }
        }
        .onAppear {
            if let rate = wallet.exchangeRateToEUR {
                rateText = NSDecimalNumber(decimal: rate).stringValue
            }
        }
    }

    private func save() {
        if let value = Decimal(string: rateText.replacingOccurrences(of: ",", with: ".")), value > 0 {
            wallet.exchangeRateToEUR = value
        }
    }
}
