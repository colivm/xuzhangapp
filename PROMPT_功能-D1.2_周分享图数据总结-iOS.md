# Agent Prompt · Task D1.2 — 周分享图「数据总结 + 关照」（仅 iOS）

> **背景**：D1.1 已把分享图从 KPI 报表改成周记海报布局，但文案仍易落成「账本解说 / 小票句 / 空煽情」，用户分享意愿不足。  
> **创始人方向**：分享图应 **基于真实数据帮用户总结**，再配 **一句叙账式关照**——有依据、说人话、愿意发。  
> **公式**：`事实（可验证）+ 关照（理解不审判）`  
> **用法**：短指令 + `@PROMPT_功能-D1.2_周分享图数据总结-iOS.md`  
> **仅 iOS**；`web-preview` **不要改**。

---

## 一、产品共识（必读）

### 1.1 用户会分享什么

| 会分享 | 不会分享 |
|--------|----------|
| 「App 帮我把这周讲明白了」 | 一条 OCR 小票（便利蜂买饮料） |
| 有数据锚点的事实总结 | 无依据的 mood（没什么大事的一周） |
| 一句理解式关照 | 预算/省钱/剁手警告 |
| 陌生朋友 3 秒能懂 | 「账本里写着」「附记：N 笔」 |

### 1.2 核心公式

```text
分享主句 = 数据事实（来自本周聚合，用户对得上号）
分享副句 = 轻关照（叙账语气：理解，不是管家）
```

**示例（创始人给定方向，可 polish 同义句）：**

| 真实信号 | 事实句 | 关照句 |
|----------|--------|--------|
| 便利蜂 5 次，本周品牌 TOP | 便利蜂去了 5 次，是这周最多的 | 工作再忙，也别忘了好好吃饭 |
| 健身/运动类 TOP | 锻炼记了 4 次，是这周最勤的事 | 练得努力，也要照顾好身体 |
| 外卖频次高 | 外卖点了 6 次 | 忙的时候靠外卖也正常，有空做顿热的更好 |
| 周三 4 笔最集中 | 周三最忙，记了 4 笔 | 忙完那天，值得对自己好一点 |

### 1.3 与播放 / D1.1 的关系

| 能力 | 关系 |
|------|------|
| **B2.5 周播** | 播放讲过程；分享图讲 **结论**。可同源数据，**不同文案管线** |
| **D1.1 布局** | 保留 390×580、ShareCardTheme、rhythm 点、无 KPI 三格/环图 |
| **Echo / 生活句** | 仅当 **无清晰数据信号** 或 **手改 title 极强** 时，才降级为生活句模式 |

---

## 二、任务编号

| ID | 做什么 | 主要文件 | 优先级 |
|----|--------|----------|--------|
| **SHARE-1** | 周分享信号聚合（品牌/分类/节奏 TOP） | `PlaybackService` 或新 `WeeklyShareInsightBuilder` | P0 |
| **SHARE-2** | 事实句 + 关照句模板池（seed 轮换） | 新 Swift 文件或 `PlaybackCopyPool` 扩展 | P0 |
| **SHARE-3** | `WeeklyShareCardPayload` 增加 `insight: ShareInsight` | `PlaybackService.swift` | P0 |
| **SHARE-4** | `WeeklyShareCardView` 改渲染 fact + care | `InsightWebView.swift` | P0 |
| **SHARE-5** | 删除/替换现有怪文案分支 | `WeeklyShareCardView` journalTitle/Body | P0 |
| **SHARE-6** | 2～3 个 fixture 走查文档或 Debug 预览 | 可选 JSON | P2 |

---

## 三、SHARE-1 · 信号检测（基于真实数据）

从 **当周 `HomeItem`（amount > 0）** 聚合，输出 `ShareInsightSignal`：

```swift
// 概念模型（实现可等价）
struct ShareInsightSignal: Equatable {
    enum Kind: Equatable {
        case brandTop(name: String, count: Int)      // 品牌/商户频次 TOP
        case categoryTop(name: String, count: Int) // 分类笔数 TOP
        case busiestDay(label: String, count: Int) // 最忙 weekday
        case lifeTitle(text: String)               // 极少数：高质量手改句
        case weakData(recordCount: Int)            // ≤2 笔或信号不足
    }
    let kind: Kind
    let recordCount: Int
    let activeDays: Int
}
```

