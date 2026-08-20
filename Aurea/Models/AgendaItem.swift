import Foundation
import SwiftData

enum AgendaItemType: String, Codable, CaseIterable, Identifiable {
    case task
    case event
    case deadline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task: return "Attività"
        case .event: return "Evento"
        case .deadline: return "Scadenza"
        }
    }

    var icon: String {
        switch self {
        case .task: return "checkmark.circle"
        case .event: return "calendar"
        case .deadline: return "exclamationmark.circle"
        }
    }
}

enum AgendaRepeat: String, Codable, CaseIterable, Identifiable {
    case never
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: return "Mai"
        case .daily: return "Ogni giorno"
        case .weekly: return "Ogni settimana"
        case .monthly: return "Ogni mese"
        case .yearly: return "Ogni anno"
        }
    }
}

@Model
final class AgendaItem {
    var title: String
    var note: String
    var type: AgendaItemType
    var date: Date
    var hasTime: Bool
    var endDate: Date?
    var isCompleted: Bool
    var repeatRule: AgendaRepeat
    var reminderMinutesBefore: Int?
    var createdAt: Date

    init(
        title: String,
        note: String = "",
        type: AgendaItemType = .task,
        date: Date = .now,
        hasTime: Bool = false,
        endDate: Date? = nil,
        isCompleted: Bool = false,
        repeatRule: AgendaRepeat = .never,
        reminderMinutesBefore: Int? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.note = note
        self.type = type
        self.date = date
        self.hasTime = hasTime
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.repeatRule = repeatRule
        self.reminderMinutesBefore = reminderMinutesBefore
        self.createdAt = createdAt
    }
}
