import Foundation
import SwiftData

enum TransactionType: String, Codable {
    case expense
    case income
    case transfer
}

@Model
final class Transaction {
    var id: UUID
    var type: TransactionType
    var amount: Decimal
    var date: Date
    var category: String
    var title: String
    var transferGroupID: UUID?

    var wallet: Wallet?

    init(
        type: TransactionType,
        amount: Decimal,
        date: Date = .now,
        category: String,
        title: String,
        wallet: Wallet? = nil,
        transferGroupID: UUID? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.amount = amount
        self.date = date
        self.category = category
        self.title = title
        self.wallet = wallet
        self.transferGroupID = transferGroupID
    }
}
