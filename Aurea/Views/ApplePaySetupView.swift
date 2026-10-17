import SwiftData
import SwiftUI

/// Istruzioni per far registrare ad Aurea i pagamenti Apple Pay con l'automazione "Transazione"
/// dell'app Comandi, e scelta del portafoglio su cui registrarli.
struct ApplePaySetupView: View {
    @Query(sort: \Wallet.name) private var wallets: [Wallet]
    @AppStorage(PaymentRecorder.defaultWalletKey) private var defaultWallet = ""

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }

    var body: some View {
        Form {
            Section {
                Label {
                    Text("Ogni volta che paghi con iPhone o Apple Watch, Aurea registra la spesa da sola: importo, negozio e categoria. Non devi aprire l'app.")
                } icon: {
                    Image(systemName: "wave.3.right.circle.fill").foregroundStyle(.tint)
                }
            }

            Section {
                step(1, "Apri l'app **Comandi** e scegli la scheda **Automazione**.")
                step(2, "Tocca **+** (o **Nuova automazione**) e scegli **Transazione**.")
                step(3, "Seleziona le carte da seguire, lascia spuntato **Quando tocco**, scegli **Esegui immediatamente** e tocca **Avanti**.")
                step(4, "Tocca **Nuovo comando vuoto**, poi **Aggiungi azione**, cerca **Aurea** e scegli **Registra pagamento Apple Pay**.")
                step(5, "Tocca **Importo** e scegli la variabile **Input comando**, poi tocca la variabile e scegli **Importo**. Fai lo stesso con **Esercente** (scegli **Esercente**) e, se vuoi, con **Carta**.")
                step(6, "Tocca **Fine**. Al prossimo pagamento la spesa compare in Aurea.")
            } header: {
                Text("Come attivarlo")
            }

            Section {
                Picker("Registra su", selection: $defaultWallet) {
                    Text("Primo portafoglio").tag("")
                    ForEach(activeWallets) { wallet in
                        Text(wallet.name).tag(wallet.name)
                    }
                }
            } header: {
                Text("Portafoglio")
            } footer: {
                Text("Se il nome della carta contiene il nome di un portafoglio (per esempio \"Carta\"), Aurea usa quello. Altrimenti usa il portafoglio scelto qui.")
            }

            Section {
                Text("La categoria si sceglie in base al negozio e a come hai classificato spese simili. Puoi sempre cambiarla dal movimento. Se l'automazione parte due volte per lo stesso pagamento, la seconda viene ignorata.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Spese da Apple Pay")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.tint))
            Text(text)
        }
    }
}
