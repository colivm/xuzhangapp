# Agent Prompt · Task B2.13 — 个人习惯预填（仅 iOS）

> **状态：待做**  
> 战略依据：[`RECORDING_CHAIN_VISION_v0.1.md`](RECORDING_CHAIN_VISION_v0.1.md) — **缩短记账链路、叙事自动长出来**  
> 依赖：**F1.3 `NarrativeCopyResolver` 已存在**（分 PR 亦可，但 emotion 须走同一 resolver）。  
> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。

---

## 任务编号对照

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| B2.8 | 智能分类（人口学 + 弱历史 10%） | `CategoryRecommendService` | ✅ |
| F1.3 | 品牌叙事池 | `MerchantBrandCatalog` + `NarrativeCopyResolver` | ⏳ 建议先或并行 |
| **B2.13** | **本 prompt · 个人习惯预填** | `RecordPrefillService` | ⏳ 本任务 |
| B2.13b | 纠正写回 + 会话上下文增强 | 同上 | 📋 本 PR 可选小 diff |

---

## 产品结论（Agent 须先理解）

**终态**：用户 **只输入金额**，分类 / 备注 / 情绪在 **高置信** 下自动填好——像用户自己会写的那样。

**前提**：需要 **本地账本存量**；消费模式因人而异，从 **本机历史** 学，**禁止**写死全局规则（如「周末小金额=小吃」作为硬编码范本）。

**与 B2.8 关系**：B2.8 是「人口学先验 + 10% 历史」；B2.13 是 **「个人先验为主，人口学仅冷启动兜底」**。本 PR **重构分类侧权重**，不是另起一套互斥 UI。

**Cascade（与 F1.3 共用）**

```text
品牌强信号（F1.3）→ 个人习惯（本 PR）→ 通用池 → 用户手改写回
```

---

## 必做 A · `RecordPrefillService.swift`

### 输入

```swift
struct RecordPrefillInput {
    let amount: Double
    let referenceDate: Date
    let items: [HomeItem]          // 全量或近 180 天
    let noteDraft: String
    let categoryLocked: Bool
    let merchantBrandId: String?   // 非 nil 时本 Service 只补 note/emotion，不改分类
}
```

### 输出

```swift
struct RecordPrefillResult {
    let category: HomeItem.Category?
    let title: String?             // 预填备注
    let emotionTag: String?
    let confidence: Double         // 0...1
    let source: String             // "brand" | "habit" | "generic"
}
```

### 个人习惯信号（从 items 聚合，本地确定性）

对每条历史 item 提取特征 bucket（**不要**写死业务含义，只存统计）：

| 维度 | bucket 示例 |
|------|-------------|
| 时段 | hour ÷ 3 → 0..7 |
| 日历 | weekday vs weekend |
| 金额 | `ScenePackCopyPool.tierIndex` 同档或 ±30% 带宽 |
| 会话 | 最近 2h 内已记笔数、上一笔 category（可选 B2.13b） |

在 `(hourBucket, isWeekend, amountBand)` 下统计：

- 各 `category` 计数 → softmax 或 top1/top2 差距
- 各 `title`（2～12 字，去「xx消费」）计数 → top title
- 若有 `merchantBrandId` 历史 → 加权

**置信度**：`top1Count / (top1+top2)` 或 gap-based；`< 0.55` → 只推荐 category chip，不自动填 title/emotion。

**冷启动**（items < 15）：降级为现有 `CategoryRecommendService`，但 history 权重 **提至 40%**（与 B2.8 文档原设计对齐），amount 人口学 **降至 15%**。

**禁止**：在 Swift 里写「if weekend && amount < 20 { return .dining }」类 **全局生活规则**；周末/时段只作 **bucket 键**，不作 **值**。

---

## 必做 B · 接入 RecordView / HomeViewModel

