import Foundation
import UserNotifications

enum AgendaNotificationManager {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule(for item: AgendaItem) {
        remove(for: item)

        guard let minutes = item.reminderMinutesBefore,
              item.hasTime else { return }

        requestAuthorization()

        let notificationDate: Date
        if minutes == 1 {
            notificationDate = item.date
        } else {
            notificationDate = item.date.addingTimeInterval(TimeInterval(-minutes * 60))
        }

        guard notificationDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = notificationBody(for: item)
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: notificationDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: item),
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    static func remove(for item: AgendaItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier(for: item)]
        )
    }

    private static func identifier(for item: AgendaItem) -> String {
        "agenda-\(item.persistentModelID.hashValue)"
    }

    private static func notificationBody(for item: AgendaItem) -> String {
        switch item.type {
        case .task:
            return "Attività in programma"
        case .event:
            return "Evento in programma"
        case .deadline:
            return "Scadenza in arrivo"
        }
    }
}
