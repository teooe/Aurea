import SwiftUI

struct GoalsCardView: View {

    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            AureaCard(
                title: "Obiettivi",
                icon: "target"
            ) {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Nessun obiettivo")
                        .foregroundStyle(Theme.Colors.secondaryText)

                    if isExpanded {
                        Text("Gli obiettivi ti permetteranno di monitorare traguardi economici e temporali.")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .transition(.opacity)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
