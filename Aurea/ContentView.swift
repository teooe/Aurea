import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Relationship.createdAt, order: .reverse) private var relationships: [Relationship]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \AgendaItem.date) private var agendaItems: [AgendaItem]

    @State private var showingQuickAdd = false
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
    private var todayAgenda: [AgendaItem] { agendaItems.filter { Calendar.current.isDateInToday($0.date) } }
    private var openTodayAgenda: [AgendaItem] { todayAgenda.filter { !$0.isCompleted } }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: Theme.Spacing.medium) {
                NetWorthCardView(totalNetWorth: totalNetWorth, wallets: activeWallets, monthlyTransactions: monthlyTransactions, transactionCount: transactions.count, isExpanded: expandedCard == .netWorth) { toggleCard(.netWorth) }

                TodayCardView(transactions: todayTransactions, isExpanded: expandedCard == .today) { toggleCard(.today) } onSelectTransaction: { transaction in
                    selectedTransaction = transaction
                } onShowAll: {
                    showingTransactions = true
                }

                Button {
                    showingAgenda = true
                } label: {
                    AureaCard(title: "Agenda", icon: "calendar.badge.clock") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if openTodayAgenda.isEmpty {
                                    Text("Nessun impegno oggi")
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                } else {
                                    Text("\(openTodayAgenda.count) \(openTodayAgenda.count == 1 ? "impegno" : "impegni") oggi")
                                        .fontWeight(.medium)
                                    if let next = openTodayAgenda.sorted(by: { $0.date < $1.date }).first {
                                        Text(next.hasTime ? "Prossimo: \(next.title) alle \(next.date.formatted(date: .omitted, time: .shortened))" : "Prossimo: \(next.title)")
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    }
                }
                .buttonStyle(.plain)

                WalletsCardView(wallets: activeWallets, isExpanded: expandedCard == .wallets) { toggleCard(.wallets) } onAddWallet: { showingAddWallet = true } onSelectWallet: { selectedWallet = $0 }

                GoalsCardView(goals: goals, isExpanded: expandedCard == .goals) { toggleCard(.goals) } onAddGoal: { showingAddGoal = true } onSelectGoal: { selectedGoal = $0 }

                RelationshipsCardView(relationships: relationships, isExpanded: expandedCard == .relationships) { toggleCard(.relationships) } onAddRelationship: { showingAddRelationship = true } onSelectRelationship: { selectedRelationship = $0 }

                Button {
                    showingFinanceCenter = true
                } label: {
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

                Color.clear.frame(height: expandedCard == nil ? 70 : 24)
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
                Button { showingQuickAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.medium))
                        .frame(width: 54, height: 54)
                        .background(.regularMaterial)
                        .clipShape(Circle())
                        .overlay { Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(Theme.Animation.standard, value: expandedCard)
        .sheet(isPresented: $showingQuickAdd) { QuickAddView() }
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

#Preview { ContentView() }
