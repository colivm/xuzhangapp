# Agent Prompt · Task A3 — AI「议」边界对齐（去预算化 · iOS）

> **状态：iOS 已完成（2026-06-06）**；下文供回归 / 新 Agent 参考。  
> 用法：**整段复制下方「复制发送」代码块**，作为一条消息发给 Cursor Agent / Codex。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。  
> 产品依据：[`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) §0.5、[`AI_ADVICE_BOUNDARY_AUDIT_v0.1.md`](AI_ADVICE_BOUNDARY_AUDIT_v0.1.md)

---

## @ 文件（Agent 必须先 Read）

```text
@AGENT_PROMPT_AI_ADVICE_BOUNDARY.md
@AI_ADVICE_BOUNDARY_AUDIT_v0.1.md
@PRODUCT_NORTH_STAR.md
@NativeDemoApp/Views/InsightWebView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Services/AIReportService.swift
@PRD_v0.1.md
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 仓库实现 **Task A3 — AI「议」边界对齐（去预算化 · 仅 iOS）**。

## 背景（必读 PRODUCT_NORTH_STAR.md §0.5）
叙账哲学是「先叙后议 · 理解而非审判」。当前小 AI 说 Tab 存在 **软性预算** 能力（如「柔和下月参考」= 本月总额 ×0.95 输出下月 ¥X），与产品内核冲突。
审计清单见 AI_ADVICE_BOUNDARY_AUDIT_v0.1.md **§2（iOS）**；§3 Web 项本轮 **不做**。

**冲突判据（任一命中即须改掉）**：
- 下月/下周 numeric 金额目标（含 ×0.95）
- 预算、上限、达成率、框住、收敛、控制预算
- 减一次消费、优化消费结构（含省钱隐含）
- 功能绕过生活切片独立完成「下月规划」

## 必须先 Read（按顺序，不要盲改）
1. AI_ADVICE_BOUNDARY_AUDIT_v0.1.md §2、§5、§7
2. `NativeDemoApp/Views/InsightWebView.swift` — 小 AI 说 Tab（周/月 soft actions、记一句本月收束）
3. `NativeDemoApp/ViewModels/HomeViewModel.swift` — local*InsightBlocks、buildMonthlyClosingText、generateDailyInsight fallback、promptTemplate
4. NativeDemoApp/Services/AIReportService.swift — system prompt
5. **Task A3 不要改** `ScenePackCopyPool.swift`（属 Task A4）

## 范围（严格）
**只改 iOS**（本任务 **已完成**；路径供回归参考）：
- `NativeDemoApp/Views/InsightWebView.swift`
- `NativeDemoApp/ViewModels/HomeViewModel.swift`
- `NativeDemoApp/Services/AIReportService.swift`
- （可选 P1）`PRD_v0.1.md` §4.1～§4.2

**禁止改**：
- `web-preview/**`（本轮不做 Web 对齐；交付未做项须写明）
- `ScenePackCopyPool.swift`（Task A4）
- 生活切片 / StoreKit / OCR / 统计页
- `API_v0.1.md`、`ai-proxy/**`（除非用户另要求）
- git commit 除非用户明确要求

## 必做 — P0（iOS）

### 1. 替换「柔和下月参考」（审计 §5.1 **方案 A**）
- `InsightWebView.swift` 按钮文案 → **「记一句本月收束」**
- 删除 `total × 0.95` 及一切下月 ¥ 数字逻辑
- 重写 `buildMonthlySoftPlanText()`（可重命名为 `buildMonthlyClosingText()`）：
  - 基于 **本月已有数据** 生成 **回望式收束句**（1～2 句）
  - 示例：「这个月「{topCategory}」出现得比较多，有几笔像是对自己的照顾。」
  - 无数据：邀请继续记，**不提下月参考金额**
- 同步 `markMonthlySoftPlan()` / analytics（如 `monthly_closing_saved`）
- 更新 `InsightWebView` 内对该按钮/方法的调用

### 2. 重写 iOS 本地 fallback（HomeViewModel）
- `localMonthlyInsightBlocks()` — advice + structure（去掉「预期内」「温柔小预算」「框住」）
- `localWeeklyInsightBlocks()` — advice（去掉「分段预算」「达成率」「优化消费结构」）
- `generateDailyInsight` fallback action（去掉「减 1 次」「控制预算」）

**改写原则**（审计 §5.2）：
- ✅ 复述已发生结构/节奏 + 生活化感受
- ✅ 「继续记，下月/下周生活章会更立体」（无数字）
- ❌ 预算、达成率、框住、收敛、减一次、管控

## 必做 — P1（iOS + 可选 PRD）

### 3. Prompt 边界
- `HomeViewModel.promptTemplate`：「可执行建议」→「温柔收束或邀请继续记录/下月再叙」
- `AIReportService.swift` system：写入审计 §5.3 禁止项（禁止预算与下月数字目标）
- （可选）`PRD_v0.1.md` §4.1～§4.2 与 §0.5 一致

### 4. `buildWeeklyRhythmText()`（仅 iOS）
- 去掉「下周再慢慢微调」
- 例：「本周开销以「{top}」为主，这一段的节奏就是这样，记下来了。」

## 禁止
- 整库搜索替换「预算」——只改小 AI 说相关 fallback / 按钮 / Prompt
- 新增下月/下周金额参考算法

## iOS 最低版本
17.0；保持现有 MVVM 风格。

## 验收（iOS）
- [ ] 小 AI 说 Tab 无按钮产出下月/下周 ¥ 数字
- [ ] HomeViewModel 本地 fallback 无：预算、达成率、框住、减一次、控制预算、×0.95
- [ ] 按钮「记一句本月收束」与生成逻辑一致
- [ ] iOS Prompt（system + promptTemplate）含 §5.3 禁止项
- [ ] 未改 ScenePackCopyPool、未改 web-preview

## 交付格式
1. **改动文件列表**
2. **验收勾选**
3. **未做项**（须含：Web 预览故意跳过）
4. **改后 fallback 示例**：daily action、weekly advice、monthly advice、本月收束各 1 条

请先 Read 再改；最小 diff。
```

---

## 备注

| 项 | 说明 |
|----|------|
| 方案选择 | 默认 **A「记一句本月收束」**；可用 **C 删按钮**（交付说明理由） |
| Web | 审计 §3 留待后续；与 iOS 对齐时再开任务 |
| 远程 AI | 只改 Prompt + fallback；真机抽测 daily/monthly |
| 关联 | Task A4 场景包独立；B2.x / E1 不顺带改 |

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-06 | 首版：Task A3 完整 Agent 对话 |
| 2026-06-06 | **仅 iOS**；移除 web-preview 范围与验收 |
| 2026-06-06 | UI 路径改为 `InsightWebView.swift`；标 **已完成** |
