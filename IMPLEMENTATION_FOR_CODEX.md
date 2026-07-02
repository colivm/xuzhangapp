# 叙账 · Codex / Agent 实现任务单

> 更新时间：2026-06-06  
> 用途：把本文件 + 指定章节的产品文档交给 Codex、Cursor Agent 等，**按任务拆分实现**，避免一次「读完所有 md」导致漏项或乱改。  
> **当前优先**：见 [`TODO.md`](TODO.md) §下一步最先做什么 — **TestFlight 回归 → B2.8 → C1**。

---

## 1. 使用方式

1. **一次只开一个任务**（Task B1、B2…），复制 **§10 对应任务的完整对话**（一条消息发送）。  
2. 让 Agent **先 Read 本任务列出的 Swift/JS 文件**，再读产品文档章节（不要整库盲改）。  
3. 交付时要求：改动文件列表、§验收勾选、**明确未做项**。  
4. iOS 最低版本：**17.0**（`numericText`、`ContentTransition` 可用）。

**不要整包投喂**：`PROJECT_ANALYSIS.md`、`API_v0.1.md` 等同任务无关时可不传。

---

## 2. 文档与代码索引

### 2.1 产品文档（按任务引用）

| 文档 | 何时读 |
|------|--------|
| [`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) | 动线 §6、能力层级 §5.1、NSM §7 |
| [`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md) | 切片 §5、次数 §5.6、感染力 §5.8、权益 §10、定价 §13、验收 §16 |
| [`PRD_v0.1.md`](PRD_v0.1.md) | 页面 §2、字段 §3 |
| [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) | 仅上架/截图任务 |

### 2.2 代码锚点（实现前必读）

| 模块 | 路径 | 说明 |
|------|------|------|
| 统计页 · 生活切片 | `NativeDemoApp/Views/StatsWebView.swift` | 默认 `selectedPeriod = .week` ✅ |
| 记账 · 场景包 | `NativeDemoApp/Views/RecordView.swift` + `ScenePackSectionView.swift` | 场景包、`OCRConfirmSheet` |
| 场景包数据 | `NativeDemoApp/Services/ScenePackCopyPool.swift` | A4 哲学对齐 ✅ |
| 切片旁白池 | `NativeDemoApp/Services/PlaybackCopyPool.swift` | B2.6 接入 ✅ |
| 今日回放 | `NativeDemoApp/Views/HomeView.swift` → `BillPlaybackSheet` | 播放状态机 |
| 切片播放 | `NativeDemoApp/Views/SummaryPlaybackSheet.swift` | 播完 CTA + **D1「保存本周故事图」** ✅ |
| 回放聚合 | `NativeDemoApp/Services/PlaybackService.swift` | 周/月 summary + `buildWeeklyShareCardPayload` ✅ |
| 账单 / 分类 | `CategoryRecommendService.swift` + `HomeViewModel` | B2.8 ✅ 历史+时段+金额+备注 |
| 天气宠物 | `WeatherCompanionService` / `PetCompanionService` / `PetCompanionCopy` | B2.9 ✅ |
| 小 AI 说 | `NativeDemoApp/Views/InsightWebView.swift` | A3 ✅；含 `WeeklyShareCardView` + AI Tab 分享入口 |
| 会员 / IAP | `MemberPricingView.swift`、`SettingsViewModel.verifyIAPPurchase` | StoreKit + verify ✅ |
| 壳与 Tab | `NativeDemoApp/ContentView.swift` | **~702 行** Tab 壳 + `AppColors` / `RecordEditSheet` |
| 周度分享卡 UI | `InsightWebView.swift` → `WeeklyShareCardView` | D1 ✅；可选迁 `Views/Components/` |
| ViewModel | `HomeViewModel.swift` | B2.8 已抽 `CategoryRecommendService`；仍偏胖 🟡 |
| Web 参考（iOS 优先，Web 滞后） | `web-preview/app.js` | 勿默认与 iOS 同步改 |
| 会员 Nudge | `NativeDemoApp/Services/MemberFlowService.swift` | 播完场景 |

---

## 3. 任务清单（推荐顺序）

```text
B1 周/月聚合 + SummaryChapter 模型                    ✅
B2 SummaryPlaybackSheet（周 5 幕 MVP）               ✅
B3 统计页生活切片卡片 + 默认本周                      ✅
B4 免费/会员次数 enforce                             ✅
A2 权益五条 UI 对齐                                  ✅
A3 AI「议」边界 · 去预算化（iOS）                    ✅
A4 场景包哲学对齐（iOS）                             ✅
B2.6 PlaybackCopyPool 接入（iOS MVP）                ✅
B2.7 分类锁定                                       ✅ 骨架
InsightWebView 从 ContentView 拆分                  ✅
C1 动线引导（首记、角标、播完 CTA）                   ✅
B2.8 智能分类推荐                                     ✅
B2.5 生活切片叙事/UI polish                           ⏳
B2.9 天气宠物                                         ✅
B2.10 场景包文案池（iOS MVP）                          ✅
C2 OCR / 今日回放次数                                ✅ 主链路
D1 播完分享图（周章）                                  ✅
F1 OCR 详情页 + 去演示按钮                           ✅ 主链路（Debug 演示按钮可选删）
E1 StoreKit + Release 门禁（iOS + backend dev 路由）   ✅
```

---

## 4. 分任务说明

### Task B1 — 聚合与模型

**范围**

- 新建或扩展 `PlaybackService`（或 `SummaryPlaybackService`）：`buildWeekSummary`、`buildMonthSummary` from `[HomeItem]`。  
- 模型：`SummaryChapter`（`id`, `title`, `metrics`, `narration.warm`/`plain`, `durationSec`）。  
- 逻辑对齐专篇 §5.3、§5.4、§5.8.3（高光一笔选取、弱数据缩幕）。

**产品依据**：`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` §5.3～5.4、§5.8、§15 JSON。

**参考**：`web-preview/app.js` → `topCategoryStats`、`buildWeeklyShareMeta`。

**禁止**：调用 ai-proxy 生成旁白；v0.1 只用 §5.8.6 模板填充变量。

**验收**

- [ ] 给定 fixture items，周摘要含 5 章（或 &lt;3 笔时 3 章）  
- [ ] `busiestDay`、`topCategory`、`ratio`、`highlight` 字段非空（有数据时）

---

### Task B2 — SummaryPlaybackSheet

**范围**

- 新建 `SummaryPlaybackSheet.swift`（或放在 `Views/`，避免 `ContentView` 再膨胀）。  
- UI：§5.5.1 三层（渐变底 + 数据 + 播放控件）；`contentTransition(.numericText())`。  
- 复用 `BillPlaybackSheet` 的 `activeIndex` / `isPlaying` / 播完逻辑。  
- 播完 CTA：北极星 §6.4（主：会员/下周；次：小 AI 说，**AI 非主 CTA**）。

