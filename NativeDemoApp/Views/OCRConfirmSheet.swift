import SwiftUI

struct OCRConfirmSheet: View {
    private struct ConfirmRow: Identifiable {
        let id: UUID
        var draft: OCRReceiptDraft
        var selected: Bool
    }

    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ConfirmRow]
    @State private var isCollectingImport = false

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

                        ocrOverviewList
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
                        guard !selectedDrafts.isEmpty, !isCollectingImport else { return }
                        isCollectingImport = true
                        if onConfirm(selectedDrafts) > 0 {
                            dismiss()
                        } else {
                            isCollectingImport = false
                        }
                    } label: {
                        Label(
                            isCollectingImport ? "正在进入整理" : "进入整理 \(selectedRows.count) 条",
                            systemImage: isCollectingImport ? "tray.and.arrow.down.fill" : "checklist.checked"
                        )
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .disabled(selectedRows.isEmpty || isCollectingImport)
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


    private var ocrOverviewList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("识别结果总览")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text("将导入 \(selectedRows.count) / \(rows.count) 条")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.subtext)
            }

            LazyVStack(spacing: 10) {
                ForEach(rows.indices, id: \.self) { index in
                    overviewRow(index)
                }
            }
        }
    }

    private func overviewRow(_ index: Int) -> some View {
        let row = rows[index]
        return HStack(alignment: .top, spacing: 11) {
            Button {
                rows[index].selected.toggle()
            } label: {
                Image(systemName: row.selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(row.selected ? AppColors.accent : AppColors.subtext.opacity(0.5))
                    .frame(width: 28, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(row.selected ? "跳过此条" : "导入此条")

            VStack(alignment: .leading, spacing: 7) {
                Text(row.draft.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(row.selected ? 1 : 0.56))
                    .lineLimit(2)

                HStack(spacing: 7) {
                    Text(row.draft.date.zhBillDateTime)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(row.selected ? 0.82 : 0.50))
                        .lineLimit(1)
                    Text(row.draft.category.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.text.opacity(row.selected ? 0.74 : 0.46))
                        .lineLimit(1)
                }

                if let note = row.draft.reviewNote {
                    overviewNote(note, status: row.draft.reviewStatus)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                Text(row.draft.amount.formatted(.cny.precision(.fractionLength(2))))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text.opacity(row.selected ? 1 : 0.50))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                statusPill(row.selected ? "将导入" : "已跳过", isSelected: row.selected)
            }
        }
        .padding(14)
        .background(confirmRowBackground(isSelected: row.selected, isActive: true))
        .overlay(confirmRowBorder(isSelected: row.selected, isActive: true))
    }

    private func overviewNote(_ note: String, status: OCRDraftReviewStatus) -> some View {
        HStack(spacing: 6) {
            Image(systemName: reviewStatusIcon(status))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(reviewStatusColor(status))
            Text(note)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.86))
                .lineLimit(1)
        }
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

    private func confirmRowBackground(isSelected: Bool, isActive: Bool = true) -> some View {
        let fill = isSelected ? AppColors.accent.opacity(isActive ? 0.10 : 0.06) : Color.white.opacity(isActive ? 0.64 : 0.48)
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(fill)
    }

    private func confirmRowBorder(isSelected: Bool, isActive: Bool = true) -> some View {
        let stroke = isSelected ? AppColors.accent.opacity(isActive ? 0.30 : 0.16) : Color.white.opacity(isActive ? 0.56 : 0.34)
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(stroke, lineWidth: isActive ? 1.1 : 1)
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
    let items: [HomeItem]
    let onToggleResolved: (UUID, Bool) -> Void
    let onCategoryChange: (UUID, HomeItem.Category) -> Void
    let onAmountChange: (UUID, Double) -> Void
    let onUpdateItem: (HomeItem) -> Void
    let onDelete: (UUID) -> Void
    let onClearResolved: () -> Void

    @State private var activeDraftID: UUID?
    @State private var isClearingResolved = false

    private var pendingItems: [HomeItem] {
        items
            .filter { $0.draftMeta?.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var resolvedItems: [HomeItem] {
        items
            .filter { $0.draftMeta?.status == .resolved }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var resolvedCount: Int {
        resolvedItems.count
    }

    private var pendingTotal: Double {
        pendingItems.reduce(0) { $0 + $1.amount }
    }

    private var activeIndex: Int? {
        guard !pendingItems.isEmpty else { return nil }
        if let activeDraftID,
           let index = pendingItems.firstIndex(where: { $0.id == activeDraftID }) {
            return index
        }
        return 0
    }

    private var activeItem: HomeItem? {
        guard let activeIndex else { return nil }
        return pendingItems[activeIndex]
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if !items.isEmpty {
                floatingBackplate(offset: 18, opacity: 0.16)
                floatingBackplate(offset: 9, opacity: 0.24)
            }

            VStack(alignment: .leading, spacing: 14) {
                panelHeader

                if items.isEmpty {
                    emptyState
                } else {
                    floatingDigestCard
                    reviewStack
                    resolvedList
                }
            }
            .padding(18)
            .background(panelBackground)
            .overlay(panelHighlight)
            .overlay(panelBorder)
            .shadow(color: Color.black.opacity(items.isEmpty ? 0.04 : 0.13), radius: items.isEmpty ? 8 : 26, x: 0, y: items.isEmpty ? 4 : 18)
            .shadow(color: AppColors.accent.opacity(items.isEmpty ? 0.02 : 0.20), radius: 30, x: 0, y: 0)
            .scaleEffect(isClearingResolved ? 0.86 : 1, anchor: .bottomTrailing)
            .offset(y: isClearingResolved ? 18 : 0)
            .opacity(isClearingResolved ? 0.46 : 1)
            .blur(radius: isClearingResolved ? 0.6 : 0)
        }
        .padding(.vertical, items.isEmpty ? 0 : 4)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: pendingItems.count)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: resolvedCount)
        .animation(.easeInOut(duration: 0.18), value: isClearingResolved)
        .onAppear(perform: normalizeActiveDraft)
        .onChange(of: pendingItems.map(\.id)) { _, _ in
            normalizeActiveDraft()
        }
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
                Button {
                    clearResolvedDrafts()
                } label: {
                    Label("\u{5B8C}\u{6210}\u{6574}\u{7406}\u{FF08}\(resolvedCount) \u{7B14}\u{FF09}", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(clearResolvedForeground)
                    .disabled(resolvedCount == 0)
            }
        }
    }

    private var floatingDigestCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.accent.opacity(0.14))
                Image(systemName: pendingItems.isEmpty ? "checkmark.seal.fill" : "doc.viewfinder")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
            .frame(width: 46, height: 46)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(pendingItems.isEmpty ? "这批账单已经收好" : "导入账单待整理")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text(floatingDigestText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(pendingItems.isEmpty ? "\(resolvedCount) 笔" : "\(pendingItems.count) 笔")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accentDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.12)))
        }
        .padding(14)
        .background(floatingDigestBackground)
        .overlay(floatingDigestBorder)
        .transition(.opacity.combined(with: .scale(scale: 0.96)).combined(with: .offset(y: 8)))
    }

    private var floatingDigestText: String {
        if pendingItems.isEmpty {
            return "确认后会进入正式账本，回放和统计会按真实记录继续计算。"
        }
        let total = pendingTotal.formatted(.cny.precision(.fractionLength(2)))
        return "合计 \(total)，先悬在这里，确认后会收进账本。"
    }

    private var floatingDigestBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(AppColors.panelStrong.opacity(0.82))
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.34),
                        AppColors.paperWarm.opacity(0.14),
                        AppColors.accent.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var floatingDigestBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.60),
                        AppColors.accent.opacity(0.24),
                        AppColors.line.opacity(0.50)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var panelSubtitle: String {
        if items.isEmpty {
            return "导入后会先放在这里，你可以再改分类、金额或删掉误识别。"
        }
        let total = pendingTotal.formatted(.cny.precision(.fractionLength(2)))
        return "\(pendingItems.count) 笔待整理 · 合计 \(total)"
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

    @ViewBuilder
    private var reviewStack: some View {
        if let activeIndex, let activeItem {
            VStack(spacing: 10) {
                reviewStackHeader(activeIndex: activeIndex)

                ZStack {
                    if pendingItems.indices.contains(activeIndex + 1) {
                        backgroundReviewCard(pendingItems[activeIndex + 1], label: "下一条")
                            .offset(y: 38)
                            .scaleEffect(0.94)
                            .opacity(0.42)
                    }

                    if pendingItems.indices.contains(activeIndex - 1) {
                        backgroundReviewCard(pendingItems[activeIndex - 1], label: "上一条")
                            .offset(y: -38)
                            .scaleEffect(0.94)
                            .opacity(0.32)
                    }

                    OCRDraftRow(
                        item: activeItem,
                        isFocused: true,
                        onToggleResolved: onToggleResolved,
                        onCategoryChange: onCategoryChange,
                        onAmountChange: onAmountChange,
                        onUpdateItem: onUpdateItem,
                        onDelete: onDelete
                    )
                    .zIndex(2)
                }
                .frame(minHeight: 368)
                .contentShape(Rectangle())

                reviewStackControls(activeIndex: activeIndex, activeItem: activeItem)
            }
            .padding(12)
            .background(reviewStackBackground)
        }
    }

    private func reviewStackHeader(activeIndex: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppColors.accent)
                .frame(width: 7, height: 7)
            Text("待整理")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accentDark.opacity(0.88))
            Text("\(activeIndex + 1) / \(pendingItems.count)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
            Spacer()
            reviewStackNavButton(systemName: "chevron.up", isEnabled: activeIndex > 0) {
                moveActiveDraft(by: -1)
            }
            reviewStackNavButton(systemName: "chevron.down", isEnabled: activeIndex < pendingItems.count - 1) {
                moveActiveDraft(by: 1)
            }
        }
    }

    private func reviewStackNavButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .foregroundStyle(isEnabled ? AppColors.text.opacity(0.82) : AppColors.subtext.opacity(0.34))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(isEnabled ? 0.58 : 0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.line.opacity(isEnabled ? 0.36 : 0.18), lineWidth: 1)
        )
    }

    private func backgroundReviewCard(_ item: HomeItem, label: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.accent.opacity(0.72))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.54)))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(0.72))
                    .lineLimit(1)
                Text(item.createdAt.zhBillDateTime)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.64))
            }
            Spacer()
            Text(item.amount.formatted(.cny.precision(.fractionLength(2))))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text.opacity(0.66))
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.56))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.accent.opacity(0.14), lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    private func reviewStackControls(activeIndex: Int, activeItem: HomeItem) -> some View {
        HStack(spacing: 10) {
            Button {
                moveActiveDraft(by: -1)
            } label: {
                Label("上一条", systemImage: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .disabled(activeIndex == 0)
            .foregroundStyle(activeIndex == 0 ? AppColors.subtext.opacity(0.44) : AppColors.text.opacity(0.80))
            .background(controlButtonBackground)

            Button {
                confirmActiveDraft(activeItem)
            } label: {
                Label("确认这一条", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.accent)
            )

            Button {
                moveActiveDraft(by: 1)
            } label: {
                Label("下一条", systemImage: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .disabled(activeIndex >= pendingItems.count - 1)
            .foregroundStyle(activeIndex >= pendingItems.count - 1 ? AppColors.subtext.opacity(0.44) : AppColors.text.opacity(0.80))
            .background(controlButtonBackground)
        }
    }

    private var controlButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.62))
    }

    private var reviewStackBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(AppColors.panelStrong.opacity(0.70))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.14), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var resolvedList: some View {
        if !resolvedItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("已整理列表")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.text.opacity(0.82))

                ForEach(resolvedItems) { item in
                    OCRDraftRow(
                        item: item,
                        isFocused: false,
                        onToggleResolved: onToggleResolved,
                        onCategoryChange: onCategoryChange,
                        onAmountChange: onAmountChange,
                        onUpdateItem: onUpdateItem,
                        onDelete: onDelete
                    )
                }
            }
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppColors.panelStrong.opacity(items.isEmpty ? 0.72 : 0.90))
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(items.isEmpty ? 0.12 : 0.42),
                        AppColors.accent.opacity(items.isEmpty ? 0.06 : 0.16),
                        AppColors.paperWarm.opacity(items.isEmpty ? 0.08 : 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var panelHighlight: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(items.isEmpty ? 0.34 : 0.62),
                        AppColors.accent.opacity(items.isEmpty ? 0.12 : 0.30),
                        Color.white.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .padding(0.5)
            .allowsHitTesting(false)
    }

    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(AppColors.accent.opacity(items.isEmpty ? 0.12 : 0.20), lineWidth: 1)
    }

    private func floatingBackplate(offset: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(AppColors.accent.opacity(opacity))
            .frame(maxWidth: .infinity)
            .frame(height: 86)
            .padding(.horizontal, offset)
            .offset(y: offset)
            .blur(radius: 0.3)
            .allowsHitTesting(false)
    }

    private func normalizeActiveDraft() {
        guard !pendingItems.isEmpty else {
            activeDraftID = nil
            return
        }
        if let activeDraftID, pendingItems.contains(where: { $0.id == activeDraftID }) {
            return
        }
        activeDraftID = pendingItems.first?.id
    }

    private func moveActiveDraft(by delta: Int) {
        guard let activeIndex else { return }
        let nextIndex = min(max(activeIndex + delta, 0), pendingItems.count - 1)
        guard nextIndex != activeIndex else { return }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            activeDraftID = pendingItems[nextIndex].id
        }
    }

    private func confirmActiveDraft(_ item: HomeItem) {
        let currentIndex = activeIndex ?? 0
        let nextCandidate: UUID? = pendingItems.indices.contains(currentIndex + 1)
            ? pendingItems[currentIndex + 1].id
            : pendingItems.indices.contains(currentIndex - 1)
                ? pendingItems[currentIndex - 1].id
                : nil
        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            activeDraftID = nextCandidate
        }
        onToggleResolved(item.id, true)
    }

    private func clearResolvedDrafts() {
        guard resolvedCount > 0, !isClearingResolved else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            isClearingResolved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onClearResolved()
            withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                isClearingResolved = false
            }
        }
    }
}

