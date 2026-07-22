import Foundation
import SwiftUI
import UIKit

enum HomePetOverlaySide: String, Codable, CaseIterable, Equatable, Sendable {
    case left
    case right

    var alignment: Alignment {
        switch self {
        case .left: return .bottomLeading
        case .right: return .bottomTrailing
        }
    }
}

struct HomePetOverlayPlacement: Codable, Equatable, Sendable {
    var side: HomePetOverlaySide
    var verticalFraction: Double

    static let defaultPlacement = HomePetOverlayPlacement(side: .right, verticalFraction: 0)
}

enum HomePetOverlayPositionPolicy {
    static let edgeCenterInset: CGFloat = 42
    static let minimumBottomInset: CGFloat = 102
    static let minimumTopClearance: CGFloat = 170
    static let dragActivationDistance: CGFloat = 8

    static func isMeaningfulDrag(_ translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) >= dragActivationDistance
    }

    static func normalized(_ placement: HomePetOverlayPlacement) -> HomePetOverlayPlacement {
        HomePetOverlayPlacement(
            side: placement.side,
            verticalFraction: min(1, max(0, placement.verticalFraction))
        )
    }

    static func bottomInset(
        for placement: HomePetOverlayPlacement,
        viewportHeight: CGFloat
    ) -> CGFloat {
        let normalizedPlacement = normalized(placement)
        let maximum = max(minimumBottomInset, viewportHeight - minimumTopClearance)
        return minimumBottomInset
            + CGFloat(normalizedPlacement.verticalFraction) * (maximum - minimumBottomInset)
    }

    static func clampedDragTranslation(
        placement: HomePetOverlayPlacement,
        proposed: CGSize,
        viewport: CGSize
    ) -> CGSize {
        guard viewport.width > edgeCenterInset * 2, viewport.height > 0 else { return .zero }
        let normalizedPlacement = normalized(placement)
        let baseX = normalizedPlacement.side == .left
            ? edgeCenterInset
            : viewport.width - edgeCenterInset
        let desiredX = min(
            viewport.width - edgeCenterInset,
            max(edgeCenterInset, baseX + proposed.width)
        )
        let baseBottom = bottomInset(for: normalizedPlacement, viewportHeight: viewport.height)
        let maximumBottom = max(minimumBottomInset, viewport.height - minimumTopClearance)
        let desiredBottom = min(
            maximumBottom,
            max(minimumBottomInset, baseBottom - proposed.height)
        )
        return CGSize(
            width: desiredX - baseX,
            height: baseBottom - desiredBottom
        )
    }

    static func committedPlacement(
        from placement: HomePetOverlayPlacement,
        translation: CGSize,
        viewport: CGSize
    ) -> HomePetOverlayPlacement {
        guard viewport.width > edgeCenterInset * 2, viewport.height > 0 else {
            return normalized(placement)
        }
        let normalizedPlacement = normalized(placement)
        let clamped = clampedDragTranslation(
            placement: normalizedPlacement,
            proposed: translation,
            viewport: viewport
        )
        let baseX = normalizedPlacement.side == .left
            ? edgeCenterInset
            : viewport.width - edgeCenterInset
        let side: HomePetOverlaySide = baseX + clamped.width < viewport.width / 2 ? .left : .right
        let baseBottom = bottomInset(for: normalizedPlacement, viewportHeight: viewport.height)
        let committedBottom = baseBottom - clamped.height
        let maximumBottom = max(minimumBottomInset, viewport.height - minimumTopClearance)
        let travel = maximumBottom - minimumBottomInset
        let fraction = travel > 0
            ? Double((committedBottom - minimumBottomInset) / travel)
            : 0
        return normalized(
            HomePetOverlayPlacement(side: side, verticalFraction: fraction)
        )
    }
}

enum HomePetOverlayPositionStore {
    private static let key = "home_pet_overlay_placement_v1"

    static func load(defaults: UserDefaults = .standard) -> HomePetOverlayPlacement {
        guard let data = defaults.data(forKey: key),
              let placement = try? JSONDecoder().decode(HomePetOverlayPlacement.self, from: data) else {
            return .defaultPlacement
        }
        return HomePetOverlayPositionPolicy.normalized(placement)
    }

    static func save(
        _ placement: HomePetOverlayPlacement,
        defaults: UserDefaults = .standard
    ) {
        let normalized = HomePetOverlayPositionPolicy.normalized(placement)
        guard let data = try? JSONEncoder().encode(normalized) else { return }
        defaults.set(data, forKey: key)
    }
}

enum PixelPetAnimationSequence: String, CaseIterable, Equatable, Sendable {
    case idle
    case tap
    case speak

    var assetName: String {
        switch self {
        case .idle:
            return "PetIdleFrames"
        case .tap:
            return "PetTapFrames"
        case .speak:
            return "PetSpeakFrames"
        }
    }
}

struct PixelPetAnimationPlan: Equatable, Sendable {
    let sequence: PixelPetAnimationSequence
    let animates: Bool
    let stableFrameIndex: Int
}

