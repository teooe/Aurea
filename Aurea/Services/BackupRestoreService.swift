import Foundation
import SwiftData

enum BackupRestoreService {
    struct Payload: Codable {
        var version: Int = 2
        var createdAt: Date = .now
        var wallets: [WalletDTO]
        var transactions: [TransactionDTO]
        var agenda: [AgendaDTO]
        var goals: [GoalDTO]
        var relationships: [RelationshipDTO]
        var relationshipPayments: [RelationshipPaymentDTO]
        var budgets: [BudgetDTO]
        var recurring: [RecurringDTO]
        var categories: [CategoryDTO]
    }

    struct WalletDTO: Codable { var name: String; var icon: String; var currencyCode: String; var initialBalance: Decimal; var exchangeRateToEUR: Decimal?; var isArchived: Bool }
    struct TransactionDTO: Codable { var id: UUID; var type: String; var amount: Decimal; var date: Date; var category: String; var title: String; var walletName: String?; var transferGroupID: UUID? }
    struct AgendaDTO: Codable { var title: String; var note: String; var type: String; var date: Date; var hasTime: Bool; var endDate: Date?; var isCompleted: Bool; var repeatRule: String; var reminderMinutesBefore: Int?; var createdAt: Date; var priority: String }
    struct GoalDTO: Codable { var id: UUID; var title: String; var type: String; var targetAmount: Decimal?; var currentAmount: Decimal; var targetDate: Date?; var createdAt: Date; var isCompleted: Bool; var linkedWalletName: String? }
    struct RelationshipDTO: Codable { var id: UUID; var personName: String; var amount: Decimal; var type: String; var note: String; var createdAt: Date; var isClosed: Bool; var dueDate: Date?; var paidAmount: Decimal? }
    struct RelationshipPaymentDTO: Codable { var id: UUID; var relationshipID: UUID; var amount: Decimal; var date: Date }
    struct BudgetDTO: Codable { var id: UUID; var title: String; var category: String?; var monthlyLimit: Decimal; var createdAt: Date; var isArchived: Bool }
    struct RecurringDTO: Codable { var id: UUID; var title: String; var amount: Decimal; var category: String; var type: String; var frequency: String; var nextDate: Date; var isActive: Bool; var walletName: String? }
    struct CategoryDTO: Codable { var id: UUID; var name: String; var type: String; var icon: String; var isArchived: Bool }

    static func makePayload(context: ModelContext) throws -> Payload {
        let wallets = try context.fetch(FetchDescriptor<Wallet>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let agenda = try context.fetch(FetchDescriptor<AgendaItem>())
        let goals = try context.fetch(FetchDescriptor<Goal>())
        let relationships = try context.fetch(FetchDescriptor<Relationship>())
        let payments = try context.fetch(FetchDescriptor<RelationshipPayment>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let recurring = try context.fetch(FetchDescriptor<RecurringTransaction>())
        let categories = try context.fetch(FetchDescriptor<FinanceCategory>())

        return Payload(
            wallets: wallets.map { .init(name: $0.name, icon: $0.icon, currencyCode: $0.currencyCode, initialBalance: $0.initialBalance, exchangeRateToEUR: $0.exchangeRateToEUR, isArchived: $0.isArchived) },
            transactions: transactions.map { .init(id: $0.id, type: $0.type.rawValue, amount: $0.amount, date: $0.date, category: $0.category, title: $0.title, walletName: $0.wallet?.name, transferGroupID: $0.transferGroupID) },
            agenda: agenda.map { .init(title: $0.title, note: $0.note, type: $0.type.rawValue, date: $0.date, hasTime: $0.hasTime, endDate: $0.endDate, isCompleted: $0.isCompleted, repeatRule: $0.repeatRule.rawValue, reminderMinutesBefore: $0.reminderMinutesBefore, createdAt: $0.createdAt, priority: $0.priority.rawValue) },
            goals: goals.map { .init(id: $0.id, title: $0.title, type: $0.type.rawValue, targetAmount: $0.targetAmount, currentAmount: $0.currentAmount, targetDate: $0.targetDate, createdAt: $0.createdAt, isCompleted: $0.isCompleted, linkedWalletName: $0.linkedWallet?.name) },
            relationships: relationships.map { .init(id: $0.id, personName: $0.personName, amount: $0.amount, type: $0.type.rawValue, note: $0.note, createdAt: $0.createdAt, isClosed: $0.isClosed, dueDate: $0.dueDate, paidAmount: $0.paidAmount) },
            relationshipPayments: payments.map { .init(id: $0.id, relationshipID: $0.relationshipID, amount: $0.amount, date: $0.date) },
            budgets: budgets.map { .init(id: $0.id, title: $0.title, category: $0.category, monthlyLimit: $0.monthlyLimit, createdAt: $0.createdAt, isArchived: $0.isArchived) },
            recurring: recurring.map { .init(id: $0.id, title: $0.title, amount: $0.amount, category: $0.category, type: $0.type.rawValue, frequency: $0.frequency.rawValue, nextDate: $0.nextDate, isActive: $0.isActive, walletName: $0.wallet?.name) },
            categories: categories.map { .init(id: $0.id, name: $0.name, type: $0.type.rawValue, icon: $0.icon, isArchived: $0.isArchived) }
        )
    }

    static func encode(_ payload: Payload) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return String(data: try encoder.encode(payload), encoding: .utf8) ?? "{}"
    }

    static func decode(_ data: Data) throws -> Payload {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Payload.self, from: data)
    }

