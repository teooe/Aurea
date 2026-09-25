# Widget di Aurea: configurazione in Xcode

I file Swift del widget sono in questa cartella, ma non vengono ancora compilati: il target
del widget va creato da Xcode, e vanno aggiunti l'App Group e la firma. Ci vogliono circa 5 minuti.

Siri e l'app Comandi rapidi **non** richiedono questa configurazione: funzionano già con l'app.

## 1. Crea il target del widget
1. In Xcode: **File → New → Target… → Widget Extension**.
2. Nome del prodotto: **`AureaWidget`**.
3. Togli la spunta da *Include Live Activity*, *Include Control* e *Include Configuration App Intent*.
4. Conferma e, se Xcode lo chiede, attiva lo schema.

## 2. Sostituisci i file generati con quelli di Aurea
1. Nella cartella `AureaWidget` creata da Xcode, elimina i file `.swift` generati
   (scegli *Move to Trash*). Tieni `Assets.xcassets` e `Info.plist`.
2. Sposta in `AureaWidget/` i due file di questa cartella:
   - `AureaWidgetBundle.swift`
   - `AureaSpendingWidget.swift`
3. Elimina la cartella `AureaWidgetSources`, compreso questo README.

## 3. Condividi il riepilogo con il widget
Seleziona `Aurea/Shared/WidgetSnapshot.swift`. Nel pannello a destra (*File inspector → Target Membership*)
spunta anche **AureaWidget**. È l'unico file che app e widget condividono.

## 4. Attiva l'App Group su entrambi i target
Per il target **Aurea** e poi per il target **AureaWidget**:
1. Apri **Signing & Capabilities** e scegli **+ Capability → App Groups**.
2. Aggiungi e spunta **`group.com.aurea.Aurea`**.

Se scegli un nome diverso, aggiorna `WidgetSnapshotStore.appGroupID` in `Aurea/Shared/WidgetSnapshot.swift`.

Controlla anche che il widget abbia lo stesso *Team* dell'app e *Minimum Deployment* 26.5.

## 5. Prova
1. Avvia l'app una volta, poi mandala in background.
2. Aggiungi il widget **Spese del mese** alla schermata Home o alla schermata di blocco.
3. Toccando il widget si apre il modulo *Nuovo movimento*.

## Come funziona
- L'app salva un piccolo riepilogo nell'App Group (spese e entrate del mese, spese di oggi,
  i 3 budget più vicini al limite) quando si apre, quando va in background e dopo ogni spesa
  registrata con Siri. Il widget legge solo quello e non tocca il database.
- A mezzanotte il widget azzera "Oggi". Se è cambiato il mese e l'app non è ancora stata aperta,
  invita ad aprirla invece di mostrare i totali del mese precedente.
- Gli importi sono segnati come dati sensibili: se in *Impostazioni → Face ID e codice* hai disattivato
  i widget a telefono bloccato, sulla schermata di blocco appaiono nascosti.
