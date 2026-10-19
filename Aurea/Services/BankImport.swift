import Foundation
import SwiftData

/// Import dei movimenti dal file CSV esportato dall'home banking. Ogni banca usa un formato diverso,
/// quindi qui si riconoscono separatore, colonne, date e importi in modo automatico, e l'utente
/// può correggere l'abbinamento delle colonne prima di importare.
enum BankImport {

    // MARK: - Lettura del file

    struct Table: Equatable {
        var header: [String]
        var rows: [[String]]
    }

    /// Converte il contenuto del file in tabella. Gestisce BOM, separatori `;` `,` e tab,
    /// campi tra virgolette e righe di intestazione della banca prima della tabella vera.
    static func table(from text: String) -> Table? {
        let cleaned = text.replacingOccurrences(of: "\u{FEFF}", with: "")
        let lines = cleaned.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty else { return nil }

        let separator = detectSeparator(lines)
        let parsed = lines.map { parseLine($0, separator: separator) }

        // L'intestazione è la prima riga che contiene almeno una colonna riconoscibile (data o importo):
        // molte banche mettono sopra intestatario, IBAN e periodo.
        let headerIndex = parsed.firstIndex { row in
            let guess = ColumnMapping.guess(header: row)
            return guess.date != nil && (guess.amount != nil || guess.debit != nil || guess.credit != nil)
        } ?? 0
        let header = parsed[headerIndex]
        let rows = parsed[(headerIndex + 1)...].filter { $0.count >= 2 && $0.contains { !$0.isEmpty } }
        return Table(header: header, rows: Array(rows))
    }

    static func detectSeparator(_ lines: [String]) -> Character {
        let sample = lines.prefix(20)
        let candidates: [Character] = [";", "\t", ","]
        // Il separatore giusto dà lo stesso numero (> 1) di colonne su più righe.
        return candidates.max { a, b in
            score(sample, a) < score(sample, b)
        } ?? ";"
    }

    private static func score(_ lines: ArraySlice<String>, _ separator: Character) -> Int {
        let counts = lines.map { parseLine($0, separator: separator).count }.filter { $0 > 1 }
        guard let mostCommon = Dictionary(grouping: counts, by: { $0 }).max(by: { $0.value.count < $1.value.count }) else { return 0 }
        return mostCommon.value.count * 10 + mostCommon.key
    }

