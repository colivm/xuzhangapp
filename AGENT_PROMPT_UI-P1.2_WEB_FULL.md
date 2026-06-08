# Agent Prompt · Task UI-P1.2-WEB — 记账页综合抛光（最新 · 仅 web-preview）

> **状态：待做 · 当前唯一 Web 记账页 Agent prompt**  
> **取代**：`P1.2_WEB_CONFIRM_NOT_CONFIG` / `P1.2b_WEB_POLISH` / `P1.2c_WEB_VISUAL_POLISH`（策略已并入本文）  
> **范围**：仅 `web-preview/`；**不动** iOS / backend / tier 判定规则 / 耳语池 15 条原文  
> **本 PR 目标**：**不堆功能** — 把已有 L0/L1/L2 策略 **收住视觉、安静交互、统一叙账语气、藏旧表单痕迹**  
> 用法：**整段复制文末「复制发送」** 发给 Agent。

---

## 0. 一句话任务

把记账页从「表单页改造 + 控件拼盘」抛光成 **「金额 → 一张生活纸条 → 放进账本」**；用户第一眼看到 **一句生活**，操作 **轻、晚、低对比**。

---

## 1. 产品北极星（不可破）

```text
默认让用户确认，不让用户配置。
记账页 = 把一段生活放进账本，不是填写金额表单。
```

**首屏主路径永远三段**（中间不得插入 fold / segment / demo 条）：

```text
1. 金额舞台
2. 生活纸条（life-slip）
3. 放进账本（全页唯一主色 CTA）
```

**禁止首屏主路径出现**：分类 chip grid、备注字段标签、`recordDetailsFold`、`memberScenePackBlock` 列表、`prefillDemoBar`（非 debug）、双按钮模式切换 segment。

---

## 2. 创始人诊断 → 本 PR 修复对照

| 糙感（实测） | 根因（当前代码） | 本 PR 目标 |
|-------------|-----------------|-----------|
| 层级对，视觉没收住 | 主行/胶囊/meta/按钮各自像控件；`scene-primary-btn` pill 抢戏 | **一张** `life-slip` 视觉对象，body + foot 一体 |
| 旧 Demo / 表单底子 | `#recordModeSegment` 在底部；快捷金额四颗大 pill；调试条可见 | OCR **侧门** link；快捷金额低调；demo 仅 `?debug=1` |
| 文案气质不统一 | `moreCopy`「路上的一句」；pack `desc` 带「比如输入¥」；hint 像说明书 | 全链路 **叙账语气**（§8） |
| 交互太工具化 | foot 大 pill +「更多」与换句并列；无「自己写一句」；主行可点无 affordance | foot **全 link**；操作分层（§6） |
| L1 像功能卡 | `--whisper` 仍有重卡边框 | L1 **轻耳语**：像提示，不像卡 |
| L2 主次不清 | 主行 18px、胶囊实心底、金额与按钮抢行 | L2 **确认卡**：主行 20–22px；胶囊弱化；金额安静 |

---

## 3. 预览三档策略（逻辑已定 · 本 PR 不改判定）

实现于 `resolveRecordPreviewTier()` — **只允许改 UI 绑定，不改 if 条件**（ obvious bug 除外）。

| 档 | 条件 | 主行 | 胶囊 | meta | foot 轻操作 | 换个角度 |
|----|------|------|------|------|------------|----------|
| **L0** | 无有效金额 | —（隐藏纸条） | — | — | — | hidden |
| **L1** | 有金额 + 低置信 | `pickColdStartWhisper()` | **隐藏** | `今天 · H:mm`（无分类） | `帮我写一句` \| `自己写一句` | **hidden** |
| **L2** | 品牌 / 习惯≥0.55 / 编辑 / 点过换句 | 生活句 | 显示（弱化样式） | `{分类} · 今天 H:mm` + link **改** | `换一句` \| `自己写一句`（brand：`换说法`） | 条件显示 |

**L1 强制**：`items.length < 3` 且无品牌 → L1。  
**L2 触发**：`editingRecordId` \| `matchBrandInNote()` \| `previewLineWasRotated` \| (`items>=3` && habit≥0.55)。

**引擎静默**：L1 保存仍写分类/emotion；UI 不展示胶囊。

---

## 4. 首屏信息架构（含 OCR · 已拍板）

### 4.1 主路径 DOM 顺序

```text
kicker「把一笔生活放进账本」
h2「记下这一笔」（可略缩小，让金额舞台更主角）
────────
#amountStage          金额舞台
#recordImportRow       有账单截图？ + 轻 link「从截图导入 →」（侧门，非 segment）
#lifeEntryPreview      生活纸条 life-slip
#recordPrimaryActions   放进账本
（编辑态：删除 / 日期）
```

### 4.2 OCR = 侧门，不是模式切换器

