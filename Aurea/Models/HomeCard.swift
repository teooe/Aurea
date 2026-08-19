import Foundation

enum HomeCard: String, Identifiable {
    case netWorth
    case today
    case wallets
    case goals
    case relationships

    var id: String {
        rawValue
    }
}
