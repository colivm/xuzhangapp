# Agent Prompt · Task F1.2 — OCR / 看看花 真机回归修复（仅 iOS）

> **状态：待做**  
> 触发：真机 TestFlight 回归（2026-06-08 前后）+ 近 3 次提交 OCR 大改（`441cf3f` / `6b4d9e7` / `7a887fc`）  
> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。  
> **格式**：「复制发送」为单一 ` ```text ` 块，块内**不要**再嵌套 ` ``` `。

---

## 任务编号对照

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| **F1.2** | **本 prompt · 6 项真机回归修复** | OCR + Stats + PlaybackCopyPool | ⏳ 本任务 |
| F1 | OCR 四步主链路 | 已完成 | ✅ |

**近 3 commit 关联**

| commit | 说明 | 与本任务关系 |
|--------|------|----------------|
| `441cf3f` | 真机调试优化 / OCR 识别优化 | 引入列表解析、待整理 UI 重构 → **问题 1/3/5/6 主因** |
| `6b4d9e7` / `7a887fc` | 按钮识别范围 | 触摸区；**问题 1 删除钮重叠** 可能仍缺布局 fix |

---

## 产品分析结论（Agent 须先理解）

| # | 用户反馈 | 结论 | 根因（代码锚点） |
|---|----------|------|------------------|
| 1 | 待整理区删除钮与金额重叠 | **✅ 属实** | `OCRDraftPanel` 在 `OCRDraftRow` 上 `.overlay(alignment: .topTrailing)` 放删除钮；行内 `headerRow` 已有右上 `amountDisplay` → 同一角落冲突 |
| 2 | 6/8 点开本周，列表仍有 6/7 数据；切片无数据 | **✅ 部分属实 · 边界不一致** | 6/7=周日、6/8=周一。切片 `PlaybackService.isoCalendar`（ISO 周一换周）正确无数据；**看看花列表** `StatsWebView.filteredItems` 用 `Calendar.current.isDate(..., weekOfYear)`，与切片 **不同日历源**，周日/周一换周边界可能不一致；且 **未与 isoCalendar 统一** |
| 3 | 「收起已整理」歧义 | **✅ 属实** | 按钮文案像「折叠 UI」，实际 `clearResolvedOCRDrafts()` 是 **把已整理项 draftMeta 清掉、并入正式账本**（不可理解为收起） |
| 4 | 本月生活章小字用了周文案 | **✅ 属实** | `monthTeaserLine` → `PlaybackCopyPool.teaser()`，但 `teasers` 池硬编码 **「这一周」** 等周文案；另 `summaryQuotaFootnote` 月卡耗尽时 footnote 写「本周切片仍可按周免费播放」 |
| 5 | 微信列表导入：上一笔负金额变下一笔标题 | **✅ 属实 · 微信结构更薄** | 见下 **§ 微信 vs 支付宝列表结构**；`nearbyListTitle` 对微信与支付宝用同一套「邻近行猜标题」，但 **仅支付宝** 有 `alipayListCategory`（「餐饮美食」等分类小字）作锚点；微信列表通常 **无分类行**，OCR 行序常为「商户 / -金额 / 时间」，上一笔 `-52.00` 易被下一笔当成 `-1` 邻近标题 |
| 6 | 待整理缺「一键整理」 | **✅ 合理需求** | 现仅逐笔点选圆圈标记 `resolved`；缺批量 `resolveAllPendingOCRDrafts()` |

---

## 微信 vs 支付宝 · 列表 OCR 结构差异（必 Read）

真机观察 + 代码对照：**不是同一套 UI，不能共用同一套「猜标题」逻辑。**

### 支付宝账单列表（有分类锚点）

```text
瑞幸咖啡              ← 商户/标题（-1 或 -2 行）
餐饮美食              ← 分类小字（alipayListCategory 可读）
-18.90                ← 金额行（parseListReceipts 入口）
```

代码已有：`alipayListCategory(from: windowLines)` → 餐饮美食/日用百货… → 分类较稳。

### 微信账单列表（通常无分类小字）

```text
商户名 / 转账备注      ← 标题应在金额 **上方** 找
-52.00                ← 金额行
05-30 19:41           ← 时间常在 **下方**（不是分类）
（下一笔）
-4.50                 ← 若仍用 offset -1，会吃到上一笔金额 ← **当前 bug**
```

微信 **没有**「餐饮美食」类行 → `listCategory` 只能 `inferCategory(title)` → title 错则分类也错（截图里大量「日用」）。

### 修复方向（写入必做 5，勿与支付宝混做）

