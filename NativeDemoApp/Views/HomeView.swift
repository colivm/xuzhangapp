import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatCardView(
                        title: "欢迎回来",
                        value: settingsViewModel.displayName,
                        iconName: "person.crop.circle.fill"
                    )
                    StatCardView(
                        title: "本月总支出",
                        value: homeViewModel.monthExpenseTotal.formatted(.currency(code: "CNY")),
                        iconName: "creditcard.fill"
                    )
                }
                .listRowSeparator(.hidden)

                Section("快捷操作") {
                    Button("手动记账") {
                        homeViewModel.inputTitle = "午餐"
                        homeViewModel.inputAmount = "26.5"
                        homeViewModel.selectedCategory = .dining
                        homeViewModel.addManualRecord()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("OCR 识票（演示）") {
                        homeViewModel.addOCRDemoRecord()
                    }
                    .buttonStyle(.bordered)
                }

                Section("最近 3 笔消费") {
                    if homeViewModel.recentThreeItems.isEmpty {
                        Text("暂无数据，先添加一条吧。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(homeViewModel.recentThreeItems) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.title)
                                        .font(.body)
                                    Spacer()
                                    Text(item.amount.formatted(.currency(code: "CNY")))
                                        .fontWeight(.semibold)
                                }
                                Text("\(item.category.rawValue) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("今日 AI 消费小结") {
                    if let insight = homeViewModel.todayInsight {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(insight.summary)
                            Text(insight.action)
                                .fontWeight(.medium)
                            Text(insight.encourage)
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    } else {
                        Text("今日复盘尚未生成。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("首页")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(HomeViewModel())
        .environmentObject(SettingsViewModel())
}
