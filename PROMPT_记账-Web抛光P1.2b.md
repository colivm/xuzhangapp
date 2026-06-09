# Agent Prompt · Task UI-P1.2b-WEB — 记账页抛光（最新 Web 预览 · 仅 web-preview）

> **状态：待做 · 当前最新 Web Agent prompt**  
> 继承 [`PROMPT_记账-Web确认而非配置.md`](PROMPT_记账-Web确认而非配置.md) 分级策略；本 PR **补齐实现糙点**。  
> **北极星**：**默认让用户确认，不让用户配置。**  
> **依赖：无** — 仅 `web-preview/`；**不动 iOS** / backend。  
> 用法：**整段复制下方「复制发送」** 发给 Agent。

---

## 背景（创始人反馈）

分级策略（L0/L1/L2）**方向对**，当前 Web 实现 **偏糙**：

| 糙点 | 应变成 |
|------|--------|
| 手动/导入切换沉到页面底部 | 回到标题下，不进三段主流程 |
| 「更多」与「换一句」并排难懂 | 主路径换句；**换个角度** 为深操作、晚出现 |
| 「更多说法」文案「路上的一句」 | 用场景包 **label + 叙式 tagline** |
| 主行黑字可点但无提示 | 可见 **自己写一句** link，与 **改** 对称 |
| 点一次换句立刻满配 L2 | 可分步：先更主行，胶囊可稍后（本 PR 至少加 hint） |
| 引擎句像定稿 | 系统句下小字 hint |

若 P1.2 部分未做，本 PR **一并实现**；若已做，**以抛光 diff 为主**。

---

## 任务编号

| ID | 内容 |
|----|------|
| UI-P1.2-WEB | 确认式分级 + 小纸条预览 |
| **UI-P1.2b-WEB** | **本 prompt · 抛光** |

---

## 首屏结构（不可破）

```text
标题 + 模式切换（手动录入 | 智能导入）  ← 必须在顶部
────────
金额舞台
生活预览卡
放进账本
```

**禁止**：分类 grid、备注标签、场景包列表、`recordDetailsFold` 首屏、`prefillDemoBar`（仅 debug）。

---

## 预览三档

| 档 | 条件 | 主行 | 胶囊 | meta | 主动作 | 换个角度 | 自己写 |
|----|------|------|------|------|--------|----------|--------|
| L0 | 无金额 | — | — | — | — | — | — |
| L1 | 低置信 / 前3笔无品牌 | 耳语15条 | 隐藏 | 今天·时间 | 帮我写一句 | hidden | link |
| L2 | 品牌/习惯/编辑/点过换句 | 生活句 | 显示 | 分类·今天·时间 + **改** | 换一句/换一句说法 | 条件显示 | link |

**L2 触发**：`editingRecordId` | `matchBrandInNote` | `previewLineWasRotated` | (`items>=3` && habit≥0.55)

**L1 强制**：`items.length < 3` 且无品牌 → L1

**引擎**：L1 保存仍写分类/emotion；UI 不 SHOW 胶囊。

---

## 必做 1 · 模式切换回顶部

**文件**：`web-preview/index.html`

将 `#recordModeSegment` 移到 `#recordFormTitle` **正下方**、`#manualForm` **之前**。

OCR 表单仍在 segment 切换下，逻辑不变。

---

## 必做 2 · 预览卡 actions 分层

**DOM**（在 `#lifeEntryPreview` 内增补）：

```html
<p id="lifeEntryHeadlineHint" class="life-entry-headline-hint hidden"></p>
<div class="life-entry-actions-row">
  <div id="lifeEntryPrimaryAction"></div>
  <button id="lifeEntryWriteOwnBtn" type="button" class="link-btn">自己写一句</button>
  <button id="lifeEntryMoreBtn" type="button" class="link-btn link-btn--muted hidden">换个角度</button>
  <span id="lifeEntryAmount" class="life-entry-amount-corner"></span>
</div>
```

### 按钮语义（禁止并列两个「换文案」主按钮）

