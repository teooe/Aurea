import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var relationships: [Relationship]
    @Query private var budgets: [Budget]
    @Query private var recurringTransactions: [RecurringTransaction]
    @Query private var transactions: [Transaction]

    @AppStorage("aurea.onboarding.completed") private var onboardingCompleted = false
    @AppStorage("aurea.appearance") private var appearanceRaw = AppAppearance.system.rawValue
    @State private var selection = 0
    @State private var previousSelection = 0
    @State private var showingQuickAdd = false
    @State private var showingBrandSplash = true
    private let quickAddRequest = QuickAddRequest.shared

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }
    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-UITesting") }

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                HomeRootView()
                    .tag(0)
                    .tabItem { Label("Home", systemImage: "house") }

                TransactionsView()
                    .tag(1)
                    .tabItem { Label("Movimenti", systemImage: "arrow.left.arrow.right") }

                Color.clear
                    .tag(4)
                    .tabItem { Label("Aggiungi", systemImage: "plus.circle.fill") }

                AnalysisView()
                    .tag(3)
                    .tabItem { Label("Analisi", systemImage: "sparkles") }
            }
            .opacity(showingBrandSplash && !isUITesting ? 0 : 1)
            .overlay(alignment: .bottom) {
                // Sopra la barra dei tab: resta visibile anche dopo la chiusura del foglio "Nuovo movimento".
                UndoBannerView(banner: UndoBanner.shared)
                    .padding(.bottom, 64)
                    .animation(.spring(duration: 0.35), value: UndoBanner.shared.notice?.id)
            }

            if showingBrandSplash && !isUITesting {
                BrandSplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .background(KeyboardDismissInstaller())
        .preferredColorScheme(appearance.colorScheme)
        .onChange(of: selection) { _, newValue in
            if newValue == 4 {
                showingQuickAdd = true
                selection = previousSelection
            } else {
                previousSelection = newValue
            }
        }
        .onAppear {
            if isUITesting {
                onboardingCompleted = true
                showingBrandSplash = false
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    withAnimation(.easeOut(duration: 0.28)) {
                        showingBrandSplash = false
                    }
                }
            }
            if !isUITesting { AppLock.shared.lockOnLaunch() }
            refreshData()
        }
        .onChange(of: scenePhase) { _, phase in
            if !isUITesting { AppLock.shared.handle(phase) }
            switch phase {
            case .active: refreshData()
            // Uscendo dall'app il widget riceve i dati aggiornati con le modifiche appena fatte.
            case .background: WidgetSnapshotBuilder.refresh(in: modelContext)
            default: break
            }
        }
        .onChange(of: quickAddRequest.isPending, initial: true) { _, pending in
            if pending {
                showingQuickAdd = true
                quickAddRequest.isPending = false
            }
        }
        .onOpenURL { url in
            // Link del widget: aurea://nuovo-movimento
            if url.scheme == "aurea" && url.host() == "nuovo-movimento" {
                showingQuickAdd = true
            }
        }
        .sheet(isPresented: $showingQuickAdd) { QuickAddView() }
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompleted && !isUITesting && !showingBrandSplash },
            set: { if !$0 { onboardingCompleted = true } }
        )) {
            OnboardingView()
        }
    }

    private func refreshData() {
        CategoryService.synchronize(in: modelContext)
        RecurringEngine.generateDueTransactions(from: recurringTransactions, in: modelContext)
        WidgetSnapshotBuilder.refresh(in: modelContext)
        refreshReminders()
    }

    private func refreshReminders() {
        AppNotificationManager.refresh(
            relationships: relationships,
            recurring: recurringTransactions,
            budgets: budgets,
            transactions: transactions
        )
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> KeyboardDismissHostView {
        let view = KeyboardDismissHostView()
        view.onAttachedToWindow = { window in
            context.coordinator.install(in: window)
        }
        return view
    }

    func updateUIView(_ uiView: KeyboardDismissHostView, context: Context) {}

    static func dismantleUIView(_ uiView: KeyboardDismissHostView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var installedWindow: UIWindow?
        weak var tapGesture: UITapGestureRecognizer?

        func install(in window: UIWindow) {
            guard installedWindow !== window else { return }
            uninstall()

            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            installedWindow = window
            tapGesture = tap
        }

        func uninstall() {
            if let tapGesture, let installedWindow {
                installedWindow.removeGestureRecognizer(tapGesture)
            }
            tapGesture = nil
            installedWindow = nil
        }

        @objc private func dismissKeyboard() {
            installedWindow?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view: UIView? = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }
    }
}

private final class KeyboardDismissHostView: UIView {
    var onAttachedToWindow: ((UIWindow) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window { onAttachedToWindow?(window) }
    }
}

private struct HomeRootView: View {
    @State private var showingSettings = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HomeDashboardView()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.trailing, 18)
            .accessibilityLabel("Impostazioni")
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }
}

#Preview { ContentView() }