    static func parseLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = Array(line).makeIterator()
        var pending: Character? = nil
        while let char = pending ?? iterator.next() {
            pending = nil
            if inQuotes {
                if char == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" { current.append("\"") } else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(char)
                }
            } else if char == "\"" {
                inQuotes = true
            } else if char == separator {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    // MARK: - Colonne

    /// Quale colonna contiene cosa. L'importo può essere in una colonna sola (con segno)
    /// oppure diviso in addebiti e accrediti.
    struct ColumnMapping: Equatable, Codable {
        var date: Int?
        var description: Int?
        var amount: Int?
        var debit: Int?
        var credit: Int?

        var isUsable: Bool { date != nil && (amount != nil || debit != nil || credit != nil) }

        static func guess(header: [String]) -> ColumnMapping {
            let names = header.map { $0.lowercased().folding(options: .diacriticInsensitive, locale: .current) }
            func find(_ keywords: [String], excluding: [String] = []) -> Int? {
                for keyword in keywords {
                    if let index = names.firstIndex(where: { name in name.contains(keyword) && !excluding.contains { name.contains($0) } }) {
                        return index
                    }
                }
                return nil
            }
            var mapping = ColumnMapping()
            // La data contabile/operazione è preferibile alla data valuta.
            mapping.date = find(["data contabile", "data operazione", "data op", "data registrazione", "started date", "completed date", "booking date", "date", "data"], excluding: ["valuta"])
                ?? find(["data valuta", "valuta"])
            mapping.description = find(["descrizione", "causale", "dettagli", "description", "payee", "beneficiario", "operazione", "movimento", "concetto"], excluding: ["data"])
            mapping.debit = find(["addebit", "uscit", "dare", "debit"])
            mapping.credit = find(["accredit", "entrat", "avere", "credit"])
            if mapping.debit == nil || mapping.credit == nil {
                mapping.amount = find(["importo", "amount", "ammontare", "valore", "euro", "eur"], excluding: ["valuta", "commission", "fee", "saldo"])
                if mapping.amount != nil { mapping.debit = nil; mapping.credit = nil }
            }
            return mapping
        }
    }

    // MARK: - Valori

    /// Importi scritti all'italiana o all'inglese: "1.234,56", "-12,50", "1,234.56", "€ 8,00", "(12,00)".
    static func amount(from text: String) -> Decimal? {
        var value = text.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        var negative = false
        if value.hasPrefix("(") && value.hasSuffix(")") { negative = true; value = String(value.dropFirst().dropLast()) }
        if value.hasSuffix("-") { negative = true; value.removeLast() }
        value = value.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == "-" || $0 == "+" }
        if value.hasPrefix("-") { negative.toggle(); value.removeFirst() }
        if value.hasPrefix("+") { value.removeFirst() }
        guard !value.isEmpty else { return nil }

        let lastComma = value.lastIndex(of: ",")
        let lastDot = value.lastIndex(of: ".")
        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            // Il separatore che compare per ultimo è quello dei decimali.
            if comma > dot {
                value = value.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                value = value.replacingOccurrences(of: ",", with: "")
            }
        case (_?, nil):
            // Solo virgole: decimale se seguita da 1-2 cifre, altrimenti migliaia.
            let parts = value.split(separator: ",")
            if parts.count == 2, (parts.last?.count ?? 0) <= 2 {
                value = value.replacingOccurrences(of: ",", with: ".")
            } else {
                value = value.replacingOccurrences(of: ",", with: "")
            }
        case (nil, _?):
            // Solo punti: con più punti, o 3 cifre dopo l'unico punto, sono migliaia ("1.234").
            let parts = value.split(separator: ".")
            if parts.count > 2 || (parts.count == 2 && parts.last?.count == 3) {
                value = value.replacingOccurrences(of: ".", with: "")
            }
        case (nil, nil):
            break
        }
        guard let decimal = Decimal(string: value) else { return nil }
        return negative ? -decimal : decimal
    }

    private static let dateFormats = [
        "dd/MM/yyyy", "dd/MM/yy", "dd-MM-yyyy", "dd.MM.yyyy", "yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss",
        "dd/MM/yyyy HH:mm", "dd/MM/yyyy HH:mm:ss", "d/M/yyyy", "yyyy/MM/dd",
    ]

    static func date(from text: String, calendar: Calendar = .current) -> Date? {
        let value = text.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.calendar = calendar
        for format in dateFormats {
            formatter.dateFormat = format
            if var date = formatter.date(from: value) {
                // "05/10/26" letto con "yyyy" diventa l'anno 26: lo si porta al 2026.
                let year = calendar.component(.year, from: date)
                if year < 100, let fixed = calendar.date(byAdding: .year, value: 2000, to: date) { date = fixed }
                // Movimenti senza ora: a mezzogiorno, così non scivolano di giorno con i fusi orari.
                if !format.contains("HH") {
                    return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)
                }
                return date
            }
        }
        return nil
    }

    // MARK: - Movimenti

    struct Row: Identifiable, Equatable {
        let id = UUID()
        var date: Date
        var description: String
        /// Positivo per le entrate, negativo per le uscite.
        var amount: Decimal
        var category: String
        var isDuplicate: Bool
        var isSelected: Bool

        var type: TransactionType { amount < 0 ? .expense : .income }

        static func == (lhs: Row, rhs: Row) -> Bool {
            lhs.date == rhs.date && lhs.description == rhs.description && lhs.amount == rhs.amount
                && lhs.category == rhs.category && lhs.isDuplicate == rhs.isDuplicate && lhs.isSelected == rhs.isSelected
        }
    }

    /// Righe pronte all'anteprima: categoria indovinata e duplicati riconosciuti (non selezionati).
    static func rows(from table: Table, mapping: ColumnMapping, existing: [Transaction], calendar: Calendar = .current) -> [Row] {
        let guesser = CategoryGuesser(history: existing)
        return table.rows.compactMap { fields in
            func field(_ index: Int?) -> String {
                guard let index, index < fields.count else { return "" }
                return fields[index]
            }
            guard let date = date(from: field(mapping.date), calendar: calendar) else { return nil }

            var value: Decimal?
            if mapping.amount != nil {
                value = amount(from: field(mapping.amount))
            } else {
                // Addebiti e accrediti in colonne separate: gli addebiti diventano negativi
                // anche quando la banca li scrive senza segno.
                let debit = amount(from: field(mapping.debit)).map { -abs($0) }
                let credit = amount(from: field(mapping.credit)).map { abs($0) }
                value = [debit, credit].compactMap { $0 }.first { $0 != 0 }
            }
            guard let value, value != 0 else { return nil }

            let description = field(mapping.description).replacingOccurrences(of: "  ", with: " ")
            let title = description.isEmpty ? (value < 0 ? "Spesa" : "Entrata") : description
            let duplicate = isDuplicate(date: date, amount: value, in: existing, calendar: calendar)
            return Row(
                date: date,
                description: title,
                amount: value,
                category: guesser.category(for: title, type: value < 0 ? .expense : .income),
                isDuplicate: duplicate,
                isSelected: !duplicate
            )
        }
    }

    /// Già registrato a mano? Stesso importo e stessa data, con un giorno di tolleranza
    /// (la banca spesso contabilizza il giorno dopo).
    static func isDuplicate(date: Date, amount: Decimal, in existing: [Transaction], calendar: Calendar) -> Bool {
        let type: TransactionType = amount < 0 ? .expense : .income
        let value = abs(amount)
        return existing.contains { transaction in
            transaction.type == type && !transaction.isTransfer && transaction.amount == value
                && abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: transaction.date), to: calendar.startOfDay(for: date)).day ?? 99) <= 1
        }
    }

    /// Salva le righe selezionate nel portafoglio scelto. Restituisce i movimenti creati, per poterli annullare.
    @discardableResult
    static func importRows(_ rows: [Row], into wallet: Wallet, in context: ModelContext) -> [Transaction] {
        let created = rows.filter(\.isSelected).map { row in
            let category = CategoryService.resolve(row.category, type: row.type, in: context)
            return Transaction(type: row.type, amount: abs(row.amount), date: row.date, category: category, title: row.description, wallet: wallet)
        }
        created.forEach { context.insert($0) }
        return created
    }
}

