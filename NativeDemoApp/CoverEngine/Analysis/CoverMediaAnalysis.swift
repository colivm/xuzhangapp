import CoreImage
import Foundation
import UIKit
import Vision

enum CoverMediaAnalysisRules {
    static let currentVersion = 1
    static let maximumConcurrentAnalysisCount = 2
    static let maximumCachedResultCount = 64
    static let minimumHeroShortEdgePixels = 1_080
}

struct CoverNormalizedPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double

    var clamped: CoverNormalizedPoint {
        CoverNormalizedPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    var isValid: Bool {
        x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
    }
}

struct CoverNormalizedRect: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var center: CoverNormalizedPoint {
        CoverNormalizedPoint(x: x + width / 2, y: y + height / 2).clamped
    }

    var clamped: CoverNormalizedRect {
        let minimumX = min(max(x, 0), 1)
        let minimumY = min(max(y, 0), 1)
        let maximumX = min(max(x + width, minimumX), 1)
        let maximumY = min(max(y + height, minimumY), 1)
        return CoverNormalizedRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX,
            height: maximumY - minimumY
        )
    }

    var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite)
            && x >= 0
            && y >= 0
            && width >= 0
            && height >= 0
            && x + width <= 1
            && y + height <= 1
    }
}

struct CoverCropSafety: Codable, Equatable, Sendable {
    let focusPoint: CoverNormalizedPoint
    let protectedRegions: [CoverNormalizedRect]
    let safetyScore: Double

    var isValid: Bool {
        focusPoint.isValid
            && protectedRegions.allSatisfy(\.isValid)
            && safetyScore.isFinite
            && (0...1).contains(safetyScore)
    }
}

