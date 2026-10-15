import Charts
import SwiftData
import SwiftUI

/// Card "Andamento": spese degli ultimi mesi in un piccolo grafico a barre, con il mese in corso evidenziato.
struct SpendingTrendCardView: View {
    let points: [(monthStart: Date, total: Decimal)]
    let onOpenReport: () -> Void

    private var completedMonths: [Decimal] { points.dropLast().map(\.total).filter { $0 > 0 } }
    private var average: Decimal? {
        guard !completedMonths.isEmpty else { return nil }
        return completedMonths.reduce(0, +) / Decimal(completedMonths.count)
    }

    var body: some View {
        Button(action: onOpenReport) {
            AureaCard(title: "Andamento spese", icon: "chart.bar") {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    if points.allSatisfy({ $0.total == 0 }) {
                        Text("Il grafico si riempie man mano che registri le spese.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    } else {
                        Chart {
                            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                                BarMark(
                                    x: .value("Mese", point.monthStart, unit: .month),
                                    y: .value("Spese", NSDecimalNumber(decimal: point.total).doubleValue)
                                )
                                .foregroundStyle(index == points.count - 1 ? Theme.Colors.accent : Theme.Colors.accent.opacity(0.35))
                                .cornerRadius(4)
                            }
                            if let average {
                                RuleMark(y: .value("Media", NSDecimalNumber(decimal: average).doubleValue))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { _ in
                                AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                            }
                        }
                        .chartYAxis(.hidden)
                        .frame(height: 110)

                        HStack {
                            if let average {
                                Text("Media \(average.formatted(.currency(code: "EUR").precision(.fractionLength(0))))/mese")
                            }
                            Spacer()
                            Text("Report")
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Andamento spese, apri il report")
    }
}