/// Indovina la categoria dalla descrizione: prima impara dai movimenti già registrati
/// (stessa parola chiave → stessa categoria), poi usa regole sulle parole più comuni.
struct CategoryGuesser {
    private var learned: [String: String] = [:]

    private static let rules: [(category: String, keywords: [String])] = [
        ("Alimentari", ["esselunga", "coop", "conad", "carrefour", "lidl", "eurospin", "pam ", "despar", "iper", "supermercat", "aldi", "penny", "bennet", "famila", "md ", "crai", "tigros", "unes"]),
        ("Trasporti", ["eni", "q8", "tamoil", "esso", "ip ", "agip", "carburant", "benzin", "trenitalia", "italo", "atm ", "atac", "gtt", "telepass", "autostrad", "parchegg", "uber", "taxi", "freenow", "ryanair", "easyjet", "ita airways"]),
        ("Casa", ["affitto", "condominio", "enel", "a2a", "hera", "iren", "acea", "edison", "bolletta", "gas ", "luce", "tim ", "vodafone", "wind", "iliad", "fastweb", "ikea", "leroy"]),
        ("Svago", ["netflix", "spotify", "disney", "prime video", "dazn", "cinema", "ristorante", "pizzeria", "trattoria", "bar ", "pub", "steam", "playstation", "ticketone"]),
        ("Salute", ["farmacia", "parafarmacia", "medic", "dentist", "ospedale", "asl", "ottica", "palestra", "fitness"]),
        ("Shopping", ["amazon", "zalando", "decathlon", "h&m", "zara", "mediaworld", "unieuro", "euronics", "apple.com", "shein"]),
        ("Stipendio", ["stipendio", "emolument", "salario", "busta paga", "retribuzion"]),
        ("Rimborso", ["rimborso", "storno", "refund"]),
    ]

    init(history: [Transaction]) {
        for transaction in history where !transaction.isTransfer {
            for word in Self.keywords(in: transaction.title) {
                learned[word] = transaction.category
            }
        }
    }

    func category(for description: String, type: TransactionType) -> String {
        for word in Self.keywords(in: description) {
            if let category = learned[word] { return category }
        }
        let text = " " + description.lowercased() + " "
        for rule in Self.rules where rule.keywords.contains(where: { text.contains($0) }) {
            let isIncomeCategory = rule.category == "Stipendio" || rule.category == "Rimborso"
            if isIncomeCategory == (type == .income) { return rule.category }
        }
        return "Altro"
    }

    /// Parole significative (almeno 4 lettere, non numeri né parole bancarie generiche).
    static func keywords(in text: String) -> [String] {
        let stop: Set<String> = ["pagamento", "carta", "bonifico", "addebito", "accredito", "presso", "operazione", "debito", "credito", "favore", "ordine", "disposizione", "sepa", "pos", "del", "con", "per", "visa", "mastercard", "contactless", "n.", "num"]
        return text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !stop.contains($0) && $0.contains(where: \.isLetter) }
    }
}

/// Ricorda colonne e portafoglio scelti per ogni formato di file (riconosciuto dall'intestazione),
/// così dal secondo import della stessa banca non serve controllare nulla.
struct BankImportMemory {
    struct Entry: Codable, Equatable {
        var mapping: BankImport.ColumnMapping
        var walletName: String?
    }

    static let key = "aurea.bankImport.formats"
    var defaults: UserDefaults = .standard

    static func signature(of header: [String]) -> String {
        header.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.joined(separator: "|")
    }

    private var all: [String: Entry] {
        guard let data = defaults.data(forKey: Self.key) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    func entry(for header: [String]) -> Entry? {
        all[Self.signature(of: header)]
    }

    func save(_ entry: Entry, for header: [String]) {
        var values = all
        values[Self.signature(of: header)] = entry
        if let data = try? JSONEncoder().encode(values) { defaults.set(data, forKey: Self.key) }
    }
}
