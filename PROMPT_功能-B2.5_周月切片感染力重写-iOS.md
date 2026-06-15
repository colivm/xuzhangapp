# Agent Prompt · B2.5 周/月切片感染力重写（仅 iOS）

> **背景**：产品与记账链路（预填、Lexicon、痕迹章节卡、周记摘页 D1.1）已明显进步，但 **周切片 / 月生活章播放** 仍偏「报表念 KPI」，播完难以形成付费情绪高峰。创始人判断：**第一次周播完、月章第三次用完** 应是会员转化峰值，当前切片效果不满意。  
> **本任务**：重写幕逻辑 + 旁白池 + 播放 Sheet 呈现，让播放像「讲完我的这段生活」，而非「又念一遍统计」。  
> **用法**：短指令 + `@PROMPT_功能-B2.5_周月切片感染力重写-iOS.md` 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。

---

## 一、问题总结（创始人 / 产品共识）

### 1.1 商业与体验的断点

```text
记账省力 ✅ → 素材在涨 ✅ → 周/月播完被打动 ❌ → 付费高峰未出现
```

- 叙账 **不是缺付费点**：会员卖的是「无限叙 + 省力记」。
- 真正断在 **第三环**：免费 1 次周播 + 终生 3 次月章，没给到「想再听一次」的峰值体验。
- 永久用户越黏记账/痕迹，说明 **记账侧认**；不肯续费，多半是 **「再播一遍不值价」**。

### 1.2 当前切片「不满意」的具体表现

| 现象 | 用户感受 | 根因（代码/设计层） |
|------|----------|---------------------|
| 周/月旁白反复讲笔数、总额、TOP 分类 | 「痕迹 Tab 已经看过了」 | `PlaybackCopyPool` 模板以 `{count}{total}{topCategory}` 为主 |
| 分类幕只有 `chart.pie` +「生活主料：餐饮」 | 像统计 App，不像周记 | 设计要的「生活配方」环图未落地或报表感过重 |
| 月章 6 幕按「上旬/中下旬/构成」翻页 | 像加长版周播，不像读一章月记 | `buildMonthSummary` 结构偏会计时间轴 |
| 高光幕取金额最大一笔 | 4.75 地铁淹没「有画面」的生活句 | `highlightItem` 弱用 title/emotionTag/用户手改 |
| 播放 Sheet vs 痕迹章节卡气质割裂 | 过程叙、产物叙不连续 | `SummaryPlaybackSheet` 仍是大字 metric + 自动翻页幻灯片 |
| 月末收束导流「打开月度复盘」 | 从「叙」拽到「议」 | `month-action` 文案与北极星冲突 |
| 第二遍播放变化小 | 只换同义句，无新角度 | 模板语义重复，seed 轮换不够 |

### 1.3 北极星对照（播完应达到）

| 现在（问题） | 目标（本任务） |
|--------------|----------------|
| 「哦，餐饮占四成」 | 「对，这周就是周三忙、那笔咖啡留住了」 |
| 信息源 = 统计维度 | 信息源 = **用户 title / emotionTag / Echo 锚点 / 代表日** |
| 屏上主角 = 大数字 | 屏上主角 = **一句 headline + 一个生活画面** |
| 月 = 更多统计幕 | 月 = **变化点 + 词气味 + 更长收束** |
| 播完想关 Sheet | 播完想 **下周再听 / 月章额度舍不得用** |

### 1.4 与已完成功能的关系

- **不推翻**：`PlaybackService` 聚合骨架、次数 `SummaryPlaybackQuotaStore`、C1 动线、D1.1 `WeeklyShareCardView`、痕迹 `traceChapterCard`。
- **要接上**：记账链路产出的生活句（`HomeItem.title`、`displayEmotionTag`、`EchoAnchorService`）必须进入 **回放选材池**。
- **视觉对齐**：播放 Sheet 向 **痕迹章节卡 + 周记摘页** 靠齐，**不要**向 KPI 报表靠齐。

---

## 二、任务编号对照

| ID | 做什么 | 主要文件 | 优先级 |
|----|--------|----------|--------|
| **SLICE-1** | 周播幕逻辑 + 选材重写 | `PlaybackService.swift` | P0 |
| **SLICE-2** | 旁白池重写（生活句导向） | `PlaybackCopyPool.swift` | P0 |
| **SLICE-3** | 播放 Sheet 信息层级 + 视觉 | `SummaryPlaybackSheet.swift` | P0 |
| **SLICE-4** | 月章与周播差异化 | `PlaybackService` + CopyPool | P0 |
| **SLICE-5** | teaserLine / 统计卡 hook | `PlaybackService`、`StatsWebView` | P1 |
| **SLICE-6** | 与 D1.1 摘页 / Echo 同源 | `PlaybackService`、`WeeklyShareCardView` | P1 |
| **SLICE-7** | copy_lint + 播放回归 case | `scripts/copy_lint.py` 或 JSON | P2 |

