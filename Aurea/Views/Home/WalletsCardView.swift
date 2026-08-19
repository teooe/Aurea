import SwiftUI

struct WalletsCardView: View {

    let wallets: [Wallet]
    let isExpanded: Bool
    let onTap: () -> Void
    let onAddWallet: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            AureaCard(
                title: "Portafogli",
                icon: "creditcard"
            ) {
                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {

                    if wallets.isEmpty {
                        Text("Nessun portafoglio")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    } else {
                        ForEach(wallets) { wallet in
                            VStack(spacing: Theme.Spacing.small) {
                                HStack {
                                    Label(
                                        wallet.name,
                                        systemImage: wallet.icon
                                    )

                                    Spacer()

                                    Text(
                                        FinancialEngine.balance(for: wallet),
                                        format: .currency(code: wallet.currencyCode)
                                    )
                                    .fontWeight(.medium)
                                }

                                if isExpanded {
                                    HStack {
                                        Text(wallet.currencyCode)

                                        Spacer()

                                        Text("Saldo iniziale")

                                        Text(
                                            wallet.initialBalance,
                                            format: .currency(code: wallet.currencyCode)
                                        )
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                                    .transition(.opacity)
                                }
                            }
                        }
                    }

                    if isExpanded {
                        Button {
                            onAddWallet()
                        } label: {
                            Label(
                                "Aggiungi portafoglio",
                                systemImage: "plus"
                            )
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