**产品依据**：§5.5、§5.5.1、§5.8、`PRODUCT_NORTH_STAR.md` §6.4。

**禁止**：逐笔列表滚动；播放中途弹会员墙。

**验收**

- [ ] 周切片可播完 5 幕（或弱数据 3 幕）  
- [ ] 宠物关用 `plain`，开用 `warm`  
- [ ] 第 3 幕有占比（环图或大字 %）

---

### Task B3 — 统计页生活切片卡片

**范围**

- 在 `StatsWebView` 筛选栏 **下**、总览 **上** 插入生活切片卡片（§5.2）。  
- 卡片随 `selectedPeriod`（week/month）切换文案与播放目标。  
- **免费用户默认 `selectedPeriod = .week`**（§6.3）。  
- 本月：显示 `剩余 x/3` 或锁定态（§5.2 示例）。  
- 主按钮仅 **「播放」**；**不要**在卡片上加「分享」。

**产品依据**：§5.2、§6.3。

**禁止**：重构整个 `ContentView`；Phase B 不做分享图。

**验收**

- [ ] 本周有数据时卡片可点播放 → 打开 `SummaryPlaybackSheet`  
- [ ] 免费默认进页为「本周」  
- [ ] 本月用尽显示锁定 +「了解会员」

---

### Task B4 — 次数 enforce

**范围**

- `UserDefaults`（或 `AppSettings`）：  
  - `playbackWeekKey` + 本周是否已用  
  - `lifetimeMonthChapterRemaining` 初值 **3**  
- 播完 ≥80% 扣次；会员 `memberTier` 跳过。  
- 话术：§11。

**产品依据**：§5.6、§10、§16。

**验收**：专篇 §16 前 3 条全部通过。

---

### Task A2 — 会员权益 UI 核对

**范围**

- 确认 `MemberPricingView` 价格 ¥9/88/168、权益五条与 §10.1.1 一致。  
- Web：`web-preview/index.html` 会员区已同步则仅核对。  
- **StoreKit / 验单** 仍 501 时：可用 Debug 切换 tier，文档注明。

**验收**：会员页文案与 §10.1.1 表格一致。

---

### Task C1 — 动线引导

> **状态：iOS 已完成**（`3bb63e9` 及后续；`PlaybackRouteGuidance` + Tab 角标 + 首记 Toast）。

**范围**

- 首记后引导今日回放（§6.2）。  
- 本周 ≥3 笔且未播：看看花 Tab 角标或首页条。  
- 播完周/月切片 CTA 符合 §6.4。  
- 单会话引导优先级：首记 &gt; 本周可播 &gt; 记≥5 未播（北极星 §6，避免弹窗堆砌）。

**依赖**：B2、B3、B4。

---

### Task C2 — OCR / 今日回放次数

**范围**

- OCR：§9，成功导入才扣次。  
- 今日回放：§10 表 1 次/天（若产品确认与专篇一致）。

**依赖**：可与 B 并行，勿改 B 的播放核心。

---

### Task B2.5 — 生活切片叙事/UI 感染力 polish

**范围**

- **仅改呈现与文案 hook**，不重写 B1 聚合骨架、B4 次数、C1/C2 动线与配额。  
- `SummaryPlaybackSheet`：**旁白为主、数字为辅**；按幕类型决定大字 metric；Header 去重复 KPI；收尾幕无总额。  
- `PlaybackService`：`teaserLine`（统计卡片副标题）；月章 `momPercent`（有上月数据时）；强化「变化点」一句 memory point。  
- 可选 P2：节奏幕 7 日小柱条、按章类型底渐变色相、高光幕引号样式、`emotionTag`。

**产品依据**：`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` §5.5.1、§5.8（尤其 §5.8.2 禁止项、§5.8.3 第 2/4 幕、§5.8.8 验收）。

**禁止**：调用 ai-proxy；统计卡加分享；播放中途会员墙；D1 分享图（本任务不做）。

**依赖**：B1～B4、C1/C2 已完成（当前仓库已有 `SummaryPlaybackSheet`）。

**验收**

- [ ] 每幕 **旁白在 metric 之上或为主视觉**，非 48pt 金额压过旁白  
- [ ] 仅「生活主料」幕保留环图/大占比；收尾幕无 count/total 大字  
- [ ] Header 播放中不常驻「N 笔 · ¥总额」（或仅第 1 幕显示日期）  
- [ ] 统计卡片有数据时副标题为 **叙事 hook**（`teaserLine`），非默认 `N笔·¥·分类`  
- [ ] 定性：播完像「我的这周」而非「又念报表」

---

### Task D1 — 播完分享图

> **状态：iOS 已完成（2026-06-06）** — 周章播完「保存本周故事图」；月章海报 v0.2。

**范围**  
- 数据与 **B2.5 后的** `buildWeekSummary` / `teaserLine` 同源；与 AI Tab「周度分享卡」共用聚合。  
- **分享图 = 一屏海报摘要**（叙事标题 + 适度图表），**不是**把 Sheet 五幕拼成一张报表。  
- 视觉：复用 `WeeklyShareCardView` 的 **主题色/渐变/品牌**，主标题优先 `teaserLine` 或播完收束句。  
- 统计卡片仍只有「播放」。  

**产品依据**：Phase D、分享策略（统计卡不分享、播完再分享）；§5.4.1 生活配方（环图可保留）。

**依赖**：**B2.5 必须先完成**。

---

### Task F1 — 支付宝/微信 OCR + 确认导入（对齐 Web）

**范围**

- **UX 以 Web 为准**（`web-preview/index.html` `ocrForm` + `ocrConfirmOverlay` + `ocr-draft-panel`；逻辑见 `app.js` `runMockOCR` → `openOCRConfirm` → `importOCRRecords` → `renderOCRDraftArea`）。  
- **四步流程**：① 选图 ② 识别进度 ③ **确认导入弹层**（勾选/改分类/批量/取消/确认）④ **草稿区待整理**（可选勾选已整理、「完成整理」）。  
- **识别**：本机 Apple Vision + 支付宝/微信 **账单详情页** parser（不上传图片）。  
- v0.1 详情页通常 **1 条**；确认弹层 UI 仍支持多行（与 Web mock 2 条一致），列表长截图 v0.2。  
- 次数：§9（C2 未做则一并实现）；**仅确认导入成功**扣次。

**产品依据**：`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` §9、§11。

**依赖**：可与 B2.5/D1 并行；C2 次数可合并进本任务。

**验收**

