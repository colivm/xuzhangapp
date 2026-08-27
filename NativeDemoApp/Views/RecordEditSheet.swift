import Foundation
import PhotosUI
import SwiftUI

enum RecordEditCategoryMutationPolicy {
    static func titleAfterSelectingCategory(
        currentTitle: String,
        category _: HomeItem.Category
    ) -> String {
        currentTitle
    }
}

struct RecordEditSheet: View {
    let item: HomeItem
    var onSave: (HomeItem) -> Bool
    var onDelete: () -> Void
    var onAttachMemoryImage: (() -> Void)?
    var onAttachMemoryImages: (([Data]) -> Bool)?

    @State private var amountText: String
    @State private var titleText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
    @State private var noteEditorExpanded = false
    @State private var categoryPanelExpanded = false
    @State private var datePanelExpanded = false
    @State private var safetyMessage: String?
    @State private var showEditPhotoPicker = false
    @State private var selectedEditPhotos: [PhotosPickerItem] = []
    @State private var didAttachMemoryImage = false
    @State private var showDeleteConfirmation = false
    @FocusState private var isNoteFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(
        item: HomeItem,
        onSave: @escaping (HomeItem) -> Bool,
        onDelete: @escaping () -> Void,
        onAttachMemoryImage: (() -> Void)? = nil,
        onAttachMemoryImages: (([Data]) -> Bool)? = nil
    ) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        self.onAttachMemoryImage = onAttachMemoryImage
        self.onAttachMemoryImages = onAttachMemoryImages
        _amountText = State(initialValue: String(format: "%.2f", item.amount))
        _titleText = State(initialValue: item.title)
        _selectedCategory = State(initialValue: item.category)
        _selectedDate = State(initialValue: item.createdAt)
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var cleanTitle: String {
        titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewTitle: String {
        cleanTitle.isEmpty ? selectedCategory.defaultRecordTitle : cleanTitle
    }

    private var previewEmotion: String {
        if editFieldsUnchanged {
            return item.displayEmotionTag
        }
        return editPreviewResolution.emotionTag
    }

    private var editFieldsUnchanged: Bool {
        abs(parsedAmount - item.amount) < 0.005
            && cleanTitle == item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            && selectedCategory == item.category
            && abs(selectedDate.timeIntervalSince(item.createdAt)) < 1
    }

    private var editPreviewResolution: RecordDraftResolution {
        let title = cleanTitle.isEmpty ? selectedCategory.defaultRecordTitle : cleanTitle
        let matchedBrand = MerchantBrandCatalog.matchBrand(in: title)
        let categoryOverridesBrand = matchedBrand.map { selectedCategory != $0.category } ?? false
        // 用户改了标题时，判断旧品牌是否仍匹配新标题；不匹配就清掉，避免沿用旧品牌文案/分类。
        let userEdited = title != item.title
        let oldBrandId = userEdited ? item.merchantBrandId : nil
        let oldBrandStillMatches: Bool = {
            guard let oldBrandId, let oldBrand = MerchantBrandCatalog.definition(for: oldBrandId) else { return false }
            return MerchantBrandCatalog.matchBrand(in: title)?.id == oldBrand.id
        }()
        let effectiveBrandId: String?
        if userEdited, !oldBrandStillMatches {
            effectiveBrandId = nil
        } else {
            effectiveBrandId = matchedBrand?.id ?? item.merchantBrandId
        }
        return RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: title,
                fallbackCategory: selectedCategory,
                amount: parsedAmount,
                date: selectedDate,
                merchantBrandId: effectiveBrandId,
                categoryLockedByUser: selectedCategory != item.category || categoryOverridesBrand,
                userEditedTitle: userEdited,
                source: "edit_preview"
            )
        )
    }

    private var editContentBottomPadding: CGFloat {
        isNoteFieldFocused ? 340 : 40
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        amountStage
                        editPreviewCard
                        saveButton
                    }
                    .padding(20)
                    .padding(.bottom, editContentBottomPadding)
                }
                .scrollIndicators(.hidden)
                .background(AppColors.bg.ignoresSafeArea())
                .navigationTitle("调整这一笔")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: titleText) { _, newValue in
                    if newValue.count > 32 {
                        titleText = String(newValue.prefix(32))
                        return
                    }
                    safetyMessage = nil
                }
                .onChange(of: noteEditorExpanded) { _, isExpanded in
                    if isExpanded {
                        focusEditNoteField(scrollProxy)
                    } else {
                        isNoteFieldFocused = false
                    }
                }
                .onChange(of: isNoteFieldFocused) { _, isFocused in
                    guard isFocused else { return }
                    scrollEditNoteFieldIntoView(scrollProxy)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        if hasRecordEditMoreActions {
                            Menu {
                                recordEditMoreActions
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .accessibilityLabel("更多")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.82))
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .confirmationDialog(
            "删除这条账单？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不会保留在账本里。")
        }
        .photosPicker(
            isPresented: $showEditPhotoPicker,
            selection: $selectedEditPhotos,
            maxSelectionCount: editPhotoPickerSelectionLimit,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedEditPhotos) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                var compressedImages: [Data] = []
                for photo in newValue.prefix(editPhotoPickerSelectionLimit) {
                    if let data = try? await photo.loadTransferable(type: Data.self),
                       let compressedData = MemoryImageCompressor.compressedJPEGData(from: data) {
                        compressedImages.append(compressedData)
                    }
                }
                await MainActor.run {
                    selectedEditPhotos = []
                    guard !compressedImages.isEmpty else { return }
                    if onAttachMemoryImages?(compressedImages) == true {
                        didAttachMemoryImage = true
                    } else {
                        onAttachMemoryImage?()
                    }
                }
            }
        }
    }

    private var editPhotoPickerSelectionLimit: Int {
        max(1, 9 - item.memoryImageCount)
    }

    private var hasRecordEditMoreActions: Bool {
        canAttachMemoryImageFromEdit
    }

    private var canAttachMemoryImageFromEdit: Bool {
        !item.hasMemoryImages && !didAttachMemoryImage && (onAttachMemoryImages != nil || onAttachMemoryImage != nil)
    }

    @ViewBuilder
    private var recordEditMoreActions: some View {
        if canAttachMemoryImageFromEdit {
            Button {
                attachMemoryImageFromEditMenu()
            } label: {
                Label("补充图片", systemImage: "photo.badge.plus")
            }

        }
    }

    private func attachMemoryImageFromEditMenu() {
        if onAttachMemoryImages != nil {
            showEditPhotoPicker = true
        } else {
            onAttachMemoryImage?()
        }
    }

    private var amountStage: some View {
        HStack(spacing: 4) {
            Text("¥")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.subtext.opacity(0.72))
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.56), lineWidth: 1)
        )
    }

    private var editPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            editPreviewHeader

            Divider().opacity(0.36)

            editPreviewActions

            editPreviewExpandedSections
        }
        .padding(18)
        .background(editPreviewBackground)
        .overlay(editPreviewBorder)
        .shadow(color: AppColors.subtext.opacity(0.09), radius: 16, x: 0, y: 7)
    }

    private var editPreviewHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(previewTitle)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            editPreviewEmotionPill
            editPreviewMetaRow
        }
    }

    private var editPreviewEmotionPill: some View {
        Text(previewEmotion)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColors.accent.opacity(0.95))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(editPreviewEmotionBorder)
    }

    private var editPreviewEmotionBorder: some View {
        Capsule(style: .continuous)
            .stroke(AppColors.accent.opacity(0.28), lineWidth: 1)
    }

    private var editPreviewMetaRow: some View {
        HStack(spacing: 7) {
            Text("\(selectedCategory.displayName) · \(selectedDate.zhBillDateTime)")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
            Button("改") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    categoryPanelExpanded.toggle()
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColors.accent.opacity(0.9))
            .buttonStyle(.plain)
        }
    }

    private var editPreviewActions: some View {
        HStack(spacing: 9) {
            quietLink("自己写一句") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    noteEditorExpanded.toggle()
                }
            }
            Text("|").foregroundStyle(AppColors.subtext.opacity(0.32))
            quietLink(selectedDate.zhBillDateTime) {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) {
                    datePanelExpanded.toggle()
                }
            }
            Spacer()
            Text(parsedAmount.formatted(.cny.precision(.fractionLength(2))))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.subtext.opacity(0.72))
        }
    }

    @ViewBuilder
    private var editPreviewExpandedSections: some View {
        if noteEditorExpanded {
            editPreviewNoteField
        }

        if let safetyMessage {
            Text(safetyMessage)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
                .transition(.opacity)
        }

        if categoryPanelExpanded {
            categoryGrid
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        if datePanelExpanded {
            WarmRecordDatePanel(selection: $selectedDate) {
                dismissKeyboard()
            }
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var editPreviewNoteField: some View {
        TextField("这一笔想怎么被记住？", text: $titleText)
            .focused($isNoteFieldFocused)
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.68))
            )
            .id("recordEditNoteField")
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var editPreviewBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.68))
    }

    private var editPreviewBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.56), lineWidth: 1)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82, maximum: 128), spacing: 8)], spacing: 8) {
            ForEach(HomeItem.Category.allCases) { cat in
                categoryGridButton(cat)
            }
        }
    }

    private func categoryGridButton(_ category: HomeItem.Category) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectCategory(category)
        } label: {
            categoryGridButtonLabel(category, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func categoryGridButtonLabel(_ category: HomeItem.Category, isSelected: Bool) -> some View {
        let weight: Font.Weight = isSelected ? .semibold : .regular
        let foreground: Color = isSelected ? AppColors.text : AppColors.subtext
        return Text(category.displayName)
            .font(.system(size: 13, weight: weight))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(categoryGridButtonBackground(isSelected: isSelected))
            .overlay(categoryGridButtonBorder(isSelected: isSelected))
    }

    private func categoryGridButtonBackground(isSelected: Bool) -> some View {
        let fill = isSelected ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.58)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fill)
    }

    private func categoryGridButtonBorder(isSelected: Bool) -> some View {
        let stroke = isSelected ? AppColors.accent.opacity(0.34) : Color.white.opacity(0.38)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(stroke, lineWidth: 1)
    }

    private func selectCategory(_ category: HomeItem.Category) {
        selectedCategory = category
        titleText = RecordEditCategoryMutationPolicy.titleAfterSelectingCategory(
            currentTitle: titleText,
            category: category
        )
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.18)) {
            categoryPanelExpanded = false
        }
    }

    private func dismissKeyboard() {
        isNoteFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func focusEditNoteField(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            isNoteFieldFocused = true
            scrollEditNoteFieldIntoView(proxy)
        }
    }

    private func scrollEditNoteFieldIntoView(_ proxy: ScrollViewProxy) {
        scrollEditNoteFieldIntoView(proxy, delay: 0.18)
        scrollEditNoteFieldIntoView(proxy, delay: 0.42)
    }

    private func scrollEditNoteFieldIntoView(_ proxy: ScrollViewProxy, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isNoteFieldFocused else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                proxy.scrollTo("recordEditNoteField", anchor: .center)
            }
        }
    }

    private var saveButton: some View {
        Button {
            var updated = item
            updated.amount = parsedAmount
            updated.title = cleanTitle.isEmpty ? selectedCategory.defaultRecordTitle : cleanTitle
            updated.category = selectedCategory
            updated.createdAt = selectedDate
            updated.updatedAt = Date()
            // 用编辑预览解析出的品牌/情绪标签覆盖，确保改了标题后旧品牌绑定被清掉。
            updated.merchantBrandId = editPreviewResolution.merchantBrandId
            updated.emotionTag = editPreviewResolution.emotionTag
            if onSave(updated) {
                dismiss()
            } else {
                safetyMessage = "这句备注里可能有隐私信息，先改成更简单的记录。"
                withAnimation(.easeInOut(duration: 0.16)) {
                    noteEditorExpanded = true
                }
            }
        } label: {
            Text("更新这一笔")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(colors: [AppColors.accent.opacity(0.92), AppColors.accent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: AppColors.accent.opacity(0.22), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(parsedAmount <= 0)
        .opacity(parsedAmount <= 0 ? 0.56 : 1)
    }

    private func quietLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.accent.opacity(0.9))
        }
        .buttonStyle(.plain)
    }

}
