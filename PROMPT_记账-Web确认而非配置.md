# Agent Prompt · Task UI-P1.2-WEB — 确认而非配置（记账页 · 仅 web-preview）

> **状态：待做 · 最新 Web 预览 prompt**（取代 [`PROMPT_记账-Web冷启动极简预览.md`](PROMPT_记账-Web冷启动极简预览.md)）  
> **北极星句**：**默认让用户确认，不让用户配置。**  
> **依赖：无** — 仅 `web-preview/`；**不动 iOS** / backend。  
> 用法：**整段复制下方「复制发送」** 发给 Agent。

---

## 任务编号对照

| ID | 做什么 | 状态 |
|----|--------|------|
| UI-P1-WEB | 叙事壳（预览卡 + 放进账本） | ✅ |
| UI-P1.1-WEB | 冷启动耳语 | 📋 并入本 prompt |
| **UI-P1.2-WEB** | **本 prompt · 确认式记账页** | ⏳ 本任务 |
| UI-P1.2 | iOS 同理念 | 📋 另 PR |

---

## 产品结论（Agent 须先理解）

### 输入层原则

```text
配置 = 传统记账（选分类、填备注、挑场景包）
确认 = 叙账（系统先理解，用户点头或轻纠错）
```

### 首屏永远只有三段（禁止第四块模块）

```text
1. 金额舞台
2. 生活预览卡（即将入册的小纸条）
3. 放进账本
```

**禁止首屏出现**：分类 chip grid、备注 TextField 标签、`recordDetailsFold` 整条、`memberScenePackBlock` 列表、`prefillDemoBar`（仅 debug）。

分类 / 备注 / 场景包 = **预览卡背后的能力**，只在用户 **轻操作 / 深操作** 后出现。

### 能力分层

| 层 | 内容 |
|----|------|
| **首屏** | 金额 + 预览 + CTA |
| **轻操作** | 换一句 · 改（分类）· 点主行补一句 |
| **深操作** | 更多（说法来源）· 分类 grid · 手写输入 |
| **引擎** | 品牌 lite / 习惯置信 / guessScenePack / inferEmotion（用户不可见） |
| **回望** | 保存后首页痕迹 / 回放（本 PR 不改，但 L1 可无胶囊） |

### 场景包产品语义

- **不叫「场景包」**，不对用户展示包名列表为主路径
- 前台只表现 **一句动作**：
  - 低置信：**帮我写一句**
  - 习惯：**换一句**
  - 品牌：**换一句说法**
- 点动作 → **直接换预览主行**（`applyMemberScenePack(guessMemberScenePackId())` 或轮换 variant）
- **更多**：预览卡右下角轻 link，点开才列通勤/吃饭/旅行/人情…（二级 Sheet）

---

## 预览三档（`resolveRecordPreviewTier`）

| 档 | 条件 | 预览主行 | 胶囊 | 次行 meta | 主动作 | 更多 |
|----|------|----------|------|-----------|--------|------|
| **L0** | 无有效金额 | —（隐藏预览卡） | — | — | — | — |
| **L1** | 有金额 + 低置信 | 耳语池 或「今天的一小笔」 | **隐藏** | `今天 · H:mm`（**无分类**） | 帮我写一句 | hidden |
| **L2** | 品牌 / 习惯≥0.55 / 编辑态 | 具体生活句 | **显示** | `{分类label} · 今天 H:mm` + link **改** | 换一句 / 换一句说法 | 显示 |

**L1 强制**：`items.length < 3` 且无品牌 → L1（前 3 笔训练营）。

**L2 判定**：`editingRecordId` **或** `matchBrandInNote()` **或** (`items.length >= 3` && `estimateHabitConfidence() >= 0.55`)。

**低置信**：引擎可静默算分类/emotion 用于 **保存**；L1 **不展示胶囊**（避免装懂）。

---

## 必做 0 · 耳语池（15 条 · 原样写入 `app.js`）

