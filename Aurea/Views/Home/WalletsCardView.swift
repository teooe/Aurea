import SwiftUI

struct WalletsCardView: View {

    let wallets: [Wallet]
    let isExpanded: Bool
    let onTap: () -> Void
    let onAddWallet: () -> Void
    let onSelectWallet: (Wallet) -> Void

    var body: some View {
        AureaCard(
            title: "Portafogli",
            icon: "creditcard"
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Button {
                    onTap()
                } label: {
                    HStack {
                        Text(wallets.isEmpty ? "Nessun portafoglio" : "\(wallets.count) portafogli")
                            .foregroundStyle(Theme.Colors.secondaryText)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if !wallets.isEmpty {
                        ForEach(wallets) { wallet in
                            Button {
                                onSelectWallet(wallet)
                            } label: {
                                VStack(spacing: Theme.Spacing.small) {
                                    HStack {
                                        Label(wallet.name, systemImage: wallet.icon)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Text(
                                            FinancialEngine.balance(for: wallet),
                                            format: .currency(code: wallet.currencyCode)
                                        )
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                    }

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
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        onAddWallet()
                    } label: {
                        Label("Aggiungi portafoglio", systemImage: "plus")
                    }
                }
            }
        }
    }
}
