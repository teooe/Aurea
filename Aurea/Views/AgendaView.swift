import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AgendaItem.date) private var items: [AgendaItem]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAdd = false
    @State private var selectedItem: AgendaItem?
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var filter: AgendaFilter = .all
    @State private var searchText = ""
    let embedded: Bool
    init(embedded: Bool = false) { self.embedded = embedded }

    private var filteredItems: [AgendaItem] { items.filter { filter.matches($0) && (searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) || $0.note.localizedCaseInsensitiveContains(searchText)) } }
    private var searchResults: [AgendaItem] { filteredItems.sorted(by: agendaSort) }
    private var dayItems: [AgendaItem] { filteredItems.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    private var activeDayItems: [AgendaItem] { dayItems.filter { !$0.isCompleted }.sorted(by: agendaSort) }
    private var completedDayItems: [AgendaItem] { dayItems.filter { $0.isCompleted } }
    private var overdueItems: [AgendaItem] { guard Calendar.current.isDateInToday(selectedDate) else { return [] }; let start = Calendar.current.startOfDay(for: .now); return filteredItems.filter { $0.date < start && !$0.isCompleted && ($0.type == .task || $0.type == .deadline) }.sorted(by: agendaSort) }
    private var upcomingItems: [AgendaItem] { Array(filteredItems.filter { $0.date > Calendar.current.endOfDay(for: selectedDate) && !$0.isCompleted }.sorted(by: agendaSort).prefix(8)) }
    private var dayTransactions: [Transaction] { transactions.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } }
    private var dayIncome: Decimal { dayTransactions.filter { $0.type == .income && $0.category != "Trasferimento" }.reduce(0) { $0 + $1.amount } }
    private var dayExpenses: Decimal { dayTransactions.filter { $0.type == .expense && $0.category != "Trasferimento" }.reduce(0) { $0 + $1.amount } }
    private var selectedDayTitle: String { Calendar.current.isDateInToday(selectedDate) ? "Oggi" : selectedDate.formatted(date: .complete, time: .omitted) }
    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            List {
                if isSearching { searchSection } else { agendaSections }
            }
            .searchable(text: $searchText, prompt: "Cerca in tutta l'agenda")
            .navigationTitle("Agenda")
            .toolbar {
                if !embedded { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
                ToolbarItem(placement: .primaryAction) { Button { showingAdd = true } label: { Image(systemName: "plus") } }
            }
            .sheet(isPresented: $showingAdd) { AddAgendaItemView(defaultDate: selectedDate) }
            .sheet(item: $selectedItem) { AgendaItemDetailView(item: $0) }
            .onAppear { displayedMonth = selectedDate; AgendaNotificationManager.requestAuthorization(); normalizeRecurringEvents() }
            .onChange(of: selectedDate) { _, newValue in displayedMonth = newValue }
        }
    }

    @ViewBuilder private var searchSection: some View {
        Section("Risultati") {
            if searchResults.isEmpty { ContentUnavailableView("Nessun risultato", systemImage: "magnifyingglass", description: Text("Nessun impegno corrisponde alla ricerca.")) }
            else { ForEach(searchResults) { item in Button { selectedDate = item.date; displayedMonth = item.date; selectedItem = item } label: { HStack { agendaRowContent(item); Spacer(); VStack(alignment: .trailing, spacing: 2) { Text(item.date.formatted(date: .abbreviated, time: .omitted)).font(.caption); if item.hasTime { Text(timeText(for: item)).font(.caption2) } }.foregroundStyle(.secondary) } }.buttonStyle(.plain) } }
        }
    }

    @ViewBuilder private var agendaSections: some View {
        Section {
            HStack { Button { moveDay(-1) } label: { Image(systemName: "chevron.left") }; Spacer(); Button("Oggi") { goToToday() }.fontWeight(.semibold); Spacer(); Button { moveDay(1) } label: { Image(systemName: "chevron.right") } }.buttonStyle(.borderless)
            DatePicker("Giorno", selection: $selectedDate, displayedComponents: .date).datePickerStyle(.graphical).id(monthKey)
        }
        Section { Picker("Filtro", selection: $filter) { ForEach(AgendaFilter.allCases) { Label($0.title, systemImage: $0.icon).tag($0) } }.pickerStyle(.menu) }
        Section { HStack(spacing: 16) { dayMetric(title: "Impegni", value: "\(activeDayItems.count)"); Divider().frame(height: 34); dayMetric(title: "Entrate", value: dayIncome.formatted(.currency(code: "EUR"))); Divider().frame(height: 34); dayMetric(title: "Spese", value: dayExpenses.formatted(.currency(code: "EUR"))) } } header: { Text("Riepilogo del giorno") }
        if !overdueItems.isEmpty { Section { ForEach(overdueItems) { agendaRow($0) } } header: { Label("Da recuperare", systemImage: "exclamationmark.triangle") } footer: { Text("Attività e scadenze dei giorni precedenti ancora aperte.") } }
        Section { if activeDayItems.isEmpty { ContentUnavailableView("Nessun impegno", systemImage: "calendar.badge.checkmark", description: Text("Non ci sono attività aperte per questa giornata.")) } else { ForEach(activeDayItems) { agendaRow($0) } } } header: { Text(selectedDayTitle) }
        if !completedDayItems.isEmpty { Section { ForEach(completedDayItems) { agendaRow($0) } } header: { Text("Completati") } }
        if Calendar.current.isDateInToday(selectedDate) && !upcomingItems.isEmpty { Section { ForEach(upcomingItems) { agendaRow($0) } } header: { Text("Prossimamente") } }
    }

    private var monthKey: String { let c = Calendar.current.dateComponents([.year,.month], from: displayedMonth); return "\(c.year ?? 0)-\(c.month ?? 0)" }
    private func moveDay(_ amount: Int) { if let d = Calendar.current.date(byAdding: .day, value: amount, to: selectedDate) { selectedDate = d; displayedMonth = d } }
    private func goToToday() { selectedDate = .now; displayedMonth = .now }
    private func agendaSort(_ lhs: AgendaItem, _ rhs: AgendaItem) -> Bool { if lhs.hasTime != rhs.hasTime { return lhs.hasTime }; if lhs.hasTime && rhs.hasTime && lhs.date != rhs.date { return lhs.date < rhs.date }; let rank: [AgendaPriority:Int] = [.high:0,.normal:1,.low:2]; if lhs.priority != rhs.priority { return (rank[lhs.priority] ?? 1) < (rank[rhs.priority] ?? 1) }; return lhs.date < rhs.date }
    private func dayMetric(title: String, value: String) -> some View { VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7) }.frame(maxWidth: .infinity, alignment: .leading) }
    private func agendaRow(_ item: AgendaItem) -> some View { Button { selectedItem = item } label: { HStack { agendaRowContent(item); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }.contentShape(Rectangle()) }.buttonStyle(.plain) }
    private func agendaRowContent(_ item: AgendaItem) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                if item.hasTime { Text(item.date.formatted(date: .omitted, time: .shortened)).font(.caption.weight(.semibold)).monospacedDigit() }
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : item.type.icon).font(.title3).foregroundStyle(item.isCompleted ? .secondary : .primary)
            }.frame(width: 52)
            VStack(alignment: .leading, spacing: 3) {
                HStack { Text(item.title).fontWeight(.medium).strikethrough(item.isCompleted); if item.priority == .high && !item.isCompleted { Image(systemName: "exclamationmark.circle.fill").font(.caption) } }
                HStack(spacing: 5) { Text(item.type.title); if item.hasTime { Text("•"); Text(timeText(for: item)) }; if item.repeatRule != .never { Image(systemName: "repeat") }; if item.reminderMinutesBefore != nil && item.hasTime { Image(systemName: "bell") }; if item.priority != .normal { Text("• \(item.priority.title)") } }.font(.caption).foregroundStyle(.secondary)
            }.foregroundStyle(item.isCompleted ? .secondary : .primary)
        }
    }
    private func timeText(for item: AgendaItem) -> String { guard item.hasTime else { return "Tutto il giorno" }; let start = item.date.formatted(date: .omitted, time: .shortened); guard item.type == .event, let end = item.endDate else { return start }; return "\(start)–\(end.formatted(date: .omitted, time: .shortened))" }
    private func normalizeRecurringEvents() { for item in items where item.type == .event && item.repeatRule != .never && item.date < Date() { let duration = item.endDate?.timeIntervalSince(item.date); var next = item.date; while next < Date() { next = item.repeatRule.nextDate(after: next) }; item.date = next; if let duration { item.endDate = next.addingTimeInterval(duration) }; AgendaNotificationManager.schedule(for: item) } }
}

