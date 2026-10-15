import SwiftUI
import UIKit

/// Preparazione e visualizzazione della foto dello scontrino allegata a un movimento.
enum ReceiptImage {
    /// Lato lungo massimo: abbastanza per leggere uno scontrino, senza occupare megabyte.
    static let maxDimension: CGFloat = 1600

    /// Ridimensiona e comprime in JPEG. Restituisce nil se l'immagine non è utilizzabile.
    static func jpegData(from image: UIImage, quality: CGFloat = 0.7) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

/// Foto a schermo intero, con zoom a due dita e doppio tocco.
struct ReceiptImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width * scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { scale = min(max(lastScale * $0.magnification, 1), 5) }
                            .onEnded { _ in lastScale = scale }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation { scale = scale > 1 ? 1 : 2.5; lastScale = scale }
                    }
            }
            }
            .background(Color.black)
            .navigationTitle("Scontrino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
    }
}
