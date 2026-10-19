import Foundation
import SwiftData
import UserNotifications

/// "Elimina tutti i dati": svuota l'archivio come al primo avvio. Le preferenze (aspetto, notifiche,
/// blocco con Face ID) restano; si cancella invece ciò che si riferisce ai dati eliminati.
enum DataResetService {

    /// Chiavi e prefissi delle preferenze legate ai dati (avvisi già mostrati, formati di import, ecc.).
    static let dataMemoryPrefixes = [
        "aurea.budget.alert.",
        "aurea.unusual.alert.",
        "aurea.bankImport.",
        "aurea.subscriptions.",
        PaymentRecorder.defaultWalletKey,
        ExchangeRateService.lastUpdateKey,
    ]

    static func eraseAll(in context: ModelContext, defaults: UserDefaults = .standard) throws {
        // Prima i movimenti e ciò che punta ai portafogli, poi i portafogli.
        try deleteAll(Transaction.self, in: context)
        try deleteAll(RecurringTransaction.self, in: context)
        try deleteAll(Goal.self, in: context)
        try deleteAll(Budget.self, in: context)
        try deleteAll(RelationshipPayment.self, in: context)
        try deleteAll(Relationship.self, in: context)
        try deleteAll(AgendaItem.self, in: context)
        try deleteAll(FinanceCategory.self, in: context)
        try deleteAll(Wallet.self, in: context)
        try context.save()

        // Le categorie predefinite tornano subito, come al primo avvio.
        CategoryService.synchronize(in: context)
        try context.save()

        for key in defaults.dictionaryRepresentation().keys where dataMemoryPrefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Promemoria e notifiche che riguardavano i dati eliminati; il widget torna vuoto.
    @MainActor
    static func clearSideEffects(in context: ModelContext) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        WidgetSnapshotBuilder.refresh(in: context)
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) {
            context.delete(model)
        }
    }
}