private enum AgendaFilter: String, CaseIterable, Identifiable {
    case all, task, event, deadline
    var id: String { rawValue }
    var title: String { switch self { case .all:return "Tutto"; case .task:return "Attività"; case .event:return "Eventi"; case .deadline:return "Scadenze" } }
    var icon: String { switch self { case .all:return "line.3.horizontal.decrease.circle"; case .task:return "checkmark.circle"; case .event:return "calendar"; case .deadline:return "exclamationmark.circle" } }
    func matches(_ item: AgendaItem) -> Bool { switch self { case .all:return true; case .task:return item.type == .task; case .event:return item.type == .event; case .deadline:return item.type == .deadline } }
}

struct AddAgendaItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let defaultDate: Date
    @State private var title = ""; @State private var note = ""; @State private var type: AgendaItemType = .task; @State private var date: Date; @State private var hasTime = false; @State private var hasEndTime = false; @State private var endDate: Date; @State private var repeatRule: AgendaRepeat = .never; @State private var reminder = 0; @State private var priority: AgendaPriority = .normal
    init(defaultDate: Date = .now) { self.defaultDate = defaultDate; _date = State(initialValue: defaultDate); _endDate = State(initialValue: defaultDate.addingTimeInterval(3600)) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") { Picker("Tipo", selection: $type) { ForEach(AgendaItemType.allCases) { Label($0.title, systemImage: $0.icon).tag($0) } }.pickerStyle(.segmented) }
                Section("Dettagli") {
                    TextField("Titolo", text: $title); TextField("Note (opzionale)", text: $note, axis: .vertical); DatePicker("Data", selection: $date, displayedComponents: .date); Toggle("Orario", isOn: $hasTime)
                    if hasTime { DatePicker(type == .event ? "Inizio" : "Ora", selection: $date, displayedComponents: .hourAndMinute); if type == .event { Toggle("Ora di fine", isOn: $hasEndTime); if hasEndTime { DatePicker("Fine", selection: $endDate, in: date..., displayedComponents: [.date,.hourAndMinute]) } } }
                    Picker("Priorità", selection: $priority) { ForEach(AgendaPriority.allCases) { Text($0.title).tag($0) } }
                }
                Section("Ripetizione") { Picker("Ripeti", selection: $repeatRule) { ForEach(AgendaRepeat.allCases) { Text($0.title).tag($0) } } }
                Section { Picker("Avviso", selection: $reminder) { Text("Nessuno").tag(0); Text("All'ora dell'impegno").tag(1); Text("5 minuti prima").tag(5); Text("15 minuti prima").tag(15); Text("30 minuti prima").tag(30); Text("1 ora prima").tag(60); Text("1 giorno prima").tag(1440) }.disabled(!hasTime) } header: { Text("Promemoria") }
            }
            .navigationTitle("Nuovo impegno").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Salva") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
            .onChange(of: date) { oldValue, newValue in if hasEndTime && endDate < newValue { endDate = newValue.addingTimeInterval(3600) } else if hasEndTime { endDate = endDate.addingTimeInterval(newValue.timeIntervalSince(oldValue)) } }
            .onChange(of: type) { _, newType in if newType != .event { hasEndTime = false } }
        }
    }
    private func save() { let item = AgendaItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines), note: note.trimmingCharacters(in: .whitespacesAndNewlines), type: type, date: date, hasTime: hasTime, endDate: type == .event && hasTime && hasEndTime ? endDate : nil, repeatRule: repeatRule, reminderMinutesBefore: hasTime && reminder != 0 ? reminder : nil, priority: priority); modelContext.insert(item); AgendaNotificationManager.schedule(for: item); dismiss() }
}

