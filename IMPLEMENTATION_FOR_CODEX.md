# 叙账 · Codex / Agent 实现任务单

> 更新时间：2026-06-02\
> 用途：把本文件 + 指定章节的产品文档交给 Codex、Cursor Agent 等，**按任务拆分实现**，避免一次「读完所有 md」导致漏项或乱改。\
> 产品真相：`PRODUCT_NORTH_STAR.md`、`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`；本文件只写 **工程范围、代码锚点、禁止项、验收**。

***

## 1. 使用方式

1.  **一次只开一个任务**（Task B1、B2…），复制 **§10 对应任务的完整对话**（一条消息发送）。
2.  让 Agent **先 Read 本任务列出的 Swift/JS 文件**，再读产品文档章节（不要整库盲改）。
3.  交付时要求：改动文件列表、§验收勾选、**明确未做项**。
4.  iOS 最低版本：**17.0**（`numericText`、`ContentTransition` 可用）。

**不要整包投喂**：`PROJECT_ANALYSIS.md`、`API_v0.1.md` 等同任务无关时可不传。

***

## 2. 文档与代码索引

### 2.1 产品文档（按任务引用）

| 文档                                                                           | 何时读                                         |
| ---------------------------------------------------------------------------- | ------------------------------------------- |
| [`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md)                             | 动线 §6、能力层级 §5.1、NSM §7                      |
| [`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md) | 切片 §5、次数 §5.6、感染力 §5.8、权益 §10、定价 §13、验收 §16 |
| [`PRD_v0.1.md`](PRD_v0.1.md)                                                 | 页面 §2、字段 §3                                 |
| [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md)                               | 仅上架/截图任务                                    |

### 2.2 代码锚点（实现前必读）

| 模块         | 路径                                                                                              | 说明                                                           |
| ---------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| 统计页        | `NativeDemoApp/ContentView.swift` → `StatsWebView`                                              | 当前默认 `selectedPeriod = .month`，**免费用户应改为 `.week`**（北极星 §6.3） |
| 今日回放       | `NativeDemoApp/Views/HomeView.swift` → `BillPlaybackSheet`                                      | 播放状态机：`activeIndex` + `Task.sleep`                           |
| 回放数据       | `NativeDemoApp/Services/PlaybackService.swift`                                                  | 扩展周/月聚合                                                      |
| 账单数据       | `NativeDemoApp/Models/HomeItem.swift`、`HomeViewModel.swift`                                     | `items` 数据源                                                  |
| 会员         | `NativeDemoApp/Views/MemberPricingView.swift`、`SettingsViewModel`                               | `memberTier`：`monthly`/`yearly`/`lifetime`                   |
| 场景包门槛      | `ContentView.swift` → `scenePacks`、`memberScenePackSection`                                     | 已有会员判断                                                       |
| Web 环图/周聚合 | `web-preview/app.js` → `buildWeeklyShareMeta`、`topCategoryStats`、`downloadWeeklyShareCardImage` | 生活配方与聚合参考                                                    |
| 周度分享卡 iOS  | `ContentView.swift` → `WeeklyShareCardView`                                                     | Phase D 分享复用，**Phase B 不做统计卡分享按钮**                           |
| 会员 Nudge   | `NativeDemoApp/Services/MemberFlowService.swift`                                                | 播完场景                                                         |

***

## 3. 任务清单（推荐顺序）

```text
B1 周/月聚合 + SummaryChapter 模型
B2 SummaryPlaybackSheet（周 5 幕 MVP）
B3 统计页生活切片卡片 + 默认本周
B4 免费/会员次数 enforce
A2 权益五条 UI 对齐（MemberPricingView 已改价，核对 enforce）
C1 动线引导（首记、角标、播完 CTA）
C2 OCR / 今日回放次数
D1 播完分享图（合并周卡）
```

***

## 4. 分任务说明

### Task B1 — 聚合与模型

**范围**

*   新建或扩展 `PlaybackService`（或 `SummaryPlaybackService`）：`buildWeekSummary`、`buildMonthSummary` from `[HomeItem]`。
*   模型：`SummaryChapter`（`id`, `title`, `metrics`, `narration.warm`/`plain`, `durationSec`）。
*   逻辑对齐专篇 §5.3、§5.4、§5.8.3（高光一笔选取、弱数据缩幕）。

