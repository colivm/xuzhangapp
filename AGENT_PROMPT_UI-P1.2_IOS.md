# Agent Prompt · Task UI-P1.2-iOS — 记账页：只迁交互结构 + 视觉层级（仅 iOS）

> **状态：待做 · 当前 iOS 记账页 Agent prompt**  
> **迁什么**：L0/L1/L2 **展示分层**、life-slip **视觉层级**、安静 link 操作、OCR 侧门、首屏信息架构  
> **不迁什么**：Web 文案、耳语池、品牌句、场景包 tagline；**iOS 文案引擎一字不改**  
> **范围**：仅 `NativeDemoApp/` 记账页 View 层；**禁止改** `web-preview/`  
> 用法：整段复制 `AGENT_PROMPT_UI-P1.2_IOS_COPY.txt`

---

## 0. 本 PR 边界（创始人拍板）

```text
从 Web 迁：交互结构 + 视觉层级
从 Web 不迁：任何叙事文案与引擎产出
```

**文案引擎冻结**（只读、只接线，不改内容、不改算法）：

```text
RecordPrefillService.swift
NarrativeCopyResolver.swift
MerchantBrandCatalog.swift
ScenePackCopyPool.swift（含 rules / notes / label / desc）
HomeViewModel.refreshRecordPrefill / addManualRecord 写入逻辑
```

主行、胶囊、场景句、品牌句、习惯句 **继续走 iOS 现有 `previewHeadline` / `previewEmotion` / `applyScenePack` 链路**；tier 只决定 **显隐、字号、权重、foot 操作**，不替换句源。

---

## 1. 产品共识

策略成立：用户只确认、不配置。Web 已验证 **结构**；iOS 用 **原生 UI** 表达同一结构，叙事仍由 iOS 引擎供稿。

验收母句：我只输一个金额，它就轻轻帮我把这笔生活接住了。

---

## 2. Web 审查结论（可推进）

结构正确，无阻塞。iOS 吸收 **布局与交互**，不吸收 Web 文案实现。

---

## 3. 冻结区

```text
文案引擎（见 §0）
PlaybackService · SummaryPlaybackSheet · WeeklyShareCardView
OCRConfirmSheet 结构与确认流程
StoreKit · 会员权益判定
HomeView · StatsWebView
web-preview/
```

**允许改**：`RecordView` 布局、 `LifeEntryPreviewCard` 样式与 foot 操作、UI 层 `RecordPreviewTier` 判定、`ScenePackAngleSheet` **壳**（列表数据仍来自 `ScenePackCopyPool`）。

---

## 4. 可改文件（最小范围）

```text
NativeDemoApp/Views/RecordView.swift
NativeDemoApp/Views/Components/LifeEntryPreviewCard.swift
NativeDemoApp/Models/RecordPreviewTier.swift     ← 新建，仅 tier 判定，无文案
NativeDemoApp/Views/ScenePackAngleSheet.swift    ← 新建，仅 Sheet 壳 + 列表接线
```

**禁止新建**：`ColdStartWhisperPool.swift`、`ScenePackAngleTaglines`、任何 Web 句池镜像文件。

---

## 5. 预览三档（UI 展示层 · 对齐 Web 结构）

新建 `RecordPreviewTier.swift` — **只解析 tier，不生成文案**：

| 档 | 判定（与 Web 结构对齐） | UI 差异（无文案改动） |
|----|------------------------|----------------------|
| L0 | amount <= 0 | 隐藏纸条 |
| L1 | items<3 && 无品牌 && 无 note && !rotated && !编辑 | whisper 视觉；**隐藏胶囊**；meta 仅时间 |
| L2 | 品牌 / note / rotated / 编辑 / (items>=3 && habit≥0.55) | confirm 视觉；弱胶囊；meta 含分类+改 |

habit≥0.55：读 `recordPrefillResult` 且 `source=="habit"` 的 `confidence`。

**主行 / 胶囊文案**：仍调用 RecordView **现有** `previewHeadline`、`previewEmotion` — **禁止**为 L1 接入 Web 耳语池或新 fallback 句库。

**L1 无专用耳语时**：继续显示现有 `previewHeadline` 产出（含 category fallback）；靠 **whisper 视觉**区分档位，不靠改句源。