```javascript
const coldStartWhispers = [
  "金额在这就行，分类和备注可以先空着。",
  "只填数额，也算把今天留住了一截。",
  "不用解释为什么花，先记上就好。",
  "分类我会先帮你猜，错了晚点再改。",
  "这一句生活句，放进账本后会自己长出来。",
  "记完去首页，今天会多一段痕迹。",
  "今晚回放时，这一笔会轮到它说话。",
  "花出去的不是分数，是今天真实走过的一下。",
  "记一笔，今天又多了一小块可叙的素材。",
  "细节晚点再补也行，数额先按住这一刻。",
  "早上记下的，会并进今天前半段的故事。",
  "夜里记下的，留给今天的收束来讲。",
  "周末记下的，算进这段日子的一个脚注。",
  "想不起具体买了什么，也没关系。",
  "不用挑分类，先把这一刻记下来。",
];
```

`pickColdStartWhisper(amount, date)` → `stableIndex(\`${amount}|${dateKey}|${hourBucket}\`, length)`。

**amountAssist**：

- L0：`记下一笔今天的生活`
- L1：`数额够了，点下面放进账本。`
- L2：可隐藏或 `金额只是刻度，这一笔会被记住。`

气质：笃定、生活化；**禁止**软腻玄学句、审计词（超支/浪费/克制/预算/剁手）。

---

## 必做 1 · 预览卡 DOM 重构（小纸条）

**文件**：`web-preview/index.html` + `styles.css`

建议结构（Agent 可微调 class，语义须保留）：

```html
<section id="lifeEntryPreview" class="life-entry-preview">
  <p id="lifeEntryHeadline" class="life-entry-headline"><!-- 主行，可点 --></p>
  <p id="lifeEntryEmotion" class="life-entry-emotion hidden"><!-- 胶囊 L2 --></p>
  <div class="life-entry-meta-row">
    <p id="lifeEntryMeta" class="life-entry-meta"></p>
    <button type="button" id="lifeEntryChangeCategory" class="link-btn hidden">改</button>
  </div>
  <div class="life-entry-actions-row">
    <div id="lifeEntryPrimaryAction"></div>
    <button type="button" id="lifeEntryMoreBtn" class="link-btn link-btn--muted hidden">更多</button>
    <span id="lifeEntryAmount" class="life-entry-amount-corner"></span>
  </div>
  <div id="lifeEntryNoteEditor" class="life-entry-note-editor hidden">
    <input id="titleInput" type="text" placeholder="这一笔想怎么被记住？" />
  </div>
  <div id="lifeEntryCategoryPanel" class="life-entry-category-panel hidden">
    <div id="categoryOptions" class="category-options inline"></div>
  </div>
</section>
```

**删除或永久 hidden 首屏**：`#recordDetailsFold` 整条（逻辑迁入预览卡内 panel）。

**视觉**：预览卡主角；L1 `--whisper` 淡底、主行 15–16px regular；金额 corner 小字 muted。

---

## 必做 2 · `updateLifeEntryPreview()` + 交互

### 主行来源（L2）

```text
用户 titleInput（若展开写过）
→ brand displayName / habit title
→ applyScenePack 结果
→ category fallback（吃饭的一小笔）
```

L1 主行：`pickColdStartWhisper()` **或** 固定 `今天的一小笔`（二选一或 whisper 优先）。

### 主动作按钮（动态创建）

| 档 / source | 按钮文案 | click |
|-------------|----------|-------|
| L1 | 帮我写一句 | `rotatePreviewLine()`：guessPack + applyMemberScenePack，**不**先开列表 |
| L2 habit | 换一句 | 同上 + variant++ |
| L2 brand | 换一句说法 | 同上或换品牌 tier 句 |
| L2 generic | 帮我写一句 | 同 L1 |

非会员 L1 → `openAccountOverlay()` 可保留。

### 轻操作接线

