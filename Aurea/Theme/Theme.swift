import SwiftUI

enum Theme {
    
    // MARK: - Colors
    
    enum Colors {
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let card = Color(.systemBackground)
        
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        
        static let income = Color.green
        static let expense = Color.red
        static let accent = Color.accentColor
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let small: CGFloat = 8
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
    
    // MARK: - Animation
    
    enum Animation {
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
    }
}
