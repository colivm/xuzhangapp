# Agent Prompt · Task D1.1 — 周分享海报叙事化 polish（仅 iOS）

> **状态：iOS 已完成（2026-06-07）**；真机回归见 [`TODO.md`](TODO.md) 第 13 条。  
> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。  
> **格式**：「复制发送」为单一 ` ```text ` 块，块内**不要**再嵌套 ` ``` `，否则复制会截断。

---

## 任务编号对照（必读）

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| **B2.5** | 生活切片 Sheet 叙事/UI | `SummaryPlaybackSheet.swift` | ⏳ 可并行；气质应对齐 |
| **D1** | 播完导出分享图（功能） | `SummaryPlaybackSheet` + `WeeklyShareCardView` | ✅ 已完成 |
| **D1.1** | **周分享海报 polish**（本 prompt） | `WeeklyShareCardView` + `WeeklyShareCardPayload.anchorLine` | ✅ **iOS 已完成** |

**关系**：D1 已接通播完「保存本周故事图」与 AI Tab 预览/分享；D1.1 **不重做导出入口**，只把 `WeeklyShareCardView` 从「报表/dashboard」改成「生活周记海报」。

---

## 设计 brief 摘要（Agent 须内化）

**问题**：数据层已叙（`headline` ← `teaserLine`，`subtitle` ← 切片收束句），但 UI 仍三格 KPI + 柱图 + 环图 TOP%，像消费分析报告，违背「账是素材，叙是目的」。

**目标**：缩略图 3 秒内像 **生活周记 / 故事海报**，不是支付宝年度账单。  
**母版气质**：对齐 `SummaryPlaybackSheet` 播完页与 `ShareCardTheme` 暖色渐变；**不要**对齐 web Canvas 报表布局。

---

## @ 文件（Agent 必须先 Read）

