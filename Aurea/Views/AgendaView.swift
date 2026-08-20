import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AgendaItem.date) private var items: [AgendaItem]
    @State private var showingAdd = false
    @State private var selectedItem: AgendaItem?
    @State private var selectedDate = Date()

    private var dayItems: [AgendaItem] {
        items.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var activeDayItems: [AgendaItem] { dayItems.filter { !$0.isCompleted } }
    private var completedDayItems: [AgendaItem] { dayItems.filter { $0.isCompleted } }

    private var upcomingItems: [AgendaItem] {
        items.filter { $0.date > Calendar.current.endOfDay(for: selectedDate) && !$0.isCompleted }
            .prefix(8).map { $0 }
    }

    private var selectedDayTitle: String {
        Calendar.current.isDateInToday(selectedDate) ? "Oggi" : selectedDate.formatted(date: .complete, time: .omitted)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Giorno", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                Section {
                    if activeDayItems.isEmpty {
                        ContentUnavailableView("Nessun impegno", systemImage: "calendar.badge.checkmark", description: Text("Non ci sono attività aperte per questa giornata."))
                    } else {
                        ForEach(activeDayItems) { agendaRow($0) }
                    }
                } header: {
                    Text(selectedDayTitle)
                }

                if !completedDayItems.isEmpty {
                    Section {
                        ForEach(completedDayItems) { agendaRow($0) }
                    } header: {
                        Text("Completati")
                    }
                }

                if Calendar.current.isDateInToday(selectedDate) && !upcomingItems.isEmpty {
                    Section {
                        ForEach(upcomingItems) { agendaRow($0) }
                    } header: {
                        Text("Prossimamente")
                    }
                }
            }
            .navigationTitle("Agenda")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { AddAgendaItemView(defaultDate: selectedDate) }
            .sheet(item: $selectedItem) { AgendaItemDetailView(item: $0) }
            .onAppear {
                AgendaNotificationManager.requestAuthorization()
                normalizeRecurringEvents()
            }
        }
    }

    private func agendaRow(_ item: AgendaItem) -> some View {
        Button { selectedItem = item } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : item.type.icon)
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .fontWeight(.medium)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)

                    HStack(spacing: 5) {
                        Text(item.type.title)
                        if item.hasTime {
                            Text("•")
                            Text(item.date.formatted(date: .omitted, time: .shortened))
                        }
                        if item.repeatRule != .never { Image(systemName: "repeat") }
                        if item.reminderMinutesBefore != nil && item.hasTime { Image(systemName: "bell") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func normalizeRecurringEvents() {
        for item in items where item.type == .event && item.repeatRule != .never && item.date < Date() {
            var next = item.date
            while next < Date() { next = item.repeatRule.nextDate(after: next) }
            item.date = next
            AgendaNotificationManager.schedule(for: item)
        }
    }
}

struct AddAgendaItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let defaultDate: Date

    @State private var title = ""
    @State private var note = ""
    @State private var type: AgendaItemType = .task
    @State private var date: Date
    @State private var hasTime = false
    @State private var repeatRule: AgendaRepeat = .never
    @State private var reminder = 0

    init(defaultDate: Date = .now) {
        self.defaultDate = defaultDate
        _date = State(initialValue: defaultDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        ForEach(AgendaItemType.allCases) { value in
                            Label(value.title, systemImage: value.icon).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Dettagli") {
                    TextField("Titolo", text: $title)
                    TextField("Note (opzionale)", text: $note, axis: .vertical)
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    Toggle("Orario", isOn: $hasTime)
                    if hasTime { DatePicker("Ora", selection: $date, displayedComponents: .hourAndMinute) }
                }

                Section("Ripetizione") {
                    Picker("Ripeti", selection: $repeatRule) {
                        ForEach(AgendaRepeat.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section {
                    Picker("Avviso", selection: $reminder) {
                        Text("Nessuno").tag(0)
                        Text("All'ora dell'impegno").tag(1)
                        Text("5 minuti prima").tag(5)
                        Text("15 minuti prima").tag(15)
                        Text("30 minuti prima").tag(30)
                        Text("1 ora prima").tag(60)
                        Text("1 giorno prima").tag(1440)
                    }
                    .disabled(!hasTime)
                } header: {
                    Text("Promemoria")
                } footer: {
                    Text(hasTime ? "Aurea programmerà una notifica locale sul dispositivo." : "Attiva Orario per impostare un promemoria.")
                }
            }
            .navigationTitle("Nuovo impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let item = AgendaItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            date: date,
            hasTime: hasTime,
            repeatRule: repeatRule,
            reminderMinutesBefore: hasTime && reminder != 0 ? reminder : nil
        )
        modelContext.insert(item)
        AgendaNotificationManager.schedule(for: item)
        dismiss()
    }
}

struct AgendaItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let item: AgendaItem
    @State private var showingEdit = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Impegno") {
                    LabeledContent("Tipo", value: item.type.title)
                    LabeledContent("Titolo", value: item.title)
                    LabeledContent("Data", value: item.hasTime ? item.date.formatted(date: .long, time: .shortened) : item.date.formatted(date: .long, time: .omitted))
                    if !item.note.isEmpty { LabeledContent("Note", value: item.note) }
                    if item.repeatRule != .never { LabeledContent("Ripetizione", value: item.repeatRule.title) }
                }

                Section {
                    Button { showingEdit = true } label: { Label("Modifica impegno", systemImage: "pencil") }
                }

                if item.type == .task || item.type == .deadline {
                    Section {
                        Button { toggleCompletion() } label: {
                            Label(completionTitle, systemImage: item.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        AgendaNotificationManager.remove(for: item)
                        modelContext.delete(item)
                        dismiss()
                    } label: { Label("Elimina", systemImage: "trash") }
                }
            }
            .navigationTitle("Dettaglio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
            .sheet(isPresented: $showingEdit) { EditAgendaItemView(item: item) }
        }
    }

    private var completionTitle: String {
        if item.isCompleted { return "Segna da fare" }
        return item.repeatRule == .never ? "Segna come completato" : "Completa e passa alla prossima"
    }

    private func toggleCompletion() {
        if item.isCompleted {
            item.isCompleted = false
            AgendaNotificationManager.schedule(for: item)
        } else if item.repeatRule != .never {
            item.date = item.repeatRule.nextDate(after: item.date)
            AgendaNotificationManager.schedule(for: item)
        } else {
            item.isCompleted = true
            AgendaNotificationManager.remove(for: item)
        }
    }
}

extension AgendaRepeat {
    func nextDate(after date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .never: return date
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}

private extension Calendar {
    func endOfDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        return self.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? start
    }
}
