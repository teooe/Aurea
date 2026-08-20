import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aurea.onboarding.completed") private var onboardingCompleted = false
    @Query private var wallets: [Wallet]

    @State private var page = 0
    @State private var showingAddWallet = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(icon: "sparkles", title: "Benvenuto in Aurea", text: "Finanze e agenda in un unico spazio, semplice e personale."),
        OnboardingPage(icon: "wallet.pass", title: "Tieni sotto controllo i soldi", text: "Portafogli, movimenti, budget, obiettivi e debiti o crediti lavorano insieme."),
        OnboardingPage(icon: "calendar", title: "Organizza le giornate", text: "Attività, eventi, scadenze, priorità e promemoria sono sempre a portata di mano."),
        OnboardingPage(icon: "sparkles.rectangle.stack", title: "Chiedi ad Aurea", text: "L'assistente può leggere i dati dell'app, rispondere alle tue domande e preparare azioni da confermare.")
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
