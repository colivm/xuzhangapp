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

/// The form sends only its actual edits. A fresh ledger row remains the owner of
/// attachments and other fields that can change while an editor is open.
struct RecordEditIntent {
    let baseline: HomeItem
    let categoryIntent: RecordExplicitIntentState
    let amountChanged: Bool
    let titleChanged: Bool
    let dateChanged: Bool
}

enum RecordEditPolicy {
    static func intent(
        baseline: HomeItem,
        amountText: String,
        noteText: String,
        initialNoteText: String,
        date: Date,
        categoryIntent: RecordExplicitIntentState
    ) -> RecordEditIntent {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ""))
        // An untouched two-decimal display must not round a historical value.
        let amountChanged = amountText != String(format: "%.2f", baseline.amount)
            && amount != baseline.amount
        return RecordEditIntent(
            baseline: baseline,
            categoryIntent: categoryIntent,
            amountChanged: amountChanged,
            titleChanged: noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                != initialNoteText.trimmingCharacters(in: .whitespacesAndNewlines),
            dateChanged: date != baseline.createdAt
        )
    }

    static func proposedItem(
        intent: RecordEditIntent,
        amountText: String,
        noteText: String,
        date: Date
    ) -> HomeItem {
        var proposed = intent.baseline
        if intent.amountChanged {
            proposed.amount = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        }
        if intent.titleChanged {
            let title = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            proposed.title = title.isEmpty ? intent.categoryIntent.category.defaultRecordTitle : title
        }
        if intent.dateChanged { proposed.createdAt = date }
        proposed.category = intent.categoryIntent.category
        return proposed
    }

    static func applying(
        _ proposed: HomeItem,
        intent: RecordEditIntent,
        to current: HomeItem
    ) -> HomeItem {
        guard proposed.id == current.id, intent.baseline.id == current.id else { return current }
        var updated = current
        if intent.amountChanged { updated.amount = proposed.amount }
        if intent.titleChanged {
            updated.title = proposed.title
            updated.userEditedTitle = true
        }
        if intent.dateChanged { updated.createdAt = proposed.createdAt }
        let newCategoryDecision = (intent.categoryIntent.categoryWasSelectedByUser
            && intent.categoryIntent.categorySelectionRevision != nil)
            || (intent.categoryIntent.categorySource == .handwritten
                && intent.categoryIntent.handwrittenRevision != nil)
        if newCategoryDecision {
            updated.category = intent.categoryIntent.category
            if intent.categoryIntent.categoryWasSelectedByUser {
                updated.userEditedCategory = true
                if updated.category != current.category {
                    updated.categoryCorrectionFrom = current.category
                }
            } else if intent.categoryIntent.categorySource == .handwritten {
                updated.userEditedCategory = nil
                updated.categoryCorrectionFrom = nil
            }
        }
        let factsChanged = updated.title != current.title
            || updated.category != current.category
            || updated.amount != current.amount
            || updated.createdAt != current.createdAt
        // Selecting the existing category changes provenance only. Opening and
        // closing a form does not reset a chosen emotion or recalculate metadata.
        guard factsChanged else { return updated }

        if updated.category != current.category { updated.scenePackId = nil }
        let matchedBrand = MerchantBrandCatalog.matchBrand(in: updated.title)
        let brandID = intent.titleChanged ? matchedBrand?.id : (matchedBrand?.id ?? current.merchantBrandId)
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: updated.title, fallbackCategory: updated.category,
                amount: updated.amount, date: updated.createdAt,
                merchantBrandId: brandID,
                categoryLockedByUser: updated.userEditedCategory == true,
                userEditedTitle: true, source: "edit",
                scenePackId: updated.scenePackId,
                categoryIsSettled: true,
                preserveConfirmedTitle: true,
                manualNoteAnchor: updated.userEditedTitle == true ? updated.title : nil
            )
        )
        // All editor text is confirmed existing text or a committed user edit.
        // Keep it without turning existing generated text into handwritten data.
        updated.title = resolution.title
        updated.merchantBrandId = resolution.merchantBrandId
        let hasConflict = updated.userEditedTitle == true && RecordExplicitIntentPolicy.hasCategoryConflict(
            note: updated.title, category: updated.category
        )
        updated.emotionTag = hasConflict ? "" : RecordMemoryContextService.enhancedEmotionTag(
            input: RecordMemoryContextInput(
                title: updated.title, category: updated.category,
                amount: updated.amount, date: updated.createdAt,
                baseEmotionTag: resolution.emotionTag,
                weather: storedWeather(from: updated.memoryContext, date: updated.createdAt)
            )
        )
        updated = PhotoMemoryPromptPolicy.refreshedAutomaticAnchorMetadata(original: current, updated: updated)
        if !hasConflict, let trusted = TrustedUserMomentNarrativePolicy.emotionTag(for: updated) {
            updated.emotionTag = trusted
        }
        return updated
    }

    private static func storedWeather(from context: HomeItem.MemoryContext?, date: Date) -> WeatherSnapshot? {
        guard let context else { return nil }
        let code: Int? = context.weatherKind == "rain" ? 61 : context.weatherKind == "snow" ? 71 : nil
        guard code != nil || context.temperatureCelsius != nil else { return nil }
        return WeatherSnapshot(temp: context.temperatureCelsius, weatherCode: code, ts: date)
    }
}

struct RecordEditSheet: View {
    let item: HomeItem
    var onSave: (HomeItem, RecordEditIntent) -> Bool
    var onDelete: () -> Void
    var onAttachMemoryImage: (() -> Void)?
    var onAttachMemoryImages: (([Data]) -> Bool)?

