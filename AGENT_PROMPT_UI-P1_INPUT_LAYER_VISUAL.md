# Agent Prompt · Task UI-P1 — 记账页「生活放进账本」（仅 iOS）

> **状态：待做**  
> 设计北极星：[`RECORD_PAGE_DESIGN_v0.1.md`](RECORD_PAGE_DESIGN_v0.1.md) — **把一段生活放进账本，不是填写金额表单**  
> 依赖：**F1.3 + B2.13 已落地**（预填/品牌/情绪有数据可预览；无则 UI 仍成立）  
> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。

---

## 任务编号对照

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| F1.3 / B2.13 | 预填数据层 | `RecordPrefillService`、`NarrativeCopyResolver` | ✅ |
| **UI-P1** | **本 prompt · RecordView 叙事化** | `RecordView` + 新 Components | ⏳ 本任务 |
| UI-P1b | 首页 Hero 叙事化（可选同 PR 小 diff） | `HomeView` | 📋 可选 |
| UI-P2 | 看看花列表层视觉统一 | `StatsWebView` | 📋 未纳入 |

---

## 产品结论（Agent 须先理解）

当前 `RecordView` 仍是 **web recordPage 表单克隆**：`Text("金额")`、金额后展开分类 grid + 备注 TextField +「保存记录」——与已 polish 的 **账单回放 / 生活切片 / D1.1 分享图** 气质割裂。

**目标**：用户感受是 **确认一段生活**，不是提交字段。

**不动**：`HomeViewModel.addManualRecord`、`refreshRecordPrefill`、OCR 导入逻辑、播放 Sheet、分享卡。

---

## 🔒 冻结区（禁止改逻辑/布局内核）

```text
SummaryPlaybackSheet · PlaybackService 幕结构
WeeklyShareCardView · 导出 PNG
BillPlaybackSheet 播放时序
OCRConfirmSheet 结构（UI-P1 仅可改 Record 页内 OCR 入口 copy）
StoreKit · 会员权益逻辑
```

---

## 必做 1 · 生活预览卡 `LifeEntryPreviewCard`（核心）

**新建** `NativeDemoApp/Views/Components/LifeEntryPreviewCard.swift`

**何时显示**：`hasValidAmount == true`

**内容**（从上到下）：

| 元素 | 来源 | 样式 |
|------|------|------|
| 主行 | `inputTitle` 非空 → 用之；否则 brand displayName；否则 `selectedCategory.label + 「的一小笔」` 类 soft fallback | 17–18pt semibold，叙色 `AppColors.text` |
| 情绪胶囊 | 预览 emotion：调 `NarrativeCopyResolver.resolveEmotionTag`（与保存同源 Context；seed 用 amount+date+category） | 复用 Home 列表 capsule 样式 |
| 次行 | `category.displayName` · `selectedDate` 简短时间 | 11–12pt muted |
| 金额 | 右下角，`inputAmount` formatted | **小于主行**，rounded，muted——不是 Hero |

**交互**：

- 点卡片 → 展开「补充细节」（备注 TextField + chip）
- 分类旁 **「改」** → 展开现有 category chip grid（默认 **收起**）

**禁止**：卡片长得像 KPI 报表（不要「今日支出」「合计」）。

---

## 必做 2 · 金额「舞台」重构

**文件**：`RecordView.swift` — 替换 `amountField`

1. **删除** 对外标签 `Text("金额")`
2. 金额区：**大号 ¥ + 数字**，居中或偏上，作为 **唯一默认焦点**
3. 保留现有 `amountKeyboardDock`、quick keys 行为
4. 无金额时：subtitle 一句 — **「记下一笔今天的生活」**（或同类，过哲学问句）

---

## 必做 3 · 表单折叠（默认只认预览 + 金额）

**文件**：`RecordView.swift` — `manualForm`

默认（有金额）顺序：

```text
1. 金额舞台
2. LifeEntryPreviewCard
3. 主 CTA「放进账本」/「记下这一笔」
4. （折叠）分类 · 备注 · 场景包 · hints
```

1. `categorySection`：**默认隐藏** grid；预览卡次行显示当前分类 + Button「改分类」toggle
2. `noteSection`：**默认隐藏**；预览卡点击或「补充细节」toggle
3. `memberScenePackSection`：**禁止收进深折叠**。按三态接预览卡（见必做 6）
4. 删除/弱化 hints「数据仅保存在本机」首屏展示 → 收到设置或首次安装即可（可选删）

