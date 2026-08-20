import SwiftUI

struct GoalsCardView: View {

    let goals: [Goal]
    let isExpanded: Bool
    let onTap: () -> Void
    let onAddGoal: () -> Void
    let onSelectGoal: (Goal) -> Void

    private var activeGoals: [Goal] {
        goals.filter { !$0.isCompleted }
    }

    private var completedGoals: [Goal] {
        goals.filter { $0.isCompleted }
    }

    var body: some View {
        AureaCard(
            title: "Obiettivi",
            icon: "target"
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Button {
                    onTap()
                } label: {
                    HStack {
                        if activeGoals.isEmpty {
                            Text("Nessun obiettivo attivo")
                                .foregroundStyle(Theme.Colors.secondaryText)
                        } else {
                            Text("\(activeGoals.count) obiettiv\(activeGoals.count == 1 ? "o" : "i") attiv\(activeGoals.count == 1 ? "o" : "i")")
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if !activeGoals.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                            Text("In corso")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.secondaryText)

                            ForEach(activeGoals) { goal in
                                goalButton(goal)
                            }
                        }
                    }

                    if !completedGoals.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                            Text("Completati")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.Colors.secondaryText)

                            ForEach(completedGoals) { goal in
                                goalButton(goal)
                                    .opacity(0.65)
                            }
                        }
                    }

                    Button {
                        onAddGoal()
                    } label: {
                        Label("Aggiungi obiettivo", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func goalButton(_ goal: Goal) -> some View {
        Button {
            onSelectGoal(goal)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                HStack {
                    Text(goal.title)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(goal.isCompleted ? "100%" : progressText(for: goal))
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                ProgressView(value: goal.isCompleted ? 1 : progress(for: goal))

                if let detail = detailText(for: goal) {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func progress(for goal: Goal) -> Double {
        switch goal.type {
        case .economic:
            return economicProgress(for: goal)
        case .temporal:
            return temporalProgress(for: goal)
        case .both:
            return min(economicProgress(for: goal), temporalProgress(for: goal))
        }
    }

    private func economicProgress(for goal: Goal) -> Double {
        guard let target = goal.targetAmount, target > 0 else { return 0 }
        let current = NSDecimalNumber(decimal: goal.currentAmount).doubleValue
        let targetValue = NSDecimalNumber(decimal: target).doubleValue
        return min(max(current / targetValue, 0), 1)
    }

    private func temporalProgress(for goal: Goal) -> Double {
        guard let targetDate = goal.targetDate else { return 0 }
        let total = targetDate.timeIntervalSince(goal.createdAt)
        guard total > 0 else { return 1 }
        let elapsed = Date().timeIntervalSince(goal.createdAt)
        return min(max(elapsed / total, 0), 1)
    }

    private func progressText(for goal: Goal) -> String {
        "\(Int((progress(for: goal) * 100).rounded()))%"
    }

    private func detailText(for goal: Goal) -> String? {
        var parts: [String] = []

        if let target = goal.targetAmount {
            parts.append(
                "\(goal.currentAmount.formatted(.currency(code: "EUR"))) / \(target.formatted(.currency(code: "EUR")))"
            )
        }

        if let targetDate = goal.targetDate {
            parts.append("entro il \(targetDate.formatted(date: .abbreviated, time: .omitted))")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
