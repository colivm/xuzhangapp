# Agent Prompt · Task UI-P1.1-WEB — 冷启动极简预览（仅 web-preview）

> **状态：待做**  
> **战略**：输入层「记时极简」——冷启动只露 **金额 + 许可耳语 + 放进账本**；丰盈留在引擎与回望。  
> **依赖：无** — 仅改 `web-preview/`；**不动 iOS**、不动 backend、不要求 F1.3/B2.13 全量移植。  
> 用法：**整段复制下方「复制发送」** 发给 Agent。

---

## 任务编号对照

| ID | 做什么 | 范围 | 状态 |
|----|--------|------|------|
| UI-P1-WEB | 记账页叙事壳 | web-preview | ✅ 已有 |
| **UI-P1.1-WEB** | **本 prompt · 预览分级 L1/L2 + 冷启动极简** | web-preview | ⏳ 本任务 |
| UI-P1.1 | iOS 同理念（另 PR） | NativeDemoApp | 📋 本 PR 不做 |

---

## 产品结论（Agent 须先理解）

**问题**：冷启动时预览卡 + 场景包 + 分类 chip 同时出现，像「填表」不像「先留下来」。

**原则**（[`PRODUCT_VISION_EVAL_v0.1.md`](PRODUCT_VISION_EVAL_v0.1.md)）：

```text
输入层：许可（可以不想清楚）
叙事成品：主要在列表 / 今日小记 / 回放里第一次被听见
```

**耳语气质（L1 必守）**：

| 要 | 不要 |
|----|------|
| 笃定、生活化、像朋友放行 | 腻、玄学、过度柔软（「悄悄」「慢慢有形状」堆砌） |
| 明确「只金额也够」 | 说教、催填备注/分类 |
| 指向「晚点会在首页/回放看见」 | KPI、审计、省钱暗示 |

过 [`CATEGORY_SCENE_COPY_AUDIT_v0.1.md`](CATEGORY_SCENE_COPY_AUDIT_v0.1.md) §2 问句；**禁止**：超支、浪费、克制、理性消费、预算、剁手。

**预览分级**：

| 级别 | 条件（Web 简化判定） | 用户看到 |
|------|----------------------|----------|
| **L0** | 无有效金额 | 金额舞台 +「记下一笔今天的生活」 |
| **L1** | 有金额 + 冷启动 | **一行耳语** + corner 金额 + CTA；**无胶囊、无分类 meta、无场景包区块** |
| **L2** | 品牌命中 / 习惯态 / 第 4 笔起且置信够 | 完整预览卡（主行 + 胶囊 + meta + 快捷动作） |

---

## 必做 0 · L1 耳语池（定稿 · 须完整写入 `app.js`）

**选取**：`stableIndex(seed, coldStartWhispers.length)`，seed = `amount|dateKey|hourBucket`（与现有 stable 逻辑一致）。

```javascript
const coldStartWhispers = [
  // 许可：只金额就够
  "金额在这就行，分类和备注可以先空着。",
  "只填数额，也算把今天留住了一截。",
  "不用解释为什么花，先记上就好。",
  // 引擎承接
  "分类我会先帮你猜，错了晚点再改。",
  "这一句生活句，放进账本后会自己长出来。",
  // 回望指向
  "记完去首页，今天会多一段痕迹。",
  "今晚回放时，这一笔会轮到它说话。",
  // 生活切片感（笃定，不腻）
  "花出去的不是分数，是今天真实走过的一下。",
  "记一笔，今天又多了一小块可叙的素材。",
  "细节晚点再补也行，数额先按住这一刻。",
  // 时段轻语境（仍一句，不拆 UI）
  "早上记下的，会并进今天前半段的故事。",
  "夜里记下的，留给今天的收束来讲。",
  "周末记下的，算进这段日子的一个脚注。",
  // 冷启动安心
  "想不起具体买了什么，也没关系。",
  "不用挑分类，先把这一刻记下来。",
];
```

**共 15 条**；Agent **不得**删减为 3 条，不得改回旧版「悄悄并进今天」类软腻句。

**金额舞台辅助句（L0→有金额，非 preview 内）** `amountAssist` 可与耳语分工：

- 无金额：`记下一笔今天的生活`
- 有金额 + L1：`数额够了，点下面放进账本。`（固定一句，**不**与耳语重复）

---

## 必做 1 · `resolveRecordPreviewTier()`（Web 自包含）

