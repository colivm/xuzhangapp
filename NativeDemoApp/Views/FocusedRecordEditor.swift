import Foundation
import PhotosUI
import SwiftUI

struct FocusedRecordEditor: View {
    let item: HomeItem
    var autoCommitRequestID: UUID?
    var onSave: (HomeItem) -> Bool
    var onCancel: () -> Void
    var onDelete: () -> Void
    var onAttachMemoryImage: (() -> Void)?
    var onAttachMemoryImages: (([Data]) -> Bool)?

    @State private var amountText: String
    @State private var noteText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
    @State private var mode: EditorMode = .editing
    @State private var isDatePanelVisible = false
    @State private var validationMessage: String?
    @State private var showPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var didAttachMemoryImage = false
    @State private var showDeleteConfirmation = false
    @FocusState private var focusedField: FocusedField?

    private enum EditorMode {
        case editing
        case categoryPicking
    }

    private enum FocusedField {
        case amount
        case note
    }

    init(
        item: HomeItem,
        autoCommitRequestID: UUID? = nil,
        onSave: @escaping (HomeItem) -> Bool,
        onCancel: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onAttachMemoryImage: (() -> Void)? = nil,
        onAttachMemoryImages: (([Data]) -> Bool)? = nil
    ) {
        self.item = item
        self.autoCommitRequestID = autoCommitRequestID
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        self.onAttachMemoryImage = onAttachMemoryImage
        self.onAttachMemoryImages = onAttachMemoryImages
        _amountText = State(initialValue: String(format: "%.2f", item.amount))
        _noteText = State(initialValue: item.hasMeaningfulTitle ? item.title : "")
        _selectedCategory = State(initialValue: item.category)
        _selectedDate = State(initialValue: item.createdAt)
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var cleanNote: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var accent: Color {
        AppColors.accent
    }

    private var categoryAccent: Color {
        AppColors.categoryColor(selectedCategory)
    }

    private var draftDisplayTitle: String {
        cleanNote.isEmpty ? "\(selectedCategory.rawValue) \(selectedDate.zhBillTime)" : cleanNote
    }

    var body: some View {
        ZStack {
            if mode == .editing {
                editCard
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                categoryPickerCard
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(editorSpring, value: mode)
        .animation(editorSpring, value: isDatePanelVisible)
        .onChange(of: autoCommitRequestID) { _, requestID in
            guard requestID != nil else { return }
            save()
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: photoPickerSelectionLimit,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotos) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                var compressedImages: [Data] = []
                for photo in newValue.prefix(photoPickerSelectionLimit) {
                    if let data = try? await photo.loadTransferable(type: Data.self),
                       let compressedData = MemoryImageCompressor.compressedJPEGData(from: data) {
                        compressedImages.append(compressedData)
                    }
                }
                await MainActor.run {
                    selectedPhotos = []
                    guard !compressedImages.isEmpty else { return }
                    if onAttachMemoryImages?(compressedImages) == true {
                        didAttachMemoryImage = true
                    } else {
                        onAttachMemoryImage?()
                    }
                }
            }
        }
        .confirmationDialog(
            "删除这条账单？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不会保留在账本里。")
        }
    }

