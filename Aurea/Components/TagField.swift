import SwiftUI

/// Campo per le etichette di un movimento, con le etichette recenti da aggiungere con un tocco.
struct TagField: View {
    @Binding var text: String
    let suggestions: [String]

    private var current: [String] { Transaction.parseTags(text) }
    private var available: [String] {
        let used = Set(current.map { $0.lowercased() })
        return suggestions.filter { !used.contains($0.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Etichette (es. Vacanza Sicilia)", text: $text)
                .textInputAutocapitalization(.sentences)
            if !available.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(available, id: \.self) { tag in
                            Button {
                                text = (current + [tag]).joined(separator: ", ")
                            } label: {
                                Label(tag, systemImage: "tag")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}