**文件**：`web-preview/app.js`

```javascript
// 返回 "L0" | "L1" | "L2"
function resolveRecordPreviewTier() { ... }
```

**L2 判定（任一满足）**：

1. `editingRecordId` 非空 → 始终 L2（编辑需全字段）
2. `matchBrandInNote(refs.titleInput.value)` 命中
3. `state.items.length >= 3` **且** `estimateHabitConfidence() >= 0.55`（第 4 笔起才可能）

**L1 强制**：

- `state.items.length < 3` **且** 无品牌命中 → **强制 L1**（前 3 笔极简训练营）

**习惯置信（简化 B2.13）**：

```javascript
function estimateHabitConfidence() {
  // 近 180 天 items；hourBucket(÷3) + weekend + amountBand(±30%)
  // 统计 category 计数 → top1/(top1+top2)；<0.55 不算习惯
}
```

**删除** `prefillDemoMode` / `prefillDemoPresets` 作为用户主路径；`updateLifeEntryPreview()` **只读 tier**。

---

## 必做 2 · 轻量 `matchBrandInNote`（5 品牌）

**文件**：`web-preview/app.js`（或 `narrative/brands-lite.js`）

```javascript
const brandsLite = [
  { id: "luckin", displayName: "瑞幸咖啡", aliases: ["瑞幸咖啡","瑞幸","luckin"],
    emotion: "早班路上，顺手续一口", category: "餐饮" },
  { id: "starbucks", displayName: "星巴克", aliases: ["星巴克","starbucks"],
    emotion: "窗边坐一会儿", category: "餐饮" },
  { id: "mcd", displayName: "麦当劳", aliases: ["麦当劳","mcdonald","mcd"],
    emotion: "忙里垫一口热的", category: "餐饮" },
  { id: "meituan", displayName: "美团", aliases: ["美团","meituan"],
    emotion: "外卖到了，先吃饭", category: "餐饮" },
  { id: "didi", displayName: "滴滴", aliases: ["滴滴","didi"],
    emotion: "这段路先记下来", category: "交通" },
];
```

备注命中 → L2；胶囊用 `emotion`；快捷「换一句说法」。

---

## 必做 3 · 重写 `updateLifeEntryPreview()`

| tier | DOM |
|------|-----|
| L0 | `#lifeEntryPreview` hidden |
| L1 | class `life-entry-preview--whisper`；headline=耳语池；隐藏 `#lifeEntryEmotion`；meta=`今天 · M/D`（**无分类**）；quickActions=「✨ 帮我写一句」+ link「补充细节」 |
| L2 | 去 whisper class；完整卡；meta 含分类；三档 quick action（brand link / habit 换一句 / generic 帮我写一句） |

**`#recordDetailsFold`**：L1 **默认整个 hidden**；仅「补充细节」link 可 `toggleRecordDetails(true)`。

**`#memberScenePackBlock`**：L1 禁止列表外露；统一走 Sheet（必做 5）。

---

## 必做 4 · 前 3 笔极简

`state.items.length < 3` 且无品牌 → 强制 L1。  
验收：清空 localStorage 连记 3 笔，输入页均为耳语态。

---

## 必做 5 · 场景包 Bottom Sheet

`index.html` 增 `#scenePackSheet`；L1/L2 点「帮我写一句」→ Sheet → `applyMemberScenePack` → 关 Sheet。  
非会员 → `openAccountOverlay()`。

---

## 必做 6 · demo 条仅 debug

`#prefillDemoBar` 默认 `hidden`；`?debug=1` 或 `DEBUG_UI_ENABLED` 时显示。

---

## 必做 7 · 样式 `styles.css`

`.life-entry-preview--whisper`：淡底、15–16px regular headline、无胶囊槽位。

---

## 可选 · L1 保存 toast

`已记下。首页「今天留下的痕迹」里会出现这一笔。`

---

## 禁止

- NativeDemoApp / backend / ai-proxy
- 耳语改回 3 条软腻旧版
- git commit（除非用户要求）

---

## 验收

- [ ] 清空数据 → `9.9`：耳语（15 池轮换）+ CTA；无胶囊、无分类海、无 demo 条
- [ ] 连续输入多笔：耳语句会随 seed 变化，不总是一句
- [ ] 备注「瑞幸」→ L2，无需 debug
- [ ] 前 3 笔强制 L1；第 4 笔起习惯够才 L2
- [ ] 帮我写一句 → Sheet
- [ ] OCR / 保存 / 首页不回归
- [ ] 耳语读起来 **笃定、生活化**，不软腻不奇怪

