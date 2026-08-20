import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Relationship.createdAt, order: .reverse) private var relationships: [Relationship]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query(sort: \AgendaItem.date) private var agendaItems: [AgendaItem]
    @Query private var budgets: [Budget]
    @Query(sort: \RecurringTransaction.nextDate) private var recurringTransactions: [RecurringTransaction]

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
    private var todayAgenda: [AgendaItem] { agendaItems.filter { Calendar.current.isDateInToday($0.date) && !$0.isCompleted }.sorted { $0.date < $1.date } }
    private var overdueAgenda: [AgendaItem] { let start = Calendar.current.startOfDay(for: .now); return agendaItems.filter { !$0.isCompleted && $0.date < start && ($0.type == .task || $0.type == .deadline) } }
    private var upcomingAgenda: [AgendaItem] { let start = Calendar.current.startOfDay(for: .now); return agendaItems.filter { !$0.isCompleted && $0.date >= start }.sorted { $0.date < $1.date } }
    private var monthExpenses: Decimal { monthlyTransactions.filter { $0.type == .expense && $0.category != "Trasferimento" }.reduce(0) { $0 + valueInEUR($1) } }
    private var monthIncome: Decimal { monthlyTransactions.filter { $0.type == .income && $0.category != "Trasferimento" }.reduce(0) { $0 + valueInEUR($1) } }
    private var monthBalance: Decimal { monthIncome - monthExpenses }
    private var activeBudgets: [Budget] { budgets.filter { !$0.isArchived } }
    private var activeRecurring: [RecurringTransaction] { recurringTransactions.filter { $0.isActive } }
    private var upcomingRecurring: [RecurringTransaction] { activeRecurring.filter { $0.nextDate >= Calendar.current.startOfDay(for: .now) }.sorted { $0.nextDate < $1.nextDate } }
    private var openRelationships: [Relationship] { relationships.filter { !$0.isClosed && $0.remainingAmount > 0 } }
    private var dueRelationships: [Relationship] { let today = Calendar.current.startOfDay(for: .now); return openRelationships.filter { ($0.dueDate ?? .distantFuture) <= today } }
    private var activeGoals: [Goal] { goals.filter { !$0.isCompleted } }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: Theme.Spacing.medium) {
                header
                dayBriefCard
                NetWorthCardView(totalNetWorth: totalNetWorth, wallets: activeWallets, monthlyTransactions: monthlyTransactions, transactionCount: transactions.count, isExpanded: expandedCard == .netWorth) { toggleCard(.netWorth) }
                financialPulseCard
                smartAlerts
                TodayCardView(transactions: todayTransactions, isExpanded: expandedCard == .today) { toggleCard(.today) } onSelectTransaction: { selectedTransaction = $0 } onShowAll: { showingTransactions = true }
                agendaCard
                WalletsCardView(wallets: activeWallets, isExpanded: expandedCard == .wallets) { toggleCard(.wallets) } onAddWallet: { showingAddWallet = true } onSelectWallet: { selectedWallet = $0 }
                GoalsCardView(goals: goals, isExpanded: expandedCard == .goals) { toggleCard(.goals) } onAddGoal: { showingAddGoal = true } onSelectGoal: { selectedGoal = $0 }
                RelationshipsCardView(relationships: relationships, isExpanded: expandedCard == .relationships) { toggleCard(.relationships) } onAddRelationship: { showingAddRelationship = true } onSelectRelationship: { selectedRelationship = $0 }
                financeToolsButton
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Aurea")
                    .font(.largeTitle.bold())
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.title2)
                .padding(10)
                .background(.regularMaterial)
                .clipShape(Circle())
        }
    }

    private var dayBriefCard: some View {
        AureaCard(title: "La tua giornata", icon: "sun.max") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    metricBlock(title: "Impegni", value: "\(todayAgenda.count)", subtitle: todayAgenda.isEmpty ? "giornata libera" : "ancora aperti")
                    metricBlock(title: "Movimenti", value: "\(todayTransactions.count)", subtitle: todayTransactions.isEmpty ? "nessuno oggi" : "registrati oggi")
                }
                if let next = todayAgenda.first {
                    Divider()
                    Button { showingAgenda = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: next.type.icon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Prossimo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(next.title)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if next.hasTime { Text(next.date.formatted(date: .omitted, time: .shortened)).font(.subheadline.monospacedDigit()) }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var financialPulseCard: some View {
        AureaCard(title: "Questo mese", icon: "waveform.path.ecg") {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    financeMetric("Entrate", value: monthIncome)
                    financeMetric("Spese", value: monthExpenses)
                    financeMetric("Bilancio", value: monthBalance)
                }
                if monthIncome != 0 || monthExpenses != 0 {
                    GeometryReader { geometry in
                        let total = max(decimalDouble(monthIncome + monthExpenses), 1)
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4).fill(.primary.opacity(0.75)).frame(width: geometry.size.width * decimalDouble(monthIncome) / total)
                            RoundedRectangle(cornerRadius: 4).fill(.secondary.opacity(0.35))
                        }
                    }
                    .frame(height: 7)
                }
                HStack {
                    Text(monthBalance >= 0 ? "Mese in positivo" : "Spese superiori alle entrate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dettagli") { showingFinanceCenter = true }.font(.caption.weight(.semibold))
                }
            }
        }
    }

    @ViewBuilder private var smartAlerts: some View {
        if !alertRows.isEmpty {
            AureaCard(title: "Da tenere d'occhio", icon: "bell.badge") {
                VStack(spacing: 0) {
                    ForEach(Array(alertRows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider().padding(.vertical, 10) }
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: row.icon).frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).font(.subheadline.weight(.semibold))
                                Text(row.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var agendaCard: some View {
        Button { showingAgenda = true } label: {
            AureaCard(title: "Agenda", icon: "calendar.badge.clock") {
                VStack(alignment: .leading, spacing: 10) {
                    if upcomingAgenda.isEmpty {
                        HStack { Text("Nessun impegno in programma").foregroundStyle(Theme.Colors.secondaryText); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                    } else {
                        ForEach(Array(upcomingAgenda.prefix(3))) { item in
                            HStack(spacing: 10) {
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(item.date.formatted(.dateTime.day())).font(.headline.monospacedDigit())
                                    Text(item.date.formatted(.dateTime.month(.abbreviated))).font(.caption2).foregroundStyle(.secondary)
                                }.frame(width: 38)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).fontWeight(.medium).lineLimit(1)
                                    Text(item.hasTime ? item.date.formatted(date: .omitted, time: .shortened) : item.type.title).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if item.priority == .high { Image(systemName: "exclamationmark.circle.fill").font(.caption) }
                            }
                        }
                        HStack { Text(upcomingAgenda.count > 3 ? "+ \(upcomingAgenda.count - 3) altri" : "Apri agenda").font(.caption).foregroundStyle(.secondary); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }.buttonStyle(.plain)
    }

    private var financeToolsButton: some View {
        Button { showingFinanceCenter = true } label: {
            HStack {
                Label("Strumenti finanziari", systemImage: "chart.pie").fontWeight(.medium)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if !activeBudgets.isEmpty { Text("\(activeBudgets.count) budget").font(.caption).foregroundStyle(.secondary) }
                    if !activeRecurring.isEmpty { Text("\(activeRecurring.count) ricorrenti").font(.caption2).foregroundStyle(.secondary) }
                }
                Image(systemName: "chevron.right").font(.caption)
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func metricBlock(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func financeMetric(_ title: String, value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: "EUR"))).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var alertRows: [HomeAlertRow] {
        var rows: [HomeAlertRow] = []
        if !overdueAgenda.isEmpty { rows.append(HomeAlertRow(icon: "exclamationmark.triangle", title: "\(overdueAgenda.count) \(overdueAgenda.count == 1 ? "impegno arretrato" : "impegni arretrati")", detail: "Apri l'Agenda per recuperarli.")) }
        if !dueRelationships.isEmpty { rows.append(HomeAlertRow(icon: "person.crop.circle.badge.exclamationmark", title: "Debiti o crediti in scadenza", detail: "Hai \(dueRelationships.count) rapporto aperto da controllare.")) }
        if let recurring = upcomingRecurring.first, recurring.nextDate <= (Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now) { rows.append(HomeAlertRow(icon: "repeat", title: "Ricorrente in arrivo", detail: "\(recurring.title) · \(recurring.nextDate.formatted(date: .abbreviated, time: .omitted))")) }
        if let warning = budgetWarning { rows.append(warning) }
        if let goal = activeGoals.first(where: { $0.targetDate != nil && ($0.targetDate ?? .distantFuture) <= (Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now) }) { rows.append(HomeAlertRow(icon: "target", title: "Obiettivo vicino alla scadenza", detail: goal.title)) }
        return Array(rows.prefix(4))
    }

    private var budgetWarning: HomeAlertRow? {
        for budget in activeBudgets {
            let spent: Decimal
            if let category = budget.category {
                spent = monthlyTransactions.filter { $0.type == .expense && $0.category == category }.reduce(0) { $0 + valueInEUR($1) }
            } else {
                spent = monthExpenses
            }
            guard budget.monthlyLimit > 0 else { continue }
            let ratio = decimalDouble(spent / budget.monthlyLimit)
            if ratio >= 1 { return HomeAlertRow(icon: "exclamationmark.octagon", title: "Budget superato", detail: "\(budget.title): \(spent.formatted(.currency(code: "EUR"))) su \(budget.monthlyLimit.formatted(.currency(code: "EUR"))).") }
            if ratio >= 0.8 { return HomeAlertRow(icon: "gauge.with.dots.needle.67percent", title: "Budget quasi esaurito", detail: "\(budget.title) è all'\(Int(ratio * 100))%.") }
        }
        return nil
    }

    private func valueInEUR(_ transaction: Transaction) -> Decimal { transaction.amount * (transaction.wallet?.effectiveExchangeRateToEUR ?? 1) }
    private func decimalDouble(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
    private var greeting: String { let hour = Calendar.current.component(.hour, from: .now); if hour < 12 { return "Buongiorno" }; if hour < 18 { return "Buon pomeriggio" }; return "Buonasera" }
    private func toggleCard(_ card: HomeCard) { withAnimation(Theme.Animation.standard) { expandedCard = expandedCard == card ? nil : card } }
}

private struct HomeAlertRow {
    let icon: String
    let title: String
    let detail: String
}