### 3.1 优先级（高 → 低）

1. **brandTop**：同一 `merchantBrandId` 或 Lexicon/标题匹配到的 **具名品牌** ≥3 次，且为本周最高  
   - 展示名用 `MerchantBrandCatalog` 的 **品牌中文名**（如「便利蜂」），勿用 OCR 碎句  
2. **categoryTop**：无 brandTop 时，分类笔数 TOP 且 count ≥2（或占 week 笔数 ≥40%）  
   - 分类映射到 **生活语义**（餐饮→吃饭，交通→路上，健身/运动→锻炼）  
3. **busiestDay**：brand/category 都不明显，但某天 count ≥3  
4. **lifeTitle**：仅当 `EchoAnchorService.isEligibleLifeTraceTitle` **且** `userEditedTitle == true`  
5. **weakData**：recordCount ≤2 或无上述信号

### 3.2 禁止当作分享 hero 的数据

- 单条 OCR 小票原文（「便利蜂买饮料」）  
- 纯分类默认名 / generic title  
- 金额、占比 %、TOP1 环图 KPI  
- 播放旁白 `teaserLine` **照搬**（可作 fallback 素材，须过 humanize）

### 3.3 品牌 TOP 示例（便利蜂 fixture）

```text
输入：本周 5 笔，其中 5 笔 merchantBrandId = bianlifeng（或标题均匹配便利蜂）
输出 signal：brandTop(name: "便利蜂", count: 5)
```

---

## 四、SHARE-2 · 文案模板池

新增 `ShareInsightCopyPool`（或等价），输入 `signal + seed`，输出：

```swift
struct ShareInsight: Equatable {
    let fact: String    // 大字主句
    let care: String    // 副句关照
    let footnote: String // 如 "5 次 · 06.15–06.21"
}
```

### 4.1 模板变量

```text
{brandName} {categoryLabel} {count} {busiestDay} {recordCount}
```

### 4.2 brandTop 模板（warm / plain 各 2+，seed 轮换）

**便利蜂 / 便利店类：**

- 事实：`{brandName}去了 {count} 次，是这周最多的`  
- 关照：`工作再忙，也别忘了好好吃饭` / `顺路补给，也算照顾自己了`

**咖啡类（瑞幸等）：**

- 事实：`{brandName}买了 {count} 次，这周靠它提神`  
- 关照：`提神可以，别熬太晚` / `忙归忙，记得睡够`

**外卖类：**

- 事实：`外卖点了 {count} 次，是这周最多的`  
- 关照：`忙的时候靠外卖也正常` / `有空做顿热的，更好`

### 4.3 categoryTop 模板

| 分类语义 | 事实示例 | 关照示例 |
|----------|----------|----------|
| 餐饮 | 吃饭占了这周大头，记了 {count} 次 | 好好吃饭，也是在好好过 |
| 交通 | 路上记了 {count} 笔，总在移动 | 移动多的一周，记得歇一歇 |
| 健身/运动 | 锻炼记了 {count} 次，是这周最勤的事 | 练得努力，也要照顾好身体 |
| 娱乐 | 放松安排比较多，{count} 次 | 该玩就玩，别亏待自己 |
| 购物 | 随手买比计划买多，{count} 笔 | 买都买了，开心就好 |
| 兜底 | {categoryLabel} 出现得最多，{count} 次 | 这周就这样，先记下来 |

### 4.4 busiestDay 模板

- 事实：`{busiestDay}最忙，记了 {count} 笔`  
- 关照：`忙完那天，值得对自己好一点` / `把最满的一天留在这里`

### 4.5 lifeTitle 模式（降级，少数）

- 事实：直接用 `{lifeTitle}`（须过 Echo 门槛）  
- 关照：`是这周最想留下来的一句` / `这样的周，值得存一页`

### 4.6 weakData 模式

- 事实：`这周才记了 {recordCount} 笔，刚开头`  
- 关照：`多记几次，下次能讲更完整` / `已经开始看见自己了`

### 4.7 口吻与禁词（`COPY_GOVERNANCE`）

- **允许**：理解、关照、基于事实的轻建议（吃饭/休息/身体）  
- **禁止**：预算、少花、剁手、下月目标、占比%、¥ 大字、「账本」「附记」「先放在这里」

---

## 五、SHARE-4 · UI 呈现（对齐 D1.1 布局）

信息层级 **不变**，只换文案来源：

