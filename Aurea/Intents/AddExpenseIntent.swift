import AppIntents
import Foundation
import SwiftData

/// "Registra una spesa su Aurea": Siri chiede importo e categoria, poi salva senza aprire l'app.
nonisolated struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Registra spesa"
    static let description = IntentDescription("Registra una spesa in Aurea senza aprire l'app.")
    /// Con il telefono bloccato Siri chiede prima di sbloccarlo: nessuno può registrare spese al posto tuo.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Importo", requestValueDialog: "Quanto hai speso?")
    var amount: Double

    @Parameter(title: "Categoria", requestValueDialog: "In quale categoria?", optionsProvider: ExpenseCategoryOptions())
    var category: String

    @Parameter(title: "Descrizione")
    var note: String?

    @Parameter(title: "Portafoglio", optionsProvider: WalletOptions())
    var wallet: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Registra \(\.$amount) in \(\.$category)") {
            \.$note
            \.$wallet
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AureaStore.container.mainContext
        let value = IntentAmount.decimal(from: amount)
        guard value > 0 else {
            throw IntentError.message("L'importo deve essere maggiore di zero.")
        }

        let wallets = try context.fetch(FetchDescriptor<Wallet>()).filter { !$0.isArchived }
        guard let selectedWallet = IntentAmount.wallet(named: wallet, in: wallets) else {
            throw IntentError.message(wallets.isEmpty
                ? "Non hai ancora un portafoglio: aprine uno in Aurea."
                : "Non trovo il portafoglio \(wallet ?? "").")
        }

        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCategory.isEmpty, !Transaction.isReservedCategory(trimmedCategory) else {
            throw IntentError.message("Scegli una categoria di spesa valida.")
        }

        let resolvedCategory = CategoryService.resolve(trimmedCategory, type: .expense, in: context)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = trimmedNote.isEmpty ? resolvedCategory : trimmedNote

        context.insert(Transaction(type: .expense, amount: value, category: resolvedCategory, title: title, wallet: selectedWallet))
        try context.save()
        WidgetSnapshotBuilder.refresh(in: context)

        let formatted = value.formatted(.currency(code: selectedWallet.currencyCode))
        return .result(dialog: "Registrata una spesa di \(formatted) in \(resolvedCategory).")
    }
}

/// "Quanto ho speso questo mese su Aurea".
nonisolated struct MonthSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Spese del mese"
    static let description = IntentDescription("Ti dice quanto hai speso e guadagnato questo mese.")
    /// La risposta rivela dati finanziari: a telefono bloccato serve prima lo sblocco.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AureaStore.container.mainContext
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let snapshot = WidgetSnapshotBuilder.make(transactions: transactions, budgets: budgets)

        let expenses = snapshot.monthExpenses.formatted(.currency(code: "EUR"))
        let income = snapshot.monthIncome.formatted(.currency(code: "EUR"))
        var text = "Questo mese hai speso \(expenses) e incassato \(income)."
        if let budget = snapshot.budgets.first, budget.ratio >= 0.8 {
            let percent = Int(budget.ratio * 100)
            text += budget.ratio >= 1
                ? " Hai superato il budget \(budget.title)."
                : " Il budget \(budget.title) è al \(percent)%."
        }
        return .result(dialog: "\(text)")
    }
}

/// Apre l'app direttamente sul modulo del nuovo movimento.
nonisolated struct OpenQuickAddIntent: AppIntent {
    static let title: LocalizedStringResource = "Nuovo movimento"
    static let description = IntentDescription("Apre Aurea sul modulo per registrare un movimento.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickAddRequest.shared.isPending = true
        return .result()
    }
}

nonisolated struct ExpenseCategoryOptions: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [String] {
        let context = AureaStore.container.mainContext
        return try context.fetch(FetchDescriptor<FinanceCategory>(sortBy: [SortDescriptor(\.name)]))
            .filter { $0.type == .expense && !$0.isArchived }
            .map(\.name)
    }
}

nonisolated struct WalletOptions: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [String] {
        let context = AureaStore.container.mainContext
        return try context.fetch(FetchDescriptor<Wallet>(sortBy: [SortDescriptor(\.name)]))
            .filter { !$0.isArchived }
            .map(\.name)
    }
}

nonisolated enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let text): LocalizedStringResource(stringLiteral: text)
        }
    }
}

/// Conversioni usate dagli intent, separate per poterle testare.
nonisolated enum IntentAmount {
    /// Siri passa un Double: lo riportiamo a un Decimal arrotondato al centesimo (12,3 e non 12,2999…).
    static func decimal(from value: Double) -> Decimal {
        var raw = Decimal(value)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 2, .plain)
        return rounded
    }

    /// Portafoglio scelto per nome (senza distinguere maiuscole), altrimenti il primo attivo.
    @MainActor
    static func wallet(named name: String?, in wallets: [Wallet]) -> Wallet? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return wallets.first
        }
        return wallets.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
