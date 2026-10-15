import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID
    var title: String
    var category: String?
    /// Limite per periodo (il nome resta "monthly" per compatibilità con i dati già salvati).
    var monthlyLimit: Decimal
    var createdAt: Date
    var isArchived: Bool
    /// `nil` per i budget creati prima dei periodi: valgono come mensili.
    var periodRaw: String?
    /// Se attivo, il residuo non speso del periodo precedente si aggiunge al limite.
    var rolloverEnabled: Bool?

    init(title: String, category: String? = nil, monthlyLimit: Decimal, period: BudgetPeriod = .monthly, rollover: Bool = false, createdAt: Date = .now, isArchived: Bool = false) {
        self.id = UUID()
        self.title = title
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.periodRaw = period.rawValue
        self.rolloverEnabled = rollover
    }

    var period: BudgetPeriod {
        get { periodRaw.flatMap(BudgetPeriod.init(rawValue:)) ?? .monthly }
        set { periodRaw = newValue.rawValue }
    }

    var rollover: Bool {
        get { rolloverEnabled ?? false }
        set { rolloverEnabled = newValue }
    }

    var limit: Decimal { monthlyLimit }
}

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case monthly, weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: "Mensile"
        case .weekly: "Settimanale"
        }
    }

    /// "fine mese" / "fine settimana", per i testi.
    var endLabel: String {
        switch self {
        case .monthly: "fine mese"
        case .weekly: "fine settimana"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .monthly: .month
        case .weekly: .weekOfYear
        }
    }
}
