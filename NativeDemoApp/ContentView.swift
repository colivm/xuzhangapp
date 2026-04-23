import SwiftUI
import PhotosUI

struct ContentView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }

            RecordView()
                .tabItem {
                    Label("记账", systemImage: "plus.rectangle.on.rectangle")
                }

            StatsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }

            InsightView()
                .tabItem {
                    Label("AI复盘", systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .task {
            await homeViewModel.generateDailyInsight(
                userName: settingsViewModel.displayName,
                settings: settingsViewModel.settings
            )
        }
    }
}

struct RecordView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @State private var selectedEntryMode: EntryMode = .manual
    @State private var selectedPhoto: PhotosPickerItem?

    enum EntryMode: String, CaseIterable, Identifiable {
        case manual = "手动录入"
        case ocr = "OCR识票"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("方式", selection: $selectedEntryMode) {
                    ForEach(EntryMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if selectedEntryMode == .manual {
                    recordInputs
                } else {
                    Section("OCR 识别") {
                        Text("选择小票图片后将调用 Vision OCR 自动填充金额与分类。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label("选择小票图片", systemImage: "photo")
                        }
                        .buttonStyle(.borderedProminent)

                        Button("使用演示 OCR 记录") {
                            homeViewModel.addOCRDemoRecord()
                        }
                        .buttonStyle(.bordered)

                        if !homeViewModel.ocrStatus.isEmpty {
                            Text(homeViewModel.ocrStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("记账")
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        await homeViewModel.prefillFromOCR(imageData: data)
                    }
                }
            }
        }
    }

    private var recordInputs: some View {
        Group {
            Section("金额") {
                TextField("输入金额，例如 26.50", text: $homeViewModel.inputAmount)
                    .keyboardType(.decimalPad)
            }

            Section("分类") {
                Picker("分类", selection: $homeViewModel.selectedCategory) {
                    ForEach(HomeItem.Category.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
            }

            Section("描述与日期") {
                TextField("备注（如：午餐、地铁）", text: $homeViewModel.inputTitle)
                DatePicker("日期", selection: $homeViewModel.selectedDate, displayedComponents: [.date])
            }

            Section {
                Button("保存记录") {
                    homeViewModel.addManualRecord()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct StatsView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("周期", selection: $homeViewModel.selectedPeriod) {
                        ForEach(HomeViewModel.Period.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("分类支出占比") {
                    if homeViewModel.categorySummary.isEmpty {
                        Text("当前周期暂无记录。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(homeViewModel.categorySummary, id: \.category.id) { summary in
                            HStack {
                                Text(summary.category.rawValue)
                                Spacer()
                                Text(summary.amount.formatted(.currency(code: "CNY")))
                                    .fontWeight(.semibold)
                                Text("\(Int(summary.ratio * 100))%")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 45, alignment: .trailing)
                            }
                        }
                    }
                }

                Section("账单明细") {
                    ForEach(homeViewModel.periodItems) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.title)
                                Spacer()
                                Text(item.amount.formatted(.currency(code: "CNY")))
                                    .fontWeight(.medium)
                            }
                            Text("\(item.category.rawValue) · \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("统计")
            .listStyle(.insetGrouped)
        }
    }
}

struct InsightView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("今日消费复盘") {
                    if let insight = homeViewModel.todayInsight {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(insight.summary)
                            Text(insight.action)
                                .fontWeight(.semibold)
                            Text(insight.encourage)
                                .foregroundStyle(.secondary)
                        }
                        .font(.body)
                        .padding(.vertical, 4)
                    } else {
                        Text("还没有今日复盘，点击下方按钮生成。")
                            .foregroundStyle(.secondary)
                    }

                    Button("重新生成今日建议") {
                        Task {
                            await homeViewModel.regenerateTodayInsight(
                                userName: settingsViewModel.displayName,
                                settings: settingsViewModel.settings
                            )
                        }
                    }

                    if homeViewModel.isGeneratingInsight {
                        ProgressView("AI 正在生成中...")
                    }
                    if let errorMessage = homeViewModel.insightErrorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Prompt 模板示例") {
                    Text(
                        HomeViewModel.promptTemplate(
                            todayTotal: homeViewModel.recentThreeItems.reduce(0) { $0 + $1.amount },
                            weeklyAverage: 0,
                            monthlyTotal: homeViewModel.monthExpenseTotal,
                            topCategories: homeViewModel.categorySummary.prefix(3).map(\.category.rawValue).joined(separator: "、")
                        )
                    )
                    .font(.caption)
                    .textSelection(.enabled)
                }

                Section("历史复盘") {
                    if homeViewModel.insights.isEmpty {
                        Text("暂无历史复盘。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(homeViewModel.insights.prefix(30)) { insight in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(insight.dayKey)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(insight.summary)
                                Text(insight.action)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("AI复盘")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsViewModel())
        .environmentObject(HomeViewModel())
}
