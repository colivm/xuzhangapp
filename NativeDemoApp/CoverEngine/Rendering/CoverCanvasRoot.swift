import SwiftUI
import UIKit

struct CoverCanvasRoot: View {
    let renderInput: PreparedCoverRenderInput

    private var palette: CoverResolvedPalette {
        CoverResolvedPalette.resolve(
            renderInput.recipe.palette.paletteID,
            dynamicPalette: renderInput.dynamicPalette,
            usesImageBackground: renderInput.backgroundImage != nil
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            coverBackground

            CoverBackgroundTexture(
                family: renderInput.recipe.background.family,
                palette: palette
            )

            CoverTemplateBodyRenderer(
                renderInput: renderInput,
                palette: palette
            )

            GlobalFooterRenderer(
                renderInput: renderInput,
                palette: palette
            )
            .frame(
                width: CGFloat(renderInput.layout.footerFrame.width),
                height: CGFloat(renderInput.layout.footerFrame.height),
                alignment: .leading
            )
            .offset(
                x: CGFloat(renderInput.layout.footerFrame.x),
                y: CGFloat(renderInput.layout.footerFrame.y)
            )
        }
        .frame(
            width: CGFloat(renderInput.layout.canvasSize.width),
            height: CGFloat(renderInput.layout.canvasSize.height)
        )
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var coverBackground: some View {
        if let backgroundImage = renderInput.backgroundImage {
            Image(uiImage: backgroundImage)
                .resizable()
                .scaledToFill()
                .frame(
                    width: CGFloat(renderInput.layout.canvasSize.width),
                    height: CGFloat(renderInput.layout.canvasSize.height)
                )
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.30), Color.black.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            LinearGradient(
                colors: [palette.backgroundStart, palette.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var accessibilitySummary: String {
        let period = renderInput.allocation.masthead.first?.text ?? renderInput.identity.periodKey
        let lead = renderInput.allocation.storyLead.text
        let imageCount = renderInput.preparedImagesByID.count
        return "\(period)，\(lead)，\(imageCount) 张封面照片，\(renderInput.footerPresentation.text)"
    }
}

private struct CoverTemplateBodyRenderer: View {
    let renderInput: PreparedCoverRenderInput
    let palette: CoverResolvedPalette

    private var bodyAtomsByID: [String: CoverContentAtom] {
        Dictionary(
            uniqueKeysWithValues: renderInput.allocation.visiblePlacements.compactMap { placement in
                placement.region == .footer ? nil : (placement.atom.id, placement.atom)
            }
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CoverTemplateDecoration(
                templateID: renderInput.recipe.template.templateID,
                layout: renderInput.layout,
                palette: palette
            )

            ForEach(renderInput.layout.bodyAtomPlacements) { placement in
                if let atom = bodyAtomsByID[placement.atomID] {
                    Text(atom.text)
                        .font(font(for: placement.textRole))
                        .foregroundStyle(textColor(for: placement.textRole))
                        .multilineTextAlignment(textAlignment(placement.alignment))
                        .lineSpacing(lineSpacing(for: placement.textRole))
                        .lineLimit(placement.lineLimit)
                        .minimumScaleFactor(minimumScaleFactor(for: placement.textRole))
                        .frame(
                            width: CGFloat(placement.frame.width),
                            height: CGFloat(placement.frame.height),
                            alignment: frameAlignment(placement.alignment)
                        )
                        .offset(
                            x: CGFloat(placement.frame.x),
                            y: CGFloat(placement.frame.y)
                        )
                }
            }

            ForEach(renderInput.layout.mediaPlacements.sorted { $0.zIndex < $1.zIndex }) { placement in
                if let image = renderInput.preparedImagesByID[placement.mediaID] {
                    coverImage(image, placement: placement)
                        .zIndex(Double(placement.zIndex))
                }
            }
        }
    }

    @ViewBuilder
    private func coverImage(
        _ image: UIImage,
        placement: ResolvedCoverMediaPlacement
    ) -> some View {
        let cornerRadius = mediaCornerRadius(placement.treatment)
        let frameSize = CGSize(
            width: CGFloat(placement.frame.width),
            height: CGFloat(placement.frame.height)
        )
        let focusPoint = renderInput.mediaAnalysesByID[placement.mediaID]?.cropSafety.focusPoint
            ?? CoverNormalizedPoint(x: 0.5, y: 0.5)
        let protectedRegions = renderInput.mediaAnalysesByID[placement.mediaID]?.cropSafety.protectedRegions
            ?? []
        let cropOffset = CoverCropOffsetResolver.offset(
            imageSize: image.size,
            frameSize: frameSize,
            focusPoint: focusPoint,
            protectedRegions: protectedRegions
        )
        Group {
            if placement.cropMode == .fit {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .offset(x: cropOffset.width, y: cropOffset.height)
            }
        }
        .frame(
            width: frameSize.width,
            height: frameSize.height
        )
        .clipped()
        .background(palette.paper.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(palette.ink.opacity(0.10), lineWidth: 0.8)
        )
        .shadow(
            color: palette.ink.opacity(placement.treatment == .clean ? 0.10 : 0.14),
            radius: placement.treatment == .clean ? 18 : 12,
            x: 0,
            y: placement.treatment == .clean ? 10 : 6
        )
        .offset(
            x: CGFloat(placement.frame.x),
            y: CGFloat(placement.frame.y)
        )
        .clipped()
    }

    private func font(for role: CoverTextRole) -> Font {
        let templateID = renderInput.recipe.template.templateID
        switch role {
        case .masthead:
            return .system(size: 12, weight: .semibold, design: .default)
        case .lead:
            switch templateID {
            case .magazine, .editorial:
                return .system(size: 38, weight: .bold, design: .default)
            case .journal, .scrapbook, .travelNote, .natureDiary, .warmHome:
                return .system(size: 35, weight: .semibold, design: .serif)
            case .quote:
                return .system(size: 48, weight: .semibold, design: .serif)
            case .timeline, .film:
                return .system(size: 36, weight: .semibold, design: .default)
            case .minimal:
                return .system(size: 44, weight: .semibold, design: .serif)
            case .memoryWall, .quietEditorial:
                return .system(size: 40, weight: .semibold, design: .serif)
            case .bookCover:
                return .system(size: 42, weight: .semibold, design: .serif)
            case .heroStory, .memoryFocus, .postcard, .coffeeStory,
                 .nightStory, .ocean:
                return .system(size: 42, weight: .semibold, design: .serif)
            }
        case .support:
            let usesSerif = renderInput.recipe.typography.family == .journal
                || renderInput.recipe.typography.family == .songEditorial
            return .system(
                size: templateID == .journal ? 18 : 16,
                weight: .regular,
                design: usesSerif ? .serif : .default
            )
        case .caption:
            return .system(size: 12, weight: .medium, design: .default)
        case .mark:
            return .system(size: 12, weight: .semibold, design: .default)
        case .timeline:
            return .system(size: 13, weight: .semibold, design: .default)
        }
    }

    private func textColor(for role: CoverTextRole) -> Color {
        switch role {
        case .lead:
            return palette.ink
        case .support:
            return palette.ink.opacity(0.76)
        default:
            return palette.mutedInk
        }
    }

    private func textAlignment(_ alignment: CoverTextAlignmentToken) -> TextAlignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private func frameAlignment(_ alignment: CoverTextAlignmentToken) -> Alignment {
        switch alignment {
        case .leading: return .topLeading
        case .center: return .top
        case .trailing: return .topTrailing
        }
    }

    private func lineSpacing(for role: CoverTextRole) -> CGFloat {
        switch role {
        case .lead:
            return renderInput.recipe.template.templateID == .quote ? 10 : 7
        case .support:
            return renderInput.recipe.typography.family == .journal ? 9 : 6
        default: return 2
        }
    }

    private func minimumScaleFactor(for role: CoverTextRole) -> CGFloat {
        guard role == .lead else { return 0.84 }
        switch renderInput.recipe.template.templateID {
        case .journal, .quote, .bookCover, .quietEditorial:
            return 0.68
        default:
            return 0.74
        }
    }

    private func mediaCornerRadius(_ treatment: MediaTreatment) -> CGFloat {
        switch treatment {
        case .clean: return 22
        case .paper: return 14
        case .film: return 8
        case .polaroid: return 10
        }
    }
}

private struct CoverTemplateDecoration: View {
    let templateID: CoverTemplateID
    let layout: ResolvedCoverLayout
    let palette: CoverResolvedPalette

    @ViewBuilder
    var body: some View {
        switch templateID {
        case .heroStory:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.paper.opacity(0.52))
                .frame(width: 432, height: 78)
                .offset(x: 20, y: 194)
        case .magazine:
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.ink.opacity(0.18))
                    .frame(width: 1, height: 520)
                    .offset(x: 347, y: 282)
                Rectangle()
                    .fill(palette.ink.opacity(0.52))
                    .frame(width: 138, height: 2)
                    .offset(x: 370, y: 176)
            }
        case .memoryFocus:
            ZStack(alignment: .topLeading) {
                Circle()
                    .stroke(palette.mutedInk.opacity(0.12), lineWidth: 1)
                    .frame(width: 412, height: 412)
                    .offset(x: 64, y: 232)
                Rectangle()
                    .fill(palette.mutedInk.opacity(0.16))
                    .frame(width: 96, height: 1)
                    .offset(x: 56, y: 286)
            }
        case .journal:
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.mutedInk.opacity(0.14))
                    .frame(width: 1, height: 410)
                    .offset(x: 56, y: 392)
                ForEach(0..<7, id: \.self) { index in
                    Rectangle()
                        .fill(palette.mutedInk.opacity(0.10))
                        .frame(width: 384, height: 0.8)
                        .offset(x: 72, y: 454 + CGFloat(index) * 46)
                }
            }
        case .film:
            ZStack(alignment: .topLeading) {
                ForEach(0..<12, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.paper.opacity(0.38))
                        .frame(width: 16, height: 8)
                        .offset(x: 12, y: 228 + CGFloat(index) * 50)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.paper.opacity(0.38))
                        .frame(width: 16, height: 8)
                        .offset(x: 512, y: 228 + CGFloat(index) * 50)
                }
            }
        case .quote:
            ZStack(alignment: .topLeading) {
                Circle()
                    .fill(palette.paper.opacity(0.70))
                    .frame(width: 286, height: 286)
                    .offset(x: 258, y: 54)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.mutedInk.opacity(0.12), lineWidth: 1)
                    .frame(width: 468, height: 430)
                    .offset(x: 36, y: 112)
            }
        case .timeline:
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.mutedInk.opacity(0.24))
                    .frame(width: 1.5, height: 520)
                    .offset(x: 48, y: 292)
                ForEach(timelinePlacements) { placement in
                    Circle()
                        .fill(palette.ink.opacity(0.72))
                        .frame(width: 8, height: 8)
                        .offset(
                            x: 44.75,
                            y: CGFloat(placement.frame.y + 10)
                        )
                }
            }
        case .minimal:
            Path { path in
                path.move(to: CGPoint(x: 286, y: 72))
                path.addLine(to: CGPoint(x: 520, y: 28))
                path.addLine(to: CGPoint(x: 520, y: 352))
                path.addLine(to: CGPoint(x: 356, y: 386))
                path.closeSubpath()
            }
            .fill(palette.mutedInk.opacity(0.055))
        case .postcard:
            ZStack(alignment: .topLeading) {
                Circle()
                    .stroke(palette.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                    .frame(width: 70, height: 70)
                    .offset(x: 420, y: 44)
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(palette.mutedInk.opacity(0.16))
                        .frame(width: 154, height: 1)
                        .offset(x: 32, y: 662 + CGFloat(index) * 28)
                }
            }
        case .scrapbook:
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.paper.opacity(0.58))
                    .frame(width: 108, height: 22)
                    .rotationEffect(.degrees(-8))
                    .offset(x: 276, y: 236)
                Rectangle()
                    .fill(palette.paper.opacity(0.52))
                    .frame(width: 92, height: 20)
                    .rotationEffect(.degrees(6))
                    .offset(x: 52, y: 592)
            }
        case .editorial:
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.ink.opacity(0.20))
                    .frame(width: 1, height: 508)
                    .offset(x: 358, y: 294)
                Rectangle()
                    .fill(palette.ink.opacity(0.56))
                    .frame(width: 142, height: 2)
                    .offset(x: 366, y: 270)
            }
        case .memoryWall:
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(palette.mutedInk.opacity(0.10), lineWidth: 1)
                    .frame(width: 492, height: 620)
                    .offset(x: 24, y: 204)
                Circle()
                    .fill(palette.ink.opacity(0.12))
                    .frame(width: 94, height: 94)
                    .offset(x: 398, y: 96)
            }
        case .travelNote:
            Path { path in
                path.move(to: CGPoint(x: 92, y: 302))
                path.addCurve(
                    to: CGPoint(x: 118, y: 590),
                    control1: CGPoint(x: 20, y: 390),
                    control2: CGPoint(x: 176, y: 488)
                )
            }
            .stroke(palette.ink.opacity(0.22), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 8]))
        case .bookCover:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(palette.ink.opacity(0.18), lineWidth: 1)
                .frame(width: 404, height: 812)
                .offset(x: 68, y: 24)
        case .natureDiary:
            ZStack(alignment: .topLeading) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(palette.mutedInk.opacity(0.06 + Double(index) * 0.018))
                        .frame(width: 52, height: 116)
                        .rotationEffect(.degrees(Double(index) * 18 - 34))
                        .offset(x: 438 - CGFloat(index) * 26, y: 54 + CGFloat(index) * 26)
                }
            }
        case .coffeeStory:
            ZStack(alignment: .topLeading) {
                Circle()
                    .stroke(palette.ink.opacity(0.12), lineWidth: 12)
                    .frame(width: 116, height: 116)
                    .offset(x: 400, y: 92)
                Circle()
                    .stroke(palette.ink.opacity(0.08), lineWidth: 1)
                    .frame(width: 142, height: 142)
                    .offset(x: 387, y: 79)
            }
        case .warmHome:
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(palette.mutedInk.opacity(0.14), lineWidth: 1)
                    .frame(width: 176, height: 148)
                    .offset(x: 344, y: 48)
                Rectangle()
                    .fill(palette.mutedInk.opacity(0.10))
                    .frame(width: 1, height: 148)
                    .offset(x: 432, y: 48)
            }
        case .nightStory:
            ZStack(alignment: .topLeading) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(palette.paper.opacity(0.08 + Double(index) * 0.025))
                        .frame(width: 420 - CGFloat(index) * 54, height: 2)
                        .offset(x: 60 + CGFloat(index) * 22, y: 812 + CGFloat(index) * 10)
                }
            }
        case .ocean:
            ZStack(alignment: .topLeading) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(palette.mutedInk.opacity(0.06 + Double(index) * 0.018))
                        .frame(width: 360 - CGFloat(index) * 34, height: 3)
                        .offset(x: 90 + CGFloat(index) * 18, y: 820 + CGFloat(index) * 8)
                }
            }
        case .quietEditorial:
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(palette.mutedInk.opacity(0.14))
                    .frame(width: 1, height: 420)
                    .offset(x: 48, y: 144)
                Circle()
                    .fill(palette.mutedInk.opacity(0.06))
                    .frame(width: 240, height: 240)
                    .offset(x: 340, y: 34)
            }
        }
    }

    private var timelinePlacements: [ResolvedCoverAtomPlacement] {
        layout.bodyAtomPlacements.filter { $0.textRole == .timeline }
    }
}

