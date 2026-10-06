# Aurea

App iOS in SwiftUI + SwiftData per la gestione personale: finanze (portafogli, movimenti, budget, obiettivi, ricorrenze), relazioni e agenda, con analisi e report, azioni Siri/Comandi rapidi, blocco con Face ID e scansione degli scontrini.

## Struttura

- `Aurea/Models/` – modelli dati (SwiftData)
- `Aurea/Views/` – schermate (la home è in `Views/Home/`)
- `Aurea/Services/` – motori di calcolo, categorie, notifiche, backup/ripristino, esportazione CSV, lettura scontrini
- `Aurea/Intents/` – azioni per Siri e Comandi rapidi
- `Aurea/Shared/` – tipi condivisi con il widget
- `Aurea/Components/`, `Aurea/Theme/` – componenti riusabili e tema grafico
- `AureaWidgetSources/` – sorgenti del widget (il target va creato in Xcode, vedi il README della cartella)
- `AureaTests/`, `AureaUITests/` – test
- `.github/workflows/build.yml` – CI: compila ed esegue i test su simulatore iOS

## Requisiti

Xcode recente (target di deployment iOS 26.5). Apri `Aurea.xcodeproj` e avvia lo schema `Aurea`.
