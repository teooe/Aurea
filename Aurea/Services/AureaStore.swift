import Foundation
import SwiftData

/// Unico ModelContainer dell'app, condiviso tra interfaccia e App Intents (Siri, Comandi rapidi):
/// così un movimento registrato da Siri compare subito nell'app.
enum AureaStore {
    static let schema = Schema([
        Wallet.self,
        Transaction.self,
        Relationship.self,
        RelationshipPayment.self,
        Goal.self,
        FinanceCategory.self,
        Budget.self,
        RecurringTransaction.self,
        AgendaItem.self,
    ])

    /// Preferenza "Sincronizza con iCloud": vale dal riavvio successivo dell'app.
    static let iCloudSyncKey = "aurea.icloud.enabled"
    static let cloudKitContainerID = "iCloud.com.aurea.Aurea"

    /// La sincronizzazione richiede la capability iCloud, possibile solo con un account sviluppatore
    /// a pagamento. Finché non si aggiunge `AUREA_ICLOUD` alle condizioni di compilazione
    /// (vedi docs/iCloud.md) l'opzione resta spenta e l'archivio è solo sul dispositivo.
    static var isCloudSyncAvailable: Bool {
        #if AUREA_ICLOUD
        return true
        #else
        return false
        #endif
    }

    static var isCloudSyncActive: Bool {
        isCloudSyncAvailable && UserDefaults.standard.bool(forKey: iCloudSyncKey)
    }

    static let container: ModelContainer = {
        #if DEBUG
        // Con -DemoData (solo build Debug) si lavora in memoria su dati di esempio: il database vero non viene aperto.
        let inMemory = DemoData.isEnabled
        #else
        let inMemory = false
        #endif
        // Esplicito: senza la scelta dell'utente non si usa mai CloudKit, anche se la capability c'è.
        let cloud: ModelConfiguration.CloudKitDatabase = (isCloudSyncActive && !inMemory) ? .private(cloudKitContainerID) : .none
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: cloud)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            #if DEBUG
            if inMemory { DemoData.seed(in: container.mainContext) }
            #endif
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
