# Agent Prompt · Task UI-P1 — iOS 叙事化（记账页 + 首页 · 仅 iOS）

> **状态：待做**  
> **战略**：Web 预览暂停拟真；**iOS 为真源**，本 PR 把已落地的 F1.3/B2.13 引擎 **展示成叙账气质**。  
> 设计北极星：[`RECORD_PAGE_DESIGN_v0.1.md`](RECORD_PAGE_DESIGN_v0.1.md)  
> 依赖：**F1.3 + B2.13 已 commit**（`RecordPrefillService`、`NarrativeCopyResolver`、`MerchantBrandCatalog`）  
> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview/` 本轮 **禁止改**（Web 仅作交互方向参考，勿双份维护）。

---

## 任务编号对照

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| F1.3 / B2.13 | 预填数据层 | `RecordPrefillService`、`NarrativeCopyResolver` | ✅ |
| **UI-P1** | **记账页叙事化** | `RecordView` + `LifeEntryPreviewCard` | ⏳ 本任务 |
| **UI-P1b** | **首页 Hero + 去重复回放** | `HomeView` + `HomeViewModel` | ⏳ 本任务（同 PR） |
| UI-P2 | 看看花列表视觉统一 | `StatsWebView` | 📋 未纳入 |

---

## 产品结论（Agent 须先理解）

**北极星句**：叙账的记账页应该像 **「把一段生活放进账本」**，不是 **「填写金额表单」**。

当前痛点（真机 / 模拟器）：

1. **RecordView** 仍是 web 表单克隆：`Text("金额")`、分类 grid、备注框、「保存记录」——与已 polish 的回放/切片气质割裂；F1.3/B2.13 预填有数据但 **藏在表单里**。
2. **HomeView** 仍是 KPI 风「今日已花 ¥xxx」；「今日小记」叙事弱；且 **回放入口可能重复**（大 CTA + 列表面板小钮并存时要去重）。
3. **今日小记副文案**：记 1 笔 / 3 笔 / 4 笔不应只剩数字变、句子不变——须按 **笔数分档** 生成 headline + subtitle。

**不动**：`addManualRecord` 业务规则、`PlaybackService` 播放时序、`SummaryPlaybackSheet` / `WeeklyShareCardView` 内核、OCR 确认 Sheet 结构、StoreKit。

---

## 🔒 冻结区（禁止改逻辑/布局内核）

```text
SummaryPlaybackSheet · PlaybackService 幕结构与时序
WeeklyShareCardView · 导出 PNG
BillPlaybackSheet 播放时序（可改 Sheet 外壳 copy，不改 tick 逻辑）
OCRConfirmSheet 结构
StoreKit · 会员权益逻辑
web-preview/ 任何文件
```

---

# Part A · 记账页 UI-P1

## 必做 A1 · `LifeEntryPreviewCard`（核心）

**新建** `NativeDemoApp/Views/Components/LifeEntryPreviewCard.swift`

**何时显示**：`hasValidAmount == true`

| 元素 | 来源 | 样式 |
|------|------|------|
| 主行 | `inputTitle` 非空 → 用之；否则 `MerchantBrandCatalog` displayName；否则 category soft fallback（如「餐饮的一小笔」） | 17–18pt semibold |
| 情绪胶囊 | `NarrativeCopyResolver.resolveEmotionTag` 预览（与保存同源 Context；seed = amount+date+category+brandId） | 复用 Home 列表 capsule |
| 次行 | `category.displayName` · `selectedDate` 简短时间 | 11–12pt muted |
| 金额 | corner，`inputAmount` formatted | **小于主行**，muted |

**交互**：

- 点卡片 → 展开「补充细节」（备注 TextField）
- 「改分类」→ toggle 现有 category chip grid（默认 **收起**）

**禁止**：KPI 报表风（不要「今日支出」「合计」做主行）。

---

## 必做 A2 · 金额「舞台」

**文件**：`RecordView.swift` — 替换 `amountField`

1. **删除** 对外标签 `Text("金额")`
2. 大号 `¥` + 数字为 **唯一默认焦点**
3. 保留 `amountKeyboardDock`、quick keys
4. 无金额时 subtitle：**「记下一笔今天的生活」**

---

## 必做 A3 · 表单折叠

`manualForm` 默认顺序（有金额）：

```text
1. 金额舞台
2. LifeEntryPreviewCard
3. 主 CTA「放进账本」
4. （折叠）分类 · 备注 · 场景包
```

- `categorySection`：默认隐藏 grid；预览次行 +「改分类」toggle
- `noteSection`：默认隐藏；预览卡点击或「补充细节」toggle
- `ScenePackSectionView`：**禁止删、禁止藏进深折叠**

---

## 必做 A4 · CTA 与页标题

1. 页顶 `Text("记账")` → **「记一笔」** 或 **「放进账本」**（全页统一）
2. `saveRow`：**「放进账本」**；minHeight ~52，非 mega 渐变提交感
3. `recordModeSegment`（手动/OCR）保留

---

## 必做 A5 · 预览 emotion 接线

**文件**：`RecordView` + `HomeViewModel`（只读暴露，不改 `addManualRecord`）

1. `recordPrefillResult` + `NarrativeCopyResolver` → 预览胶囊
2. 用户改金额/日期/备注 → 预览 **即时** 刷新
3. 保存后列表 `emotionTag` 与预览一致

---

## 必做 A6 · 一键备注 · 两态 + 品牌叠加

> 设计文档 §3.5「三态」在实现层收敛为：**主状态机 = 冷启动 ↔ 习惯**；**品牌 = 叠加层**（非与习惯并列的日常第三态）。

**主行 ≠ 胶囊**：

- 场景包 / 一键备注 → 写 **`inputTitle`** → 预览 **主行** 刷新
- 胶囊 → Resolver / 品牌池

| 条件 | 预览卡下方 UI |
|------|----------------|
| `recordPrefillResult?.source == "brand"` 或 `merchantBrandId != nil` | 小 link「换一句说法」 |
| `source == "habit"` 且 confidence ≥ 0.55 | 「✨ 换一句」 |
| 冷启动 / generic / confidence < 0.55 | **主角**「✨ 帮我写一句」 |

**验收**：

- [ ] 冷启动输入金额后仍一眼看到写一句入口
- [ ] 点场景包后 **预览主行变**，不是只改隐藏 TextField
- [ ] 瑞幸类品牌：可几乎直接「放进账本」；「换一句」仍可达

---

# Part B · 首页 UI-P1b

## 必做 B1 · Hero 改为「今日小记」（非 KPI）

**文件**：`HomeView.swift` + `HomeViewModel.swift`

**替换** 当前 Hero「今日已花 + 巨大金额」为叙式卡片：

```text
kicker:   今日小记
title:    按今日笔数分档（见下表）
subtitle: 按今日笔数分档（见下表）
foot:     今日合计 pill + 本周累计 pill（小字，非 Hero）
```

### 笔数分档文案（须在 `HomeViewModel` 集中实现，如 `todayStoryNarrative`）

| 笔数 | title | subtitle |
|------|-------|----------|
| 0 | 今天先记下来 | 晚上再回头看，这一天会慢慢有轮廓。 |
| 1 | 今天的第一笔小痕迹 | `{emotionTag}，这一天刚翻开第一页。`（取该笔 emotionTag，无则 Resolver/infer） |
| 2 | 今天已留下 2 段小痕迹 | 主要在「{topCategory}」上，轮廓慢慢变得具体。 |
| 3 | 今天留下了 3 段小痕迹 | 合计 {todayTotal}，几笔小账轻轻串起今天。 |
| 4+ | 今天留下了 {n} 段小痕迹 | 「{topCategory}」居多，几笔小账轻轻留住今天怎样过的。 |

`topCategory` = 今日各 category 金额最大者；格式化金额用现有 `formatted(.cny)`。

**禁止**：Hero 主视觉仍是 audit 式「今日已花 ¥大数字」。

---

## 必做 B2 · 双动作区 + 去重复回放

**替换** 当前单独 mega「＋ 快速记账」为 **等权双卡**（参考 Web 已验证布局，在 iOS 原生实现）：

| 左卡 | 右卡 |
|------|------|
| 记一笔 · 只输金额也可以 | 听今日回放 · 有记录后「十几秒叙完今天」 |

**删除**「今日账单」面板标题行里的 **「账单回放」小按钮**——全页只保留 **右卡** 一个回放入口。

`requestTodayPlayback()` / 配额 / `BillPlaybackSheet` 逻辑 **不变**，只改入口 UI。

首笔引导 toast（`firstRecordTodayPlayback`）可保留，不与右卡冲突。

---

## 必做 B3 · 面板 copy 轻对齐

- 「今日账单」→ **「今天留下的痕迹」**（仅标题 copy，列表行逻辑不动）
- 「近期生活节奏」卡片 **本 PR 可不动**

---

## 设计参考（只读）

```text
@NativeDemoApp/Views/InsightWebView.swift     → WeeklyShareCardView headline 层级
@NativeDemoApp/Views/HomeView.swift           → emotionTag capsule
@NativeDemoApp/Views/RecordView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Services/NarrativeCopyResolver.swift
@RECORD_PAGE_DESIGN_v0.1.md
```

Typography：叙 headline 22pt bold；生活主行 17pt semibold；muted 12pt；圆角 16–24 `glassPanel`。

---

## 禁止

- 改 `web-preview/`
- 删分类 / OCR / 场景包 / 预填能力
- 改 Playback / 分享图播放内核
- git commit（除非用户明确要求）

---

## 总验收

### 记账页

- [ ] 打开记账 Tab：无首屏「金额」标签 + 分类 grid 堆叠
- [ ] 输入 9.9：出现生活预览卡（主行 + 胶囊 + 次行 + corner 金额）
- [ ] 主按钮「放进账本」，非「保存记录」
- [ ] 分类/备注默认收起，B2.7 锁定仍有效
- [ ] 品牌/习惯/冷启动：一键备注 prominence 正确；点包后预览主行变
- [ ] OCR 切换与导入仍可用

### 首页

- [ ] Hero 为「今日小记」叙事，非「今日已花」大 KPI
- [ ] 记 1 / 2 / 3 / 4 笔时 title **与** subtitle **均有明显区别**
- [ ] 全页仅 **一个** 今日回放入口（右动作卡）；列表面板无重复小钮
- [ ] 记一笔左卡可跳转记账 Tab

### 问句

> 这是在帮用户把一段生活放进账本，还是在让他填一张表？

---

## @ 文件

```text
@RECORD_PAGE_DESIGN_v0.1.md
@AGENT_PROMPT_UI-P1_IOS.md
@NativeDemoApp/Views/RecordView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/Services/NarrativeCopyResolver.swift
@NativeDemoApp/Services/RecordPrefillService.swift
@NativeDemoApp/Views/ScenePackSectionView.swift
@NativeDemoApp/Views/InsightWebView.swift
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task UI-P1 + UI-P1b — iOS 叙事化（记账页 + 首页）**（仅 iOS；**同一 PR**）。

