import PhotosUI
import SwiftUI
import UIKit

struct MemoryAttachmentThumbnail: View {
    let imageData: Data
    var height: CGFloat = 120
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                memoryImageFallback
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var memoryImageFallback: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.paperMist, AppColors.paperWarm.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppColors.accent.opacity(0.68))
        }
    }
}

struct MemorySuccessCard: View {
    let item: HomeItem
    let onAddImage: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 58, height: 58)
                Image(systemName: "checkmark")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 6) {
                Text("已放进账本 ✨")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text("为这一笔留下一个回忆。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .multilineTextAlignment(.center)
            }

            memoryRecordSummary

            VStack(spacing: 10) {
                Button(action: onAddImage) {
                    Label("添加图片（可选）", systemImage: "photo.on.rectangle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppColors.accent.opacity(0.92))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    Text("暂不添加")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppColors.panelStrong.opacity(0.94))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.56), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.16), radius: 28, x: 0, y: 18)
    }

    private var memoryRecordSummary: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: MemoryAttachmentVisuals.categorySystemImage(item.category))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.categoryColor(item.category))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.categoryColor(item.category).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                Text("\(item.createdAt.zhBillTime) · \(item.category.rawValue)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
            }

            Spacer(minLength: 8)

            Text(item.amount.formatted(.cny))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.56))
        )
    }
}

struct MemorySourceSheet: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule(style: .continuous)
                .fill(AppColors.line.opacity(0.72))
                .frame(width: 38, height: 4)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("添加图片")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text("图片只是回忆的附件，不会影响这笔记录。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
            }
            .padding(.bottom, 6)

            Button {
                onClose()
            } label: {
                MemorySourceRow(title: "拍照", subtitle: "下一版接入相机权限", systemImage: "camera")
                    .opacity(0.54)
            }
            .buttonStyle(.plain)
            .disabled(true)

            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                MemorySourceRow(title: "从相册选择", subtitle: "仅在这里请求相册访问", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Text("取消")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.subtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .background(AppColors.bg)
    }
}

private struct MemorySourceRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.accent.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
    }
}

struct MemoryPreviewSheet: View {
    let item: HomeItem
    let imageData: Data
    let onConfirm: () -> Void
    let onReselect: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MemoryAttachmentThumbnail(imageData: imageData, height: 300, cornerRadius: 20)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.displayTitle)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppColors.text)
                                .lineLimit(2)
                            Spacer(minLength: 12)
                            Text(item.amount.formatted(.cny))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.text)
                        }

                        Text(item.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            memoryInfoChip(item.category.rawValue, systemImage: MemoryAttachmentVisuals.categorySystemImage(item.category))
                            memoryInfoChip(item.createdAt.zhBillDateTime, systemImage: "clock")
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.66))
                    )

                    Text("确认后，这张图片会作为这笔消费的回忆附件出现在痕迹和今日列表里。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .padding(.horizontal, 2)
                }
                .padding(18)
            }
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("预览")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(action: onConfirm) {
                        Text("关联到消费")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppColors.accent.opacity(0.92))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onReselect) {
                        Text("重新选择")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.subtext)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
            }
        }
    }

    private func memoryInfoChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.accent)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(AppColors.accent.opacity(0.10))
            )
    }
}

enum MemoryAttachmentVisuals {
    static func categorySystemImage(_ category: HomeItem.Category) -> String {
        switch category {
        case .dining: return "fork.knife"
        case .transport: return "bus.fill"
        case .shopping: return "bag.fill"
        case .daily: return "mug.fill"
        case .entertainment: return "film.fill"
        case .lodging: return "bed.double.fill"
        case .health: return "cross.case.fill"
        case .home: return "house.fill"
        case .social: return "gift.fill"
        case .other: return "sparkles"
        }
    }
}

enum MemoryImageCompressor {
    static func compressedJPEGData(from data: Data, maxPixel: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > 0 else { return nil }
        let scale = min(1, maxPixel / longestSide)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
