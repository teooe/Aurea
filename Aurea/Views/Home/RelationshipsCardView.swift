import SwiftUI

struct RelationshipsCardView: View {

    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            AureaCard(
                title: "Debiti e Crediti",
                icon: "arrow.left.arrow.right"
            ) {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Nessuna relazione economica")
                        .foregroundStyle(Theme.Colors.secondaryText)

                    if isExpanded {
                        Text("Qui verranno mostrati debiti e crediti aperti.")
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
