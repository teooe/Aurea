import SwiftData
import SwiftUI
import UIKit

/// Avviso "Movimento registrato · Annulla" mostrato per qualche secondo dopo un salvataggio.
/// Sostituisce il vecchio dialogo di conferma: salvare è immediato, correggere è un tocco.
@Observable
final class UndoBanner {
    static let shared = UndoBanner()
    static let duration: Duration = .seconds(5)

    struct Notice: Identifiable {
        let id = UUID()
        let message: String
        let transactions: [Transaction]
    }

    private(set) var notice: Notice?

    /// Mostra l'avviso per i movimenti appena salvati (due per un trasferimento).
    func post(_ transactions: [Transaction], message: String) {
        let notice = Notice(message: message, transactions: transactions)
        self.notice = notice
        UIAccessibility.post(notification: .announcement, argument: message)
        Task { @MainActor in
            try? await Task.sleep(for: Self.duration)
            // Un salvataggio successivo ha già sostituito l'avviso: non va chiuso quello nuovo.
            if self.notice?.id == notice.id { withAnimation { self.notice = nil } }
        }
    }

    func undo(in context: ModelContext) {
        guard let notice else { return }
        // Se nel frattempo il movimento è stato eliminato dal dettaglio, non c'è nulla da annullare.
        for transaction in notice.transactions where !transaction.isDeleted {
            context.delete(transaction)
        }
        try? context.save()
        self.notice = nil
    }

    func dismiss() {
        notice = nil
    }
}

struct UndoBannerView: View {
    @Environment(\.modelContext) private var modelContext
    let banner: UndoBanner

    var body: some View {
        if let notice = banner.notice {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(notice.message)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button("Annulla") {
                    withAnimation { banner.undo(in: modelContext) }
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(notice.id)
            .gesture(DragGesture(minimumDistance: 10).onEnded { value in
                if value.translation.height > 20 { withAnimation { banner.dismiss() } }
            })
        }
    }
}