---

## 必做 6 · 一键备注 · 三态 prominence（不可删）

**文件**：`LifeEntryPreviewCard` + `RecordView` + 保留 `ScenePackSectionView`

**主行 vs 胶囊**：
- `applyScenePack` → 更新 `inputTitle` → **预览卡主行**刷新
- `emotionTag` 胶囊 → Resolver/品牌池，与场景包 **可并存**

**三态 UI**（`recordPrefillResult?.source` + brand match）：

| source / 态 | 预览卡下方 |
|-------------|------------|
| `brand` | 小 link「换一句说法」→ 调 `onQuickGenerate` |
| `habit` | 按钮「✨ 换一句」+ 可选展开场景包 |
| `generic` 或 confidence < 0.55 | **主按钮级**「✨ 帮我写一句」→ `onQuickGenerate`；无会员则引导会员或 note chips |

**验收**：
- [ ] 冷启动用户输入金额后 **仍一眼看到** 写一句的入口
- [ ] 点一键备注后 **预览主行变**，不是只改隐藏 TextField
- [ ] 瑞幸品牌态：可不放主角一键，但「换一句」仍可达

---

## 必做 4 · 主 CTA 与页标题

1. 页顶 `Text("记账")` → **「记一笔」** 或 **「放进账本」**（二选一，全页统一）
2. `saveRow` 按钮文案：**「放进账本」**；禁用态仍可见，非「保存记录」
3. 渐变按钮 **缩小** — minHeight ~52，不要 mega 表单提交感
4. `recordModeSegment`（手动/OCR）保留；样式可略收紧，**不删 OCR**

---

## 必做 5 · 预览 emotion 接线

**文件**：`HomeViewModel` 或 `RecordView`

1. `refreshRecordPrefill` 已有 `recordPrefillResult`；保存前应用 Resolver 预览 emotion（与 `addManualRecord` 一致）
2. 若 `recordPrefillResult?.emotionTag` 有值 → 预览卡展示
3. 无预填 → 仍可用 Resolver 基于 category+amount 生成 **预览** capsule（不必等保存）

**禁止**改 `addManualRecord` 业务规则，仅 **暴露只读预览** 给 UI。

---

## 可选 UI-P1b · 首页 Hero（同 PR 仅当 diff 小）

**文件**：`HomeView.swift`

- 「今日已花」→ 叙式 headline（如今日笔数 + 一句 hero subtitle，已有 `todayHeroSubtitle`）
- 「＋ 快速记账」mega 钮 → 与「账单回放」**同等权重** 双钮，或缩小 primary
- **不动** `BillPlaybackSheet`、列表行逻辑

可做可不做；不做不算 UI-P1 FAIL。

---

## 设计参考（只读，抽取语法）

```text
@NativeDemoApp/Views/InsightWebView.swift  → WeeklyShareCardView headline/subtitle 层级
@NativeDemoApp/Views/HomeView.swift        → emotionTag capsule 样式
@RECORD_PAGE_DESIGN_v0.1.md
@PRODUCT_NORTH_STAR.md §0
```

**Typography 建议**（与现有 App 一致，勿新字体）：

- 叙 headline：22pt bold
- 生活主行：17pt semibold
- muted：12pt `AppColors.subtext`
- 圆角：连续 16–24，沿用 `glassPanel`

---

## 禁止

- 改 web-preview
- 改 Playback / 分享图 / OCR 确认 Sheet 结构
- 删分类/OCR/场景包/预填能力
- 首页大改（除非 UI-P1b 且 diff 小）
- git commit 除非用户明确要求

---

## 验收

- [ ] 打开记账 Tab：**看不到**「金额」字段标签首屏堆表单
- [ ] 输入 9.9 后：出现 **生活预览卡**（主行+情绪胶囊+小字分类时间+ corner 金额）
- [ ] 主按钮是「放进账本」类文案，非「保存记录」
- [ ] 分类/备注 **默认收起**，可展开修改；B2.7 锁定仍有效
- [ ] 品牌/习惯预填后预览与保存条目 emotion 一致
- [ ] OCR 切换与导入流程 **仍可用**
- [ ] 品牌/习惯/冷启动：一键备注 prominence 符合三态
- [ ] 问句：像 **放进账本**，不像 **填表**