    static func restore(_ payload: Payload, context: ModelContext) throws {
        try deleteAll(context)
        var walletMap: [String: Wallet] = [:]
        for dto in payload.wallets {
            let wallet = Wallet(name: dto.name, icon: dto.icon, currencyCode: dto.currencyCode, initialBalance: dto.initialBalance, exchangeRateToEUR: dto.exchangeRateToEUR, isArchived: dto.isArchived)
            context.insert(wallet); walletMap[dto.name] = wallet
        }
        for dto in payload.categories {
            let item = FinanceCategory(name: dto.name, type: TransactionType(rawValue: dto.type) ?? .expense, icon: dto.icon, isArchived: dto.isArchived); item.id = dto.id; context.insert(item)
        }
        for dto in payload.transactions {
            let item = Transaction(type: TransactionType(rawValue: dto.type) ?? .expense, amount: dto.amount, date: dto.date, category: dto.category, title: dto.title, wallet: dto.walletName.flatMap { walletMap[$0] }, transferGroupID: dto.transferGroupID); item.id = dto.id; context.insert(item)
        }
        for dto in payload.agenda {
            context.insert(AgendaItem(title: dto.title, note: dto.note, type: AgendaItemType(rawValue: dto.type) ?? .task, date: dto.date, hasTime: dto.hasTime, endDate: dto.endDate, isCompleted: dto.isCompleted, repeatRule: AgendaRepeat(rawValue: dto.repeatRule) ?? .never, reminderMinutesBefore: dto.reminderMinutesBefore, createdAt: dto.createdAt, priority: AgendaPriority(rawValue: dto.priority) ?? .normal))
        }
        for dto in payload.goals {
            let item = Goal(title: dto.title, type: GoalType(rawValue: dto.type) ?? .economic, targetAmount: dto.targetAmount, currentAmount: dto.currentAmount, targetDate: dto.targetDate, createdAt: dto.createdAt, isCompleted: dto.isCompleted, linkedWallet: dto.linkedWalletName.flatMap { walletMap[$0] }); item.id = dto.id; context.insert(item)
        }
        for dto in payload.relationships {
            let item = Relationship(personName: dto.personName, amount: dto.amount, type: RelationshipType(rawValue: dto.type) ?? .debt, note: dto.note, createdAt: dto.createdAt, isClosed: dto.isClosed, dueDate: dto.dueDate, paidAmount: dto.paidAmount); item.id = dto.id; context.insert(item)
        }
        for dto in payload.relationshipPayments { let item = RelationshipPayment(relationshipID: dto.relationshipID, amount: dto.amount, date: dto.date); item.id = dto.id; context.insert(item) }
        for dto in payload.budgets { let item = Budget(title: dto.title, category: dto.category, monthlyLimit: dto.monthlyLimit, createdAt: dto.createdAt, isArchived: dto.isArchived); item.id = dto.id; context.insert(item) }
        for dto in payload.recurring { let item = RecurringTransaction(title: dto.title, amount: dto.amount, category: dto.category, type: TransactionType(rawValue: dto.type) ?? .expense, frequency: RecurringFrequency(rawValue: dto.frequency) ?? .monthly, nextDate: dto.nextDate, wallet: dto.walletName.flatMap { walletMap[$0] }, isActive: dto.isActive); item.id = dto.id; context.insert(item) }
        CategoryService.synchronize(in: context)
        try context.save()
    }

    private static func deleteAll(_ context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<RelationshipPayment>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Transaction>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<RecurringTransaction>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Goal>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<AgendaItem>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Budget>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<FinanceCategory>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Relationship>()) { context.delete(item) }
        for item in try context.fetch(FetchDescriptor<Wallet>()) { context.delete(item) }
        try context.save()
    }
}
