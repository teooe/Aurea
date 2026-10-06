import AppIntents

/// Frasi per Siri e azioni pronte nell'app Comandi rapidi, disponibili senza configurazione.
nonisolated struct AureaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Registra una spesa su \(.applicationName)",
                "Aggiungi una spesa in \(.applicationName)",
                "Nuova spesa su \(.applicationName)",
            ],
            shortTitle: "Registra spesa",
            systemImageName: "eurosign.circle"
        )
        AppShortcut(
            intent: MonthSummaryIntent(),
            phrases: [
                "Quanto ho speso su \(.applicationName)",
                "Spese del mese su \(.applicationName)",
            ],
            shortTitle: "Spese del mese",
            systemImageName: "chart.bar"
        )
        AppShortcut(
            intent: OpenQuickAddIntent(),
            phrases: [
                "Apri nuovo movimento su \(.applicationName)",
            ],
            shortTitle: "Nuovo movimento",
            systemImageName: "plus.circle"
        )
    }
}