**产品依据**：`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` §5.3～5.4、§5.8、§15 JSON。

**参考**：`web-preview/app.js` → `topCategoryStats`、`buildWeeklyShareMeta`。

**禁止**：调用 ai-proxy 生成旁白；v0.1 只用 §5.8.6 模板填充变量。

**验收**

*   [ ] 给定 fixture items，周摘要含 5 章（或 <3 笔时 3 章）
*   [ ] `busiestDay`、`topCategory`、`ratio`、`highlight` 字段非空（有数据时）

***

### Task B2 — SummaryPlaybackSheet

**范围**

*   新建 `SummaryPlaybackSheet.swift`（或放在 `Views/`，避免 `ContentView` 再膨胀）。
*   UI：§5.5.1 三层（渐变底 + 数据 + 播放控件）；`contentTransition(.numericText())`。
*   复用 `BillPlaybackSheet` 的 `activeIndex` / `isPlaying` / 播完逻辑。
*   播完 CTA：北极星 §6.4（主：会员/下周；次：小 AI 说，**AI 非主 CTA**）。

**产品依据**：§5.5、§5.5.1、§5.8、`PRODUCT_NORTH_STAR.md` §6.4。

**禁止**：逐笔列表滚动；播放中途弹会员墙。

**验收**

*   [ ] 周切片可播完 5 幕（或弱数据 3 幕）
*   [ ] 宠物关用 `plain`，开用 `warm`
*   [ ] 第 3 幕有占比（环图或大字 %）

***

### Task B3 — 统计页生活切片卡片

**范围**

*   在 `StatsWebView` 筛选栏 **下**、总览 **上** 插入生活切片卡片（§5.2）。
*   卡片随 `selectedPeriod`（week/month）切换文案与播放目标。
*   **免费用户默认 `selectedPeriod = .week`**（§6.3）。
*   本月：显示 `剩余 x/3` 或锁定态（§5.2 示例）。
*   主按钮仅 **「播放」**；**不要**在卡片上加「分享」。

**产品依据**：§5.2、§6.3。

**禁止**：重构整个 `ContentView`；Phase B 不做分享图。

**验收**

*   [ ] 本周有数据时卡片可点播放 → 打开 `SummaryPlaybackSheet`
*   [ ] 免费默认进页为「本周」
*   [ ] 本月用尽显示锁定 +「了解会员」

***

### Task B4 — 次数 enforce

**范围**

*   `UserDefaults`（或 `AppSettings`）：
    *   `playbackWeekKey` + 本周是否已用
    *   `lifetimeMonthChapterRemaining` 初值 **3**
*   播完 ≥80% 扣次；会员 `memberTier` 跳过。
*   话术：§11。

**产品依据**：§5.6、§10、§16。

**验收**：专篇 §16 前 3 条全部通过。

***

### Task A2 — 会员权益 UI 核对

**范围**

*   确认 `MemberPricingView` 价格 ¥9/88/168、权益五条与 §10.1.1 一致。
*   Web：`web-preview/index.html` 会员区已同步则仅核对。
*   **StoreKit / 验单** 仍 501 时：可用 Debug 切换 tier，文档注明。

**验收**：会员页文案与 §10.1.1 表格一致。

***

### Task C1 — 动线引导

**范围**

*   首记后引导今日回放（§6.2）。
*   本周 ≥3 笔且未播：看看花 Tab 角标或首页条。
*   播完周/月切片 CTA 符合 §6.4。
*   单会话引导优先级：首记 > 本周可播 > 记≥5 未播（北极星 §6，避免弹窗堆砌）。

**依赖**：B2、B3、B4。

***

### Task C2 — OCR / 今日回放次数

**范围**

*   OCR：§9，成功导入才扣次。
*   今日回放：§10 表 1 次/天（若产品确认与专篇一致）。

**依赖**：可与 B 并行，勿改 B 的播放核心。

***

### Task D1 — 播完分享图

**范围**

*   **仅**在 `SummaryPlaybackSheet` 播完页提供「保存故事图」。
*   复用 `WeeklyShareCardView` / `downloadWeeklyShareCardImage` 布局；与 AI Tab「周度分享卡」共用聚合。
*   统计卡片仍只有「播放」。