1. **通用**：拒绝纯 `-52.00` / 金额行当地名（底线）
2. **微信专用** `wechatListTitle(lines:amountIndex:)`（不要只调 offsets 微调）：
   - 从金额行 **向上** 扫描，跳过：纯金额、时间行（`\d{1,2}-\d{1,2}` / `\d{1,2}:\d{2}`）、状态词（交易成功/已退款）
   - **优先**含中文且非 blocked 的行；向上最多 4 行
   - 若向上先遇到 **上一笔金额行** → 停止，勿跨过交易边界
   - 找不到 → fallback「账单记录」或「微信消费」，**不要**用 `-xx.xx`
3. **支付宝**：保持 `alipayListCategory` + 现有 offsets；分类行 **不得** 当地名（已在 blocked 含「餐饮美食」等，确认 `isLikelyListTitle` 拦得住）
4. 可选：微信用 **时间行在下方** 反推标题区间（amountIndex 下方 1 行若是时间，则 title 只在 amountIndex 上方找）

---

## @ 文件（Agent 必须先 Read）

```text
@AGENT_PROMPT_F1.2_OCR_STATS_REGRESSION.md
@NativeDemoApp/Views/OCRConfirmSheet.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Services/OCRService.swift
@NativeDemoApp/Views/StatsWebView.swift
@NativeDemoApp/Services/PlaybackService.swift
@NativeDemoApp/Services/PlaybackCopyPool.swift
@TEST_CASES_v0.1.md
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task F1.2 — OCR / 看看花 真机回归修复**（6+1 项；**仅 iOS**；**同一 PR**）。

## 背景
TestFlight 真机回归发现 6 个问题（见 AGENT_PROMPT_F1.2_OCR_STATS_REGRESSION.md 分析表）。近 commit `441cf3f` 大幅改了 OCR 列表解析与待整理 UI。修复须 **小 diff**，不重写 OCR 架构。

## 执行顺序（必须按此顺序改，避免返工）
1. **必做 5** — OCR 微信/支付宝分流 + 少一行增强（数据正确优先）
2. **必做 2** — 本周筛选与 isoCalendar 统一
3. **必做 4** — 月章 subtitle 去「周」化
4. **必做 1** — 待整理 UI 删除/金额不重叠
5. **必做 3** — 「完成整理」文案
6. **必做 6** — 一键标记已整理

## 必须先 Read
@AGENT_PROMPT_F1.2_OCR_STATS_REGRESSION.md
@NativeDemoApp/Services/OCRService.swift
@NativeDemoApp/Views/OCRConfirmSheet.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/StatsWebView.swift
@NativeDemoApp/Services/PlaybackService.swift
@NativeDemoApp/Services/PlaybackCopyPool.swift

---

## 必做 5 · 微信列表 OCR：标题提取、支付宝分流、少一行（最先做）

**文件**：`OCRService.swift`

**现象 A**：标题变成 `-52.00`、`-4.50`（上一笔金额被当下笔 title）。
**现象 B**：列表导入 **容易少一行**（真机：屏幕边缘笔展示不全 + 代码 dedup/行序问题）。

**根因**：
- 微信列表 **无支付宝式「餐饮美食」分类小字**，行序常为「商户 / -金额 / 时间」；不能与支付宝共用 offsets 猜标题。
- Vision `observations` 当前 **未按 Y 坐标排序**，邻近行逻辑易乱。
- dedup key `title|amount|day` 在 title 错时 **误并两笔**。
- 截图 **最上/最下一笔被 Tab/刘海裁切** → Vision 根本 OCR 不到（产品层需引导）。

**要求 5A · 通用底线**
1. `isUsableTitle` / `isLikelyListTitle` **拒绝**纯金额行：`^-?\s*[¥￥]?\s*[0-9]+(\.[0-9]{1,2})?\s*$`
2. `signedListAmountInfo` 的 `inlineTitle` 若像金额 → nil

**要求 5B · 微信专用（必做）**
1. 新增 `wechatListTitle(lines:amountIndex:)`，**不要**只调 offsets 微调
2. 从 amount 行 **向上**扫描（最多 4 行）：跳过纯金额、时间行、状态词；遇上一笔金额行 **停止**；选第一条含中文且过 `isLikelyListTitle` 的行
3. 若 amount 行 **下方 1 行是时间**，title 只在上方找
4. 找不到 → **「微信消费」** 或「账单记录」，禁止 `-xx.xx` 作 title

**要求 5C · 支付宝（保持 + 小加固）**
1. 继续 `alipayListCategory` + offsets `[-1,-2,-3,1]`
2. 分类小字（餐饮美食等）**不得**进入 title

**要求 5D · 少一行增强（同 PR 必做）**
1. **Vision Y 排序**：`recognizeReceipt` 里对 `VNRecognizedTextObservation` 按 boundingBox.minY **从上到下**排序后再拼 `lines`（Vision 坐标系注意翻转）
2. **dedup 防误杀**：`seenKeys` 改为含 **amount 行 index** 或 window hash，勿仅用 `title|amount|day`（title 错时会吞笔）
3. **截图引导文案**（`RecordView` OCR 区）：加一句「请保证每笔完整在画面内，上下留一点边；首尾笔被裁切可能漏识别」
4. **可选**：确认页 subtitle 显示「解析 M 笔」；M 明显少于屏内笔数时可提示重拍 — 小 diff 可做可不做
5. `prefix(12)` **保持**；交付说明若一屏超 12 笔会截断

**验收 5**：
- [ ] 微信列表：title 为商户/中文，**无** `-52.00`
- [ ] 支付宝：分类与 title 仍正常
- [ ] 同屏 5 笔支出不应因 dedup 只出 4 笔（title 修复后回归）
- [ ] lines 按 Y 排序后 parse 结果稳定

---

## 必做 2 · 「本周」筛选与切片同周界

**问题**：2026-06-08（周一）新自然周；2026-06-07（周日）不应在「本周」列表；切片无数据（正确）。

**要求**：
1. 共用周界：`PlaybackService.isoCalendar` 或 `AppCalendar.weekInterval(for:)`，**周一 00:00 本地**～下周一 00:00 半开区间，与 `buildWeekSummary` 一致
2. 替换 `StatsWebView.filteredItems` case `.week` 与 `HomeViewModel.filteredItems(in: .week)` 的 `Calendar.current.isDate(..., weekOfYear)`
3. 周筛选用 `createdAt`，**不要**用 `importedAt`

**验收**：
- [ ] anchor 2026-06-08：`createdAt` 2026-06-07 23:59 **不在**本周；2026-06-08 00:01 **在**本周
- [ ] 本周切片无数据时，本周列表 **同为空**

---

## 必做 4 · 本月生活章副文案去「周」化

**根因**：`PlaybackCopyPool.teasers` 硬编码「这一周」；`monthTeaserLine` 误用周池。

**要求**：
1. 拆分 `weekTeasers` / `monthTeasers`；月池 **禁止「这一周/本周」**
2. `monthTeaserLine` 只调月池；`weekTeaserLine` 只调周池
3. `StatsWebView.summaryQuotaFootnote` 月耗尽时勿只写「本周切片仍可按周免费播放」→ 月章语义优先

**验收**：看看花选 **本月**，subtitle/footnote **无「这一周」**（周卡除外）

---

## 必做 1 · 待整理卡片 UI：删除钮与金额不重叠

**文件**：`OCRConfirmSheet.swift`

**要求**（推荐 A）：删除钮移出 header 右上；¥ 与 trash **不得 overlap**；分类 Picker 勿竖排单字（`lineLimit(1)` / 宽度）

**验收**：¥39.57 与 trash 可分别点击。

---

## 必做 3 · 「收起已整理」→「完成整理（N 笔）」

**现状**：`clearResolvedOCRDrafts()` = 已整理项 **正式入账**，不是 UI 折叠。

**要求**：按钮 **「完成整理（N 笔）」** 或 **「将 N 笔已整理入账」**；N=0 disabled；禁用「收起/折叠/隐藏」

**验收**：用户能懂 = 已勾选进正式账本。

---

## 必做 6 · 待整理「一键标记已整理」

**要求**：
1. `HomeViewModel.resolveAllPendingOCRDrafts()`：全部 pending → resolved；persist + sync
2. `OCRDraftPanel` 加 **「一键标记已整理」**（pending=0 disabled）
3. **不**自动入账；用户仍点「完成整理」才 `clearResolvedOCRDrafts`

**验收**：导入 5 笔 → 一键标记 → 完成整理 → 看看花可见。

---

## 禁止

- 改 web-preview
- 重构 ContentView / 整文件 OCR 重写
- 改 StoreKit、D1.1 分享图、B2.11/B2.12 已完成项（除非回归 FAIL）
- git commit 除非用户明确要求

---

## 总验收（TestFlight 8 条快验 + 6 条全量）

快验：微信 OCR 无负 title · 不少行 · 本周边界 · 月章无周文案 · UI 不重叠 · 完成整理文案 · 一键整理 · 支付宝仍正常

全量见 AGENT_PROMPT_F1.2 分析表 6 项。

---

## 交付

1. 改动文件列表（按执行顺序 5→2→4→1→3→6）
2. 验收勾选
3. 周界与 Vision Y 排序说明
4. monthTeasers 全文（若改 PlaybackCopyPool）
5. 未做项：长图 OCR、web 对齐、prefix(12) 扩容

最小 diff；严格按执行顺序改。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | 首版：真机 6 项 + 近 3 commit 关联 |
| 2026-06-08 | § 微信 vs 支付宝列表结构；必做 5 改为微信专用 title 扫描 |
| 2026-06-08 | 复制发送块：执行顺序 5→2→4→1→3→6 + 少一行增强（Y 排序/dedup/引导） |