enum PixelPetAnimationPolicy {
    static let idleDurationsMilliseconds = [800, 120, 90, 90, 100, 120, 180, 800]
    static let tapDurationsMilliseconds = [120, 80, 80, 80, 140, 100, 80, 180]
    static let speakDurationsMilliseconds = [160, 90, 90, 90, 110, 90, 100, 240]

    static func durationsMilliseconds(for sequence: PixelPetAnimationSequence) -> [Int] {
        switch sequence {
        case .idle:
            return idleDurationsMilliseconds
        case .tap:
            return tapDurationsMilliseconds
        case .speak:
            return speakDurationsMilliseconds
        }
    }

    static func plan(
        tapPending: Bool,
        bubbleVisible: Bool,
        sceneIsActive: Bool,
        reduceMotion: Bool,
        lowPowerMode: Bool
    ) -> PixelPetAnimationPlan {
        let stableSequence: PixelPetAnimationSequence = bubbleVisible ? .speak : .idle
        guard sceneIsActive, !reduceMotion, !lowPowerMode else {
            return PixelPetAnimationPlan(
                sequence: stableSequence,
                animates: false,
                stableFrameIndex: 0
            )
        }
        return PixelPetAnimationPlan(
            sequence: tapPending ? .tap : stableSequence,
            animates: true,
            stableFrameIndex: 0
        )
    }

    static func followUpSequence(bubbleVisible: Bool) -> PixelPetAnimationSequence {
        bubbleVisible ? .speak : .idle
    }
}

private struct PixelPetAnimationRequest: Equatable {
    let tapTrigger: Int
    let bubbleVisible: Bool
    let sceneIsActive: Bool
    let reduceMotion: Bool
    let lowPowerMode: Bool
}

private final class PixelPetFrameBox: NSObject {
    let frames: [UIImage]

    init(frames: [UIImage]) {
        self.frames = frames
    }
}

private enum PixelPetSpriteSheet {
    private static let columns = 4
    private static let rows = 2
    private static let expectedFrameCount = 8
    private static let cache = NSCache<NSString, PixelPetFrameBox>()

    static func frames(for sequence: PixelPetAnimationSequence) -> [UIImage] {
        let key = sequence.rawValue as NSString
        if let cached = cache.object(forKey: key) {
            return cached.frames
        }
        guard let sheet = UIImage(named: sequence.assetName),
              let source = sheet.cgImage,
              source.width.isMultiple(of: columns),
              source.height.isMultiple(of: rows) else {
            return []
        }

        let frameWidth = source.width / columns
        let frameHeight = source.height / rows
        var frames: [UIImage] = []
        frames.reserveCapacity(expectedFrameCount)

        for index in 0..<expectedFrameCount {
            let rect = CGRect(
                x: CGFloat((index % columns) * frameWidth),
                y: CGFloat((index / columns) * frameHeight),
                width: CGFloat(frameWidth),
                height: CGFloat(frameHeight)
            )
            guard let cropped = source.cropping(to: rect) else {
                return []
            }
            frames.append(
                UIImage(cgImage: cropped, scale: sheet.scale, orientation: .up)
            )
        }

        cache.setObject(PixelPetFrameBox(frames: frames), forKey: key)
        return frames
    }

    static func fallbackFrame() -> UIImage? {
        frames(for: .idle).first
    }
}

struct PixelPetAnimationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var currentFrame: UIImage?
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var handledTapTrigger: Int

    let isSpeaking: Bool
    let tapTrigger: Int

    init(isSpeaking: Bool, tapTrigger: Int) {
        self.isSpeaking = isSpeaking
        self.tapTrigger = tapTrigger
        _currentFrame = State(initialValue: PixelPetSpriteSheet.fallbackFrame())
        _handledTapTrigger = State(initialValue: tapTrigger)
    }

    var body: some View {
        Group {
            if let currentFrame {
                Image(uiImage: currentFrame)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .accessibilityHidden(true)
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name.NSProcessInfoPowerStateDidChange
            )
        ) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .task(id: animationRequest) {
            await runAnimation(for: animationRequest)
        }
    }

    private var animationRequest: PixelPetAnimationRequest {
        PixelPetAnimationRequest(
            tapTrigger: tapTrigger,
            bubbleVisible: isSpeaking,
            sceneIsActive: scenePhase == .active,
            reduceMotion: reduceMotion,
            lowPowerMode: isLowPowerModeEnabled
        )
    }

    @MainActor
    private func runAnimation(for request: PixelPetAnimationRequest) async {
        let tapPending = request.tapTrigger != handledTapTrigger
        let plan = PixelPetAnimationPolicy.plan(
            tapPending: tapPending,
            bubbleVisible: request.bubbleVisible,
            sceneIsActive: request.sceneIsActive,
            reduceMotion: request.reduceMotion,
            lowPowerMode: request.lowPowerMode
        )

        guard plan.animates else {
            handledTapTrigger = request.tapTrigger
            showStableFrame(sequence: plan.sequence, index: plan.stableFrameIndex)
            return
        }

        if tapPending {
            handledTapTrigger = request.tapTrigger
            guard await play(sequence: .tap, repeats: false) else { return }
            guard !Task.isCancelled else { return }
        }

        let followUp = PixelPetAnimationPolicy.followUpSequence(
            bubbleVisible: request.bubbleVisible
        )
        _ = await play(sequence: followUp, repeats: true)
    }

    @MainActor
    private func play(
        sequence: PixelPetAnimationSequence,
        repeats: Bool
    ) async -> Bool {
        let frames = PixelPetSpriteSheet.frames(for: sequence)
        let durations = PixelPetAnimationPolicy.durationsMilliseconds(for: sequence)
        guard frames.count == durations.count else {
            currentFrame = PixelPetSpriteSheet.fallbackFrame()
            return false
        }

        repeat {
            for (index, frame) in frames.enumerated() {
                guard !Task.isCancelled else { return false }
                currentFrame = frame
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(durations[index]) * 1_000_000
                    )
                } catch {
                    return false
                }
            }
        } while repeats && !Task.isCancelled

        return !Task.isCancelled
    }

    @MainActor
    private func showStableFrame(
        sequence: PixelPetAnimationSequence,
        index: Int
    ) {
        let frames = PixelPetSpriteSheet.frames(for: sequence)
        if frames.indices.contains(index) {
            currentFrame = frames[index]
        } else {
            currentFrame = PixelPetSpriteSheet.fallbackFrame()
        }
    }
}