private struct OCRDraftRow: View {
    let item: HomeItem
    let isFocused: Bool
    let onToggleResolved: (UUID, Bool) -> Void
    let onCategoryChange: (UUID, HomeItem.Category) -> Void
    let onAmountChange: (UUID, Double) -> Void
    let onUpdateItem: (HomeItem) -> Void
    let onDelete: (UUID) -> Void

    @State private var amountText: String
    @State private var titleText: String
    @State private var selectedDate: Date
    @State private var isEditingAmount = false

    init(
        item: HomeItem,
        isFocused: Bool = false,
        onToggleResolved: @escaping (UUID, Bool) -> Void,
        onCategoryChange: @escaping (UUID, HomeItem.Category) -> Void,
        onAmountChange: @escaping (UUID, Double) -> Void,
        onUpdateItem: @escaping (HomeItem) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        self.item = item
        self.isFocused = isFocused
        self.onToggleResolved = onToggleResolved
        self.onCategoryChange = onCategoryChange
        self.onAmountChange = onAmountChange
        self.onUpdateItem = onUpdateItem
        self.onDelete = onDelete
        _amountText = State(initialValue: String(format: "%.2f", item.amount))
        _titleText = State(initialValue: item.title)
        _selectedDate = State(initialValue: item.createdAt)
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
            if isFocused {
                editableFields
            }
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
        .shadow(color: isFocused ? AppColors.accent.opacity(0.16) : Color.black.opacity(0.04), radius: isFocused ? 18 : 8, y: isFocused ? 10 : 4)
        .onChange(of: item.amount) { _, newValue in
            guard !isEditingAmount else { return }
            amountText = amountInputText(newValue)
        }
        .onChange(of: item.id) { _, _ in
            titleText = item.title
            selectedDate = item.createdAt
            amountText = amountInputText(item.amount)
            isEditingAmount = false
        }
        .onChange(of: item.title) { _, newValue in
            guard titleText != newValue else { return }
            titleText = newValue
        }
        .onChange(of: item.createdAt) { _, newValue in
            guard selectedDate != newValue else { return }
            selectedDate = newValue
        }
    }