- [ ] 流程与 Web 截图一致：进度条 → 确认导入 → 草稿区出现待整理  
- [ ] 确认弹层含「所有识别均在本地完成，数据不上传」  
- [ ] 支付宝/微信详情 fixture 能解析 amount + title + date  
- [ ] `HomeItem.source = .ocr`；失败/取消不扣次

---

### Task E1 — StoreKit 2 + 后端验单

**范围**

- **iOS**：StoreKit 2 购买月/年/永久；恢复购买；替换 `MemberPricingView.handlePurchase` 的 Demo 写 tier。  
- **Backend**：实现 `POST /v1/iap/verify`（替换 501），校验 App Store 交易并 `setSessionByUserId` 更新 `memberTier` / `memberExpiresAt`。  
- **配置**：App Store Connect Product ID、沙盒账号；首月 ¥6 用 **Introductory Offer**（ASC 配置，非客户端私改价）。  
- **登录**：验单需 `requireAuth`（`Authorization: Bearer`）；购买成功后同步 `GET /v1/member/me` → 本地 `AppSettings.memberTier`。

**产品依据**：`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` §13；`API_v0.1.md` §8（需扩展请求/响应体）；`IOS_REAL_INTEGRATION_CHECKLIST.md` §1 会员与支付。

**定价与 tier 映射**

| tier | 价格 | ASC 类型 |
|------|------|----------|
| `monthly` | ¥9（首月推介 ¥6） | Auto-Renewable Subscription |
| `yearly` | ¥88 | Auto-Renewable Subscription |
| `lifetime` | ¥168（首发可 ¥148 promotional） | Non-Consumable 或订阅组外一次性（产品策略自定，文档写清） |

**禁止**

- 客户端仅改 `memberTier` 不验单即视为已付费（保留 **Debug** 开关仅 `#if DEBUG` 或 Staging）。  
- Phase B 切片逻辑与本任务混在同一对话（E1 独立）。

**依赖**：用户已能登录（`/v1/auth/sms/verify`）；**建议在 Phase B 完成后**、TestFlight 收费前做。

**验收**

- [ ] 沙盒：购买年付 → 验单 200 → `member/me` 为 `yearly` → App 内切片次数不受限  
- [ ] 恢复购买可用  
- [ ] 未登录购买流程提示先登录（或购买后引导登录再验单）  
- [ ] 生产：`/v1/iap/verify` 不再返回 501  

---

## 5. 全局禁止项（每个任务都要遵守）

- 不要把叙账做成 **AI 记账** 主路径；切片旁白 **本地模板**。  
- 不要 **阉割** 免费记账、列表、基础统计。  
- 不要未实现功能写进 **商店截图**（见 `APP_STORE_LISTING.md`）。  
- 不要 `git commit` 除非用户明确要求。  
- 不要改 `backend` / `ai-proxy` 除非任务单写明。  
- 禁止词：超支、浪费、克制、理性消费等（PRD §4、§5.8.2）。

---

## 6. 提示词骨架（可选）

各任务 **完整可复制对话** 见 **§10**。若自行拼装，替换 `[任务ID]` 与必读文件列表即可。

---

## 7. 建议首次投喂包（Phase B 合并，可选）

给 Codex **一条对话**只发：

1. 本文件 **§2.2 + Task B1 + B2 + B3 + B4 + §5 + §6 模板**（B1～B4 可合并为「Phase B 一次做完」若上下文够大）  
2. `PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`（全文或 §5～§16）  
3. `PRODUCT_NORTH_STAR.md` §5～§6  

合并提示词见 **§10.0**；或分任务 **§10.1～10.4**。

---

## 8. 相关链接

| 文档 | 说明 |
|------|------|
| [`TODO.md`](TODO.md) | 上线与运维待办 |
| [`NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md`](NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md) | 真机联调 |
| [`PROJECT_SETUP.md`](PROJECT_SETUP.md) | 环境（若存在） |

1. 本文件 **§10.0（Phase B 合并）** 或 **§10.1～10.4 分任务**  
2. `PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`（全文或 §5～§16）  
3. `PRODUCT_NORTH_STAR.md` §5～§6  

---

## 10. 各任务完整对话示例

> **用法（Cursor）**：新建 Agent 对话 → 用 `@` 引用各任务下列「@ 文件」→ 将「复制发送」整段作为 **一条用户消息** 发送。  
> **用法（Codex）**：在仓库根目录打开项目，粘贴「复制发送」段，并确保 Agent 能 Read 所列路径。  
> **顺序**：B1 → B2 → B3 → B4 → A2 → C1 → C2 → D1；每任务 **新对话**（或附上上一任务交付摘要）。

---

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

---

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

---

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

---

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

---

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

---

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

---

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

---

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

---

### 10.8 Task B2.5 — 生活切片叙事/UI 感染力 polish

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@PRODUCT_NORTH_STAR.md
@NativeDemoApp/Views/SummaryPlaybackSheet.swift
@NativeDemoApp/Services/PlaybackService.swift
@NativeDemoApp/ContentView.swift
@NativeDemoApp/Views/HomeView.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
@web-preview/app.js
```

**前置**：B1～B4、C1/C2 已完成。**必须在 D1 之前做。**

**复制发送**

```text
你在 xuzhangapp 实现 **Task B2.5 — 生活切片叙事/UI 感染力 polish**（只 polish 呈现与 hook 文案；不改次数 enforce、不加分享、不重构 ContentView 非相关部分）。

## 背景
Phase B MVP 已能播 5/6 幕，但 Sheet 层级「大字 metric 在上、旁白在下」+ Header/收尾重复 KPI，体感偏报表。专篇 §5.8：感染力 = 事实密度 + 叙事顺序，非堆数字。

## 必做 — SummaryPlaybackSheet（P0）
1. **信息层级**：每幕布局改为「幕标题（叙事向）→ 旁白 20–24pt 主视觉 → 辅助数字 1 个且小字号」；旁白在 metric **之上**
2. **按幕隐藏/弱化大字 metric**（§5.8.2、§5.8.3）：
   - 开场：不要 48pt 总额；旁白 + 小字 `N笔 · ¥总额` 即可
   - 节奏：不要最忙日 **金额** 大字；主信息 weekday（可保留 7 日 mini 柱条，参考 WeeklyShareCardView trend）
   - 主料：保留环图 + %（唯一图表幕）
   - 高光：引号/卡片样式展示 `highlight.title`；金额降为脚注，勿 48pt
   - 收尾：**无任何** count/total 大字 KPI
3. **Header 瘦身**：播放中去掉常驻 `rangeLabel · N笔 · ¥总额`；可仅第 1 幕显示日期范围
4. **按章类型底渐变**（§5.5.1）：intro / rhythm / category / highlight / outro 色相略区分 + 切幕 crossfade（可选低对比 SF Symbol，非全屏图）
5. warm/plain 仍随 `petCompanionEnabled`；播完 CTA 不动（§6.4）

