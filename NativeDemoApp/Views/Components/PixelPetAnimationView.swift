import SwiftUI
import UIKit

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
