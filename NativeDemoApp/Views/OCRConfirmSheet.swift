import SwiftUI

struct OCRConfirmSheet: View {
    private struct ConfirmRow: Identifiable {
        let id: UUID
        var draft: OCRReceiptDraft
        var selected: Bool
    }

    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ConfirmRow]

    let onConfirm: ([OCRReceiptDraft]) -> Int

    init(drafts: [OCRReceiptDraft], onConfirm: @escaping ([OCRReceiptDraft]) -> Int) {
        _rows = State(initialValue: drafts.map { ConfirmRow(id: $0.id, draft: $0, selected: $0.defaultSelected) })
        self.onConfirm = onConfirm
    }

    private var selectedRows: [ConfirmRow] {
        rows.filter(\.selected)
    }

    private var selectedTotal: Double {
        selectedRows.reduce(0) { $0 + $1.draft.amount }
    }

    private var reviewNotes: [String] {
        Array(Set(rows.compactMap { $0.draft.reviewNote })).sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("先帮你把截图里的支出整理出来，请核对金额、备注和分类。")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.text)

                            Text("识别均在本地完成，原图不会上传。退款和收入会尽量忽略。")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.subtext)

                            HStack(spacing: 10) {
                                statBlock(title: "识别条数", value: "\(rows.count)")
                                statBlock(title: "总金额", value: selectedTotal.formatted(.cny.precision(.fractionLength(2))))
                            }
                        }

                        if !reviewNotes.isEmpty {
                            reviewSummary
                        }

                        receiptFoldDivider

                        LazyVStack(spacing: 10) {
                            ForEach(rows.indices, id: \.self) { index in
                                confirmRow(index)
                            }
                        }
                    }
                    .padding(18)
                }

                Divider()
                HStack(spacing: 12) {
                    Button("取消") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.subtext)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.7))
                        )

                    Button {
                        let selectedDrafts = selectedRows.map(\.draft)
                        if onConfirm(selectedDrafts) > 0 {
                            dismiss()
                        }
                    } label: {
                        Text("导入 \(selectedRows.count) 条到账单")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .disabled(selectedRows.isEmpty)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedRows.isEmpty ? AppColors.subtext.opacity(0.35) : AppColors.accent)
                    )
                }
                .padding(16)
                .background(AppColors.panelStrong)
            }
            .navigationTitle("待确认账单")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    private var reviewSummary: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.accent.opacity(0.82))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text("已做识别整理")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(0.82))

                ForEach(reviewNotes.prefix(2), id: \.self) { note in
                    Text(note)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.88))
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.accent.opacity(0.14), lineWidth: 1)
        )
    }

    private func confirmRow(_ index: Int) -> some View {
        let row = rows[index]
        return VStack(alignment: .leading, spacing: 12) {
            confirmRowHeader(row: row, index: index)
            if let note = row.draft.reviewNote {
                reviewNoteRow(note, status: row.draft.reviewStatus)
            }
            confirmRowCategory(row: row, index: index)
        }
        .padding(16)
        .background(confirmRowBackground(isSelected: row.selected))
        .overlay(confirmRowBorder(isSelected: row.selected))
        .overlay(alignment: .leading) {
            if row.selected {
                Capsule(style: .continuous)
                    .fill(AppColors.accent.opacity(0.22))
                    .frame(width: 3)
                    .padding(.vertical, 14)
            }
        }
    }

    private func confirmRowHeader(row: ConfirmRow, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                rows[index].selected.toggle()
            } label: {
                Image(systemName: row.selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(row.selected ? AppColors.accent : AppColors.subtext.opacity(0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("导入此条")

            VStack(alignment: .leading, spacing: 8) {
                Text("备注")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.subtext.opacity(0.74))

                Text(row.draft.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(3)

                HStack(spacing: 6) {
                    if let brand = brand(for: row.draft) {
                        brandChip(brand)
                    }

                    if let scene = sceneSignal(for: row.draft), scene.confidenceTier >= .medium {
                        sceneChip(scene)
                    }
                }

                Text(row.draft.date.zhBillDateTime)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.72))
            }

            Spacer(minLength: 8)

            amountReviewBlock(row.draft)
        }
    }

    private func amountReviewBlock(_ draft: OCRReceiptDraft) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("金额")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.subtext.opacity(0.72))
            Text(draft.amount.formatted(.cny.precision(.fractionLength(2))))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.54))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.accent.opacity(0.14), lineWidth: 1)
        )
    }

    private func brand(for draft: OCRReceiptDraft) -> MerchantBrandDefinition? {
        MerchantBrandCatalog.definition(for: draft.merchantBrandId)
            ?? MerchantBrandCatalog.matchOCRBrand(in: "\(draft.title)\n\(draft.rawText)")
    }

    private func brandChip(_ brand: MerchantBrandDefinition) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "tag.fill")
                .font(.system(size: 10, weight: .bold))
            Text(brand.displayName)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(AppColors.accent.opacity(0.88))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(AppColors.accent.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppColors.accent.opacity(0.18), lineWidth: 1)
        )
    }

    private func sceneSignal(for draft: OCRReceiptDraft) -> LifeSceneSignal? {
        let item = HomeItem(
            title: "\(draft.title)\n\(draft.rawText)",
            amount: draft.amount,
            category: draft.category,
            source: .ocr,
            createdAt: draft.date,
            merchantBrandId: draft.merchantBrandId
        )
        let signal = LifeSceneSemanticService.classify(item)
        return signal.confidenceTier >= .medium ? signal : nil
    }

    private func sceneChip(_ signal: LifeSceneSignal) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
            Text(LifeSceneSemanticService.displayTheme(for: signal))
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(AppColors.text.opacity(0.74))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.64))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppColors.line.opacity(0.35), lineWidth: 1)
        )
    }

    private func reviewNoteRow(_ note: String, status: OCRDraftReviewStatus) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: reviewStatusIcon(status))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(reviewStatusColor(status))
                .padding(.top, 2)

            Text(note)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.88))
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(reviewStatusColor(status).opacity(0.08))
        )
    }

    private func reviewStatusIcon(_ status: OCRDraftReviewStatus) -> String {
        switch status {
        case .ready:
            return "checkmark.seal.fill"
        case .needsReview:
            return "exclamationmark.circle.fill"
        case .possibleDuplicate:
            return "arrow.triangle.merge"
        }
    }

    private func reviewStatusColor(_ status: OCRDraftReviewStatus) -> Color {
        switch status {
        case .ready:
            return AppColors.accent.opacity(0.82)
        case .needsReview:
            return Color.orange.opacity(0.86)
        case .possibleDuplicate:
            return AppColors.accent.opacity(0.82)
        }
    }

    private func confirmRowCategory(row: ConfirmRow, index: Int) -> some View {
        HStack(spacing: 10) {
            Text("分类")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.subtext.opacity(0.78))

            OCRCategoryChips(selectedCategory: row.draft.category) { category in
                if rows[index].draft.category != category {
                    rows[index].draft.categoryCorrectionFrom = rows[index].draft.category
                }
                rows[index].draft.category = category
                rows[index].draft.userEditedCategory = true
            }

            Spacer()

            statusPill(row.selected ? "将导入" : "已跳过", isSelected: row.selected)
        }
    }

    private func statusPill(_ text: String, isSelected: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isSelected ? AppColors.accent.opacity(0.82) : AppColors.subtext.opacity(0.82))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : Color.white.opacity(0.50))
            )
    }

    private func confirmRowBackground(isSelected: Bool) -> some View {
        let fill = isSelected ? AppColors.accent.opacity(0.08) : Color.white.opacity(0.58)
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(fill)
    }

    private func confirmRowBorder(isSelected: Bool) -> some View {
        let stroke = isSelected ? AppColors.accent.opacity(0.24) : Color.white.opacity(0.45)
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(stroke, lineWidth: 1)
    }

    private var receiptFoldDivider: some View {
        HStack(spacing: 4) {
            ForEach(0..<18, id: \.self) { index in
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(index.isMultiple(of: 2) ? AppColors.accent.opacity(0.20) : AppColors.line.opacity(0.56))
                    .frame(width: 10, height: 2)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -18 : 18))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .accessibilityHidden(true)
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.68))
        )
    }
}