    private var rowBackground: some View {
        let fill = isFocused ? Color.white.opacity(0.78) : (isResolved ? Color.white.opacity(0.46) : Color.white.opacity(0.68))
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(fill)
    }

    private var rowBorder: some View {
        let stroke = isFocused ? AppColors.accent.opacity(0.30) : (isResolved ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.52))
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
            Text(isFocused ? "当前账单" : item.title)
                .font(.system(size: isFocused ? 12 : 16, weight: isFocused ? .bold : .semibold))
                .foregroundStyle(AppColors.text)
                .lineLimit(isFocused ? 1 : 3)
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

    private var editableFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("备注")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.subtext.opacity(0.76))
                TextField("备注", text: $titleText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(inputBackground)
                    .onSubmit(commitTitle)
                    .onChange(of: titleText) { _, _ in
                        commitTitle()
                    }
            }

            DatePicker(
                "时间",
                selection: $selectedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.subtext.opacity(0.78))
            .datePickerStyle(.compact)
            .onChange(of: selectedDate) { _, _ in
                commitDate()
            }
        }
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.62))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.line.opacity(0.26), lineWidth: 1)
            )
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

    private func commitTitle() {
        let cleanTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty,
              cleanTitle != item.title else { return }
        var updated = item
        updated.title = cleanTitle
        updated.userEditedTitle = true
        onUpdateItem(updated)
    }

    private func commitDate() {
        guard abs(selectedDate.timeIntervalSince(item.createdAt)) >= 1 else { return }
        var updated = item
        updated.createdAt = selectedDate
        onUpdateItem(updated)
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
