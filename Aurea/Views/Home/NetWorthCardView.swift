import SwiftUI

struct NetWorthCardView: View {

    let totalNetWorth: Decimal
    let walletCount: Int
    let transactionCount: Int
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            AureaCard(
                title: "Patrimonio",
                icon: "wallet.pass"
            ) {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {

                    Text(
                        totalNetWorth,
                        format: .currency(code: "EUR")
                    )
                    .font(.system(size: 40, weight: .semibold))

                    Text("Patrimonio totale")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    if isExpanded {
                        Divider()

                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            Text("Dettaglio")
                                .font(.headline)

                            Text("\(walletCount) portafogli")
                                .foregroundStyle(Theme.Colors.secondaryText)

                            Text("\(transactionCount) movimenti registrati")
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
