import UIKit
import Vision

/// Legge il testo di uno scontrino con Vision, interamente sul dispositivo (nessun invio in rete).
/// `nonisolated`: le callback di Vision arrivano su un thread in background, non sul MainActor.
nonisolated enum ReceiptScanner {

    enum ScanError: LocalizedError {
        case unreadableImage
        var errorDescription: String? { "Immagine non leggibile." }
    }

    /// Righe di testo di tutte le pagine, dall'alto in basso.
    static func lines(from images: [UIImage]) async throws -> [String] {
        var result: [String] = []
        for image in images {
            result += try await lines(from: image)
        }
        return result
    }

    static func lines(from image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw ScanError.unreadableImage }
        let orientation = cgOrientation(image.imageOrientation)

        // perform è sincrono: lo si esegue fuori dal thread principale e si riprende il continuation una sola volta.
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["it-IT", "en-US"]
                // La correzione linguistica "aggiusta" i numeri in parole: meglio il testo grezzo.
                request.usesLanguageCorrection = false

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                do {
                    try handler.perform([request])
                    continuation.resume(returning: joinIntoRows(request.results ?? []))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Vision restituisce blocchi separati: "TOTALE" a sinistra e "12,50" a destra sono due osservazioni.
    /// Le riunisce in righe (stessa altezza), ordinate dall'alto e da sinistra a destra.
    private static func joinIntoRows(_ observations: [VNRecognizedTextObservation]) -> [String] {
        let items = observations.compactMap { observation -> (box: CGRect, text: String)? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return (observation.boundingBox, text)
        }
        // Coordinate di Vision: origine in basso a sinistra, quindi y più alta = più in alto.
        let sorted = items.sorted { $0.box.midY > $1.box.midY }

        var rows: [[(box: CGRect, text: String)]] = []
        for item in sorted {
            if let last = rows.last?.first, abs(last.box.midY - item.box.midY) < max(last.box.height, item.box.height) * 0.5 {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
            }
        }
        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
        }
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
