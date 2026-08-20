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

    static func netWorth(wallets: [Wallet]) -> Decimal {
        wallets.reduce(0) { total, wallet in
            total + balance(for: wallet)
        }
    }

    static func totalIncome(from transactions: [Transaction]) -> Decimal {
        transactions
            .filter { $0.type == .income && $0.category != "Trasferimento" }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    static func totalExpenses(from transactions: [Transaction]) -> Decimal {
        transactions
            .filter { $0.type == .expense && $0.category != "Trasferimento" }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    static func cashFlow(from transactions: [Transaction]) -> Decimal {
        totalIncome(from: transactions) - totalExpenses(from: transactions)
    }
}
