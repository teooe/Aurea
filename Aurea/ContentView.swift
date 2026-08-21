import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var relationships: [Relationship]
    @Query private var budgets: [Budget]
    @Query private var recurringTransactions: [RecurringTransaction]
    @Query private var transactions: [Transaction]

    @AppStorage("aurea.onboarding.completed") private var onboardingCompleted = false
    @AppStorage("aurea.appearance") private var appearanceRaw = AppAppearance.system.rawValue
    @State private var selection = 0
    @State private var previousSelection = 0
    @State private var showingQuickAdd = false

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }

    var body: some View {
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

            AgendaView(embedded: true)
                .tag(2)
                .tabItem { Label("Agenda", systemImage: "calendar") }

            AureaAssistantView()
                .tag(3)
                .tabItem { Label("Aurea", systemImage: "sparkles") }
        }
        .preferredColorScheme(appearance.colorScheme)
        .onChange(of: selection) { _, newValue in
            if newValue == 4 {
                showingQuickAdd = true
                selection = previousSelection
            } else {
                previousSelection = newValue
            }
        }
        .onAppear { refreshReminders() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshReminders() }
        }
        .sheet(isPresented: $showingQuickAdd) { GlobalQuickAddView() }
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompleted },
            set: { if !$0 { onboardingCompleted = true } }
        )) {
            OnboardingView()
        }
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
