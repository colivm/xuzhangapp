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
    @FocusState private var focusedField: RecordField?

    private enum RecordField {
        case amount
        case note
    }

    private let recordAccent = AppColors.accent
    private let recordInk = AppColors.text

    private let scenePacks = ScenePackCopyPool.definitions

    private var isMember: Bool {
        let tier = settingsViewModel.memberTier.lowercased()
        return ["monthly", "yearly", "lifetime"].contains(tier)
    }

    private func guessScenePackId() -> String {
        let categoryToPackId: [HomeItem.Category: String] = [
            .dining: "food",
            .transport: "commute",
            .daily: "pet",
            .shopping: "travel",
            .entertainment: "travel",
            .lodging: "travel",
            .other: "travel",
        ]
        if let packId = categoryToPackId[homeViewModel.selectedCategory],
           scenePacks.contains(where: { $0.id == packId }) {
            return packId
        }

        let amount = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        if amount <= 15 { return "commute" }
        if amount <= 45 { return "food" }
        if amount <= 120 { return "pet" }
        return "travel"
    }

    private func applyScenePack(_ pack: ScenePackDefinition, keepSelectedCategory: Bool = false) {
        dismissKeyboard()
        let amount = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        let categoryContext = keepSelectedCategory ? homeViewModel.selectedCategory : pack.category
        homeViewModel.inputTitle = ScenePackCopyPool.note(
            for: pack,
            amount: amount,
            categoryContext: categoryContext,
            petName: settingsViewModel.petNickname,
            historyItems: homeViewModel.items
        )
        if !keepSelectedCategory {
            homeViewModel.selectCategory(pack.category)
        }
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

    private var hasAmountDraft: Bool {
        !homeViewModel.inputAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowAmountQuickKeys: Bool {
        selectedEntryMode == .manual && (focusedField == .amount || hasAmountDraft)
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    private func refreshRecommendedCategory() {
        guard selectedEntryMode == .manual else { return }
        guard !homeViewModel.categoryLockedByUser else { return }
        if let category = homeViewModel.recommendCategory(for: homeViewModel.inputAmount) {
            homeViewModel.applyRecommendedCategory(category)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // ── Record Panel (matching web recordPage) ──
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("记账")
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    dismissKeyboard()
                }
            }
        }
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
        .sheet(isPresented: $showRecordDateSheet) {
            NavigationStack {
                DatePicker("账单日期", selection: $homeViewModel.selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("补记日期")
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
            // Amount field
            amountField
            // Quick keyboard (show on focus or draft, matching web)
            if shouldShowAmountQuickKeys { amountQuickKeys }
            // Category chips
            if hasValidAmount { categorySection }
            // Note suggestions
            if hasValidAmount { noteSection }
            // Save row — always visible (gray when disabled, matching web .save-btn:disabled)
            saveRow
            // Member scene packs (matching web: show when amount ready + is member)
            if hasValidAmount && isMember { memberScenePackSection }
            // Hints (only visible when amount is valid, matching web)
            if hasValidAmount {
                VStack(alignment: .leading, spacing: 4) {
                    Text("默认今天，如需补记点右侧日历。")
                    Text("数据仅保存在本机，不上传云端。")
                }
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
            }
        }
    }

    // MARK: - Amount Field

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("金额")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(recordInk.opacity(0.82))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                HStack(spacing: 0) {
                    Text("¥")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.subtext.opacity(0.74))
                        .padding(.trailing, 2)
                        .offset(y: 1)

                    TextField("0.00", text: $homeViewModel.inputAmount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(recordInk)
                        .multilineTextAlignment(.leading)
                        .focused($focusedField, equals: .amount)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
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

            Text("输入金额，我帮你自动归类")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.76))
        }
    }

    // MARK: - Amount Quick Keys

    private var amountQuickKeys: some View {
        HStack(spacing: 8) {
            quickKeyButton(".00") { applyDot00() }
            quickKeyButton("+10元") { applyAmountDelta(10) }
            quickKeyButton("+50元") { applyAmountDelta(50) }
            quickKeyButton("+100元") { applyAmountDelta(100) }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.panelStrong.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.line.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: AppColors.bg.opacity(0.32), radius: 14, x: 0, y: 6)
    }

    private func quickKeyButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(recordInk.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.panelStrong.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.line.opacity(0.76), lineWidth: 1)
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

                    Text("保存")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hasValidAmount ? Color.white : AppColors.subtext.opacity(0.72))
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
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
        let quickPack = scenePacks.first(where: { $0.id == quickPackId }) ?? scenePacks[0]
        ScenePackSectionView(
            scenePacks: scenePacks,
            isExpanded: scenePackExpanded,
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
            Text("导入微信/支付宝单笔账单详情截图，识别后先确认，再写入账单。")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)

            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Label("导入账单 / 识别票据", systemImage: "photo")
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
                onClearResolved: homeViewModel.clearResolvedOCRDrafts
            )
            .padding(.top, 6)
        }
    }

    // MARK: - Amount helpers

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