**产品依据**：Phase D、分享策略（统计卡不分享、播完再分享）。

***

## 5. 全局禁止项（每个任务都要遵守）

*   不要把叙账做成 **AI 记账** 主路径；切片旁白 **本地模板**。
*   不要 **阉割** 免费记账、列表、基础统计。
*   不要未实现功能写进 **商店截图**（见 `APP_STORE_LISTING.md`）。
*   不要 `git commit` 除非用户明确要求。
*   不要改 `backend` / `ai-proxy` 除非任务单写明。
*   禁止词：超支、浪费、克制、理性消费等（PRD §4、§5.8.2）。

***

## 6. 提示词骨架（可选）

各任务 **完整可复制对话** 见 **§10**。若自行拼装，替换 `[任务ID]` 与必读文件列表即可。

***

## 7. 建议首次投喂包（Phase B 合并，可选）

给 Codex **一条对话**只发：

1.  本文件 **§2.2 + Task B1 + B2 + B3 + B4 + §5 + §6 模板**（B1～B4 可合并为「Phase B 一次做完」若上下文够大）
2.  `PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`（全文或 §5～§16）
3.  `PRODUCT_NORTH_STAR.md` §5～§6

合并提示词见 **§10.0**；或分任务 **§10.1～10.4**。

***

## 8. 相关链接

| 文档                                                                                                   | 说明      |
| ---------------------------------------------------------------------------------------------------- | ------- |
| [`TODO.md`](TODO.md)                                                                                 | 上线与运维待办 |
| [`NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md`](NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md) | 真机联调    |
| [`PROJECT_SETUP.md`](PROJECT_SETUP.md)                                                               | 环境（若存在） |

1.  本文件 **§10.0（Phase B 合并）** 或 **§10.1～10.4 分任务**
2.  `PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`（全文或 §5～§16）
3.  `PRODUCT_NORTH_STAR.md` §5～§6

***

## 10. 各任务完整对话示例

> **用法（Cursor）**：新建 Agent 对话 → 用 `@` 引用各任务下列「@ 文件」→ 将「复制发送」整段作为 **一条用户消息** 发送。\
> **用法（Codex）**：在仓库根目录打开项目，粘贴「复制发送」段，并确保 Agent 能 Read 所列路径。\
> **顺序**：B1 → B2 → B3 → B4 → A2 → C1 → C2 → D1；每任务 **新对话**（或附上上一任务交付摘要）。

***

### 10.0 Phase B 合并（B1～B4 一次做完，上下文够大时用）

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@PRODUCT_NORTH_STAR.md
@NativeDemoApp/ContentView.swift
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/Services/PlaybackService.swift
@NativeDemoApp/Models/HomeItem.swift
@NativeDemoApp/Models/AppSettings.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
@web-preview/app.js
```

**复制发送**

```text
你在 xuzhangapp 仓库实现 iOS 17+ SwiftUI（叙账）。本对话完成 Phase B：**Task B1→B2→B3→B4**，按顺序实现，保证模拟器可跑通「看看花 → 播放周切片 → 次数扣减」。

## 范围
- B1：`SummaryChapter` + `buildWeekSummary` / `buildMonthSummary`（§5.3～5.4、§5.8、§15）
- B2：`SummaryPlaybackSheet`（§5.5、§5.5.1、§5.8.6 模板旁白）
- B3：`StatsWebView` 生活切片卡片；免费默认「本周」（§5.2、北极星 §6.3）
- B4：`playbackWeekKey` + `lifetimeMonthChapterRemaining=3`；播完≥80%扣次；会员跳过（§5.6、§11）

## 必须先 Read
IMPLEMENTATION_FOR_CODEX.md §4 B1～B4、§5
PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md §5～§11、§16
PRODUCT_NORTH_STAR.md §5.1、§6.3～§6.4
HomeView.swift（BillPlaybackSheet）、PlaybackService.swift、StatsWebView in ContentView.swift
web-preview/app.js（topCategoryStats、buildWeeklyShareMeta）

## 禁止
AI 生成旁白；统计卡分享按钮；播放中途会员墙；重构整个 ContentView；改 backend；未要求 commit

