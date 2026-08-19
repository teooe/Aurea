import SwiftUI

struct AureaCard<Content: View>: View {
    
    let title: String
    let icon: String
    let content: Content
    
    init(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                
                Spacer()
            }
            
            content
        }
        .padding(Theme.Spacing.large)
        .background(Theme.Colors.card)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Theme.Radius.medium,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: Theme.Radius.medium,
                style: .continuous
            )
            .strokeBorder(
                Color.primary.opacity(0.08),
                lineWidth: 1
            )
        }
    }
}

#Preview {
    AureaCard(
        title: "Patrimonio",
        icon: "wallet.pass"
    ) {
        Text("€ 0,00")
            .font(.largeTitle)
            .fontWeight(.semibold)
    }
    .padding()
}