| 控件 | 行为 |
|------|------|
| **帮我写一句 / 换一句 / 换一句说法** | `rotatePreviewLine()`，系统直接换主行 |
| **自己写一句** | `noteEditorExpanded=true`，focus `#titleInput`；**L1/L2 均显示** |
| **换个角度**（原「更多」） | 仅当 `previewLineWasRotated === true` **或** `tier===L2` 且非 L1 时显示；开 Sheet |

**禁止** L1 显示「换个角度」。

### 系统句 hint（`#lifeEntryHeadlineHint`）

当主行来自引擎（换句/习惯/品牌）且 `titleInput` 为空或与引擎句相同：

```text
系统先写了一句 · 可点「自己写一句」改成你的话
```

用户手写后 **hidden**。字号 11px muted。

主行 `cursor:pointer` 保留，但 **不能作为唯一入口**。

---

## 必做 3 · 「换个角度」Sheet 文案（取代草率占位）

**删除** `moreCopy` 硬编码「路上的一句」。

改用 `memberScenePacks` + **叙式 tagline**（展示用，可新建 `pack.tagline` 或 `scenePackMoreTaglines` 对象）：

| id | 标题（用 pack.label） | 副文案 tagline |
|----|----------------------|----------------|
| commute | 打工人通勤包 | 地铁、公交、赶路路上的一小段 |
| food | 吃货专属包 | 一顿饭、一杯喝的、一顿小聚 |
| travel | 旅行预算包 | 出发、途中、沿路留下的小痕迹 |
| pet | 铲屎官宠物包 | 宠物日常、照顾和陪伴 |

**禁止**副文案出现：`比如：输入 ¥`、`适合 XXX 这一类`、`XX的一句`。

Sheet 标题：**换个角度**（不用「更多说法」）  
Sheet 副标题：**从不同生活角度，换种说法记下这一笔。**

点选项 → `applyMemberScenePack` → 关 Sheet → 更新主行；`previewLineWasRotated=true`。

---

## 必做 4 · 耳语池（15 条 · 不得删减）

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

**amountAssist**：L1 `数额够了，点下面放进账本。` · L0 `记下一笔今天的生活`

---

## 必做 5 · 引擎（保持 / 补齐）

- `resolveRecordPreviewTier()` / `estimateHabitConfidence()` / `matchBrandInNote()` + **brandsLite×5**
- `rotatePreviewLine()` 不自动展开分类 panel
- `#lifeEntryChangeCategory` 仅 L2；点 **改** 才 toggle `#lifeEntryCategoryPanel`
- `#prefillDemoBar` 仅 `?debug=1` 或 `DEBUG_UI_ENABLED`

---

## 必做 6 · 样式抛光 `styles.css`

- `.life-entry-actions-row`：主按钮 pill + link 分组；link 字号 12px
- `.life-entry-headline-hint`：11px muted，margin-top 4px
- `.life-entry-preview--whisper`：L1 淡底、主行 regular
- `#recordModeSegment` 顶部间距与标题对齐
- 换个角度 Sheet 列表项：标题 semibold + tagline 一行 muted

---

## 可选

- L1 首次保存 toast：`已记下。首页会慢慢长出这一笔的痕迹。`
- `localStorage` 一次 hint：`不用写备注，点放进账本也行`（仅首笔）

---

## 禁止

- NativeDemoApp / backend
- 对用户文案「场景包」「备注字段」
- 首屏分类 grid / 场景包列表
- git commit（除非用户要求）

---

## 验收

- [ ] **模式切换在标题下**，不在页面底部
- [ ] 清空数据 → 只输 10：**L1 耳语**，无胶囊，有 **帮我写一句** + **自己写一句**，无 **换个角度**
- [ ] 点 **换一句** → 主行变；出现 hint；出现 **换个角度**
- [ ] 点 **自己写一句** → 输入框出现（不必先点黑字）
- [ ] **换个角度** Sheet 用 pack.label + tagline，无「路上的一句」
- [ ] 点 **改** 才出分类 grid；默认不出
- [ ] 备注瑞幸 → L2 品牌
- [ ] 首屏仍仅：金额 → 预览 → 放进账本（+ 顶部模式切换）
- [ ] 像 **确认**，不像 **配置**

---

## @ 文件

