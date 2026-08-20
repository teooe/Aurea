import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse)
    private var transactions: [Transaction]
    @Query(sort: \Relationship.createdAt, order: .reverse)
    private var relationships: [Relationship]
    @Query(sort: \Goal.createdAt, order: .reverse)
    private var goals: [Goal]
    
    @State private var showingQuickAdd = false
    @State private var showingAddWallet = false
    @State private var showingAddRelationship = false
    @State private var showingAddGoal = false
    @State private var selectedRelationship: Relationship?
    @State private var selectedGoal: Goal?
    @State private var selectedWallet: Wallet?
    @State private var selectedTransaction: Transaction?
    @State private var expandedCard: HomeCard?
    
    private var totalNetWorth: Decimal {
        FinancialEngine.netWorth(wallets: wallets)
    }
    
    private var todayTransactions: [Transaction] {
        TimelineEngine.transactionsForToday(from: transactions)
    }

    private var monthlyTransactions: [Transaction] {
        TimelineEngine.transactionsForCurrentMonth(from: transactions)
    }

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.Spacing.medium) {
                    NetWorthCardView(
                        totalNetWorth: totalNetWorth,
                        wallets: wallets,
                        monthlyTransactions: monthlyTransactions,
                        transactionCount: transactions.count,
                        isExpanded: expandedCard == .netWorth
                    ) {
                        withAnimation(Theme.Animation.standard) {
                            expandedCard = expandedCard == .netWorth ? nil : .netWorth
                        }
                    }
                    
                    TodayCardView(
                        transactions: todayTransactions,
                        isExpanded: expandedCard == .today
                    ) {
                        withAnimation(Theme.Animation.standard) {
                            expandedCard = expandedCard == .today ? nil : .today
                        }
                    } onSelectTransaction: { transaction in
                        selectedTransaction = transaction
                    }
                    
                    WalletsCardView(
                        wallets: wallets,
                        isExpanded: expandedCard == .wallets
                    ) {
                        withAnimation(Theme.Animation.standard) {
                            expandedCard = expandedCard == .wallets ? nil : .wallets
                        }
                    } onAddWallet: {
                        showingAddWallet = true
                    } onSelectWallet: { wallet in
                        selectedWallet = wallet
                    }
                    
                    GoalsCardView(
                        goals: goals,
                        isExpanded: expandedCard == .goals
                    ) {
                        withAnimation(Theme.Animation.standard) {
                            expandedCard = expandedCard == .goals ? nil : .goals
                        }
                    } onAddGoal: {
                        showingAddGoal = true
                    } onSelectGoal: { goal in
                        selectedGoal = goal
                    }

                    RelationshipsCardView(
                        relationships: relationships,
                        isExpanded: expandedCard == .relationships
                    ) {
                        withAnimation(Theme.Animation.standard) {
                            expandedCard = expandedCard == .relationships ? nil : .relationships
                        }
                    } onAddRelationship: {
                        showingAddRelationship = true
                    } onSelectRelationship: { relationship in
                        selectedRelationship = relationship
                    }
                }
                .padding(.horizontal, Theme.Spacing.medium)
                .padding(.top, Theme.Spacing.medium)
                .padding(.bottom, 80)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if expandedCard == nil {
                Button {
                    showingQuickAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.medium))
                        .frame(width: 54, height: 54)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    Color.primary.opacity(0.1),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Theme.Animation.standard, value: expandedCard)
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddView()
        }
        .sheet(isPresented: $showingAddWallet) {
            AddWalletView()
        }
        .sheet(isPresented: $showingAddRelationship) {
            AddRelationshipView()
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView()
        }
        .sheet(item: $selectedRelationship) { relationship in
            RelationshipDetailView(relationship: relationship)
        }
        .sheet(item: $selectedGoal) { goal in
            GoalDetailView(goal: goal)
        }
        .sheet(item: $selectedWallet) { wallet in
            WalletDetailView(wallet: wallet)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
    }
}

#Preview {
    ContentView()
}
