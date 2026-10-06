import Foundation
import SwiftData

/// Esporta i movimenti in un CSV pensato per Excel e Numbers in italiano:
/// separatore ";", virgola decimale, importi con segno (spese negative) e BOM UTF-8
/// perché Excel riconosca le lettere accentate.
enum CSVExporter {

    static let header = ["Data", "Ora", "Tipo", "Titolo", "Categoria", "Importo", "Valuta", "Importo EUR", "Portafoglio"]

    static func csv(for transactions: [Transaction], timeZone: TimeZone = .current) -> String {
        let dateFormatter = makeFormatter("dd/MM/yyyy", timeZone: timeZone)
        let timeFormatter = makeFormatter("HH:mm", timeZone: timeZone)

        var lines = [header.joined(separator: separator)]
        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            let sign: Decimal = transaction.type == .expense ? -1 : 1
            let amount = transaction.amount * sign
            let amountInEUR = FinancialEngine.amountInEUR(for: transaction) * sign
            let fields = [
                dateFormatter.string(from: transaction.date),
                timeFormatter.string(from: transaction.date),
                typeLabel(for: transaction),
                transaction.title,
                transaction.category,
                number(amount),
                transaction.wallet?.currencyCode ?? "EUR",
                number(amountInEUR, scale: 2),
                transaction.wallet?.name ?? "",
            ]
            lines.append(fields.map { escape($0) }.joined(separator: separator))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Scrive il CSV in un file temporaneo pronto da condividere.
    static func writeFile(for transactions: [Transaction], now: Date = .now) throws -> URL {
        let stamp = makeFormatter("yyyy-MM-dd", timeZone: .current).string(from: now)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Aurea-Movimenti-\(stamp).csv")
        try csv(for: transactions).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func typeLabel(for transaction: Transaction) -> String {
        if transaction.isTransfer { return "Trasferimento" }
        switch transaction.type {
        case .expense: return "Spesa"
        case .income: return "Entrata"
        case .transfer: return "Trasferimento"
        }
    }

    /// Numero con virgola decimale e senza separatore delle migliaia, così i fogli di calcolo lo leggono come valore.
    static func number(_ value: Decimal, scale: Int? = nil) -> String {
        var value = value
        if let scale {
            var rounded = Decimal()
            NSDecimalRound(&rounded, &value, scale, .plain)
            value = rounded
        }
        return NSDecimalNumber(decimal: value).stringValue.replacingOccurrences(of: ".", with: ",")
    }

    /// Mette tra virgolette solo i campi che contengono separatore, virgolette o a capo.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == ";" || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static let separator = ";"

    private static func makeFormatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}