struct OCRDraftPanel: View {
    private typealias DraftGroup = (key: String, importedAt: Date, items: [HomeItem])

    let items: [HomeItem]
    let onToggleResolved: (UUID, Bool) -> Void
    let onCategoryChange: (UUID, HomeItem.Category) -> Void
    let onAmountChange: (UUID, Double) -> Void
    let onDelete: (UUID) -> Void
    let onClearResolved: () -> Void
    let onResolveAllPending: () -> Void

    private var visibleGroups: [DraftGroup] {
        let grouped = Dictionary(grouping: items) { item in
            item.draftMeta?.batchId ?? item.id.uuidString
        }
        var groups: [DraftGroup] = grouped.map { key, batchItems in
            let importedAt = batchItems.first?.draftMeta?.importedAt ?? batchItems.first?.createdAt ?? .now
            let sortedItems = batchItems.sorted { $0.createdAt > $1.createdAt }
            return (key: key, importedAt: importedAt, items: sortedItems)
        }
        groups.sort { $0.importedAt > $1.importedAt }
        return Array(groups.prefix(3))
    }

    private var pendingItems: [HomeItem] {
        items.filter { $0.draftMeta?.status == .pending }
    }

    private var resolvedCount: Int {
        items.filter { $0.draftMeta?.status == .resolved }.count
    }

