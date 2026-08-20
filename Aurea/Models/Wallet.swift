import Foundation
import SwiftData

@Model
final class Wallet {
    var name: String
    var icon: String
    var currencyCode: String
    var initialBalance: Decimal
    var exchangeRateToEUR: Decimal?
    var archivedFlag: Bool?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.wallet)
    var transactions: [Transaction] = []

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

    var effectiveExchangeRateToEUR: Decimal {
        if currencyCode == "EUR" { return 1 }
        return exchangeRateToEUR ?? 1
    }
}