## 必做 — PlaybackService + 统计卡片（P1）
1. `SummaryPlayback` 增加 `teaserLine: String`（或等价），由周/月聚合生成 **一句 narrative hook**（如「周三最忙，餐饮大约占四成」）
2. `StatsWebView.summaryCardSubtitle`：有数据时优先 `teaserLine`，勿默认 `N笔 · ¥ · 分类为主`
3. 月章开篇：有上月数据时填充 `momPercent` 进旁白（§5.8.6 模板）
4. 月章「变化点」：一句具体 memory point（新分类 / 连续记账日 / 某旬偏高），避免只列分类名

## 可选 — P2（时间够再做，写在交付未做项）
- 节奏幕 7 日柱条对齐 web trend
- 高光幕带 `emotionTag`
- 宠物名 `{petName}` 接设置（现硬编码「小窝」可改可配置名）

## 必须先 Read
专篇 §5.5.1、§5.8 全文（尤其 §5.8.2 禁止、§5.8.3 第 2/4 幕）
SummaryPlaybackSheet.swift、PlaybackService.buildWeekSummary/buildMonthSummary
BillPlaybackSheet（对比「故事线」气质）
ContentView StatsWebView summarySliceCard 段

## 禁止
D1 分享按钮/导出 PNG；改 B4 扣次逻辑；调用 ai-proxy；统计卡加「分享」；播放中途会员墙；整文件重构 ContentView

## 验收
- [ ] 旁白为主、数字为辅；仅主料幕有大占比/环图
- [ ] 收尾无重复总额；Header 不三重重复 KPI
- [ ] 统计卡片副标题为 teaser 叙事句（有数据时）
- [ ] 月章有上月数据时出现较上月 ±%
- [ ] 手动：播完问「像不像我的这周」而非只对数字

## 交付
改动文件列表、验收勾选、P2 未做项、**说明 D1 可在此之后接播完分享**
```

---

### 10.9 Task D1 — 播完分享图

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@NativeDemoApp/Views/SummaryPlaybackSheet.swift
@NativeDemoApp/ContentView.swift
@web-preview/app.js
@NativeDemoApp/ViewModels/HomeViewModel.swift
```

**前置**：**B2.5 已完成**（Sheet 叙事层级、`teaserLine`、播完 CTA 定稿后再做分享图）。

**复制发送**

```text
你在 xuzhangapp 实现 **Task D1 — 播完分享图**（仅播完入口，统计卡片仍只有「播放」）。

## 背景
B2.5 已把生活切片 Sheet 定为「旁白为主、数字为辅」。分享图是 **一屏可发朋友圈的海报**，可以比 Sheet 略多数据（趋势条+环图），但 **不要**回到纯 KPI 报表；主标题用 narrative hook，不是「N笔 · ¥总额」大字堆叠。

## 必做
1. `SummaryPlaybackSheet` 播完页 **次 CTA**（周切片）：「保存本周故事图」→ 导出 PNG → `UIActivityViewController` 分享/存相册
2. **数据同源**：`PlaybackService.buildWeekSummary` + B2.5 的 `teaserLine`（或最后一幕 plain/warm 收束句作副标题）；与 AI Tab「周度分享卡」共用周聚合，勿另写一套统计
3. **视觉**：
   - 复用 `WeeklyShareCardView` 的 `ShareCardTheme`（宠物/简洁两套渐变）
   - **主文案**：`teaserLine` 或「你好，{nickname}」+ 一句收束（参考 Web 分享卡语气，见 web `downloadWeeklyShareCardImage`）
   - **图表**：保留 TOP1 环图；7 日小趋势可选；金额/笔数降为次级字号，勿盖过标题句
   - 页脚：叙账标识 + 「温柔回看…」类 footer（与现有 WeeklyShareCardView 一致）
4. 若 `WeeklyShareCardView` 与上述冲突：抽 **共用 `WeeklyShareCardRenderer`** 或给 View 增加 `headline:` 参数，避免 AI Tab 与播完导出两套图
5. **不要**在 StatsWebView 生活切片卡片上加分享按钮
6. 月章播完分享：v0.1 可只做周；月简版海报注明未做项

## 必须先 Read
B2.5 改动后的 SummaryPlaybackSheet（播完 CTA 区）
PlaybackService（teaserLine、buildWeekSummary）
ContentView WeeklyShareCardView
web-preview/app.js downloadWeeklyShareCardImage
专篇 §5.4.1、分享策略（统计卡不分享）

## 禁止
把 Sheet 五幕 metric 原样拼成一张图；统计卡分享；Sheet 每幕加分享；假社交功能；commit 除非要求

## 验收
- [ ] 仅播完页可导出；统计卡仍仅「播放」
- [ ] 图主标题为 narrative（teaserLine/收束句），非 22pt 三行 KPI 霸屏
- [ ] 主题色与 B2.5 / WeeklyShareCardView 一致；数据与当周账单一致
- [ ] AI Tab「周度分享卡」与播完导出 **同源渲染或同源数据**（说明差异若保留两处入口）

## 交付
文件列表、导出步骤、与 AI Tab 周卡的关系、月章未做项
```

---

### 10.10 Task E1 — StoreKit 2 + 后端验单

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@API_v0.1.md
@NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md
@NativeDemoApp/Views/MemberPricingView.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
@NativeDemoApp/Services/AuthService.swift
@backend/src/server.js
@backend/src/store.js
```

**前置**：Phase B 完成（切片 + 次数 enforce）；用户可短信登录。

**复制发送**

```text
你在 xuzhangapp 实现 **Task E1 — StoreKit 2 内购 + 后端验单**（iOS + backend；不改生活切片播放核心）。

## 必做 — iOS
1. 新建 `IAPService`（或等价）：StoreKit 2 `Product.products(for:)`、purchase、Transaction.updates、restore
2. Product ID 从 `Info.plist` / `AppSecrets.plist` / 常量读取（占位符见 IOS_REAL_INTEGRATION_CHECKLIST §2）：
   - monthly → tier `monthly`
   - yearly → tier `yearly`
   - lifetime → tier `lifetime`
3. 替换 `MemberPricingView.handlePurchase`：真实购买 → 拿 signed transaction / transactionId → POST 验单
4. 验单成功后：`AuthService` 调 `GET /v1/member/me` 刷新 tier → `SettingsViewModel.memberTier`
5. 提供「恢复购买」入口（会员页底部）
6. **Release 不得**存在本地写 tier 的 UI；Debug 模拟开通入口已删除（2026-06-06）；会员变更仅 StoreKit → verify → `member/me`
7. 首月 ¥6：依赖 ASC Introductory Offer，客户端只加载对应 subscription product

