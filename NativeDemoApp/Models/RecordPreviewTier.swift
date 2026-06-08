import Foundation

enum RecordPreviewTier {
    case hidden
    case whisper
    case confirm

    struct Input {
        let amount: Double
        let itemsCount: Int
        let hasBrand: Bool
        let hasNote: Bool
        let previewLineWasRotated: Bool
        let isEditing: Bool
        let prefillSource: String?
        let prefillConfidence: Double?
    }

    static func resolve(_ input: Input) -> RecordPreviewTier {
        guard input.amount > 0 else { return .hidden }

        if input.hasBrand || input.hasNote || input.previewLineWasRotated || input.isEditing {
            return .confirm
        }

        if input.itemsCount < 3 {
            return .whisper
        }

        if input.prefillSource == "habit",
           (input.prefillConfidence ?? 0) >= 0.55 {
            return .confirm
        }

        return .whisper
    }
}