    private var pendingTotal: Double {
        pendingItems.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelHeader

            if items.isEmpty {
                emptyState
            } else {
                draftGroupList
            }
        }
        .padding(18)
        .background(panelBackground)
        .overlay(panelBorder)
    }

    private var panelHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("待整理账单")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text(panelSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Button("\u{4E00}\u{952E}\u{6807}\u{8BB0}\u{5DF2}\u{6574}\u{7406}") { onResolveAllPending() }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(resolveAllForeground)
                    .disabled(pendingItems.isEmpty)
                Button("\u{5B8C}\u{6210}\u{6574}\u{7406}\u{FF08}\(resolvedCount) \u{7B14}\u{FF09}") { onClearResolved() }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(clearResolvedForeground)
                    .disabled(resolvedCount == 0)
            }
        }
    }

    private var panelSubtitle: String {
        if items.isEmpty {
            return "导入后会先放在这里，你可以再改分类、金额或删掉误识别。"
        }
        let total = pendingTotal.formatted(.cny.precision(.fractionLength(2)))
        return "\(pendingItems.count) 笔待整理 · 合计 \(total)"
    }

    private var resolveAllForeground: Color {
        pendingItems.isEmpty ? AppColors.subtext.opacity(0.45) : AppColors.accent
    }

    private var clearResolvedForeground: Color {
        resolvedCount > 0 ? AppColors.accent : AppColors.subtext.opacity(0.45)
    }

    private var emptyState: some View {
        Text("选择账单截图后，识别结果会先进入确认页；确认导入后，会出现在这里继续整理。")
            .font(.system(size: 13))
            .foregroundStyle(AppColors.subtext)
            .frame(maxWidth: .infinity, minHeight: 108)
            .background(emptyStateBackground)
    }

    private var emptyStateBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.58))
    }

    private var draftGroupList: some View {
        LazyVStack(spacing: 14) {
            ForEach(visibleGroups, id: \.key) { group in
                draftGroupSection(group)
            }
        }
    }

    private func draftGroupSection(_ group: DraftGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("导入于 \(group.importedAt.zhBillDateTime)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)
            ForEach(group.items) { item in
                OCRDraftRow(
                    item: item,
                    onToggleResolved: onToggleResolved,
                    onCategoryChange: onCategoryChange,
                    onAmountChange: onAmountChange,
                    onDelete: onDelete
                )
            }
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(AppColors.accent.opacity(0.06))
    }

    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(AppColors.accent.opacity(0.16), lineWidth: 1)
    }
}

private struct OCRDraftRow: View {
    let item: HomeItem
    let onToggleResolved: (UUID, Bool) -> Void
    let onCategoryChange: (UUID, HomeItem.Category) -> Void
    let onAmountChange: (UUID, Double) -> Void
    let onDelete: (UUID) -> Void

    @State private var amountText: String
    @State private var isEditingAmount = false

    init(
        item: HomeItem,
        onToggleResolved: @escaping (UUID, Bool) -> Void,
        onCategoryChange: @escaping (UUID, HomeItem.Category) -> Void,
        onAmountChange: @escaping (UUID, Double) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        self.item = item
        self.onToggleResolved = onToggleResolved
        self.onCategoryChange = onCategoryChange
        self.onAmountChange = onAmountChange
        self.onDelete = onDelete
        _amountText = State(initialValue: String(format: "%.2f", item.amount))
    }

    private var isResolved: Bool {
        item.draftMeta?.status == .resolved
    }