---

## @ 文件

```text
@AGENT_PROMPT_UI-P1.1_WEB_COLDSTART_MIN.md
@PRODUCT_VISION_EVAL_v0.1.md
@CATEGORY_SCENE_COPY_AUDIT_v0.1.md
@web-preview/app.js
@web-preview/index.html
@web-preview/styles.css
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task UI-P1.1-WEB — 冷启动极简预览**（仅 web-preview；**同一 PR**）。

## 战略
冷启动输入只露：金额 + 许可耳语 + 放进账本。叙事丰盈留在列表/回放，不在输入前堆满。
**无外部依赖**：不动 iOS/backend；Web 内 tier 判定 + 5 品牌 lite + 15 条耳语池。
耳语要笃定、生活化，不要软腻奇怪（禁止回到「悄悄并进今天」类旧句）。

## 执行顺序
1. 写入 coldStartWhispers（15 条，见下）+ pickColdStartWhisper(seed)
2. resolveRecordPreviewTier() + estimateHabitConfidence()
3. matchBrandInNote() + brandsLite（5 品牌）
4. 重写 updateLifeEntryPreview() — L1 whisper / L2 full
5. 前 3 笔强制 L1（品牌除外）；amountAssist L1 用固定句
6. recordDetailsFold L1 hidden；场景包 Sheet
7. prefillDemoBar 仅 debug；styles whisper 态

## 必须先 Read
@AGENT_PROMPT_UI-P1.1_WEB_COLDSTART_MIN.md
@PRODUCT_VISION_EVAL_v0.1.md
@CATEGORY_SCENE_COPY_AUDIT_v0.1.md
@web-preview/app.js
@web-preview/index.html
@web-preview/styles.css

---

## 预览分级

| tier | 条件 | UI |
| L0 | 无金额 | 仅金额舞台 |
| L1 | 有金额 + (items<3 或 习惯置信<0.55) 且无品牌 | 耳语一行，无胶囊，meta 仅今天·日期 |
| L2 | 品牌命中 / (items>=3 且 习惯>=0.55) / 编辑态 | 完整预览卡 |

---

## L1 耳语池（15 条 · 须全部写入 app.js）

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

stableIndex(`${amount}|${dateKey}|${hourBucket}`, length) 选句。

**amountAssist**（有金额+L1）：「数额够了，点下面放进账本。」

气质：笃定、生活化；禁止超支/浪费/克制/预算/剁手；不要软腻玄学句。

---

## L1 UI
- class life-entry-preview--whisper
- 隐藏 #lifeEntryEmotion
- meta：今天 · M/D（无分类名）
- quickActions：✨帮我写一句 + link补充细节
- #recordDetailsFold 整个 hidden（除非用户点补充细节）
- 无 #memberScenePackBlock 列表

## L2 UI
- 完整预览卡 + 胶囊 + 分类 meta
- brand → link「换一句说法」；habit →「✨换一句」；generic →「✨帮我写一句」

## brandsLite（5 个）
luckin / starbucks / mcd / meituan / didi（含 aliases + emotion + category）
备注命中 → 自动 L2

## 前 3 笔
items.length < 3 且无品牌 → 强制 L1

## Sheet
#scenePackSheet：帮我写一句 → 选包 → applyMemberScenePack → 关闭

## demo 条
#prefillDemoBar 默认 hidden；?debug=1 或 DEBUG_UI_ENABLED 才显示
删除 prefillDemoMode 用户主路径

---

## 禁止
NativeDemoApp、backend、耳语删成 3 条旧版、git commit（除非用户要求）

---

## 验收
- [ ] 9.9 冷启动：15 池耳语+CTA，无胶囊无分类海
- [ ] 多笔/改金额：耳语会轮换
- [ ] 备注瑞幸 → L2
- [ ] 前 3 笔 L1；第 4 笔起可 L2
- [ ] Sheet 选场景包
- [ ] 耳语不软腻不奇怪
- [ ] 保存/OCR/首页不回归

---

## 交付
1. 改动文件列表
2. tier 规则 + 耳语选取逻辑
3. 验收勾选
4. 未做：iOS UI-P1.1

最小 diff，仅 web-preview/。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版 |
| 2026-06-02 | 耳语池扩至 15 条；气质约束；复制发送块扩全 |