private struct CoverBackgroundTexture: View {
    let family: BackgroundFamily
    let palette: CoverResolvedPalette

    @ViewBuilder
    var body: some View {
        switch family {
        case .morningLight, .sunset:
            LinearGradient(
                colors: [Color.white.opacity(0.20), Color.clear],
                startPoint: .topTrailing,
                endPoint: .center
            )
        case .warmHome, .coffeeTime, .autumn:
            Circle()
                .fill(palette.paper.opacity(0.16))
                .frame(width: 420, height: 420)
                .offset(x: 248, y: -120)
        case .creamPaper, .journal, .paperGray:
            Canvas { context, _ in
                for index in 0..<18 {
                    let y = CGFloat(index) * 54 + 18
                    context.fill(
                        Path(CGRect(x: 0, y: y, width: 540, height: 0.7)),
                        with: .color(palette.mutedInk.opacity(0.035))
                    )
                }
            }
        case .forestDiary, .nature:
            LinearGradient(
                colors: [palette.paper.opacity(0.18), Color.clear, palette.mutedInk.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .travelNote, .postcard:
            Rectangle()
                .stroke(palette.mutedInk.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [5, 9]))
                .padding(20)
        case .nightWalk, .film:
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.clear, Color.black.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .editorial, .bookCover:
            Rectangle()
                .fill(palette.ink.opacity(0.025))
                .frame(width: 186)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .ocean:
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        case .minimal, .quietEditorial, .softUtility:
            Color.clear
        }
    }
}

private struct GlobalFooterRenderer: View {
    let renderInput: PreparedCoverRenderInput
    let palette: CoverResolvedPalette