## 验收
专篇 §16 前 3 条 + §5.8.9 + Task B2 验收

## 交付
改动文件列表、§16 勾选、模拟器操作步骤、未做项（C1/D1 等）
请先 Read 再编码，完成后确认 Xcode 编译通过。
```

***

### 10.1 Task B1 — 聚合与模型

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@NativeDemoApp/Services/PlaybackService.swift
@NativeDemoApp/Models/HomeItem.swift
@web-preview/app.js
```

**复制发送**

```text
你在 xuzhangapp 实现 **Task B1 — 周/月聚合 + SummaryChapter 模型**（仅 B1，不做 UI Sheet、不改统计页）。

## 必做
1. 模型 `SummaryChapter`：id, title, metrics, narration.warm, narration.plain, durationSec
2. 服务 `buildWeekSummary([HomeItem])` → 5 章（记录<3 笔 → 3 章，§5.8.7）
3. 服务 `buildMonthSummary([HomeItem])` → 6 章骨架（§5.4，可先实现开篇+上中下旬+生活构成+结语）
4. 高光一笔：§5.8.3（优先有 note/title，否则最大额）
5. 旁白：§5.8.6 模板 + 变量替换（禁止调 ai-proxy）
6. 单元测试或 Preview 用 fixture 验证输出 JSON 结构接近专篇 §15

## 必须先 Read
PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md §5.3～5.4、§5.8、§15
web-preview/app.js → topCategoryStats、buildWeeklyShareMeta
PlaybackService.swift、HomeItem.swift

## 禁止
SummaryPlaybackSheet、StatsWebView 改动；AI 远程调用；commit 除非要求

## 验收
- [ ] 周：5 章或弱数据 3 章
- [ ] 有数据时 busiestDay、topCategory、ratio、highlight 有值
- [ ] warm/plain 两套 narration 同时生成

## 交付
新增/修改文件、fixture 示例输出、留给 B2 的接口说明
```

***

### 10.2 Task B2 — SummaryPlaybackSheet

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@PRODUCT_NORTH_STAR.md
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/Services/PlaybackService.swift
@NativeDemoApp/Models/HomeItem.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
@web-preview/app.js
```

**复制发送**

```text
你在 xuzhangapp 实现 **Task B2 — SummaryPlaybackSheet**（周切片播放；B1 若无则本任务内实现 B1 最小子集）。

## 必做
1. 新建 `NativeDemoApp/Views/SummaryPlaybackSheet.swift`
2. UI：§5.5.1 渐变底 + 数据层 + 播放控件；numericText 数字动画
3. 复用 BillPlaybackSheet 的 activeIndex / isPlaying / Task.sleep
4. 第 3 幕：生活配方环图或超大占比 %
5. warm/plain 随宠物开关（SettingsViewModel）
6. 播完 CTA：北极星 §6.4（主：关闭/会员/下周；次：多聊一句，AI 非主 CTA）
7. 预览：#Preview 或临时 Debug 按钮（最小改动 StatsWebView/HomeView）

## 必须先 Read
专篇 §5.5、§5.5.1、§5.8 全文
HomeView.swift BillPlaybackSheet
PlaybackService / B1 聚合

## 禁止
统计正式卡片（B3）；次数 enforce（B4）；分享按钮；播放中途付费墙；整文件重构 ContentView

## 验收
- [ ] 周切片播完 5 幕（或 3 幕弱数据）
- [ ] plain/warm + 冷/暖色底
- [ ] 第 3 幕有占比可视化

## 交付
文件列表、验收勾选、如何 Preview/模拟器触发、未做 B3/B4 说明
```

***

### 10.3 Task B3 — 统计页生活切片卡片

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@PRODUCT_NORTH_STAR.md
@NativeDemoApp/ContentView.swift
@NativeDemoApp/Views/SummaryPlaybackSheet.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
```

**前置**：B1、B2 已完成（或本仓库已有 `SummaryPlaybackSheet`）。

**复制发送**