- **移除或永久隐藏** `#recordModeSegment`（手动录入 \| 智能导入）于主路径
- 新增 `record-import-row`：金额舞台下方一行——说明 `有账单截图？`（muted）+ link `从截图导入 →`（`#recordImportLink`）
- 点击 → 展开 `#ocrForm`（可 slide-down，非全页 Tab 切换）；引导 copy：`从账单里捞一段生活，确认后再放进账本`
- `state.recordMode` / OCR 逻辑 **保留**；UI 上不呈现双按钮 segment
- OCR 区内主按钮 copy 偏叙事：`选择截图，捞进账本`（可微调，禁止「上传票据填表」腔）

### 4.3 藏起来的旧模块

| 元素 | 处理 |
|------|------|
| `#amountQuickKeyboard` | 默认 hidden；focus 时显示 **小 link 行** `.00 \| +10 \| +50 \| +100`（非四颗大 pill） |
| `#prefillDemoBar` | 仅 `?debug=1` 或 `DEBUG_UI_ENABLED` |
| `#recordDetailsFold` | 永久 hidden + aria-hidden |
| `#memberScenePackBlock` | 不在记账页主路径渲染（数据仍供 Sheet / 引擎用） |

---

## 5. 生活纸条 · 视觉对象（核心抛光）

**文件**：`index.html` 结构调整 + `styles.css` 重写 `.life-entry-*` → `.life-slip-*`（可保留旧 id，class 迁移）

### 5.1 推荐结构

```html
<section id="lifeEntryPreview" class="life-slip hidden">
  <div class="life-slip-body">
    <p id="lifeEntryHeadline" class="life-slip-headline"></p>
    <p id="lifeEntryHeadlineHint" class="life-slip-hint hidden"></p>
    <p id="lifeEntryEmotion" class="life-slip-mood hidden"></p>
    <p id="lifeEntryMeta" class="life-slip-meta muted">
      <!-- 分类·时间；L2 末尾内嵌 button#lifeEntryChangeCategory 改 -->
    </p>
  </div>
  <div class="life-slip-foot">
    <nav id="lifeEntryQuietActions" class="life-slip-quiet-actions" aria-label="轻操作"></nav>
    <span id="lifeEntryAmount" class="life-slip-amount"></span>
  </div>
  <div id="lifeEntryNoteEditor" class="life-slip-expand hidden">
    <input id="titleInput" type="text" placeholder="这一笔想怎么被记住？" />
  </div>
  <div id="lifeEntryCategoryPanel" class="life-slip-expand hidden">
    <div id="categoryOptions" class="category-options inline"></div>
  </div>
</section>
```

**视觉原则**：

- **一个容器**：圆角 20–24px、极淡纸感；子块 **不得** 各自像独立 button card
- **body / foot**：12px 留白或 1px 极淡分隔线；foot **不是** 第二面板
- **禁止** foot 出现 `scene-primary-btn` / `scene-quick-btn` / 与「放进账本」同权重的主色块
- **删掉** `#lifeEntryPrimaryAction` 动态 pill 渲染；改由 `#lifeEntryQuietActions` 纯 link 承担

### 5.2 L1 · `life-slip--whisper`

| 属性 | 值 |
|------|-----|
| 容器 | 无重阴影；可选左侧 2px accent 竖线；背景几乎融入 panel |
| 主行 | 15–16px **regular**，subtext 色，行高 1.55 |
| 胶囊 | 不显示 |
| meta | 11px muted |
| foot | `帮我写一句` \| `自己写一句`（12px link，竖线分隔） |
| 角标金额 | 11px，opacity ~0.55，tabular-nums，右下 |

感受：**一行许可 + 安静金额**，不是「又一张功能卡」。

### 5.3 L2 · `life-slip--confirm`

| 属性 | 值 |
|------|-----|
| 主行 | **20–22px semibold**，text 色，最大权重 |
| 胶囊 mood | 11px；无实心底或 50% 描边；主行下 6px，**附注感** |
| meta | 12px；`吃饭 · 今天 16:24`；**改** 为同行末尾 link（非独立行） |
| foot | 见 §6 |
| 角标金额 | 12px subtext，弱于主行，foot 右下 |
| hint | 引擎句时显示（§7） |

### 5.4 金额舞台节奏

- L0 `amountAssist`：`记下一笔今天的生活`
- L1：`数额够了。`（短，不抢纸条）
- L2：hidden 或极淡 `金额只是刻度`（二选一，须安静）
- `amountStage` → `life-slip` → `save-row` 间距 16–20px

---

## 6. 安静操作 · 交互分层（功能 + 质感合一）

### 6.1 三层分工

