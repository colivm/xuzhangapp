import Foundation
import UIKit
import Vision

struct OCRReceiptDraft {
    var title: String
    var amount: Double
    var date: Date
    var category: HomeItem.Category
    var confidence: Double
    var rawText: String
}

enum OCRServiceError: Error {
    case invalidImage
    case noRecognizedText
}

final class OCRService {
    func recognizeReceipt(from imageData: Data) async throws -> OCRReceiptDraft {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw OCRServiceError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let observations = request.results ?? []
        let candidates = observations.compactMap { $0.topCandidates(1).first }
        let lines = candidates.map(\.string).filter { !$0.isEmpty }
        let text = lines.joined(separator: "\n")

        guard !lines.isEmpty else {
            throw OCRServiceError.noRecognizedText
        }

        let amount = extractAmount(from: text) ?? 0
        let merchant = extractMerchant(from: lines) ?? "OCR识别账单"
        let category = inferCategory(from: text)
        let confidence = candidates.map(\.confidence).reduce(0, +) / Float(max(candidates.count, 1))

        return OCRReceiptDraft(
            title: merchant,
            amount: amount,
            date: .now,
            category: category,
            confidence: Double(confidence),
            rawText: text
        )
    }

    private func extractAmount(from text: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        let values = matches.compactMap { match -> Double? in
            guard match.numberOfRanges > 1 else { return nil }
            let value = nsText.substring(with: match.range(at: 1))
            return Double(value)
        }
        return values.max()
    }

    private func extractMerchant(from lines: [String]) -> String? {
        lines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { return false }
            return !trimmed.contains("¥") && !trimmed.lowercased().contains("total")
        }
    }

    private func inferCategory(from text: String) -> HomeItem.Category {
        let lower = text.lowercased()
        if lower.contains("咖啡") || lower.contains("餐") || lower.contains("外卖") {
            return .dining
        }
        if lower.contains("地铁") || lower.contains("公交") || lower.contains("打车") {
            return .transport
        }
        if lower.contains("超市") || lower.contains("商城") || lower.contains("购物") {
            return .shopping
        }
        if lower.contains("酒店") || lower.contains("住宿") {
            return .lodging
        }
        return .daily
    }
}
