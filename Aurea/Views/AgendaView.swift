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

    private var upcomingItems: [AgendaItem] {
        items.filter { $0.date > Calendar.current.startOfDay(for: selectedDate) && !Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && !$0.isCompleted }
            .prefix(8).map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Giorno", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                Section(Calendar.current.isDateInToday(selectedDate) ? "Oggi" : selectedDate.formatted(date: .complete, time: .omitted)) {
                    if dayItems.isEmpty {
                        ContentUnavailableView("Nessun impegno", systemImage: "calendar.badge.checkmark", description: Text("La giornata è libera."))
                    } else {
                        ForEach(dayItems) { item in
                            agendaRow(item)
                        }
                    }
                }

                if Calendar.current.isDateInToday(selectedDate) && !upcomingItems.isEmpty {
                    Section("Prossimamente") {
                        ForEach(upcomingItems) { item in
                            agendaRow(item)
                        }
                    }
                }
            }
            .navigationTitle("Agenda")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddAgendaItemView(defaultDate: selectedDate)
            }
            .sheet(item: $selectedItem) { item in
                AgendaItemDetailView(item: item)
            }
        }
    }

    private func agendaRow(_ item: AgendaItem) -> some View {
        Button {
            selectedItem = item
        } label: {
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
                        if item.repeatRule != .never {
                            Image(systemName: "repeat")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                        .lineLimit(2...5)
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
                } footer: {
                    Text("In questa prima versione Aurea salva la preferenza del promemoria. Le notifiche di sistema verranno collegate nel prossimo passaggio.")
                }
            }
            .navigationTitle("Nuovo impegno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        let item = AgendaItem(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            type: type,
                            date: date,
                            hasTime: hasTime,
                            repeatRule: repeatRule,
                            reminderMinutesBefore: reminder == 0 ? nil : reminder
                        )
                        modelContext.insert(item)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct AgendaItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let item: AgendaItem

    var body: some View {
        NavigationStack {
            Form {
                Section("Impegno") {
                    LabeledContent("Tipo", value: item.type.title)
                    LabeledContent("Titolo", value: item.title)
                    LabeledContent("Data", value: item.date.formatted(date: .long, time: item.hasTime ? .shortened : .omitted))
                    if !item.note.isEmpty { LabeledContent("Note", value: item.note) }
                    if item.repeatRule != .never { LabeledContent("Ripetizione", value: item.repeatRule.title) }
                    if let reminder = item.reminderMinutesBefore {
                        LabeledContent("Promemoria", value: reminderText(reminder))
                    }
                }

                if item.type == .task || item.type == .deadline {
                    Section {
                        Button {
                            item.isCompleted.toggle()
                        } label: {
                            Label(item.isCompleted ? "Segna da fare" : "Segna come completato", systemImage: item.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        modelContext.delete(item)
                        dismiss()
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Dettaglio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
            }
        }
    }

    private func reminderText(_ minutes: Int) -> String {
        if minutes == 1 { return "All'ora dell'impegno" }
        if minutes == 60 { return "1 ora prima" }
        if minutes == 1440 { return "1 giorno prima" }
        return "\(minutes) minuti prima"
    }
}
