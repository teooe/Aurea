import SwiftUI

struct BrandSplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var background: Color {
        colorScheme == .dark
            ? Color(red: 0.055, green: 0.125, blue: 0.205)
            : Color(.systemBackground)
    }

    private var foreground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color(red: 0.055, green: 0.125, blue: 0.205)
    }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            horizonWaves
                .opacity(colorScheme == .dark ? 0.14 : 0.08)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                OrizzonteMark()
                    .stroke(
                        foreground,
                        style: StrokeStyle(
                            lineWidth: 5.5,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: 128, height: 108)

                Text("AUREA")
                    .font(.system(size: 30, weight: .medium, design: .default))
                    .tracking(8)
                    .foregroundStyle(foreground)
                    .padding(.leading, 8)

                Text("gestisci oggi\nil tuo domani")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(foreground.opacity(0.78))
                    .lineSpacing(3)

                Circle()
                    .fill(Color(red: 0.98, green: 0.68, blue: 0.10))
                    .frame(width: 8, height: 8)
                    .padding(.top, 26)

                Spacer()
                    .frame(height: 140)
            }
        }
        .accessibilityHidden(true)
    }

    private var horizonWaves: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let baseY = size.height * 0.82
                let amplitudes: [CGFloat] = [26, 44, 62]

                for (index, amplitude) in amplitudes.enumerated() {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: baseY + CGFloat(index) * 18))

                    let step: CGFloat = 8
                    var x: CGFloat = 0
                    while x <= size.width {
                        let phase = (x / max(size.width, 1)) * .pi * 2
                        let y = baseY
                            + CGFloat(index) * 18
                            + sin(phase + CGFloat(index) * 0.9) * amplitude
                        path.addLine(to: CGPoint(x: x, y: y))
                        x += step
                    }

                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.addLine(to: CGPoint(x: 0, y: size.height))
                    path.closeSubpath()

                    context.fill(path, with: .color(foreground.opacity(0.34 - Double(index) * 0.07)))
                }
            }
        }
    }
}

private struct OrizzonteMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let midX = rect.midX
        let topY = rect.minY + rect.height * 0.06
        let legY = rect.minY + rect.height * 0.69
        let leftX = rect.minX + rect.width * 0.27
        let rightX = rect.maxX - rect.width * 0.27

        path.move(to: CGPoint(x: leftX, y: legY))
        path.addLine(to: CGPoint(x: midX, y: topY))
        path.addLine(to: CGPoint(x: rightX, y: legY))

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.minY + rect.height * 0.46))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.37, y: rect.minY + rect.height * 0.46))

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.minY + rect.height * 0.59))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.33, y: rect.minY + rect.height * 0.59))

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.90))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.minY + rect.height * 0.90),
            control: CGPoint(x: midX, y: rect.minY + rect.height * 0.64)
        )

        return path
    }
}

#Preview("Chiara") {
    BrandSplashView()
        .preferredColorScheme(.light)
}

#Preview("Scura") {
    BrandSplashView()
        .preferredColorScheme(.dark)
}