    var body: some View {
        HStack(spacing: 12) {
            Text(renderInput.footerPresentation.text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let qrCodeImage = renderInput.verifiedQRCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.mutedInk.opacity(0.16))
                .frame(height: 0.8)
        }
        .accessibilityHidden(true)
    }
}

@MainActor
enum CoverExportCoordinator {
    static func renderImage(
        from session: CoverShareSession,
        scale: CGFloat = 2
    ) -> UIImage? {
        let renderInput = session.exportRenderInput
        let renderer = ImageRenderer(
            content: CoverCanvasRoot(renderInput: renderInput)
        )
        renderer.proposedSize = ProposedViewSize(
            width: CGFloat(renderInput.layout.canvasSize.width),
            height: CGFloat(renderInput.layout.canvasSize.height)
        )
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

private struct CoverResolvedPalette {
    let backgroundStart: Color
    let backgroundEnd: Color
    let paper: Color
    let ink: Color
    let mutedInk: Color

    static func resolve(
        _ paletteID: CoverPaletteID,
        dynamicPalette: CoverDynamicPalette?,
        usesImageBackground: Bool
    ) -> CoverResolvedPalette {
        if usesImageBackground {
            return CoverResolvedPalette(
                backgroundStart: Color.black,
                backgroundEnd: Color.black.opacity(0.72),
                paper: Color.white,
                ink: Color.white,
                mutedInk: Color.white.opacity(0.80)
            )
        }
        if let dynamicPalette, dynamicPalette.isValid {
            return CoverResolvedPalette(
                backgroundStart: color(dynamicPalette.backgroundStart),
                backgroundEnd: color(dynamicPalette.backgroundEnd),
                paper: color(dynamicPalette.paper),
                ink: color(dynamicPalette.ink),
                mutedInk: color(dynamicPalette.mutedInk)
            )
        }
        switch paletteID {
        case .creamMorning:
            return palette("F8F5EE", "EEF5F0", "242421", "66635D")
        case .warmBeige:
            return palette("F4EEE5", "E9DDCC", "2D2925", "6E645C")
        case .fogGreen:
            return palette("F3F6F1", "DDE5DD", "263029", "647067")
        case .coffeeBrown:
            return palette("F2E9DE", "D8C7B6", "332A25", "746257")
        case .nightBlue:
            return CoverResolvedPalette(
                backgroundStart: hex("263543"),
                backgroundEnd: hex("17232D"),
                paper: hex("E8EDF0"),
                ink: Color.white.opacity(0.94),
                mutedInk: Color.white.opacity(0.70)
            )
        case .paperGray:
            return palette("F4F2EE", "E7E4DE", "282724", "68655F")
        case .oceanBlue:
            return palette("EDF3F5", "CBDCE2", "24343B", "617780")
        case .quietCream:
            return palette("FBF8F1", "F2EEE5", "262522", "706C65")
        }
    }

    private static func palette(
        _ start: String,
        _ end: String,
        _ ink: String,
        _ muted: String
    ) -> CoverResolvedPalette {
        CoverResolvedPalette(
            backgroundStart: hex(start),
            backgroundEnd: hex(end),
            paper: hex("FFFDF7"),
            ink: hex(ink),
            mutedInk: hex(muted)
        )
    }

    private static func hex(_ value: String) -> Color {
        var parsed: UInt64 = 0
        Scanner(string: value).scanHexInt64(&parsed)
        return Color(
            red: Double((parsed >> 16) & 0xFF) / 255,
            green: Double((parsed >> 8) & 0xFF) / 255,
            blue: Double(parsed & 0xFF) / 255
        )
    }

    private static func color(_ value: CoverRGBA) -> Color {
        Color(
            red: value.red,
            green: value.green,
            blue: value.blue,
            opacity: value.alpha
        )
    }
}