    var body: some View {
        rowContent
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            categoryRow
            if isEditingAmount {
                amountPad
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(rowBackground)
        .overlay(rowBorder)
        .animation(.easeInOut(duration: 0.16), value: isEditingAmount)
        .onChange(of: item.amount) { _, newValue in
            guard !isEditingAmount else { return }
            amountText = amountInputText(newValue)
        }
    }

    private var rowBackground: some View {
        let fill = isResolved ? Color.white.opacity(0.46) : Color.white.opacity(0.68)
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(fill)
    }

    private var rowBorder: some View {
        let stroke = isResolved ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.52)
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(stroke, lineWidth: 1)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            resolveButton
            titleBlock
            Spacer(minLength: 8)
            amountDisplay
        }
    }

    private var resolveButton: some View {
        Button {
            onToggleResolved(item.id, !isResolved)
        } label: {
            Image(systemName: isResolved ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(isResolved ? AppColors.accent : AppColors.subtext.opacity(0.48))
        }
        .buttonStyle(.plain)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .lineLimit(3)
            Text(item.createdAt.zhBillDateTime)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)
        }
    }

    private var amountDisplay: some View {
        Button {
            amountText = amountInputText(item.amount)
            isEditingAmount = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("¥")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.subtext.opacity(0.78))
                Text(amountText.isEmpty ? "0.00" : amountText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .minimumScaleFactor(0.75)
                if isEditingAmount {
                    amountCursor
                        .offset(y: 4)
                }
            }
            .padding(.horizontal, isEditingAmount ? 8 : 0)
            .padding(.vertical, isEditingAmount ? 5 : 0)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isEditingAmount ? Color.white.opacity(0.78) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isEditingAmount ? AppColors.accent.opacity(0.26) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("修改金额")
    }

    private var categoryRow: some View {
        HStack(spacing: 10) {
            Text("分类")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)
            categoryPicker
            Spacer()
            Text(isResolved ? "已整理" : "待整理 ↓")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isResolved ? AppColors.accent : AppColors.subtext)
            deleteButton
        }
    }

    private var categoryPicker: some View {
        OCRCategoryChips(selectedCategory: item.category) { category in
            onCategoryChange(item.id, category)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            onDelete(item.id)
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.58), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var amountPad: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                amountQuickButton(".00") { applyDot00() }
                amountQuickButton("+10") { applyAmountDelta(10) }
                amountQuickButton("+50") { applyAmountDelta(50) }
                amountCloseButton
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.94, green: 0.95, blue: 0.96).opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    private var amountCloseButton: some View {
        Button {
            commitAmount()
            isEditingAmount = false
        } label: {
            Image(systemName: "keyboard.chevron.compact.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 42, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("收起键盘")
    }

    private func amountQuickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.text.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                )
        }
        .buttonStyle(.plain)
    }

    private func amountPadButton(_ title: String, isAccent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(isAccent ? AppColors.accent : AppColors.text.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(isAccent ? 0.74 : 0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(isAccent ? AppColors.accent.opacity(0.22) : Color.white.opacity(0.7), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var amountCursor: some View {
        TimelineView(.periodic(from: .now, by: 0.56)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.56)
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(AppColors.accent.opacity(0.72))
                .frame(width: 2, height: 22)
                .opacity(tick.isMultiple(of: 2) ? 1 : 0.16)
        }
        .frame(width: 5, height: 24)
    }

    private func commitAmount() {
        guard let value = Double(amountText.replacingOccurrences(of: ",", with: "")), value > 0 else { return }
        onAmountChange(item.id, value)
    }

    private func appendAmountKey(_ key: String) {
        var value = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        if key == "." {
            guard !value.contains(".") else { return }
            amountText = value.isEmpty ? "0." : value + "."
            commitAmount()
            return
        }

        if value == "0" {
            value = ""
        }
        let next = value + key
        guard isValidAmountDraft(next) else { return }
        amountText = next
        commitAmount()
    }

    private func deleteAmountKey() {
        guard !amountText.isEmpty else { return }
        amountText.removeLast()
        commitAmount()
    }

    private func applyAmountDelta(_ delta: Double) {
        let base = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        amountText = amountInputText(max(0, base + delta))
        commitAmount()
    }

    private func applyDot00() {
        let base = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        amountText = String(format: "%.2f", base)
        commitAmount()
    }

    private func isValidAmountDraft(_ value: String) -> Bool {
        guard value.count <= 9 else { return false }
        if let dotIndex = value.firstIndex(of: ".") {
            let decimals = value[value.index(after: dotIndex)...]
            return decimals.count <= 2
        }
        return true
    }

    private func amountInputText(_ amount: Double) -> String {
        if amount.rounded() == amount {
            return String(format: "%.0f", amount)
        }
        return String(format: "%.2f", amount)
    }
}

private struct OCRCategoryChips: View {
    let selectedCategory: HomeItem.Category
    let onSelect: (HomeItem.Category) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(HomeItem.Category.allCases) { category in
                        Button {
                            onSelect(category)
                        } label: {
                            categoryLabel(category)
                        }
                        .buttonStyle(.plain)
                        .id(category)
                    }
                }
            }
            .onAppear {
                scrollSelectedCategoryIntoView(proxy, animated: false)
            }
            .onChange(of: selectedCategory) { _, _ in
                scrollSelectedCategoryIntoView(proxy, animated: true)
            }
        }
        .frame(maxWidth: 220, alignment: .leading)
    }

    private func scrollSelectedCategoryIntoView(_ proxy: ScrollViewProxy, animated: Bool) {
        let action = {
            proxy.scrollTo(selectedCategory, anchor: .center)
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.18)) {
                action()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                action()
            }
        }
    }

    private func categoryLabel(_ category: HomeItem.Category) -> some View {
        let isSelected = selectedCategory == category
        return Text(category.displayName)
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? AppColors.text : AppColors.subtext)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? AppColors.accent.opacity(0.16) : Color.white.opacity(0.58))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? AppColors.accent.opacity(0.3) : Color.white.opacity(0.38), lineWidth: 1)
            )
    }
}