```text
@PROMPT_记账-Web抛光P1.2b.md
@PROMPT_记账-Web确认而非配置.md
@PRODUCT_VISION_EVAL_v0.1.md
@web-preview/index.html
@web-preview/app.js
@web-preview/styles.css
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task UI-P1.2b-WEB — 记账页抛光**（仅 web-preview；**同一 PR**）。

## 北极星
**默认让用户确认，不让用户配置。**
分级 L0/L1/L2 策略保留；本 PR 修实现糙点。

## 战略
仅 web-preview；不动 iOS/backend。若 P1.2 未完成则一并实现分级与小纸条结构。

## 执行顺序
1. #recordModeSegment 移到 #recordFormTitle 正下方（修底部错位）
2. 预览卡增 lifeEntryWriteOwnBtn + lifeEntryHeadlineHint；「更多」改名为「换个角度」
3. 换个角度 仅 previewLineWasRotated 或 L2 显示；L1 不显示
4. openScenePackMoreSheet 改用 memberScenePacks.label + 叙式 tagline（见下表）
5. 系统句 hint：「系统先写了一句 · 可点「自己写一句」改成你的话」
6. 自己写一句 → 展开 titleInput 并 focus（L1/L2 均可见）
7. 改 → 才展开分类 grid；换一句不自动展开 grid
8. 耳语池 15 条、tier 引擎、brandsLite×5、debug demo 条
9. styles 抛光 actions 分层 + hint + whisper 态

## 必须先 Read
@PROMPT_记账-Web抛光P1.2b.md
@web-preview/index.html
@web-preview/app.js
@web-preview/styles.css

---

## 首屏
标题下：手动录入 | 智能导入
然后：金额舞台 → 生活预览卡 → 放进账本

## 预览三档
L0 无金额 | L1 耳语无胶囊 meta仅今天·时间 | L2 完整卡+改
L1：帮我写一句 + 自己写一句（无换个角度）
L2：换一句/换一句说法 + 自己写一句 + 换个角度（条件显示）

## 换个角度 Sheet（禁止「路上的一句」）
commute → 打工人通勤包 · 地铁、公交、赶路路上的一小段
food → 吃货专属包 · 一顿饭、一杯喝的、一顿小聚
travel → 旅行预算包 · 出发、途中、沿路留下的小痕迹
pet → 铲屎官宠物包 · 宠物日常、照顾和陪伴
Sheet 标题：换个角度；副标题：从不同生活角度，换种说法记下这一笔。

## 耳语池（15条全保留）
金额在这就行，分类和备注可以先空着。
只填数额，也算把今天留住了一截。
不用解释为什么花，先记上就好。
分类我会先帮你猜，错了晚点再改。
这一句生活句，放进账本后会自己长出来。
记完去首页，今天会多一段痕迹。
今晚回放时，这一笔会轮到它说话。
花出去的不是分数，是今天真实走过的一下。
记一笔，今天又多了一小块可叙的素材。
细节晚点再补也行，数额先按住这一刻。
早上记下的，会并进今天前半段的故事。
夜里记下的，留给今天的收束来讲。
周末记下的，算进这段日子的一个脚注。
想不起具体买了什么，也没关系。
不用挑分类，先把这一刻记下来。

## 交互分工
换一句 = 系统自动换主行（一键备注主路径）
换个角度 = 选手动角度（深操作，晚出现）
自己写一句 = 展开输入（可见入口，不依赖点黑字）
改 = 分类纠错，才出 grid

## 禁止
NativeDemoApp、backend、首屏分类/场景包列表、对用户说场景包/备注、git commit（除非用户要求）

## 验收
- [ ] 模式切换在顶部
- [ ] L1 耳语+自己写一句，无换个角度
- [ ] 换句后有 hint+换个角度
- [ ] Sheet tagline 叙式无草率占位
- [ ] 改才出分类
- [ ] 首屏三段+顶栏切换
- [ ] 像确认不像配置

## 交付
1. 改动文件列表
2. 糙点修复对照表
3. 验收勾选
4. 未做：iOS UI-P1.2

最小 diff，仅 web-preview/。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版：P1.2 策略 + 抛光 6 条；最新 Web prompt |