struct AgendaItemDetailView: View {
    @Environment(\.dismiss) private var dismiss; @Environment(\.modelContext) private var modelContext; let item: AgendaItem; @State private var showingEdit = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Impegno") {
                    LabeledContent("Tipo", value: item.type.title); LabeledContent("Titolo", value: item.title)
                    LabeledContent("Data", value: item.date.formatted(date: .long, time: .omitted))
                    if item.hasTime { LabeledContent(item.type == .event && item.endDate != nil ? "Orario" : "Ora", value: timeText) }
                    if item.type == .event, let end = item.endDate, !Calendar.current.isDate(end, inSameDayAs: item.date) { LabeledContent("Fine", value: end.formatted(date: .long, time: .shortened)) }
                    LabeledContent("Priorità", value: item.priority.title); if !item.note.isEmpty { LabeledContent("Note", value: item.note) }; if item.repeatRule != .never { LabeledContent("Ripetizione", value: item.repeatRule.title) }
                }
                Section { Button { showingEdit = true } label: { Label("Modifica impegno", systemImage: "pencil") } }
                if item.type == .task || item.type == .deadline { Section { Button { toggleCompletion() } label: { Label(completionTitle, systemImage: item.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle") } } }
                Section { Button(role: .destructive) { AgendaNotificationManager.remove(for: item); modelContext.delete(item); dismiss() } label: { Label("Elimina", systemImage: "trash") } }
            }
            .navigationTitle("Dettaglio").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
            .sheet(isPresented: $showingEdit) { EditAgendaItemView(item: item) }
        }
    }
    private var timeText: String { let start = item.date.formatted(date: .omitted, time: .shortened); guard let end = item.endDate else { return start }; return "\(start)–\(end.formatted(date: .omitted, time: .shortened))" }
    private var completionTitle: String { item.isCompleted ? "Segna da fare" : (item.repeatRule == .never ? "Segna come completato" : "Completa e passa alla prossima") }
    private func toggleCompletion() { if item.isCompleted { item.isCompleted = false; AgendaNotificationManager.schedule(for: item) } else if item.repeatRule != .never { var next = item.repeatRule.nextDate(after: item.date); while next <= Date() { next = item.repeatRule.nextDate(after: next) }; item.date = next; AgendaNotificationManager.schedule(for: item) } else { item.isCompleted = true; AgendaNotificationManager.remove(for: item) } }
}

extension AgendaRepeat { func nextDate(after date: Date) -> Date { let c = Calendar.current; switch self { case .never:return date; case .daily:return c.date(byAdding:.day,value:1,to:date) ?? date; case .weekly:return c.date(byAdding:.weekOfYear,value:1,to:date) ?? date; case .monthly:return c.date(byAdding:.month,value:1,to:date) ?? date; case .yearly:return c.date(byAdding:.year,value:1,to:date) ?? date } } }
private extension Calendar { func endOfDay(for date: Date) -> Date { let start = startOfDay(for: date); return self.date(byAdding:.day,value:1,to:start)?.addingTimeInterval(-1) ?? start } }
