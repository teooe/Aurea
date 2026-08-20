import Foundation
import SwiftData

@Model
final class RelationshipPayment {
    var id: UUID
    var relationshipID: UUID
    var amount: Decimal
    var date: Date

    init(relationshipID: UUID, amount: Decimal, date: Date = .now) {
        self.id = UUID()
        self.relationshipID = relationshipID
        self.amount = amount
        self.date = date
    }
}
