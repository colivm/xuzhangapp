# Agent Prompt · Task UI-P1.3-iOS-SMALL — 顶栏 / 新建补记日期 / 首页文案（小 PR · 仅 iOS）

> **状态：待做 · 走查落地 · 改动面小**  
> **范围**：`ContentView.swift` · `RecordView.swift` · `HomeView.swift` + 可选新建 `WarmRecordDatePanel.swift`  
> **不动**：痕迹页 / 复盘页 / 设置 / 会员 / 文案引擎 / Web  
> 用法：**整段复制同目录 `AGENT_PROMPT_UI-P1.3_IOS_SMALL_POLISH_COPY.txt`**

---

## 0. 一句话

修三个「小但扎眼」的 demo 残留：**顶栏小字语义**、**新建补记日期与编辑不一致**、**首页动作卡与 Tab 文案不统一**。

---

## 1. 背景（代码已证实）

| 问题 | 位置 | 现状 |
|------|------|------|
| 顶栏小字永远「今天」 | `ContentView.topBar` ~220 | 非首页 Tab 语义冲突 |
| 新建用系统 DatePicker + 浮动日历 | `RecordView` ~348 sheet + ~903 浮动钮 | 编辑已用 `RecordEditSheet.warmCalendar` |
| 首页「记一笔」 | `HomeView` ~22 | Tab 定稿「记下」 |

编辑路径 `RecordEditSheet` 已是 life-slip + 暖日历 + quiet「改日期」——**新建应对齐，不要两套**。

---

## 2. 范围与禁止

**可改**：
- `NativeDemoApp/ContentView.swift`（仅 `topBar` / `AppTab` 辅助属性）
- `NativeDemoApp/Views/RecordView.swift`
- `NativeDemoApp/Views/HomeView.swift`（仅动作卡 title 一行）
- 新建 `NativeDemoApp/Views/Components/WarmRecordDatePanel.swift`（从 `RecordEditSheet` 抽取，推荐）
- `RecordEditSheet` 改为引用共享组件（若抽取）

**禁止**：
- 改 `RecordPrefillService` / `NarrativeCopyResolver` / tier 判定 / 保存业务规则
- 改痕迹页、复盘页、设置、会员
- 把编辑迁回 `RecordView`（本 PR 不做架构合并）
- `web-preview/` · `backend/`
- git commit（除非用户明确要求）

---

## 3. 任务 A · 顶栏小字按 Tab 变化

`topBar` 第一行小字 **不要** 固定 `Text("今天")`。

**推荐**：用 `selectedTab.title`（与底栏 Tab 名一致）：

| Tab | 小字 | 大标题（已有 `pageTitle`） |
|-----|------|---------------------------|
| 今天 | 今天 | 今日 |
| 记下 | 记下 | 记下这一笔 |
| 痕迹 | 痕迹 | 账单与切片 |
| 复盘 | 复盘 | 生活复盘 |
| 我的 | 我的 | 设置 |

实现：在 `AppTab` 加 `kicker: String`（或复用 `title`），`topBar` 绑定即可。样式保持 12pt medium subtext，**不改**大标题字号与 Tab 栏。

---

## 4. 任务 B · 新建补记日期对齐编辑暖日历

### 4.1 删除（新建路径）

- `RecordView` 中 `.sheet(isPresented: $showRecordDateSheet)` 的 **系统** `DatePicker(.graphical)` 整段
- `saveRow` 里 `放进账本` 按钮右上 **浮动** `Image(systemName: "calendar")` 及 `offset` 叠层
- `@State showRecordDateSheet`（若不再需要）

### 4.2 新增（对齐 `RecordEditSheet`）

- 抽取 **`WarmRecordDatePanel`**：`Binding<Date>` + 月切换 + 日 grid + 时/分 stepper + 暖色底（从 `RecordEditSheet.warmCalendar` 及 helper 迁出，**视觉与交互一致**）
- `RecordView` 增加 `@State private var datePanelExpanded = false`
- 增加 quiet link **「改日期」**（12pt accent link，与编辑 `quietLink("改日期")` 同气质）
- 点击 toggle `datePanelExpanded`；展开时在 **life-slip 下方或 saveRow 上方** inline 显示 `WarmRecordDatePanel`（**不要** sheet、不要系统控件）
- 默认 **折叠**；仅用户点「改日期」才展开
- `homeViewModel.selectedDate` 仍为唯一日期源；变更后刷新 `previewCardMeta`

### 4.3 「改日期」放哪

**优先**：saveRow 下方一行 secondary quiet actions，仅 `改日期`（与编辑 foot 一致，不抢「放进账本」）。

**禁止**：saveRow 上再挂圆形日历 icon。

### 4.4 RecordEditSheet

若已抽取组件，`RecordEditSheet` 内 `warmCalendar` 改为 `WarmRecordDatePanel(selection: $selectedDate, calendarMonth: $calendarMonth)`，避免双份实现。

---

## 5. 任务 C · 首页动作卡文案

`HomeView` 双动作卡左侧：

```text
「记一笔」 → 「记下一笔」
```

subtitle「只输金额也可以」**保留**。右侧「听今日回放」不动。

---

## 6. 验收

- [ ] 切到痕迹/复盘/设置：顶栏小字 **不是**「今天」
- [ ] 新建记账：无系统 graphical DatePicker sheet；saveRow **无**浮动日历 icon
- [ ] 点「改日期」→ inline 暖日历；默认折叠；选日期后 meta 更新
- [ ] 编辑账单暖日历仍正常（若抽组件则共用）
- [ ] 首页左卡为「记下一笔」
- [ ] life-slip / 放进账本 / OCR 侧门 / tier **零回归**

---

## 7. @ 文件

```text
@AGENT_PROMPT_UI-P1.3_IOS_SMALL_POLISH.md
@NativeDemoApp/ContentView.swift
@NativeDemoApp/Views/RecordView.swift
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/ContentView.swift（RecordEditSheet · warmCalendar 参考）
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 走查小 PR 合并：顶栏 + 新建暖日历 + 首页文案 |