---

## 三、必做 SLICE-1 · 周播幕逻辑重写

### 3.1 目标结构（5 幕，可 weak 时缩 3 幕）

| 幕 id | 叙事向标题 | 内容来源 | 禁止 |
|-------|-----------|----------|------|
| `week-presence` | 这一周 | 只确认「这段日子在记」；total **退到角标** | 48pt 总额压过旁白 |
| `week-rhythm` | 哪天最热 | 最忙 weekday + **该日 1 笔代表 title**（若有） | 只报星期几无生活句 |
| `week-voices` | 留下的话 | 从本周挑 1～2 条 **高质量 title**（非 generic、优先 userEdited / Echo） | 再用 TOP1 分类当主视觉 |
| `week-scent` | 常冒头的词 | 3～5 个关键词（title + emotionTag，复用 Insight 词云思路） | 环图 KPI 三格 |
| `week-outro` | 先记到这里 | 一句收束；播完 CTA 对齐 §6.4 | 收尾再报 count/total |

**弱数据（<3 笔）**：缩为 3 幕 presence → voices（若有）→ outro，保留 `week-weak-*` 语气。

### 3.2 选材评分（新增私有逻辑即可）

对周期内每笔 `HomeItem` 打 **playbackMaterialScore**：

- `userEditedTitle == true` +分
- title 非 `defaultRecordTitle` / 非纯分类名 +分
- `EchoAnchorService.isEligibleLifeTraceTitle` +分
- 有非 generic `displayEmotionTag` +分
- **仅金额大** 不单独当选高光

`highlightItem` / 代表条目逻辑与 `StatsWebView.traceRepresentativeItems` **对齐或复用**。

### 3.3 保留 / 弱化

- **可保留**：`EchoAnchorService.pickEchoAnchor` 用于 `week-voices` 主句
- **弱化或删除独立幕**：原 `week-top-category` 若保留，**不得**为第 3 幕主视觉；分类信息进 `week-scent` 或角标
- **节奏幕**：必须带 **真实 weekday 标签**（`busiestDay`），忌「某一天」

---

## 四、必做 SLICE-4 · 月章差异化

### 4.1 目标结构（6 幕 → 建议 5 幕）

| 幕 id | 关键 | 与周播差异 |
|-------|------|------------|
| `month-opening` | 活跃天数 + **一句本月收束**（可无环比数字） | 更长呼吸 |
| `month-early-voice` | 上旬 **代表生活句** + 轻量节奏 | 不是只报 earlyCount |
| `month-late-voice` | 下旬/中下旬侧写 | 同上 |
| `month-change` | **变化点**（保留 `meaningfulMonthlyCategoryChange` / 连续记账日） | 月章独家记忆点 |
| `month-scent` | 本月常冒头词（3～5）或 TOP2 生活句 | 替代「生活构成」环图 KPI 幕 |
| `month-outro` | 收束；**禁止**「打开月度复盘」导流 AI Tab | 只 CTA：下月再叙 / 了解会员 / 保存摘页（若已有） |

### 4.2 禁止

- 6 幕全部重复 `{count}{total}{topCategory}` 句式
- `month-action` 引导去 **小 AI 说 / 议**
- 无上月数据时硬编 `momPercent` 吓人数字

---

## 五、必做 SLICE-2 · PlaybackCopyPool 重写原则

### 5.1 模板变量扩展

在现有变量基础上 **优先使用**：

```text
{highlightTitle} {highlightDayLabel} {echoLine}
{voiceTitle1} {voiceTitle2} {scentWord1} {scentWord2} {scentWord3}
{changeHint} {leadingSegment} {activeDays}
```

### 5.2 旁白原则（`COPY_GOVERNANCE` + §5.8）

- **事实 + 可选轻隐喻**；禁止预算/省钱/审判词
- 同一播放 **幕间不重复** 同一 KPI 句式
- `warm` / `plain`：事实相同，语气不同；关宠物用 `plain`
- 第二遍播放（同 seed 不同 variant 或不同幕序旁白）用户应感到 **新角度**，不是同义替换

### 5.3 teaserLine

- 周：`PlaybackCopyPool.weekTeaser` 改为 **叙事 hook**（如「周三最忙，留下过一句关于…」），**非** `N笔·¥·分类为主`
- 月：同理；`StatsWebView.summaryCardSubtitle` 优先 `teaserLine`

---

## 六、必做 SLICE-3 · SummaryPlaybackSheet 呈现

参照 `PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` §5.5.1、§5.8.3，并 **对齐 D1.1 / 痕迹卡**：

