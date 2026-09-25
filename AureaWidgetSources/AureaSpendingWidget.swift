import SwiftUI
import WidgetKit

// Widget "Spese del mese". Legge solo il riepilogo che l'app salva nell'App Group
// (WidgetSnapshot.swift, condiviso con l'app): non apre il database.

nonisolated struct SpendingEntry: TimelineEntry {
    let date: Date
    /// `nil` finché l'app non ha mai scritto un riepilogo (o l'App Group non è configurato).
    let snapshot: WidgetSnapshot?
}

nonisolated struct SpendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendingEntry {
        SpendingEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendingEntry) -> Void) {
        completion(SpendingEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingEntry>) -> Void) {
        let now = Date.now
        let entry = SpendingEntry(date: now, snapshot: WidgetSnapshotStore.load())
        // A mezzanotte "oggi" torna a zero e, a inizio mese, il widget si accorge del cambio di mese.
        // Per il resto è l'app a chiedere l'aggiornamento quando i dati cambiano.
        let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

struct AureaSpendingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotStore.widgetKind, provider: SpendingProvider()) { entry in
            SpendingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "aurea://nuovo-movimento"))
        }
        .configurationDisplayName("Spese del mese")
        .description("Quanto hai speso questo mese e oggi, con i budget più vicini al limite. Tocca per registrare una spesa.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct SpendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpendingEntry

    private var snapshot: WidgetSnapshot? {
        guard let snapshot = entry.snapshot, snapshot.isCurrentMonth(at: entry.date) else { return nil }
        return snapshot
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            if let snapshot {
                Text("Speso \(euro(snapshot.monthExpenses)) questo mese")
                    .privacySensitive()
            } else {
                Text("Apri Aurea")
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Speso questo mese").font(.caption2)
                Text(snapshot.map { euro($0.monthExpenses) } ?? "—")
                    .font(.headline)
                    .widgetAccentable()
                    .privacySensitive()
                if let snapshot {
                    Text("Oggi \(euro(snapshot.expensesToday(at: entry.date)))").font(.caption2)
                        .privacySensitive()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                summary
                    .frame(maxWidth: .infinity, alignment: .leading)
                budgets
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            summary
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Questo mese", systemImage: "eurosign.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let snapshot {
                Text(euro(snapshot.monthExpenses))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .privacySensitive()
                Text("spesi")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                HStack {
                    Text("Oggi")
                    Spacer()
                    Text(euro(snapshot.expensesToday(at: entry.date))).fontWeight(.semibold)
                        .privacySensitive()
                }
                .font(.caption)
            } else {
                Spacer(minLength: 0)
                Text("Apri Aurea per vedere le spese del mese.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder private var budgets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Budget", systemImage: "gauge.with.dots.needle.50percent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let snapshot, !snapshot.budgets.isEmpty {
                ForEach(Array(snapshot.budgets.prefix(2).enumerated()), id: \.offset) { _, budget in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(budget.title).lineLimit(1)
                            Spacer()
                            Text("\(Int(budget.ratio * 100))%").monospacedDigit()
                        }
                        .font(.caption)
                        .privacySensitive()
                        ProgressView(value: min(max(budget.ratio, 0), 1))
                            .tint(budget.ratio >= 1 ? .red : (budget.ratio >= 0.8 ? .orange : .accentColor))
                    }
                }
            } else if let snapshot {
                Text("Entrate \(euro(snapshot.monthIncome))").font(.caption).privacySensitive()
                Text("Bilancio \(euro(snapshot.monthBalance))").font(.caption).privacySensitive()
            }
            Spacer(minLength: 0)
        }
    }

    private func euro(_ value: Decimal) -> String {
        value.formatted(.currency(code: "EUR").precision(.fractionLength(0...2)))
    }
}

#Preview(as: .systemMedium) {
    AureaSpendingWidget()
} timeline: {
    SpendingEntry(date: .now, snapshot: .placeholder)
    SpendingEntry(date: .now, snapshot: nil)
}