---

## @ 文件

```text
@RECORD_PAGE_DESIGN_v0.1.md
@AGENT_PROMPT_UI-P1_INPUT_LAYER_VISUAL.md
@NativeDemoApp/Views/RecordView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/Services/NarrativeCopyResolver.swift
@NativeDemoApp/Views/InsightWebView.swift
@PRODUCT_NORTH_STAR.md
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task UI-P1 — 记账页「生活放进账本」**（仅 iOS；**同一 PR**）。

## 北极星句
**叙账的记账页应该像「把一段生活放进账本」，不是「填写金额表单」。**

详见 RECORD_PAGE_DESIGN_v0.1.md

## 背景
RecordView 仍是 web 表单克隆（金额标签、分类 grid、保存记录）。F1.3/B2.13 预填已就绪，UI 须把叙事 **预览** 出来。playback/切片/分享图 **冻结不改**。

## 执行顺序
1. **必做 1** — LifeEntryPreviewCard 组件
2. **必做 2** — 金额舞台（删「金额」标签）
3. **必做 3** — 分类/备注/场景包默认折叠
4. **必做 4** — CTA「放进账本」+ 页标题
5. **必做 5** — 预览 emotion 接 NarrativeCopyResolver
6. **必做 6** — 一键备注三态 prominence（禁止删场景包）
7. **可选** — HomeView Hero 轻改（UI-P1b）

## 必须先 Read
@RECORD_PAGE_DESIGN_v0.1.md
@AGENT_PROMPT_UI-P1_INPUT_LAYER_VISUAL.md
@NativeDemoApp/Views/RecordView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Services/NarrativeCopyResolver.swift
@NativeDemoApp/Views/InsightWebView.swift
@NativeDemoApp/Views/HomeView.swift

---

## 必做 1 · LifeEntryPreviewCard

新建 Views/Components/LifeEntryPreviewCard.swift

hasValidAmount 时显示：
- 主行：inputTitle / brand displayName / category soft fallback
- 情绪胶囊：Resolver 预览（与保存同源）
- 次行：分类 · 时间
- 金额 corner，字号小于主行

点卡片 → 展开备注；「改分类」→ 展开 chip grid

---

## 必做 2 · 金额舞台

删 Text("金额") 标签；大号 ¥+数字为焦点；无金额时 subtitle「记下一笔今天的生活」

---

## 必做 3 · 表单折叠

manualForm 顺序：金额 → 预览卡 → 主 CTA →（折叠）分类/备注/场景包
categorySection、noteSection 默认 hidden，toggle 展开

---

## 必做 4 · CTA

「保存记录」→「放进账本」；按钮缩小；页顶「记账」→「记一笔」或「放进账本」

---

## 必做 5 · 预览 emotion

用 recordPrefillResult + NarrativeCopyResolver 在保存前展示 capsule；不改 addManualRecord 规则

---

## 必做 6 · 一键备注三态（禁止删场景包）

主行=inputTitle（场景包写这里）；胶囊=emotionTag（品牌/Resolver）

| source | UI |
| brand | 预览卡下小 link「换一句说法」 |
| habit | 「✨ 换一句」 |
| generic / 低置信 | 预览卡上主角「✨ 帮我写一句」 |

点一键/选包 → 预览主行即时更新。保留 ScenePackSectionView。

---

## 🔒 冻结

SummaryPlaybackSheet、WeeklyShareCardView、BillPlaybackSheet 播放逻辑、OCRConfirmSheet 结构、StoreKit

---

## 禁止

web-preview、删预填/OCR/场景包、playback 大改、git commit（除非用户要求）

---

## 验收

- [ ] 无首屏表单堆叠
- [ ] 9.9 输入后有生活预览卡+情绪胶囊
- [ ] 「放进账本」CTA
- [ ] 分类/备注可折叠修改，B2.7 有效
- [ ] OCR 仍可用
- [ ] 冷启动仍见「帮我写一句」；点一键后预览主行变
- [ ] 像放进账本，不像填表

---

## 交付

1. 改动文件列表
2. 前后对比说明（3 条）
3. 验收勾选
4. 未做：UI-P2 看看花、OCR Sheet 叙事化

最小 diff；只动 RecordView + 新 Component + 必要 ViewModel 预览暴露。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | 首版：记账页北极星 + LifeEntryPreviewCard + 表单折叠 |
