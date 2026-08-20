import SwiftUI

struct EditAgendaItemView: View {
    @Environment(\.dismiss) private var dismiss
    let item: AgendaItem

    @State private var title: String
    @State private var note: String
    @State private var type: AgendaItemType
    @State private var date: Date
    @State private var hasTime: Bool
    @State private var repeatRule: AgendaRepeat
    @State private var reminder: Int

    init(item: AgendaItem) {
        self.item = item
        _title = State(initialValue: item.title)
        _note = State(initialValue: item.note)
        _type = State(initialValue: item.type)
        _date = State(initialValue: item.date)
        _hasTime = State(initialValue: item.hasTime)
        _repeatRule = State(initialValue: item.repeatRule)
        _reminder = State(initialValue: item.reminderMinutesBefore ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        ForEach(AgendaItemType.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Dettagli") {
                    TextField("Titolo", text: $title)
                    TextField("Note", text: $note, axis: .vertical)
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    Toggle("Orario", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Ora", selection: $date, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Ripetizione") {
                    Picker("Ripeti", selection: $repeatRule) {
                        ForEach(AgendaRepeat.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                }

                Section("Promemoria") {
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
                }
            }
            .navigationTitle("Modifica impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        item.type = type
        item.date = date
        item.hasTime = hasTime
        item.repeatRule = repeatRule
        item.reminderMinutesBefore = hasTime && reminder != 0 ? reminder : nil
        AgendaNotificationManager.schedule(for: item)
        dismiss()
    }
}
