# Sincronizzazione iCloud

Aurea è già pronta per sincronizzare i dati con iCloud (CloudKit), ma l'opzione è spenta:
la capability iCloud funziona solo con un **account sviluppatore Apple a pagamento** (Apple Developer Program).
Con l'account gratuito i dati restano solo sul dispositivo, come oggi.

Quando avrai l'account a pagamento, servono circa 10 minuti, tutti da Xcode.

## 1. Attiva iCloud sul target Aurea
1. In Xcode seleziona il progetto **Aurea** nella barra a sinistra, poi il target **Aurea**.
2. Apri la scheda **Signing & Capabilities** e controlla che *Team* sia il tuo account a pagamento.
3. Premi **+ Capability** e scegli **iCloud**.
4. Nella sezione iCloud spunta **CloudKit**.
5. Sotto *Containers* premi **+** e crea **`iCloud.com.aurea.Aurea`**, poi spuntalo.
   Se scegli un nome diverso, aggiornalo anche in `AureaStore.cloudKitContainerID` (`Aurea/Services/AureaStore.swift`).
6. Premi di nuovo **+ Capability** e aggiungi **Background Modes**, poi spunta **Remote notifications**:
   serve per ricevere subito le modifiche fatte sugli altri dispositivi.

## 2. Accendi l'opzione nel codice
1. Sempre nel target **Aurea**, apri la scheda **Build Settings** e cerca *Active Compilation Conditions*.
2. Sia in **Debug** sia in **Release** aggiungi `AUREA_ICLOUD` (lascia gli altri valori già presenti).

Ora in **Impostazioni → iCloud** compare l'interruttore *Sincronizza con iCloud*.

## 3. Prova
1. Prima di tutto crea un **backup completo** da Impostazioni (per sicurezza).
2. Attiva *Sincronizza con iCloud*, chiudi Aurea dal selettore delle app e riaprila.
3. Sul secondo dispositivo, con lo stesso Apple ID, fai lo stesso: dopo qualche minuto i dati compaiono.

La prima volta, su [CloudKit Console](https://icloud.developer.apple.com/) lo schema viene creato in
*Development*. Prima di distribuire l'app su TestFlight o App Store va pubblicato in *Production*
(**Deploy Schema Changes**).

## Cosa è già pronto
- Tutti i modelli hanno valori predefiniti e relazioni opzionali con inverso, come richiede CloudKit.
- Le foto degli scontrini sono salvate fuori dal database e vengono caricate su iCloud come file allegati.
- Senza `AUREA_ICLOUD`, o con l'interruttore spento, l'archivio usa esplicitamente solo il dispositivo.
- Il widget e le preferenze (aspetto, notifiche, budget) non passano da iCloud: restano per dispositivo.
