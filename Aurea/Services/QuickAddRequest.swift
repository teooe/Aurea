import Observation

/// Richiesta di aprire il modulo "Nuovo movimento" arrivata da fuori (Comandi rapidi).
@Observable
final class QuickAddRequest {
    static let shared = QuickAddRequest()
    var isPending = false
}
