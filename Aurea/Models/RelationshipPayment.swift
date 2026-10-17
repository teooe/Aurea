import Foundation
import SwiftData

@Model
final class RelationshipPayment {
    var id: UUID = UUID()
    var relationshipID: UUID = UUID()
    var amount: Decimal = 0
    var date: Date = Date.now

    init(relationshipID: UUID, amount: Decimal, date: Date = .now) {
        self.id = UUID()
        self.relationshipID = relationshipID
        self.amount = amount
        self.date = date
    }
}
