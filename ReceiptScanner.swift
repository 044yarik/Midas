import SwiftUI
import VisionKit
import Vision

struct ParsedReceipt: Identifiable {
    let id = UUID()
    var merchant: String
    var total: Double
    var itemsCount: Int
    var date: Date
}

// MARK: - Камера-сканер документов (VisionKit)

struct DocumentScanner: UIViewControllerRepresentable {
    var onResult: (ParsedReceipt?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ p: DocumentScanner) { parent = p }

        func documentCameraViewController(_ c: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage }
            Task {
                let lines = await ReceiptOCR.recognize(images)
                let parsed = ReceiptOCR.parse(lines)
                await MainActor.run { parent.onResult(parsed); parent.dismiss() }
            }
        }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) {
            parent.onResult(nil); parent.dismiss()
        }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError e: Error) {
            parent.onResult(nil); parent.dismiss()
        }
    }
}

// MARK: - OCR + разбор чека

enum ReceiptOCR {
    static func recognize(_ images: [CGImage]) async -> [String] {
        var all: [String] = []
        for img in images {
            let lines: [String] = await withCheckedContinuation { cont in
                let req = VNRecognizeTextRequest { r, _ in
                    let obs = (r.results as? [VNRecognizedTextObservation]) ?? []
                    cont.resume(returning: obs.compactMap { $0.topCandidates(1).first?.string })
                }
                req.recognitionLevel = .accurate
                req.usesLanguageCorrection = true
                req.recognitionLanguages = ["uk-UA", "ru-RU", "en-US"]
                try? VNImageRequestHandler(cgImage: img).perform([req])
            }
            all += lines
        }
        return all
    }

    private static let totalKeys = ["до сплати", "сума", "разом", "всього", "итого", "всего", "total", "к оплате"]

    static func parse(_ lines: [String]) -> ParsedReceipt? {
        guard !lines.isEmpty else { return nil }

        // 1. Итог: число в строке с ключевым словом (или в следующей строке)
        var total: Double?
        for (i, line) in lines.enumerated() {
            let low = line.lowercased()
            guard totalKeys.contains(where: { low.contains($0) }) else { continue }
            if let v = amounts(in: line).max() { total = max(total ?? 0, v) }
            else if i + 1 < lines.count, let v = amounts(in: lines[i + 1]).max() { total = max(total ?? 0, v) }
        }
        // 2. Запасной вариант: самое большое число с копейками
        if total == nil { total = lines.flatMap(amounts(in:)).max() }
        guard let sum = total else { return nil }

        // Магазин: первая «осмысленная» строка сверху
        let merchant = lines.prefix(6).first { l in
            let letters = l.filter(\.isLetter).count
            return letters >= 3 && !l.lowercased().contains("чек")
        } ?? "Чек"

        // Позиции: строки вида "... 12,50" без ключевых слов итога
        let items = lines.filter { l in
            !amounts(in: l).isEmpty && !totalKeys.contains(where: { l.lowercased().contains($0) })
        }.count

        return ParsedReceipt(merchant: merchant.trimmingCharacters(in: .whitespaces),
                             total: sum, itemsCount: max(items, 1), date: .now)
    }

    /// Числа вида 62,57 / 62.57 / 1 234,50
    private static func amounts(in s: String) -> [Double] {
        let pattern = #"\d{1,3}(?:[  ]\d{3})*[.,]\d{2}(?!\d)"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap {
            let raw = ns.substring(with: $0.range)
                .replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Double(raw)
        }
    }
}
