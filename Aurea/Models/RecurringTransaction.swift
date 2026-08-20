import Foundation
import SwiftData

@Model
final class RecurringTransaction {
    var id: UUID
    var title: String
    var amount: Decimal
    var category: String
    var typeRawValue: String
    var frequencyRawValue: String
    var nextDate: Date
    var isActive: Bool
    var wallet: Wallet?

    init(title: String, amount: Decimal, category: String, type: TransactionType, frequency: RecurringFrequency, nextDate: Date, wallet: Wallet? = nil, isActive: Bool = true) {
        self.id = UUID()
        self.title = title
        self.amount = amount
        self.category = category
        self.typeRawValue = type.rawValue
        self.frequencyRawValue = frequency.rawValue
        self.nextDate = nextDate
        self.wallet = wallet
        self.isActive = isActive
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRawValue) ?? .expense }
        set { typeRawValue = newValue.rawValue }
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRawValue) ?? .monthly }
        set { frequencyRawValue = newValue.rawValue }
    }
}

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, monthly, yearly
    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Settimanale"
        case .monthly: "Mensile"
        case .yearly: "Annuale"
        }
    }

    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}
