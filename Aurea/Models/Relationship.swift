import Foundation
import SwiftData

@Model
final class Relationship {
    var id: UUID
    var personName: String
    var amount: Decimal
    var typeRawValue: String
    var note: String
    var createdAt: Date
    var isClosed: Bool
    var dueDate: Date?
    var paidAmount: Decimal?

    init(
        personName: String,
        amount: Decimal,
        type: RelationshipType,
        note: String = "",
        createdAt: Date = Date(),
        isClosed: Bool = false,
        dueDate: Date? = nil,
        paidAmount: Decimal? = nil
    ) {
        self.id = UUID()
        self.personName = personName
        self.amount = amount
        self.typeRawValue = type.rawValue
        self.note = note
        self.createdAt = createdAt
        self.isClosed = isClosed
        self.dueDate = dueDate
        self.paidAmount = paidAmount
    }

    var type: RelationshipType {
        get { RelationshipType(rawValue: typeRawValue) ?? .debt }
        set { typeRawValue = newValue.rawValue }
    }

    var repaid: Decimal { paidAmount ?? 0 }
    var remainingAmount: Decimal { max(amount - repaid, 0) }
}

enum RelationshipType: String, Codable, CaseIterable {
    case debt
    case credit
}
