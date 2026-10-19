import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Query private var wallets: [Wallet]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Relationship.createdAt, order: .reverse) private var relationships: [Relationship]
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @Query private var budgets: [Budget]
    @Query(sort: \RecurringTransaction.nextDate) private var recurringTransactions: [RecurringTransaction]

    @State private var showingAddWallet = false
    @State private var showingAddRelationship = false
    @State private var showingAddGoal = false
    @State private var showingTransactions = false
    @State private var showingFinanceCenter = false
    @State private var showingReports = false
    @State private var selectedRelationship: Relationship?
    @State private var selectedGoal: Goal?
    @State private var selectedWallet: Wallet?
    @State private var selectedTransaction: Transaction?
    @State private var expandedCard: HomeCard?

    private var activeWallets: [Wallet] { wallets.filter { !$0.isArchived } }
    private var totalNetWorth: Decimal { FinancialEngine.netWorth(wallets: activeWallets) }
    private var todayTransactions: [Transaction] { TimelineEngine.transactionsForToday(from: transactions) }
    private var monthlyTransactions: [Transaction] { TimelineEngine.transactionsForCurrentMonth(from: transactions) }
    private var monthExpenses: Decimal { monthlyTransactions.filter { $0.type == .expense && !$0.isTransfer }.reduce(0) { $0 + valueInEUR($1) } }
    private var monthIncome: Decimal { monthlyTransactions.filter { $0.type == .income && !$0.isTransfer }.reduce(0) { $0 + valueInEUR($1) } }
    private var monthBalance: Decimal { monthIncome - monthExpenses }
    private var activeBudgets: [Budget] { budgets.filter { !$0.isArchived } }
    /// Budget attivi dal più vicino al limite, nel loro periodo corrente (mese o settimana).
    private var budgetProgress: [HomeBudgetProgress] {
        activeBudgets
            .filter { $0.limit > 0 }
            .map { HomeBudgetProgress(budget: $0, status: BudgetEngine.status(for: $0, transactions: transactions)) }
            .sorted { $0.status.ratio > $1.status.ratio }
    }
    private var activeRecurring: [RecurringTransaction] { recurringTransactions.filter { $0.isActive } }
    private var forecast: ForecastEngine.MonthForecast? { ForecastEngine.monthForecast(transactions: transactions, recurring: recurringTransactions) }
    private var upcomingRecurring: [RecurringTransaction] { activeRecurring.filter { $0.nextDate >= Calendar.current.startOfDay(for: .now) }.sorted { $0.nextDate < $1.nextDate } }
    private var openRelationships: [Relationship] { relationships.filter { !$0.isClosed && $0.remainingAmount > 0 } }
    private var dueRelationships: [Relationship] { let today = Calendar.current.startOfDay(for: .now); return openRelationships.filter { ($0.dueDate ?? .distantFuture) <= today } }
    private var activeGoals: [Goal] { goals.filter { !$0.isCompleted } }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: Theme.Spacing.medium) {
                header
                NetWorthCardView(totalNetWorth: totalNetWorth, wallets: activeWallets, monthlyTransactions: monthlyTransactions, transactionCount: transactions.count, isExpanded: expandedCard == .netWorth) { toggleCard(.netWorth) }
                financialPulseCard
                SpendingTrendCardView(points: FinancialEngine.monthlyExpenses(from: transactions)) { showingReports = true }
                smartAlerts
                TodayCardView(transactions: todayTransactions, isExpanded: expandedCard == .today) { toggleCard(.today) } onSelectTransaction: { selectedTransaction = $0 } onShowAll: { showingTransactions = true }
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
        .sheet(isPresented: $showingTransactions) { TransactionsView(showsCloseButton: true) }
        .sheet(isPresented: $showingFinanceCenter) { FinanceCenterView() }
        .sheet(isPresented: $showingReports) { NavigationStack { ReportsView(showsDoneButton: true) } }
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
                if let forecast, forecast.daysLeft > 0 {
                    forecastRow(forecast)
                }
                if !budgetProgress.isEmpty {
                    Divider()
                    Button { showingFinanceCenter = true } label: {
                        VStack(spacing: 10) {
                            ForEach(budgetProgress.prefix(3)) { item in
                                budgetRow(item.budget, status: item.status)
                            }
                            if budgetProgress.count > 3 {
                                Text("+ \(budgetProgress.count - 3) altri budget")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Text(monthBalance >= 0 ? "Mese in positivo" : "Spese superiori alle entrate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Report") { showingReports = true }.font(.caption.weight(.semibold))
                }
            }
        }
    }

    private func forecastRow(_ forecast: ForecastEngine.MonthForecast) -> some View {
        let balance = forecast.projectedBalance
        let value = balance.formatted(.currency(code: "EUR").precision(.fractionLength(0)))
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: balance >= 0 ? "arrow.up.forward.circle" : "exclamationmark.triangle")
                .foregroundStyle(balance >= 0 ? Theme.Colors.income : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("A questo ritmo finirai il mese con \(balance >= 0 ? "+" : "")\(value)")
                    .font(.subheadline.weight(.semibold))
                Text(forecastDetail(forecast))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func forecastDetail(_ forecast: ForecastEngine.MonthForecast) -> String {
        func euro(_ value: Decimal) -> String { value.formatted(.currency(code: "EUR").precision(.fractionLength(0))) }
        var parts = ["Spese previste \(euro(forecast.projectedExpenses))"]
        if forecast.upcomingExpenses > 0 { parts.append("di cui \(euro(forecast.upcomingExpenses)) ricorrenti da pagare") }
        if forecast.upcomingIncome > 0 { parts.append("entrate in arrivo \(euro(forecast.upcomingIncome))") }
        return parts.joined(separator: " · ")
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

    private func budgetRow(_ budget: Budget, status: BudgetStatus) -> some View {
        let ratio = status.ratio
        let tint: Color = ratio >= 1 ? .red : (ratio >= 0.8 ? .orange : .accentColor)
        let perDay = BudgetEngine.dailyAllowance(for: status)
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(budget.title).font(.subheadline.weight(.medium)).lineLimit(1)
                if budget.period == .weekly {
                    Text("settimana").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(status.spent.formatted(.currency(code: "EUR"))) / \(status.limit.formatted(.currency(code: "EUR")))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ratio >= 1 ? .red : .secondary)
            }
            ProgressView(value: min(max(ratio, 0), 1))
                .tint(tint)
            Text(status.isOver
                 ? "Superato di \((status.spent - status.limit).formatted(.currency(code: "EUR")))"
                 : "Puoi spendere \(perDay.formatted(.currency(code: "EUR"))) al giorno")
                .font(.caption2)
                .foregroundStyle(ratio >= 1 ? .red : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(ratio * 100)) per cento")
    }

    private func financeMetric(_ title: String, value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.formatted(.currency(code: "EUR"))).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var alertRows: [HomeAlertRow] {
        var rows: [HomeAlertRow] = []
        if !dueRelationships.isEmpty { rows.append(HomeAlertRow(icon: "person.crop.circle.badge.exclamationmark", title: "Debiti o crediti in scadenza", detail: "Hai \(dueRelationships.count) rapporto aperto da controllare.")) }
        if let recurring = upcomingRecurring.first, recurring.nextDate <= (Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now) { rows.append(HomeAlertRow(icon: "repeat", title: "Ricorrente in arrivo", detail: "\(recurring.title) · \(recurring.nextDate.formatted(date: .abbreviated, time: .omitted))")) }
        if let warning = budgetWarning { rows.append(warning) }
        if let goal = activeGoals.first(where: { $0.targetDate != nil && ($0.targetDate ?? .distantFuture) <= (Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now) }) { rows.append(HomeAlertRow(icon: "target", title: "Obiettivo vicino alla scadenza", detail: goal.title)) }
        return Array(rows.prefix(4))
    }

    private var budgetWarning: HomeAlertRow? {
        for item in budgetProgress {
            let (budget, spent, ratio) = (item.budget, item.status.spent, item.status.ratio)
            if ratio >= 1 { return HomeAlertRow(icon: "exclamationmark.octagon", title: "Budget superato", detail: "\(budget.title): \(spent.formatted(.currency(code: "EUR"))) su \(item.status.limit.formatted(.currency(code: "EUR"))).") }
            if ratio >= 0.8 { return HomeAlertRow(icon: "gauge.with.dots.needle.67percent", title: "Budget quasi esaurito", detail: "\(budget.title) è all'\(Int(ratio * 100))%.") }
        }
        return nil
    }

    private func valueInEUR(_ transaction: Transaction) -> Decimal { transaction.amount * (transaction.wallet?.effectiveExchangeRateToEUR ?? 1) }
    private func decimalDouble(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
    private var greeting: String { let hour = Calendar.current.component(.hour, from: .now); if hour < 12 { return "Buongiorno" }; if hour < 18 { return "Buon pomeriggio" }; return "Buonasera" }
    private func toggleCard(_ card: HomeCard) { withAnimation(Theme.Animation.standard) { expandedCard = expandedCard == card ? nil : card } }
}

private struct HomeBudgetProgress: Identifiable {
    let budget: Budget
    let status: BudgetStatus
    var id: UUID { budget.id }
}

private struct HomeAlertRow {
    let icon: String
    let title: String
    let detail: String
}