```text
@AGENT_PROMPT_D1.1_WEEKLY_SHARE_POSTER.md
@PRODUCT_NORTH_STAR.md
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
@IMPLEMENTATION_FOR_CODEX.md
@NativeDemoApp/Views/InsightWebView.swift
@NativeDemoApp/Views/SummaryPlaybackSheet.swift
@NativeDemoApp/Services/PlaybackService.swift
@NativeDemoApp/Views/StatsWebView.swift
@TEST_CASES_v0.1.md
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task D1.1 — 周分享海报叙事化 polish**（仅 iOS；**不改 web-preview**）。

## 背景（北极星）
分享图对外（朋友圈/相册）也要遵守：先叙后议 · 理解而非审判。
自检问句：这是在帮用户温柔地看见生活，还是在拉回「管钱工具」？
当前 WeeklyShareCardView 主视觉是三格 KPI + 双图表，与 D1/B2.5 文档「叙事海报、非 KPI 霸屏」冲突。

## 现状（必读后再改）
- WeeklyShareCardView 在 InsightWebView.swift 末尾（~L559+）：390×580 snapshot
- 入口 1：SummaryPlaybackSheet.shareWeeklyStoryCard() — 播完「保存本周故事图」
- 入口 2：InsightWebView AI Tab — 周度分享卡预览 + UIActivityViewController
- 数据：PlaybackService.buildWeeklyShareCardPayload — headline=teaserLine, subtitle=最后一幕 plain
- ShareCardTheme 已有 pet / neutral 两套；snapshot() 逻辑保留

## 目标布局 — 方向 A「生活周记海报」（默认实现）

信息层级（自上而下）：

1. **顶栏（小）**：周期 periodText（左）+ 弱品牌「叙账」（右）；删除「叙账 · 周度分享卡」功能标题
2. **主标题（大，占屏高约 40%+）**：headline（teaserLine）；rounded、2–3 行；可去掉或弱化「你好，{nickname}」— 若保留 nickname，须小于 headline、不占主位
3. **第二叙事层（中）**：subtitle（切片收束句）；从 footer 小字 **上提** 到 headline 下方
4. **生活锚点（中偏小，一行）**：anchorLine — 见下文 payload 扩展；无则省略，勿用 KPI 三格顶替
5. **辅助信息（小，一行）**：如「这周记了 N 次」；**不要**并排「记录/支出/主料」三格；**不要** ¥ 总额大字
6. **可选纹理**：极淡 7 日节奏条（opacity ~30–40%，无「近7天小趋势」dashboard 标题、无峰值高亮阴影）；**默认去掉环图**
7. **页脚（小）**：「来自 叙账 · 温柔回看每一周」或等价；cornerDec 猫耳/简洁装饰可保留

参考线框（非像素稿）：

  [3.24 ~ 3.30                    叙账]
  「餐饮和路上居多，有一笔像对自己的照顾。」  ← headline
  温柔回看，不必苛责。                      ← subtitle
  周三那笔最像高光。                        ← anchorLine（可选）
  这周记了 6 次。                           ← 一行辅助
  ▁▂▃▅▃▂▁                                   ← 可选极淡 rhythm
  来自 叙账 · 温柔回看每一周

## 必删 / 必弱化（UI 层）

| 删除 | 原因 |
|------|------|
| 标题「叙账 · 周度分享卡」 | 功能名，报表感 |
| HStack 三格 storyMetric（记录/支出/主料） | 典型 dashboard |
| ringChart 整块（TOP xx%、占比最高、继续按笔记录更好） | 财务分析 + 轻微教练感 |
| 「近7天小趋势」类 dashboard 小标题 | 改无标题或「这一周的起伏」 |

| 弱化 | 做法 |
|------|------|
| trendChart | 改为 rhythmTexture：更矮、更淡、无 peak 阴影；或整段删除（删后卡片仍须完整可分享） |
| 数字 | 全卡无 %、无 TOP、无 ¥ 大字；笔数最多一行生活化 copy |

## 文案替换（硬编码在 View 内时须改）

- 「记录 N 笔」→「这周记了 N 次」/「留下了 N 段小痕迹」
- 「支出 ¥X」→ 删除或仅 Debug 不展示
- 「主料 · XX」→ 并入 headline/anchor，不单列 KPI
- 「XX占比最高 / 节奏平稳 / 继续按笔记录更好」→ 全部删除
- 按钮「保存本周故事图」已正确 — **不要改** SummaryPlaybackSheet 按钮文案

## 必做 — UI 实现

1. **重写 WeeklyShareCardView.body 信息架构** 按上文「方向 A」；保留 ShareCardTheme、isPetMode、snapshot()、390×580 导出尺寸
2. **减少「白底面板套卡片」**：可保留外层渐变 + 单层内容区，降低 panelBorder 报表块感
3. **两入口同源**：SummaryPlaybackSheet 与 InsightWebView 仍共用同一 WeeklyShareCardView(payload:)；禁止两套海报
4. **弱数据周**（1–2 笔）：headline/subtitle 仍可读；辅助行用温柔起步句，勿空一大块图表区
5. **（推荐）迁文件**：若 diff 过大，将 WeeklyShareCardView 抽到 NativeDemoApp/Views/Components/WeeklyShareCardView.swift；InsightWebView 只保留 AI Tab 入口 — 小改即可，非必须

## 必做 — 可选 payload 扩展（小改 PlaybackService，优先做）

在 WeeklyShareCardPayload 增加 **anchorLine: String?**（或 lifeAnchor），由 buildWeeklyShareCardPayload 从已 build 的 SummaryPlayback 抽取 **一句**，优先级：

1. highlight 幕存在 → 如「{weekday}那笔：{highlightTitle}」（无金额）
2. 否则 rhythm 幕 → 如「{busiestDay}最满」
3. 否则 nil

**不要**为此重写 weekTeaserLine 全文逻辑（属 B2.5 文案池）；本任务只多一个展示字段。
WeeklyShareCardView 旧 init(weekTotal:...) 可保留给 Preview，但生产路径走 payload。

## 禁止

- 改 web-preview/app.js 或 Canvas 分享卡
- 改 SummaryPlaybackSheet 播完 CTA 文案/次数/会员墙
- 改 B4 扣次、StoreKit、OCR、B2.8/B2.9 宠物天气
- StatsWebView 生活切片卡片加分享按钮
- 把 Sheet 五幕 metric 拼贴进一张图
- 新增环图 + 柱图双 chart（最多一种极弱纹理）
- git commit 除非用户明确要求

## 验收（手动 + 肉眼）

- [ ] 播完「保存本周故事图」导出 PNG；AI Tab 预览 **同一套** 新布局
- [ ] 缩略图 3 秒：像「生活周记」而非「消费报告」
- [ ] 遮掉 rhythm 条后，卡片仍完整可分享（叙事先立住）
- [ ] 无 %、无 TOP、无三 KPI 并排、无 ¥ 总额大字
- [ ] headline 视觉为主角；数字类信息面积明显小于叙事文案
- [ ] pet / neutral 两套主题均可读；snapshot @3x 清晰
- [ ] 与 SummaryPlaybackSheet 播完页并排：气质同一产品
- [ ] 当周无数据时 buildWeeklyShareCardPayload 仍 nil，按钮 disabled 行为不变

## 交付

1. 改动文件列表
2. 前后对比说明（删了哪些报表元素、主视觉改什么）
3. anchorLine 抽取规则（若实现）
4. 验收勾选
5. 未做项：月章海报 v0.2、weekTeaserLine 去 % 文案（B2.5）、web 对齐、B2.5 Sheet 全量 polish

最小 diff；先 Read InsightWebView WeeklyShareCardView 与 SummaryPlaybackSheet.shareWeeklyStoryCard 再改。
```

---

## 与 B2.5 合并发送（可选）

若一次 PR 同时 polish **切片 Sheet + 分享海报**，同一条消息内按顺序粘贴：

1. [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) **§10.8** B2.5「复制发送」全文  
2. 空一行  
3. 整段 **上文「复制发送」**  
4. 末尾加一句：

```text
同一 PR：B2.5 改 Sheet 层级，D1.1 改 WeeklyShareCardView；两入口分享图必须与 D1.1 验收一致。
```

---

## 文档回写（Agent 交付后由人改，非本任务必做）

- `TODO.md`：栏 A 增加 `- [ ] D1.1 周分享海报 polish`
- `IMPLEMENTATION_FOR_CODEX.md`：§10.9 后增 §10.9.1 D1.1 摘要 + 链到本文件
