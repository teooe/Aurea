import SwiftUI

struct RelationshipsCardView: View {

    let relationships: [Relationship]
    let isExpanded: Bool
    let onTap: () -> Void
    let onAddRelationship: () -> Void
    let onSelectRelationship: (Relationship) -> Void

    private var openRelationships: [Relationship] {
        relationships.filter { !$0.isClosed }
    }

    private var debts: [Relationship] {
        openRelationships.filter { $0.type == .debt }
    }

    private var credits: [Relationship] {
        openRelationships.filter { $0.type == .credit }
    }

    private var totalDebts: Decimal {
        debts.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var totalCredits: Decimal {
        credits.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var body: some View {
        AureaCard(
            title: "Debiti e Crediti",
            icon: "arrow.left.arrow.right"
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Button {
                    onTap()
                } label: {
                    Group {
                        if openRelationships.isEmpty {
                            HStack {
                                Text("Nessuna relazione economica")
                                    .foregroundStyle(Theme.Colors.secondaryText)
                                Spacer()
                            }
                        } else {
                            HStack(spacing: Theme.Spacing.medium) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Debiti")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)

                                    Text(totalDebts, format: .currency(code: "EUR"))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.red)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Crediti")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)

                                    Text(totalCredits, format: .currency(code: "EUR"))
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if !openRelationships.isEmpty {
                        VStack(spacing: Theme.Spacing.small) {
                            ForEach(openRelationships) { relationship in
                                Button {
                                    onSelectRelationship(relationship)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(relationship.personName)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.primary)

                                            if !relationship.note.isEmpty {
                                                Text(relationship.note)
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.Colors.secondaryText)
                                                    .lineLimit(1)
                                            }
                                        }

                                        Spacer()

                                        Text(
                                            relationship.amount,
                                            format: .currency(code: "EUR")
                                        )
                                        .fontWeight(.medium)
                                        .foregroundStyle(
                                            relationship.type == .debt ? .red : .green
                                        )

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity)
                    }

                    Button {
                        onAddRelationship()
                    } label: {
                        Label(
                            "Aggiungi debito o credito",
                            systemImage: "plus"
                        )
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
