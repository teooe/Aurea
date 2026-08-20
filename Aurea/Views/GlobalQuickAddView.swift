import SwiftUI

struct GlobalQuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingTransaction = false
    @State private var showingAgendaItem = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingTransaction = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "eurosign.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Movimento")
                                    .fontWeight(.semibold)
                                Text("Spesa, entrata o trasferimento")
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

                    Button {
                        showingAgendaItem = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Impegno")
                                    .fontWeight(.semibold)
                                Text("Attività, evento o scadenza")
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
                } header: {
                    Text("Aggiungi")
                }
            }
            .navigationTitle("Nuovo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTransaction) {
                QuickAddView()
            }
            .sheet(isPresented: $showingAgendaItem) {
                AddAgendaItemView()
            }
        }
    }
}
