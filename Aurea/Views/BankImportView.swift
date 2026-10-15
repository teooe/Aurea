import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Import dei movimenti dal CSV della banca: scelta del file, controllo delle colonne,
/// anteprima con categorie modificabili e duplicati esclusi, poi import nel portafoglio scelto.
struct BankImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Wallet.name) private var wallets: [Wallet]
    @Query(sort: \FinanceCategory.name) private var categories: [FinanceCategory]

    @State private var showingImporter = false
    @State private var fileName: String?
    @State private var table: BankImport.Table?
    @State private var mapping = BankImport.ColumnMapping()
    /// Importo in due colonne (uscite e entrate) invece che in una sola con il segno.
    @State private var separateColumns = false
    @State private var rows: [BankImport.Row] = []
    @State private var wallet: Wallet?
    @State private var errorMessage: String?

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }
    private var selectedCount: Int { rows.filter(\.isSelected).count }
    private var duplicateCount: Int { rows.filter(\.isDuplicate).count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingImporter = true
                    } label: {
                        Label(fileName ?? "Scegli il file CSV", systemImage: "doc.badge.arrow.up")
                    }
                } footer: {
                    Text("Dall'home banking esporta la lista movimenti in formato CSV (se c'è solo Excel, aprilo e salvalo come CSV). Aurea riconosce da sola le colonne delle principali banche; puoi correggerle qui sotto.")
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }

                if let table {
                    mappingSection(table)

                    Section("Portafoglio") {
                        Picker("Importa in", selection: $wallet) {
                            ForEach(activeWallets) { Text($0.name).tag($0 as Wallet?) }
                        }
                    }

                    previewSection
                }
            }
            .navigationTitle("Importa dalla banca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importa \(selectedCount)") { importSelected() }
                        .fontWeight(.semibold)
                        .disabled(selectedCount == 0 || wallet == nil)
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text]) { result in
                load(result)
            }
            .onAppear { wallet = wallet ?? activeWallets.first }
            .onChange(of: mapping) { _, _ in rebuildRows() }
        }
    }

    // MARK: - Sezioni

    private func mappingSection(_ table: BankImport.Table) -> some View {
        Section {
            columnPicker("Data", selection: $mapping.date, header: table.header)
            columnPicker("Descrizione", selection: $mapping.description, header: table.header)
            Picker("Importo", selection: Binding(
                get: { separateColumns },
                set: { separate in
                    separateColumns = separate
                    if separate { mapping.amount = nil } else { mapping.debit = nil; mapping.credit = nil }
                }
            )) {
                Text("Una colonna").tag(false)
                Text("Uscite e entrate").tag(true)
            }
            .pickerStyle(.segmented)
            if !separateColumns {
                columnPicker("Importo (con segno)", selection: $mapping.amount, header: table.header)
            } else {
                columnPicker("Uscite / addebiti", selection: $mapping.debit, header: table.header)
                columnPicker("Entrate / accrediti", selection: $mapping.credit, header: table.header)
            }
        } header: {
            Text("Colonne")
        } footer: {
            if !mapping.isUsable {
                Text("Indica almeno la colonna della data e quella dell'importo.").foregroundStyle(.red)
            } else {
                Text("\(table.rows.count) righe nel file.")
            }
        }
    }

    private func columnPicker(_ title: String, selection: Binding<Int?>, header: [String]) -> some View {
        Picker(title, selection: selection) {
            Text("—").tag(nil as Int?)
            ForEach(header.indices, id: \.self) { index in
                Text(header[index].isEmpty ? "Colonna \(index + 1)" : header[index]).tag(index as Int?)
            }
        }
    }

    @ViewBuilder private var previewSection: some View {
        Section {
            if rows.isEmpty {
                Text(mapping.isUsable ? "Nessun movimento riconosciuto con queste colonne." : "Completa le colonne per vedere l'anteprima.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach($rows) { $row in
                    previewRow($row)
                }
            }
        } header: {
            Text("Anteprima")
        } footer: {
            if duplicateCount > 0 {
                Text("\(duplicateCount) movimenti sembrano già registrati (stesso importo, stessa data o il giorno prima/dopo) e sono esclusi: attivali se vuoi importarli comunque.")
            }
        }
    }

    private func previewRow(_ row: Binding<BankImport.Row>) -> some View {
        let value = row.wrappedValue
        let type = value.type
        return HStack(alignment: .top, spacing: 12) {
            Button {
                row.wrappedValue.isSelected.toggle()
            } label: {
                Image(systemName: value.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(value.isSelected ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(value.isSelected ? "Escludi" : "Includi")

            VStack(alignment: .leading, spacing: 3) {
                Text(value.description).lineLimit(2)
                HStack(spacing: 6) {
                    Text(value.date.formatted(date: .abbreviated, time: .omitted))
                    Menu {
                        ForEach(categories.filter { $0.type == type && !$0.isArchived }) { category in
                            Button(category.name) { row.wrappedValue.category = category.name }
                        }
                    } label: {
                        Text(value.category).underline()
                    }
                    if value.isDuplicate {
                        Text("Già presente").foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value.amount.formatted(.currency(code: wallet?.currencyCode ?? "EUR")))
                .fontWeight(.medium)
                .foregroundStyle(value.amount < 0 ? Theme.Colors.expense : Theme.Colors.income)
        }
        .opacity(value.isSelected ? 1 : 0.5)
    }

    // MARK: - Azioni

    private func load(_ result: Result<URL, Error>) {
        errorMessage = nil
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            // Molte banche italiane esportano ancora in Windows-1252 invece che in UTF-8.
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252),
                  let parsed = BankImport.table(from: text) else {
                errorMessage = "Il file non sembra un CSV leggibile."
                return
            }
            fileName = url.lastPathComponent
            table = parsed
            mapping = BankImport.ColumnMapping.guess(header: parsed.header)
            separateColumns = mapping.amount == nil && (mapping.debit != nil || mapping.credit != nil)
            rebuildRows()
            if !mapping.isUsable {
                errorMessage = "Non ho riconosciuto tutte le colonne: indicale qui sotto."
            }
        } catch {
            errorMessage = "Impossibile aprire il file: \(error.localizedDescription)"
        }
    }

    private func rebuildRows() {
        guard let table, mapping.isUsable else { rows = []; return }
        rows = BankImport.rows(from: table, mapping: mapping, existing: transactions)
    }

    private func importSelected() {
        guard let wallet else { return }
        let created = BankImport.importRows(rows, into: wallet, in: modelContext)
        try? modelContext.save()
        UndoBanner.shared.post(created, message: "Importati \(created.count) movimenti in \(wallet.name)")
        dismiss()
    }
}
