import Foundation
import SwiftData

@Model
final class FinanceCategory {
    var id: UUID
    var name: String
    var typeRawValue: String
    var icon: String
    var isArchived: Bool

    init(name: String, type: TransactionType, icon: String = "tag", isArchived: Bool = false) {
        self.id = UUID()
        self.name = name
        self.typeRawValue = type.rawValue
        self.icon = icon
        self.isArchived = isArchived
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }
}
