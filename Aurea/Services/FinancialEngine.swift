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
}
