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
                        ReportsView()
                    } label: {
                        Label("Report", systemImage: "chart.bar.xaxis")
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
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]
    @Query private var transactions: [Transaction]
    @State private var showingAdd = false
    @State private var editingCategory: FinanceCategory?

    private var archived: [FinanceCategory] { categories.filter(\.isArchived) }

    var body: some View {
        List {
            ForEach([TransactionType.expense, .income], id: \.rawValue) { type in
                Section(type == .expense ? "Spese" : "Entrate") {
                    let matching = categories.filter { $0.type == type && !$0.isArchived }
                    if matching.isEmpty {
                        Text("Nessuna categoria")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matching) { category in
                            categoryRow(category)
                                .swipeActions {
                                    Button("Archivia") { category.isArchived = true }
                                        .tint(.orange)
                                }
                        }
                    }
                }
            }

            if !archived.isEmpty {
                Section {
                    ForEach(archived) { category in
                        categoryRow(category)
                            .opacity(0.6)
                            .swipeActions {
                                Button("Ripristina") { category.isArchived = false }
                                    .tint(.green)
                            }
                    }
                } header: {
                    Text("Archiviate")
                } footer: {
                    Text("Le categorie archiviate non compaiono più tra i suggerimenti, ma i movimenti già registrati le mantengono.")
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
        .sheet(isPresented: $showingAdd) { CategoryEditorView(category: nil) }
        .sheet(item: $editingCategory) { CategoryEditorView(category: $0) }
    }

    private func categoryRow(_ category: FinanceCategory) -> some View {
        Button {
            editingCategory = category
        } label: {
            HStack {
                Label(category.name, systemImage: category.icon)
                Spacer()
                let count = CategoryService.usageCount(of: category, in: transactions)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Crea una categoria o, se `category` è valorizzata, la modifica.
/// Rinominare aggiorna anche i movimenti, i ricorrenti e i budget che la usano.
private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [FinanceCategory]
    @Query private var transactions: [Transaction]

    let category: FinanceCategory?

    @State private var name: String
    @State private var type: TransactionType
    @State private var icon: String

    private let icons = ["tag", "cart", "fork.knife", "car", "house", "bag", "heart", "gamecontroller", "gift", "briefcase", "banknote", "airplane", "graduationcap", "pawprint", "wrench.and.screwdriver", "arrow.uturn.backward"]

    init(category: FinanceCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _type = State(initialValue: category?.type ?? .expense)
        _icon = State(initialValue: category?.icon ?? "tag")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Un'altra categoria dello stesso tipo con questo nome.
    private var duplicate: FinanceCategory? {
        CategoryService.find(trimmedName, type: type, in: categories.filter { $0 !== category })
    }

    private var usageCount: Int {
        category.map { CategoryService.usageCount(of: $0, in: transactions) } ?? 0
    }

    private var canSave: Bool {
        guard !trimmedName.isEmpty, !Transaction.isReservedCategory(trimmedName) else { return false }
        // In creazione un doppione non ha senso; in modifica diventa un'unione.
        return category != nil || duplicate == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if category == nil {
                    Picker("Tipo", selection: $type) {
                        Text("Spesa").tag(TransactionType.expense)
                        Text("Entrata").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("Nome", text: $name)
                } footer: {
                    if Transaction.isReservedCategory(trimmedName) {
                        Text("“\(Transaction.transferCategory)” è riservata ai trasferimenti.")
                            .foregroundStyle(.red)
                    } else if let duplicate {
                        Text(category == nil
                             ? "Esiste già la categoria “\(duplicate.name)”."
                             : "Salvando, questa categoria verrà unita a “\(duplicate.name)”.")
                    } else if category != nil && usageCount > 0 {
                        Text("Il nuovo nome verrà applicato anche a \(usageCount) \(usageCount == 1 ? "movimento" : "movimenti").")
                    }
                }

                Section("Icona") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(icons, id: \.self) { value in
                            Button {
                                icon = value
                            } label: {
                                Image(systemName: value)
                                    .frame(width: 40, height: 40)
                                    .background(icon == value ? Color.accentColor.opacity(0.2) : Color.clear, in: Circle())
                                    .foregroundStyle(icon == value ? Color.accentColor : Color.primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(value)
                            .accessibilityAddTraits(icon == value ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "Nuova categoria" : "Modifica categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        if let category {
            category.icon = icon
            if trimmedName != category.name {
                try? CategoryService.rename(category, to: trimmedName, in: modelContext)
            }
        } else {
            modelContext.insert(FinanceCategory(name: trimmedName, type: type, icon: icon))
        }
        dismiss()
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
                Text("I movimenti ricorrenti vengono registrati automaticamente all'apertura dell'app. Usa questo pulsante per farlo subito.")
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
        RecurringEngine.generateDueTransactions(from: recurring, in: modelContext)
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
                        let resolvedCategory = CategoryService.resolve(category, type: type, in: modelContext)
                        modelContext.insert(RecurringTransaction(title: title.trimmingCharacters(in: .whitespacesAndNewlines), amount: parsedAmount, category: resolvedCategory, type: type, frequency: frequency, nextDate: nextDate, wallet: wallet))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Transaction.isReservedCategory(category) || (parsedAmount ?? 0) <= 0 || wallet == nil)
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
