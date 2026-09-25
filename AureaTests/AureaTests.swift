import Testing
import Foundation
import SwiftData
@testable import Aurea

struct AureaTests {

    @Test func walletBalanceHandlesIncomeAndExpenses() {
        let wallet = Wallet(name: "Test", icon: "wallet.pass", initialBalance: 100)
        wallet.transactions = [
            Transaction(type: .income, amount: 50, category: "Stipendio", title: "Entrata", wallet: wallet),
            Transaction(type: .expense, amount: 20, category: "Cibo", title: "Spesa", wallet: wallet)
        ]

        #expect(FinancialEngine.balance(for: wallet) == 130)
    }

    @Test func netWorthConvertsForeignWalletsAndIgnoresArchived() {
        let eur = Wallet(name: "EUR", icon: "wallet.pass", currencyCode: "EUR", initialBalance: 100)
        let usd = Wallet(name: "USD", icon: "dollarsign.circle", currencyCode: "USD", initialBalance: 100, exchangeRateToEUR: 0.9)
        let archived = Wallet(name: "Archivio", icon: "archivebox", currencyCode: "EUR", initialBalance: 500, isArchived: true)

        #expect(FinancialEngine.netWorth(wallets: [eur, usd, archived]) == 190)
    }

    @Test func totalIncomeAndExpensesExcludeTransfers() {
        let wallet = Wallet(name: "Test", icon: "wallet.pass")
        let items = [
            Transaction(type: .income, amount: 100, category: "Stipendio", title: "Entrata", wallet: wallet),
            Transaction(type: .expense, amount: 30, category: "Cibo", title: "Cena", wallet: wallet),
            Transaction(type: .expense, amount: 50, category: "Trasferimento", title: "Trasferimento", wallet: wallet)
        ]

        #expect(FinancialEngine.totalIncome(from: items) == 100)
        #expect(FinancialEngine.totalExpenses(from: items) == 30)
        #expect(FinancialEngine.cashFlow(from: items) == 70)
    }

    @Test func transfersAreRecognizedByGroupIDAndLegacyCategory() {
        let linked = Transaction(type: .expense, amount: 50, category: "Casa", title: "Giroconto", transferGroupID: UUID())
        let legacy = Transaction(type: .expense, amount: 50, category: Transaction.transferCategory, title: "Vecchio trasferimento")
        let normal = Transaction(type: .expense, amount: 50, category: "Casa", title: "Affitto")

        #expect(linked.isTransfer)
        #expect(legacy.isTransfer)
        #expect(!normal.isTransfer)
        #expect(FinancialEngine.totalExpenses(from: [linked, legacy, normal]) == 50)
    }

    @Test func transferCategoryIsReserved() {
        #expect(Transaction.isReservedCategory("Trasferimento"))
        #expect(Transaction.isReservedCategory(" trasferimento "))
        #expect(!Transaction.isReservedCategory("Trasporti"))
    }

    @Test func totalsConvertForeignCurrencies() {
        let usd = Wallet(name: "USD", icon: "dollarsign.circle", currencyCode: "USD", exchangeRateToEUR: 0.9)
        let eur = Wallet(name: "EUR", icon: "wallet.pass")
        let items = [
            Transaction(type: .expense, amount: 100, category: "Viaggi", title: "Hotel", wallet: usd),
            Transaction(type: .expense, amount: 10, category: "Cibo", title: "Pranzo", wallet: eur)
        ]

        #expect(FinancialEngine.totalExpenses(from: items) == 100)
    }

