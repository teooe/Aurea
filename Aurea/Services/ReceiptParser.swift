import Foundation

/// Interpreta il testo letto da uno scontrino (una riga per elemento, dall'alto in basso)
/// e ne ricava totale, data e nome del negozio. È pura logica sulle stringhe, così si testa
/// senza fotocamera; l'OCR sta in ReceiptScanner.
enum ReceiptParser {

    struct Result: Equatable {
        var amount: Decimal?
        var date: Date?
        var merchant: String?
    }

    static func parse(_ lines: [String], now: Date = .now, calendar: Calendar = .current) -> Result {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Result(
            amount: total(in: cleaned),
            date: date(in: cleaned, now: now, calendar: calendar),
            merchant: merchant(in: cleaned)
        )
    }

    // MARK: - Totale

    /// Parole che indicano il totale, dalla più affidabile alla meno affidabile.
    private static let totalKeywords = ["totale complessivo", "totale euro", "totale eur", "importo pagato", "totale", "total", "pagato", "da pagare"]
    /// Righe che contengono "totale" ma non sono il totale da pagare.
    private static let excludedKeywords = ["subtot", "sub tot", "iva", "imponibile", "sconto", "resto", "contant", "num. pezzi", "articoli", "punti"]

    static func total(in lines: [String]) -> Decimal? {
        let lowered = lines.map { $0.lowercased() }

        for keyword in totalKeywords {
            for (index, line) in lowered.enumerated() where line.contains(keyword) {
                guard !excludedKeywords.contains(where: { line.contains($0) }) else { continue }
                // L'OCR spesso separa etichetta e importo: se la riga non ha un importo, guarda la successiva.
                if let amount = amounts(in: lines[index]).last {
                    return amount
                }
                if index + 1 < lines.count, let amount = amounts(in: lines[index + 1]).first {
                    return amount
                }
            }
        }

        // Nessuna etichetta riconosciuta: l'importo più alto, escludendo contanti e resto
        // (i contanti consegnati superano il totale).
        return lines.enumerated()
            .filter { index, _ in !excludedKeywords.contains(where: { lowered[index].contains($0) }) }
            .flatMap { amounts(in: $0.element) }
            .max()
    }

    /// Importi con due decimali in una riga: "12,50", "1.234,56", "€ 8.90", "12,50 EUR".
    static func amounts(in line: String) -> [Decimal] {
        // Il lookahead finale esclude le date con i punti ("25.09.2026" non è 25,09 €).
        let pattern = #"(?<![\d.,])(\d{1,3}(?:[.\s]\d{3})+|\d+)[.,](\d{2})(?!\d|[./\-]\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let whole = Range(match.range(at: 1), in: line),
                  let cents = Range(match.range(at: 2), in: line) else { return nil }
            let digits = line[whole].filter(\.isNumber)
            return Decimal(string: "\(digits).\(line[cents])")
        }
    }

    // MARK: - Data

    static func date(in lines: [String], now: Date, calendar: Calendar) -> Date? {
        let pattern = #"(?<!\d)(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4}|\d{2})(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        // Tolleranza di un giorno per scontrini con orologio avanti o fuso diverso.
        let latest = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            for match in regex.matches(in: line, range: range) {
                guard let dayRange = Range(match.range(at: 1), in: line),
                      let monthRange = Range(match.range(at: 2), in: line),
                      let yearRange = Range(match.range(at: 3), in: line),
                      let day = Int(line[dayRange]), let month = Int(line[monthRange]), var year = Int(line[yearRange]) else { continue }
                if year < 100 { year += 2000 }
                var components = DateComponents(year: year, month: month, day: day)
                components.hour = 12
                // Scarta date impossibili (31/02) che Calendar normalizzerebbe in silenzio.
                guard let date = calendar.date(from: components),
                      calendar.component(.day, from: date) == day,
                      calendar.component(.month, from: date) == month,
                      date <= latest,
                      year >= 2000 else { continue }
                return date
            }
        }
        return nil
    }

    // MARK: - Negozio

    /// Intestazioni di legge che precedono il nome del negozio.
    private static let headerNoise = ["documento commerciale", "scontrino", "vendita", "prestazione", "p.iva", "partita iva", "c.f.", "tel", "via ", "viale", "piazza", "corso", "www", "http", "cassa", "operatore"]

    static func merchant(in lines: [String]) -> String? {
        for line in lines.prefix(6) {
            let lowered = line.lowercased()
            guard !headerNoise.contains(where: { lowered.contains($0) }) else { continue }
            let letters = line.filter(\.isLetter).count
            // Un nome ha soprattutto lettere: scarta righe di numeri, date o codici.
            guard letters >= 3, Double(letters) / Double(line.count) >= 0.6 else { continue }
            return line.localizedCapitalized
        }
        return nil
    }
}
