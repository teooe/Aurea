import Foundation
import SwiftData

@Model
final class Wallet {
    var name: String
    var icon: String
    var currencyCode: String
    var initialBalance: Decimal
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.wallet)
    var transactions: [Transaction] = []

    init(
        name: String,
        icon: String,
        currencyCode: String = "EUR",
        initialBalance: Decimal = 0
    ) {
        self.name = name
        self.icon = icon
        self.currencyCode = currencyCode
        self.initialBalance = initialBalance
    }
    
}
