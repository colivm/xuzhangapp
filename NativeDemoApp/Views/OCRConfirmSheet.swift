import SwiftUI

struct OCRConfirmSheet: View {
    private struct ConfirmRow: Identifiable {
        let id: UUID
        var draft: OCRReceiptDraft
        var selected: Bool
    }

    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ConfirmRow]
    @State private var batchCategory: HomeItem.Category = .dining

    let onConfirm: ([OCRReceiptDraft]) -> Int

    init(drafts: [OCRReceiptDraft], onConfirm: @escaping ([OCRReceiptDraft]) -> Int) {
        _rows = State(initialValue: drafts.map { ConfirmRow(id: $0.id, draft: $0, selected: true) })
        self.onConfirm = onConfirm
    }

    private var selectedRows: [ConfirmRow] {
        rows.filter(\.selected)
    }

    private var selectedTotal: Double {
        selectedRows.reduce(0) { $0 + $1.draft.amount }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
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

                        toolbar

                        VStack(spacing: 10) {
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
                .background(.ultraThinMaterial)
            }
            .navigationTitle("待确认账单")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button("全选") {
                    for index in rows.indices {
                        rows[index].selected = true
                    }
                }
                Button("反选") {
                    for index in rows.indices {
                        rows[index].selected.toggle()
                    }
                }
                Spacer()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.accent)

            HStack {
                Text("把已选账单改为")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
                Picker("批量修改分类", selection: $batchCategory) {
                    ForEach(HomeItem.Category.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: batchCategory) { _, category in
                    for index in rows.indices where rows[index].selected {
                        rows[index].draft.category = category
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.66))
        )
    }

    private func confirmRow(_ index: Int) -> some View {
        let row = rows[index]
        return VStack(alignment: .leading, spacing: 12) {
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
                    Text(row.draft.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(3)

                    Text(row.draft.date.zhBillDateTime)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }

                Spacer(minLength: 8)

                Text(row.draft.amount.formatted(.cny.precision(.fractionLength(2))))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .minimumScaleFactor(0.75)
            }

            HStack(spacing: 10) {
                Text("分类")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                Picker("分类", selection: $rows[index].draft.category) {
                    ForEach(HomeItem.Category.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 13, weight: .medium))

                Spacer()

                Text(row.selected ? "将导入" : "已跳过")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(row.selected ? AppColors.accent : AppColors.subtext)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(row.selected ? AppColors.accent.opacity(0.08) : Color.white.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(row.selected ? AppColors.accent.opacity(0.24) : Color.white.opacity(0.45), lineWidth: 1)
        )
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
    let onDelete: (UUID) -> Void
    let onClearResolved: () -> Void

    private var visibleGroups: [(key: String, importedAt: Date, items: [HomeItem])] {
        let grouped = Dictionary(grouping: items) { item in
            item.draftMeta?.batchId ?? item.id.uuidString
        }
        return grouped.map { key, batchItems in
            let importedAt = batchItems.first?.draftMeta?.importedAt ?? batchItems.first?.createdAt ?? .now
            return (key: key, importedAt: importedAt, items: batchItems.sorted { $0.createdAt > $1.createdAt })
        }
        .sorted { $0.importedAt > $1.importedAt }
        .prefix(3)
        .map { $0 }
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
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("待整理账单")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text(items.isEmpty ? "导入后会先放在这里，你可以再改分类、金额或删掉误识别。" : "\(pendingItems.count) 笔待整理 · 合计 \(pendingTotal.formatted(.cny.precision(.fractionLength(2))))")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                }
                Spacer()
                Button("收起已整理") { onClearResolved() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(resolvedCount > 0 ? AppColors.accent : AppColors.subtext.opacity(0.45))
                    .disabled(resolvedCount == 0)
            }

            if items.isEmpty {
                Text("选择账单截图后，识别结果会先进入确认页；确认导入后，会出现在这里继续整理。")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.subtext)
                    .frame(maxWidth: .infinity, minHeight: 108)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.58))
                    )
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(visibleGroups, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("导入于 \(group.importedAt.zhBillDateTime)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.subtext)
                            ForEach(group.items) { item in
                                OCRDraftRow(
                                    item: item,
                                    onToggleResolved: onToggleResolved,
                                    onCategoryChange: onCategoryChange,
                                    onAmountChange: onAmountChange
                                )
                                .overlay(alignment: .topTrailing) {
                                    Button(role: .destructive) {
                                        onDelete(item.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppColors.subtext.opacity(0.8))
                                            .frame(width: 30, height: 30)
                                            .background(Color.white.opacity(0.58), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(10)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.accent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.accent.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct OCRDraftRow: View {
    let item: HomeItem
    let onToggleResolved: (UUID, Bool) -> Void
    let onCategoryChange: (UUID, HomeItem.Category) -> Void
    let onAmountChange: (UUID, Double) -> Void

    @State private var amountText: String

    init(
        item: HomeItem,
        onToggleResolved: @escaping (UUID, Bool) -> Void,
        onCategoryChange: @escaping (UUID, HomeItem.Category) -> Void,
        onAmountChange: @escaping (UUID, Double) -> Void
    ) {
        self.item = item
        self.onToggleResolved = onToggleResolved
        self.onCategoryChange = onCategoryChange
        self.onAmountChange = onAmountChange
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
            amountEditor
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isResolved ? Color.white.opacity(0.46) : Color.white.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isResolved ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.52), lineWidth: 1)
        )
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
        Text(item.amount.formatted(.cny.precision(.fractionLength(2))))
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(AppColors.text)
            .minimumScaleFactor(0.75)
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
        }
    }

    private var categoryPicker: some View {
        Picker("分类", selection: Binding(
            get: { item.category },
            set: { onCategoryChange(item.id, $0) }
        )) {
            ForEach(HomeItem.Category.allCases) { category in
                Text(category.displayName).tag(category)
            }
        }
        .pickerStyle(.menu)
        .font(.system(size: 12))
    }

    private var amountEditor: some View {
        TextField("金额", text: $amountText)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(AppColors.text)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
            .onSubmit { commitAmount() }
            .onChange(of: amountText) { _, newValue in
                guard let value = Double(newValue.replacingOccurrences(of: ",", with: "")), value > 0 else { return }
                onAmountChange(item.id, value)
            }
    }

    private func commitAmount() {
        guard let value = Double(amountText.replacingOccurrences(of: ",", with: "")), value > 0 else { return }
        onAmountChange(item.id, value)
    }
}