| 控件 | 行为 |
|------|------|
| `#lifeEntryHeadline` click | toggle `#lifeEntryNoteEditor`；placeholder 非「备注」 |
| `#lifeEntryChangeCategory` | toggle `#lifeEntryCategoryPanel`；**仅 L2 显示** |
| `#lifeEntryMoreBtn` | open `#scenePackMoreSheet`（二级：列出现有 `memberScenePacks`） |

### 次行 meta

- L1：`今天 · ${compactTime()}`  
- L2：`${categoryLabel} · 今天 ${compactTime()}`  

---

## 必做 3 · 引擎（Web 自包含）

```javascript
function resolveRecordPreviewTier() { ... }
function estimateHabitConfidence() { ... }  // 简化 B2.13
function matchBrandInNote(text) { ... }    // brandsLite ×5
function resolvePreviewEmotion(tier, ctx) {
  // L1: return "" 不展示；保存时仍 inferEmotionTag
  // L2: brand emotion > habit > inferEmotionTag
}
function rotatePreviewLine() {
  // guessMemberScenePackId + stableScenePackNote + variant
  // 更新 headline + titleInput；不展开 UI 模块
}
```

**brandsLite**：luckin / starbucks / mcd / meituan / didi（aliases + emotion + category）。

**删除** `prefillDemoMode` 用户路径；`#prefillDemoBar` 仅 `?debug=1` 或 `DEBUG_UI_ENABLED`。

---

## 必做 4 · `#scenePackMoreSheet`（深操作 · 二级）

- 标题：**更多说法**（不叫场景包）
- 列表：`memberScenePacks` emoji + label；点选 → applyMemberScenePack → 关 Sheet → 更新主行
- L1 默认 **不显示**「更多」；用户点过「帮我写一句」后可显示「更多」（可选）

---

## 必做 5 · 保存行为

- L1 无胶囊展示：**保存时** `emotionTag` 仍 `inferEmotionTag` 或 resolver 静默写入
- 可选 toast：`已记下。去首页看看今天留下的痕迹。`

---

## 禁止

- `NativeDemoApp/`、backend
- 首屏 `recordDetailsFold` / 分类 grid / 场景包列表
- 对用户文案出现「场景包」「备注字段」标签
- git commit（除非用户要求）

---

## 验收

- [ ] 首屏仅：金额 → 预览卡 → 放进账本
- [ ] L1：`9.9` 耳语主行，**无胶囊**，meta 无分类，按钮「帮我写一句」
- [ ] 点「帮我写一句」→ 主行变，**无**包列表展开
- [ ] L2：有胶囊 + meta 含分类 + **改** → 才出 grid
- [ ] 点主行 → 出现「这一笔想怎么被记住？」输入，无「备注」标签
- [ ] 「更多」→ 二级 Sheet 列包；主路径不叫场景包
- [ ] 备注「瑞幸」→ L2 品牌态
- [ ] 前 3 笔偏 L1；第 4 笔起高置信可 L2
- [ ] `?debug=1` 可见旧 demo 条
- [ ] 首页/OCR/保存不回归
- [ ] 问句：**确认**，不是 **配置**

---

## @ 文件