## 必做 — Backend
1. 实现 `POST /v1/iap/verify`（替换 server.js 501 stub）
2. 请求体建议（可扩展 API_v0.1 §8）：`{ "productId", "transactionId", "signedTransactionInfo" }` 或 JWS 字段
3. 使用 App Store Server API（或 Apple 官方验签库）校验交易
4. 校验通过 → `setSessionByUserId(userId, { memberTier, memberExpiresAt })`
5. tier 映射与 PRODUCT §13 一致；永久 `lifetime` 的 expiresAt 为 null
6. 幂等：同一 originalTransactionId 重复验单不重复降级
7. 环境变量：`APPLE_ISSUER_ID`、`APPLE_KEY_ID`、私钥路径等（写入 backend/.env.example，勿提交密钥）

## 必须先 Read
API_v0.1.md §8、§9
PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md §13
MemberPricingView.handlePurchase（当前 Demo）
AuthService /v1/member/me
server.js /v1/iap/verify、/v1/member/dev/set-tier（仅开发参考）

## 禁止
未验单直接 settingsViewModel.memberTier = plan.id（任何构建配置）
在本任务重构 SummaryPlaybackSheet / 切片次数逻辑
提交 .p8 私钥或真实 .env 到 git
未要求 commit

## 验收
- [ ] 沙盒年付购买 → verify 200 → member/me yearly → 切片无次数限制
- [ ] 恢复购买
- [ ] 501 已消除（Staging/生产配置密钥后）
- [ ] API_v0.1.md §8 补充请求/响应示例

## 交付
改动文件列表、ASC 需人工配置清单（Product ID、推介促销）、沙盒测试步骤、.env.example 新增项
请先 Read 再实现；iOS 与 backend 分开说明如何联调。
```

---

### 10.11 Task F1 — 支付宝/微信 OCR + 确认导入

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@web-preview/index.html
@web-preview/app.js
@web-preview/styles.css
@NativeDemoApp/Services/OCRService.swift
@NativeDemoApp/ContentView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Models/HomeItem.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
```

**前置**：Web 预览 OCR 四步流程已存在；iOS 当前仅 `prefillFromOCR` 无确认弹层。

**复制发送**

```text
你在 xuzhangapp 实现 **Task F1 — 支付宝/微信 OCR + 确认导入**，iOS UX **对齐 Web 四步流程**（见用户截图与 web-preview）。

## Web 四步（必须 Read app.js 对照实现，不要凭印象）
1. **选图**：智能导入 tab →「导入账单 / 识别票据」→ PhotosPicker
2. **识别中**：`ocrLoadingBox` 进度条 +「正在识别账单，请稍候…」；按钮 disabled
3. **确认导入弹层**（`ocrConfirmOverlay`）：
   - 标题「确认导入账单」+ tip「所有识别均在本地完成，数据不上传」
   - 统计：识别条数、总金额
   - 工具栏：全选/反选、批量修改分类
   - 列表：每条 checkbox「导入此条」、金额、时间·标题、分类 picker
   - 底栏：取消 | 确认导入（显示已选 N 条）
   - **只有点「确认导入」才写入账单**
4. **草稿区**（`ocr-draft-panel`，确认写入后出现）：
   - 摘要「共 N 笔待整理 · 合计 ¥X」
   - 按导入日期分组；每行：checkbox、时间、分类（可改）、金额（可点改）、左滑删除
   - 「待整理 ↓」态 → 勾选后变已整理；右上角「完成整理」清除已整理标记
   - 空态文案与 Web 一致

Web 代码锚点：`runMockOCR` → `openOCRConfirm` → `ocrConfirmBtn` → `importOCRRecords`（带 draftMeta）→ `renderOCRDraftArea`

## 必做 — 识别引擎（OCRService，本机 Vision，不上传）
1. 保留/增强 `VNRecognizeTextRequest`（zh-Hans）
2. `detectProvider`：支付宝 | 微信 | generic
3. **v0.1 目标截图**：支付宝/微信 **单笔账单详情页**（非账单列表长图）
4. 支付宝：金额（「金额」行旁 ¥）、商品说明/商家名称、创建/付款时间
5. 微信：金额（支持 -¥，支出取 abs）、商户全称/商品、支付时间
6. 列表长图 / 无法解析 → 错误提示「请打开单笔账单详情页再截图」，**不扣次、不进确认弹层**
7. 返回 `[OCRReceiptDraft]`（数组，详情页通常 1 条；结构支持多条以便 UI 复用 Web）

## 必做 — iOS 视图（建议新建，避免 ContentView 再膨胀）
- `OCRConfirmSheet.swift` — 对齐 Web 确认弹层
- `OCRDraftPanel` 或嵌入记账页 ocrForm — 对齐 Web 草稿区
- 识别进度：ocrForm 内 ProgressView，与 Web 一致
- 删除 iOS 上无对应的「使用演示 OCR 记录」或仅 `#if DEBUG`

## 必做 — 数据与次数
1. 确认导入 → `HomeItem(source: .ocr)`；可选 `draftMeta`（batchId、importedAt、status pending/resolved）与 Web 同语义
2. C2 若未做：免费 3 次/自然日，**仅确认导入 ≥1 条成功**扣次；会员不限；§11 用尽话术
3. 识别失败、用户取消确认：**不扣次**

## v0.1 范围边界（写在交付未做项）
- ✅ 详情页单笔（确认弹层 1 行）
- ⏳ 列表长图一次多条（v0.2）
- ⏳ 相机拍照（可先 PhotosPicker）
- ⏳ 纸质小票（generic parser 尽力而为）

## 禁止
上传图片到 backend/第三方 OCR；跳过确认弹层直接写入；改生活切片/StoreKit；commit 除非要求

## 必须先 Read
web-preview/app.js：`runMockOCR`、`openOCRConfirm`、`importOCRRecords`、`renderOCRDraftArea`
ContentView.swift：`ocrForm`、PhotosPicker onChange
OCRService.swift 现状

## 验收
- [ ] 四步流程与 Web 行为一致（可先 mock 2 条测 UI，再接真 parser）
- [ ] 确认弹层 tip + 全选/反选/批量分类
- [ ] 草稿区待整理 / 完成整理
- [ ] 支付宝/微信详情 fixture 各 1 张解析正确
- [ ] source=ocr；扣次规则 §9

## 交付
新增 View 列表、与 Web 步骤对照表、fixture 说明、v0.2 未做项
```

---

### 10.12 Task B2.7 — 记账分类锁定（一键备注不覆盖手选分类）

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@NativeDemoApp/ContentView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@web-preview/app.js
@TEST_CASES_v0.1.md
```