```text
[周记一页 / 本周摘页          日期范围]

【fact · 26pt bold · 2–3 行】     ← ShareInsight.fact
【care · 17pt medium · 1–2 行】   ← ShareInsight.care

[可选：极淡 7 日 rhythm 点]

footnote：{recordCount} 次 · 这一周
页脚：叙账 · 基于你这周的真实记录
```

### 必删（当前代码中的怪文案）

| 删除 | 替换 |
|------|------|
| `这周记下了这一笔` | `ShareInsight.fact` |
| `账本里写着「…」` | 不用 |
| `这一周先放在这里` | `ShareInsight.care` |
| `附记：N 笔记录` | `N 次 · 这一周` |
| `来自 叙账 · 一笔一笔，回头再看` | `叙账 · 基于你这周的真实记录`（或等价） |

**全卡仍禁止**：¥ 总额大字、占比环图、三格 KPI。

---

## 六、数据流

```text
HomeItem[] (本周)
    → ShareInsightSignal 检测（SHARE-1）
    → ShareInsightCopyPool（SHARE-2）
    → WeeklyShareCardPayload.insight
    → WeeklyShareCardView 渲染
```

**两入口同源**：

- `SummaryPlaybackSheet.shareWeeklyStoryCard()`  
- `InsightWebView` AI Tab 周度分享卡  

均走 `buildWeeklyShareCardPayload`；禁止 View 内再写第二套 hero 逻辑。

---

## 七、scope guard

- 不改 `SummaryPlaybackQuotaStore`、StoreKit  
- 不重做 D1.1 布局尺寸 / snapshot  
- 不改 `web-preview`  
- 不大改 B2.5 播放幕（可共享聚合函数，不共用 hero 文案）  
- 不调用远程 AI 生成分享句（本地模板即可）

---

## 八、验收

### 8.1 产品三问

- [ ] 用户会说「对，这周确实是这样」——**有数据感**  
- [ ] 关照不反感（不像理财 App / 爸妈唠叨）  
- [ ] 愿意 **存相册**；至少一条 fixture 愿意 **发朋友圈**

### 8.2 Fixture 走查

| 场景 | 预期 fact（含） | 禁止 |
|------|-----------------|------|
| 便利蜂 5 笔 / 5 次 | 「便利蜂」「5 次」「最多」 | 「便利蜂买饮料」作大字 |
| 健身 4 笔 TOP | 「锻炼」「4 次」 | 空泛「没什么大事」 |
| 2 笔 weak | 「刚开头」 | 硬编品牌 TOP |
| 全 generic title | categoryTop 或 busiestDay | OCR 碎句 |

### 8.3 技术

- [ ] 播完保存 + AI Tab 导出 **同一 insight**  
- [ ] `copy_lint` 无新增禁词  
- [ ] 390×580 snapshot 正常

---

## 九、@ 文件

```text
@PROMPT_功能-D1.2_周分享图数据总结-iOS.md
@PROMPT_功能-D1.1_周分享海报叙事化-iOS.md
@PRODUCT_NORTH_STAR.md
@COPY_GOVERNANCE_PLAN_v0.1.md
@NativeDemoApp/Views/InsightWebView.swift
@NativeDemoApp/Services/PlaybackService.swift
@NativeDemoApp/Services/MerchantBrandCatalog.swift
@NativeDemoApp/Services/EchoAnchorService.swift
@NativeDemoApp/Views/SummaryPlaybackSheet.swift
```

---

## 十、复制发送

```text
请阅读并执行：@PROMPT_功能-D1.2_周分享图数据总结-iOS.md

背景：周分享图要说人话、用户愿意分享。方向是「基于真实数据总结 + 一句关照」，不是小票句放大、不是空煽情、不是账本解说。

请按 SHARE-1～SHARE-5 实现：信号聚合 → ShareInsightCopyPool → payload.insight → WeeklyShareCardView 渲染 fact+care。删除「这周记下了这一笔」「账本里写着」「附记」等怪文案。

优先级 P0。遵守 scope guard，不改 web-preview、不动次数/StoreKit。

完成后输出：
1. 改了哪些文件
2. §8.2 四条 fixture 走查结果
3. 刻意未做项

约束：仅 iOS；最小 diff；不提交除非我要求；中文 commit message。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-15 | 首版：创始人「数据总结+关照」思路 → D1.2 prompt |
