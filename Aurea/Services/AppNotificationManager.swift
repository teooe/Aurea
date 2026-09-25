import Foundation
import UserNotifications
import SwiftData

enum AppNotificationManager {
    static let relationshipKey = "aurea.notifications.relationships"
    static let recurringKey = "aurea.notifications.recurring"
    static let budgetKey = "aurea.notifications.budgets"
    static let dailyReminderKey = "aurea.notifications.dailyReminder"
    /// Minuti dalla mezzanotte (21:00 = 1260).
    static let dailyReminderMinutesKey = "aurea.notifications.dailyReminderMinutes"
    static let defaultDailyReminderMinutes = 21 * 60
    /// Quanti giorni di promemoria programmare in anticipo; vengono riprogrammati a ogni apertura.
    static let dailyReminderHorizon = 14

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func refresh(relationships: [Relationship], recurring: [RecurringTransaction], budgets: [Budget], transactions: [Transaction]) {
        requestAuthorization()
        scheduleRelationships(relationships)
        scheduleRecurring(recurring)
        evaluateBudgets(budgets, transactions: transactions)
        scheduleDailyReminders(transactions: transactions)
    }

    // MARK: - Promemoria giornaliero

    /// Promemoria singoli per i prossimi giorni invece di uno ripetuto: così quello di oggi
    /// si può saltare se hai già registrato un movimento.
    private static func scheduleDailyReminders(transactions: [Transaction]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<dailyReminderHorizon).map { "daily-\($0)" })
        guard UserDefaults.standard.bool(forKey: dailyReminderKey) else { return }

        let minutes = UserDefaults.standard.object(forKey: dailyReminderMinutesKey) as? Int ?? defaultDailyReminderMinutes
        let loggedToday = transactions.contains { Calendar.current.isDateInToday($0.date) }
        let dates = dailyReminderDates(now: .now, minutesAfterMidnight: minutes, loggedToday: loggedToday)

        for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Hai registrato le spese di oggi?"
            content.body = "Bastano pochi secondi: apri Aurea e tocca +."
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            center.add(UNNotificationRequest(identifier: "daily-\(index)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
        }
    }

    /// Orari dei promemoria nei prossimi giorni: esclude quelli già passati e oggi se c'è già un movimento.
    static func dailyReminderDates(now: Date, minutesAfterMidnight: Int, loggedToday: Bool, days: Int = dailyReminderHorizon, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let hour = min(max(minutesAfterMidnight / 60, 0), 23)
        let minute = min(max(minutesAfterMidnight % 60, 0), 59)
        return (0..<days).compactMap { offset in
            if offset == 0 && loggedToday { return nil }
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { return nil }
            return fire
        }
    }

    private static func scheduleRelationships(_ relationships: [Relationship]) {
        let center = UNUserNotificationCenter.current()
        let ids = relationships.map { "relationship-\($0.id.uuidString)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard UserDefaults.standard.object(forKey: relationshipKey) as? Bool ?? true else { return }

        for item in relationships where !item.isClosed && item.remainingAmount > 0 {
            guard let due = item.dueDate else { continue }
            let fire = Calendar.current.date(byAdding: .day, value: -1, to: due) ?? due
            guard fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = item.type == .debt ? "Debito in scadenza" : "Credito in scadenza"
            content.body = "\(item.personName): \(item.remainingAmount.formatted(.currency(code: "EUR")))"
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: fire) ?? fire)
            center.add(UNNotificationRequest(identifier: "relationship-\(item.id.uuidString)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    private static func scheduleRecurring(_ recurring: [RecurringTransaction]) {
        let center = UNUserNotificationCenter.current()
        let ids = recurring.map { "recurring-\($0.id.uuidString)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard UserDefaults.standard.object(forKey: recurringKey) as? Bool ?? true else { return }

        for item in recurring where item.isActive {
            let fire = Calendar.current.date(byAdding: .day, value: -1, to: item.nextDate) ?? item.nextDate
            guard fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Movimento ricorrente in arrivo"
            content.body = "\(item.title): \(item.amount.formatted(.currency(code: item.wallet?.currencyCode ?? "EUR")))"
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: fire) ?? fire)
            center.add(UNNotificationRequest(identifier: "recurring-\(item.id.uuidString)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    private static func evaluateBudgets(_ budgets: [Budget], transactions: [Transaction]) {
        guard UserDefaults.standard.object(forKey: budgetKey) as? Bool ?? true else { return }
        let monthKey = Date().formatted(.dateTime.year().month())
        for budget in budgets where !budget.isArchived && budget.monthlyLimit > 0 {
            let spent = FinancialEngine.spentThisMonth(for: budget, transactions: transactions)
            let ratio = NSDecimalNumber(decimal: spent / budget.monthlyLimit).doubleValue
            guard ratio >= 0.8 else { continue }
            let level = ratio >= 1 ? "100" : "80"
            let memoryKey = "aurea.budget.alert.\(budget.id.uuidString).\(monthKey).\(level)"
            guard !UserDefaults.standard.bool(forKey: memoryKey) else { continue }
            UserDefaults.standard.set(true, forKey: memoryKey)
            let content = UNMutableNotificationContent()
            content.title = ratio >= 1 ? "Budget superato" : "Budget quasi esaurito"
            content.body = "\(budget.title): \(spent.formatted(.currency(code: "EUR"))) su \(budget.monthlyLimit.formatted(.currency(code: "EUR")))"
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "budget-\(budget.id.uuidString)-\(level)", content: content, trigger: nil))
        }
    }
}
