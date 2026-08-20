import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection = 0
    @State private var showingQuickAdd = false

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tag(0)
                .tabItem { Label("Home", systemImage: "house") }

            TransactionsView()
                .tag(1)
                .tabItem { Label("Movimenti", systemImage: "arrow.left.arrow.right") }

            AgendaView(embedded: true)
                .tag(2)
                .tabItem { Label("Agenda", systemImage: "calendar") }

            AureaAIPlaceholderView()
                .tag(3)
                .tabItem { Label("Aurea", systemImage: "sparkles") }
        }
        .safeAreaInset(edge: .bottom) {
            Button { showingQuickAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 54, height: 54)
                    .background(.regularMaterial)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1) }
                    .shadow(radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 2)
        }
        .sheet(isPresented: $showingQuickAdd) { GlobalQuickAddView() }
    }
}

private struct HomeView: View {
    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Relationship.createdAt, order: .reverse) private var relationships: [Relationship]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \AgendaItem.date) private var agendaItems: [AgendaItem]

    @State private var showingAddWallet = false
    @State private var showingAddRelationship = false
    @State private var showingAddGoal = false
    @State private var showingTransactions = false
    @State private var showingFinanceCenter = false
    @State private var showingAgenda = false
    @State private var selectedRelationship: Relationship?
    @State private var selectedGoal: Goal?
    @State private var selectedWallet: Wallet?
    @State private var selectedTransaction: Transaction?
    @State private var expandedCard: HomeCard?

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }
    private var totalNetWorth: Decimal { FinancialEngine.netWorth(wallets: activeWallets) }
    private var todayTransactions: [Transaction] { TimelineEngine.transactionsForToday(from: transactions) }
    private var monthlyTransactions: [Transaction] { TimelineEngine.transactionsForCurrentMonth(from: transactions) }
    private var openTodayAgenda: [AgendaItem] {
        agendaItems.filter { Calendar.current.isDateInToday($0.date) && !$0.isCompleted }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: Theme.Spacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aurea")
                            .font(.largeTitle.bold())
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                NetWorthCardView(totalNetWorth: totalNetWorth, wallets: activeWallets, monthlyTransactions: monthlyTransactions, transactionCount: transactions.count, isExpanded: expandedCard == .netWorth) { toggleCard(.netWorth) }

                TodayCardView(transactions: todayTransactions, isExpanded: expandedCard == .today) { toggleCard(.today) } onSelectTransaction: { selectedTransaction = $0 } onShowAll: { showingTransactions = true }

                Button { showingAgenda = true } label: {
                    AureaCard(title: "Agenda", icon: "calendar.badge.clock") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(openTodayAgenda.isEmpty ? "Nessun impegno oggi" : "\(openTodayAgenda.count) \(openTodayAgenda.count == 1 ? "impegno" : "impegni") oggi")
                                    .fontWeight(openTodayAgenda.isEmpty ? .regular : .medium)
                                    .foregroundStyle(openTodayAgenda.isEmpty ? Theme.Colors.secondaryText : .primary)
                                if let next = openTodayAgenda.sorted(by: { $0.date < $1.date }).first {
                                    Text(next.hasTime ? "Prossimo: \(next.title) alle \(next.date.formatted(date: .omitted, time: .shortened))" : "Prossimo: \(next.title)")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                WalletsCardView(wallets: activeWallets, isExpanded: expandedCard == .wallets) { toggleCard(.wallets) } onAddWallet: { showingAddWallet = true } onSelectWallet: { selectedWallet = $0 }
                GoalsCardView(goals: goals, isExpanded: expandedCard == .goals) { toggleCard(.goals) } onAddGoal: { showingAddGoal = true } onSelectGoal: { selectedGoal = $0 }
                RelationshipsCardView(relationships: relationships, isExpanded: expandedCard == .relationships) { toggleCard(.relationships) } onAddRelationship: { showingAddRelationship = true } onSelectRelationship: { selectedRelationship = $0 }

                Button { showingFinanceCenter = true } label: {
                    HStack {
                        Label("Strumenti finanziari", systemImage: "chart.pie").fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Color.clear.frame(height: 90)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.top, Theme.Spacing.medium)
        }
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.always)
        .background(Theme.Colors.background.ignoresSafeArea())
        .animation(Theme.Animation.standard, value: expandedCard)
        .sheet(isPresented: $showingAddWallet) { AddWalletView() }
        .sheet(isPresented: $showingAddRelationship) { AddRelationshipView() }
        .sheet(isPresented: $showingAddGoal) { AddGoalView() }
        .sheet(isPresented: $showingTransactions) { TransactionsView() }
        .sheet(isPresented: $showingFinanceCenter) { FinanceCenterView() }
        .sheet(isPresented: $showingAgenda) { AgendaView() }
        .sheet(item: $selectedRelationship) { RelationshipDetailView(relationship: $0) }
        .sheet(item: $selectedGoal) { GoalDetailView(goal: $0) }
        .sheet(item: $selectedWallet) { WalletDetailView(wallet: $0) }
        .sheet(item: $selectedTransaction) { TransactionDetailView(transaction: $0) }
    }

    private func toggleCard(_ card: HomeCard) {
        withAnimation(Theme.Animation.standard) { expandedCard = expandedCard == card ? nil : card }
    }
}

private struct AureaAIPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 46))
                Text("Aurea")
                    .font(.largeTitle.bold())
                Text("Il tuo assistente personale per finanze e organizzazione arriverà qui.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 36)
                Spacer()
            }
            .padding(.top, 70)
            .navigationTitle("Aurea AI")
        }
    }
}

#Preview { ContentView() }
