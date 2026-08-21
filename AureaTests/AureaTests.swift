import Testing
import Foundation
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
