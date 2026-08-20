import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID
    var title: String
    var category: String?
    var monthlyLimit: Decimal
    var createdAt: Date
    var isArchived: Bool

    init(title: String, category: String? = nil, monthlyLimit: Decimal, createdAt: Date = .now, isArchived: Bool = false) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}