1. 用户输入金额 / 改日期 → 调 `RecordPrefillService.prefill`
2. `categoryLockedByUser == false` 且 confidence ≥ 0.55 → `applyRecommendedCategory`
3. confidence ≥ 0.65 且 `inputTitle` 空 → 预填 `inputTitle`（title 建议）
4. 保存时：`emotionTag = NarrativeCopyResolver.resolveEmotionTag(...)` — habit source 时 brandId 来自 prefill 或 nil
5. UI：保留「推荐」chip；可选 subtitle「根据你的记账习惯」（小 diff，可不做）

---

## 必做 C · 纠正即学习（最小版）

用户 **手选分类** 或 **改备注** 后保存：

- 不要求独立 ML；下次 prefill 自然从 **新 items** 重新聚合即可
- 若做 B2.13b：同一 session 内连续两笔同 category，略 boost 该 category（+0.1 confidence cap 1.0）

---

## 必做 D · 与 F1.3 边界

| 场景 | 行为 |
|------|------|
| `merchantBrandId != nil` | 分类/title/emotion **品牌优先**；习惯引擎不覆盖 |
| OCR 无品牌，手动只输金额 | 习惯引擎主路径 |
| 习惯与 B2.8 冲突 | 本 PR 以 `RecordPrefillService` 为单一入口；`CategoryRecommendService` 可内聚为 private 或委托 |

---

## 分阶段交付（本 PR = A 阶段）

| 阶段 | 范围 | 本 PR |
|------|------|-------|
| A | 金额 → 分类 + 备注预填 | ✅ |
| B | emotion 全自动 + 高置信一键保存 UX | 可选 |
| C | 会话上下文、90 天衰减 | B2.13b |

---

## 禁止

- 全局「周末=娱乐」类硬编码规则表
- 云端上传习惯数据
- 改 OCR 解析（F1.2/F1.3）
- git commit 除非用户明确要求

---

## 验收

- [ ] 新用户 < 15 笔：行为 ≈ B2.8 升级版，无胡填 title
- [ ] 同一用户连续 30 笔「工作日 8 点 ¥4 交通」→ 第 31 笔 8 点 ¥4 **高置信交通** + 常见 title
- [ ] 手改分类锁定后，改金额 **不覆盖** 分类（B2.7）
- [ ] 有 `merchantBrandId` 时不被习惯覆盖
- [ ] 置信度低：仅 category chip 推荐，title 空

---

## @ 文件

```text
@RECORDING_CHAIN_VISION_v0.1.md
@AGENT_PROMPT_B2.13_HABIT_PREFILL.md
@NativeDemoApp/Services/CategoryRecommendService.swift
@NativeDemoApp/Services/ScenePackCopyPool.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/RecordView.swift
@NativeDemoApp/Models/HomeItem.swift
@AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task B2.13 — 个人习惯预填（A 阶段）**（仅 iOS）。

## 北极星句
**缩短记账链路、叙事自动长出来。** 无品牌强信号时，从本机账本学个人习惯；冷启动走通用池。

## 必须先 Read
@RECORDING_CHAIN_VISION_v0.1.md
@AGENT_PROMPT_B2.13_HABIT_PREFILL.md
@NativeDemoApp/Services/CategoryRecommendService.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/RecordView.swift
@AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md

## 必做
1. `RecordPrefillService` — bucket 聚合 + confidence；禁止全局生活规则硬编码
2. 接入 RecordView：金额/日期变化 → 预填 category（+ title 高置信）
3. 重构推荐入口：个人历史为主，人口学兜底；与 B2.7 锁定兼容
4. emotion 走 `NarrativeCopyResolver`；brandId 优先于 habit
5. 纠正即学习：依赖 items 重聚合即可

## 禁止
写死「周末+小金额=某分类」、云端习惯、OCR 改动、web-preview、git commit（除非用户要求）

## 交付
1. 改动文件列表
2. confidence 算法简述
3. 验收勾选
4. 未做：B2.13b 会话衰减、高置信一键保存 UX

最小 diff。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | 首版：A 阶段习惯预填 + 与 F1.3 cascade |
