# Aurea

App iOS in SwiftUI + SwiftData per la gestione personale: finanze (portafogli, transazioni, budget, obiettivi, ricorrenze), relazioni, agenda e un assistente con insight e report.

## Struttura

- `Aurea/Models/` – modelli dati (SwiftData)
- `Aurea/Views/` – schermate (la home è in `Views/Home/`)
- `Aurea/Services/` – motori di calcolo, notifiche, backup/ripristino
- `Aurea/Components/`, `Aurea/Theme/` – componenti riusabili e tema grafico
- `AureaTests/`, `AureaUITests/` – test

## Requisiti

Xcode recente (il target di deployment è iOS 26.5). Apri `Aurea.xcodeproj` e avvia lo schema `Aurea`.
