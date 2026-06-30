import SwiftUI

struct TraceInlineRecordEditor: View {
    let item: HomeItem
    var autoCommitRequestID: UUID?
    var onSave: (HomeItem) -> Bool
    var onCancel: () -> Void

    @State private var amountText: String
    @State private var titleText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
    @State private var validationMessage: String?
    @State private var isCategoryPanelExpanded = false
    @State private var isDatePopoverVisible = false
    @State private var isSpecificDatePanelVisible = false
    @FocusState private var focusedField: InlineEditField?

    private enum InlineEditField {
        case amount
        case title
    }

    init(
        item: HomeItem,
        autoCommitRequestID: UUID? = nil,
        onSave: @escaping (HomeItem) -> Bool,
        onCancel: @escaping () -> Void
    ) {
        self.item = item
        self.autoCommitRequestID = autoCommitRequestID
        self.onSave = onSave
        self.onCancel = onCancel
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

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                amountField
                    .layoutPriority(1)
                categorySelector
                    .frame(width: 112)
            }

            TextField("这一笔想怎么被记住？", text: $titleText)
                .font(.system(size: 15))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(inlineFieldChrome)
                .focused($focusedField, equals: .title)
                .onChange(of: titleText) { _, value in
                    if value.count > 32 {
                        titleText = String(value.prefix(32))
                    }
                    validationMessage = nil
                }

            inlineDateSelector

            if isCategoryPanelExpanded {
                categoryGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 94/255, green: 108/255, blue: 119/255))
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("取消") {
                    onCancel()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 82/255, green: 94/255, blue: 104/255))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(inlineSecondaryButtonBackground)

                Button {
                    save()
                } label: {
                    Text("保存")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            AppColors.accent,
                            in: Capsule(style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(parsedAmount <= 0)
                .opacity(parsedAmount <= 0 ? 0.55 : 1)
            }
        }
        .padding(.top, -6)
        .onChange(of: autoCommitRequestID) { _, requestID in
            guard requestID != nil else { return }
            softCommitAndCollapse()
        }
    }

    private var amountField: some View {
        HStack(spacing: 3) {
            Text("¥")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 85/255, green: 99/255, blue: 110/255))
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .focused($focusedField, equals: .amount)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(inlineFieldChrome)
    }

    private var categorySelector: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isDatePopoverVisible = false
                isSpecificDatePanelVisible = false
                isCategoryPanelExpanded.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Text(selectedCategory.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(AppColors.text.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(inlineFieldChrome)
        }
        .buttonStyle(.plain)
    }

    private var inlineDateSelector: some View {
        Button {
            withAnimation(traceInlinePopoverSpring) {
                isCategoryPanelExpanded = false
                isSpecificDatePanelVisible = false
                isDatePopoverVisible.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text("时间")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 85/255, green: 99/255, blue: 110/255))
                Spacer()
                Text(selectedDate.zhBillDateTime)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 85/255, green: 99/255, blue: 110/255))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(inlineFieldChrome)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if isDatePopoverVisible {
                traceDatePopover
                    .offset(x: -2, y: -118)
                    .zIndex(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
            }
        }
        .zIndex(isDatePopoverVisible ? 20 : 0)
    }

    private var traceDatePopover: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                traceDateQuickButton("今天") {
                    applyQuickDate(.today)
                }
                traceDateQuickButton("昨天") {
                    applyQuickDate(.yesterday)
                }
                traceDateQuickButton("现在") {
                    selectedDate = Date()
                    closeDatePopover()
                }
            }

            Button {
                withAnimation(traceInlinePopoverSpring) {
                    isSpecificDatePanelVisible.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                    Text("具体时间")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(isSpecificDatePanelVisible ? 180 : 0))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.80))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.56))
                )
            }
            .buttonStyle(.plain)

            if isSpecificDatePanelVisible {
                WarmRecordDatePanel(selection: $selectedDate)
                    .frame(width: 250)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topTrailing)))
            }
        }
        .padding(10)
        .frame(width: isSpecificDatePanelVisible ? 274 : 238, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(AppColors.paperWarm.opacity(0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private func traceDateQuickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.62))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppColors.accent.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private enum TraceQuickDate {
        case today
        case yesterday
    }

    private func applyQuickDate(_ quickDate: TraceQuickDate) {
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute, .second], from: selectedDate)
        let base: Date
        switch quickDate {
        case .today:
            base = Date()
        case .yesterday:
            base = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        }
        let day = calendar.startOfDay(for: base)
        selectedDate = calendar.date(
            bySettingHour: currentComponents.hour ?? calendar.component(.hour, from: Date()),
            minute: currentComponents.minute ?? calendar.component(.minute, from: Date()),
            second: currentComponents.second ?? 0,
            of: day
        ) ?? base
        closeDatePopover()
    }

    private func closeDatePopover() {
        withAnimation(traceInlinePopoverSpring) {
            isDatePopoverVisible = false
            isSpecificDatePanelVisible = false
        }
    }

    private var traceInlinePopoverSpring: Animation {
        .spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.06)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82, maximum: 128), spacing: 8)], spacing: 8) {
            ForEach(HomeItem.Category.allCases) { category in
                categoryGridButton(category)
            }
        }
    }

    private func categoryGridButton(_ category: HomeItem.Category) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
            withAnimation(.easeInOut(duration: 0.18)) {
                isCategoryPanelExpanded = false
            }
        } label: {
            Text(category.displayName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppColors.text : AppColors.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(categoryGridButtonBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    private func categoryGridButtonBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isSelected ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppColors.accent.opacity(0.34) : Color.white.opacity(0.38), lineWidth: 1)
            )
    }

    private var inlineFieldChrome: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.74))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.86), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.accent.opacity(0.28))
                    .frame(height: 1)
                    .padding(.horizontal, 10)
            }
    }

    private var inlineSecondaryButtonBackground: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.76))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.80), lineWidth: 1)
            )
            .shadow(color: AppColors.subtext.opacity(0.07), radius: 7, x: 0, y: 3)
    }

    private func save() {
        var updated = item
        updated.amount = parsedAmount
        updated.title = cleanTitle.isEmpty ? selectedCategory.defaultRecordTitle : cleanTitle
        updated.category = selectedCategory
        updated.createdAt = selectedDate
        updated.updatedAt = Date()
        if !onSave(updated) {
            validationMessage = "这句备注里可能有隐私信息，先改成更简单的记录。"
        }
    }

    private func softCommitAndCollapse() {
        focusedField = nil
        guard parsedAmount > 0 else {
            validationMessage = "金额先留在这里，补完整再收起。"
            return
        }
        save()
    }
}