| 层 | 控件 | 行为 |
|----|------|------|
| **轻 · foot link** | 换句族 / 自己写 / 换个角度 | 见下表 |
| **轻 · meta** | **改** | toggle `#lifeEntryCategoryPanel`；**仅 L2**；默认不展开 grid |
| **深 · expand** | 手写输入 / 分类 grid | 默认 hidden；用户主动才展开 |

### 6.2 foot 文案（`#lifeEntryQuietActions` 动态渲染）

用 `button.link-quiet` 或 `<a role="button">`，竖线 `|` 分隔，**无 pill、无渐变、无 emoji 前缀**（去掉 `✨`）。

| tier / 状态 | foot |
|-------------|------|
| L1 | `帮我写一句` \| `自己写一句` |
| L2 未换句 | `换一句` \| `自己写一句`（brand：`换说法`） |
| L2 已换句 | `换一句` \| `换个角度` \| `自己写一句` |

**换个角度** 显示条件：`previewLineWasRotated === true` **或**（`tier===L2` && `source!=='cold'`）。**L1 永不显示**。

### 6.3 各控件行为（接线须完整）

| 控件 | click |
|------|-------|
| `帮我写一句` / `换一句` / `换说法` | `rotatePreviewLine()`：guessPack + applyMemberScenePack / brand lines；**不**自动展开分类 grid |
| `自己写一句` | `noteEditorExpanded=true`；展开 `#lifeEntryNoteEditor`；focus `#titleInput`；**L1/L2 均可见** |
| `换个角度` | `openScenePackMoreSheet()` |
| `改` | toggle `#lifeEntryCategoryPanel` |
| `#lifeEntryHeadline` click | 仍可展开手写（辅助）；**不能**作为唯一「自己写」入口 |

### 6.4 样式

- link：12px；hover 仅 underline 或 opacity 0.85；**无**背景色块
- 预览卡 foot 视觉权重 **低于** 主行 **远低于**「放进账本」

---

## 7. 系统句 hint

`#lifeEntryHeadlineHint`：11px muted，主行下 4px。

**显示条件**：主行来自引擎（品牌/习惯/换句）且用户未手写覆盖。

**文案（叙式，非说明书）**：

```text
想换说法，点下面轻字即可
```

用户手写或与引擎句不同 → hidden。

~~禁止~~：`系统先写了一句 · 可点「自己写一句」…`（太工具）。

---

## 8. 文案气质 · 叙账语气规范

### 8.1 规则

- ✅ 生活瞬间、周记感、可叙之材、笃定不软腻
- ❌ 功能提示（「适合通勤类小记」）、填表腔（「比如输入¥」）、审计词（超支/浪费/预算/剁手）、广告腔
- ❌ 对用户出现「场景包」「备注字段」标签

### 8.2 耳语池（15 条 · 原文不得改）

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

### 8.3 品牌 emotion + lines（展示用 · 可润色但须过审）

| id | emotion（胶囊） | lines 轮换示例 |
|----|----------------|----------------|
| luckin | 早班路上，顺手续一口 | 同上 / 蓝杯小小提神 / 赶路前醒一醒 |
| starbucks | 给自己留一小段坐下来的时间 | 咖啡香里缓一会儿 / 今天短暂停靠 |
| mcd | （保持生活感，去广告腔） | 随手填饱的一顿 / 赶时间也要吃一口 |
| meituan | （保持生活感） | 外卖送到门口的一餐 / 懒得下厨的今天 |
| didi | （保持生活感） | 这一段路，交给车轮 / 赶时间的短途 |

`memberScenePacks[].desc`：**不得**出现在用户可见 UI（仅引擎 rules 可用）。

### 8.4 换个角度 Sheet（取代 `moreCopy` 硬编码）

**删除** `openScenePackMoreSheet` 内 `路上的一句` / `吃饭的一句` 等。

Sheet 标题：**换个角度**  
Sheet 副标题：**从另一种生活角度，记下这一笔。**

| pack.id | 列表主标题（`pack.label`） | tagline（新建 `scenePackMoreTaglines`） |
|---------|---------------------------|----------------------------------------|
| commute | 打工人通勤包 | 地铁公交，赶路路上的一小段 |
| food | 吃货专属包 | 一顿饭、一杯喝的、小聚 |
| travel | 旅行预算包 | 出发、途中、沿路痕迹 |
| pet | 铲屎官宠物包 | 宠物日常与陪伴 |

列表项：标题 semibold + tagline 一行 muted；**禁止**副文案含 `比如`、`适合 XXX 类`、`XX的一句`。

---

## 9. 引擎参考（已存在 · 补齐接线即可）

```text
resolveRecordPreviewTier()     tier 判定
estimateHabitConfidence()      习惯置信
matchBrandInNote() + brandsLite×5
pickColdStartWhisper()         L1 主行
rotatePreviewLine()            换句主路径
applyMemberScenePack()         场景句写入 titleInput
guessMemberScenePackId()       猜包
inferEmotionTag()              L2 胶囊
renderPreviewPrimaryAction()   → 本 PR 删除 pill 路径，改 renderQuietActions()
```