```text
@PROMPT_记账-Web确认而非配置.md
@PRODUCT_VISION_EVAL_v0.1.md
@RECORD_PAGE_DESIGN_v0.1.md
@web-preview/app.js
@web-preview/index.html
@web-preview/styles.css
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task UI-P1.2-WEB — 确认而非配置（记账页）**（仅 web-preview；**同一 PR**）。

## 北极星
**默认让用户确认，不让用户配置。**
首屏永远只有：金额舞台 → 生活预览卡 → 放进账本。
分类/备注/场景包是预览卡背后能力，不是首屏模块。

## 战略
先看 Web 预览验证交互；不动 iOS/backend。引擎 Web 自包含（tier + 5品牌 + 习惯置信简化）。

## 执行顺序
1. 重构 #lifeEntryPreview 小纸条 DOM（主行/胶囊/meta+改/actions/角标金额/内嵌 note+category panel）
2. 移除或永久隐藏 #recordDetailsFold 首屏；#memberScenePackBlock 不首屏展示
3. resolveRecordPreviewTier + estimateHabitConfidence + matchBrandInNote + brandsLite
4. updateLifeEntryPreview() 三档 L0/L1/L2
5. 主动作：帮我写一句/换一句/换一句说法 → rotatePreviewLine() 直接换主行
6. #lifeEntryMoreBtn + #scenePackMoreSheet 二级「更多说法」
7. 主行点击 → #lifeEntryNoteEditor（placeholder：这一笔想怎么被记住？）
8. 改 → #lifeEntryCategoryPanel 才展示 grid
9. coldStartWhispers 15 条 + pickColdStartWhisper
10. prefillDemoBar 仅 debug；styles L1 whisper / L2 完整卡

## 必须先 Read
@PROMPT_记账-Web确认而非配置.md
@PRODUCT_VISION_EVAL_v0.1.md
@RECORD_PAGE_DESIGN_v0.1.md
@web-preview/app.js
@web-preview/index.html
@web-preview/styles.css

---

## 预览三档

| 档 | 条件 | 主行 | 胶囊 | meta | 主动作 |
| L0 | 无金额 | 隐藏预览 | — | — | — |
| L1 | 低置信 / 前3笔无品牌 | 耳语池15条或今天的一小笔 | 隐藏 | 今天·时间 only | 帮我写一句 |
| L2 | 品牌/习惯≥0.55/编辑 | 具体生活句 | 显示 | 分类·今天·时间 + link改 | 换一句/换一句说法 |

L1 引擎可静默算分类emotion用于保存，但不展示胶囊。

---

## 耳语池（15条 · 全部写入 app.js，不得删减）

"金额在这就行，分类和备注可以先空着。"
"只填数额，也算把今天留住了一截。"
"不用解释为什么花，先记上就好。"
"分类我会先帮你猜，错了晚点再改。"
"这一句生活句，放进账本后会自己长出来。"
"记完去首页，今天会多一段痕迹。"
"今晚回放时，这一笔会轮到它说话。"
"花出去的不是分数，是今天真实走过的一下。"
"记一笔，今天又多了一小块可叙的素材。"
"细节晚点再补也行，数额先按住这一刻。"
"早上记下的，会并进今天前半段的故事。"
"夜里记下的，留给今天的收束来讲。"
"周末记下的，算进这段日子的一个脚注。"
"想不起具体买了什么，也没关系。"
"不用挑分类，先把这一刻记下来。"

amountAssist L1：「数额够了，点下面放进账本。」

---

## 场景包 UX（不叫场景包）

主路径：点 帮我写一句/换一句 → rotatePreviewLine() → 主行即时变，不展开包列表
深路径：预览卡 link「更多」→ #scenePackMoreSheet 标题「更多说法」→ 选包 applyMemberScenePack

brandsLite：luckin starbucks mcd meituan didi；备注瑞幸 → L2

---

## 交互

- 点主行 → 显示 titleInput，placeholder「这一笔想怎么被记住？」，禁止「备注」标签
- L2 显示 link「改」→ 展开 category grid panel
- 角标金额在预览卡 actions row 右侧
- 删除 recordDetailsFold 首屏路径

---

## 禁止

NativeDemoApp、backend、首屏分类grid/场景包列表、对用户说「场景包」、git commit（除非用户要求）

---

## 验收

- [ ] 首屏仅三段
- [ ] L1 9.9 耳语无胶囊；帮我写一句直接换主行
- [ ] L2 有改/有更多；点改才出分类
- [ ] 点主行手写；无备注字段感
- [ ] 瑞幸备注 → L2
- [ ] 前3笔L1；保存首页不回归
- [ ] 像确认不像配置

---

## 交付

1. 改动文件列表
2. 三档规则 + 轻/深操作说明
3. 验收勾选
4. 未做：iOS UI-P1.2

最小 diff，仅 web-preview/。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版：综合「确认而非配置」8 条 + UI-P1.1 耳语池；取代 P1.1 为最新 Web prompt |
