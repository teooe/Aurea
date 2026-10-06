import SwiftUI
import SwiftData

struct RelationshipsCardView: View {

    let relationships: [Relationship]
    let isExpanded: Bool
    let onTap: () -> Void
    let onAddRelationship: () -> Void
    let onSelectRelationship: (Relationship) -> Void

    private var openRelationships: [Relationship] { relationships.filter { !$0.isClosed } }
    private var closedRelationships: [Relationship] { relationships.filter { $0.isClosed } }
    private var debts: [Relationship] { openRelationships.filter { $0.type == .debt } }
    private var credits: [Relationship] { openRelationships.filter { $0.type == .credit } }
    private var totalDebts: Decimal { debts.reduce(0) { $0 + $1.remainingAmount } }
    private var totalCredits: Decimal { credits.reduce(0) { $0 + $1.remainingAmount } }

    var body: some View {
        AureaCard(title: "Debiti e Crediti", icon: "arrow.left.arrow.right") {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Button { onTap() } label: {
                    Group {
                        if openRelationships.isEmpty {
                            HStack {
                                Text("Nessuna relazione economica aperta").foregroundStyle(Theme.Colors.secondaryText)
                                Spacer()
                            }
                        } else {
                            HStack(spacing: Theme.Spacing.medium) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Debiti").font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                                    Text(totalDebts, format: .currency(code: "EUR")).fontWeight(.semibold).foregroundStyle(.red)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Crediti").font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                                    Text(totalCredits, format: .currency(code: "EUR")).fontWeight(.semibold).foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if !openRelationships.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            Text("Aperti").font(.caption.weight(.semibold)).foregroundStyle(Theme.Colors.secondaryText)
                            ForEach(openRelationships) { relationship in relationshipRow(relationship, settled: false) }
                        }
                    }

                    if !closedRelationships.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            Text("Saldati").font(.caption.weight(.semibold)).foregroundStyle(Theme.Colors.secondaryText)
                            ForEach(closedRelationships) { relationship in relationshipRow(relationship, settled: true) }
                        }
                    }

                    Button { onAddRelationship() } label: {
                        Label("Aggiungi debito o credito", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func relationshipRow(_ relationship: Relationship, settled: Bool) -> some View {
        Button { onSelectRelationship(relationship) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(relationship.personName).fontWeight(.medium)
                        if settled {
                            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(settled ? .secondary : .primary)

                    if let dueDate = relationship.dueDate, !settled {
                        Text("Scadenza \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(Theme.Colors.secondaryText)
                    } else if !relationship.note.isEmpty {
                        Text(relationship.note).font(.caption).foregroundStyle(Theme.Colors.secondaryText).lineLimit(1)
                    }
                }
                Spacer()
                Text(settled ? relationship.amount : relationship.remainingAmount, format: .currency(code: "EUR"))
                    .fontWeight(.medium)
                    .foregroundStyle(settled ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(relationship.type == .debt ? Color.red : Color.green))
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.Colors.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
