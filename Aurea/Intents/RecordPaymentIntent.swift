import AppIntents
import Foundation
import SwiftData

/// Azione per l'automazione "Transazione" dell'app Comandi: dopo un pagamento con Apple Pay
/// iOS passa importo, esercente e carta, e Aurea registra la spesa da sola.
/// Le istruzioni per collegarla sono in Impostazioni → Spese da Apple Pay.
struct RecordPaymentIntent: AppIntent {
    static let title: LocalizedStringResource = "Registra pagamento Apple Pay"
    static let description = IntentDescription("Registra in Aurea un pagamento fatto con Apple Pay. Collegala all'automazione Transazione dell'app Comandi.")
    /// L'automazione parte subito dopo il pagamento, spesso a telefono bloccato. L'azione aggiunge
    /// soltanto una spesa e la sua risposta non mostra saldi né altri dati.
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static let openAppWhenRun = false

    @Parameter(title: "Importo")
    var amount: String

    @Parameter(title: "Esercente")
    var merchant: String?

    @Parameter(title: "Carta")
    var card: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Registra \(\.$amount) pagati a \(\.$merchant)") {
            \.$card
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AureaStore.container.mainContext
        switch try PaymentRecorder.record(amountText: amount, merchant: merchant, card: card, in: context) {
        case .recorded(let transaction):
            WidgetSnapshotBuilder.refresh(in: context)
            let value = transaction.amount.formatted(.currency(code: transaction.wallet?.currencyCode ?? "EUR"))
            return .result(dialog: "Aurea: \(value) in \(transaction.category).")
        case .duplicate:
            return .result(dialog: "Aurea: pagamento già registrato.")
        }
    }
}

/// Logica dell'azione, separata per poterla provare nei test.
enum PaymentRecorder {
    /// Portafoglio su cui registrare i pagamenti quando il nome della carta non corrisponde a nessuno.
    static let defaultWalletKey = "aurea.applepay.wallet"

    enum Outcome {
        case recorded(Transaction)
        case duplicate
    }

    @MainActor
    static func record(
        amountText: String,
        merchant: String?,
        card: String?,
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) throws -> Outcome {
        guard let parsed = BankImport.amount(from: amountText), parsed != 0 else {
            throw IntentError.message("Importo non valido: \(amountText).")
        }
        let value = abs(parsed)
        let wallets = try context.fetch(FetchDescriptor<Wallet>()).filter { !$0.isArchived }
        guard let wallet = wallet(forCard: card, preferred: defaults.string(forKey: defaultWalletKey), in: wallets) else {
            throw IntentError.message("Non hai ancora un portafoglio: aprine uno in Aurea.")
        }

        let name = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = name.isEmpty ? "Pagamento Apple Pay" : name
        let history = try context.fetch(FetchDescriptor<Transaction>())

        // Un'automazione ripetuta per errore non deve registrare due volte lo stesso pagamento.
        let recent = now.addingTimeInterval(-120)
        if history.contains(where: { $0.type == .expense && $0.amount == value && $0.title == title && $0.date >= recent }) {
            return .duplicate
        }

        let guessed = CategoryGuesser(history: history).category(for: title, type: .expense)
        let category = CategoryService.resolve(guessed, type: .expense, in: context)
        let transaction = Transaction(type: .expense, amount: value, date: now, category: category, title: title, wallet: wallet)
        context.insert(transaction)
        try context.save()
        return .recorded(transaction)
    }

    /// Il portafoglio che si chiama come la carta, poi quello scelto in Impostazioni, poi il primo.
    @MainActor
    static func wallet(forCard card: String?, preferred: String?, in wallets: [Wallet]) -> Wallet? {
        if let card = card?.lowercased(), !card.isEmpty,
           let match = wallets.first(where: { card.contains($0.name.lowercased()) || $0.name.lowercased().contains(card) }) {
            return match
        }
        if let preferred, let match = wallets.first(where: { $0.name == preferred }) { return match }
        return wallets.first
    }
}
