import SwiftUI

enum Theme {

    // MARK: - Colors

    enum Colors {
        static let background = Color(.systemGroupedBackground)
        static let secondaryBackground = Color(.secondarySystemGroupedBackground)
        static let card = Color(.secondarySystemGroupedBackground)

        static let primaryText = Color.primary
        static let secondaryText = Color.secondary

        static let income = Color.green
        static let expense = Color.red
        static let accent = Color.accentColor
        static let separator = Color.primary.opacity(0.08)
        static let subtleFill = Color.primary.opacity(0.045)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let regular: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 24
    }

    // MARK: - Layout

    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let cardPadding: CGFloat = 20
        static let minimumTapTarget: CGFloat = 44
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.18)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.28)
        static let spring = SwiftUI.Animation.spring(response: 0.34, dampingFraction: 0.86)
    }
}
