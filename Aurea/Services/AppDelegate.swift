import UIKit
import UserNotifications

/// Gestisce le notifiche: le mostra anche ad app aperta e porta al modulo "Nuovo movimento"
/// quando si tocca il promemoria giornaliero.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Senza questo, le notifiche che scattano mentre l'app è aperta (es. "Budget superato") non si vedono.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        guard identifier.hasPrefix("daily-") else { return }
        await MainActor.run {
            QuickAddRequest.shared.isPending = true
        }
    }
}
