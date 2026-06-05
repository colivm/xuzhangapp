import Foundation
import UIKit
import Vision

enum OCRProvider: String {
    case alipay = "支付宝"
    case wechat = "微信"
    case generic = "generic"
}

struct OCRReceiptDraft: Identifiable, Equatable {
    let id: UUID
    var title: String
    var amount: Double
    var date: Date
    var category: HomeItem.Category
    var confidence: Double
    var rawText: String
    var provider: OCRProvider

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        date: Date,
        category: HomeItem.Category,
        confidence: Double,
        rawText: String,
        provider: OCRProvider
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.confidence = confidence
        self.rawText = rawText
        self.provider = provider
    }
}

enum OCRServiceError: LocalizedError {
    case invalidImage
    case noRecognizedText
    case detailPageRequired

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "图片读取失败，请重新选择。"
        case .noRecognizedText:
            return "没有识别到账单文字，请重新截图。"
        case .detailPageRequired:
            return "请打开单笔账单详情页再截图"
        }
    }
}

final class OCRService {
    func recognizeReceipt(from imageData: Data) async throws -> [OCRReceiptDraft] {
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
        let lines = candidates
            .map(\.string)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let text = lines.joined(separator: "\n")

        guard !lines.isEmpty else {
            throw OCRServiceError.noRecognizedText
        }

        let confidence = candidates.map(\.confidence).reduce(0, +) / Float(max(candidates.count, 1))
        let provider = detectProvider(from: text)
        guard !looksLikeListScreenshot(lines: lines, provider: provider) else {
            throw OCRServiceError.detailPageRequired
        }

        let draft: OCRReceiptDraft?
        switch provider {
        case .alipay:
            draft = parseAlipay(lines: lines, rawText: text, confidence: Double(confidence))
        case .wechat:
            draft = parseWeChat(lines: lines, rawText: text, confidence: Double(confidence))
        case .generic:
            draft = parseGeneric(lines: lines, rawText: text, confidence: Double(confidence))
        }

        guard let draft, draft.amount > 0 else {
            throw OCRServiceError.detailPageRequired
        }
        return [draft]
    }

    private func detectProvider(from text: String) -> OCRProvider {
        if text.contains("支付宝") || text.contains("蚂蚁") || text.contains("花呗") {
            return .alipay
        }
        if text.contains("微信支付") || text.contains("微信") || text.contains("零钱") {
            return .wechat
        }
        return .generic
    }

    private func looksLikeListScreenshot(lines: [String], provider: OCRProvider) -> Bool {
        let text = lines.joined(separator: "\n")
        let listHints = ["账单列表", "全部交易", "交易记录", "本月支出", "本月收入", "筛选", "月账单", "全部账单"]
        let detailHints = ["账单详情", "商品说明", "商家名称", "创建时间", "付款时间", "商户全称", "支付时间", "当前状态"]
        let hasListHint = listHints.contains { text.contains($0) }
        let hasDetailHint = detailHints.contains { text.contains($0) }
        let currencyCount = currencyCandidates(in: text).count

        if hasListHint && !hasDetailHint {
            return true
        }
        if provider != .generic && currencyCount >= 4 && !hasDetailHint {
            return true
        }
        return false
    }

    private func parseAlipay(lines: [String], rawText: String, confidence: Double) -> OCRReceiptDraft? {
        let amount = amountNear(labels: ["金额", "付款金额", "实付"], in: lines) ?? currencyCandidates(in: rawText).first
        let title = valueFor(labels: ["商品说明", "商家名称", "收款方", "付款给"], in: lines) ?? fallbackTitle(from: lines)
        let date = dateNear(labels: ["付款时间", "创建时间", "交易时间"], in: lines) ?? firstDate(in: rawText)
        guard let amount, let title, let date else { return nil }

        return OCRReceiptDraft(
            title: title,
            amount: abs(amount),
            date: date,
            category: inferCategory(from: "\(title)\n\(rawText)"),
            confidence: confidence,
            rawText: rawText,
            provider: .alipay
        )
    }

    private func parseWeChat(lines: [String], rawText: String, confidence: Double) -> OCRReceiptDraft? {
        let amount = amountNear(labels: ["金额", "支付金额", "转账金额"], in: lines) ?? currencyCandidates(in: rawText).first
        let title = valueFor(labels: ["商户全称", "商品", "收款方", "对方"], in: lines) ?? fallbackTitle(from: lines)
        let date = dateNear(labels: ["支付时间", "交易时间", "转账时间"], in: lines) ?? firstDate(in: rawText)
        guard let amount, let title, let date else { return nil }

        return OCRReceiptDraft(
            title: title,
            amount: abs(amount),
            date: date,
            category: inferCategory(from: "\(title)\n\(rawText)"),
            confidence: confidence,
            rawText: rawText,
            provider: .wechat
        )
    }

