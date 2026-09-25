import LocalAuthentication
import SwiftUI
import UIKit

/// Blocco dell'app con Face ID / Touch ID, con il codice del dispositivo come alternativa.
/// Quando è attivo, l'app si blocca andando in background e mostra una copertura
/// nel selettore delle app, così saldi e movimenti non restano visibili.
@Observable
final class AppLock {
    static let shared = AppLock()

    static let enabledKey = "aurea.security.lockEnabled"

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }
    /// Serve l'autenticazione per vedere l'app.
    private(set) var isLocked = false
    private(set) var isAuthenticating = false
    /// Face ID viene proposto da solo una volta per ogni ritorno nell'app: se l'utente annulla,
    /// l'app torna attiva e senza questo flag richiederebbe subito lo sblocco, all'infinito.
    private var shouldPromptAutomatically = false
    var lastError: String?

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    /// Nome del metodo di sblocco disponibile, per i testi dell'interfaccia.
    var methodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "codice"
        }
    }

    var methodIcon: String {
        switch methodName {
        case "Face ID": "faceid"
        case "Touch ID": "touchid"
        case "Optic ID": "opticid"
        default: "lock.open"
        }
    }

    /// Il dispositivo ha almeno un codice impostato (requisito per il blocco).
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    // MARK: - Ciclo di vita

    /// All'avvio: se il blocco è attivo si parte bloccati.
    func lockOnLaunch() {
        guard isEnabled else { return }
        isLocked = true
        shouldPromptAutomatically = true
        LockWindow.shared.show()
    }

    func handle(_ phase: ScenePhase) {
        guard isEnabled else { return }
        switch phase {
        case .background:
            isLocked = true
            shouldPromptAutomatically = true
            LockWindow.shared.show()
        case .inactive:
            // Centro di controllo, notifiche, selettore app, richiesta di Face ID: copri senza bloccare.
            LockWindow.shared.show()
        case .active:
            if !isLocked {
                LockWindow.shared.hide()
            } else if shouldPromptAutomatically {
                shouldPromptAutomatically = false
                Task { await unlock() }
            }
        @unknown default:
            break
        }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        if await authenticate(reason: "Sblocca Aurea per vedere i tuoi dati.") {
            isLocked = false
            lastError = nil
            LockWindow.shared.hide()
        }
    }

    /// Attiva o disattiva il blocco; in entrambi i casi chiede prima l'autenticazione.
    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }
        guard isAvailable else {
            lastError = "Imposta un codice sul dispositivo per usare il blocco."
            return
        }
        let reason = enabled ? "Conferma per attivare il blocco di Aurea." : "Conferma per disattivare il blocco di Aurea."
        if await authenticate(reason: reason) {
            isEnabled = enabled
            lastError = nil
        }
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Annulla"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel || error.code == .systemCancel {
            return false
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}

/// Finestra sopra tutto il resto, fogli aperti compresi: una copertura dentro ContentView
/// lascerebbe visibili i fogli presentati (es. Movimenti aperto dalla Home).
final class LockWindow {
    static let shared = LockWindow()
    private var window: UIWindow?

    func show() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState != .unattached }) else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let host = UIHostingController(rootView: LockScreenView(lock: AppLock.shared))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = false
        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window = nil
    }
}

struct LockScreenView: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial).ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Aurea")
                    .font(.largeTitle.bold())

                if lock.isLocked {
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("Sblocca con \(lock.methodName)", systemImage: lock.methodIcon)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(lock.isAuthenticating)

                    if let error = lock.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
        }
        .animation(.default, value: lock.isLocked)
    }
}
