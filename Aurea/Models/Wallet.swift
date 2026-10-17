import Foundation
import SwiftData

@Model
final class Wallet {
    var name: String = ""
    var icon: String = ""
    var currencyCode: String = "EUR"
    var initialBalance: Decimal = 0
    var exchangeRateToEUR: Decimal?
    var archivedFlag: Bool?

    // Relazioni opzionali e con inverso: è ciò che richiede la sincronizzazione iCloud (CloudKit).
    @Relationship(deleteRule: .cascade, inverse: \Transaction.wallet)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Goal.linkedWallet)
    var linkedGoals: [Goal]? = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.wallet)
    var recurringTransactions: [RecurringTransaction]? = []

    init(
        name: String,
        icon: String,
        currencyCode: String = "EUR",
        initialBalance: Decimal = 0,
        exchangeRateToEUR: Decimal? = nil,
        isArchived: Bool = false
    ) {
        self.name = name
        self.icon = icon
        self.currencyCode = currencyCode
        self.initialBalance = initialBalance
        self.exchangeRateToEUR = exchangeRateToEUR
        self.archivedFlag = isArchived
    }

    var isArchived: Bool {
        get { archivedFlag ?? false }
        set { archivedFlag = newValue }
    }

    /// Identità esplicita per `ForEach` e liste. Senza, con Xcode 26 e l'isolamento su MainActor
    /// il compilatore non trova l'`id` di `Identifiable` (gli altri modelli hanno `var id: UUID`).
    /// È calcolata, quindi non viene salvata e non cambia lo schema del database.
    var id: ObjectIdentifier { ObjectIdentifier(self) }

    var effectiveExchangeRateToEUR: Decimal {
        if currencyCode == "EUR" { return 1 }
        return exchangeRateToEUR ?? 1
    }
}