struct CoverRGBA: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var isValid: Bool {
        [red, green, blue, alpha].allSatisfy { $0.isFinite && (0...1).contains($0) }
    }

    var clamped: CoverRGBA {
        CoverRGBA(
            red: min(max(red, 0), 1),
            green: min(max(green, 0), 1),
            blue: min(max(blue, 0), 1),
            alpha: min(max(alpha, 0), 1)
        )
    }

    func mixed(with other: CoverRGBA, amount: Double) -> CoverRGBA {
        let weight = min(max(amount, 0), 1)
        return CoverRGBA(
            red: red + (other.red - red) * weight,
            green: green + (other.green - green) * weight,
            blue: blue + (other.blue - blue) * weight,
            alpha: alpha + (other.alpha - alpha) * weight
        ).clamped
    }

    var relativeLuminance: Double {
        func linear(_ value: Double) -> Double {
            value <= 0.03928
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    func contrastRatio(with other: CoverRGBA) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

struct CoverDynamicPalette: Codable, Equatable, Sendable {
    let sourceMediaID: UUID
    let backgroundStart: CoverRGBA
    let backgroundEnd: CoverRGBA
    let paper: CoverRGBA
    let ink: CoverRGBA
    let mutedInk: CoverRGBA
    let accent: CoverRGBA
    let minimumTextContrastRatio: Double

    var isValid: Bool {
        [backgroundStart, backgroundEnd, paper, ink, mutedInk, accent].allSatisfy(\.isValid)
            && minimumTextContrastRatio.isFinite
            && minimumTextContrastRatio >= 4.5
            && ink.contrastRatio(with: backgroundStart) >= 4.5
            && ink.contrastRatio(with: backgroundEnd) >= 4.5
            && mutedInk.contrastRatio(with: backgroundStart) >= 3
            && mutedInk.contrastRatio(with: backgroundEnd) >= 3
    }
}

struct CoverMediaAnalysis: Codable, Equatable, Sendable {
    let ruleVersion: Int
    let cacheKey: String
    let pixelWidth: Int
    let pixelHeight: Int
    let sharpness: Double
    let exposure: Double
    let dynamicRange: Double
    let resolutionFitness: Double
    let composition: Double
    let subjectSalience: Double
    let qualityScore: Double
    let hasSevereBlur: Bool
    let hasSevereExposureFailure: Bool
    let isBelowHeroResolution: Bool
    let cropSafety: CoverCropSafety
    let palette: CoverDynamicPalette?

    var isHeroEligible: Bool {
        isValid
            && !hasSevereBlur
            && !hasSevereExposureFailure
            && !isBelowHeroResolution
            && cropSafety.safetyScore >= 0.28
    }

    var isValid: Bool {
        let scores = [
            sharpness,
            exposure,
            dynamicRange,
            resolutionFitness,
            composition,
            subjectSalience,
            qualityScore,
        ]
        return ruleVersion == CoverMediaAnalysisRules.currentVersion
            && !cacheKey.isEmpty
            && pixelWidth > 0
            && pixelHeight > 0
            && scores.allSatisfy { $0.isFinite && (0...1).contains($0) }
            && cropSafety.isValid
            && (palette?.isValid ?? true)
    }

    var stableSignature: String {
        CoverStableIdentity.fingerprint([
            String(ruleVersion),
            cacheKey,
            String(format: "%.5f", qualityScore),
            String(format: "%.5f", cropSafety.focusPoint.x),
            String(format: "%.5f", cropSafety.focusPoint.y),
            palette == nil ? "fallback-palette" : "dynamic-palette",
        ])
    }

    func retargeted(to mediaID: UUID) -> CoverMediaAnalysis {
        guard let palette else { return self }
        return CoverMediaAnalysis(
            ruleVersion: ruleVersion,
            cacheKey: cacheKey,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            sharpness: sharpness,
            exposure: exposure,
            dynamicRange: dynamicRange,
            resolutionFitness: resolutionFitness,
            composition: composition,
            subjectSalience: subjectSalience,
            qualityScore: qualityScore,
            hasSevereBlur: hasSevereBlur,
            hasSevereExposureFailure: hasSevereExposureFailure,
            isBelowHeroResolution: isBelowHeroResolution,
            cropSafety: cropSafety,
            palette: CoverDynamicPalette(
                sourceMediaID: mediaID,
                backgroundStart: palette.backgroundStart,
                backgroundEnd: palette.backgroundEnd,
                paper: palette.paper,
                ink: palette.ink,
                mutedInk: palette.mutedInk,
                accent: palette.accent,
                minimumTextContrastRatio: palette.minimumTextContrastRatio
            )
        )
    }
}

struct CoverMediaAnalysisRequest: @unchecked Sendable {
    let mediaID: UUID
    let stableImageIdentity: String
    let image: UIImage

    var cacheKey: String {
        let cgSize = image.cgImage.map { "\($0.width)x\($0.height)" }
            ?? "\(Int(image.size.width * image.scale))x\(Int(image.size.height * image.scale))"
        return CoverStableIdentity.fingerprint([
            stableImageIdentity,
            cgSize,
            "cover-media-analysis-v\(CoverMediaAnalysisRules.currentVersion)",
        ])
    }
}

actor LocalCoverMediaAnalyzer {
    static let shared = LocalCoverMediaAnalyzer()

    private let maximumCacheCount: Int
    private var cachedByKey: [String: CoverMediaAnalysis] = [:]
    private var cacheOrder: [String] = []
    private var completedAnalysisExecutionCount = 0

    init(maximumCacheCount: Int = CoverMediaAnalysisRules.maximumCachedResultCount) {
        self.maximumCacheCount = max(1, maximumCacheCount)
    }

    func analyze(
        _ requests: [CoverMediaAnalysisRequest]
    ) async -> [UUID: CoverMediaAnalysis] {
        var resolved: [UUID: CoverMediaAnalysis] = [:]
        var pending: [CoverMediaAnalysisRequest] = []
        var pendingKeys = Set<String>()

        for request in requests {
            guard !Task.isCancelled else { return [:] }
            if let cached = cachedByKey[request.cacheKey] {
                resolved[request.mediaID] = cached.retargeted(to: request.mediaID)
            } else if pendingKeys.insert(request.cacheKey).inserted {
                pending.append(request)
            }
        }

        var startIndex = 0
        while startIndex < pending.count, !Task.isCancelled {
            let endIndex = min(
                startIndex + CoverMediaAnalysisRules.maximumConcurrentAnalysisCount,
                pending.count
            )
            let batch = Array(pending[startIndex..<endIndex])
            let analyzed = await withTaskGroup(
                of: (String, CoverMediaAnalysis?).self,
                returning: [String: CoverMediaAnalysis].self
            ) { group in
                for request in batch {
                    group.addTask(priority: .userInitiated) {
                        guard !Task.isCancelled else { return (request.cacheKey, nil) }
                        return (
                            request.cacheKey,
                            CoverMediaAnalyzerCore.analyze(request)
                        )
                    }
                }
                var values: [String: CoverMediaAnalysis] = [:]
                for await (key, analysis) in group {
                    guard !Task.isCancelled else {
                        group.cancelAll()
                        break
                    }
                    if let analysis {
                        values[key] = analysis
                    }
                }
                return values
            }
            guard !Task.isCancelled else { return [:] }
            for (key, analysis) in analyzed {
                completedAnalysisExecutionCount += 1
                insert(analysis, for: key)
            }
            startIndex = endIndex
        }

        for request in requests {
            if let analysis = cachedByKey[request.cacheKey] {
                resolved[request.mediaID] = analysis.retargeted(to: request.mediaID)
            }
        }
        return resolved
    }

    func cachedResultCount() -> Int {
        cachedByKey.count
    }

    func analysisExecutionCount() -> Int {
        completedAnalysisExecutionCount
    }

    private func insert(_ analysis: CoverMediaAnalysis, for key: String) {
        if cachedByKey[key] == nil {
            cacheOrder.append(key)
        }
        cachedByKey[key] = analysis
        while cacheOrder.count > maximumCacheCount {
            let evictedKey = cacheOrder.removeFirst()
            cachedByKey.removeValue(forKey: evictedKey)
        }
    }
}

enum CoverMediaRoleScoring {
    static func qualityScore(
        for descriptor: MediaDescriptor
    ) -> Double {
        descriptor.analysis?.qualityScore ?? 0.5
    }

    static func orderedHeroCandidates(
        _ descriptors: [MediaDescriptor],
        leadEvidenceItemIDs: [UUID]
    ) -> [MediaDescriptor] {
        let leadEvidence = Set(leadEvidenceItemIDs)
        return descriptors.enumerated()
            .filter { _, descriptor in
                descriptor.eligibility == .heroEligible
                    && descriptor.privacyRisk == .safe
                    && !Set(descriptor.evidenceItemIDs).isDisjoint(with: leadEvidence)
            }
            .sorted { lhs, rhs in
                let leftScore = qualityScore(for: lhs.element)
                let rightScore = qualityScore(for: rhs.element)
                if abs(leftScore - rightScore) > 0.000_001 {
                    return leftScore > rightScore
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    static func orderedSecondaryCandidates(
        _ descriptors: [MediaDescriptor],
        excluding heroID: UUID?
    ) -> [MediaDescriptor] {
        let hero = heroID.flatMap { id in descriptors.first { $0.id == id } }
        return descriptors.enumerated()
            .filter {
                $0.element.id != heroID
                    && $0.element.privacyRisk == .safe
                    && $0.element.eligibility != .excluded
            }
            .sorted { lhs, rhs in
                let leftScore = secondaryGain(lhs.element, hero: hero)
                let rightScore = secondaryGain(rhs.element, hero: hero)
                if abs(leftScore - rightScore) > 0.000_001 {
                    return leftScore > rightScore
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func secondaryGain(
        _ descriptor: MediaDescriptor,
        hero: MediaDescriptor?
    ) -> Double {
        let base = qualityScore(for: descriptor)
        guard let hero else { return base }
        let orientationDiversity = descriptor.orientation == hero.orientation ? 0 : 1.0
        let focusDiversity: Double
        if let point = descriptor.analysis?.cropSafety.focusPoint,
           let heroPoint = hero.analysis?.cropSafety.focusPoint {
            focusDiversity = min(1, hypot(point.x - heroPoint.x, point.y - heroPoint.y) * 1.5)
        } else {
            focusDiversity = 0.35
        }
        return 0.65 * base + 0.20 * orientationDiversity + 0.15 * focusDiversity
    }
}

enum CoverCropOffsetResolver {
    static func offset(
        imageSize: CGSize,
        frameSize: CGSize,
        focusPoint: CoverNormalizedPoint,
        protectedRegions: [CoverNormalizedRect] = []
    ) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              frameSize.width > 0, frameSize.height > 0 else { return .zero }
        let scale = max(
            frameSize.width / imageSize.width,
            frameSize.height / imageSize.height
        )
        let renderedWidth = imageSize.width * scale
        let renderedHeight = imageSize.height * scale
        let horizontalOverflow = max(0, renderedWidth - frameSize.width)
        let verticalOverflow = max(0, renderedHeight - frameSize.height)
        let point = focusPoint.clamped
        let desiredX = renderedWidth * (0.5 - point.x)
        let desiredY = renderedHeight * (0.5 - point.y)
        let globalHorizontalRange = (-horizontalOverflow / 2)...(horizontalOverflow / 2)
        let globalVerticalRange = (-verticalOverflow / 2)...(verticalOverflow / 2)
        let protectedHorizontalRange = protectedOffsetRange(
            regions: protectedRegions,
            renderedLength: renderedWidth,
            frameLength: frameSize.width,
            readsHorizontalAxis: true
        )
        let protectedVerticalRange = protectedOffsetRange(
            regions: protectedRegions,
            renderedLength: renderedHeight,
            frameLength: frameSize.height,
            readsHorizontalAxis: false
        )
        return CGSize(
            width: clampedOffset(
                desiredX,
                globalRange: globalHorizontalRange,
                protectedRange: protectedHorizontalRange
            ),
            height: clampedOffset(
                desiredY,
                globalRange: globalVerticalRange,
                protectedRange: protectedVerticalRange
            )
        )
    }

    private static func protectedOffsetRange(
        regions: [CoverNormalizedRect],
        renderedLength: CGFloat,
        frameLength: CGFloat,
        readsHorizontalAxis: Bool
    ) -> ClosedRange<CGFloat>? {
        guard !regions.isEmpty else { return nil }
        let centeredOrigin = (frameLength - renderedLength) / 2
        var lowerBound = -CGFloat.greatestFiniteMagnitude
        var upperBound = CGFloat.greatestFiniteMagnitude
        for region in regions {
            let minimum = readsHorizontalAxis ? region.x : region.y
            let length = readsHorizontalAxis ? region.width : region.height
            lowerBound = max(
                lowerBound,
                -centeredOrigin - CGFloat(minimum) * renderedLength
            )
            upperBound = min(
                upperBound,
                frameLength - centeredOrigin - CGFloat(minimum + length) * renderedLength
            )
        }
        return lowerBound <= upperBound ? lowerBound...upperBound : nil
    }

    private static func clampedOffset(
        _ desired: CGFloat,
        globalRange: ClosedRange<CGFloat>,
        protectedRange: ClosedRange<CGFloat>?
    ) -> CGFloat {
        let lowerBound = max(globalRange.lowerBound, protectedRange?.lowerBound ?? globalRange.lowerBound)
        let upperBound = min(globalRange.upperBound, protectedRange?.upperBound ?? globalRange.upperBound)
        guard lowerBound <= upperBound else {
            return min(max(desired, globalRange.lowerBound), globalRange.upperBound)
        }
        return min(max(desired, lowerBound), upperBound)
    }
}

private enum CoverMediaAnalyzerCore {
    private static let sampleSize = 64
    private static let ciContext = CIContext(options: [.cacheIntermediates: false])
    private static let white = CoverRGBA(red: 1, green: 1, blue: 1, alpha: 1)
    private static let darkInk = CoverRGBA(red: 0.105, green: 0.102, blue: 0.094, alpha: 1)
    private static let lightInk = CoverRGBA(red: 0.975, green: 0.97, blue: 0.95, alpha: 1)

    static func analyze(
        _ request: CoverMediaAnalysisRequest
    ) -> CoverMediaAnalysis? {
        guard !Task.isCancelled,
              let cgImage = normalizedCGImage(request.image),
              let sample = pixelSample(cgImage) else { return nil }
        let vision = visionFeatures(cgImage)
        guard !Task.isCancelled else { return nil }

        let metrics = imageMetrics(sample)
        let pixelWidth = cgImage.width
        let pixelHeight = cgImage.height
        let shortEdge = min(pixelWidth, pixelHeight)
        let resolutionFitness = clamp(
            Double(shortEdge) / Double(CoverMediaAnalysisRules.minimumHeroShortEdgePixels)
        )
        let protectedRegions = vision.faceRects
        let focusRegion = union(protectedRegions) ?? vision.salientRect
        let focusPoint = focusRegion?.center ?? CoverNormalizedPoint(x: 0.5, y: 0.5)
        let cropSafetyScore = cropSafetyScore(for: focusRegion)
        let composition = compositionScore(focusPoint)
        let subjectSalience = max(metrics.subjectSalience, vision.salientRect == nil ? 0 : 0.72)
        let severeBlur = metrics.sharpness < 0.14
        let severeExposure = metrics.meanLuminance < 0.075 || metrics.meanLuminance > 0.925
        let resolutionPenalty = shortEdge < CoverMediaAnalysisRules.minimumHeroShortEdgePixels ? 0.25 : 0
        let penalties = (severeBlur ? 0.35 : 0)
            + (severeExposure ? 0.25 : 0)
            + resolutionPenalty
        let score = clamp(
            0.24 * metrics.sharpness
                + 0.18 * metrics.exposure
                + 0.13 * metrics.dynamicRange
                + 0.15 * resolutionFitness
                + 0.12 * cropSafetyScore
                + 0.09 * composition
                + 0.09 * subjectSalience
                - penalties
        )
        let cropSafety = CoverCropSafety(
            focusPoint: focusPoint.clamped,
            protectedRegions: protectedRegions,
            safetyScore: cropSafetyScore
        )
        let palette = makePalette(
            mediaID: request.mediaID,
            sample: sample,
            excludedRegions: protectedRegions
        )
        return CoverMediaAnalysis(
            ruleVersion: CoverMediaAnalysisRules.currentVersion,
            cacheKey: request.cacheKey,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            sharpness: metrics.sharpness,
            exposure: metrics.exposure,
            dynamicRange: metrics.dynamicRange,
            resolutionFitness: resolutionFitness,
            composition: composition,
            subjectSalience: subjectSalience,
            qualityScore: score,
            hasSevereBlur: severeBlur,
            hasSevereExposureFailure: severeExposure,
            isBelowHeroResolution: shortEdge < CoverMediaAnalysisRules.minimumHeroShortEdgePixels,
            cropSafety: cropSafety,
            palette: palette
        )
    }

    private struct PixelSample {
        let width: Int
        let height: Int
        let rgba: [UInt8]
    }

    private struct ImageMetrics {
        let meanLuminance: Double
        let sharpness: Double
        let exposure: Double
        let dynamicRange: Double
        let subjectSalience: Double
    }

    private struct VisionFeatures {
        let faceRects: [CoverNormalizedRect]
        let salientRect: CoverNormalizedRect?
    }

    private static func normalizedCGImage(_ image: UIImage) -> CGImage? {
        image.cgImage
    }

    private static func pixelSample(_ cgImage: CGImage) -> PixelSample? {
        let source = CIImage(cgImage: cgImage)
        let scaleX = CGFloat(sampleSize) / max(source.extent.width, 1)
        let scaleY = CGFloat(sampleSize) / max(source.extent.height, 1)
        let sampled = source.transformed(
            by: CGAffineTransform(scaleX: scaleX, y: scaleY)
        )
        var bytes = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        ciContext.render(
            sampled,
            toBitmap: &bytes,
            rowBytes: sampleSize * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
            format: .RGBA8,
            colorSpace: colorSpace
        )
        return PixelSample(width: sampleSize, height: sampleSize, rgba: bytes)
    }

    private static func imageMetrics(_ sample: PixelSample) -> ImageMetrics {
        let count = sample.width * sample.height
        var luminance = [Double](repeating: 0, count: count)
        var sum = 0.0
        for index in 0..<count {
            let byteIndex = index * 4
            let red = Double(sample.rgba[byteIndex]) / 255
            let green = Double(sample.rgba[byteIndex + 1]) / 255
            let blue = Double(sample.rgba[byteIndex + 2]) / 255
            let value = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            luminance[index] = value
            sum += value
        }
        let mean = sum / Double(max(1, count))
        let variance = luminance.reduce(0) { result, value in
            result + pow(value - mean, 2)
        } / Double(max(1, count))
        var laplacianEnergy = 0.0
        var maximumGradient = 0.0
        var interiorCount = 0
        for y in 1..<(sample.height - 1) {
            for x in 1..<(sample.width - 1) {
                let index = y * sample.width + x
                let center = luminance[index]
                let laplacian = abs(
                    4 * center
                        - luminance[index - 1]
                        - luminance[index + 1]
                        - luminance[index - sample.width]
                        - luminance[index + sample.width]
                )
                laplacianEnergy += laplacian
                maximumGradient = max(maximumGradient, laplacian)
                interiorCount += 1
            }
        }
        let averageLaplacian = laplacianEnergy / Double(max(1, interiorCount))
        return ImageMetrics(
            meanLuminance: mean,
            sharpness: clamp(averageLaplacian * 5.2),
            exposure: clamp(1 - abs(mean - 0.5) / 0.5),
            dynamicRange: clamp(sqrt(variance) * 4.2),
            subjectSalience: clamp(maximumGradient * 1.8)
        )
    }

    private static func visionFeatures(_ cgImage: CGImage) -> VisionFeatures {
        guard !Task.isCancelled else {
            return VisionFeatures(faceRects: [], salientRect: nil)
        }
        let faceRequest = VNDetectFaceRectanglesRequest()
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try? handler.perform([faceRequest, saliencyRequest])
        let faces = (faceRequest.results ?? []).map { observation in
            topLeftNormalizedRect(observation.boundingBox)
        }
        let salientObservation = saliencyRequest.results?.first
        let salient = salientObservation?.salientObjects?.max(by: { lhs, rhs in
                lhs.boundingBox.width * lhs.boundingBox.height
                    < rhs.boundingBox.width * rhs.boundingBox.height
            })
            .map { topLeftNormalizedRect($0.boundingBox) }
        return VisionFeatures(faceRects: faces, salientRect: salient)
    }

    private static func topLeftNormalizedRect(_ rect: CGRect) -> CoverNormalizedRect {
        CoverNormalizedRect(
            x: rect.minX,
            y: 1 - rect.maxY,
            width: rect.width,
            height: rect.height
        ).clamped
    }

    private static func union(_ rects: [CoverNormalizedRect]) -> CoverNormalizedRect? {
        guard var value = rects.first else { return nil }
        for rect in rects.dropFirst() {
            let minimumX = min(value.x, rect.x)
            let minimumY = min(value.y, rect.y)
            let maximumX = max(value.x + value.width, rect.x + rect.width)
            let maximumY = max(value.y + value.height, rect.y + rect.height)
            value = CoverNormalizedRect(
                x: minimumX,
                y: minimumY,
                width: maximumX - minimumX,
                height: maximumY - minimumY
            ).clamped
        }
        return value
    }

    private static func cropSafetyScore(for rect: CoverNormalizedRect?) -> Double {
        guard let rect else { return 0.72 }
        if rect.width > 0.78 || rect.height > 0.86 { return 0.18 }
        let edgeMargin = [
            rect.x,
            rect.y,
            1 - rect.x - rect.width,
            1 - rect.y - rect.height,
        ].min() ?? 0
        let sizePenalty = max(0, rect.width * rect.height - 0.58)
        return clamp(0.50 + edgeMargin * 2.2 - sizePenalty)
    }

    private static func compositionScore(_ point: CoverNormalizedPoint) -> Double {
        let thirds = [
            CoverNormalizedPoint(x: 1.0 / 3.0, y: 1.0 / 3.0),
            CoverNormalizedPoint(x: 2.0 / 3.0, y: 1.0 / 3.0),
            CoverNormalizedPoint(x: 1.0 / 3.0, y: 2.0 / 3.0),
            CoverNormalizedPoint(x: 2.0 / 3.0, y: 2.0 / 3.0),
        ]
        let minimumDistance = thirds.map { hypot(point.x - $0.x, point.y - $0.y) }.min() ?? 1
        return clamp(1 - minimumDistance / 0.48)
    }

    private static func makePalette(
        mediaID: UUID,
        sample: PixelSample,
        excludedRegions: [CoverNormalizedRect]
    ) -> CoverDynamicPalette? {
        var colors: [CoverRGBA] = []
        colors.reserveCapacity(sample.width * sample.height)
        for y in 0..<sample.height {
            for x in 0..<sample.width {
                let normalizedX = (Double(x) + 0.5) / Double(sample.width)
                let normalizedY = 1 - (Double(y) + 0.5) / Double(sample.height)
                let isExcluded = excludedRegions.contains { rect in
                    normalizedX >= rect.x && normalizedX <= rect.x + rect.width
                        && normalizedY >= rect.y && normalizedY <= rect.y + rect.height
                }
                guard !isExcluded else { continue }
                let index = (y * sample.width + x) * 4
                let color = CoverRGBA(
                    red: Double(sample.rgba[index]) / 255,
                    green: Double(sample.rgba[index + 1]) / 255,
                    blue: Double(sample.rgba[index + 2]) / 255,
                    alpha: 1
                )
                let luminance = color.relativeLuminance
                if luminance > 0.035, luminance < 0.93 {
                    colors.append(color)
                }
            }
        }
        guard colors.count >= 24 else { return nil }
        let dominant = dominantColor(colors)
        let muted = limitedSaturation(dominant, minimum: 0.08, maximum: 0.32)
        let start = muted.mixed(with: white, amount: 0.84)
        let end = muted.mixed(with: white, amount: 0.72)
        let ink = min(
            darkInk.contrastRatio(with: start),
            darkInk.contrastRatio(with: end)
        ) >= 4.5 ? darkInk : lightInk
        let mutedCandidate = ink.mixed(with: start, amount: ink == darkInk ? 0.28 : 0.18)
        let mutedInk = min(
            mutedCandidate.contrastRatio(with: start),
            mutedCandidate.contrastRatio(with: end)
        ) >= 3 ? mutedCandidate : ink
        let minimumContrast = min(
            ink.contrastRatio(with: start),
            ink.contrastRatio(with: end)
        )
        let palette = CoverDynamicPalette(
            sourceMediaID: mediaID,
            backgroundStart: start,
            backgroundEnd: end,
            paper: white.mixed(with: muted, amount: 0.05),
            ink: ink,
            mutedInk: mutedInk,
            accent: muted,
            minimumTextContrastRatio: minimumContrast
        )
        return palette.isValid ? palette : nil
    }

    private static func dominantColor(_ colors: [CoverRGBA]) -> CoverRGBA {
        let clusterCount = min(5, colors.count)
        var centers = (0..<clusterCount).map { index in
            colors[index * max(1, colors.count / clusterCount)]
        }
        let colorLabs = colors.map(lab)
        var assignments = [Int](repeating: 0, count: colors.count)
        for _ in 0..<6 {
            let centerLabs = centers.map(lab)
            for index in colors.indices {
                assignments[index] = centerLabs.enumerated().min { lhs, rhs in
                    labDistance(colorLabs[index], lhs.element)
                        < labDistance(colorLabs[index], rhs.element)
                }?.offset ?? 0
            }
            for cluster in 0..<clusterCount {
                let members = colors.enumerated().compactMap { index, color in
                    assignments[index] == cluster ? color : nil
                }
                guard !members.isEmpty else { continue }
                centers[cluster] = CoverRGBA(
                    red: members.reduce(0) { $0 + $1.red } / Double(members.count),
                    green: members.reduce(0) { $0 + $1.green } / Double(members.count),
                    blue: members.reduce(0) { $0 + $1.blue } / Double(members.count),
                    alpha: 1
                )
            }
        }
        let counts = (0..<clusterCount).map { cluster in
            assignments.filter { $0 == cluster }.count
        }
        let winningIndex = counts.enumerated().max { $0.element < $1.element }?.offset ?? 0
        return centers[winningIndex]
    }

    private static func limitedSaturation(
        _ color: CoverRGBA,
        minimum: Double,
        maximum: Double
    ) -> CoverRGBA {
        let maximumChannel = [color.red, color.green, color.blue].max() ?? 0
        let minimumChannel = [color.red, color.green, color.blue].min() ?? 0
        let lightness = (maximumChannel + minimumChannel) / 2
        let delta = maximumChannel - minimumChannel
        guard delta > 0.000_001 else {
            return color.mixed(with: CoverRGBA(red: 0.55, green: 0.57, blue: 0.54, alpha: 1), amount: minimum)
        }
        let currentSaturation = delta / (1 - abs(2 * lightness - 1))
        let targetSaturation = min(max(currentSaturation, minimum), maximum)
        if currentSaturation <= targetSaturation { return color }
        let gray = CoverRGBA(red: lightness, green: lightness, blue: lightness, alpha: 1)
        return gray.mixed(with: color, amount: targetSaturation / currentSaturation)
    }

    private struct LabColor {
        let lightness: Double
        let a: Double
        let b: Double
    }

    private static func lab(_ color: CoverRGBA) -> LabColor {
        func linear(_ value: Double) -> Double {
            value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        let red = linear(color.red)
        let green = linear(color.green)
        let blue = linear(color.blue)
        let x = (0.4124 * red + 0.3576 * green + 0.1805 * blue) / 0.95047
        let y = (0.2126 * red + 0.7152 * green + 0.0722 * blue)
        let z = (0.0193 * red + 0.1192 * green + 0.9505 * blue) / 1.08883
        func pivot(_ value: Double) -> Double {
            value > 0.008856 ? pow(value, 1.0 / 3.0) : 7.787 * value + 16.0 / 116.0
        }
        let fx = pivot(x)
        let fy = pivot(y)
        let fz = pivot(z)
        return LabColor(
            lightness: 116 * fy - 16,
            a: 500 * (fx - fy),
            b: 200 * (fy - fz)
        )
    }

    private static func labDistance(_ lhs: LabColor, _ rhs: LabColor) -> Double {
        let lightness = lhs.lightness - rhs.lightness
        let a = lhs.a - rhs.a
        let b = lhs.b - rhs.b
        return lightness * lightness + a * a + b * b
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
