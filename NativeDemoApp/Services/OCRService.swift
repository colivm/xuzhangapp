import Foundation
import ImageIO
import UIKit
import Vision

enum OCRProvider: String {
    case alipay = "支付宝"
    case wechat = "微信"
    case generic = "generic"
}

enum OCRDraftReviewStatus: String, Equatable {
    case ready
    case needsReview
    case possibleDuplicate
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
    var merchantBrandId: String?
    var userEditedCategory: Bool?
    var categoryCorrectionFrom: HomeItem.Category?
    var reviewNote: String?
    var defaultSelected: Bool
    var reviewStatus: OCRDraftReviewStatus

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        date: Date,
        category: HomeItem.Category,
        confidence: Double,
        rawText: String,
        provider: OCRProvider,
        merchantBrandId: String? = nil,
        userEditedCategory: Bool? = nil,
        categoryCorrectionFrom: HomeItem.Category? = nil,
        reviewNote: String? = nil,
        defaultSelected: Bool = true,
        reviewStatus: OCRDraftReviewStatus = .ready
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.confidence = confidence
        self.rawText = rawText
        self.provider = provider
        self.merchantBrandId = merchantBrandId
        self.userEditedCategory = userEditedCategory
        self.categoryCorrectionFrom = categoryCorrectionFrom
        self.reviewNote = reviewNote
        self.defaultSelected = defaultSelected
        self.reviewStatus = reviewStatus
    }
}

enum OCRServiceError: LocalizedError {
    case invalidImage
    case noRecognizedText
    case detailPageRequired

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "这张图片没打开成功，请重新选择一张。"
        case .noRecognizedText:
            return "没看到账单文字。请截取包含商户、金额和时间的页面再试。"
        case .detailPageRequired:
            return "没找到金额。请换一张更清晰、包含金额的账单截图。"
        }
    }
}

final class OCRService {
    private enum ListAmountInfo {
        case expense(amount: Double, inlineTitle: String?)
        case ignored
    }

    private enum ListParseMode {
        case alipay
        case wechat
        case generic

        var provider: OCRProvider {
            switch self {
            case .alipay: return .alipay
            case .wechat: return .wechat
            case .generic: return .generic
            }
        }
    }

    private enum OCRPageType: Equatable {
        case detail
        case list
        case unknown
    }

    private struct OCRLine {
        let text: String
        let boundingBox: CGRect
    }