    private func parseGeneric(lines: [String], rawText: String, confidence: Double) -> OCRReceiptDraft? {
        guard let amount = currencyCandidates(in: rawText).first ?? plainAmountCandidates(in: rawText).max(),
              let title = fallbackTitle(from: lines) else {
            return nil
        }
        return OCRReceiptDraft(
            title: title,
            amount: abs(amount),
            date: firstDate(in: rawText) ?? .now,
            category: inferCategory(from: rawText),
            confidence: confidence,
            rawText: rawText,
            provider: .generic
        )
    }

    private func amountNear(labels: [String], in lines: [String]) -> Double? {
        for (index, line) in lines.enumerated() where labels.contains(where: { line.contains($0) }) {
            let scope = lines[index..<min(lines.count, index + 3)].joined(separator: "\n")
            if let amount = currencyCandidates(in: scope).first ?? plainAmountCandidates(in: scope).max() {
                return amount
            }
        }
        return nil
    }

    private func valueFor(labels: [String], in lines: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            guard let label = labels.first(where: { line.contains($0) }) else { continue }
            let sameLine = line
                .replacingOccurrences(of: label, with: "")
                .replacingOccurrences(of: "：", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if isUsableTitle(sameLine) {
                return sameLine
            }
            if index + 1 < lines.count {
                let next = lines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                if isUsableTitle(next) {
                    return next
                }
            }
        }
        return nil
    }

    private func fallbackTitle(from lines: [String]) -> String? {
        let blocked = ["¥", "￥", "金额", "时间", "订单", "单号", "支付", "账单", "详情", "当前状态", "成功", "付款方式"]
        return lines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isUsableTitle(trimmed) else { return false }
            return !blocked.contains { trimmed.contains($0) }
        }
    }

    private func isUsableTitle(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 40 else { return false }
        if trimmed.range(of: #"^\d{4}[-/.年]"#, options: .regularExpression) != nil { return false }
        if trimmed.range(of: #"[¥￥]\s*-?\d"#, options: .regularExpression) != nil { return false }
        return true
    }

    private func dateNear(labels: [String], in lines: [String]) -> Date? {
        for (index, line) in lines.enumerated() where labels.contains(where: { line.contains($0) }) {
            let scope = lines[index..<min(lines.count, index + 3)].joined(separator: " ")
            if let date = firstDate(in: scope) {
                return date
            }
        }
        return nil
    }

    private func firstDate(in text: String) -> Date? {
        let pattern = #"20\d{2}[-/.年]\d{1,2}[-/.月]\d{1,2}[日\s]*\d{0,2}:?\d{0,2}:?\d{0,2}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else {
            return nil
        }
        let raw = nsText.substring(with: match.range)
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = ["yyyy-M-d HH:mm:ss", "yyyy-M-d HH:mm", "yyyy-M-d"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return nil
    }

    private func currencyCandidates(in text: String) -> [Double] {
        let pattern = #"[-+]?\s*[¥￥]\s*([0-9]+(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let full = nsText.substring(with: match.range(at: 0))
            let value = nsText.substring(with: match.range(at: 1))
            let sign = full.contains("-") ? -1.0 : 1.0
            return (Double(value) ?? 0) * sign
        }
    }

    private func plainAmountCandidates(in text: String) -> [Double] {
        let pattern = #"(?<!\d)([0-9]{1,6}(?:\.[0-9]{1,2})?)\s*元"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return Double(nsText.substring(with: match.range(at: 1)))
        }
    }

    private func inferCategory(from text: String) -> HomeItem.Category {
        let lower = text.lowercased()
        if lower.contains("咖啡") || lower.contains("餐") || lower.contains("外卖") || lower.contains("饭") || lower.contains("茶") {
            return .dining
        }
        if lower.contains("地铁") || lower.contains("公交") || lower.contains("打车") || lower.contains("滴滴") || lower.contains("铁路") {
            return .transport
        }
        if lower.contains("超市") || lower.contains("商城") || lower.contains("购物") || lower.contains("淘宝") || lower.contains("京东") {
            return .shopping
        }
        if lower.contains("电影") || lower.contains("游戏") || lower.contains("会员") {
            return .entertainment
        }
        if lower.contains("酒店") || lower.contains("住宿") || lower.contains("民宿") {
            return .lodging
        }
        return .daily
    }
}