## 战略
Web 预览暂停拟真；**iOS 为真源**。F1.3/B2.13 引擎已落地，本 PR 把预填/品牌/情绪 **展示成叙账 UI**。
**禁止改 web-preview/**。

## 北极星句
叙账的记账页应该像「把一段生活放进账本」，不是「填写金额表单」。
详见 RECORD_PAGE_DESIGN_v0.1.md

## 执行顺序
1. **A1** — 新建 LifeEntryPreviewCard
2. **A2** — 金额舞台（删「金额」标签）
3. **A3** — 分类/备注/场景包默认折叠
4. **A4** — CTA「放进账本」+ 页标题
5. **A5** — 预览 emotion 接 NarrativeCopyResolver（不改 addManualRecord 规则）
6. **A6** — 一键备注：品牌叠加 / 习惯 / 冷启动 prominence
7. **B1** — 首页 Hero「今日小记」+ 笔数分档 narrative（HomeViewModel.todayStoryNarrative）
8. **B2** — 双动作卡（记一笔 + 听今日回放）；删列表面板重复回放钮
9. **B3** — 「今天留下的痕迹」标题 copy

## 必须先 Read
@RECORD_PAGE_DESIGN_v0.1.md
@AGENT_PROMPT_UI-P1_IOS.md
@NativeDemoApp/Views/RecordView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/Services/NarrativeCopyResolver.swift
@NativeDemoApp/Services/RecordPrefillService.swift
@NativeDemoApp/Views/ScenePackSectionView.swift

---

## Part A · 记账页

### A1 LifeEntryPreviewCard
新建 Views/Components/LifeEntryPreviewCard.swift
hasValidAmount 时：主行(inputTitle/brand/category fallback) + 情绪胶囊(Resolver) + 次行(分类·时间) + corner 金额(小于主行)
点卡片→展开备注；「改分类」→展开 chip grid

### A2 金额舞台
删 Text("金额")；大号¥+数字；无金额 subtitle「记下一笔今天的生活」

### A3 表单折叠
顺序：金额 → 预览卡 → 主 CTA →（折叠）分类/备注/场景包
禁止删 ScenePackSectionView

### A4 CTA
「保存记录」→「放进账本」；页顶「记账」→「记一笔」；按钮缩小

### A5 预览 emotion
recordPrefillResult + NarrativeCopyResolver 保存前展示；改金额/日期即时刷新

### A6 一键备注（主行≠胶囊）
| 条件 | UI |
| brand / merchantBrandId | 小 link「换一句说法」 |
| habit + confidence≥0.55 | 「✨ 换一句」 |
| 冷启动/generic/低置信 | 主角「✨ 帮我写一句」 |
场景包写 inputTitle → 预览主行即时更新

---

## Part B · 首页

### B1 今日小记 Hero（替换「今日已花」KPI）
HomeViewModel 实现 todayStoryNarrative：
- 0笔: 今天先记下来 / 晚上再回头看…
- 1笔: 今天的第一笔小痕迹 / {emotionTag}，这一天刚翻开第一页
- 2笔: 今天已留下 2 段小痕迹 / 主要在「{topCategory}」上…
- 3笔: 今天留下了 3 段小痕迹 / 合计 {todayTotal}，几笔小账轻轻串起今天
- 4+笔: 今天留下了 {n} 段小痕迹 / 「{topCategory}」居多…
foot: 今日合计 + 本周累计 小 pill

### B2 去重复回放
等权双卡：左「记一笔」右「听今日回放」
删除「今日账单」面板标题行「账单回放」小按钮；requestTodayPlayback 逻辑不变

### B3 copy
「今日账单」→「今天留下的痕迹」

---

## 🔒 冻结
SummaryPlaybackSheet、WeeklyShareCardView、BillPlaybackSheet 播放时序、OCRConfirmSheet 结构、StoreKit、web-preview

---

## 禁止
web-preview、删预填/OCR/场景包、playback 内核大改、git commit（除非用户要求）

---

## 验收

记账页：
- [ ] 无首屏表单堆叠；9.9 后有预览卡+胶囊
- [ ] 「放进账本」CTA；分类/备注可折叠；OCR 可用
- [ ] 冷启动见「帮我写一句」；点包后预览主行变

首页：
- [ ] Hero 叙式「今日小记」，非大 KPI 金额
- [ ] 1/2/3/4 笔 title+subtitle 均有区别
- [ ] 全页仅一个今日回放入口

问句：像放进账本，不像填表。

---

## 交付
1. 改动文件列表（A1–A6, B1–B3）
2. 前后对比 3 条
3. 验收勾选
4. 未做：UI-P2 看看花、OCR Sheet 叙事化、web-preview

最小 diff；优先 RecordView + LifeEntryPreviewCard + HomeView + HomeViewModel 叙事属性。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版：UI-P1 记账页 + UI-P1b 首页（今日小记分档、去重复回放）；Web 停拟真 |
