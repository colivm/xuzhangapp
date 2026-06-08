# Agent Prompt · Task ONB-MIN — 极简新手引导（仅 iOS）

> **状态：待做**  
> **战略**：打开 App 后 **1 张首启卡** + **首笔保存情境提示（回看）**；不搞开屏轮播、不搞多步 coach marks。  
> 闭环：**记一笔 → 放进账本 → 听今日回放**  
> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**（可留旧 demo 引导）。

---

## 任务编号对照

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| UI-P1 | 记账页叙事化 | `RecordView` | ✅ |
| **ONB-MIN** | **本 prompt · 极简引导** | `ContentView` + 新 Sheet + 设置接线 | ⏳ 本任务 |

---

## 产品结论（Agent 须先理解）

**只做三步闭环的教学，不做功能说明书。**

```text
① 首启 1 张卡  →  「记第一笔」（跳记账 Tab）
② 用户自己记账保存  →  不额外弹窗（UI-P1 已教）
③ 首笔保存后  →  情境提示带进「听今日回放」
```

**明确不做：**

- 开屏 Logo 后多图滑动轮播
- 3 张价值主张卡（收成 **1 张**）
- 记账页逐步高亮 / coach marks
- 单独讲 AI、隐私、分类、会员

**气质**：[`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) — 先叙后议；不是「1 分钟快速记账」工具 demo。

---

## 必做 1 · 首启单卡 `MinimalOnboardingSheet`

**新建** `NativeDemoApp/Views/MinimalOnboardingSheet.swift`

**展示时机**：App **首次安装后第一次进入** `ContentView`（`hasCompletedMinimalOnboarding == false`）

**UI（单屏，无分页）**：

| 元素 | 文案（定稿，可微调字号） |
|------|--------------------------|
| 标题 | **记一笔，今天就开始有轮廓** |
| 副文 | 只输金额也可以。记好后，晚上用十几秒叙完这一天。 |
| 主 CTA | **记第一笔** |
| 次 CTA | 跳过 |

**样式**：与现有 `glassPanel` / `AppColors.accent` 一致；全屏或 `.sheet` + 大圆角均可，须 **可跳过**、无强制等待。

**交互**：

- **记第一笔** → `hasCompletedMinimalOnboarding = true` → dismiss → `selectedTab = .record`
- **跳过** → `hasCompletedMinimalOnboarding = true` → dismiss → 停留首页

---

## 必做 2 · 持久化 flag

**推荐**：`UserDefaults` 独立 key，或 `AppSettings` 增字段（若增字段须 `LocalStore` 读写 + 默认值 `false`）

```text
key 建议: minimal_onboarding_completed_v1
```

- 完成 / 跳过后置 `true`
- **不**因删账单重置；仅设置「重新查看」可临时展示（见必做 4）

---

## 必做 3 · 第三步「回看」对齐现有情境提示

**已有逻辑（保留，仅对齐文案）**：

- `HomeViewModel.addManualRecord`：首笔 `wasEmpty` → `emitRouteGuidance(.firstRecordTodayPlayback)`
- `HomeView.handleRouteGuidance` → `firstRecordToast` + `requestTodayPlayback()`

**须统一文案**（`PlaybackRouteGuidance` + `HomeView.firstRecordToast` 与下面一致）：

| 位置 | 文案 |
|------|------|
| title | **用十几秒叙一下今天** |
| message / subtitle | **第一笔已经记好，听一遍今日回放。** |

**行为（本 PR 默认保持）**：

- 首笔保存回到首页后，toast 短暂出现；现有 **0.8s 后自动打开** `BillPlaybackSheet` 可保留
- 若实现时发现太突兀，可改为：**仅 toast，用户点「听今日回放」双卡打开** — 二选一，在交付说明里写清

**禁止**：改 `BillPlaybackSheet` / `PlaybackService` 播放时序内核。

---

## 必做 4 · 设置页「重新查看新手引导」

**文件**：`SettingsView.swift`

当前为 stub：`webButton("重新查看新手引导") { /* trigger guide overlay */ }`

**接线**：

1. `SettingsViewModel` 或 `ContentView` 增加 `@Published var showMinimalOnboarding = false`（或 Notification / callback，择一）
2. 设置按钮 → `showMinimalOnboarding = true`
3. 展示 **同一** `MinimalOnboardingSheet`
4. **重看不算首次**：可再次「记第一笔」跳记账 Tab；**不要**重置 `hasCompletedMinimalOnboarding` 为 false（避免每次启动又弹）
5. **不要**重放 `firstRecordTodayPlayback`（那是首笔一次性情境提示）

---

## 必做 5 · `ContentView` 挂载

- `.fullScreenCover` 或 `.sheet` 绑定 `showMinimalOnboarding`
- `onAppear`：若 `!hasCompletedMinimalOnboarding` → 展示首启卡
- 与宠物气泡、会员弹窗 **不打架**：首启卡优先；宠物首启可延后到引导关闭后（若已有 `pet` 首启逻辑）

---

## 禁止

- 开屏多图 Asset 轮播
- 改 `web-preview` 引导文案（本轮）
- 改 OCR / StoreKit / 播放 Sheet 内核
- git commit（除非用户明确要求）

---

## 验收

- [ ] 全新安装（或清空 flag）：首次打开见 **1 张** 首启卡，可跳过
- [ ] 点「记第一笔」→ 记账 Tab；输入金额可见 UI-P1 预览卡
- [ ] **不**在记账页额外弹 onboarding
- [ ] 首笔保存回首页 → 情境 toast/回放提示文案为「十几秒叙一下今天」
- [ ] 设置「重新查看新手引导」→ 再次展示 **同一** 首启卡
- [ ] 第二次冷启动 **不再** 自动弹首启卡
- [ ] 问句：像在教 **记→存→叙**，不像在读功能列表

---

## @ 文件

```text
@AGENT_PROMPT_ONBOARDING_MIN.md
@PRODUCT_NORTH_STAR.md
@NativeDemoApp/ContentView.swift
@NativeDemoApp/Views/SettingsView.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Services/LocalStore.swift
@NativeDemoApp/Models/AppSettings.swift
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task ONB-MIN — 极简新手引导**（仅 iOS；**同一 PR**）。

## 战略
只做三步闭环：记一笔 → 放进账本 → 听今日回放。
**1 张首启卡 + 首笔保存情境回看**；不做开屏轮播、不做多页说明书、不做记账 coach marks。
**禁止改 web-preview/**。

## 执行顺序
1. **必做 1** — 新建 MinimalOnboardingSheet（单屏）
2. **必做 2** — UserDefaults/AppSettings 持久化 hasCompletedMinimalOnboarding
3. **必做 5** — ContentView 首启挂载 + 记第一笔跳 .record
4. **必做 3** — 对齐 firstRecordTodayPlayback 文案（不改播放内核）
5. **必做 4** — SettingsView「重新查看新手引导」接同一 Sheet

## 必须先 Read
@AGENT_PROMPT_ONBOARDING_MIN.md
@PRODUCT_NORTH_STAR.md
@NativeDemoApp/ContentView.swift
@NativeDemoApp/Views/SettingsView.swift
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift

---

## 必做 1 · MinimalOnboardingSheet

新建 Views/MinimalOnboardingSheet.swift

单屏文案：
- 标题：记一笔，今天就开始有轮廓
- 副文：只输金额也可以。记好后，晚上用十几秒叙完这一天。
- 主 CTA：记第一笔 → dismiss + selectedTab = .record
- 次 CTA：跳过 → dismiss

glassPanel / AppColors 气质；无分页。

---

## 必做 2 · Flag

minimal_onboarding_completed_v1（UserDefaults 或 AppSettings+LocalStore）
完成/跳过后 true；删账单不重置。

---

## 必做 3 · 首笔回看（已有逻辑，只改文案）

HomeViewModel.PlaybackRouteGuidance.firstRecordTodayPlayback：
- title：用十几秒叙一下今天
- message：第一笔已经记好，听一遍今日回放。

HomeView.firstRecordToast 同步。

保留 emitRouteGuidance(.firstRecordTodayPlayback) 与 requestTodayPlayback；
0.8s 自动开 Sheet 可保留，或改为仅 toast（交付说明二选一）。

禁止改 BillPlaybackSheet / PlaybackService 时序。

---

## 必做 4 · 设置重看

SettingsView「重新查看新手引导」→ showMinimalOnboarding = true
展示同一 MinimalOnboardingSheet；不重置 completed flag；不重放首笔 toast。

---

## 必做 5 · ContentView

onAppear：!hasCompletedMinimalOnboarding → 展示 Sheet
与宠物首启错开（引导关后再宠物，若冲突）

---

## 🔒 冻结

BillPlaybackSheet 播放时序、PlaybackService、OCR、StoreKit、web-preview

---

## 禁止

开屏轮播、3 张卡、记账页 coach marks、web-preview、git commit（除非用户要求）

---

## 验收

- [ ] 首启 1 张卡，可跳过
- [ ] 记第一笔 → 记账 Tab
- [ ] 记账页无额外 onboarding
- [ ] 首笔保存 → 回看提示文案对齐
- [ ] 设置可重看同一卡
- [ ] 二次启动不自动弹
- [ ] 像教记→存→叙，不像功能列表

---

## 交付

1. 改动文件列表
2. 首启与首笔回看如何串联（3 条）
3. 自动开回放 Sheet 还是仅 toast（说明选择）
4. 验收勾选

最小 diff。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版：ONB-MIN 单卡首启 + 首笔回看 + 设置重看 |
