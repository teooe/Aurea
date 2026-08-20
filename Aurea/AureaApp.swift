//
//  AureaApp.swift
//  Aurea
//
//  Created by Matteo Ragazzoli on 14/08/2026.
//

import SwiftUI
import SwiftData

@main
struct AureaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Wallet.self,
            Transaction.self,
            Relationship.self,
            Goal.self,
            FinanceCategory.self,
            Budget.self,
            RecurringTransaction.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
