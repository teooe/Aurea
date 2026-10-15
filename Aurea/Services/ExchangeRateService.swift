import Foundation
import SwiftData

/// Cambi ufficiali della Banca Centrale Europea, pubblicati ogni giorno lavorativo verso le 16.
/// L'aggiornamento è facoltativo (si attiva in Valute e cambi) e parte al massimo una volta al giorno.
enum ExchangeRateService {

    static let autoUpdateKey = "aurea.rates.autoUpdate"
    static let lastUpdateKey = "aurea.rates.lastUpdate"
    static let sourceURL = URL(string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")!

    struct Rates: Equatable {
        /// Giorno di riferimento dei cambi indicato dalla BCE.
        var date: Date?
        /// Unità di ogni valuta per 1 EUR (es. USD 1,09).
        var perEUR: [String: Decimal]

        /// Quanti euro vale 1 unità della valuta: è il dato salvato nei portafogli.
        func rateToEUR(for code: String) -> Decimal? {
            if code == "EUR" { return 1 }
            guard let perEUR = perEUR[code], perEUR > 0 else { return nil }
            var value = 1 / perEUR
            var rounded = Decimal()
            NSDecimalRound(&rounded, &value, 6, .plain)
            return rounded
        }
    }

    enum UpdateError: LocalizedError {
        case invalidData
        var errorDescription: String? { "La BCE ha risposto con dati non leggibili." }
    }

    /// Legge il file XML della BCE: `<Cube time='2026-10-14'>` e `<Cube currency='USD' rate='1.0912'/>`.
    static func parse(_ data: Data) -> Rates? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var rates: [String: Decimal] = [:]
        let pattern = #"currency=['"]([A-Z]{3})['"]\s+rate=['"]([0-9.]+)['"]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let codeRange = Range(match.range(at: 1), in: text),
                  let rateRange = Range(match.range(at: 2), in: text),
                  let rate = Decimal(string: String(text[rateRange]), locale: Locale(identifier: "en_US_POSIX")),
                  rate > 0 else { continue }
            rates[String(text[codeRange])] = rate
        }
        guard !rates.isEmpty else { return nil }

        var date: Date?
        if let timeRegex = try? NSRegularExpression(pattern: #"time=['"](\d{4}-\d{2}-\d{2})['"]"#),
           let match = timeRegex.firstMatch(in: text, range: range),
           let dayRange = Range(match.range(at: 1), in: text) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
            formatter.dateFormat = "yyyy-MM-dd"
            date = formatter.date(from: String(text[dayRange]))
        }
        return Rates(date: date, perEUR: rates)
    }

    /// Aggiorna i portafogli in valuta estera che la BCE quota. Restituisce quanti sono cambiati.
    @discardableResult
    static func apply(_ rates: Rates, to wallets: [Wallet]) -> Int {
        var changed = 0
        for wallet in wallets where wallet.currencyCode != "EUR" {
            guard let rate = rates.rateToEUR(for: wallet.currencyCode), wallet.exchangeRateToEUR != rate else { continue }
            wallet.exchangeRateToEUR = rate
            changed += 1
        }
        return changed
    }

    static func fetch() async throws -> Rates {
        var request = URLRequest(url: sourceURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let rates = parse(data) else { throw UpdateError.invalidData }
        return rates
    }

    /// Scarica e applica i cambi. Restituisce quanti portafogli sono stati aggiornati.
    @discardableResult
    static func update(in context: ModelContext, defaults: UserDefaults = .standard, now: Date = .now) async throws -> Int {
        let rates = try await fetch()
        let wallets = (try? context.fetch(FetchDescriptor<Wallet>())) ?? []
        let changed = apply(rates, to: wallets)
        if changed > 0 { try? context.save() }
        defaults.set(now, forKey: lastUpdateKey)
        return changed
    }

    /// Chiamata quando l'app torna attiva: non fa nulla se l'opzione è spenta, se non ci sono
    /// portafogli in valuta estera o se l'ultimo aggiornamento è di oggi. Gli errori di rete si ignorano.
    static func updateIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard, now: Date = .now, calendar: Calendar = .current) {
        guard defaults.bool(forKey: autoUpdateKey) else { return }
        if let last = defaults.object(forKey: lastUpdateKey) as? Date, calendar.isDate(last, inSameDayAs: now) { return }
        let wallets = (try? context.fetch(FetchDescriptor<Wallet>())) ?? []
        guard wallets.contains(where: { $0.currencyCode != "EUR" && !$0.isArchived }) else { return }
        Task { try? await update(in: context, defaults: defaults, now: now) }
    }
}