    private var editCard: some View {
        VStack(spacing: 0) {
            headerControls

            VStack(spacing: 9) {
                categoryAvatar

                Text(draftDisplayTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                amountEditor

                if !item.displayEmotionTag.isEmpty {
                    Text(item.displayEmotionTag)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))
                }

                Text(selectedCategory.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.subtext)
            }
            .padding(.top, 2)
            .padding(.bottom, 22)

            VStack(spacing: 8) {
                editorActionRow(
                    icon: MemoryAttachmentVisuals.categorySystemImage(selectedCategory),
                    title: "分类",
                    value: selectedCategory.rawValue,
                    isAccent: true
                ) {
                    focusedField = nil
                    isDatePanelVisible = false
                    withAnimation(editorSpring) {
                        mode = .categoryPicking
                    }
                }

                noteRow

                editorActionRow(
                    icon: "clock",
                    title: "时间",
                    value: selectedDate.zhBillDateTime,
                    isAccent: false
                ) {
                    focusedField = nil
                    withAnimation(editorSpring) {
                        isDatePanelVisible.toggle()
                    }
                }

                if isDatePanelVisible {
                    WarmRecordDatePanel(selection: $selectedDate)
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }

            Button {
                save()
            } label: {
                Text("保存")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(saveButtonBackground)
            }
            .buttonStyle(.plain)
            .disabled(parsedAmount <= 0)
            .opacity(parsedAmount <= 0 ? 0.54 : 1)
            .padding(.top, 18)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(editorCardBackground)
        .overlay(editorCardBorder)
        .shadow(color: AppColors.subtext.opacity(0.17), radius: 26, x: 0, y: 18)
        .shadow(color: accent.opacity(0.10), radius: 18, x: 0, y: 10)
        .scaleEffect(1.012, anchor: .top)
    }

    private var categoryPickerCard: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(editorSpring) {
                        mode = .editing
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(AppColors.panelStrong.opacity(0.76)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭分类选择")

                Spacer()

                Text("选择分类")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.text)

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.bottom, 12)

            VStack(spacing: 2) {
                ForEach(HomeItem.Category.allCases) { category in
                    categoryPickerRow(category)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(editorCardBackground)
        .overlay(editorCardBorder)
        .shadow(color: AppColors.subtext.opacity(0.15), radius: 24, x: 0, y: 15)
        .scaleEffect(1.01, anchor: .top)
    }

    private var headerControls: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppColors.panelStrong.opacity(0.76)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭记录编辑")

            Spacer()

            Capsule(style: .continuous)
                .fill(AppColors.line.opacity(0.55))
                .frame(width: 38, height: 4)
                .opacity(0.74)

            Spacer()

            HStack(spacing: 8) {
                if canAttachMemoryImage {
                    Menu {
                        Button {
                            attachMemoryImage()
                        } label: {
                            Label("补充图片", systemImage: "photo.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(AppColors.panelStrong.opacity(0.76)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("更多")
                    .accessibilityHint("补充这条记录的图片")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(AppColors.panelStrong.opacity(0.76)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除记录")
            }
        }
    }

    private var canAttachMemoryImage: Bool {
        !item.hasMemoryImages && !didAttachMemoryImage && (onAttachMemoryImages != nil || onAttachMemoryImage != nil)
    }

    private var photoPickerSelectionLimit: Int {
        max(1, 9 - item.memoryImageCount)
    }

    private func attachMemoryImage() {
        if onAttachMemoryImages != nil {
            showPhotoPicker = true
        } else {
            onAttachMemoryImage?()
        }
    }

    private var categoryAvatar: some View {
        ZStack {
            Circle()
                .fill(categoryAccent.opacity(0.14))
                .frame(width: 68, height: 68)
            Circle()
                .fill(AppColors.panelStrong.opacity(0.84))
                .frame(width: 54, height: 54)
                .shadow(color: categoryAccent.opacity(0.14), radius: 12, x: 0, y: 6)
            Image(systemName: MemoryAttachmentVisuals.categorySystemImage(selectedCategory))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(categoryAccent)
        }
        .padding(.top, -2)
    }

    private var amountEditor: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("¥")
                .font(.system(size: 27, weight: .bold, design: .rounded))
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .focused($focusedField, equals: .amount)
                .onChange(of: amountText) { _, value in
                    amountText = sanitizedAmountText(value)
                    validationMessage = nil
                }
                .frame(width: max(94, min(178, CGFloat(amountText.count) * 19 + 42)))
        }
        .foregroundStyle(AppColors.text)
        .padding(.top, 1)
    }

    private var noteRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.subtext)
                .frame(width: 20)

            Text("备注")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.subtext)

            TextField("这一笔想怎么被记住？", text: $noteText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .note)
                .onChange(of: noteText) { _, value in
                    if value.count > 32 {
                        noteText = String(value.prefix(32))
                    }
                    validationMessage = nil
                }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(editorRowBackground)
    }

    private func editorActionRow(
        icon: String,
        title: String,
        value: String,
        isAccent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isAccent ? categoryAccent : AppColors.subtext)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.subtext)

                Spacer(minLength: 12)

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(editorRowBackground)
        }
        .buttonStyle(.plain)
    }

    private func categoryPickerRow(_ category: HomeItem.Category) -> some View {
        let isSelected = selectedCategory == category
        let rowAccent = AppColors.categoryColor(category)
        return Button {
            selectedCategory = category
            validationMessage = nil
            withAnimation(editorSpring) {
                mode = .editing
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: MemoryAttachmentVisuals.categorySystemImage(category))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(rowAccent)
                    .frame(width: 28)

                Text(category.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(AppColors.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.11) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var editorCardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppColors.panelStrong.opacity(0.88))
            )
            .overlay(
                LinearGradient(
                    colors: [
                        AppColors.monthlyInsightBg.opacity(0.52),
                        AppColors.panelStrong.opacity(0.42),
                        accent.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var editorCardBorder: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        AppColors.panelStrong.opacity(0.68),
                        accent.opacity(0.22),
                        AppColors.stroke.opacity(0.36)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }

    private var editorRowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppColors.panelStrong.opacity(0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.stroke.opacity(0.34), lineWidth: 0.8)
            )
    }

    private var saveButtonBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.92),
                        AppColors.accentDark.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: accent.opacity(0.28), radius: 14, x: 0, y: 7)
    }

    private var editorSpring: Animation {
        .spring(response: 0.34, dampingFraction: 0.90, blendDuration: 0.06)
    }

    private func save() {
        focusedField = nil
        guard parsedAmount > 0 else {
            validationMessage = "金额先留在这里，补完整再保存。"
            return
        }
        var updated = item
        updated.amount = parsedAmount
        updated.title = cleanNote.isEmpty ? selectedCategory.defaultRecordTitle : cleanNote
        updated.category = selectedCategory
        updated.createdAt = selectedDate
        updated.updatedAt = Date()
        if !onSave(updated) {
            validationMessage = "这句备注里可能有隐私信息，先改成更简单的记录。"
        }
    }

    private func sanitizedAmountText(_ value: String) -> String {
        var output = ""
        var hasDecimalPoint = false
        var decimalCount = 0
        for character in value {
            if character == "." {
                guard !hasDecimalPoint else { continue }
                hasDecimalPoint = true
                output.append(character)
            } else if character.isNumber {
                if hasDecimalPoint {
                    guard decimalCount < 2 else { continue }
                    decimalCount += 1
                }
                output.append(character)
            }
        }
        if output.count > 10 {
            output = String(output.prefix(10))
        }
        return output
    }

}