1. **信息层级**：幕标题（小）→ **旁白 22–26pt 主视觉** → 辅助数字 1 个且小字号
2. **Header 瘦身**：播放中不常驻 `N笔·¥总额`；可仅首幕显示日期范围
3. **分类幕**：若保留环图，**全片仅 1 次**；或改为词云/代表句卡片（推荐后者）
4. **高光幕**：引号卡片展示 `highlightTitle`；金额脚注，勿 48pt
5. **收尾幕**：无 count/total 大字
6. **底渐变**：intro / rhythm / voices / scent / outro 色相略区分（已有 palette 可扩展）
7. **播完 CTA**：保持 §6.4；周播完「保存本周故事图」与 `WeeklyShareCardView` **同源 headline/anchorLine**

---

## 七、明确不做（scope guard）

- 不改 `SummaryPlaybackQuotaStore` 次数规则
- 不调 ai-proxy / 远程 AI 生成旁白
- 不重构 `ContentView` / 底栏
- 不改 `web-preview`
- 不新增会员定价
- 不大改 `ScenePackCopyPool` 记账侧

---

## 八、验收清单（Agent 完成前自检）

### 8.1 产品三问（播完后）

- [ ] 有没有一句提到 **我写过 / 记得的事**？（非「餐饮占 40%」）
- [ ] 有没有一句是 **播放前不知道的**？（结构或生活侧写）
- [ ] 会不会想 **下周再点播放**？

### 8.2 技术回归

- [ ] 本周 ≥3 笔：周播 5 幕（或 weak 3 幕）可播完；≥80% 扣周次数
- [ ] 本月有数据：月章可播完；扣终生月次数
- [ ] 会员：次数不扣；播放正常
- [ ] `teaserLine` 在痕迹 Tab 回放卡副标题可见且 **非纯 KPI**
- [ ] 播完周章「保存故事图」与播放 **headline/anchor 同源**
- [ ] 无「打开月度复盘」类导流 AI 的旁白
- [ ] `copy_lint.py` 扫 CopyPool 无新增禁词

### 8.3 样例数据走查（建议自造 fixture）

| 场景 | 预期 |
|------|------|
| 本周 8 笔：含「地铁」「瑞幸」手改 title | 高光/ voices 幕出现生活句，非只讲餐饮占比 |
| 本周 2 笔 | weak 路径，不硬凑 5 幕 |
| 本月有上月对比 | change 幕有一句具体变化 |
| 全是 generic title | 降级文案诚实，不编造感受 |

---

## 九、文件清单

| 文件 | 动作 |
|------|------|
| `NativeDemoApp/Services/PlaybackService.swift` | 幕结构、选材、teaser |
| `NativeDemoApp/Services/PlaybackCopyPool.swift` | 模板重写 |
| `NativeDemoApp/Views/SummaryPlaybackSheet.swift` | 层级、视觉、按幕 UI |
| `NativeDemoApp/Views/StatsWebView.swift` | summaryCardSubtitle 用 teaserLine |
| `NativeDemoApp/Services/EchoAnchorService.swift` | 仅只读复用，小改可 |
| `scripts/copy_lint.py` | 可选：扫 PlaybackCopyPool |

---

## 十、相关文档

| 文档 | 用途 |
|------|------|
| [`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) §0、§6 | 先叙后议、播完 CTA |
| [`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md) §5.8 | 感染力禁止项与幕要点 |
| [`PRODUCT_OBJECTIVE_REVIEW_RECORD_TO_NARRATIVE_v0.1.md`](PRODUCT_OBJECTIVE_REVIEW_RECORD_TO_NARRATIVE_v0.1.md) | 简记→可叙链路 |
| [`COPY_GOVERNANCE_PLAN_v0.1.md`](COPY_GOVERNANCE_PLAN_v0.1.md) | 口吻与禁词 |
| [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) §10.8 | 原 B2.5 基线 |
| [`AGENT_PROMPT_D1.1_WEEKLY_SHARE_POSTER.md`](AGENT_PROMPT_D1.1_WEEKLY_SHARE_POSTER.md) | 摘页气质对齐 |

---

## 十一、复制发送（给 Agent）

```text
请阅读并执行：@PROMPT_功能-B2.5_周月切片感染力重写-iOS.md

背景：记账/痕迹/预填已进步，但周切片与月生活章播放仍偏报表念 KPI，播完形不成付费情绪高峰。请按 SLICE-1～SLICE-6 重写幕逻辑、PlaybackCopyPool、SummaryPlaybackSheet，让播放讲「我的生活句」而非重复笔数/总额/TOP分类。

优先级：SLICE-1/2/3/4（P0）→ SLICE-5/6（P1）。遵守 scope guard，不改次数 enforce、不调 AI、不改 web-preview。

完成后输出：
1. 改了哪些文件、每条 SLICE 摘要
2. §8.1 产品三问 + §8.3 样例走查结果
3. 刻意未做项

约束：仅 iOS；最小 diff；不提交除非我要求；中文 commit message。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-15 | 首版：创始人问题总结 + 幕逻辑重写 prompt |