    @MainActor
    @Test func recurringEngineCatchesUpMissedOccurrences() throws {
        let container = try ModelContainer(
            for: Wallet.self, Transaction.self, RecurringTransaction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))!
        let start = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 9))!

        let wallet = Wallet(name: "Conto", icon: "wallet.pass")
        let rent = RecurringTransaction(title: "Affitto", amount: 500, category: "Casa", type: .expense, frequency: .monthly, nextDate: start, wallet: wallet)
        let paused = RecurringTransaction(title: "Palestra", amount: 40, category: "Sport", type: .expense, frequency: .monthly, nextDate: start, wallet: wallet, isActive: false)
        context.insert(wallet)
        context.insert(rent)
        context.insert(paused)

        let created = RecurringEngine.generateDueTransactions(from: [rent, paused], in: context, now: now)

        #expect(created.count == 3) // 1 luglio, 1 agosto, 1 settembre
        #expect(created.allSatisfy { $0.title == "Affitto" })
        #expect(calendar.component(.month, from: rent.nextDate) == 10)
        #expect(paused.nextDate == start)

        let again = RecurringEngine.generateDueTransactions(from: [rent, paused], in: context, now: now)
        #expect(again.isEmpty)
    }

    @MainActor
    private func makeCategoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Wallet.self, Transaction.self, RecurringTransaction.self, Budget.self, FinanceCategory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @MainActor
    @Test func synchronizeRegistersTypedCategoriesAndUnifiesCase() throws {
        let container = try makeCategoryContainer()
        let context = container.mainContext
        let cibo = FinanceCategory(name: "Cibo", type: .expense)
        context.insert(cibo)
        let lower = Transaction(type: .expense, amount: 10, category: "cibo ", title: "Pizza")
        let custom = Transaction(type: .expense, amount: 20, category: "Palestra", title: "Abbonamento")
        let transferHalf = Transaction(type: .expense, amount: 30, category: Transaction.transferCategory, title: "Giroconto", transferGroupID: UUID())
        [lower, custom, transferHalf].forEach { context.insert($0) }

        CategoryService.synchronize(in: context)
        CategoryService.synchronize(in: context) // idempotente
        try context.save()

        let expenseNames = try context.fetch(FetchDescriptor<FinanceCategory>()).filter { $0.type == .expense }.map(\.name)
        #expect(lower.category == "Cibo")
        #expect(expenseNames.filter { $0 == "Palestra" }.count == 1)
        #expect(!expenseNames.contains(Transaction.transferCategory))
        #expect(expenseNames.filter { $0.lowercased() == "cibo" }.count == 1)
    }

    @MainActor
    @Test func synchronizeSeedsDefaultsOnlyWhenTypeIsEmpty() throws {
        let container = try makeCategoryContainer()
        let context = container.mainContext
        context.insert(FinanceCategory(name: "Mia", type: .expense))

        CategoryService.synchronize(in: context)
        try context.save()

        let categories = try context.fetch(FetchDescriptor<FinanceCategory>())
        #expect(categories.filter { $0.type == .expense }.map(\.name) == ["Mia"])
        #expect(categories.filter { $0.type == .income }.count == CategoryService.defaultIncomeCategories.count)
    }

    @MainActor
    @Test func resolveReusesExistingCategoryAndRestoresArchived() throws {
        let container = try makeCategoryContainer()
        let context = container.mainContext
        let archived = FinanceCategory(name: "Viaggi", type: .expense, isArchived: true)
        context.insert(archived)

        #expect(CategoryService.resolve("  viaggi", type: .expense, in: context) == "Viaggi")
        #expect(!archived.isArchived)

        #expect(CategoryService.resolve("Libri", type: .expense, in: context) == "Libri")
        try context.save()
        let names = try context.fetch(FetchDescriptor<FinanceCategory>()).map(\.name)
        #expect(names.contains("Libri"))
    }

    @MainActor
    @Test func renamePropagatesToTransactionsRecurringAndBudgets() throws {
        let container = try makeCategoryContainer()
        let context = container.mainContext
        let category = FinanceCategory(name: "Cibo", type: .expense)
        let expense = Transaction(type: .expense, amount: 10, category: "Cibo", title: "Pizza")
        let incomeSameName = Transaction(type: .income, amount: 5, category: "Cibo", title: "Rimborso cena")
        let recurring = RecurringTransaction(title: "Spesa", amount: 50, category: "Cibo", type: .expense, frequency: .weekly, nextDate: .now)
        let budget = Budget(title: "Mangiare", category: "Cibo", monthlyLimit: 300)
        context.insert(category)
        [expense, incomeSameName].forEach { context.insert($0) }
        context.insert(recurring)
        context.insert(budget)

        try CategoryService.rename(category, to: "Alimentari", in: context)

        #expect(category.name == "Alimentari")
        #expect(expense.category == "Alimentari")
        #expect(incomeSameName.category == "Cibo")
        #expect(recurring.category == "Alimentari")
        #expect(budget.category == "Alimentari")
    }

    @MainActor
    @Test func renameToExistingNameMergesCategories() throws {
        let container = try makeCategoryContainer()
        let context = container.mainContext
        let source = FinanceCategory(name: "Supermercato", type: .expense)
        let target = FinanceCategory(name: "Alimentari", type: .expense)
        let expense = Transaction(type: .expense, amount: 40, category: "Supermercato", title: "Spesa")
        context.insert(source)
        context.insert(target)
        context.insert(expense)

        try CategoryService.rename(source, to: "alimentari", in: context)

        #expect(expense.category == "Alimentari")
        try context.save()
        let names = try context.fetch(FetchDescriptor<FinanceCategory>()).map(\.name)
        #expect(names == ["Alimentari"])
    }

    @Test func periodFilterRespectsMonthBoundaries() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))!
        let lastDayOfAugust = calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 23, minute: 59))!
        let firstOfSeptember = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        let items = [
            Transaction(type: .expense, amount: 1, date: lastDayOfAugust, category: "Casa", title: "Agosto"),
            Transaction(type: .expense, amount: 1, date: firstOfSeptember, category: "Casa", title: "Settembre"),
            Transaction(type: .expense, amount: 1, date: july, category: "Casa", title: "Luglio"),
        ]

        let lastMonth = TransactionFilter(period: .lastMonth).apply(to: items, now: now, calendar: calendar)
        let thisMonth = TransactionFilter(period: .thisMonth).apply(to: items, now: now, calendar: calendar)
        let threeMonths = TransactionFilter(period: .lastThreeMonths).apply(to: items, now: now, calendar: calendar)

        #expect(lastMonth.map(\.title) == ["Agosto"])
        #expect(thisMonth.map(\.title) == ["Settembre"])
        #expect(threeMonths.count == 3)
    }

    @Test func kindAndCategoryFiltersExcludeTransfers() {
        let items = [
            Transaction(type: .expense, amount: 10, category: "Cibo", title: "Pizza"),
            Transaction(type: .income, amount: 100, category: "Stipendio", title: "Settembre"),
            Transaction(type: .expense, amount: 50, category: Transaction.transferCategory, title: "Giroconto", transferGroupID: UUID()),
        ]

        #expect(TransactionFilter(kind: .expenses).apply(to: items).map(\.title) == ["Pizza"])
        #expect(TransactionFilter(kind: .income).apply(to: items).map(\.title) == ["Settembre"])
        #expect(TransactionFilter(category: "cibo").apply(to: items).map(\.title) == ["Pizza"])
        #expect(TransactionFilter(searchText: "  pizz ").apply(to: items).map(\.title) == ["Pizza"])
        #expect(TransactionFilter().apply(to: items).count == 3)
    }

    @MainActor
    @Test func deletingTransferRemovesBothHalves() throws {
        let container = try ModelContainer(for: Wallet.self, Transaction.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let groupID = UUID()
        let outgoing = Transaction(type: .expense, amount: 50, category: Transaction.transferCategory, title: "→ Risparmi", transferGroupID: groupID)
        let incoming = Transaction(type: .income, amount: 50, category: Transaction.transferCategory, title: "← Conto", transferGroupID: groupID)
        let other = Transaction(type: .expense, amount: 5, category: "Cibo", title: "Caffè")
        [outgoing, incoming, other].forEach { context.insert($0) }
        try context.save()

        Transaction.delete(incoming, from: [outgoing, incoming, other], in: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Transaction>()).map(\.title)
        #expect(remaining == ["Caffè"])
    }

    @Test func legacyTransferWithoutGroupCannotBeDeletedFromList() {
        let legacy = Transaction(type: .expense, amount: 50, category: Transaction.transferCategory, title: "Vecchio")
        let normal = Transaction(type: .expense, amount: 5, category: "Cibo", title: "Caffè")
        #expect(!legacy.canBeDeleted)
        #expect(normal.canBeDeleted)
    }

    @Test func relationshipRemainingAmountNeverBecomesNegative() {
        let relationship = Relationship(personName: "Luca", amount: 100, type: .debt, paidAmount: 40)
        #expect(relationship.remainingAmount == 60)

        relationship.paidAmount = 150
        #expect(relationship.remainingAmount == 0)
    }

    @Test func recurringFrequencyProducesFutureDate() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 10))!

        let weekly = RecurringFrequency.weekly.nextDate(after: start, calendar: calendar)
        let monthly = RecurringFrequency.monthly.nextDate(after: start, calendar: calendar)
        let yearly = RecurringFrequency.yearly.nextDate(after: start, calendar: calendar)

        #expect(calendar.dateComponents([.day], from: start, to: weekly).day == 7)
        #expect(calendar.component(.month, from: monthly) == 9)
        #expect(calendar.component(.year, from: yearly) == 2027)
    }

    @Test func agendaRepeatPreservesExpectedCadence() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 18))!

        let daily = AgendaRepeat.daily.nextDate(after: start)
        let weekly = AgendaRepeat.weekly.nextDate(after: start)

        #expect(Calendar.current.dateComponents([.day], from: start, to: daily).day == 1)
        #expect(Calendar.current.dateComponents([.day], from: start, to: weekly).day == 7)
    }

    @Test func walletExchangeRateDefaultsCorrectly() {
        let eur = Wallet(name: "EUR", icon: "wallet.pass", currencyCode: "EUR")
        let foreignWithoutRate = Wallet(name: "USD", icon: "dollarsign.circle", currencyCode: "USD")
        let foreignWithRate = Wallet(name: "GBP", icon: "sterlingsign.circle", currencyCode: "GBP", exchangeRateToEUR: 1.15)

        #expect(eur.effectiveExchangeRateToEUR == 1)
        #expect(foreignWithoutRate.effectiveExchangeRateToEUR == 1)
        #expect(foreignWithRate.effectiveExchangeRateToEUR == 1.15)
    }
}