```text
你在 xuzhangapp 实现 **Task B3 — 统计页生活切片卡片**（仅 B3；次数逻辑留给 B4，但可预留 hook）。

## 必做
1. `StatsWebView`：筛选栏 **下**、总览 **上** 插入生活切片卡片（§5.2 示例文案）
2. 卡片随 selectedPeriod（本周/本月）变化：标题、笔数、金额、按钮态
3. **免费用户默认 selectedPeriod = .week**（北极星 §6.3）；会员可保持上次或本周
4. 点击「播放」→ present `SummaryPlaybackSheet`（周或月 summary）
5. 本月：显示「剩余 x/3」或可播；用尽 → 🔒 +「了解会员」（§5.2）；B4 未做时 x 可硬编码 3 或读 UserDefaults 占位
6. 主按钮 **仅「播放」**，不要「分享」

## 必须先 Read
专篇 §5.2
ContentView.swift StatsWebView 段
SummaryPlaybackSheet.swift

## 禁止
B4 完整扣次（除非顺带做）；分享图；重构 ContentView 非 Stats 部分

## 验收
- [ ] 本周有数据可播放
- [ ] 免费进看看花默认「本周」
- [ ] 本月卡片态符合 §5.2（含锁定示例）

## 交付
文件列表、验收勾选、截图描述、B4 待接字段说明
```

***

### 10.4 Task B4 — 次数 enforce

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@NativeDemoApp/Views/SummaryPlaybackSheet.swift
@NativeDemoApp/ContentView.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
@NativeDemoApp/Models/AppSettings.swift
```

**前置**：B2、B3 已完成。

**复制发送**

```text
你在 xuzhangapp 实现 **Task B4 — 免费/会员次数 enforce**（仅 B4，不改聚合/Sheet UI 结构除非必要）。

## 必做
1. 存储：`playbackWeekKey`（自然周 ISO week，周一 0 点本地时区）+ 本周是否已用
2. 存储：`lifetimeMonthChapterRemaining` 初值 **3**，播完月章 -1，最小 0
3. 播放前校验：会员 tier ∈ monthly/yearly/lifetime → 跳过
4. 扣次时机：完整播完 ≥80% 或 playbackDone（§5.6）
5. 用尽话术：专篇 §11（Alert/Toast/卡片态）
6. 接入 B3 卡片 + SummaryPlaybackSheet 播完回调

## 必须先 Read
专篇 §5.6、§10、§11、§16 前 3 条
SettingsViewModel.memberTier

## 禁止
改 backend；伪造 StoreKit；commit 除非要求

## 验收（§16）
- [ ] 同自然周第 2 次周播提示用尽；新周恢复
- [ ] 本月第 4 次起锁定；前 3 次显示剩余
- [ ] 会员周/月均不限

## 交付
文件列表、UserDefaults/AppSettings 键名文档、手动测试步骤
```

***

### 10.5 Task A2 — 会员权益 UI 核对

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@NativeDemoApp/Views/MemberPricingView.swift
@web-preview/index.html
@web-preview/app.js
```

**复制发送**

```text
你在 xuzhangapp 做 **Task A2 — 会员页权益与定价 UI 核对**（以文档为准对齐，不做 StoreKit 真 IAP）。

## 必做
1. iOS `MemberPricingView`：价格 ¥9 / 年 ¥88 / 永久 ¥168；权益五条与 §10.1.1 完全一致
2. Web `index.html` 会员区价格 + 五条与 iOS 一致
3. Web `app.js` 若仍有旧 AI 五条文案 → 改为 §10.1.1
4. 脚注：免费额度 §10.1.2 一句（会员页底部 muted 小字即可）
5. 若 IAP 未接：Settings 保留 Debug tier 或文档注释，不假装已扣款

## 必须先 Read
专篇 §10.1、§13

## 禁止
改切片播放逻辑；改 backend 验单；commit 除非要求

## 验收
- [ ] iOS/Web 五条顺序与文案匹配 §10.1.1 表格
- [ ] 价格与 §13 一致

## 交付
diff 文件列表、前后不一致项清单
```

***

### 10.6 Task C1 — 动线引导

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_NORTH_STAR.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/ContentView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Services/MemberFlowService.swift
```

**前置**：B2、B3、B4 已完成。

**复制发送**

```text
你在 xuzhangapp 实现 **Task C1 — 动线引导**（仅引导 UI/状态，不重写切片核心）。