    @State private var amountText: String
    @State private var titleText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
    @State private var initialBaseline: HomeItem
    @State private var categoryIntent: RecordExplicitIntentState
    @State private var noteEditorExpanded = false
    @State private var categoryPanelExpanded = false
    @State private var datePanelExpanded = false
    @State private var safetyMessage: String?
    @State private var showEditPhotoPicker = false
    @State private var selectedEditPhotos: [PhotosPickerItem] = []
    @State private var didAttachMemoryImage = false
    @State private var showDeleteConfirmation = false
    @State private var isNoteFieldFocused = false
    @Environment(\.dismiss) private var dismiss

    init(
        item: HomeItem,
        onSave: @escaping (HomeItem, RecordEditIntent) -> Bool,
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
        _initialBaseline = State(initialValue: item)
        _categoryIntent = State(initialValue: RecordExplicitIntentState(
            category: item.category, userSelectedCategory: item.userEditedCategory == true
        ))
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var cleanTitle: String {
        titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editIntent: RecordEditIntent {
        RecordEditPolicy.intent(
            baseline: initialBaseline, amountText: amountText, noteText: titleText,
            initialNoteText: initialBaseline.title, date: selectedDate, categoryIntent: categoryIntent
        )
    }

    private var proposedItem: HomeItem {
        RecordEditPolicy.proposedItem(
            intent: editIntent, amountText: amountText, noteText: titleText, date: selectedDate
        )
    }

    private var previewTitle: String { proposedItem.title }

    private var previewEmotion: String {
        RecordEditPolicy.applying(proposedItem, intent: editIntent, to: item).displayEmotionTag
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
                var sourceImages: [Data] = []
                for photo in newValue.prefix(editPhotoPickerSelectionLimit) {
                    if let data = try? await photo.loadTransferable(type: Data.self) {
                        sourceImages.append(data)
                    }
                }
                // UIImage decoding, resizing and JPEG encoding are CPU-heavy;
                // keep them off the main actor so the editor remains scrollable.
                let compressedImages = await Task.detached(priority: .userInitiated) {
                    sourceImages.compactMap { MemoryImageCompressor.compressedJPEGData(from: $0) }
                }.value
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

            if !previewEmotion.isEmpty { editPreviewEmotionPill }
            editPreviewMetaRow
        }
    }

    private var editPreviewEmotionPill: some View {
        Text(previewEmotion)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(editEmotionForeground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(editPreviewEmotionBorder)
    }

    private var editPreviewEmotionBorder: some View {
        Capsule(style: .continuous)
            .stroke(AppColors.accent.opacity(AppColors.isDarkMode ? 0.22 : 0.28), lineWidth: 1)
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
            .foregroundStyle(editControlForeground)
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
        CommittedRecordNoteField(
            text: titleText,
            placeholder: "这一笔想怎么被记住？",
            isFocused: $isNoteFieldFocused,
            onCommittedChange: commitNote,
            onSubmit: dismissKeyboard
        )
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.isDarkMode ? AppColors.panelStrong : Color.white.opacity(0.68))
            )
            .id("recordEditNoteField")
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var editPreviewBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppColors.isDarkMode ? AppColors.panelStrong : Color.white.opacity(0.68))
    }

    private var editPreviewBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(AppColors.stroke.opacity(AppColors.isDarkMode ? 0.62 : 0.56), lineWidth: 1)
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
        let fill = isSelected
            ? AppColors.accent.opacity(AppColors.isDarkMode ? 0.16 : 0.18)
            : (AppColors.isDarkMode ? AppColors.surfaceMuted.opacity(0.54) : Color.white.opacity(0.58))
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fill)
    }

    private func categoryGridButtonBorder(isSelected: Bool) -> some View {
        let stroke = isSelected
            ? AppColors.accent.opacity(AppColors.isDarkMode ? 0.28 : 0.34)
            : AppColors.stroke.opacity(AppColors.isDarkMode ? 0.52 : 0.38)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(stroke, lineWidth: 1)
    }

    private func selectCategory(_ category: HomeItem.Category) {
        // End IME composition before registering the later category selection.
        dismissKeyboard()
        categoryIntent.selectCategory(category)
        selectedCategory = category
        titleText = RecordEditCategoryMutationPolicy.titleAfterSelectingCategory(
            currentTitle: titleText,
            category: category
        )
        withAnimation(.easeInOut(duration: 0.18)) {
            categoryPanelExpanded = false
        }
    }

    private func commitNote(_ value: String) {
        let title = String(value.prefix(32))
        guard title != titleText else { return }
        let meaningChanged = title.trimmingCharacters(in: .whitespacesAndNewlines)
            != titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        titleText = title
        if meaningChanged {
            categoryIntent.writeNote(title)
            selectedCategory = categoryIntent.category
        }
        safetyMessage = nil
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isNoteFieldFocused = false
    }

    private func focusEditNoteField(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard noteEditorExpanded else { return }
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
            dismissKeyboard()
            if onSave(proposedItem, editIntent) {
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
                .foregroundStyle(AppColors.isDarkMode ? AppColors.onAccent : Color.white)
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
        .disabled(proposedItem.amount <= 0)
        .opacity(proposedItem.amount <= 0 ? 0.56 : 1)
    }

    private func quietLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(editControlForeground)
        }
        .buttonStyle(.plain)
    }

    /// These are supporting edit actions, not the page's primary CTA.  Dark
    /// themes use the contrast-safe accent token at a lower intensity so the
    /// links stay discoverable without competing with the record title/amount.
    private var editControlForeground: Color {
        AppColors.readableAccent.opacity(AppColors.isDarkMode ? 0.74 : 0.90)
    }

    private var editEmotionForeground: Color {
        AppColors.readableAccent.opacity(AppColors.isDarkMode ? 0.78 : 0.95)
    }

}
