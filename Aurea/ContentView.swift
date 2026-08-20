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
        ScrollView(.vertical) {
            VStack(spacing: Theme.Spacing.medium) {
                NetWorthCardView(
                    totalNetWorth: totalNetWorth,
                    wallets: wallets,
                    monthlyTransactions: monthlyTransactions,
                    transactionCount: transactions.count,
                    isExpanded: expandedCard == .netWorth
                ) {
                    toggleCard(.netWorth)
                }
                
                TodayCardView(
                    transactions: todayTransactions,
                    isExpanded: expandedCard == .today
                ) {
                    toggleCard(.today)
                } onSelectTransaction: { transaction in
                    selectedTransaction = transaction
                }
                
                WalletsCardView(
                    wallets: wallets,
                    isExpanded: expandedCard == .wallets
                ) {
                    toggleCard(.wallets)
                } onAddWallet: {
                    showingAddWallet = true
                } onSelectWallet: { wallet in
                    selectedWallet = wallet
                }
                
                GoalsCardView(
                    goals: goals,
                    isExpanded: expandedCard == .goals
                ) {
                    toggleCard(.goals)
                } onAddGoal: {
                    showingAddGoal = true
                } onSelectGoal: { goal in
                    selectedGoal = goal
                }

                RelationshipsCardView(
                    relationships: relationships,
                    isExpanded: expandedCard == .relationships
                ) {
                    toggleCard(.relationships)
                } onAddRelationship: {
                    showingAddRelationship = true
                } onSelectRelationship: { relationship in
                    selectedRelationship = relationship
                }

                Color.clear
                    .frame(height: expandedCard == nil ? 70 : 24)
            }
            .id(expandedCard)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.top, Theme.Spacing.medium)
        }
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.always)
        .background(Theme.Colors.background.ignoresSafeArea())
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

    private func toggleCard(_ card: HomeCard) {
        withAnimation(Theme.Animation.standard) {
            expandedCard = expandedCard == card ? nil : card
        }
    }
}

#Preview {
    ContentView()
}
