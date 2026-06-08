# Agent Prompt · Task UI-P1-WEB — 记账页「生活放进账本」Web 预览原型

> **状态：待做**  
> **范围：仅 `web-preview/`** — **不要改** `NativeDemoApp/`、backend、ai-proxy  
> 设计依据：[`RECORD_PAGE_DESIGN_v0.1.md`](RECORD_PAGE_DESIGN_v0.1.md) · [`AGENT_PROMPT_UI-P1_INPUT_LAYER_VISUAL.md`](AGENT_PROMPT_UI-P1_INPUT_LAYER_VISUAL.md)  
> 用途：创始人 **Windows 本地预览 UI 气质**，验证后再做 iOS UI-P1  
> 用法：**整段复制下方「复制发送」** 发给 Agent。

---

## 任务编号对照

| ID | 做什么 | 目录 | 状态 |
|----|--------|------|------|
| UI-P1-WEB | **本 prompt · Web 记账页叙事原型** | `web-preview/` | ⏳ 本任务 |
| UI-P1 | iOS 正式实现 | `NativeDemoApp/` | 📋 Web 验过后再做 |

---

## 产品结论

**北极星句**：叙账的记账页应该像 **「把一段生活放进账本」**，不是 **「填写金额表单」**。

Web 预览目标：

1. **只看 UI/交互气质** — 不要求与 iOS F1.3/B2.13 逻辑 1:1
2. **可切换三种预填态**（品牌 / 习惯 / 冷启动）方便创始人对比
3. **一键备注不能废** — 三态 prominence（见 §必做 6）
4. **冻结** 看看花/playback/分享相关页面 — 只动 `#recordPage`

---

## @ 文件（必须先 Read）

```text
@RECORD_PAGE_DESIGN_v0.1.md
@AGENT_PROMPT_UI-P1_INPUT_LAYER_VISUAL.md
@web-preview/index.html
@web-preview/app.js
@web-preview/styles.css
@NativeDemoApp/Views/HomeView.swift
（只读：emotionTag capsule 样式参考，勿改 iOS）
```

---

## 必做 1 · HTML 结构（`index.html` `#manualForm`）

在 `#manualForm` 内 **重排**，顺序：

```text
1. #amountStage          — 金额舞台（无「金额」label）
2. #lifeEntryPreview     — 生活预览卡（有金额时显示）
3. #recordPrimaryActions — 「放进账本」+ 日历
4. #recordDetailsFold    — 默认 collapsed：分类 / 备注 / 场景包
5. #prefillDemoBar       — 仅 Web：三态演示切换（见必做 7）
```

### 删除或移入 fold 的首屏元素

- `<label class="field"><span>金额</span>` → 改为 `#amountStage`，**去掉 span 标签**
- `#categoryField`、 `#noteField` → 移入 `#recordDetailsFold` 或默认 `hidden`
- `#saveRecordBtn` 文案 **「保存这一笔」→「放进账本」**
- `#localPrivacyHint` / `#dateHint` → 移入 fold 底部或默认 hidden

### `#lifeEntryPreview` 结构（新建）

```html
<section id="lifeEntryPreview" class="life-entry-preview hidden">
  <div class="life-entry-main">
    <p id="lifeEntryHeadline" class="life-entry-headline">…</p>
    <span id="lifeEntryAmount" class="life-entry-amount">¥0.00</span>
  </div>
  <p id="lifeEntryEmotion" class="life-entry-emotion hidden"></p>
  <p id="lifeEntryMeta" class="life-entry-meta muted">…</p>
  <div id="lifeEntryQuickActions" class="life-entry-quick-actions"></div>
</section>
```

### `#amountStage`

- 保留 `#amountInput` / `#amountDisplay` / quick keyboard
- 无金额时 `#amountAssist`：**「记下一笔今天的生活」**
- 大号金额视觉（CSS 负责）

---

## 必做 2 · CSS（`styles.css`）

新增 `.life-entry-preview` 系列，气质对齐 iOS 叙式（非 KPI 报表）：

