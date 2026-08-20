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

    init(
        personName: String,
        amount: Decimal,
        type: RelationshipType,
        note: String = "",
        createdAt: Date = Date(),
        isClosed: Bool = false
    ) {
        self.id = UUID()
        self.personName = personName
        self.amount = amount
        self.typeRawValue = type.rawValue
        self.note = note
        self.createdAt = createdAt
        self.isClosed = isClosed
    }

    var type: RelationshipType {
        get {
            RelationshipType(rawValue: typeRawValue) ?? .debt
        }
        set {
            typeRawValue = newValue.rawValue
        }
    }
}

enum RelationshipType: String, Codable, CaseIterable {
    case debt
    case credit
}