**复制发送**

```text
你在 xuzhangapp 修复 **Task B2.7 — 记账分类锁定**（iOS 对齐 Web 已有行为；小 diff，勿重构 ContentView）。

## Bug 复现
1. 记账 Tab 手动输入金额 → 系统自动 `recommendCategory` 选中分类
2. 用户手动点选其他分类（如「购物」）
3. 点「✨ 一键生成备注」（文案写「不改你的分类」）
4. **实际**：`applyScenePack` 执行 `homeViewModel.selectedCategory = pack.category`，分类被场景包强行改回（如吃货包→餐饮）

**根因（iOS）**
- `ContentView.applyScenePack` L675 无条件 `selectedCategory = pack.category`
- `guessScenePackId()` 仅按金额猜包，忽略用户已选分类
- `.onChange(of: inputAmount)` L733-737 每次改金额都 `recommendCategory` 覆盖手选分类

**Web 正确参考（必须 Read）**
- `web-preview/app.js`：`categoryLockedByUser`（用户点分类 chip 时 `selectCategory` 置 true）
- `applyMemberScenePack(packId, { keepSelectedCategory: true })` — 一键按钮走此分支，只写备注不改分类
- `guessMemberScenePackId()` — **优先** `categoryToPackId[selectedCategory]` 再 fallback 金额
- 金额 onChange 推荐分类：`if (!categoryLockedByUser)` 才自动改

## 必做 — iOS

### 1. HomeViewModel
- 新增 `categoryLockedByUser: Bool`（或私有 + `lockCategorySelection()` / `isCategoryLocked`）
- 用户手动选分类时：`selectedCategory = cat` 且 `categoryLockedByUser = true`
- `resetInput()`（保存成功后）：`categoryLockedByUser = false`（与重置 `selectedCategory` 一并）
- `prefillFromOCR`：填入 OCR 分类后可 `categoryLockedByUser = false`（OCR 视为新草稿）

### 2. ContentView 记账表单
- `.onChange(of: inputAmount)`：**仅当 `!categoryLockedByUser`** 时才 `recommendCategory` 写 `selectedCategory`
- `categoryChip` 点击：除改 `selectedCategory` 外调用 lock（或在 ViewModel 封装 `selectCategory(_:)`）

### 3. applyScenePack
- 签名改为 `applyScenePack(_ pack: ScenePack, keepSelectedCategory: Bool = false)`
- `keepSelectedCategory == true`：**只** `inputTitle = note`，**不**改 `selectedCategory`
- `keepSelectedCategory == false`（展开列表点具体场景包）：保持现行为，分类随包改（用户显式选场景）

### 4. guessScenePackId
- 对齐 Web `guessMemberScenePackId` 的 `categoryToPackId` 映射：
  - 餐饮→food, 交通→commute, 购物→shopping, 日用→pet, 娱乐/其他→travel
- 先按 `homeViewModel.selectedCategory` 映射；无映射再按金额 fallback

### 5. 一键生成备注按钮
- 调用 `applyScenePack(quickPack, keepSelectedCategory: true)`
- UI 副文案「不改你的分类」须与行为一致

## 禁止
- 改场景包 rules 文案、会员 gating、OCR 流程、生活切片
- 同步改 web-preview（Web 已正确，除非发现 iOS 对齐后 Web 也有遗漏）

## 验收（手动 + 可补单测）
- [ ] 输入 ¥12 → 自动餐饮 → 改选「购物」→ 一键备注 → **仍为购物**，标题有备注
- [ ] 手选「交通」后改金额 ¥12→¥50 → **仍为交通**（不被 recommend 覆盖）
- [ ] 保存一笔后新单 → 金额输入再次触发自动推荐（lock 已重置）
- [ ] 展开场景包点「打工人通勤包」→ **分类改为交通**（显式选包，预期覆盖）
- [ ] `TEST_CASES_v0.1.md` 可追加 **TC-REC-13**：手改分类 + 一键备注不覆盖

## 交付
改动文件列表、验收勾选、与 Web 行为对照一句
```

---

### 10.13 Task B2.8 — 智能分类推荐（历史 + 时段 + 金额）

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md §8
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/RecordView.swift
@web-preview/app.js
@TEST_CASES_v0.1.md
```

**前置**：**B2.7** `categoryLockedByUser` 已落地（手选分类后不再被覆盖）。

**复制发送**

```text
你在 xuzhangapp 实现 **Task B2.8 — 智能分类推荐**（本地优先、可解释；替换纯金额档位）。

## 现状问题
iOS `HomeViewModel.recommendCategory` 仅按金额硬编码：
`<30 餐饮, <80 交通, <200 日用, <600 购物, else 其他`
用户生活模式差异大，推荐不准；Web 有 `topCategoryFromHistory` + `localRecommendedCategory` 但仍缺「时段」维度。

## 目标
输入金额后，综合 **历史记账习惯 + 当前时段 + 金额先验 + 备注关键词** 给出默认分类；用户手选后（B2.7 lock）不再改。

## 必做 — 新建 `CategoryRecommendService.swift`（或 HomeViewModel 内聚，优先独立 Service）

### 输入 `CategoryRecommendInput`
- `amount: Double`
- `now: Date`（用 `selectedDate` 若用户在补记日期，否则 `.now`）
- `items: [HomeItem]`（本地全量或近 90 天）
- `noteDraft: String`（`inputTitle`  trim）
- `locked: Bool` — true 时调用方直接 return 不改分类

### 评分模型（本地、确定性，禁止调用 AI 作默认路径）

对 7 类各算 `score`（餐饮/购物/交通/娱乐/日用/住宿/其他），取最高：

**1. 历史习惯（权重 40%）**
- 统计近 90 天各分类笔数占比 → `historyRatio[cat]`
- **同金额带**（amount ×0.7～1.3）历史最常分类 + 额外加分
- 无历史：回退 `topCategoryFromHistory()`（Web 同名逻辑）

**2. 时段情境（权重 35%）** — 用 `Calendar` + 本地时区
| 时段 | 倾向 |
|------|------|
| 07:00–10:00 工作日 | 交通 +3（尤其 amount≤30）；餐饮 +1 |
| 11:00–14:00 | 餐饮 +3 |
| 17:00–20:00 | 餐饮 +2；交通 +1（下班通勤） |
| 22:00–06:00 | 餐饮 +2（宵夜/饮品）；娱乐 +1 |
| 周六日 14:00–22:00 | 娱乐 +2；购物 +1 |
- `selectedDate` 非今天时，用该日 weekday/hour 判断

