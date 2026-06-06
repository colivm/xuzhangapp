# NativeDemoApp (iOS 17+)

一个从零搭建的 SwiftUI 原生 iOS App 示例（叙账 v0.1），包含：

- 底部 `TabBar`（首页 / 记账 / 统计 / AI复盘 / 设置）
- 手动记账 + OCR 占位识别流程
- 本地统计（本周 / 本月）
- 每日 AI 复盘（温和文案生成）
- 本地数据存储（`UserDefaults` + 本地 JSON 文件）
- 深色模式适配（系统/浅色/深色）
- 可选同步开关占位（默认关闭）
- 远程 AI Key 使用 iOS Keychain 保存（不写入本地明文设置）
- 远程 AI 月度调用上限控制（默认 120 次）

## 目录结构

```text
NativeDemoApp.xcodeproj
NativeDemoApp
├── NativeDemoAppApp.swift
├── ContentView.swift          # Tab 壳 ~702 行
├── Info.plist
├── Assets.xcassets
├── Models/
├── Services/
├── ViewModels/
└── Views/
    ├── HomeView.swift
    ├── RecordView.swift
    ├── StatsWebView.swift
    ├── InsightWebView.swift   # 小 AI 说 Tab
    ├── SettingsView.swift
    └── Components/
```

## 在 Xcode 运行

1. 在 macOS 上安装 Xcode 15+。
2. 打开 `NativeDemoApp.xcodeproj`。
3. 选择 `iPhone 15`（或任意 iOS 17+ 模拟器）。
4. `Cmd + R` 运行。

## 功能说明（v0.1）

- 首页展示本月支出、最近消费，并支持快捷添加。
- 记账页支持手动录入，OCR 流程提供演示占位。
- 统计页展示分类占比与周期账单明细。
- AI 复盘页支持每日建议生成与历史查看。
- 设置页支持主题、语气、Face ID 开关与同步开关占位。

## 产品文档

- **`PRODUCT_NORTH_STAR.md`**：产品北极星（生活回望、叙/账、先叙后议、NSM 与评审原则）。
- **`APP_STORE_LISTING.md`**：App Store 名称/副标题、截图顺序与上架自检。
- **`IMPLEMENTATION_FOR_CODEX.md`**：给 Codex/Agent 的分任务实现单（代码锚点、禁止项、验收）。
- **`PROJECT_SETUP.md`**：项目搭建总览（本机开发、生产 ECS、Staging、iOS 联调）。
- `PROJECT_ANALYSIS.md`：架构分析与完成度评估。
- `STAGING_ENV_SETUP.md`：同机 Staging 部署与分支发版流程。
- `PRD_v0.1.md`：页面清单、字段设计、Prompt 模板与技术结构说明。
- **`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`**：生活切片、今日回放、场景包、OCR 与免费/会员权益设计。
- `API_v0.1.md`：AI 日报与可选同步接口草案。
- `TODO.md`：进度与上线清单。
- `ai-proxy/README.md`：最小后端代理部署说明（推荐生产使用）。
- `NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md`：iOS 真实接入所需参数、账号和验收标准。
- `NativeDemoApp/AppSecrets.example.plist`：生产配置模板（复制为 `AppSecrets.plist` 后填真实值）。
- `backend/README.md`：iOS 迁移期的后端骨架（auth/member/ledger/iap/ai）。
