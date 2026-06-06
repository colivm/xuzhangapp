# 叙账 · AI「议」边界审计清单 v0.1

> 更新时间：2026-06-06  
> 状态：**产品定稿 · 代码待改**（本轮只出清单，不改实现）  
> 依据：[`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) **§0.5**  
> 背景：「柔和下月参考」等行为在语气上接近叙账，在结构上仍是 **软性预算**，与「先叙后议」「理解而非审判」冲突。

---

## 1. 审计原则

### 1.1 冲突判据（任一命中即标 ❌）

- 输出 **下月 / 下周 numeric 金额目标**（含 `total × 0.95`、「约 ¥X」参考）  
- 出现 **预算、上限、达成率、框住、收敛、控制预算** 等管控语义  
- 默认动作是 **比过去少花 / 减一次 / 优化结构以省钱**  
- 功能可 **绕过生活切片 / 生活章** 独立完成「下月规划」  

### 1.2 可保留 / 低优先级审视（⚠️）

- **回望式**描述 + 「下周/下月 **再叙时对照**」（无数字）  
- 「继续记」「节奏平稳」等 **中性鼓励**  
- 场景包 **「旅行预算包」**、备注「两晚住宿预算」→ **旅行语义**，非 App 级预算教练（**不误删**）

### 1.3 改码优先级

| 级别 | 含义 |
|------|------|
| **P0** | 直接产出预算数字或明确预算动作，用户可见 |
| **P1** | 无数字但导向管控/优化消费，或 Prompt 易诱发预算建议 |
| **P2** | 文档 / 示例 / 死代码 / 远程 fallback 示例 |
| **—** | 已对齐或无需改 |

---

## 2. iOS 待改项

### 2.1 UI 按钮 · `NativeDemoApp/ContentView.swift`

| 优先级 | 位置 | 当前 | 问题 | 建议方向 |
|--------|------|------|------|----------|
| **P0** | 月度 soft action ~L794 | 按钮「**柔和下月参考**」 | 名称即预算预期 | 删除，或改为「记一句本月收束」/「下月再叙时对照」 |
| **—** | ~L797 | 「保存月度小结」 | 回望式 | 保留 |
| **—** | ~L800 | 「切换叙述风格」 | 换叙述，非管控 | 保留 |
| **⚠️ P1** | ~L668 | 「梳理本周节奏」 | 依赖下文文案 | 保留按钮，改 `buildWeeklyRhythmText` |
| **—** | ~L673 | 「生成周度分享卡」 | 分享回望 | 保留（与 D1 分享图同源） |
| **—** | ~L678 | 「标记常花类目」 | 回望标记 | 保留 |

### 2.2 逻辑与 fallback · `NativeDemoApp/ViewModels/HomeViewModel.swift`

| 优先级 | 函数 / 行 | 当前文案或逻辑 | 问题 |
|--------|-----------|----------------|------|
| **P0** | `buildMonthlySoftPlanText()` ~L931-934 | `total × 0.95` → 「下月生活开销温柔参考：约 ¥\(next)…」 | 核心冲突：软性下月预算 |
| **P0** | `markMonthlySoftPlan()` ~L937-940 | 调用上文 + 事件 `monthly_soft_plan` | 与 P0 同删/同改 |
| **P0** | `localMonthlyInsightBlocks()` advice ~L469 | 「下月可以给「\(top)」设一个**温柔小预算**，不用太紧，轻轻**框住**就好。」 | 预算 + 框住 |
| **P0** | `localWeeklyInsightBlocks()` advice ~L448-450 | 「设置**分段预算**…回看**预算达成率**」/ 「**优化消费结构**」 | 典型预算教练 |
| **P0** | `generateDailyInsight` fallback action ~L689-690 | 「明天把高频消费先**减 1 次**…**控制预算**」 | 管控动作 |
| **⚠️ P1** | `buildWeeklyRhythmText()` ~L919-921 | 「…下周再慢慢**微调**」 | 轻微前瞻管控 |
| **⚠️ P1** | `localMonthlyInsightBlocks()` structure ~L466 | 「…可以留意是否都在**预期内**」 | 轻微评判感 |
| **—** | `markWeeklyTag()` ~L924-927 | 「常花类目回看：…」 | 回望式，可保留 |
| **—** | `markMonthlySaveSummary()` ~L943-947 | 「月度小结：…」 | 回望式，可保留 |

### 2.3 Prompt · `HomeViewModel.promptTemplate` + `AIReportService.swift`

| 优先级 | 位置 | 当前 | 问题 |
|--------|------|------|------|
| **P1** | `promptTemplate` ~L797-811 | 「输出简短复盘和一条**可执行建议**」 | 「可执行」易诱发「减支/设预算」类 action |
| **P1** | `AIReportService` system ~L73-77 | 「不说教、不批判」 | 缺 **禁止预算/下月数字目标** 明示 |
| **P2** | 远程 AI 实际输出 | 非确定性 | 改 Prompt 后需抽测 daily / monthly |

### 2.4 其他 iOS

| 优先级 | 文件 | 说明 |
|--------|------|------|
| **—** | `ScenePackCopyPool.swift` | 「旅行**预算包**」「两晚住宿**预算**」= 场景语义，**不改** |
| **P2** | Tab 命名 `ContentView` `.insight` | 「小 AI 说」「生活复盘」— 可接受；商店勿主打 AI |

---

## 3. Web 待改项 · `web-preview/`（⏳ 本轮不做，后续与 iOS 对齐）

> **2026-06-06**：Task A3 范围收窄为 **仅 iOS**；本节保留清单供后续 Web 任务使用。

### 3.1 UI · `index.html`

| 优先级 | 元素 id | 当前按钮文案 | 问题 |
|--------|---------|--------------|------|
| **P0** | `#monthlySoftPlanBtn` | **柔和下月参考** | 同 iOS |
| **—** | `#monthlySaveSummaryBtn` | 保存月度小结 | 保留 |
| **—** | `#monthlyToneSwitchBtn` | 切换叙述风格 | 保留 |
| **⚠️ P1** | `#weeklyRhythmBtn` | 梳理本周节奏 | 改 `buildWeeklyRhythmText` |
| **—** | `#weeklyShareBtn` | 生成周度分享卡 | 保留 |
| **—** | `#weeklyTagBtn` | 标记常花类目 | 保留 |

### 3.2 逻辑 · `web-preview/app.js`

| 优先级 | 函数 / 行 | 当前 | 问题 |
|--------|-----------|------|------|
| **P0** | `buildMonthlySoftPlanText()` ~L1971-1977 | `total × 0.95` → 下月温柔参考 ¥X | 同 iOS P0 |
| **P0** | `monthlySoftPlanBtn` handler ~L4529-4535 | Toast「**柔和下月参考**已生成…」 | 同 P0 |
| **P0** | `monthlyInsightPayload()` advice ~L3125-3128 | 「设置**预算上限**…**波动收敛**」 | 预算教练 |
| **P0** | `rangeInsightPayload()` advice ~L3150-3153 | 「**分段预算**」「**达成率**」「**优化消费结构**」 | 同 iOS weekly fallback |
| **P0** | `buildSoftBudgetDraft()` ~L1612-1625 | 下周生活开销约 ¥X（**死代码，未接线**） | 应删除或禁止接入，避免误用 |
| **⚠️ P1** | `buildWeeklyRhythmText()` ~L1651-1653 | 「下周再慢慢微调」 | 同 iOS |
| **⚠️ P1** | `buildMonthlySoftPlanText` 空数据 ~L1974 | 「…**下月参考**会更贴近…」 | 用语仍指向预算功能 |
| **—** | `AI_GLOBAL_STYLE_PROMPT` ~L114-115 | 已禁省钱/控制等词 | **好**，但与 fallback 矛盾，fallback 须改 |
| **—** | `AI_FORBIDDEN_WORDS` ~L121-134 | 含控制/节约等 | Post 处理有；**fallback 绕过** |
| **P2** | `ai-proxy/README.md` 示例 action | 「减少一次冲动小额消费」 | 文档示例需改 |

### 3.3 场景包 · `app.js` scenePacks

| 优先级 | 项 | 说明 |
|--------|-----|------|
| **—** | `旅行预算包` / 「两晚住宿预算」 | 场景语义，**不误改** |

---

## 4. 文档与 API 待改项

| 优先级 | 文件 | 位置 | 当前 | 建议 |
|--------|------|------|------|------|
| **P1** | `PRD_v0.1.md` | §4.1 System Prompt | 「一条**可执行建议**」 | 改为「一条轻收束 / 感受句，**禁止预算与下月数字目标**」 |
| **P1** | `PRD_v0.1.md` | §4.2 JSON `action` 字段说明 | 无边界 | 补充 §0.5 约束 |
| **P2** | `API_v0.1.md` | 示例 ~L328 | 「预算会更轻松」 | 换回望式示例 |
| **P2** | `ai-proxy/README.md` | 响应示例 | 「减少一次冲动…」 | 换回望式示例 |
| **—** | `PLAYBACK_COPY_POOL_v0.2.md` | §1 禁用词 | 已列省钱/占比过高等 | AI fallback 应对齐同一套 |
| **—** | `PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` | §5.8 禁止说教 | 已对齐 | 实施时引用 |

---

## 5. 建议替换方向（产品文案，供改码时选用）

### 5.1 「柔和下月参考」按钮 → 备选

| 方案 | 按钮名 | 生成内容示例 |
|------|--------|--------------|
| **A · 收束** | 记一句本月收束 | 「这个月的主线多在餐饮，有几笔像是对自己的照顾。」 |
| **B · 邀请再叙** | 下月再叙时对照 | 「继续记就好；下月打开生活章，再看看有没有新变化。」 |
| **C · 删除** | — | 月度区只保留「保存月度小结」「切换叙述风格」 |

**禁止**：任何默认 `× 0.95` 或「约 ¥X」下月数。

### 5.2 fallback `advice` / `action` 改写原则

- ✅ 「这周/月 **`\(top)`** 出现得比较多，有几笔像是 **`{生活化猜测}`**。」  
- ✅ 「节奏整体 **`{平稳/丰富}`**，继续记， **`{下月/下周}`** 生活章会更立体。」  
- ❌ 设预算、达成率、减一次、控制、收敛、框住、优化结构（若含省钱隐含）

### 5.3 Prompt 增补句（daily / monthly 共用，改码时写入 system）

```text
「议」只谈已经发生的生活：可复述结构、节奏与感受。
禁止：下月/下周金额目标、预算上限、减少支出比例、达成率、任何管控式省钱建议。
action 字段应是温柔收束或邀请继续记录/下月再叙，不是理财计划。
```

---

## 6. 改码顺序建议（未来执行，本轮不做）

```text
1. P0：删除或替换「柔和下月参考」按钮 + buildMonthlySoftPlanText（**iOS**；Web 见 §3 后续）
2. P0：重写 localMonthly / localWeekly / daily fallback advice（**iOS**）
3. P1：改 promptTemplate + AIReportService system（**iOS**；PRD 可选）
4. P1：buildWeeklyRhythmText「微调」→ 回望式（**iOS**）
5. P2：PRD / API 示例 / ai-proxy README（可选）
6. P2：Web §3 全量（**另任务**）
7. 抽测：远程 AI daily + monthly 各 20 条（真机）
```

---

## 7. 验收标准（改码完成后）

- [ ] 小 AI 说 Tab 内 **无任何按钮** 产出下月/下周 ¥ 数字  
- [ ] 全部本地 fallback `advice`/`action` 无「预算」「达成率」「框住」「减一次」  
- [ ] Prompt 含 §5.3 禁止项；远程 AI 抽检通过率 ≥ 90%  
- [ ] 「旅行预算包」等场景包 **未误改**  
- [ ] 月度主路径仍为：**看看花 · 生活章 → 可选小 AI 说**  

---

## 8. 相关文档

| 文档 | 内容 |
|------|------|
| [`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) | §0.5 议的边界（宪法） |
| [`PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md`](PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md) | §3.6～§3.7 内核与哲学 |
| [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) | 改码时可单开任务引用本文 §6 |
| [`AGENT_PROMPT_AI_ADVICE_BOUNDARY.md`](AGENT_PROMPT_AI_ADVICE_BOUNDARY.md) | Task A3 · 小 AI 说去预算化 |
| [`AGENT_PROMPT_SCENE_PACK_PHILOSOPHY.md`](AGENT_PROMPT_SCENE_PACK_PHILOSOPHY.md) | Task A4 · 场景包哲学对齐（iOS） |

---

## 9. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-06 | 首版：iOS / Web / 文档 / Prompt 全量审计；P0～P2 分级；代码未改 |
| 2026-06-06 | Task A3 实施范围收窄为 **仅 iOS**；§3 Web 标记后续 |
