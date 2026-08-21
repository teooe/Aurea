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
            HStack(spacing: Theme.Spacing.regular) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 30, height: 30)
                    .background(Theme.Colors.subtleFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.primaryText)

                Spacer(minLength: 0)
            }

            content
        }
        .padding(Theme.Layout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .fill(Theme.Colors.card)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .strokeBorder(Theme.Colors.separator, lineWidth: 0.75)
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

#Preview {
    ZStack {
        Theme.Colors.background.ignoresSafeArea()

        AureaCard(title: "Patrimonio", icon: "wallet.pass") {
            Text("€ 0,00")
                .font(.largeTitle.weight(.semibold))
                .monospacedDigit()
        }
        .padding()
    }
}
