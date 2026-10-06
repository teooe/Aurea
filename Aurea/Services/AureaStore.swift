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

    static let container: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
