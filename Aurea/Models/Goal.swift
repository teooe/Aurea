import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var typeRawValue: String
    var targetAmount: Decimal?
    var currentAmount: Decimal
    var targetDate: Date?
    var createdAt: Date
    var isCompleted: Bool

    init(
        title: String,
        type: GoalType,
        targetAmount: Decimal? = nil,
        currentAmount: Decimal = .zero,
        targetDate: Date? = nil,
        createdAt: Date = Date(),
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.typeRawValue = type.rawValue
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.isCompleted = isCompleted
    }

    var type: GoalType {
        get { GoalType(rawValue: typeRawValue) ?? .economic }
        set { typeRawValue = newValue.rawValue }
    }
}

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case economic
    case temporal
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .economic: "Economico"
        case .temporal: "Temporale"
        case .both: "Entrambi"
        }
    }
}