---

## 6. 首屏信息架构（只改结构）

```text
金额舞台
侧门：有账单截图？从截图导入 →
life-slip（有金额）
放进账本
```

- 隐藏主路径 `recordModeSegment`；OCR 走侧门 + 现有 `ocrForm` / `PhotosPicker`
- 藏起首屏 `recordDetailsFold`（非编辑态）、`memberScenePackSection` 列表
- 分类 / 备注 / 场景：纸条 expand 或编辑态

**侧门 / 按钮 / hint** 可用 **RecordView 现有** 短文案或极简 affordance 句；**禁止**从 Web 批量迁入叙事句。

---

## 7. LifeEntryPreviewCard → life-slip（只改视觉 + 操作布局）

### 结构

```text
body: headline + hint? + mood? + metaRow(改)
foot: quietActions (link) + amount corner
```

### L1 whisper 视觉

15–16pt regular、subtext 色、无重阴影、**不显示 mood**、金额弱化右下

### L2 confirm 视觉

20–22pt semibold 主行、mood 11pt 弱化、金额 subtext 右下

### foot 安静操作（禁止 pill / ✨）

| tier | 操作（沿用 iOS 现有文案习惯即可） |
|------|----------------------------------|
| L1 | 帮我写一句 \| 自己写一句 |
| L2 | 换一句 \| 自己写一句（品牌：换说法）；rotated 后加 换个角度 |

**行为接线**（逻辑不变，只改触发入口）：

- 换句族 → 现有 `handlePreviewQuickAction` / `applyScenePack`
- 自己写一句 → `noteEditorExpanded` + focus
- 换个角度 → `ScenePackAngleSheet`（列表用 `ScenePackCopyPool` + **现有** `scenePackDesc`）
- 改 → `categoryGridExpanded`

**会员门禁**：保留现有 `isMember` 逻辑，只改按钮样式。

---

## 8. 换个角度 Sheet（壳 only）

- 标题 / 副标题：可用现有 iOS 叙事化短句或 Sheet 通用句；**禁止**新建 Web tagline 字典
- 列表项：`pack.emoji` + `pack.label` + **现有** `scenePackDesc(pack)`（`ScenePackCopyPool.desc`）
- 点选 → 现有 `applyScenePack(pack)` → dismiss

**禁止**：改 `ScenePackCopyPool` 内 notes/rules/desc 正文。

---

## 9. RecordView 状态（结构用）

```swift
@State private var previewLineWasRotated = false
@State private var showScenePackAngleSheet = false
```

- tier 接入后：`previewEmotion` 在 L1 **不渲染**（可仍计算，仅 UI hidden）
- `amountAssist` 显隐/层级调整属 **视觉层级**，文案用现有字段
- 金额清空 → `previewLineWasRotated = false`

---

## 10. 实施顺序

```text
1. RecordPreviewTier.swift（纯 tier，无文案）
2. LifeEntryPreviewCard → life-slip 双态 + quiet foot（Preview 可验）
3. RecordView：tier 显隐 + 首屏结构 + OCR 侧门 + 藏 fold
4. ScenePackAngleSheet（壳，数据接 ScenePackCopyPool）
5. 验收
```

每步可编译；禁止重写 RecordView 全文。

---

## 11. 验收

- [ ] 结构：金额 → life-slip → 放进账本；无 Segment；无首屏场景包列表
- [ ] L1：whisper 视觉、无胶囊；L2：confirm 视觉、弱胶囊
- [ ] foot 为 link，无 pill；自己写一句 / 改 / 换个角度 接线正确
- [ ] OCR 侧门
- [ ] **文案引擎文件 git diff 为空**（或仅 import 无逻辑改动）
- [ ] 保存 / OCR / 编辑 / 会员 不回归
- [ ] 母句：我只输金额，有没有被轻轻接住？

---

## 12. 禁止

- 新建/同步 Web 耳语池、品牌 emotion 表、angle tagline 表
- 改 `NarrativeCopyResolver` / `ScenePackCopyPool` / `MerchantBrandCatalog` / `RecordPrefillService`
- 改 `web-preview/`
- git commit（除非用户要求）

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版 |
| 2026-06-02 | v2：明确只迁结构+视觉，文案引擎冻结 |
