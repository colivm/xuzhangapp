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
    let reason: PhotoMemoryPromptReason?
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
                Text(reason?.title ?? "已放进账本")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text(reason?.detail ?? "需要时再补一张图，不用每笔都加。")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            memoryRecordSummary

            VStack(spacing: 10) {
                Button(action: onAddImage) {
                    Label(reason?.actionTitle ?? "留张记忆图", systemImage: "photo.on.rectangle")
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
                    Text("先不加")
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
                if let reason {
                    Text(reason.sceneLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppColors.accent.opacity(0.10))
                        )
                }
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

struct MemoryPreviewSheet: View {
    let item: HomeItem
    let imageDatas: [Data]
    let onConfirm: (Int) -> Void
    let onReselect: () -> Void
    @State private var selectedCoverIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        ZStack(alignment: .topLeading) {
                            if imageDatas.indices.contains(selectedCoverIndex) {
                                MemoryAttachmentThumbnail(
                                    imageData: imageDatas[selectedCoverIndex],
                                    height: 312,
                                    cornerRadius: 22
                                )
                            }

                            Label("代表这笔", systemImage: "sparkle")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Capsule(style: .continuous).fill(Color.black.opacity(0.30)))
                                .padding(12)
                        }

                        if imageDatas.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(imageDatas.enumerated()), id: \.offset) { pair in
                                        Button {
                                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                                selectedCoverIndex = pair.offset
                                            }
                                        } label: {
                                            MemoryAttachmentThumbnail(imageData: pair.element, height: 58, cornerRadius: 12)
                                                .frame(width: 58)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(pair.offset == selectedCoverIndex ? AppColors.accent : Color.white.opacity(0.55), lineWidth: pair.offset == selectedCoverIndex ? 2 : 1)
                                                )
                                                .overlay(alignment: .topTrailing) {
                                                    if pair.offset == selectedCoverIndex {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .font(.system(size: 17, weight: .bold))
                                                            .foregroundStyle(AppColors.accent)
                                                            .background(Circle().fill(.white))
                                                            .offset(x: 5, y: -5)
                                                    }
                                                }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Text("选一张最能代表这笔的图，复盘里会优先用这一张。")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                    }

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

                    Text("确认后，主图会成为这笔账的记忆锚点，其他图片先收在这笔里。")
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
                    Button {
                        onConfirm(selectedCoverIndex)
                    } label: {
                        Text("留下这张")
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

struct MemoryRecordDetailSheet: View {
    let item: HomeItem
    let onSave: (HomeItem) -> Bool
    let onAddImages: () -> Void
    let onRemoveImage: (Int) -> Void
    let onSetCoverImage: (Int) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImageIndex = 0
    @State private var imageExpanded = false
    @State private var amountText: String
    @State private var titleText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
    @State private var categoryPanelExpanded = false
    @State private var datePanelExpanded = false
    @State private var validationMessage: String?
    @State private var savedAmount: Double
    @State private var savedTitle: String
    @State private var savedCategory: HomeItem.Category
    @State private var savedDate: Date
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isNoteFocused: Bool

    init(
        item: HomeItem,
        onSave: @escaping (HomeItem) -> Bool,
        onAddImages: @escaping () -> Void,
        onRemoveImage: @escaping (Int) -> Void,
        onSetCoverImage: @escaping (Int) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.onSave = onSave
        self.onAddImages = onAddImages
        self.onRemoveImage = onRemoveImage
        self.onSetCoverImage = onSetCoverImage
        self.onDelete = onDelete
        _amountText = State(initialValue: String(format: "%.2f", item.amount))
        _titleText = State(initialValue: item.hasMeaningfulTitle ? item.title : "")
        _selectedCategory = State(initialValue: item.category)
        _selectedDate = State(initialValue: item.createdAt)
        _savedAmount = State(initialValue: item.amount)
        _savedTitle = State(initialValue: item.title)
        _savedCategory = State(initialValue: item.category)
        _savedDate = State(initialValue: item.createdAt)
    }

    private var memoryImages: [Data] {
        item.memoryImages
    }

    private var selectedImageDisplayIndex: Int {
        min(selectedImageIndex + 1, max(memoryImages.count, 1))
    }

    private var selectedImageIsCover: Bool {
        item.normalizedCoverMemoryImageIndex == selectedImageIndex
    }

    private var canAddMoreImages: Bool {
        memoryImages.count < 9
    }

    private var cleanTitle: String {
        titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var effectiveAmount: Double {
        parsedAmount > 0 ? parsedAmount : item.amount
    }

    private var draftTitle: String {
        cleanTitle.isEmpty ? selectedCategory.defaultRecordTitle : cleanTitle
    }

    private var draftDisplayTitle: String {
        cleanTitle.isEmpty ? "\(selectedCategory.rawValue) \(selectedDate.zhBillTime)" : cleanTitle
    }

    private var draftEmotionTag: String {
        RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: draftTitle,
                fallbackCategory: selectedCategory,
                amount: effectiveAmount,
                date: selectedDate,
                merchantBrandId: item.merchantBrandId,
                categoryLockedByUser: selectedCategory != item.category || item.userEditedCategory == true,
                userEditedTitle: item.userEditedTitle == true || draftTitle != item.title,
                source: "memory_detail"
            )
        ).emotionTag
    }

    private var hasDraftChanges: Bool {
        abs(parsedAmount - savedAmount) >= 0.005
            || draftTitle != savedTitle
            || selectedCategory != savedCategory
            || abs(selectedDate.timeIntervalSince(savedDate)) >= 1
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    memoryHeroSection

                    VStack(alignment: .leading, spacing: 10) {
                        Text("记忆图")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.text)

                        memoryImageManager
                    }
                    .padding(.top, imageExpanded ? 12 : 2)

                }
                .padding(18)
                .padding(.bottom, 26)
            }
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("消费详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        closeDetail()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.red.opacity(0.82))
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.96), .large])
        .presentationDragIndicator(.hidden)
        .onChange(of: isNoteFocused) { oldValue, newValue in
            if oldValue && !newValue {
                saveDraftChanges()
            }
        }
        .onChange(of: isAmountFocused) { oldValue, newValue in
            if oldValue && !newValue {
                saveDraftChanges()
            }
        }
        .onChange(of: memoryImages.count) { _, count in
            if selectedImageIndex >= count {
                selectedImageIndex = max(0, count - 1)
            }
        }
    }

    @ViewBuilder
    private var memoryHeroSection: some View {
        VStack(spacing: 0) {
            memoryImageLayer(height: imageExpanded ? 430 : 330, fitMode: imageExpanded)

            memoryDetailSummary
                .offset(y: imageExpanded ? -8 : -62)
                .padding(.bottom, imageExpanded ? 18 : -44)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: imageExpanded)
    }

    @ViewBuilder
    private func memoryImageLayer(height: CGFloat, fitMode: Bool) -> some View {
        if !memoryImages.isEmpty {
            ZStack(alignment: .topTrailing) {
                TabView(selection: $selectedImageIndex) {
                    ForEach(Array(memoryImages.enumerated()), id: \.offset) { pair in
                        memoryHeroImage(imageData: pair.element, height: height, fitMode: fitMode)
                            .padding(.horizontal, 1)
                            .tag(pair.offset)
                    }
                }
                .frame(height: height)
                .tabViewStyle(.page(indexDisplayMode: memoryImages.count > 1 ? .automatic : .never))
                .shadow(color: AppColors.subtext.opacity(0.18), radius: 24, x: 0, y: 14)
                .shadow(color: Color.white.opacity(0.30), radius: 8, x: -2, y: -2)
                .onTapGesture {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        imageExpanded.toggle()
                    }
                }

                HStack(spacing: 5) {
                    Text(selectedImageIsCover ? "主图 \(selectedImageDisplayIndex)/\(memoryImages.count)" : "\(selectedImageDisplayIndex)/\(memoryImages.count)")
                    Image(systemName: imageExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(Color.black.opacity(0.26)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, imageExpanded ? 18 : 78)
                .accessibilityLabel(imageExpanded ? "收起图片" : "展开图片")
            }
        }
    }

    @ViewBuilder
    private func memoryHeroImage(imageData: Data, height: CGFloat, fitMode: Bool) -> some View {
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: fitMode ? .fit : .fill)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.54))
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.62), lineWidth: 1)
                )
        } else {
            MemoryAttachmentThumbnail(imageData: imageData, height: height, cornerRadius: 24)
        }
    }

    private var memoryImageManager: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(memoryImages.enumerated()), id: \.offset) { pair in
                        Button {
                            selectedImageIndex = pair.offset
                        } label: {
                            MemoryAttachmentThumbnail(imageData: pair.element, height: 62, cornerRadius: 13)
                                .frame(width: 62)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(pair.offset == selectedImageIndex ? AppColors.accent : Color.clear, lineWidth: 2)
                                        .padding(1)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if pair.offset == item.normalizedCoverMemoryImageIndex {
                                        Image(systemName: "sparkle")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 18, height: 18)
                                            .background(Circle().fill(AppColors.accent.opacity(0.92)))
                                            .offset(x: 4, y: -4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }

                    if canAddMoreImages {
                        Button(action: onAddImages) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                Text("补一张")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 62, height: 62)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color.white.opacity(0.64))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(AppColors.accent.opacity(0.20), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                            Text("已满")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(AppColors.tertiary)
                        .frame(width: 62, height: 62)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.white.opacity(0.46))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color.white.opacity(0.34), lineWidth: 1)
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 10) {
                Button {
                    onSetCoverImage(selectedImageIndex)
                } label: {
                    Label(selectedImageIsCover ? "已是主图" : "设为主图", systemImage: selectedImageIsCover ? "checkmark.circle.fill" : "sparkle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedImageIsCover ? AppColors.accent.opacity(0.82) : AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Color.white.opacity(0.62))
                        )
                }
                .buttonStyle(.plain)
                .disabled(memoryImages.isEmpty || selectedImageIsCover)

                Button(role: .destructive) {
                    onRemoveImage(selectedImageIndex)
                } label: {
                    Text("删除")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.78))
                        .frame(width: 76)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(Color.white.opacity(0.62))
                        )
                }
                .buttonStyle(.plain)
                .disabled(memoryImages.isEmpty)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.56))
        )
    }

    private var memoryDetailSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(draftDisplayTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 10)

                HStack(spacing: 2) {
                    Text("¥")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($isAmountFocused)
                        .submitLabel(.done)
                        .onSubmit { saveDraftChanges() }
                        .onChange(of: amountText) { _, value in
                            if value.count > 10 {
                                amountText = String(value.prefix(10))
                            }
                            validationMessage = nil
                        }
                }
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .frame(width: 116)
            }

            TextField("未填写备注", text: $titleText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(cleanTitle.isEmpty ? 0.54 : 0.86))
                .focused($isNoteFocused)
                .submitLabel(.done)
                .onSubmit { saveDraftChanges() }
                .onChange(of: titleText) { _, value in
                    if value.count > 32 {
                        titleText = String(value.prefix(32))
                    }
                    validationMessage = nil
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.54))
                )
                .contentShape(Rectangle())

            VStack(spacing: 10) {
                Button {
                    isNoteFocused = false
                    withAnimation(.easeInOut(duration: 0.18)) {
                        categoryPanelExpanded.toggle()
                        datePanelExpanded = false
                    }
                } label: {
                    memoryDetailInfoRow("分类", value: selectedCategory.rawValue, systemImage: MemoryAttachmentVisuals.categorySystemImage(selectedCategory), showsChevron: true)
                }
                .buttonStyle(.plain)

                if categoryPanelExpanded {
                    memoryCategoryGrid
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    isNoteFocused = false
                    withAnimation(.easeInOut(duration: 0.18)) {
                        datePanelExpanded.toggle()
                        categoryPanelExpanded = false
                    }
                } label: {
                    memoryDetailInfoRow("时间", value: selectedDate.zhBillDateTime, systemImage: "clock", showsChevron: true)
                }
                .buttonStyle(.plain)

                if datePanelExpanded {
                    WarmRecordDatePanel(selection: $selectedDate) {
                        saveDraftChanges()
                    }
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                memoryDetailInfoRow("记忆", value: draftEmotionTag, systemImage: "sparkles")
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.72))
                    .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.82))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.76), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.12), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 8)
        .padding(.bottom, 18)
    }

    private var memoryCategoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74, maximum: 118), spacing: 8)], spacing: 8) {
            ForEach(HomeItem.Category.allCases) { category in
                Button {
                    selectedCategory = category
                    validationMessage = nil
                    withAnimation(.easeInOut(duration: 0.16)) {
                        categoryPanelExpanded = false
                    }
                    saveDraftChanges()
                } label: {
                    Text(category.rawValue)
                        .font(.system(size: 13, weight: selectedCategory == category ? .bold : .medium))
                        .foregroundStyle(selectedCategory == category ? AppColors.text : AppColors.subtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedCategory == category ? AppColors.accent.opacity(0.16) : Color.white.opacity(0.54))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func memoryDetailInfoRow(_ title: String, value: String, systemImage: String, showsChevron: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 28, height: 28)
                .background(Circle().fill(AppColors.accent.opacity(0.10)))

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.subtext)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColors.tertiary)
            }
        }
    }

    @discardableResult
    private func saveDraftChanges() -> Bool {
        guard hasDraftChanges else {
            validationMessage = nil
            return true
        }
        var updated = item
        guard parsedAmount > 0 else {
            validationMessage = "金额需要大于 0。"
            return false
        }
        updated.amount = parsedAmount
        updated.title = draftTitle
        updated.category = selectedCategory
        updated.createdAt = selectedDate
        updated.updatedAt = Date()
        let didSave = onSave(updated)
        if didSave {
            savedAmount = parsedAmount
            savedTitle = draftTitle
            savedCategory = selectedCategory
            savedDate = selectedDate
        }
        validationMessage = didSave ? nil : "这句备注里可能有隐私信息，先改成更简单的记录。"
        return didSave
    }

    private func closeDetail() {
        if saveDraftChanges() {
            dismiss()
        }
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
