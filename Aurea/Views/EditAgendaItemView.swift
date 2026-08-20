import SwiftUI

struct EditAgendaItemView: View {
    @Environment(\.dismiss) private var dismiss
    let item: AgendaItem
    @State private var title: String
    @State private var note: String
    @State private var type: AgendaItemType
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var hasEndTime: Bool
    @State private var endDate: Date
    @State private var repeatRule: AgendaRepeat
    @State private var reminder: Int
    @State private var priority: AgendaPriority

    init(item: AgendaItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _note = State(initialValue: item.note)
        _type = State(initialValue: item.type)
        _date = State(initialValue: item.date)
        _hasTime = State(initialValue: item.hasTime)
        _hasEndTime = State(initialValue: item.endDate != nil)
        _endDate = State(initialValue: item.endDate ?? item.date.addingTimeInterval(3600))
        _repeatRule = State(initialValue: item.repeatRule)
        _reminder = State(initialValue: item.reminderMinutesBefore ?? 0)
        _priority = State(initialValue: item.priority)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") { Picker("Tipo", selection: $type) { ForEach(AgendaItemType.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented) }
                Section("Dettagli") {
                    TextField("Titolo", text: $title)
                    TextField("Note", text: $note, axis: .vertical)
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    Toggle("Orario", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Inizio", selection: $date, displayedComponents: .hourAndMinute)
                        if type == .event {
                            Toggle("Ora di fine", isOn: $hasEndTime)
                            if hasEndTime { DatePicker("Fine", selection: $endDate, in: date..., displayedComponents: [.date, .hourAndMinute]) }
                        }
                    }
                    Picker("Priorità", selection: $priority) { ForEach(AgendaPriority.allCases) { Text($0.title).tag($0) } }
                }
                Section("Ripetizione") { Picker("Ripeti", selection: $repeatRule) { ForEach(AgendaRepeat.allCases) { Text($0.title).tag($0) } } }
                Section("Promemoria") { Picker("Avviso", selection: $reminder) { Text("Nessuno").tag(0); Text("All'ora dell'impegno").tag(1); Text("5 minuti prima").tag(5); Text("15 minuti prima").tag(15); Text("30 minuti prima").tag(30); Text("1 ora prima").tag(60); Text("1 giorno prima").tag(1440) }.disabled(!hasTime) }
            }
            .navigationTitle("Modifica impegno").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Salva") { save() }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
            .onChange(of: date) { oldValue, newValue in
                if hasEndTime && endDate < newValue { endDate = newValue.addingTimeInterval(3600) }
                else if hasEndTime { endDate = endDate.addingTimeInterval(newValue.timeIntervalSince(oldValue)) }
            }
            .onChange(of: type) { _, newType in if newType != .event { hasEndTime = false } }
        }
    }

    private func save() {
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        item.type = type
        item.date = date
        item.hasTime = hasTime
        item.endDate = type == .event && hasTime && hasEndTime ? endDate : nil
        item.repeatRule = repeatRule
        item.reminderMinutesBefore = hasTime && reminder != 0 ? reminder : nil
        item.priority = priority
        AgendaNotificationManager.schedule(for: item)
        dismiss()
    }
}
