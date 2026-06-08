import SwiftUI
import PhotosUI

struct RecordView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onSaved: (() -> Void)? = nil
    @State private var selectedEntryMode: EntryMode = .manual
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isOCRRecognizing = false
    @State private var ocrProgress = 0.0
    @State private var ocrConfirmDrafts: [OCRReceiptDraft] = []
    @State private var showOCRConfirmSheet = false
    @State private var showRecordDateSheet = false
    @State private var scenePackExpanded = false
    @State private var scenePackVariants: [String: Int] = [:]
    @State private var amountPadActive = false
    @State private var recordDetailsExpanded = false
    @State private var categoryGridExpanded = false
    @State private var noteEditorExpanded = false
    @FocusState private var focusedField: RecordField?

    private enum RecordField {
        case amount
        case note
    }

    private let recordAccent = AppColors.accent
    private let recordInk = AppColors.text

    private var visibleScenePacks: [ScenePackDefinition] {
        ScenePackCopyPool.definitions.filter { pack in
            settingsViewModel.petCompanionEnabled || pack.id != "pet"
        }
    }

    private var isMember: Bool {
        let tier = settingsViewModel.memberTier.lowercased()
        return ["monthly", "yearly", "lifetime"].contains(tier)
    }

    private func guessScenePackId() -> String {
        let categoryToPackId: [HomeItem.Category: String] = [
            .dining: "food",
            .transport: "commute",
            .shopping: "shopping",
            .daily: "home",
            .entertainment: "travel",
            .lodging: "travel",
            .health: "care",
            .home: "home",
            .social: "social",
            .other: "travel",
        ]
        if let packId = categoryToPackId[homeViewModel.selectedCategory],
           visibleScenePacks.contains(where: { $0.id == packId }) {
            return packId
        }

        let amount = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        if amount <= 15 { return "commute" }
        if amount <= 45 { return "food" }
        if amount <= 120 { return "home" }
        return "travel"
    }

    private func applyScenePack(_ pack: ScenePackDefinition, keepSelectedCategory: Bool = false) {
        dismissKeyboard()
        let amount = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        let categoryContext = keepSelectedCategory ? homeViewModel.selectedCategory : pack.category
        let variantKey = scenePackVariantKey(
            pack: pack,
            amount: amount,
            category: categoryContext,
            date: homeViewModel.selectedDate
        )
        let variant = scenePackVariants[variantKey, default: 0]
        scenePackVariants[variantKey] = variant + 1
        homeViewModel.inputTitle = ScenePackCopyPool.note(
            for: pack,
            amount: amount,
            date: homeViewModel.selectedDate,
            categoryContext: categoryContext,
            petName: settingsViewModel.petNickname,
            historyItems: homeViewModel.items,
            allowPetCopy: settingsViewModel.petCompanionEnabled,
            variant: variant
        )
        if !keepSelectedCategory {
            homeViewModel.selectCategory(pack.category)
        }
    }

    private func scenePackVariantKey(
        pack: ScenePackDefinition,
        amount: Double,
        category: HomeItem.Category,
        date: Date
    ) -> String {
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        let hour = Calendar.current.component(.hour, from: date)
        let amountBucket = Int((amount * 100).rounded())
        return "\(pack.id)|\(category.rawValue)|\(amountBucket)|\(Int(day))|\(hour)"
    }

    private func scenePackDesc(_ pack: ScenePackDefinition) -> String {
        ScenePackCopyPool.renderPetName(pack.desc, petName: settingsViewModel.petNickname)
    }

    enum EntryMode: String, CaseIterable, Identifiable {
        case manual = "手动录入"
        case ocr = "智能导入"
        var id: String { rawValue }
    }

    private var hasValidAmount: Bool {
        guard let v = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) else { return false }
        return v > 0
    }

    private var inputAmountValue: Double {
        Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var previewBrand: MerchantBrandDefinition? {
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let brand = MerchantBrandCatalog.matchBrand(in: title) {
            return brand
        }
        if let title = homeViewModel.recordPrefillResult?.title {
            return MerchantBrandCatalog.matchBrand(in: title)
        }
        return nil
    }

    private var previewHeadline: String {
        let title = homeViewModel.inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        if let prefillTitle = homeViewModel.recordPrefillResult?.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !prefillTitle.isEmpty {
            return prefillTitle
        }
        return previewFallbackTitle(for: homeViewModel.selectedCategory)
    }

    private var previewEmotion: String {
        if let result = homeViewModel.recordPrefillResult,
           let emotion = result.emotionTag?.trimmingCharacters(in: .whitespacesAndNewlines),
           !emotion.isEmpty,
           (result.source == "brand" || result.confidence >= 0.65) {
            return emotion
        }
        let brandId = previewBrand?.id
        return NarrativeCopyResolver.resolveEmotionTag(
            context: NarrativeCopyResolver.Context(
                brandId: brandId,
                category: homeViewModel.selectedCategory,
                amount: inputAmountValue,
                date: homeViewModel.selectedDate,
                seed: "\(inputAmountValue)|\(homeViewModel.selectedDate.timeIntervalSince1970)|\(homeViewModel.selectedCategory.rawValue)|\(brandId ?? "")"
            )
        )
    }

    private var previewMeta: String {
        "\(homeViewModel.selectedCategory.displayName) · \(homeViewModel.selectedDate.zhBillDateTime)"
    }

    private var previewQuickActionTitle: String {
        switch previewQuickActionProminence {
        case .link:
            return "换一句说法"
        case .balanced:
            return "✨ 换一句"
        case .primary:
            return "✨ 帮我写一句"
        }
    }

    private var previewQuickActionProminence: LifeEntryPreviewCard.QuickActionProminence {
        if previewBrand != nil || homeViewModel.recordPrefillResult?.source == "brand" {
            return .link
        }
        if let result = homeViewModel.recordPrefillResult,
           result.source == "habit",
           result.confidence >= 0.55 {
            return .balanced
        }
        return .primary
    }

    private var hasAmountDraft: Bool {
        !homeViewModel.inputAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowAmountQuickKeys: Bool {
        selectedEntryMode == .manual && amountPadActive
    }

    private func dismissKeyboard() {
        amountPadActive = false
        focusedField = nil
    }

    private func previewFallbackTitle(for category: HomeItem.Category) -> String {
        switch category {
        case .dining: return "吃饭的一小笔"
        case .transport: return "路上的一小段"
        case .shopping: return "给生活添一点"
        case .daily: return "日常的一点补给"
        case .entertainment: return "留给放松的一笔"
        case .lodging: return "停下来的一晚"
        case .health: return "照顾自己的一笔"
        case .home: return "把家安顿一下"
        case .social: return "心意往来的一笔"
        case .other: return "今天的一小笔"
        }
    }

    private func handlePreviewQuickAction() {
        dismissKeyboard()
        guard hasValidAmount else { return }
        guard isMember else {
            withAnimation(.easeInOut(duration: 0.2)) {
                recordDetailsExpanded = true
                noteEditorExpanded = true
            }
            return
        }
        let quickPackId = guessScenePackId()
        let packs = visibleScenePacks
        guard let quickPack = packs.first(where: { $0.id == quickPackId }) ?? packs.first else { return }
        applyScenePack(quickPack, keepSelectedCategory: true)
    }

    private func refreshRecommendedCategory() {
        guard selectedEntryMode == .manual else { return }
        guard !homeViewModel.categoryLockedByUser else { return }
        homeViewModel.refreshRecordPrefill()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // ── Record Panel (matching web recordPage) ──
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("记一笔")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(recordInk)

                    // Segment control
                    recordModeSegment

                    if selectedEntryMode == .manual {
                        manualForm
                    } else {
                        ocrForm
                    }
                }
                .glassPanel(radius: 24, padding: 24)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 120)
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shouldShowAmountQuickKeys {
                amountKeyboardDock
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: shouldShowAmountQuickKeys)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                await MainActor.run {
                    isOCRRecognizing = true
                    ocrProgress = 0.12
                }
                let progressTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 180_000_000)
                        await MainActor.run {
                            ocrProgress = min(0.88, ocrProgress + 0.08)
                        }
                    }
                }
                var drafts: [OCRReceiptDraft] = []
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    drafts = await homeViewModel.recognizeOCRDrafts(imageData: data, isMember: isMember)
                }
                progressTask.cancel()
                await MainActor.run {
                    ocrProgress = 1
                    if !drafts.isEmpty {
                        ocrConfirmDrafts = drafts
                        showOCRConfirmSheet = true
                    }
                }
                try? await Task.sleep(nanoseconds: 180_000_000)
                await MainActor.run {
                    isOCRRecognizing = false
                    ocrProgress = 0
                    selectedPhoto = nil
                }
            }
        }
        .onChange(of: homeViewModel.inputAmount) { _, _ in
            refreshRecommendedCategory()
        }
        .onChange(of: homeViewModel.inputTitle) { _, _ in
            refreshRecommendedCategory()
        }
        .onChange(of: homeViewModel.selectedDate) { _, _ in
            refreshRecommendedCategory()
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue == .note {
                amountPadActive = false
            }
        }
        .sheet(isPresented: $showRecordDateSheet) {
            NavigationStack {
                DatePicker("账单时间", selection: $homeViewModel.selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("补记时间")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showRecordDateSheet = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showOCRConfirmSheet) {
            OCRConfirmSheet(drafts: ocrConfirmDrafts) { selectedDrafts in
                homeViewModel.importOCRDrafts(selectedDrafts, isMember: isMember)
            }
        }
        .onChange(of: showOCRConfirmSheet) { _, isPresented in
            if !isPresented {
                ocrConfirmDrafts = []
            }
        }
    }

    // MARK: - Segment

    private var recordModeSegment: some View {
        HStack(spacing: 4) {
            ForEach(EntryMode.allCases) { mode in
                Button {
                    dismissKeyboard()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEntryMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: selectedEntryMode == mode ? .semibold : .regular))
                        .foregroundStyle(recordInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedEntryMode == mode
                                ? Color.white.opacity(0.85)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: selectedEntryMode == mode ? Color.black.opacity(0.08) : .clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.25))
        )
    }

    // MARK: - Manual Form

    @ViewBuilder
    private var manualForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            amountField
            if hasValidAmount {
                lifeEntryPreview
            }
            saveRow
            if hasValidAmount {
                recordDetailsFold
                VStack(alignment: .leading, spacing: 4) {
                    Text("默认今天，如需补记点右侧日历。")
                    Text("数据仅保存在本机，不上传云端。")
                }
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
            }
        }
    }

    private var lifeEntryPreview: some View {
        LifeEntryPreviewCard(
            headline: previewHeadline,
            emotion: previewEmotion,
            meta: previewMeta,
            amountText: inputAmountValue.formatted(.cny),
            quickActionTitle: previewQuickActionTitle,
            quickActionProminence: previewQuickActionProminence,
            onTap: {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) {
                    recordDetailsExpanded = true
                    noteEditorExpanded = true
                }
                focusedField = .note
            },
            onChangeCategory: {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) {
                    recordDetailsExpanded = true
                    categoryGridExpanded = true
                }
            },
            onQuickAction: handlePreviewQuickAction
        )
    }

    private var recordDetailsFold: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) {
                    recordDetailsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("补充细节")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(recordInk.opacity(0.88))
                        Text("不急，想补再补。")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.subtext.opacity(0.78))
                    }
                    Spacer()
                    Image(systemName: recordDetailsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.subtext.opacity(0.72))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.54))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.46), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if recordDetailsExpanded {
                HStack(spacing: 8) {
                    detailToggleButton("改分类", isActive: categoryGridExpanded) {
                        withAnimation(.easeInOut(duration: 0.16)) { categoryGridExpanded.toggle() }
                    }
                    detailToggleButton("写点细节", isActive: noteEditorExpanded) {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            noteEditorExpanded.toggle()
                            if noteEditorExpanded { focusedField = .note }
                        }
                    }
                }

                if categoryGridExpanded { categorySection }
                if noteEditorExpanded { noteSection }
                if isMember { memberScenePackSection }
            }
        }
    }

    private func detailToggleButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            dismissKeyboard()
            action()
        }) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? AppColors.accent.opacity(0.9) : recordInk.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(isActive ? AppColors.accent.opacity(0.12) : Color.white.opacity(0.58))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(isActive ? AppColors.accent.opacity(0.25) : Color.white.opacity(0.48), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount Field

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                focusedField = nil
                withAnimation(.easeInOut(duration: 0.16)) {
                    amountPadActive = true
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    HStack(spacing: 0) {
                    Text("¥")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.subtext.opacity(0.74))
                        .padding(.trailing, 2)
                        .offset(y: 1)

                    Text(homeViewModel.inputAmount.isEmpty ? "0.00" : homeViewModel.inputAmount)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(homeViewModel.inputAmount.isEmpty ? AppColors.subtext.opacity(0.45) : recordInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.numericText())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.35), AppColors.accent.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(hasValidAmount ? "金额只是刻度，这一笔会长成一句生活记录。" : "记下一笔今天的生活")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.76))
        }
    }

    // MARK: - Amount Quick Keys

    private var amountKeyboardDock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("金额")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
                quickKeyButton(".00") { applyDot00() }
                    .frame(maxWidth: 72)
                quickKeyButton("+10") { applyAmountDelta(10) }
                    .frame(maxWidth: 72)
                quickKeyButton("+50") { applyAmountDelta(50) }
                    .frame(maxWidth: 72)
                Button {
                    dismissKeyboard()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(recordAccent)
                        .frame(width: 42, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.78))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("收起键盘")
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9"], id: \.self) { key in
                    amountPadButton(key) { appendAmountKey(key) }
                }
                amountPadButton(".") { appendAmountKey(".") }
                amountPadButton("0") { appendAmountKey("0") }
                amountPadButton("⌫", isAccent: true) { deleteAmountKey() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(red: 0.94, green: 0.95, blue: 0.96).opacity(0.86))
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.line.opacity(0.55))
                .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: -6)
    }

    private func amountPadButton(_ title: String, isAccent: Bool = false, action: @escaping () -> Void) -> some View {
        let foreground = amountPadForeground(isAccent: isAccent)
        let fill = amountPadFill(isAccent: isAccent)
        let stroke = amountPadStroke(isAccent: isAccent)

        return Button(action: action) {
            Text(title)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func amountPadForeground(isAccent: Bool) -> Color {
        isAccent ? recordAccent : recordInk.opacity(0.92)
    }

    private func amountPadFill(isAccent: Bool) -> Color {
        isAccent ? Color.white.opacity(0.72) : Color.white.opacity(0.92)
    }

    private func amountPadStroke(isAccent: Bool) -> Color {
        isAccent ? recordAccent.opacity(0.22) : Color.white.opacity(0.7)
    }

    private func quickKeyButton(_ title: String, isAccent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isAccent ? recordAccent : recordInk.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isAccent ? recordAccent.opacity(0.12) : Color.white.opacity(0.78))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isAccent ? recordAccent.opacity(0.25) : AppColors.line.opacity(0.76), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分类（点一下即可）")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(recordInk.opacity(0.82))

            let recommended = homeViewModel.recommendCategory(for: homeViewModel.inputAmount)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100, maximum: 180), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(HomeItem.Category.allCases) { category in
                    categoryChip(category: category, isRecommended: recommended == category)
                }
            }
        }
    }

    private func categoryChip(category: HomeItem.Category, isRecommended: Bool) -> some View {
        let isSelected = homeViewModel.selectedCategory == category
        return Button {
            dismissKeyboard()
            withAnimation(.easeInOut(duration: 0.12)) {
                homeViewModel.selectCategory(category)
            }
        } label: {
            HStack(spacing: 4) {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
                if isRecommended {
                    Text("推荐")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.subtext)
                }
            }
            .foregroundStyle(isSelected
                ? AppColors.accent.opacity(0.84)
                : recordInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                isSelected
                    ? AppColors.accent.opacity(0.16)
                    : Color.white.opacity(0.62),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isSelected ? AppColors.accent.opacity(0.45) : Color.white.opacity(0.45),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "",
                text: $homeViewModel.inputTitle,
                prompt: Text("已归类到「\(homeViewModel.selectedCategory.label)」，可补充点细节（不填也能保存）")
                    .foregroundStyle(AppColors.subtext.opacity(0.72))
            )
            .focused($focusedField, equals: .note)
            .submitLabel(.done)
            .onSubmit { dismissKeyboard() }
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(homeViewModel.noteSuggestions(for: homeViewModel.selectedCategory), id: \.self) { suggestion in
                        Button(suggestion) {
                            dismissKeyboard()
                            homeViewModel.inputTitle = suggestion
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(recordInk.opacity(0.88))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.thinMaterial)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Save Row

    private var saveRow: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                guard hasValidAmount else { return }
                dismissKeyboard()
                homeViewModel.addManualRecord()
                recordDetailsExpanded = false
                categoryGridExpanded = false
                noteEditorExpanded = false
                onSaved?()
            } label: {
                ZStack {
                    if hasValidAmount {
                        LinearGradient(
                            colors: [recordAccent.opacity(0.92), recordAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(Capsule(style: .continuous))
                    } else {
                        Capsule(style: .continuous)
                            .fill(AppColors.panelStrong)
                    }

                    Text("放进账本")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hasValidAmount ? Color.white : AppColors.subtext.opacity(0.72))
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(hasValidAmount ? Color.white.opacity(0.36) : AppColors.line, lineWidth: 1)
                )
                .shadow(color: hasValidAmount ? recordAccent.opacity(0.35) : Color.clear, radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(!hasValidAmount)

            if hasValidAmount {
                Button {
                    dismissKeyboard()
                    showRecordDateSheet = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(recordAccent)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.white)
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                        )
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -10)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Member Scene Packs

    @ViewBuilder
    private var memberScenePackSection: some View {
        let quickPackId = guessScenePackId()
        let packs = visibleScenePacks
        let quickPack = packs.first(where: { $0.id == quickPackId }) ?? packs[0]
        ScenePackSectionView(
            scenePacks: packs,
            isExpanded: scenePackExpanded,
            isPetMode: settingsViewModel.petCompanionEnabled,
            recordInk: recordInk,
            onQuickGenerate: {
                applyScenePack(quickPack, keepSelectedCategory: true)
            },
            onToggleExpanded: {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) { scenePackExpanded.toggle() }
            },
            onSelectPack: { pack in
                applyScenePack(pack)
            },
            scenePackDesc: scenePackDesc
        )
    }

    // MARK: - OCR Form

    @ViewBuilder
    private var ocrForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导入微信/支付宝账单截图，识别后先确认，再写入账单。")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)

            Text("请保证每笔完整在画面内，上下留一点边；首尾笔被裁切可能漏识别。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.86))

            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Label("导入账单截图", systemImage: "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        LinearGradient(
                            colors: [recordAccent.opacity(0.92), recordAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: recordAccent.opacity(0.25), radius: 8, y: 4)
            }
            .disabled(isOCRRecognizing)

            if isOCRRecognizing {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: ocrProgress)
                        .tint(recordAccent)
                    Text("正在识别账单，请稍候…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.68))
                )
            }

            #if DEBUG
            Button("使用演示 OCR 结果") {
                ocrConfirmDrafts = homeViewModel.makeDemoOCRDrafts()
                showOCRConfirmSheet = true
            }
            .font(.system(size: 14))
            .foregroundStyle(recordAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(recordAccent.opacity(0.5), lineWidth: 1)
            )
            #endif

            if !homeViewModel.ocrStatus.isEmpty {
                Text(homeViewModel.ocrStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                    .padding(.top, 4)
            }

            OCRDraftPanel(
                items: homeViewModel.ocrDraftItems,
                onToggleResolved: { id, isResolved in homeViewModel.updateOCRDraftStatus(id: id, isResolved: isResolved) },
                onCategoryChange: { id, category in homeViewModel.updateOCRDraftCategory(id: id, category: category) },
                onAmountChange: { id, amount in homeViewModel.updateOCRDraftAmount(id: id, amount: amount) },
                onDelete: { id in homeViewModel.deleteOCRDraftItem(id: id) },
                onClearResolved: homeViewModel.clearResolvedOCRDrafts,
                onResolveAllPending: homeViewModel.resolveAllPendingOCRDrafts
            )
            .padding(.top, 6)
        }
    }

    // MARK: - Amount helpers

    private func appendAmountKey(_ key: String) {
        var value = homeViewModel.inputAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        if key == "." {
            guard !value.contains(".") else { return }
            homeViewModel.inputAmount = value.isEmpty ? "0." : value + "."
            return
        }

        if value == "0" {
            value = ""
        }
        let next = value + key
        guard isValidAmountDraft(next) else { return }
        homeViewModel.inputAmount = next
    }

    private func deleteAmountKey() {
        guard !homeViewModel.inputAmount.isEmpty else { return }
        homeViewModel.inputAmount.removeLast()
    }

    private func isValidAmountDraft(_ value: String) -> Bool {
        guard value.count <= 9 else { return false }
        if let dotIndex = value.firstIndex(of: ".") {
            let decimals = value[value.index(after: dotIndex)...]
            return decimals.count <= 2
        }
        return true
    }

    private func applyAmountDelta(_ delta: Double) {
        let base = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        let next = max(0, base + delta)
        homeViewModel.inputAmount = String(format: "%.2f", next)
    }

    private func applyDot00() {
        let base = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        homeViewModel.inputAmount = String(format: "%.2f", base)
    }
}
