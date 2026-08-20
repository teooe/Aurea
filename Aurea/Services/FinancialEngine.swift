import Foundation

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
            .filter { $0.type == .income && $0.category != "Trasferimento" }
            .reduce(Decimal.zero) { $0 + amountInEUR(for: $1) }
    }

    static func totalExpenses(from transactions: [Transaction]) -> Decimal {
        transactions
            .filter { $0.type == .expense && $0.category != "Trasferimento" }
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
                transaction.category != "Trasferimento" &&
                (budget.category == nil || transaction.category == budget.category)
            }
            .reduce(Decimal.zero) { $0 + amountInEUR(for: $1) }
    }
}
