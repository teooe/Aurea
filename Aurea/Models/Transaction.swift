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

    static var transferCategory: String { "Trasferimento" }

    /// Movimento che fa parte di un trasferimento tra portafogli: non conta come entrata o spesa.
    /// Il controllo sulla categoria copre i trasferimenti salvati prima di `transferGroupID`.
    var isTransfer: Bool {
        transferGroupID != nil || type == .transfer || category == Transaction.transferCategory
    }

    /// La categoria dei trasferimenti è riservata: usarla su un movimento normale lo escluderebbe dai totali.
    static func isReservedCategory(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(transferCategory) == .orderedSame
    }
}