## 必做
1. **首记**：生涯第 1 笔保存后 → 轻 Sheet/Toast「用 10 秒叙一下今天」→ 今日回放（§6.2）
2. **本周可播**：本周≥3 笔且本周未播周切片 → 看看花 Tab badge 或首页条（§6.2）
3. **记≥5 未播**：累计≥5 笔且从未完整播周切片 → 看看花卡片/条文案（§6.2）
4. **播完 CTA** 核对 SummaryPlaybackSheet 符合 §6.4（若 B2 已做则补全/修正）
5. **引导优先级**：同会话最多 1 条主动引导 — 首记 > 本周可播 > 记≥5（§6 防吵）
6. 新用户 7 日内不主推 AI Tab（不新增 AI 首页弹窗）

## 必须先 Read
PRODUCT_NORTH_STAR.md §6 全文
HomeViewModel 记账保存点、MemberFlowService

## 禁止
多个 Alert 叠弹；播放中途会员墙；commit 除非要求

## 验收
- [ ] 首记后可触发今日回放引导
- [ ] 满足条件时出现「本周可播」提示且仅一条/会话
- [ ] 播完周/月主 CTA 非 AI

## 交付
文件列表、触发条件表、手动测试用例
```

***

### 10.7 Task C2 — OCR / 今日回放次数

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@NativeDemoApp/ContentView.swift
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
```

**复制发送**

```text
你在 xuzhangapp 实现 **Task C2 — OCR 与今日回放次数 enforce**（与 B 并行，勿改 SummaryPlayback 核心）。

## 必做
1. **OCR**：免费 3 次/自然日，仅成功导入（≥1 条）扣次；会员不限（§9）
2. **今日回放**：免费 1 次/自然日，会员不限（§10 总表）
3. 用尽话术 §11（OCR + 今日回放）
4. 存储键独立，不与 playbackWeekKey / lifetimeMonthChapter 混用
5. iOS 入口：记账 OCR 流程 + HomeView BillPlaybackSheet 播前校验

## 必须先 Read
专篇 §6（今日回放）、§9、§10、§11
OCR 相关 View in ContentView

## 禁止
改周/月切片次数（B4 已做则只读）；真实 OCR 识别引擎（仍占位可）；commit 除非要求

## 验收
- [ ] OCR 第 4 次当日提示用尽；失败不扣
- [ ] 今日回放第 2 次当日提示；会员跳过

## 交付
文件列表、键名、测试步骤
```

***

### 10.8 Task D1 — 播完分享图

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@NativeDemoApp/Views/SummaryPlaybackSheet.swift
@NativeDemoApp/ContentView.swift
@web-preview/app.js
@NativeDemoApp/ViewModels/HomeViewModel.swift
```

**前置**：B2 已完成。

**复制发送**

```text
你在 xuzhangapp 实现 **Task D1 — 播完分享图**（仅播完入口，统计卡片仍只有「播放」）。

## 必做
1. `SummaryPlaybackSheet` 播完页 **次 CTA**：「保存本周故事图」→ 导出 PNG → 系统分享/存相册
2. 视觉复用 `WeeklyShareCardView` 或 web `downloadWeeklyShareCardImage` 布局（趋势条+环图+文案）
3. 与 AI Tab「周度分享卡」共用聚合数据（buildWeekSummary / buildWeeklyShareMeta 同源）
4. **不要**在 StatsWebView 生活切片卡片上加分享按钮
5. 月章播完分享可 v0.1 仅做周，或简版月海报（注明未做项）

## 必须先 Read
ContentView WeeklyShareCardView
web-preview/app.js downloadWeeklyShareCardImage
专篇 Phase D、分享策略（统计卡不分享）

## 禁止
统计卡分享；假社交功能；commit 除非要求

## 验收
- [ ] 仅播完页可导出分享图
- [ ] 统计卡仍仅「播放」
- [ ] 图含叙账标识、与当前周数据一致

## 交付
文件列表、导出步骤、与旧「周度分享卡」关系说明
```

***

## 11. 修订记录

| 日期         | 说明                                                   |
| ---------- | ---------------------------------------------------- |
| 2026-06-02 | 首版：任务 B1～D1、代码锚点、禁止项、Codex 提示词模板                     |
| 2026-06-02 | 新增 **§10 各任务完整对话示例**（B1～B4、A2、C1、C2、D1 + Phase B 合并） |

