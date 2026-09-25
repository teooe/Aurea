import Foundation
import SwiftData

enum FinancialEngine {

    static func balance(for wallet: Wallet) -> Decimal {
        wallet.transactions.reduce(wallet.initialBalance) { balance, transaction in
            switch transaction.type {
            case .income:
                return balance + transaction.amount
            case .expense:
                return balance - transaction.amount
            case .transfer:
                return balance
            }
        }
    }

    static func amountInEUR(for transaction: Transaction) -> Decimal {
        transaction.amount * (transaction.wallet?.effectiveExchangeRateToEUR ?? 1)
    }

    static func balanceInEUR(for wallet: Wallet) -> Decimal {
        balance(for: wallet) * wallet.effectiveExchangeRateToEUR
    }

    static func netWorth(wallets: [Wallet]) -> Decimal {
        wallets
            .filter { !$0.isArchived }
            .reduce(0) { $0 + balanceInEUR(for: $1) }
    }

    static func totalIncome(from transactions: [Transaction]) -> Decimal {
        transactions
            .filter { $0.type == .income && !$0.isTransfer }
            .reduce(Decimal.zero) { $0 + amountInEUR(for: $1) }
    }

    static func totalExpenses(from transactions: [Transaction]) -> Decimal {
        transactions
            .filter { $0.type == .expense && !$0.isTransfer }
            .reduce(Decimal.zero) { $0 + amountInEUR(for: $1) }
    }

    static func cashFlow(from transactions: [Transaction]) -> Decimal {
        totalIncome(from: transactions) - totalExpenses(from: transactions)
    }

    static func spentThisMonth(for budget: Budget, transactions: [Transaction], calendar: Calendar = .current) -> Decimal {
        let monthTransactions = transactions.filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
        return monthTransactions
            .filter { transaction in
                transaction.type == .expense &&
                !transaction.isTransfer &&
                (budget.category == nil || transaction.category == budget.category)
            }
            .reduce(Decimal.zero) { $0 + amountInEUR(for: $1) }
    }

    /// Quanto si può spendere al giorno, da oggi a fine mese compresi, per restare nel limite.
    /// Zero se il budget è già esaurito. Arrotondato per difetto al centesimo, per non superarlo.
    static func dailyAllowance(limit: Decimal, spent: Decimal, now: Date = .now, calendar: Calendar = .current) -> Decimal {
        let remaining = limit - spent
        guard remaining > 0,
              let days = calendar.range(of: .day, in: .month, for: now)?.count else { return 0 }
        let daysLeft = max(days - calendar.component(.day, from: now) + 1, 1)
        var perDay = remaining / Decimal(daysLeft)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &perDay, 2, .down)
        return rounded
    }
}