| 元素 | 建议 |
|------|------|
| `.life-entry-preview` | glass 面板；极淡 gradient；圆角 20–24px |
| `.life-entry-headline` | 17–18px semibold；主叙事色 |
| `.life-entry-amount` | 右上/右下；14–15px muted；**小于 headline** |
| `.life-entry-emotion` | capsule：浅 accent 底 + 圆角 pill（参考 iOS Home 列表 emotionTag） |
| `.life-entry-meta` | 12px；分类 · 时间 |
| `#amountStage` | 居中或大号左对齐；**无 field label** |
| `#saveRecordBtn` / `.save-btn` | min-height ~52；非 mega 72px |
| `#recordDetailsFold` | `details` 或 `.fold-panel`；默认 closed，summary「补充细节 / 改分类」 |

**禁止**：预览卡做成「今日支出 ¥128」报表风。

---

## 必做 3 · JS 预览逻辑（`app.js`）

### 3A · 状态

```javascript
// Web 演示用；不影响 persist
let prefillDemoMode = 'generic'; // 'brand' | 'habit' | 'generic'
let recordDetailsExpanded = false;
```

### 3B · `updateLifeEntryPreview()`

在 `renderRecord()` 内调用（手动模式 + amountReady）。

**输入**：当前 amount、`selectedCategory`、`titleInput.value`、`prefillDemoMode`

**Mock 三态数据**（硬编码即可，注释标明 Web-only）：

| mode | headline | emotion | quickAction |
|------|----------|---------|-------------|
| `brand` | 瑞幸咖啡 | 早班路上，顺手续一口 | 次要 link「换一句说法」 |
| `habit` | 地铁通勤 | 日常出行 | 按钮「✨ 换一句」 |
| `generic` | （空或「吃饭的一小笔」fallback） | 日常一口 或空 | **主角**「✨ 帮我写一句」 |

**规则**：

- 若 `titleInput` 非空 → headline **优先用用户/场景包写的**
- emotion 胶囊：有则显示 `#lifeEntryEmotion`，无则 hidden
- `#lifeEntryAmount` = 当前输入金额 formatted
- `#lifeEntryMeta` = `${selectedCategory} · ${日期时间简写}` + 可选 button「改分类」→ 展开 fold

### 3C · 与现有逻辑接线

- `applyScenePack` / 一键生成备注 → 更新 `titleInput` + **调用 `updateLifeEntryPreview()`**（主行即时变）
- `updateCategoryUI` / 推荐分类 → 更新 meta；**不要删** `localRecommendedCategory`
- `renderMemberScenePack()` → 移入 fold 内或预览卡 quickActions 下方；**保留** `memberScenePacks` 与展开逻辑

---

## 必做 4 · 表单折叠

- 无金额：只显示 amountStage + assist
- 有金额：amountStage + lifeEntryPreview + 放进账本；**不显示** category grid / note input 首屏
- 「改分类」「补充细节」→ toggle `#recordDetailsFold`
- 编辑已有账单（`editingRecordId`）→ 可默认展开 fold

---

## 必做 5 · OCR 区轻改（同页）

- `#ocrForm` 首句改为：**「从账单里捞生活片段，确认后再放进账本。」**
- **不要**大改 OCR draft 结构（F1.2 对齐另 task）

---

## 必做 6 · 一键备注 · 三态 prominence

| prefillDemoMode | `#lifeEntryQuickActions` 渲染 |
|-----------------|-------------------------------|
| brand | `<button class="link-btn">换一句说法</button>` → 触发 quickGenerate |
| habit | `<button class="scene-quick-btn">✨ 换一句</button>` |
| generic | `<button class="scene-primary-btn">✨ 帮我写一句</button>`（主视觉） |

- 非会员：generic 态点「帮我写一句」→ 现有会员引导（`memberScenePackEntryBtn` 逻辑）
- 会员：点按钮 → 现有 `applyScenePack(quickPack)` + 刷新预览卡
- **禁止**删除 `#memberScenePackBlock` / 一键生成备注能力

---

## 必做 7 · Web 演示条（创始人验收用）

在 `#recordPage` 底部或预览卡下加 **仅 Web** 条：

```html
<div id="prefillDemoBar" class="prefill-demo-bar">
  <span class="muted">预览态：</span>
  <button data-prefill-mode="brand">品牌（瑞幸）</button>
  <button data-prefill-mode="habit">习惯（地铁）</button>
  <button data-prefill-mode="generic">冷启动</button>
</div>
```