**3. 金额先验（权重 15%）** — 弱化现规则
- ≤20 → 餐饮+交通 各 +1
- 21–50 → 餐饮+交通
- 51–200 → 日用+购物
- >200 → 购物+其他
（分数低于历史/时段，勿单独决定）

**4. 备注关键词（权重 10%）**
- 地铁/公交/打车/停车/加油 → 交通 +4
- 咖啡/奶茶/午餐/晚餐/外卖/早餐 → 餐饮 +4
- 超市/买菜/日用品 → 日用 +3
- 电影/游戏/KTV → 娱乐 +3
- 酒店/民宿/住宿 → 住宿 +4

### 输出
- `recommended: HomeItem.Category`
- `reasonTag: String?`（可选，调试用；UI 仍只显示 chip「推荐」）

### 接入点
- 替换 `recommendCategory(for:)` 为委托 Service（或 `recommendCategory(input:)`）
- `RecordView.swift` `.onChange(inputAmount)` 与 `categorySection` 的 `recommended` 均走新逻辑
- **尊重** `categoryLockedByUser`（B2.7）

### 可选 P2（时间够再做）
- 远程 AI 分类：对齐 Web `recommendCategorySmart`（仅 `useRemoteAI` 开且备注非空时 async 覆盖，1.8s 超时回本地）
- v0.1 **不强制** AI；本地评分必须完整可用

## 禁止
- 改场景包、生活切片、天气宠物（另任务 B2.9）
- 手选分类后被覆盖

## 验收
- [ ] 早 8 点输入 ¥4 → 倾向 **交通**（非一律餐饮）
- [ ] 12 点输入 ¥25 → 倾向 **餐饮**
- [ ] 用户常记「购物」且金额 80～150 → 历史拉高购物
- [ ] 手选分类后改金额 → 分类不变（B2.7）
- [ ] 补记日期：用 `selectedDate` 的星期/小时参与时段分
- [ ] 追加 **TC-REC-14** 到 TEST_CASES（可选）

## 交付
算法简述（各权重）、改动文件、验收勾选、P2 未做项
```

---

### 10.14 Task B2.9 — 天气场景宠物陪伴（对齐 Web）

**@ 文件**

```text
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md §8
@web-preview/app.js
@NativeDemoApp/ContentView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/SettingsView.swift
@NativeDemoApp/Info.plist
```

**复制发送**

```text
你在 xuzhangapp 实现 **Task B2.9 — 天气场景宠物陪伴**（iOS 对齐 Web 已有能力；本地规则为主）。

## 现状问题
- 设置有「天气场景暖心互动」开关，但 iOS **未实现**：无定位、无 open-meteo、无场景规则
- 记完账 `petMessage` 仅 4 条固定随机句，无天气/时段/消费场景
- 点首页宠物无 Web 的 `buildContextualPetMessage` / `PET_SCENE_RULES` 逻辑

## Web 参考（必须 Read 并移植）
`web-preview/app.js`：
- `petCopy`（recordSaved / weatherHint / weatherContext / companion / lightScene）
- `PET_SCENE_RULES`（hotNoCool / rainyHome / monthEndSoft / weekendHealing / commuteSteady / groceryWarm / highSpendComfort / noExpenseCalm）
- `buildContextualPetMessage(recordLike)` — 记完账气泡
- `fetchWeatherSnapshot` — Open-Meteo `api.open-meteo.com`（无需 key）
- `refreshWeatherInBackground` / 设置开关联动
- 宠物按钮 click 分支（L4540+）
- 辅助：`isLateNight` / `isDrinkOrSnack` / `commuteExpenseCountToday` / `hasCoolingExpenseToday` 等

## 必做

### 1. `WeatherCompanionService.swift`（新建）
- CoreLocation 取坐标（`whenInUse`）；缓存 30min
- `fetchWeatherSnapshot()` → `{ temp, weatherCode, ts }` 对齐 Web
- 拒绝权限时返回 nil，走通用文案（不崩溃、不阻塞记账）

### 2. `PetCompanionCopy.swift` 或内嵌常量
- 移植 `petCopy` + `PET_SCENE_RULES` 为 Swift
- `{petName}` 替换：有 `petNickname` 用设置值，否则「小窝」
- 禁止词同北极星（不骂用户乱花钱）

### 3. `PetCompanionService.buildContextualMessage(...)`
参数：`record: HomeItem?`, `weather: WeatherSnapshot?`, `settings: AppSettings`, `todayItems: [HomeItem]`
逻辑对齐 Web `buildContextualPetMessage`：
1. `!weatherCompanionEnabled` → recordSaved 随机；偶发 weatherHint 引导开权限
2. 无定位 → 温柔 fallback + weatherHint（冷却，勿每次弹）
3. 有天气 → 按 `PET_SCENE_RULES` 优先级匹配第一条
4. 补充规则：低温+热饮 `coldDrink`、周末+餐饮娱乐 `weekendRelax`、深夜+零食 `lateNightSnack`
5. 兜底 `recordSaved`

### 4. 接入点
- `HomeViewModel.addManualRecord` 成功后：`petMessage = await PetCompanionService...`（勿阻塞 UI >100ms，天气 fetch 用缓存）
- `ContentView` 首页宠物按钮点击：对齐 Web pet click（天气开 → 场景句；否则 companion/lightScene）
- `SettingsView` 开天气开关：触发一次权限请求 + `startWeatherRefresh`；关则停
- `Info.plist` 增加 `NSLocationWhenInUseUsageDescription`（中文说明：用于天气相关温柔提醒，可关）

### 5. 开关关系
| 宠物陪伴 | 天气互动 | 行为 |
|----------|----------|------|
| 关 | * | 不显示宠物气泡（现有逻辑） |
| 开 | 关 | recordSaved / companion 通用句 |
| 开 | 开 | 完整场景+天气规则 |

## 可选 P2
- Web 的 `buildWeatherSpendPetMessage` AI 句（需 remoteAI + ai-proxy）；v0.1 可只做 `weatherAiFallback` 本地句
- 天气权限「前往设置」深链

## 禁止
- 改分类推荐（B2.8）、生活切片、StoreKit
- 上传账单到天气 API；仅 lat/lon → open-meteo

## 验收
- [ ] 设置开「天气互动」→ 系统定位弹窗（首次）
- [ ] 雨天记一笔 → 宠物气泡含雨天治愈语境（非 4 条固定句）
- [ ] 高温且无冷饮记录 → hotNoCool 类提示（可 mock weather）
- [ ] 关天气 → 记完账仍有一句 recordSaved，无定位请求
- [ ] 关宠物 → 无气泡
- [ ] 拒绝定位 → 不崩溃，通用文案 + 偶发 hint

