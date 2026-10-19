import Foundation
import SwiftUI
import UIKit

/// Riepilogo di un mese: i numeri che finiscono nel PDF.
struct MonthlyReport: Equatable {
    struct Line: Equatable {
        var title: String
        var detail: String
        var amount: Decimal
    }

    var monthStart: Date
    /// "2026-09", calcolato con lo stesso calendario del report (usato nel nome del file).
    var monthKey: String
    var income: Decimal
    var expenses: Decimal
    var previousExpenses: Decimal
    var categories: [Line]
    var biggestExpenses: [Line]
    var budgets: [Line]

    var balance: Decimal { income - expenses }
    var savingsRate: Double? {
        guard income > 0 else { return nil }
        return NSDecimalNumber(decimal: balance / income).doubleValue
    }

    static func make(
        for month: Date,
        transactions: [Transaction],
        budgets: [Budget],
        calendar: Calendar = .current
    ) -> MonthlyReport {
        let interval = calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, duration: 0)
        let previousStart = calendar.date(byAdding: .month, value: -1, to: interval.start) ?? interval.start
        let inMonth = transactions.filter { interval.contains($0.date) && !$0.isTransfer }
        let previous = transactions.filter { $0.date >= previousStart && $0.date < interval.start && !$0.isTransfer }
        let expenses = inMonth.filter { $0.type == .expense }

        var byCategory: [String: Decimal] = [:]
        for expense in expenses { byCategory[expense.category, default: 0] += FinancialEngine.amountInEUR(for: expense) }
        let total = FinancialEngine.totalExpenses(from: inMonth)
        let categories = byCategory.sorted { $0.value > $1.value }.map { name, amount in
            let share = total > 0 ? NSDecimalNumber(decimal: amount / total).doubleValue : 0
            return Line(title: name, detail: share.formatted(.percent.precision(.fractionLength(0))), amount: amount)
        }
        let biggest = expenses.sorted { FinancialEngine.amountInEUR(for: $0) > FinancialEngine.amountInEUR(for: $1) }.prefix(8).map {
            Line(title: $0.title, detail: "\($0.category) · \($0.date.formatted(.dateTime.day().month(.abbreviated)))", amount: FinancialEngine.amountInEUR(for: $0))
        }
        // Budget mensili: speso nel mese del report rispetto al limite.
        let budgetLines = budgets.filter { !$0.isArchived && $0.period == .monthly && $0.limit > 0 }.map { budget in
            let spent = BudgetEngine.spent(for: budget, in: interval, transactions: transactions)
            return Line(title: budget.title, detail: "su \(budget.limit.formatted(.currency(code: "EUR")))", amount: spent)
        }

        return MonthlyReport(
            monthStart: interval.start,
            monthKey: String(format: "%04d-%02d", calendar.component(.year, from: interval.start), calendar.component(.month, from: interval.start)),
            income: FinancialEngine.totalIncome(from: inMonth),
            expenses: total,
            previousExpenses: FinancialEngine.totalExpenses(from: previous),
            categories: Array(categories.prefix(10)),
            biggestExpenses: Array(biggest),
            budgets: budgetLines
        )
    }
}

/// Crea il PDF (A4, una pagina) del report mensile.
enum MonthlyReportPDF {
    static let pageSize = CGSize(width: 595, height: 842)

    @MainActor
    static func write(_ report: MonthlyReport) throws -> URL {
        // "2026-09": niente "/" nel nome, che il sistema leggerebbe come una cartella.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Aurea-Report-\(report.monthKey).pdf")
        let renderer = ImageRenderer(content: MonthlyReportPage(report: report).frame(width: pageSize.width, height: pageSize.height))
        renderer.proposedSize = ProposedViewSize(pageSize)
        // Pagina sempre A4: la dimensione proposta dal renderer può essere zero (per esempio fuori da una finestra),
        // e con una pagina vuota il contesto PDF non si crea.
        var box = CGRect(origin: .zero, size: pageSize)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        context.beginPDFPage(nil)
        renderer.render { _, draw in draw(context) }
        context.endPDFPage()
        context.closePDF()
        try (data as Data).write(to: url, options: .atomic)
        return url
    }
}

/// La pagina del PDF. Colori fissi (non quelli del tema scuro): è un documento da stampare.
private struct MonthlyReportPage: View {
    let report: MonthlyReport

    private func euro(_ value: Decimal) -> String { value.formatted(.currency(code: "EUR")) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aurea · Report mensile").font(.system(size: 11, weight: .semibold)).foregroundStyle(.gray)
                Text(report.monthStart.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.system(size: 26, weight: .bold))
            }

            HStack(spacing: 12) {
                metric("Entrate", euro(report.income), color: .green)
                metric("Spese", euro(report.expenses), color: .red)
                metric("Bilancio", euro(report.balance), color: report.balance >= 0 ? .black : .red)
            }

            Text(summarySentence).font(.system(size: 11)).foregroundStyle(.gray)

            HStack(alignment: .top, spacing: 24) {
                table("Spese per categoria", report.categories)
                table("Spese più alte", report.biggestExpenses)
            }

            if !report.budgets.isEmpty {
                table("Budget del mese", report.budgets)
            }

            Spacer(minLength: 0)
            Text("Creato con Aurea il \(Date.now.formatted(date: .long, time: .shortened))")
                .font(.system(size: 9))
                .foregroundStyle(.gray)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
    }

    private var summarySentence: String {
        var parts: [String] = []
        if let rate = report.savingsRate {
            parts.append(rate >= 0
                ? "Hai messo da parte il \(rate.formatted(.percent.precision(.fractionLength(0)))) delle entrate."
                : "Hai speso più di quanto hai incassato.")
        }
        if report.previousExpenses > 0 {
            let change = NSDecimalNumber(decimal: (report.expenses - report.previousExpenses) / report.previousExpenses).doubleValue
            let percent = abs(change).formatted(.percent.precision(.fractionLength(0)))
            parts.append(change >= 0 ? "Spese in aumento del \(percent) rispetto al mese prima." : "Spese in calo del \(percent) rispetto al mese prima.")
        }
        return parts.joined(separator: " ")
    }

    private func metric(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.gray)
            Text(value).font(.system(size: 17, weight: .semibold)).foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.95)))
    }

    private func table(_ title: String, _ lines: [MonthlyReport.Line]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .bold))
            if lines.isEmpty {
                Text("Nessun dato").font(.system(size: 10)).foregroundStyle(.gray)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.title).font(.system(size: 10, weight: .medium)).lineLimit(1)
                        Text(line.detail).font(.system(size: 8)).foregroundStyle(.gray).lineLimit(1)
                    }
                    Spacer()
                    Text(euro(line.amount)).font(.system(size: 10)).monospacedDigit()
                }
                Divider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