切换 → 更新 `prefillDemoMode` → `updateLifeEntryPreview()`。  
iOS 不会有此条；CSS 用小字 muted，标注「开发预览」。

---

## 禁止

- 改 `NativeDemoApp/`、backend、ai-proxy
- 改 `#statsPage` / playback / 分享图 / 首页大结构
- 删 OCR / 场景包 / 分类推荐
- git commit 除非用户明确要求

---

## 验收（浏览器本地）

- [ ] 打开记账 Tab：首屏 **无**「金额」字段标签 + 分类 grid
- [ ] 输入 9.9：出现生活预览卡；金额在卡片 corner 且小于主行
- [ ] 三态演示条切换：brand / habit / generic 下 quickAction prominence 不同
- [ ] 点「帮我写一句」/ 一键备注：预览 **主行** 变（不是只改隐藏 input）
- [ ] 「放进账本」按钮；fold 内仍可改分类/备注
- [ ] OCR Tab 仍可切换；手动/OCR segment 保留
- [ ] 问句：像放进账本，不像填表

---

## 交付

1. 改动文件：`index.html`、`styles.css`、`app.js`（+ 可选 `README.md` 一句如何预览三态）
2. 截图说明或文字描述三态差异
3. 验收勾选
4. 明确 **Web-only mock** 项，iOS UI-P1 需接真实 Resolver

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task UI-P1-WEB — 记账页「生活放进账本」Web 预览原型**。

## 范围
**仅 web-preview/** — 禁止改 NativeDemoApp、backend、ai-proxy。

## 北极星句
叙账记账页 = **把一段生活放进账本**，不是填写金额表单。
详见 RECORD_PAGE_DESIGN_v0.1.md

## 目的
创始人在 Windows 浏览器先看 UI 气质，满意后再做 iOS UI-P1。

## 必须先 Read
@RECORD_PAGE_DESIGN_v0.1.md
@AGENT_PROMPT_UI-P1_WEB_PREVIEW.md
@web-preview/index.html
@web-preview/app.js
@web-preview/styles.css

## 执行顺序
1. index.html — amountStage + lifeEntryPreview + recordDetailsFold
2. styles.css — 叙式预览卡（非报表 KPI）
3. app.js — updateLifeEntryPreview() + renderRecord 接线
4. 三态 prominence + 场景包刷新预览主行
5. prefillDemoBar（Web-only 三态切换）
6. OCR 区 copy 轻改

---

## 必做 1 · HTML 重排 #manualForm

顺序：amountStage → lifeEntryPreview → 放进账本 → recordDetailsFold（分类/备注/场景包）

删首屏「金额」label；saveRecordBtn →「放进账本」

lifeEntryPreview 含：headline、emotion capsule、meta、quickActions、corner amount

---

## 必做 2 · CSS

life-entry-preview glass 风；headline 17–18px；amount corner muted 更小；emotion pill

---

## 必做 3 · JS updateLifeEntryPreview()

Mock 三态（Web-only）：
- brand：瑞幸咖啡 + 早班路上顺手续一口 + link「换一句说法」
- habit：地铁通勤 + 日常出行 + 「✨ 换一句」
- generic：空/fallback + 主角「✨ 帮我写一句」

titleInput 非空 → headline 优先；applyScenePack 后刷新预览主行

---

## 必做 4 · 表单折叠

有金额：不首屏展示 category grid / note；fold 内补充

---

## 必做 6 · 一键备注三态（禁止删 memberScenePack）

brand 次要 / habit 并列 / generic 主角；点一键 → 预览主行变

---

## 必做 7 · #prefillDemoBar

按钮切换 brand|habit|generic，标注「开发预览」

---

## 禁止

NativeDemoApp、stats/playback 大改、删场景包、git commit（除非用户要求）

---

## 验收

无首屏表单堆叠 · 预览卡+胶囊 · 三态切换 · 一键改预览主行 · 放进账本 · OCR 可切换

---

## 交付

文件列表、三态说明、验收勾选、Web mock vs iOS 待接项

最小 diff；只动 recordPage 相关。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | 首版：Web 预览原型 + 三态演示条 + 完整复制发送块 |