## 交付
改动文件、Info.plist 文案、与 Web 规则对照表、验收勾选、P2 未做项
```

---

### 10.15 任务编号对照 + 合并 Prompt（可选）

**不要混任务**：你跑的 **B2.10**（场景备注池）≠ **B2.8**（智能分类）≠ **B2.9**（天气宠物）。

| ID | 名称 | 改什么 | 独立 Agent 文件 | 典型状态 |
|----|------|--------|-----------------|----------|
| **A4** | 场景包哲学对齐 | tagline、旅行出发包、5 条替词 | [`AGENT_PROMPT_SCENE_PACK_PHILOSOPHY.md`](AGENT_PROMPT_SCENE_PACK_PHILOSOPHY.md) | ✅ iOS |
| **B2.7** | 分类锁定 | `categoryLockedByUser` | §10.12 | ✅ |
| **B2.8** | 智能分类推荐 | `CategoryRecommendService` | [`AGENT_PROMPT_B2.8_SMART_CATEGORY.md`](AGENT_PROMPT_B2.8_SMART_CATEGORY.md) | ✅ |
| **B2.9** | 天气宠物 | Open-Meteo + `PET_SCENE_RULES` | [`AGENT_PROMPT_B2.9_WEATHER_PET.md`](AGENT_PROMPT_B2.9_WEATHER_PET.md) | ✅ |
| **B2.10** | 场景备注池扩展 | 四包×4档×8条 + stable hash | §10.16 | ✅ iOS MVP |

**可选合并（仅 B2.8 + B2.9）**：若希望 Codex **一次 PR** 完成「记账更聪明 + 宠物有温度」，将 §10.13 + §10.14 两段 prompt 合并发送，并注明：**先做 B2.7 依赖检查 → B2.8 → B2.9**，验收分节勾选。**不要**把 B2.10 / A4 写进同一条 prompt。

---

### 10.16 Task B2.10 — 场景备注包文案池扩展

**@ 文件**

```text
@SCENE_PACK_COPY_POOL_v0.2.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md §7
@NativeDemoApp/ContentView.swift
@web-preview/app.js
@IMPLEMENTATION_FOR_CODEX.md §10.12
```

**前置**：建议 **B2.7**（`keepSelectedCategory`）已完成。

**复制发送**

```text
你在 xuzhangapp 实现 **Task B2.10 — 场景备注包文案池扩展**（会员一键备注；本地模板，不接 AI）。

## @ 必读
@SCENE_PACK_COPY_POOL_v0.2.md（§3～§7 全部 128 条备注为唯一文案来源）

## 当前状态（2026-06-07 同步）
iOS 已迁入 `ScenePackCopyPool.swift`：8 包 × 4 档 × 8 条，并支持餐饮/交通时段子池、历史关键词增强、`{petName}` 渲染、心意往来包和顺手添置包。
连续点击同一场景包会用 `variant` 顺序轮换，避免用户不满意时只能得到同一句。
Web 同步仍作为后续任务单独处理。

## 目标
1. 维护 `ScenePackCopyPool.swift`，当前 iOS 为 8 包 × 4 档 × 8 条
2. 选取：首次 `hash(dayKey + packId + tierIndex + categoryContext + contextKey) % poolSize`；连续点击用 `variant` 顺序后移，同天可换句、换日也可换句
3. 可选：时段子池（commute morning/evening、food noon/night）在 tier 内优先
4. `enrichNoteWithHistory` 对齐 Web（§2.2）：45% 概率追加用户历史备注关键词
5. `{petName}`：读 `AppSettings.petNickname`（无则「小窝」）
6. `applyScenePack`：一键 `keepSelectedCategory: true` 只写备注；展开点包可改分类（B2.7）
7. `guessScenePackId`：先分类映射再金额 fallback（§8）
8. **iOS + Web** 同步扩展（同文案池）；Web 仍走 `applyMemberScenePack`

## 结构建议
```swift
struct ScenePackDefinition {
  let id, emoji, label, desc: String
  let category: HomeItem.Category
  let tiers: [ScenePackTier] // maxAmount + notes: [String]
}
```

## 禁止
- 自造不在 SCENE_PACK_COPY_POOL_v0.2.md 里的句子
- 接 ai-proxy 生成备注
- 改会员门槛、生活切片

## 验收
- [ ] 四包每档 ≥8 条备注已迁入
- [ ] 同一天同金额连点一键备注 → 同一句（稳定 hash）
- [ ] 改系统日期到次日 → 句式可变化
- [ ] 手选「购物」+ 一键备注 → 分类不变，备注来自 shopping 顺手添置包，不出现门票/机票/高铁/行程
- [ ] 宠物包 `{petName}` 正确替换；第 4 档（≤150）存在
- [ ] 历史备注词偶发追加（同分类）
- [ ] Web memberScenePacks 与 iOS 条数一致

## 交付
改动文件、128 条迁入核对、验收勾选、时段子池是否实现
```

---

## 11. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版：任务 B1～D1、代码锚点、禁止项、Codex 提示词模板 |
| 2026-06-02 | 新增 **§10 各任务完整对话示例**（B1～B4、A2、C1、C2、D1 + Phase B 合并） |
| 2026-06-02 | 新增 **Task E1** StoreKit + 后端验单（§4 + §10.10）；TestFlight 付费前置 |
| 2026-06-02 | 新增 **Task B2.5** 切片叙事/UI polish（§4 + §10.8）；D1 前置必做；§10.8/10.9 顺延 |
| 2026-06-02 | **Task D1（§10.9）** prompt 对齐 B2.5：teaserLine 主标题、Sheet≠分享图、禁止 KPI 霸屏 |
| 2026-06-04 | 新增 **Task F1** 支付宝/微信 OCR + Web 四步确认导入（§4 + §10.11） |
| 2026-06-04 | 新增 **Task B2.7** 记账分类锁定（§10.12）；一键备注不覆盖手选分类 |
| 2026-06-04 | 新增 **Task B2.8** 智能分类推荐（§10.13）、**B2.9** 天气宠物（§10.14） |
| 2026-06-04 | 新增 **Task B2.10** 场景备注包文案池（§10.16）、`SCENE_PACK_COPY_POOL_v0.2.md` |
| 2026-06-06 | §2.2 代码锚点更新（StatsWebView/RecordView）；§3 任务状态；链至 TODO |
| 2026-06-06 | §2.2：`InsightWebView`、ContentView ~702；结构债 🟡 说明 |
| 2026-06-06 | E1：iOS Release tier 门禁 ✅；§10.10 删 Debug 模拟开通说明 |
| 2026-06-06 | D1 ✅：§2.2/§3/§4 Task D1 状态；周播完分享图 |
| 2026-06-06 | §10.15 任务编号对照表；链至 AGENT_PROMPT_B2.8 / B2.9 |
