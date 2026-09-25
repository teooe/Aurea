import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aurea.onboarding.completed") private var onboardingCompleted = false
    @Query private var wallets: [Wallet]

    @State private var page = 0
    @State private var showingAddWallet = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(icon: "sparkles", title: "Benvenuto in Aurea", text: "Spese, budget e obiettivi in un unico spazio, semplice e personale."),
        OnboardingPage(icon: "wallet.pass", title: "Tieni sotto controllo i soldi", text: "Portafogli, movimenti, budget, obiettivi e debiti o crediti lavorano insieme."),
        OnboardingPage(icon: "plus.circle", title: "Registra in un attimo", text: "Tocca +, scrivi l'importo e scegli la categoria. Oppure chiedi a Siri: «Registra una spesa su Aurea»."),
        OnboardingPage(icon: "sparkles.rectangle.stack", title: "Analisi automatica", text: "Aurea ti segnala budget a rischio, dove risparmiare e le scadenze in arrivo, senza dover chiedere.")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 22) {
                            Spacer()
                            Image(systemName: item.icon)
                                .font(.system(size: 62, weight: .medium))
                            Text(item.title)
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            Text(item.text)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 12) {
                    if page == pages.count - 1 && wallets.filter({ !$0.isArchived }).isEmpty {
                        Button {
                            showingAddWallet = true
                        } label: {
                            Label("Crea il primo portafoglio", systemImage: "wallet.pass.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button {
                        if page < pages.count - 1 {
                            withAnimation { page += 1 }
                        } else {
                            onboardingCompleted = true
                            dismiss()
                        }
                    } label: {
                        Text(page < pages.count - 1 ? "Continua" : "Inizia a usare Aurea")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .sheet(isPresented: $showingAddWallet) { AddWalletView() }
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let text: String
}