    func recognizeReceipt(from imageData: Data) async throws -> [OCRReceiptDraft] {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw OCRServiceError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation)
        )
        try handler.perform([request])

        let recognizedLines = (request.results ?? [])
            .compactMap { observation -> (candidate: VNRecognizedText, box: CGRect)? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return (candidate, observation.boundingBox)
            }
            .compactMap { item -> (candidate: VNRecognizedText, line: OCRLine)? in
                let text = item.candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return (item.candidate, OCRLine(text: text, boundingBox: item.box))
            }
            .sorted { lhs, rhs in
                if isSameOCRRow(lhs.line.boundingBox, rhs.line.boundingBox) {
                    return lhs.line.boundingBox.minX < rhs.line.boundingBox.minX
                }
                return lhs.line.boundingBox.minY > rhs.line.boundingBox.minY
            }
        let candidates = recognizedLines.map { $0.candidate }
        let ocrLines = recognizedLines.map { $0.line }
        let lines = ocrLines.map { $0.text }

        guard !lines.isEmpty else {
            throw OCRServiceError.noRecognizedText
        }

        let confidence = candidates.map(\.confidence).reduce(0, +) / Float(max(candidates.count, 1))
        let contentOCRLines = ocrLines.filter { !isSystemUILine($0) }
        let parseOCRLines = contentOCRLines.isEmpty ? ocrLines : contentOCRLines
        let parseLines = parseOCRLines.map(\.text)
        let parseText = parseLines.joined(separator: "\n")
        let provider = detectProvider(from: parseText)

        if looksLikeAlipayOrderDisplayDetail(lines: parseLines),
           let draft = parseAlipayOrderDisplayDetail(
               ocrLines: parseOCRLines,
               rawText: parseText,
               confidence: Double(confidence)
           ) {
            return finalizeOCRDrafts([draft], pageType: .detail)
        }

        if looksLikePaymentSuccessResult(ocrLines: parseOCRLines),
           let draft = parsePaymentSuccessResult(
               ocrLines: parseOCRLines,
               rawText: parseText,
               confidence: Double(confidence),
               provider: provider
           ) {
            return finalizeOCRDrafts([draft], pageType: .detail)
        }

        let isListScreenshot = looksLikeListScreenshot(lines: parseLines, provider: provider)
        let isDetailScreenshot = looksLikeDetailScreenshot(lines: parseLines)
        if isDetailScreenshot,
           let draft = parseDetailReceipt(
            ocrLines: parseOCRLines,
            rawText: parseText,
            confidence: Double(confidence),
            provider: provider
           ) {
            return finalizeOCRDrafts([draft], pageType: .detail)
        }

        let listDrafts = parseListReceipts(
            ocrLines: parseOCRLines,
            rawText: parseText,
            confidence: Double(confidence),
            provider: provider
        )
        if (listDrafts.count >= 2 && !isDetailScreenshot) || (isListScreenshot && !listDrafts.isEmpty) {
            return finalizeOCRDrafts(listDrafts, pageType: .list)
        }
        if isListScreenshot {
            throw OCRServiceError.detailPageRequired
        }

        let draft: OCRReceiptDraft?
        switch provider {
        case .alipay:
            draft = parseAlipay(lines: parseLines, rawText: parseText, confidence: Double(confidence))
        case .wechat:
            draft = parseWeChat(lines: parseLines, rawText: parseText, confidence: Double(confidence))
        case .generic:
            draft = parseGeneric(lines: parseLines, rawText: parseText, confidence: Double(confidence))
        }

        if let draft, draft.amount > 0, !isListScreenshot {
            return finalizeOCRDrafts([draft], pageType: isDetailScreenshot ? .detail : .unknown)
        }

        if !listDrafts.isEmpty {
            return finalizeOCRDrafts(listDrafts, pageType: isDetailScreenshot ? .detail : .unknown)
        }
        if let draft, draft.amount > 0 {
            return finalizeOCRDrafts([draft], pageType: isDetailScreenshot ? .detail : .unknown)
        }
        throw OCRServiceError.detailPageRequired
    }

    private func detectProvider(from text: String) -> OCRProvider {
        if text.contains("支付宝") || text.contains("蚂蚁") || text.contains("花呗") || text.contains("余额宝") {
            return .alipay
        }
        if text.contains("搜索交易记录") || text.contains("收支分析") || text.contains("本月已省") || text.contains("贴纸") {
            return .alipay
        }
        let alipayCategoryHints = [
            "餐饮美食", "日用百货", "服饰装扮", "文化休闲", "爱车养车", "充值缴费",
            "教育培训", "商业服务", "转账红包", "投资理财",
        ]
        if alipayCategoryHints.contains(where: { text.contains($0) }) {
            return .alipay
        }
        if text.contains("微信支付") || text.contains("微信") || text.contains("零钱") || text.contains("财付通") {
            return .wechat
        }
        if text.contains("查找交易") || text.contains("收支统计") {
            return .wechat
        }
        return .generic
    }

    private func looksLikeListScreenshot(lines: [String], provider: OCRProvider) -> Bool {
        let text = lines.joined(separator: "\n")
        let listHints = [
            "账单列表", "全部交易", "交易记录", "本月支出", "本月收入", "筛选", "月账单", "全部账单",
            "查找交易", "搜索交易记录", "收支统计", "收支分析", "全部", "支出", "转账", "退款",
        ]
        let hasListHint = listHints.contains { text.contains($0) }
        let hasDetailHint = looksLikeDetailScreenshot(lines: lines)
        let amountLineCount = listAmountLineCount(in: lines)
        let currencyCount = currencyCandidates(in: text).count
        let expenseAmountCount = listExpenseLikeLineCount(in: lines)

        if hasListHint && !hasDetailHint {
            return true
        }
        if expenseAmountCount >= 2 && !hasDetailHint {
            return true
        }
        if amountLineCount >= 3 && !hasDetailHint {
            return true
        }
        if provider != .generic && currencyCount >= 4 && !hasDetailHint {
            return true
        }
        return false
    }

    private func listExpenseLikeLineCount(in lines: [String]) -> Int {
        lines.reduce(0) { count, line in
            guard !shouldSkipListAmountLine(line) else { return count }
            guard !isListTimeLine(line), !isStatusBarSystemText(line) else { return count }
            let normalized = normalizedListText(line)
            if normalized.range(of: #"(?<!\d)-\s*(?:¥\s*)?[0-9]{1,6}(?:\.[0-9]{1,2})?"#, options: .regularExpression) != nil {
                return count + 1
            }
            return count
        }
    }

    private func looksLikeDetailScreenshot(lines: [String]) -> Bool {
        let text = lines.joined(separator: "\n")
        let detailHints = [
            "账单详情", "交易详情", "订单详情", "商品说明", "商品名称", "商家名称", "商户名称", "商户全称",
            "交易对象", "收款方", "收款账户", "创建时间", "付款时间", "支付时间", "交易时间", "转账时间", "当前状态",
            "订单号", "商户单号", "交易单号", "财付通订单号", "转账金额", "支付方式",
        ]
        return detailHints.contains { text.contains($0) }
            || text.contains("支付成功")
            || looksLikeAlipayOrderDisplayDetail(lines: lines)
    }

    private func looksLikeAlipayOrderDisplayDetail(lines: [String]) -> Bool {
        let text = lines.joined(separator: "\n")
        guard text.contains("订单展示") else { return false }
        let settlementHints = ["顾客实付款", "立减金", "实际到账", "实际金额以商家实际到账为准"]
        guard settlementHints.contains(where: { text.contains($0) }) else { return false }
        return currencyCandidates(in: text).count >= 2
    }

    private func listAmountLineCount(in lines: [String]) -> Int {
        lines.indices.reduce(0) { count, index in
            let line = lines[index]
            guard !shouldSkipListAmountLine(line) else { return count }
            guard !isListTimeLine(line), !isStatusBarSystemText(line) else { return count }
            let context = adjacentListStatusContext(lines: lines, index: index)
            guard case .some(.expense) = listAmountInfo(in: line, statusContext: context, allowPositiveExpense: true) else {
                return count
            }
            return count + 1
        }
    }

    private func isSameOCRRow(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let rowHeight = max(lhs.height, rhs.height, 0.018)
        return abs(lhs.midY - rhs.midY) <= max(0.014, rowHeight * 0.72)
    }

    private func looksLikePaymentSuccessResult(ocrLines: [OCRLine]) -> Bool {
        let text = ocrLines.map(\.text).joined(separator: "\n")
        let hasSuccessHeader = ocrLines.contains { line in
            line.text.contains("支付成功")
        }
        guard hasSuccessHeader else { return false }

        let listHints = ["账单列表", "全部交易", "交易记录", "收支统计", "收支分析", "筛选", "全部账单"]
        guard !listHints.contains(where: { text.contains($0) }) else { return false }

        return ocrLines.contains { line in
            !paymentSuccessAmountCandidates(in: line.text).isEmpty
        }
    }

    private func parsePaymentSuccessResult(
        ocrLines: [OCRLine],
        rawText: String,
        confidence: Double,
        provider: OCRProvider
    ) -> OCRReceiptDraft? {
        let amountCandidates = ocrLines.compactMap { line -> (amount: Double, line: OCRLine)? in
            guard let amount = paymentSuccessAmountCandidates(in: line.text).first else { return nil }
            return (amount, line)
        }
        guard let selected = amountCandidates
            .sorted(by: { lhs, rhs in
                if lhs.line.boundingBox.height == rhs.line.boundingBox.height {
                    return lhs.line.boundingBox.midY > rhs.line.boundingBox.midY
                }
                return lhs.line.boundingBox.height > rhs.line.boundingBox.height
            })
            .first else {
            return nil
        }

        let brand = MerchantBrandCatalog.matchOCRBrand(in: rawText)
        let title = brand?.displayName
            ?? paymentResultTitle(ocrLines: ocrLines, amountLine: selected.line)
            ?? paymentResultMerchantTitle(ocrLines: ocrLines, amountLine: selected.line)
        guard let title else { return nil }

        let resolvedProvider: OCRProvider = provider == .generic ? .wechat : provider
        return brandedDraft(OCRReceiptDraft(
            title: title,
            amount: abs(selected.amount),
            date: firstDate(in: rawText) ?? .now,
            category: inferCategory(from: "\(title)\n\(rawText)"),
            confidence: confidence,
            rawText: rawText,
            provider: resolvedProvider
        ))
    }

    private func parseDetailReceipt(
        ocrLines: [OCRLine],
        rawText: String,
        confidence: Double,
        provider: OCRProvider
    ) -> OCRReceiptDraft? {
        if looksLikePaymentSuccessResult(ocrLines: ocrLines),
           let draft = parsePaymentSuccessResult(
            ocrLines: ocrLines,
            rawText: rawText,
            confidence: confidence,
            provider: provider
           ) {
            return draft
        }

        let lines = ocrLines.map(\.text)
        switch provider {
        case .alipay:
            return parseAlipay(lines: lines, rawText: rawText, confidence: confidence)
        case .wechat:
            return parseWeChat(lines: lines, rawText: rawText, confidence: confidence)
        case .generic:
            return parseGeneric(lines: lines, rawText: rawText, confidence: confidence)
        }
    }

    private func parseAlipayOrderDisplayDetail(
        ocrLines: [OCRLine],
        rawText: String,
        confidence: Double
    ) -> OCRReceiptDraft? {
        let amountCandidates = ocrLines.compactMap { line -> (amount: Double, line: OCRLine)? in
            guard !isAlipaySettlementBreakdownLine(line.text),
                  let amount = currencyCandidates(in: line.text).first else {
                return nil
            }
            return (amount, line)
        }
        guard let selected = amountCandidates
            .sorted(by: { lhs, rhs in
                if lhs.line.boundingBox.height == rhs.line.boundingBox.height {
                    return lhs.amount > rhs.amount
                }
                return lhs.line.boundingBox.height > rhs.line.boundingBox.height
            })
            .first else {
            return nil
        }

        let title = alipayOrderDisplayTitle(ocrLines: ocrLines, amountLine: selected.line)
            ?? MerchantBrandCatalog.matchOCRBrand(in: rawText)?.displayName
            ?? fallbackTitle(from: ocrLines.map(\.text))
        guard let title else { return nil }

        return brandedDraft(OCRReceiptDraft(
            title: title,
            amount: abs(selected.amount),
            date: firstDate(in: rawText) ?? .now,
            category: inferCategory(from: "\(title)\n\(rawText)"),
            confidence: confidence,
            rawText: rawText,
            provider: .alipay
        ))
    }

    private func alipayOrderDisplayTitle(ocrLines: [OCRLine], amountLine: OCRLine) -> String? {
        let amountMidY = amountLine.boundingBox.midY
        let candidates = ocrLines
            .filter { line in
                guard line.boundingBox.midY > amountMidY else { return false }
                guard line.boundingBox.midY - amountMidY <= 0.32 else { return false }
                let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !isAlipayOrderDisplayNoiseLine(text) else { return false }
                return isUsableTitle(text)
            }
            .sorted { lhs, rhs in
                abs(lhs.boundingBox.midY - amountMidY) < abs(rhs.boundingBox.midY - amountMidY)
            }
            .map(\.text)
        return candidates.first
    }

    private func isAlipaySettlementBreakdownLine(_ text: String) -> Bool {
        let hints = ["顾客实付款", "立减金", "优惠", "红包", "实际到账", "商家实际到账"]
        return hints.contains { text.contains($0) }
    }

    private func isPaymentSuccessBreakdownLine(_ text: String) -> Bool {
        let hints = ["原价", "优惠", "立减", "红包", "返回商家", "银行卡多笔立减", "已优惠"]
        return hints.contains { text.contains($0) }
    }

    private func isAlipayOrderDisplayNoiseLine(_ text: String) -> Bool {
        let blocked = [
            "订单展示", "回首页", "返回", "上滑返回", "顾客实付款", "立减金",
            "实际到账", "实际金额以商家实际到账为准"
        ]
        return blocked.contains { text.contains($0) }
    }

    private func paymentResultTitle(ocrLines: [OCRLine], amountLine: OCRLine) -> String? {
        let amountMidY = amountLine.boundingBox.midY
        let candidates = ocrLines
            .filter { line in
                guard line.boundingBox.midY > amountMidY else { return false }
                guard line.boundingBox.midY - amountMidY <= 0.28 else { return false }
                let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !isListStatusLine(text), !isListTimeLine(text) else { return false }
                return isUsableTitle(text)
            }
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.boundingBox.midY - amountMidY)
                let rhsDistance = abs(rhs.boundingBox.midY - amountMidY)
                return lhsDistance < rhsDistance
            }
            .map(\.text)
        return candidates.first
    }

    private func paymentResultMerchantTitle(ocrLines: [OCRLine], amountLine: OCRLine) -> String? {
        let amountMidY = amountLine.boundingBox.midY
        let blocked = ["支付成功", "原价", "优惠", "返回商家"]
        let candidates = ocrLines
            .filter { line in
                guard line.boundingBox.midY < amountMidY else { return false }
                guard amountMidY - line.boundingBox.midY <= 0.38 else { return false }
                let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !blocked.contains(where: { text.contains($0) }) else { return false }
                guard !isListTimeLine(text), !isPureAmountLine(text), currencyCandidates(in: text).isEmpty else { return false }
                return isUsableTitle(text)
            }
            .sorted { lhs, rhs in
                abs(lhs.boundingBox.midY - amountMidY) < abs(rhs.boundingBox.midY - amountMidY)
            }
            .map(\.text)
        return candidates.first
    }

    private func paymentSuccessAmountCandidates(in text: String) -> [Double] {
        let blocked = ["原价", "优惠", "立减", "红包", "返回商家", "银行卡多笔立减", "已优惠"]
        guard !blocked.contains(where: { text.contains($0) }) else { return [] }
        return currencyCandidates(in: text)
    }

    private func parseAlipay(lines: [String], rawText: String, confidence: Double) -> OCRReceiptDraft? {
        let amount = amountNear(labels: ["金额", "付款金额", "实付款", "实付金额", "订单金额", "支付金额", "交易金额"], in: lines) ?? currencyCandidates(in: rawText).first
        let brand = MerchantBrandCatalog.matchOCRBrand(in: rawText)
        let title = valueFor(labels: ["商品说明", "商品名称", "商家名称", "商户名称", "交易对象", "收款方", "收款账户", "付款给", "对方账户"], in: lines) ?? brand?.displayName ?? fallbackTitle(from: lines)
        let date = dateNear(labels: ["付款时间", "创建时间", "交易时间", "支付时间", "转账时间"], in: lines) ?? firstDate(in: rawText) ?? .now
        guard let amount, let title else { return nil }

        return brandedDraft(OCRReceiptDraft(
            title: title,
            amount: abs(amount),
            date: date,
            category: inferCategory(from: "\(title)\n\(rawText)"),
            confidence: confidence,
            rawText: rawText,
            provider: .alipay
        ))
    }

    private func parseWeChat(lines: [String], rawText: String, confidence: Double) -> OCRReceiptDraft? {
        let amount = amountNear(labels: ["金额", "支付金额", "付款金额", "实付金额", "订单金额", "转账金额", "交易金额"], in: lines) ?? currencyCandidates(in: rawText).first
        let brand = MerchantBrandCatalog.matchOCRBrand(in: rawText)
        let title = valueFor(labels: ["商户全称", "商户名称", "商品", "商品名称", "交易对象", "收款方", "收款账户", "对方", "付款说明"], in: lines) ?? brand?.displayName ?? fallbackTitle(from: lines)
        let date = dateNear(labels: ["支付时间", "交易时间", "转账时间", "付款时间"], in: lines) ?? firstDate(in: rawText) ?? .now
        guard let amount, let title else { return nil }

        return brandedDraft(OCRReceiptDraft(
            title: title,
            amount: abs(amount),
            date: date,
            category: inferCategory(from: "\(title)\n\(rawText)"),
            confidence: confidence,
            rawText: rawText,
            provider: .wechat
        ))
    }

    private func parseGeneric(lines: [String], rawText: String, confidence: Double) -> OCRReceiptDraft? {
        guard let amount = currencyCandidates(in: rawText).first ?? plainAmountCandidates(in: rawText).max(),
              let title = fallbackTitle(from: lines) ?? lines.first(where: isUsableTitle) else {
            return nil
        }
        return brandedDraft(OCRReceiptDraft(
            title: title,
            amount: abs(amount),
            date: firstDate(in: rawText) ?? .now,
            category: inferCategory(from: rawText),
            confidence: confidence,
            rawText: rawText,
            provider: .generic
        ))
    }

    private func brandedDraft(_ draft: OCRReceiptDraft) -> OCRReceiptDraft {
        guard let brand = MerchantBrandCatalog.matchOCRBrand(in: "\(draft.title)\n\(draft.rawText)") else {
            return draft
        }
        var resolved = draft
        resolved.merchantBrandId = brand.id
        resolved.category = NarrativeCopyResolver.resolveCategory(brandId: brand.id, fallback: draft.category)
        resolved.title = NarrativeCopyResolver.resolveTitle(brandId: brand.id, fallback: draft.title)
        return resolved
    }

    private func finalizeOCRDrafts(_ drafts: [OCRReceiptDraft], pageType: OCRPageType) -> [OCRReceiptDraft] {
        let validDrafts = drafts.filter { $0.amount > 0 }
        guard !validDrafts.isEmpty else { return [] }

        if pageType == .detail {
            var draft = bestSingleDetailDraft(from: validDrafts)
            if validDrafts.count > 1 {
                draft.reviewNote = "识别为单笔详情，已整理为 1 笔"
                draft.reviewStatus = .needsReview
            }
            return [reviewedOCRSelectionState(draft)]
        }

        let mergedDrafts = mergeExactDuplicateDrafts(validDrafts)
        return mergedDrafts.map { reviewedOCRSelectionState($0) }
    }

    private func reviewedOCRSelectionState(_ draft: OCRReceiptDraft) -> OCRReceiptDraft {
        var reviewed = draft
        if reviewed.confidence < 0.42 {
            reviewed.reviewStatus = .needsReview
            if reviewed.reviewNote == nil {
                reviewed.reviewNote = "识别置信度偏低，请核对金额和备注"
            }
        }
        return reviewed
    }

    private func bestSingleDetailDraft(from drafts: [OCRReceiptDraft]) -> OCRReceiptDraft {
        drafts.max { lhs, rhs in
            detailDraftScore(lhs) < detailDraftScore(rhs)
        } ?? drafts[0]
    }

    private func detailDraftScore(_ draft: OCRReceiptDraft) -> Double {
        var score = draft.confidence
        if draft.merchantBrandId != nil { score += 0.16 }
        if !normalizedDraftTitle(draft.title).isEmpty { score += 0.08 }
        score += min(draft.amount / 10_000, 0.20)
        return score
    }

    private func mergeExactDuplicateDrafts(_ drafts: [OCRReceiptDraft]) -> [OCRReceiptDraft] {
        var merged: [OCRReceiptDraft] = []
        for draft in drafts {
            if let index = merged.firstIndex(where: { isExactDuplicateOCRDraft($0, draft) }) {
                if draft.confidence > merged[index].confidence {
                    var replacement = draft
                    replacement.reviewNote = merged[index].reviewNote
                    replacement.reviewStatus = merged[index].reviewStatus
                    merged[index] = replacement
                }
                merged[index].reviewNote = "疑似同一笔，已合并重复识别"
                merged[index].reviewStatus = .possibleDuplicate
            } else {
                merged.append(draft)
            }
        }
        return merged
    }

    private func isExactDuplicateOCRDraft(_ lhs: OCRReceiptDraft, _ rhs: OCRReceiptDraft) -> Bool {
        guard amountCents(lhs.amount) == amountCents(rhs.amount) else { return false }
        guard Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date) else { return false }
        let lhsTitle = normalizedDraftTitle(lhs.title)
        let rhsTitle = normalizedDraftTitle(rhs.title)
        guard !lhsTitle.isEmpty, lhsTitle == rhsTitle else { return false }

        let lhsRawText = normalizedDraftTitle(lhs.rawText)
        let rhsRawText = normalizedDraftTitle(rhs.rawText)
        return !lhsRawText.isEmpty && lhsRawText == rhsRawText
    }

    private func amountCents(_ amount: Double) -> Int {
        Int((amount * 100).rounded())
    }

    private func normalizedDraftTitle(_ title: String) -> String {
        let removable = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)
        return String(title.lowercased().unicodeScalars.filter { !removable.contains($0) })
    }

    private func parseListReceipts(
        ocrLines: [OCRLine],
        rawText: String,
        confidence: Double,
        provider: OCRProvider
    ) -> [OCRReceiptDraft] {
        if looksLikeAlipayOrderDisplayDetail(lines: ocrLines.map(\.text)) {
            return []
        }
        var combined: [OCRReceiptDraft] = []
        var seenKeys = Set<String>()
        for mode in listParseModes(provider: provider, rawText: rawText) {
            let drafts = parseListReceipts(
                ocrLines: ocrLines,
                rawText: rawText,
                confidence: confidence,
                mode: mode
            )
            for draft in drafts {
                let key = listDraftDedupKey(draft)
                guard !seenKeys.contains(key) else { continue }
                seenKeys.insert(key)
                combined.append(draft)
            }
        }
        return Array(combined.prefix(12))
    }

    private func parseListReceipts(
        ocrLines: [OCRLine],
        rawText: String,
        confidence: Double,
        mode: ListParseMode
    ) -> [OCRReceiptDraft] {
        var drafts: [OCRReceiptDraft] = []
        var seenKeys = Set<String>()
        let referenceDate = statementReferenceDate(in: rawText) ?? .now
        let allowPositiveExpense = shouldAllowPositiveListExpense(rawText: rawText, mode: mode)

        for index in ocrLines.indices {
            let line = ocrLines[index].text
            guard !isAlipaySettlementBreakdownLine(line) else { continue }
            guard !isPaymentSuccessBreakdownLine(line) else { continue }
            guard !isSystemUILine(ocrLines[index]) else { continue }
            guard !shouldSkipListAmountLine(line) else { continue }
            guard !shouldSkipListAmountCandidate(ocrLines: ocrLines, index: index) else { continue }
            let amountInfo: (amount: Double, inlineTitle: String?)
            let statusContext = adjacentListStatusContext(ocrLines: ocrLines, index: index)
            switch listAmountInfo(in: line, statusContext: statusContext, allowPositiveExpense: allowPositiveExpense) {
            case .some(.expense(let amount, let inlineTitle)):
                amountInfo = (amount, inlineTitle)
            case .some(.ignored), .none:
                continue
            }

            let recordContext = listRecordContext(ocrLines: ocrLines, amountIndex: index)
            let windowLines = recordContext.lines.map(\.text)
            let windowText = windowLines.joined(separator: "\n")
            let candidateTitle = amountInfo.inlineTitle
                ?? nearbyListTitle(lines: recordContext.lines, amountIndex: recordContext.amountIndex, mode: mode)
                ?? nearbyListTitle(lines: ocrLines, amountIndex: index, mode: mode)
            let fallbackTitle = listFallbackTitle(windowLines: windowLines, rejectedTitle: candidateTitle)
            let titleCandidate = candidateTitle ?? fallbackTitle
            let brand = listBrand(title: titleCandidate, windowText: windowText)
            guard let title = titleCandidate ?? brand?.displayName,
                  isTrustworthyListTitle(title, brand: brand) else {
                continue
            }
            let amount = abs(amountInfo.amount)
            guard amount > 0, amount < 1_000_000 else { continue }

            let date = listDate(ocrLines: ocrLines, amountIndex: index, now: referenceDate)
                ?? listDate(in: windowText, now: referenceDate)
                ?? firstDate(in: windowText)
                ?? referenceDate
            let inferredCategory = listCategory(
                mode: mode,
                title: title,
                windowLines: windowLines,
                windowText: windowText
            )
            let category = NarrativeCopyResolver.resolveCategory(brandId: brand?.id, fallback: inferredCategory)
            let resolvedTitle = NarrativeCopyResolver.resolveTitle(brandId: brand?.id, fallback: title)
            let dayKey = Calendar.current.startOfDay(for: date).timeIntervalSince1970
            let key = "\(index)|\(Int((amount * 100).rounded()))|\(Int(dayKey))"
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)

            drafts.append(
                OCRReceiptDraft(
                    title: resolvedTitle,
                    amount: amount,
                    date: date,
                    category: category,
                    confidence: confidence,
                    rawText: windowText,
                    provider: mode.provider,
                    merchantBrandId: brand?.id
                )
            )
        }

        return Array(drafts.prefix(12))
    }

    private func listParseModes(provider: OCRProvider, rawText: String) -> [ListParseMode] {
        switch provider {
        case .alipay:
            return [.alipay]
        case .wechat:
            return [.wechat]
        case .generic:
            if hasAlipayListSignal(rawText) { return [.alipay, .generic] }
            if hasWeChatListSignal(rawText) { return [.wechat, .generic] }
            return [.alipay, .wechat, .generic]
        }
    }

    private func hasAlipayListSignal(_ text: String) -> Bool {
        let hints = [
            "支付宝", "花呗", "余额宝", "搜索交易记录", "收支分析", "本月已省", "贴纸",
            "餐饮美食", "日用百货", "服饰装扮", "文化休闲", "爱车养车", "充值缴费",
            "教育培训", "商业服务", "转账红包", "投资理财",
        ]
        return hints.contains { text.contains($0) }
    }

    private func hasWeChatListSignal(_ text: String) -> Bool {
        let hints = ["微信", "微信支付", "财付通", "零钱", "查找交易", "收支统计"]
        return hints.contains { text.contains($0) }
    }

    private func listDraftDedupKey(_ draft: OCRReceiptDraft) -> String {
        let dayKey = Calendar.current.startOfDay(for: draft.date).timeIntervalSince1970
        return "\(Int((draft.amount * 100).rounded()))|\(Int(dayKey))|\(draft.title)"
    }

    private func shouldAllowPositiveListExpense(rawText: String, mode: ListParseMode) -> Bool {
        if mode != .generic { return true }
        let listHints = [
            "账单", "全部账单", "账单列表", "交易记录", "全部交易", "收支统计", "收支分析",
            "本月支出", "本月收入", "筛选", "月账单",
        ]
        return listHints.contains { rawText.contains($0) }
    }

    private func isTrustworthyListTitle(_ title: String, brand: MerchantBrandDefinition?) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "账单记录" else { return false }
        if isLikelyListTitle(trimmed) { return true }
        return brand?.displayName == trimmed
    }

    private func listFallbackTitle(windowLines: [String], rejectedTitle: String?) -> String? {
        let rejected = rejectedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let rejected, isLikelyListTitle(rejected) {
            return rejected
        }
        let candidates = windowLines.compactMap { line -> String? in
            let trimmed = normalizedOCRTitleCandidate(line)
            guard trimmed != rejected else { return nil }
            guard isLikelyListTitle(trimmed) else { return nil }
            return trimmed
        }
        return candidates.first(where: { !isGenericPaymentTitle($0) }) ?? candidates.first
    }

    private func listBrand(title: String?, windowText: String) -> MerchantBrandDefinition? {
        if let title {
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if let titleBrand = MerchantBrandCatalog.matchOCRBrand(in: trimmedTitle) {
                return titleBrand
            }
            if !trimmedTitle.isEmpty {
                return nil
            }
        }
        return MerchantBrandCatalog.matchOCRBrand(in: windowText)
    }

    private func listExpenseAmountInfo(in line: String) -> (amount: Double, inlineTitle: String?)? {
        guard case let .some(.expense(amount, inlineTitle)) = listAmountInfo(in: line) else {
            return nil
        }
        return (amount, inlineTitle)
    }

    // List examples:
    // - "瑞幸咖啡 18.00 交易成功" is an expense even without a minus sign.
    // - "瑞幸咖啡 18.00" followed by "交易成功" is also an expense.
    // - "瑞幸咖啡 18.00 交易关闭" is ignored because the order was not paid.
    private func listAmountInfo(in line: String, statusContext: String = "", allowPositiveExpense: Bool = false) -> ListAmountInfo? {
        let normalized = normalizedListText(line)
        if isListTimeLine(normalized) || isStatusBarSystemText(normalized) {
            return nil
        }
        if isMonthlySummaryLine(normalized) {
            return .ignored
        }
        let statusPattern = #"(等待确认收货|交易成功|支付成功|退款成功|已全额退款|已退款(?:\(¥?\s*[0-9]+(?:\.[0-9]{1,2})?\))?|交易关闭)"#
        let pattern = #"^(?:(.+?)\s*)?([-+])?\s*(?:¥\s*)?([-+]?\s*[0-9]{1,6}(?:\.[0-9]{1,2})?)(?:\s*"# + statusPattern + #")?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = normalized as NSString
        guard let match = regex.firstMatch(in: normalized, range: NSRange(location: 0, length: nsText.length)),
              match.numberOfRanges > 4 else {
            return looseListAmountInfo(
                in: normalized,
                statusContext: statusContext,
                allowPositiveExpense: allowPositiveExpense
            )
        }

        let status = match.range(at: 4).location != NSNotFound
            ? nsText.substring(with: match.range(at: 4))
            : ""
        let statusScope = "\(status)\n\(statusContext)"
        if statusScope.contains("交易关闭") {
            // 关闭订单展示了金额但没有实际支出，不能导入为账单。
            return .ignored
        }
        if statusScope.contains("已退款") || statusScope.contains("已全额退款") || statusScope.contains("退款成功") {
            // 退款正数行按产品规则忽略，避免和原支出重复抵消。
            return .ignored
        }
        if normalized.contains("收入") || normalized.contains("退款") || normalized.contains("转入") || normalized.contains("提现") || normalized.contains("还款") {
            return .ignored
        }

        let explicitSign = match.range(at: 2).location != NSNotFound
            ? nsText.substring(with: match.range(at: 2))
            : ""
        let rawValue = nsText.substring(with: match.range(at: 3)).replacingOccurrences(of: " ", with: "")
        if explicitSign == "+" || rawValue.hasPrefix("+") {
            return .ignored
        }
        let numericAmount = Double(
            rawValue
                .replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "-", with: "")
        ) ?? 0
        let hasMinus = explicitSign == "-" || rawValue.hasPrefix("-")
        let hasCurrency = normalized.contains("¥")
        let hasExpenseWord = normalized.contains("支出") || normalized.contains("付款") || normalized.contains("支付")
        let paidWithoutMinus = !hasMinus && ["等待确认收货", "交易成功", "支付成功"].contains { statusScope.contains($0) }
        if !hasMinus && !hasCurrency && !paidWithoutMinus && containsLongDigitRun(normalized) {
            return nil
        }
        let positiveListExpense = allowPositiveExpense && (hasCurrency || hasExpenseWord || (isPureAmountLine(normalized) && numericAmount < 1_000))
        guard hasMinus || paidWithoutMinus || positiveListExpense else { return nil }

        let title: String?
        if match.range(at: 1).location != NSNotFound {
            let rawTitle = normalizedInlineListTitle(nsText.substring(with: match.range(at: 1)))
            if isAmountOnlyCluster(rawTitle) {
                // Vision may merge the right-side amount column into lines like "-52.00 -4.50".
                // Treating the first amount as a title shifts the whole WeChat list by one row.
                return nil
            }
            title = isLikelyListTitle(rawTitle) && !isPureAmountLine(rawTitle) ? rawTitle : nil
        } else {
            title = nil
        }
        return .expense(amount: -numericAmount, inlineTitle: title)
    }

    private func looseListAmountInfo(
        in normalized: String,
        statusContext: String,
        allowPositiveExpense: Bool
    ) -> ListAmountInfo? {
        if isListTimeLine(normalized) || isStatusBarSystemText(normalized) {
            return nil
        }
        if isMonthlySummaryLine(normalized) {
            return .ignored
        }
        if normalized.contains("收入") || normalized.contains("退款") || normalized.contains("转入") || normalized.contains("提现") || normalized.contains("还款") {
            return .ignored
        }
        if statusContext.contains("交易关闭") {
            return .ignored
        }
        if statusContext.contains("已退款") || statusContext.contains("已全额退款") || statusContext.contains("退款成功") {
            return .ignored
        }

        let amountPattern = #"([-+])?\s*(?:¥\s*)?([0-9]{1,6}(?:\.[0-9]{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: amountPattern) else { return nil }
        let nsText = normalized as NSString
        let matches = regex.matches(in: normalized, range: NSRange(location: 0, length: nsText.length))
        guard let match = matches.last, match.numberOfRanges > 2 else { return nil }
        let trailingText = nsText.substring(from: match.range.location + match.range.length)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trailingText.isEmpty || isListStatusLine(trailingText) else {
            // Avoid reading merchant names such as "天润城5-7街区" as title "天润城5" + amount 7.
            return nil
        }

        let full = nsText.substring(with: match.range(at: 0))
        let explicitSign = match.range(at: 1).location != NSNotFound
            ? nsText.substring(with: match.range(at: 1))
            : ""
        if explicitSign == "+" || full.trimmingCharacters(in: .whitespaces).hasPrefix("+") {
            return .ignored
        }

        let hasMinus = explicitSign == "-" || full.trimmingCharacters(in: .whitespaces).hasPrefix("-")
        let hasCurrency = full.contains("¥") || normalized.contains("¥")
        let hasExpenseWord = normalized.contains("支出") || normalized.contains("付款") || normalized.contains("支付")
        let paidWithoutMinus = !hasMinus && ["等待确认收货", "交易成功", "支付成功"].contains { statusContext.contains($0) }
        let amount = Double(nsText.substring(with: match.range(at: 2))) ?? 0
        guard amount > 0 else { return nil }
        if !hasMinus && !hasCurrency && !paidWithoutMinus && containsLongDigitRun(normalized) {
            return nil
        }
        let positiveListExpense = allowPositiveExpense && (hasCurrency || hasExpenseWord || (isPureAmountLine(normalized) && amount < 1_000))
        guard hasMinus || paidWithoutMinus || positiveListExpense else { return nil }

        let beforeAmount = nsText.substring(to: match.range.location)
        let title = looseInlineTitle(from: beforeAmount)
        return .expense(amount: -amount, inlineTitle: title)
    }

    private func looseInlineTitle(from value: String) -> String? {
        let cleaned = normalizedInlineListTitle(value)
            .replacingOccurrences(of: #"\d{1,2}[-/.月]\d{1,2}(?:日)?(?:\s*\d{1,2}:\d{2})?"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(今天|昨日|昨天|前天)\s*\d{1,2}:\d{2}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return isLikelyListTitle(cleaned) ? cleaned : nil
    }

    private func normalizedInlineListTitle(_ value: String) -> String {
        let removeTokens = [
            "支出", "消费", "收入",
            "餐饮美食", "日用百货", "服饰装扮", "文化休闲", "爱车养车", "充值缴费",
            "教育培训", "商业服务", "转账红包", "投资理财",
        ]
        var title = value
            .replacingOccurrences(of: "｜", with: " ")
            .replacingOccurrences(of: "|", with: " ")
            .replacingOccurrences(of: "·", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for token in removeTokens {
            title = title.replacingOccurrences(of: token, with: " ")
        }
        return title
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func adjacentListStatusContext(lines: [String], index: Int) -> String {
        [index - 2, index - 1, index + 1, index + 2]
            .filter { lines.indices.contains($0) }
            .map { lines[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isListStatusLine($0) }
            .joined(separator: "\n")
    }

    private func adjacentListStatusContext(ocrLines: [OCRLine], index: Int) -> String {
        guard ocrLines.indices.contains(index) else { return "" }
        let amountBox = ocrLines[index].boundingBox
        let rowHeight = max(amountBox.height, 0.018)
        let maxLowerDistance = max(0.055, rowHeight * 2.8)

        return ocrLines.enumerated().compactMap { candidateIndex, line -> String? in
            guard candidateIndex != index else { return nil }
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isListStatusLine(text) else { return nil }

            if isSameOCRRow(line.boundingBox, amountBox) {
                return text
            }

            let isBelowAmount = line.boundingBox.midY < amountBox.midY
            let verticalDistance = amountBox.midY - line.boundingBox.midY
            let isNearBelow = isBelowAmount && verticalDistance <= maxLowerDistance
            let isRightColumnStatus = line.boundingBox.midX >= amountBox.midX - 0.08
            return isNearBelow && isRightColumnStatus ? text : nil
        }
        .joined(separator: "\n")
    }

    private func shouldSkipListAmountCandidate(ocrLines: [OCRLine], index: Int) -> Bool {
        guard ocrLines.indices.contains(index) else { return true }
        let line = ocrLines[index]
        if isSystemUILine(line) {
            return true
        }
        let normalized = normalizedListText(line.text)
        if isListTimeLine(normalized) || isStatusBarSystemText(normalized) {
            return true
        }
        guard listAmountInfo(in: normalized, allowPositiveExpense: true) != nil else { return false }
        if normalized.contains("-") || normalized.contains("−") || normalized.contains("－") {
            return false
        }

        let summaryContext = ocrLines.enumerated().compactMap { candidateIndex, candidate -> String? in
            guard candidateIndex != index else { return nil }
            let verticalDistance = abs(candidate.boundingBox.midY - line.boundingBox.midY)
            guard verticalDistance <= 0.13 else { return nil }
            return candidate.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .joined(separator: "\n")

        return isStatementSummaryContext(summaryContext)
    }

    private func isStatementSummaryContext(_ value: String) -> Bool {
        let compact = normalizedListText(value)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
        let summaryWords = [
            "收支分析", "总金额", "识别条数", "支出¥", "收入¥", "支出￥", "收入￥",
            "本月支出", "本月收入", "月支出", "月收入",
        ]
        if summaryWords.contains(where: { compact.contains($0) }) {
            return true
        }
        if compact.range(of: #"^\d{1,2}月(?:支出|收入)"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private func listRecordContext(ocrLines: [OCRLine], amountIndex: Int) -> (lines: [OCRLine], amountIndex: Int) {
        guard ocrLines.indices.contains(amountIndex) else { return ([], 0) }
        let amountLine = ocrLines[amountIndex]
        let amountBox = amountLine.boundingBox
        let rowHeight = max(amountBox.height, 0.018)
        let nextAmountBelowY = nearestListAmountYBelow(ocrLines: ocrLines, amountIndex: amountIndex)
        let upperY = min(1, amountBox.midY + max(0.028, rowHeight * 1.8))
        let lowerY = nextAmountBelowY.map { max(0, $0 + rowHeight * 1.25) } ?? max(0, amountBox.midY - 0.17)

        let scopedLines = ocrLines.enumerated().compactMap { index, line -> OCRLine? in
            guard line.boundingBox.midY <= upperY, line.boundingBox.midY >= lowerY else { return nil }
            if isSystemUILine(line) {
                return nil
            }
            if index != amountIndex, shouldSkipListAmountCandidate(ocrLines: ocrLines, index: index) {
                return nil
            }
            return line
        }
        .sorted { lhs, rhs in
            if isSameOCRRow(lhs.boundingBox, rhs.boundingBox) {
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            return lhs.boundingBox.minY > rhs.boundingBox.minY
        }

        let localIndex = scopedLines.firstIndex { $0.text == amountLine.text && $0.boundingBox == amountLine.boundingBox } ?? 0
        return (scopedLines, localIndex)
    }

    private func nearestListAmountYBelow(ocrLines: [OCRLine], amountIndex: Int) -> CGFloat? {
        guard ocrLines.indices.contains(amountIndex) else { return nil }
        let amountBox = ocrLines[amountIndex].boundingBox
        return ocrLines.enumerated().compactMap { index, line -> CGFloat? in
            guard index != amountIndex else { return nil }
            guard !isSystemUILine(line) else { return nil }
            guard line.boundingBox.midY < amountBox.midY else { return nil }
            guard !shouldSkipListAmountLine(line.text) else { return nil }
            guard !shouldSkipListAmountCandidate(ocrLines: ocrLines, index: index) else { return nil }
            guard listAmountInfo(in: line.text, allowPositiveExpense: true) != nil else { return nil }
            return line.boundingBox.midY
        }
        .max()
    }

    private func nearbyListTitle(lines: [OCRLine], amountIndex: Int, mode: ListParseMode) -> String? {
        switch mode {
        case .alipay:
            return alipayListTitle(lines: lines, amountIndex: amountIndex)
        case .wechat:
            return wechatListTitle(lines: lines, amountIndex: amountIndex)
        case .generic:
            return nearbyTitle(lines: lines, amountIndex: amountIndex, offsets: [-1, -2, 1, -3, 2])
        }
    }

    private func alipayListTitle(lines: [OCRLine], amountIndex: Int) -> String? {
        guard lines.indices.contains(amountIndex) else { return nil }
        let amountBox = lines[amountIndex].boundingBox
        let sameRowTitle = lines.enumerated()
            .filter { index, line in
                guard index != amountIndex else { return false }
                guard isSameOCRRow(line.boundingBox, amountBox) else { return false }
                guard line.boundingBox.midX < amountBox.midX else { return false }
                let candidate = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return isLikelyListTitle(candidate)
            }
            .sorted { lhs, rhs in
                lhs.element.boundingBox.minX > rhs.element.boundingBox.minX
            }
            .first?.element.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let sameRowTitle {
            return sameRowTitle
        }

        return nearbyTitle(lines: lines, amountIndex: amountIndex, offsets: [-1, -2, 1])
    }

    private func wechatListTitle(lines: [OCRLine], amountIndex: Int) -> String? {
        guard lines.indices.contains(amountIndex) else { return nil }
        let amountBox = lines[amountIndex].boundingBox

        let sameRowTitle = lines.enumerated()
            .filter { index, line in
                guard index != amountIndex else { return false }
                guard isSameOCRRow(line.boundingBox, amountBox) else { return false }
                guard line.boundingBox.midX < amountBox.midX else { return false }
                let candidate = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return isLikelyListTitle(candidate)
            }
            .sorted { lhs, rhs in
                lhs.element.boundingBox.minX > rhs.element.boundingBox.minX
            }
            .first?.element.text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let sameRowTitle {
            return sameRowTitle
        }

        guard amountIndex > 0 else { return nil }
        let start = amountIndex - 1
        let end = max(0, amountIndex - 4)

        for candidateIndex in stride(from: start, through: end, by: -1) {
            let candidate = lines[candidateIndex].text.trimmingCharacters(in: .whitespacesAndNewlines)
            if isPureAmountLine(candidate) || listExpenseAmountInfo(in: candidate) != nil {
                continue
            }
            if isListTimeLine(candidate) || isListStatusLine(candidate) {
                continue
            }
            if isLikelyListTitle(candidate) {
                return candidate
            }
        }
        return nil
    }

    private func nearbyTitle(lines: [OCRLine], amountIndex: Int, offsets: [Int]) -> String? {
        for offset in offsets {
            let candidateIndex = amountIndex + offset
            guard lines.indices.contains(candidateIndex) else { continue }
            let candidate = lines[candidateIndex].text.trimmingCharacters(in: .whitespacesAndNewlines)
            if isLikelyListTitle(candidate) {
                return candidate
            }
        }
        return nil
    }

    private func isLikelyListTitle(_ value: String) -> Bool {
        guard isUsableTitle(value), !isPureAmountLine(value), !isListTimeLine(value), !isListStatusLine(value) else { return false }
        guard !isAmountOnlyCluster(value) else { return false }
        if value.range(of: #"^\d{1,2}月$"#, options: .regularExpression) != nil { return false }
        let blocked = [
            "¥", "￥", "金额", "时间", "单号", "收款", "交易", "账单", "详情",
            "当前状态", "成功", "失败", "付款方式", "筛选", "全部", "月支出", "月收入", "余额", "零钱",
            "银行卡", "微信支付", "支付宝", "支出", "收入", "本月", "搜索", "查找", "等待确认收货",
            "日用百货", "文化休闲", "餐饮美食", "教育培训", "服饰装扮", "爱车养车", "充值缴费",
            "商业服务", "转账红包", "投资理财", "已全额退款", "已退款", "交易关闭",
            "顾客实付款", "立减金", "优惠", "红包", "实际到账", "商家实际到账",
        ]
        guard !blocked.contains(where: { value.contains($0) }) else { return false }
        return !isGenericPaymentTitle(value)
    }

    private func isGenericPaymentTitle(_ value: String) -> Bool {
        let compact = value
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let genericExact = [
            "支付", "付款", "订单", "统一支付"
        ]
        if genericExact.contains(compact) { return true }
        if compact.range(of: #"^(订单|支付|付款)\d*$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private func shouldSkipListAmountLine(_ line: String) -> Bool {
        let trimmed = normalizedListText(line)
        if isListTimeLine(trimmed) || isStatusBarSystemText(trimmed) {
            return true
        }
        if isMonthlySummaryLine(trimmed) {
            return true
        }
        let skipWords = ["本月收入", "月收入", "本月支出", "月支出", "本月已省", "转入", "提现", "还款"]
        return skipWords.contains { trimmed.contains($0) }
    }

    private func normalizedListText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "﹣", with: "-")
            .replacingOccurrences(of: "‒", with: "-")
            .replacingOccurrences(of: "﹘", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "￥", with: "¥")
            .replacingOccurrences(of: "\u{00A5}", with: "¥")
            .replacingOccurrences(of: "\u{FFE5}", with: "¥")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: #"(?<![\p{Han}A-Za-z0-9])一\s*(?=\d)"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isMonthlySummaryLine(_ value: String) -> Bool {
        let compact = normalizedListText(value).replacingOccurrences(of: " ", with: "")
        if compact.contains("收入¥") || compact.contains("收入￥") {
            return true
        }
        if compact.contains("支出¥") || compact.contains("支出￥") {
            return true
        }
        if compact.range(of: #"^(?:20\d{2}年)?\d{1,2}月.*(?:支出|收入)"#, options: .regularExpression) != nil {
            return true
        }
        if compact.range(of: #"^(?:本月|月)(?:支出|收入)"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private func listCategory(
        mode: ListParseMode,
        title: String,
        windowLines: [String],
        windowText: String
    ) -> HomeItem.Category {
        // 支付宝列表自带分类，优先信平台分类；微信通常没有分类，用商户名/标题做本地推断。
        if containsTelecomBillCue("\(title)\n\(windowText)") {
            return .daily
        }
        if mode == .alipay,
           let alipayCategory = alipayListCategory(from: windowLines) {
            if let localCategory = inferCategoryIfConfident(from: alipayLocalCategoryText(title: title, windowLines: windowLines)),
               shouldPreferLocalCategory(localCategory, overAlipayCategory: alipayCategory) {
                return localCategory
            }
            return alipayCategory
        }
        return inferCategory(from: "\(title)\n\(windowText)")
    }

    private func shouldPreferLocalCategory(
        _ localCategory: HomeItem.Category,
        overAlipayCategory alipayCategory: HomeItem.Category
    ) -> Bool {
        guard localCategory != alipayCategory else { return false }
        switch alipayCategory {
        case .other:
            return true
        case .daily:
            return [.dining, .health, .home, .transport].contains(localCategory)
        case .shopping:
            return [.dining, .health, .home, .transport].contains(localCategory)
        default:
            return false
        }
    }

    private func alipayLocalCategoryText(title: String, windowLines: [String]) -> String {
        ([title] + windowLines.filter { !isAlipayCategoryLine($0) }).joined(separator: "\n")
    }

    private func alipayListCategory(from lines: [String]) -> HomeItem.Category? {
        for line in lines {
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isAlipayCategoryLine(text) else { continue }
            return mapAlipayCategory(text)
        }
        return nil
    }

    private func isAlipayCategoryLine(_ text: String) -> Bool {
        mapAlipayCategory(text) != nil
    }

    private func mapAlipayCategory(_ text: String) -> HomeItem.Category? {
        if text.contains("餐饮美食") { return .dining }
        if text.contains("日用百货") { return .daily }
        if text.contains("服饰装扮") { return .shopping }
        if text.contains("文化休闲") { return .entertainment }
        if text.contains("爱车养车") { return .transport }
        if text.contains("充值缴费") { return .home }
        if text.contains("教育培训") { return .other }
        if text.contains("商业服务") { return .other }
        if text.contains("转账红包") { return .other }
        if text.contains("投资理财") { return .other }
        if text == "其他" { return .other }
        return nil
    }

    private func containsTelecomBillCue(_ text: String) -> Bool {
        ["话费", "话费券", "话费充值", "手机话费", "手机充值", "通讯费", "通信费", "中国移动", "中国移动通信集团", "中国联通", "中国电信", "移动通信", "运营商缴费"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private func amountNear(labels: [String], in lines: [String]) -> Double? {
        for (index, line) in lines.enumerated() where labels.contains(where: { line.contains($0) }) {
            let scope = lines[index..<min(lines.count, index + 3)].joined(separator: "\n")
            if let amount = currencyCandidates(in: scope).first ?? plainAmountCandidates(in: scope).max() ?? labeledAmountCandidates(in: scope).first {
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
        let blocked = [
            "¥", "￥", "金额", "时间", "订单", "单号", "支付", "付款", "收款", "交易", "账单", "详情",
            "当前状态", "成功", "付款方式", "筛选", "全部", "月支出", "月收入", "余额", "零钱", "银行卡",
            "完成", "取消", "返回", "关闭",
        ]
        let candidates = lines.compactMap { line -> String? in
            let trimmed = normalizedOCRTitleCandidate(line)
            guard isUsableTitle(trimmed) else { return nil }
            guard !blocked.contains(where: { trimmed.contains($0) }) else { return nil }
            return trimmed
        }
        return candidates.first(where: containsChinese) ?? candidates.first
    }

    private func isSystemUILine(_ line: OCRLine) -> Bool {
        let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (isStatusBarSystemText(text) || isStatusBarBatteryText(text)), line.boundingBox.midY >= 0.88 {
            return true
        }
        if text == "完成", line.boundingBox.midY <= 0.25 {
            return true
        }
        return false
    }

    private func normalizedOCRTitleCandidate(_ value: String) -> String {
        value
            .replacingOccurrences(of: "！", with: "!")
            .replacingOccurrences(of: #"(?<=[\p{Han}A-Za-z])\d{7,}$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsLongDigitRun(_ value: String) -> Bool {
        value.range(of: #"\d{7,}"#, options: .regularExpression) != nil
    }

    private func isStatusBarSystemText(_ value: String) -> Bool {
        let normalized = normalizedOCRTitleCandidate(value)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        guard !normalized.isEmpty else { return false }
        guard !containsChinese(normalized) else { return false }
        let compact = normalized.replacingOccurrences(of: #"[^A-Z0-9:!]"#, with: "", options: .regularExpression)
        if compact.range(of: #"^\d{1,2}:\d{2}!?[A-Z0-9!]*$"#, options: .regularExpression) != nil {
            return true
        }
        if compact.contains("5G"), compact.count <= 12 {
            return true
        }
        if compact.range(of: #"^(?:LTE|4G|3G|WIFI|WI-FI)$"#, options: .regularExpression) != nil {
            return true
        }
        if compact.range(of: #"^[!:]{2,}[A-Z0-9!:]*$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private func isStatusBarBatteryText(_ value: String) -> Bool {
        let normalized = normalizedOCRTitleCandidate(value)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        guard !containsChinese(normalized) else { return false }
        return normalized.range(of: #"^\d{1,3}%?$"#, options: .regularExpression) != nil
    }

    private func isStatusBarNoiseTitle(_ value: String) -> Bool {
        isStatusBarSystemText(value)
    }

    private func isUsableTitle(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 40 else { return false }
        if isStatusBarNoiseTitle(trimmed) { return false }
        if NarrativeCopyResolver.isNoisyTimeTitle(trimmed) || isListTimeLine(trimmed) || isListStatusLine(trimmed) { return false }
        if isPureAmountLine(trimmed) { return false }
        if isAmountOnlyCluster(trimmed) { return false }
        guard containsChinese(trimmed) || containsAlphabetic(trimmed) else { return false }
        if trimmed.range(of: #"^\d{4}[-/.年]"#, options: .regularExpression) != nil { return false }
        if trimmed.range(of: #"[¥￥]\s*-?\d"#, options: .regularExpression) != nil { return false }
        return true
    }

    private func isPureAmountLine(_ value: String) -> Bool {
        let trimmed = normalizedAmountText(value)
        return trimmed.range(
            of: #"^-?\s*[0-9]+(?:\.[0-9]{1,2})?\s*$"#,
            options: .regularExpression
        ) != nil
    }

    private func isAmountOnlyCluster(_ value: String) -> Bool {
        let normalized = normalizedAmountText(value)
        let stripped = normalized.replacingOccurrences(
            of: #"[-+]?\s*[0-9]+(?:\.[0-9]{1,2})?"#,
            with: "",
            options: .regularExpression
        )
        return !normalized.isEmpty && stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func normalizedAmountText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "\u{00A5}", with: "")
            .replacingOccurrences(of: "\u{FFE5}", with: "")
            .replacingOccurrences(of: "\u{697C}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isListTimeLine(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"^\d{1,2}:\d{2}(?::\d{2})?$"#, options: .regularExpression) != nil {
            return true
        }
        if trimmed.range(of: #"^\d{1,2}[-/.]\d{1,2}\s*\d{1,2}:\d{2}"#, options: .regularExpression) != nil {
            return true
        }
        if trimmed.range(of: #"^\d{1,2}月\d{1,2}日?\s*\d{1,2}:\d{2}"#, options: .regularExpression) != nil {
            return true
        }
        if trimmed.range(of: #"^(周一|周二|周三|周四|周五|周六|周日|星期一|星期二|星期三|星期四|星期五|星期六|星期日)\s+\d{1,2}:\d{2}"#, options: .regularExpression) != nil {
            return true
        }
        return trimmed.range(of: #"^(今天|昨日|昨天|前天)\s*\d{1,2}:\d{2}"#, options: .regularExpression) != nil
    }

    private func isListStatusLine(_ value: String) -> Bool {
        let statusWords = ["交易成功", "支付成功", "已退款", "已全额退款", "退款成功", "等待确认收货", "交易关闭"]
        return statusWords.contains { value.contains($0) }
    }

    private func containsChinese(_ value: String) -> Bool {
        value.range(of: #"\p{Han}"#, options: .regularExpression) != nil
    }

    private func containsAlphabetic(_ value: String) -> Bool {
        value.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
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
        let pattern = #"(?:20\d{2}[-/.年])?\d{1,2}[-/.月]\d{1,2}[日\s]*\d{0,2}:?\d{0,2}:?\d{0,2}"#
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
        let normalized = raw.hasPrefix("20") ? raw : "\(Calendar.current.component(.year, from: .now))-\(raw)"
        let formats = ["yyyy-M-d HH:mm:ss", "yyyy-M-d HH:mm", "yyyy-M-d"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) {
                return date
            }
        }
        return nil
    }

    private func listDate(in text: String, now: Date = .now) -> Date? {
        relativeListDate(in: text, now: now)
            ?? monthDayListDate(in: text, now: now)
            ?? dashedMonthDayListDate(in: text, now: now)
    }

    private func listDate(ocrLines: [OCRLine], amountIndex: Int, now: Date) -> Date? {
        guard ocrLines.indices.contains(amountIndex) else { return nil }
        let amountBox = ocrLines[amountIndex].boundingBox
        let nextAmountBelowY = ocrLines.enumerated()
            .filter { index, line in
                guard index != amountIndex else { return false }
                guard line.boundingBox.midY < amountBox.midY else { return false }
                guard !shouldSkipListAmountLine(line.text) else { return false }
                return listAmountInfo(in: line.text, allowPositiveExpense: true) != nil
            }
            .map { $0.element.boundingBox.midY }
            .max()

        let candidates = ocrLines.enumerated().compactMap { index, line -> (distance: CGFloat, date: Date)? in
            guard index != amountIndex else { return nil }
            guard line.boundingBox.midY < amountBox.midY else { return nil }
            if let nextAmountBelowY, line.boundingBox.midY < nextAmountBelowY {
                return nil
            }
            guard line.boundingBox.midX < amountBox.midX + 0.08 else { return nil }
            guard let date = listDate(in: line.text, now: now) ?? firstDate(in: line.text) else { return nil }
            return (amountBox.midY - line.boundingBox.midY, date)
        }
        return candidates.sorted { $0.distance < $1.distance }.first?.date
    }

    private func statementReferenceDate(in text: String) -> Date? {
        let pattern = #"(20\d{2})年\s*(\d{1,2})月"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              match.numberOfRanges > 2 else {
            return nil
        }

        var components = DateComponents()
        components.year = Int(nsText.substring(with: match.range(at: 1)))
        components.month = Int(nsText.substring(with: match.range(at: 2)))
        components.day = 15
        components.hour = 12
        return Calendar.current.date(from: components)
    }

    private func relativeListDate(in text: String, now: Date) -> Date? {
        let pattern = #"(今天|昨日|昨天|前天)\s*(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              match.numberOfRanges > 3 else {
            return nil
        }

        let label = nsText.substring(with: match.range(at: 1))
        let hour = Int(nsText.substring(with: match.range(at: 2))) ?? 0
        let minute = Int(nsText.substring(with: match.range(at: 3))) ?? 0
        let dayOffset: Int
        switch label {
        case "昨天", "昨日":
            dayOffset = -1
        case "前天":
            dayOffset = -2
        default:
            dayOffset = 0
        }
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    private func monthDayListDate(in text: String, now: Date) -> Date? {
        let pattern = #"(\d{1,2})月(\d{1,2})日\s*(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              match.numberOfRanges > 4 else {
            return nil
        }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year], from: now)
        components.month = Int(nsText.substring(with: match.range(at: 1)))
        components.day = Int(nsText.substring(with: match.range(at: 2)))
        components.hour = Int(nsText.substring(with: match.range(at: 3)))
        components.minute = Int(nsText.substring(with: match.range(at: 4)))
        components.second = 0
        return calendar.date(from: components)
    }

    private func dashedMonthDayListDate(in text: String, now: Date) -> Date? {
        let pattern = #"(\d{1,2})-(\d{1,2})\s*(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              match.numberOfRanges > 4 else {
            return nil
        }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year], from: now)
        components.month = Int(nsText.substring(with: match.range(at: 1)))
        components.day = Int(nsText.substring(with: match.range(at: 2)))
        components.hour = Int(nsText.substring(with: match.range(at: 3)))
        components.minute = Int(nsText.substring(with: match.range(at: 4)))
        components.second = 0
        return calendar.date(from: components)
    }

    private func currencyCandidates(in text: String) -> [Double] {
        let pattern = #"[-+]?\s*[¥￥]\s*([0-9]{1,6}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]{1,6}(?:\.[0-9]{1,2})?)(?![0-9,])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let full = nsText.substring(with: match.range(at: 0))
            let value = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
            let sign = full.contains("-") ? -1.0 : 1.0
            let amount = (Double(value) ?? 0) * sign
            guard abs(amount) < 1_000_000 else { return nil }
            return amount
        }
    }

    private func plainAmountCandidates(in text: String) -> [Double] {
        let pattern = #"(?<!\d)([0-9]{1,6}(?:\.[0-9]{1,2})?)(?!\d)\s*元"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return Double(nsText.substring(with: match.range(at: 1)))
        }
    }

    private func labeledAmountCandidates(in text: String) -> [Double] {
        let pattern = #"(?:金额|付款金额|支付金额|实付金额|订单金额|交易金额|转账金额)[^\d\-+]{0,8}([-+]?\s*[0-9]{1,6}(?:\.[0-9]{1,2})?)(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            return Double(nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: " ", with: ""))
        }
    }

    private func inferCategory(from text: String) -> HomeItem.Category {
        inferCategoryIfConfident(from: text) ?? .daily
    }

    private func inferCategoryIfConfident(from text: String) -> HomeItem.Category? {
        let lower = text.lowercased()
        if lower.contains("微信红包") || lower.contains("红包") || lower.contains("转账") {
            return .social
        }
        if matchesGameExpense(lower) {
            return .entertainment
        }
        var scores = Dictionary(uniqueKeysWithValues: HomeItem.Category.allCases.map { ($0, 0.0) })
        for rule in RecordSemanticLexicon.keywordRules {
            if rule.keywords.contains(where: { lower.contains($0.lowercased()) }) {
                scores[rule.category, default: 0] += rule.score
            }
        }
        for rule in RecordSemanticLexicon.ocrKeywordRules {
            if rule.keywords.contains(where: { lower.contains($0.lowercased()) }) {
                scores[rule.category, default: 0] += rule.score
            }
        }
        let ranked = scores
            .filter { $0.value > 0 }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return categoryPriority(lhs.key) < categoryPriority(rhs.key)
                }
                return lhs.value > rhs.value
            }
        if let top = ranked.first {
            return top.key
        }
        return nil
    }

    private func categoryPriority(_ category: HomeItem.Category) -> Int {
        switch category {
        case .dining: return 0
        case .transport: return 1
        case .shopping: return 2
        case .daily: return 3
        case .entertainment: return 4
        case .lodging: return 5
        case .health: return 6
        case .home: return 7
        case .social: return 8
        case .other: return 9
        }
    }

    private func matchesGameExpense(_ text: String) -> Bool {
        let gameTitles = [
            "碧蓝航线", "原神", "星穹铁道", "崩坏", "明日方舟", "王者荣耀", "和平精英", "英雄联盟",
            "逆水寒", "阴阳师", "梦幻西游", "第五人格", "蛋仔派对", "光遇", "三国杀", "炉石传说",
            "steam", "psn", "playstation", "xbox", "switch", "nintendo"
        ]
        let strongGameTerms = [
            "代肝", "陪玩", "抽卡", "氪金", "游戏币", "游戏充值", "游戏服务", "赛季票"
        ]
        let contextualGameTerms = [
            "上号", "充值", "点券", "皮肤", "月卡", "通行证", "账号交易"
        ]
        let gameContext = text.contains("游戏") || text.contains("手游") || text.contains("端游") || text.contains("网游")
        return gameTitles.contains { text.contains($0) }
            || strongGameTerms.contains { text.contains($0) }
            || (gameContext && contextualGameTerms.contains { text.contains($0) })
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
