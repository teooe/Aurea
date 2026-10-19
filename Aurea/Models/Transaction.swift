import Foundation
import SwiftData

enum TransactionType: String, Codable {
    case expense
    case income
    case transfer
}

@Model
final class Transaction {
    var id: UUID = UUID()
    var type: TransactionType = TransactionType.expense
    var amount: Decimal = 0
    var date: Date = Date.now
    var category: String = ""
    var title: String = ""
    var transferGroupID: UUID?
    /// Foto dello scontrino (JPEG ridotto). Salvata fuori dal database per non appesantirlo.
    @Attribute(.externalStorage) var receiptImageData: Data?
    /// Etichette libere (es. "Vacanza Sicilia"), separate da virgola. Raggruppano spese di categorie diverse.
    var tagsRaw: String?

    var wallet: Wallet?

    init(
        type: TransactionType,
        amount: Decimal,
        date: Date = .now,
        category: String,
        title: String,
        wallet: Wallet? = nil,
        transferGroupID: UUID? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.type = type
        self.amount = amount
        self.date = date
        self.category = category
        self.title = title
        self.wallet = wallet
        self.transferGroupID = transferGroupID
        self.tagsRaw = tags.isEmpty ? nil : tags.joined(separator: ", ")
    }

    static var transferCategory: String { "Trasferimento" }

    var tags: [String] {
        get { Transaction.parseTags(tagsRaw ?? "") }
        set { tagsRaw = newValue.isEmpty ? nil : newValue.joined(separator: ", ") }
    }

    /// "Vacanza, lavoro , vacanza" → ["Vacanza", "lavoro"]: senza vuoti né doppioni (maiuscole ignorate).
    static func parseTags(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

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