struct MovablePixelPetOverlay: View {
    private static let dragCoordinateSpaceName = "homePetOverlayViewport"

    @GestureState private var proposedDragTranslation: CGSize = .zero
    @State private var placement = HomePetOverlayPositionStore.load()
    @State private var tapSuppressionID: UUID?

    let message: String?
    let isSpeaking: Bool
    let tapTrigger: Int
    let onTap: () -> Void
    let onHide: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let viewport = proxy.size
            let clampedTranslation = HomePetOverlayPositionPolicy.clampedDragTranslation(
                placement: placement,
                proposed: proposedDragTranslation,
                viewport: viewport
            )
            petStack(viewport: viewport)
                .padding(.horizontal, 16)
                .padding(
                    .bottom,
                    HomePetOverlayPositionPolicy.bottomInset(
                        for: placement,
                        viewportHeight: viewport.height
                    )
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: placement.side.alignment
                )
                .offset(clampedTranslation)
        }
        .coordinateSpace(name: Self.dragCoordinateSpaceName)
    }

    private func petStack(viewport: CGSize) -> some View {
        VStack(
            alignment: placement.side == .left ? .leading : .trailing,
            spacing: 8
        ) {
            if let message {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.9))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.48), lineWidth: 1)
                    )
                    .frame(maxWidth: 210, alignment: placement.side == .left ? .leading : .trailing)
                    .transition(.scale(scale: 0.96, anchor: placement.side == .left ? .bottomLeading : .bottomTrailing).combined(with: .opacity))
            }

            petControl(viewport: viewport)
        }
    }

    private func petControl(viewport: CGSize) -> some View {
        PixelPetAnimationView(isSpeaking: isSpeaking, tapTrigger: tapTrigger)
            .frame(width: 48, height: 48)
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.floatingPetPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            .onTapGesture {
                guard tapSuppressionID == nil else { return }
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.6, maximumDistance: 14) {
                suppressTapTemporarily()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onHide()
            }
            .highPriorityGesture(dragGesture(viewport: viewport))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("宠物助手")
            .accessibilityHint(isSpeaking ? "点按收起消息，长按隐藏宠物" : "点按听一句，长按隐藏宠物")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "隐藏宠物") {
                onHide()
            }
            .accessibilityAction(named: "移到左侧") {
                commitAccessibilityPlacement(side: .left)
            }
            .accessibilityAction(named: "移到右侧") {
                commitAccessibilityPlacement(side: .right)
            }
    }

    private func dragGesture(viewport: CGSize) -> some Gesture {
        DragGesture(
            minimumDistance: HomePetOverlayPositionPolicy.dragActivationDistance,
            coordinateSpace: .named(Self.dragCoordinateSpaceName)
        )
            .updating($proposedDragTranslation) { value, state, transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
                state = value.translation
            }
            .onEnded { value in
                guard HomePetOverlayPositionPolicy.isMeaningfulDrag(value.translation) else {
                    return
                }
                let committed = HomePetOverlayPositionPolicy.committedPlacement(
                    from: placement,
                    translation: value.translation,
                    viewport: viewport
                )
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    placement = committed
                }
                HomePetOverlayPositionStore.save(committed)
                suppressTapTemporarily()
                UISelectionFeedbackGenerator().selectionChanged()
            }
    }

    private func suppressTapTemporarily() {
        let requestID = UUID()
        tapSuppressionID = requestID
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard tapSuppressionID == requestID else { return }
            tapSuppressionID = nil
        }
    }

    private func commitAccessibilityPlacement(side: HomePetOverlaySide) {
        let committed = HomePetOverlayPlacement(
            side: side,
            verticalFraction: placement.verticalFraction
        )
        placement = committed
        HomePetOverlayPositionStore.save(committed)
    }
}