**`rotatePreviewLine` 注意**：非 brand 分支 `applyMemberScenePack` 后 `return` 前须 `updateLifeEntryPreview()` 并设 `previewLineWasRotated=true`；换句后显示「换个角度」。

---

## 10. 当前实现缺口（Agent 对照改）

基于 `web-preview` 现状，本 PR **至少**修以下项：

| # | 现状 | 目标 |
|---|------|------|
| 1 | `#recordModeSegment` 在 `#manualForm` **之后**（页面底部） | 主路径 **无 segment**；改 `#recordImportLink` 侧门 |
| 2 | `renderPreviewPrimaryAction` 创建 `scene-primary-btn` / `scene-quick-btn` | 删除；`renderQuietActions()` 纯 link |
| 3 | 无 `#lifeEntryWriteOwnBtn` / `#lifeEntryHeadlineHint` | 按 §5 DOM 增补 |
| 4 | `#lifeEntryMoreBtn` 文案「更多」；L2 全显示 | 改名「换个角度」；按 §6.2 条件显示 |
| 5 | `openScenePackMoreSheet` 用 `moreCopy`「路上的一句」 | §8.4 tagline |
| 6 | Sheet 标题「更多说法」 | 「换个角度」 |
| 7 | `#amountQuickKeyboard` 四颗大 pill 常显可能 | focus 时小 link |
| 8 | L1 `--whisper` 仍有明显边框阴影 | §5.2 轻耳语 |
| 9 | `lifeEntryMoreBtn` 与换句 pill 并排难懂 | foot 统一 quiet actions |

---

## 11. 实施顺序（建议）

```text
1. index.html：life-slip DOM + recordImportLink；移/藏 recordModeSegment
2. app.js：renderQuietActions；删 renderPreviewPrimaryAction pill；hint / 自己写一句 / 换个角度条件
3. app.js：openScenePackMoreSheet 叙式 tagline；品牌 lines 过审
4. styles.css：life-slip L1 whisper / L2 confirm；quiet link；金额舞台节奏
5. app.js：快捷金额低调；prefillDemoBar debug gate（若无则补）
6. 自测验收 §12
```

**最小 diff**：仅 `web-preview/index.html` · `app.js` · `styles.css`。

---

## 12. 验收清单

### 质感问句

> 用户第一眼看到的是 **一句生活**，还是 **一排按钮**？

### 必过

- [ ] 首屏主路径：金额 → 纸条 → 放进账本（**无** segment、无 fold、无 demo 条）
- [ ] L1：像 **轻提示**；无胶囊；foot `帮我写一句|自己写一句`；无「换个角度」
- [ ] L2：主行最大；胶囊淡；金额安静；`改` 在 meta 行末
- [ ] L2 换句后：hint + foot 含「换个角度」
- [ ] 「自己写一句」可见且 focus 输入框（不必先点黑字）
- [ ] 「改」才出分类 grid；换句 **不** 自动展开 grid
- [ ] 换个角度 Sheet：pack.label + 叙式 tagline；无「路上的一句」
- [ ] OCR：轻 link 侧门；不像 Tab 模式切换
- [ ] 快捷金额：非首屏大 pill 占位
- [ ] `?debug=1` 可见 prefill demo；默认不可见
- [ ] 清空数据输 `10` → L1 耳语；备注「瑞幸」→ L2 品牌
- [ ] tier 判定行为与改前一致
- [ ] 首页 / OCR 保存 / 编辑不回归

### 可选

- [ ] L1 首笔保存 toast：`已记下。首页会慢慢长出这一笔的痕迹。`

---

## 13. 禁止

- 改 `resolveRecordPreviewTier` 判定条件（除非 obvious bug）
- 改 `coldStartWhispers` 15 条原文
- 新增业务功能 / 新 tier
- `NativeDemoApp/` · `backend/`
- git commit（除非用户明确要求）

---

## 14. @ 文件

```text
@AGENT_PROMPT_UI-P1.2_WEB_FULL.md
@PRODUCT_VISION_EVAL_v0.1.md
@RECORD_PAGE_DESIGN_v0.1.md
@web-preview/index.html
@web-preview/app.js
@web-preview/styles.css
```

---

## 15. 复制发送

见同目录 `AGENT_PROMPT_UI-P1.2_WEB_COPY.txt`（纯文本，无嵌套代码块，可直接全选复制）。

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 综合版：合并 P1.2 策略 + P1.2b 交互 + P1.2c 视觉 + 创始人实测糙感；OCR 侧门拍板；取代分拆 prompt |
