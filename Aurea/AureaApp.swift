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
    var sharedModelContainer: ModelContainer { AureaStore.container }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
