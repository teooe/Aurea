import SwiftData
import SwiftUI

/// Etichette e viaggi: quanto è costato ogni gruppo di spese.
struct TagsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    private var summaries: [TagEngine.Summary] { TagEngine.summaries(from: transactions) }

    var body: some View {
        List {
            if summaries.isEmpty {
                ContentUnavailableView(
                    "Nessuna etichetta",
                    systemImage: "tag",
                    description: Text("Aggiungi un'etichetta ai movimenti (per esempio \"Vacanza Sicilia\") per vedere quanto ti è costato un viaggio o un progetto, qualunque sia la categoria delle spese.")
                )
            } else {
                ForEach(summaries) { summary in
                    NavigationLink {
                        TagDetailView(tag: summary.name)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label(summary.name, systemImage: "tag").fontWeight(.semibold)
                                Spacer()
                                Text(summary.expenses, format: .currency(code: "EUR"))
                            }
                            Text("\(summary.count) movimenti · \(TagDetailView.range(summary))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Etichette e viaggi")
    }
}

struct TagDetailView: View {
    let tag: String
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @State private var selectedTransaction: Transaction?

    private var tagged: [Transaction] { TagEngine.transactions(tagged: tag, in: allTransactions) }
    private var summary: TagEngine.Summary? { TagEngine.summaries(from: tagged).first { $0.name.caseInsensitiveCompare(tag) == .orderedSame } }

    var body: some View {
        List {
            if let summary {
                Section {
                    LabeledContent("Spese") { Text(summary.expenses, format: .currency(code: "EUR")).fontWeight(.semibold) }
                    if summary.income > 0 {
                        LabeledContent("Entrate e rimborsi") { Text(summary.income, format: .currency(code: "EUR")) }
                        LabeledContent("Costo netto") { Text(summary.net, format: .currency(code: "EUR")).fontWeight(.semibold) }
                    }
                    LabeledContent("Periodo", value: Self.range(summary))
                }

                if !summary.byCategory.isEmpty {
                    Section("Per categoria") {
                        ForEach(summary.byCategory, id: \.category) { item in
                            LabeledContent(item.category) { Text(item.amount, format: .currency(code: "EUR")) }
                        }
                    }
                }
            }

            Section("Movimenti") {
                ForEach(tagged) { transaction in
                    Button {
                        selectedTransaction = transaction
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.title).foregroundStyle(.primary)
                                Text("\(transaction.category) · \(transaction.date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text((transaction.type == .expense ? -transaction.amount : transaction.amount).formatted(.currency(code: transaction.wallet?.currencyCode ?? "EUR")))
                                .foregroundStyle(transaction.type == .expense ? Theme.Colors.expense : Theme.Colors.income)
                        }
                    }
                }
            }
        }
        .navigationTitle(tag)
        .sheet(item: $selectedTransaction) { TransactionDetailView(transaction: $0) }
    }

    static func range(_ summary: TagEngine.Summary) -> String {
        let first = summary.firstDate.formatted(date: .abbreviated, time: .omitted)
        let last = summary.lastDate.formatted(date: .abbreviated, time: .omitted)
        return first == last ? first : "\(first) – \(last)"
    }
}
