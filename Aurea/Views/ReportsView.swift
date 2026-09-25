import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var selectedRange: ReportRange = .sixMonths

    /// Mostra "Fine" quando il report è aperto come foglio a sé.
    var showsDoneButton = false

    private var months: [MonthReport] {
        let count = selectedRange.monthCount
        return (0..<count).reversed().compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .month, value: -offset, to: .now) else { return nil }
            let source = transactions.filter { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .month) && !$0.isTransfer }
            let income = source.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + valueInEUR($1) }
            let expenses = source.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + valueInEUR($1) }
            return MonthReport(date: date, income: income, expenses: expenses)
        }
    }

    private var currentMonthTransactions: [Transaction] {
        transactions.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) && !$0.isTransfer }
    }
    private var currentIncome: Decimal { currentMonthTransactions.filter { $0.type == .income }.reduce(0) { $0 + valueInEUR($1) } }
    private var currentExpenses: Decimal { currentMonthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + valueInEUR($1) } }
    private var currentBalance: Decimal { currentIncome - currentExpenses }
    private var averageExpenses: Decimal {
        let values = months.map(\.expenses).filter { $0 > 0 }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Decimal(values.count)
    }
    private var categoryReports: [CategoryReport] {
        let expenses = currentMonthTransactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: \Transaction.category)
        return grouped.map { CategoryReport(name: $0.key, amount: $0.value.reduce(0) { $0 + valueInEUR($1) }) }.sorted { $0.amount > $1.amount }
    }
    private var biggestExpenses: [Transaction] {
        Array(currentMonthTransactions.filter { $0.type == .expense }.sorted { valueInEUR($0) > valueInEUR($1) }.prefix(5))
    }

    var body: some View {
        List {
            Section {
                Picker("Periodo", selection: $selectedRange) {
                    ForEach(ReportRange.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            }

            Section("Questo mese") {
                HStack(spacing: 12) {
                    metric("Entrate", currentIncome)
                    metric("Spese", currentExpenses)
                    metric("Bilancio", currentBalance)
                }
                if averageExpenses > 0 {
                    LabeledContent("Media spese mensili") { Text(averageExpenses.formatted(.currency(code: "EUR"))).fontWeight(.semibold) }
                }
            }

            Section("Andamento") {
                if months.allSatisfy({ $0.income == 0 && $0.expenses == 0 }) {
                    ContentUnavailableView("Dati insufficienti", systemImage: "chart.xyaxis.line", description: Text("Aggiungi movimenti in più mesi per vedere l'andamento."))
                } else {
                    Chart(months) { month in
                        BarMark(x: .value("Mese", month.shortName), y: .value("Entrate", decimalDouble(month.income)))
                            .foregroundStyle(by: .value("Tipo", "Entrate"))
                        BarMark(x: .value("Mese", month.shortName), y: .value("Spese", decimalDouble(month.expenses)))
                            .foregroundStyle(by: .value("Tipo", "Spese"))
                    }
                    .frame(height: 220)
                    .chartLegend(position: .bottom)
                }
            }

            Section("Bilancio mensile") {
                ForEach(months.reversed()) { month in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(month.longName).fontWeight(.medium)
                            Text("Entrate \(month.income.formatted(.currency(code: "EUR"))) · Spese \(month.expenses.formatted(.currency(code: "EUR")))")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
                        }
                        Spacer()
                        Text(month.balance.formatted(.currency(code: "EUR"))).fontWeight(.semibold).foregroundStyle(month.balance < 0 ? .red : .primary)
                    }
                }
            }

            Section("Spese per categoria · questo mese") {
                if categoryReports.isEmpty {
                    Text("Nessuna spesa registrata").foregroundStyle(.secondary)
                } else {
                    Chart(categoryReports.prefix(6)) { category in
                        BarMark(x: .value("Importo", decimalDouble(category.amount)), y: .value("Categoria", category.name))
                    }.frame(height: CGFloat(max(150, min(categoryReports.count, 6) * 42)))
                    ForEach(Array(categoryReports.prefix(6))) { category in
                        HStack { Text(category.name); Spacer(); Text(category.amount.formatted(.currency(code: "EUR"))).foregroundStyle(.secondary) }
                    }
                }
            }

            Section("Spese più alte · questo mese") {
                if biggestExpenses.isEmpty { Text("Nessuna spesa registrata").foregroundStyle(.secondary) }
                else {
                    ForEach(biggestExpenses) { transaction in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) { Text(transaction.title).fontWeight(.medium); Text(transaction.category).font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Text(valueInEUR(transaction).formatted(.currency(code: "EUR"))).fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } }
            }
        }
    }

    private func metric(_ title: String, _ value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: "EUR"))).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func valueInEUR(_ transaction: Transaction) -> Decimal { transaction.amount * (transaction.wallet?.effectiveExchangeRateToEUR ?? 1) }
    private func decimalDouble(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
}

private enum ReportRange: String, CaseIterable, Identifiable {
    case threeMonths, sixMonths, twelveMonths
    var id: String { rawValue }
    var title: String { switch self { case .threeMonths: "3 mesi"; case .sixMonths: "6 mesi"; case .twelveMonths: "12 mesi" } }
    var monthCount: Int { switch self { case .threeMonths: 3; case .sixMonths: 6; case .twelveMonths: 12 } }
}

private struct MonthReport: Identifiable {
    let date: Date
    let income: Decimal
    let expenses: Decimal
    var id: String { date.formatted(.iso8601.year().month()) }
    var balance: Decimal { income - expenses }
    var shortName: String { date.formatted(.dateTime.month(.abbreviated)) }
    var longName: String { date.formatted(.dateTime.month(.wide).year()) }
}

private struct CategoryReport: Identifiable {
    let name: String
    let amount: Decimal
    var id: String { name }
}
