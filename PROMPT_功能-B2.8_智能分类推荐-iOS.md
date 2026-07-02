# Agent Prompt · Task B2.8 — 智能分类推荐（仅 iOS）

> **状态：iOS 已完成（2026-06-06）**；下文供回归参考。  
> 用法：**整段复制下方「复制发送」** 发给 Agent。

---

## 任务编号对照（必读）

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| **A4** | 场景包哲学 / tagline / 替词 | `ScenePackCopyPool.swift` 文案 | ✅ 已完成 |
| **B2.7** | 手选分类锁定 | `categoryLockedByUser` | ✅ 已完成 |
| **B2.8** | **智能分类推荐**（本 prompt） | `CategoryRecommendService` + `HomeViewModel` | ✅ **已完成** |
| **B2.9** | 天气宠物陪伴 | [`PROMPT_功能-B2.9_天气宠物陪伴-iOS.md`](PROMPT_功能-B2.9_天气宠物陪伴-iOS.md) | ✅ **已完成** |
| **B2.10** | 场景包 128 条池 + stable hash | `ScenePackCopyPool.swift` 结构 | ✅ iOS MVP 已有 |

可选合并：**B2.8 + B2.9** 可一次 PR（见 [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) §10.15）；**B2.10 不要塞进 B2.8**。

---

## @ 文件（Agent 必须先 Read）

```text
@PROMPT_功能-B2.8_智能分类推荐-iOS.md
@IMPLEMENTATION_FOR_CODEX.md
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/RecordView.swift
@NativeDemoApp/Models/HomeItem.swift
@TEST_CASES_v0.1.md
@web-preview/app.js
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task B2.8 — 智能分类推荐**（本地优先、可解释；**仅 iOS**）。

## 背景
当前 `HomeViewModel.recommendCategory(for:)` 仍是纯金额档：
`<30 餐饮, <80 交通, <200 日用, <600 购物, else 其他`
B2.7 已做：用户手选分类后 `categoryLockedByUser`，推荐不得覆盖。

## 必须先 Read
1. IMPLEMENTATION_FOR_CODEX.md **§10.13**（评分模型全文）
2. HomeViewModel.recommendCategory / selectCategory / applyRecommendedCategory
3. RecordView.swift — `.onChange(inputAmount)` 与 categorySection 的 recommended chip
4. web-preview/app.js — `localRecommendedCategory` / `topCategoryFromHistory`（参考，本轮不改 Web）
5. **不要改** ScenePackCopyPool（属 A4/B2.10，已完成）

## 必做 — 新建 `NativeDemoApp/Services/CategoryRecommendService.swift`

### 输入 `CategoryRecommendInput`
- amount: Double
- referenceDate: Date — 用 `HomeViewModel.selectedDate`（补记场景）
- items: [HomeItem] — 近 90 天
- noteDraft: String — `inputTitle` trim
- locked: Bool — true 时调用方直接 return

### 评分（本地、确定性；禁止 AI 作默认路径）
对 7 类算分，取最高（权重见 §10.13）：
1. **历史习惯 40%** — 90 天占比 + 同金额带（×0.7～1.3）最常分类
2. **时段情境 35%** — 早高峰交通、午餐饮、周末娱乐等（用 referenceDate 的 weekday/hour）
3. **金额先验 15%** — 弱化现硬编码，不可单独决定
4. **备注关键词 10%** — 地铁/外卖/酒店等（见 §10.13 表）

输出：`recommended: HomeItem.Category`，可选 `reasonTag: String?`（Debug 用，UI 仍只显示「推荐」）

## 必做 — 接入
1. `HomeViewModel.recommendCategory(for:)` 改为委托 Service（或 `recommendCategory(input:)`）
2. 传入 amount、selectedDate、items、inputTitle、categoryLockedByUser
3. RecordView 现有 `.onChange(inputAmount)` 与 category 区 `recommended` **均走新逻辑**
4. 尊重 B2.7：`categoryLockedByUser == true` 时不改 selectedCategory

## 禁止
- 改 ScenePackCopyPool、生活切片、小 AI 说、StoreKit、OCR
- 手选分类后被 recommend 覆盖
- 改 web-preview（交付未做项须写明）
- git commit 除非用户明确要求

## 验收（iOS）
- [ ] 工作日 08:00 + ¥4 → 倾向 **交通**（非一律餐饮）
- [ ] 12:00 + ¥25 → 倾向 **餐饮**
- [ ] 历史常记购物 + ¥80～150 → 倾向 **购物**
- [ ] 手选分类后改金额 → 分类 **不变**（B2.7）
- [ ] 补记日期：用 selectedDate 的星期/小时参与时段分
- [ ] 未改 ScenePackCopyPool

## 交付
1. 改动文件列表
2. 验收勾选
3. 2～3 条示例：早高峰小额 / 午餐 / 有历史习惯
4. 未做项（Web、远程 AI 分类；B2.9 见 PROMPT_功能-B2.9_天气宠物陪伴-iOS.md）

最小 diff；先 Read 再改。
```

---

## 与 B2.9 合并发送（可选）

见 [`PROMPT_功能-B2.9_天气宠物陪伴-iOS.md`](PROMPT_功能-B2.9_天气宠物陪伴-iOS.md) 文末「与 B2.8 合并发送」。

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-06 | 首版：B2.8 独立 prompt；与 A4/B2.10 编号对照 |
| 2026-06-06 | 标 **iOS 已完成** |
