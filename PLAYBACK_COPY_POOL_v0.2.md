# 叙账 · 生活切片旁白文案池 v0.2

> 用途：供 `PlaybackService` / 后续 `PlaybackCopyPool` 接入；**本文档仅文案，不含代码**。  
> 依据：[`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md) §5.8、[`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) 对外表达原则。  
> 更新时间：2026-06-04

---

## 1. 使用说明

### 1.1 变量（实现时替换）

| 变量 | 含义 | 示例 |
|------|------|------|
| `{petName}` | 宠物昵称（设置页；默认「小窝」） | 小窝 |
| `{rangeLabel}` | 周：M月d日-M月d日；月：M月 | 6月1日-6月7日 |
| `{count}` | 笔数 | 3 |
| `{total}` | 总金额（已格式化） | ¥83 |
| `{busiestDay}` | 支出最集中日 | 6月3日 星期三 |
| `{quietestDay}` | 支出最轻日 | 6月5日 星期五 |
| `{topCategory}` | TOP1 分类 | 餐饮 |
| `{ratio}` | TOP1 占比整数 | 89 |
| `{highlightTitle}` | 高光备注/标题 | 晨间咖啡唤醒日常 |
| `{highlightAmount}` | 高光金额 | ¥66 |
| `{highlightDayLabel}` | 高光日期 | 6月3日 星期三 |
| `{activeDays}` | 月：有记录天数 | 12 |
| `{momPercent}` | 较上月（有数据时） | +8% / -5% |
| `{changeHint}` | 月变化点（系统生成事实句） | 见 §4.6 |

### 1.2 选取规则（建议，实现时参考）

```text
templateIndex = hash(weekKey + chapterId) % poolSize
```

- **同一自然周、同一幕**：多次播放选同一句（稳定）。  
- **换周**：自动换句式，降低重复感。  
- **弱数据**（周 ≤2 笔）：走 §3 弱数据池，不播节奏/高光幕。  
- **条件分支**：先判 `count` / `ratio` / `hasRichHighlight`，再进对应子池。  
- **warm / plain**：与宠物开关联动；关宠物全程 `plain`。

### 1.3 禁止词（全池遵守）

勿用：超支、浪费、应该省钱、占比过高、乱花钱、克制、理性消费、最忙（改用「花得最多的一天/最热闹」）、几乎没花钱（改用「几乎没记笔/很轻」）、认真记录生活（改「记下了/有了轮廓」）。

---

## 2. 周切片 · 标准 5 幕（≥3 笔）

### 2.1 第 1 幕 · 开场（`week-intro`）

**warm ×4**

| ID | 模板 |
|----|------|
| W1-A | 这一周，你留下了 {count} 笔小痕迹，合计 {total}。 |
| W1-B | {petName}收拢了这一周：{count} 笔，{total}。 |
| W1-C | 先把 {rangeLabel} 拢在一起——{count} 笔，{total}，从这里叙起。 |
| W1-D | {count} 笔小记录，{total}；这一周的故事，开始讲了。 |

**plain ×4**

| ID | 模板 |
|----|------|
| W1-P-A | {rangeLabel}：{count} 笔，支出 {total}。 |
| W1-P-B | 本周 {count} 笔，合计 {total}。 |
| W1-P-C | {count} 笔 · {total}（{rangeLabel}）。 |
| W1-P-D | 周期内 {count} 笔记录，总支出 {total}。 |

**条件 · 笔数偏多（count ≥ 10）warm 追加 ×2**

| ID | 模板 |
|----|------|
| W1-H-A | 这一周记得很满，{count} 笔加起来 {total}。 |
| W1-H-B | {petName}翻完这一叠：{count} 笔，{total}，脉络很清楚。 |

---

### 2.2 第 2 幕 · 节奏（`week-rhythm`，≥3 笔才播）

**warm ×4**

| ID | 模板 |
|----|------|
| W2-A | {busiestDay} 最热闹；{quietestDay} 几乎没记笔，这一周一紧一松。 |
| W2-B | 支出集中在 {busiestDay}，{quietestDay} 则很轻——节奏分得开。 |
| W2-C | {busiestDay} 花得最多；另一天 {quietestDay} 几乎空白，像刻意留白。 |
| W2-D | 若把这一周拉成曲线：{busiestDay} 是峰，{quietestDay} 是谷。 |

**plain ×4**

| ID | 模板 |
|----|------|
| W2-P-A | 支出高峰：{busiestDay}；最低：{quietestDay}。 |
| W2-P-B | {busiestDay} 笔数/金额最高，{quietestDay} 最低。 |
| W2-P-C | 集中日 {busiestDay}，轻量日 {quietestDay}。 |
| W2-P-D | 本周波动：{busiestDay} → {quietestDay}。 |

---

### 2.3 第 3 幕 · 生活配方（`week-top-category`）

**通用 warm ×4**

| ID | 模板 |
|----|------|
| W3-A | 「{topCategory}」占了这周的多数，约 {ratio}%。 |
| W3-B | 大约 {ratio}% 在「{topCategory}」——这周的生活配方，它站 C 位。 |
| W3-C | 翻遍这一周，「{topCategory}」出现最勤，约 {ratio}%。 |
| W3-D | {ratio}% 落在「{topCategory}」上，像这一周的底色。 |

**通用 plain ×4**

| ID | 模板 |
|----|------|
| W3-P-A | 「{topCategory}」约占 {ratio}%。 |
| W3-P-B | TOP1：{topCategory}（{ratio}%）。 |
| W3-P-C | {topCategory}：{ratio}% 占比。 |
| W3-P-D | 最高分类 {topCategory}，{ratio}%。 |

**条件 · 占比极高（ratio ≥ 70%）warm ×2**

| ID | 模板 |
|----|------|
| W3-S-A | 这一周几乎围着「{topCategory}」转，约 {ratio}%。 |
| W3-S-B | 「{topCategory}」一口气占到 {ratio}%，其他分类都是点缀。 |

**条件 · 占比分散（ratio ≤ 40%）warm ×2**

| ID | 模板 |
|----|------|
| W3-D-A | 「{topCategory}」略领先，约 {ratio}%，整体花得比较分散。 |
| W3-D-B | 没有一家独大：「{topCategory}」约 {ratio}%，其余分类穿插其间。 |

**分类轻量变体（可选，与通用句二选一；warm）**

| 分类 | 模板 |
|------|------|
| 餐饮 | 味蕾这周很活跃——「餐饮」约 {ratio}%，是日常的主轴。 |
| 交通 | 通勤与出行撑起了这一周，「交通」约 {ratio}%。 |
| 购物 | 购物占约 {ratio}%，像给生活添了几样新物件。 |
| 娱乐 | 娱乐约 {ratio}%，这一周留出了玩耍的空档。 |
| 日用 | 日用琐碎约 {ratio}%，是小日子里的底色。 |
| 住宿 | 住宿约 {ratio}%，多半是在路上或换了个落脚处。 |
| 其他 | 「其他」约 {ratio}%，一些不好归类的小支出。 |

---

### 2.4 第 4 幕 · 本周高光（`week-highlight`，≥3 笔且有高光）

旁白**只讲故事**；日期、金额放 UI 页脚，勿在 warm 里重复。

**warm ×4（有丰富备注时优先）**

| ID | 模板 |
|----|------|
| W4-A | {highlightDayLabel}，你为自己留了这样一笔：「{highlightTitle}」。 |
| W4-B | 若选本周一笔来代表心情，{petName}会投给「{highlightTitle}」。 |
| W4-C | {highlightDayLabel} 这一笔最有画面感——「{highlightTitle}」。 |
| W4-D | 本周的高光落在 {highlightDayLabel}：「{highlightTitle}」。 |

**plain ×4**

| ID | 模板 |
|----|------|
| W4-P-A | 单笔代表：{highlightTitle}（{highlightDayLabel}，{highlightAmount}）。 |
| W4-P-B | 本周最高单笔：{highlightAmount}，{highlightTitle}。 |
| W4-P-C | 高光：{highlightTitle} · {highlightAmount}。 |
| W4-P-D | {highlightDayLabel}：{highlightTitle}，{highlightAmount}。 |

**无丰富备注、仅金额突出时 warm ×2**

| ID | 模板 |
|----|------|
| W4-F-A | {highlightDayLabel} 有一笔 {highlightAmount}，是本周最醒目的一跳。 |
| W4-F-B | 金额最高的一笔在 {highlightDayLabel}，{highlightAmount}。 |

---

### 2.5 第 5 幕 · 收尾（`week-outro`）

**warm ×4**

| ID | 模板 |
|----|------|
| W5-A | 这一遍先叙到这里。下周再记几天，{petName}准时来接新的一周。 |
| W5-B | 这一周的故事讲完了；下个自然周，再来叙新的一章。 |
| W5-C | 先收下这一遍回看。下周见，{petName}还在。 |
| W5-D | 周切片到这儿。下一周有了新记录，再来听新版。 |

**plain ×4**

| ID | 模板 |
|----|------|
| W5-P-A | 本周切片结束，下周可再看。 |
| W5-P-B | 周度回放完成。 |
| W5-P-C | 本周生活切片已播完。 |
| W5-P-D | 结束；下个自然周更新。 |

---

## 3. 周切片 · 弱数据（1～2 笔，3 幕）

不播节奏、高光；收尾用弱数据池。

**开场 warm ×3**

| ID | 模板 |
|----|------|
| WK1-A | 还只有 {count} 笔，但这一周已经有了开头。 |
| WK1-B | {count} 笔也是开始，{total}，{petName}先帮你留住。 |
| WK1-C | 记录还不多（{count} 笔），先把 {total} 收下来。 |

**开场 plain ×3**

| ID | 模板 |
|----|------|
| WK1-P-A | {count} 笔，{total}（数据较少）。 |
| WK1-P-B | 本周 {count} 笔记录。 |
| WK1-P-C | 记录偏少：{count} 笔。 |

**收尾 warm ×3**

| ID | 模板 |
|----|------|
| WK5-A | 再多记几笔，下一遍会更像你的这一周。 |
| WK5-B | {petName}等你把这一周记满，再来叙完整版。 |
| WK5-C | 补几笔日常，下次切片会更立体。 |

**收尾 plain ×3**

| ID | 模板 |
|----|------|
| WK5-P-A | 记录较少，补充后可生成更完整切片。 |
| WK5-P-B | 建议增加记录后再播放。 |
| WK5-P-C | 数据不足，完整 5 幕需 ≥3 笔。 |

---

## 4. 月章 · 6 章（标准）

### 4.1 第 1 章 · 总览（`month-intro`）

**warm ×4**

| ID | 模板 |
|----|------|
| M1-A | {rangeLabel}，{activeDays} 天有生活痕迹，{count} 笔，一共 {total}。 |
| M1-B | {petName}收下 {rangeLabel}：{count} 笔、{activeDays} 个记录日，合计 {total}。 |
| M1-C | 这个月你来了 {activeDays} 天，留下 {count} 笔，{total}。 |
| M1-D | 先把 {rangeLabel} 拢在一起——{activeDays} 天、{count} 笔、{total}。 |

**plain ×4**

| ID | 模板 |
|----|------|
| M1-P-A | {rangeLabel}：{count} 笔，{activeDays} 天，{total}。 |
| M1-P-B | 本月 {count} 笔 / {activeDays} 记录日 / {total}。 |
| M1-P-C | {activeDays} 天有账，合计 {total}。 |
| M1-P-D | 月总览：{count} 笔，{total}。 |

**有上月对比时 warm ×2（需 `{momPercent}`）**

| ID | 模板 |
|----|------|
| M1-M-A | {rangeLabel} 总支出 {total}，比上月 {momPercent}。 |
| M1-M-B | 和上月比，{total}（{momPercent}），{activeDays} 天有记录。 |

---

### 4.2 第 2 章 · 上旬（`month-early`）

**warm ×4**（变量：`{earlyCount}` `{earlyAmount}` 或由实现映射 segments[0]）

| ID | 模板 |
|----|------|
| M2-A | 上旬 {earlyCount} 笔，{earlyAmount}，像月初慢慢铺开的底色。 |
| M2-B | 月初这十天：{earlyCount} 笔、{earlyAmount}，节奏偏稳。 |
| M2-C | 上旬先落下 {earlyCount} 笔，合计 {earlyAmount}。 |
| M2-D | 前十天记了 {earlyCount} 笔，{earlyAmount}，为这个月定调。 |

**plain ×4**

| ID | 模板 |
|----|------|
| M2-P-A | 上旬 {earlyCount} 笔，{earlyAmount}。 |
| M2-P-B | 1-10 日：{earlyAmount}。 |
| M2-P-C | 上旬支出 {earlyAmount}。 |
| M2-P-D | 上旬 {earlyCount} 笔。 |

---

### 4.3 第 3 章 · 中下旬（`month-middle-late`）

**warm ×4**（`{midAmount}` `{lateAmount}` `{leadingSegment}`）

| ID | 模板 |
|----|------|
| M3-A | 中旬 {midAmount}，下旬 {lateAmount}；{leadingSegment}更热闹一点。 |
| M3-B | 月中的节奏在中下旬拉开：{leadingSegment}支出更集中。 |
| M3-C | 中旬 {midAmount}、下旬 {lateAmount}，{leadingSegment}是本月的小高峰。 |
| M3-D | 后半月比前半月更活跃，{leadingSegment}尤其明显。 |

**plain ×4**

| ID | 模板 |
|----|------|
| M3-P-A | 中旬 {midAmount}，下旬 {lateAmount}。 |
| M3-P-B | 中下旬对比：{midAmount} / {lateAmount}。 |
| M3-P-C | 最高旬段：{leadingSegment}。 |
| M3-P-D | 中 {midAmount} · 下 {lateAmount}。 |

---

### 4.4 第 4 章 · 生活构成（`month-composition`）

**warm ×4**

| ID | 模板 |
|----|------|
| M4-A | 「{topCategory}」约占 {ratio}%，是这个月最明显的一块拼图。 |
| M4-B | 翻遍 {rangeLabel}，「{topCategory}」站 C 位，约 {ratio}%。 |
| M4-C | 生活配方里，「{topCategory}」约 {ratio}%，仍是主角。 |
| M4-D | {ratio}% 落在「{topCategory}」——这一月的底色。 |

**plain ×4**

| ID | 模板 |
|----|------|
| M4-P-A | {topCategory}：{ratio}%。 |
| M4-P-B | 本月 TOP1 {topCategory}（{ratio}%）。 |
| M4-P-C | 最高分类 {topCategory}。 |
| M4-P-D | {topCategory} 占比 {ratio}%。 |

---

### 4.5 第 5 章 · 变化点（`month-change`）

本章以 **`{changeHint}` 事实句** 为主（系统生成）；以下为 **changeHint 生成句池**（实现时按数据选 1 条，非随机堆叠）：

| 条件 | changeHint 模板 |
|------|-----------------|
| 分类 ≥3 | 这个月出现了「{catA}」「{catB}」等 {n} 类生活记录。 |
| 分类 =2 | 「{catA}」和「{catB}」交替出现，种类不多但轮廓清楚。 |
| 分类 =1 | 几乎都在「{catA}」里打转，主题很集中。 |
| 连续记录 ≥5 天 | 连续 {streakDays} 天有记录，像养成了一小段习惯。 |
| 跨度长 | 记录从 {firstDate} 延续到 {lastDate}，跨度 {spanDays} 天。 |
| 兜底 | 这个月已经留下了可以回看的生活痕迹。 |

**包裹句 warm ×3**（`{changeHint}` 作正文或前缀）

| ID | 模板 |
|----|------|
| M5-A | {changeHint} |
| M5-B | 若说这个月的一个变化：{changeHint} |
| M5-C | {petName}注意到：{changeHint} |

---

### 4.6 第 6 章 · 月末小结（`month-action`）

**warm ×4**

| ID | 模板 |
|----|------|
| M6-A | 这个月的节奏已经有轮廓了，想再聊细一点，可以打开月度复盘。 |
| M6-B | 生活章先叙到这里。下个月的新记录，会生成新的一章。 |
| M6-C | {petName}把 {rangeLabel} 收好；下次再来听新版。 |
| M6-D | 这一章讲完了——下个月见。 |

**plain ×4**

| ID | 模板 |
|----|------|
| M6-P-A | 本月生活章已生成。 |
| M6-P-B | 月章播放结束。 |
| M6-P-C | 可继续查看月度复盘。 |
| M6-P-D | 本月切片完成。 |

---

## 5. 顶栏 / 卡片 teaser（可选，非幕内旁白）

用于播放页副标题或看看花卡片一行摘要：

| ID | 模板 |
|----|------|
| T-A | {busiestDayShort} 支出最多 · {topCategory} 约 {ratio}% |
| T-B | 这一周，{topCategory} 是主角 |
| T-C | {count} 笔 · {total} · {topCategory} 为主 |
| T-D | {rangeLabel} · 约半分钟讲完 |

---

## 6. 池子规模汇总

| 范围 | warm | plain | 条件/分类追加 | 合计约 |
|------|------|-------|---------------|--------|
| 周 · 标准 5 幕 | 20+ | 20 | 分类 7 + 条件 8 | **~55 条** |
| 周 · 弱数据 | 6 | 6 | — | **12 条** |
| 月 · 6 章 | 22+ | 20 | changeHint 6 | **~48 条** |
| teaser | 4 | — | — | **4 条** |

同一用户每周换 `weekKey` 即可轮换；**约 8～12 周**才需重复同一句式（配合数据变化，体感重复显著降低）。

---

## 7. 能否接 AI？实现复杂吗？

### 7.1 结论（建议）

| 方案 | 能否接 AI | 复杂度 | 建议 |
|------|-----------|--------|------|
| **A. 纯本地池（本文档）** | 否 | ★☆☆ | **v0.2 首选**；离线、快、可审、可测 |
| **B. AI 离线扩池** | 半自动 | ★★☆ | 用 AI **批量生成**候选句 → 人工删禁词 → 写入池；不上线推理 |
| **C. AI 只写 1～2 句** | 是 | ★★★ | 每用户每周 AI 生成「变化点/高光 embellish」，**本地模板包其余幕** |
| **D. 全幕 AI 实时旁白** | 是 | ★★★★ | 不推荐作 v0.2 默认；成本、延迟、一致性、审核风险高 |

**可以接 AI，但不建议用 AI 替代整个池**；最佳是 **本地池兜底 + AI 可选增强 1 句**。

### 7.2 方案 C 参考架构（中等复杂度）

```text
用户播周切片
  → 本地模板选 4 幕（hash weekKey）
  → 若已登录 + 远程 AI 开 + 网络 OK：
       POST 聚合 JSON（笔数/分类/高光/节奏，无原始账单明细可选）
       → 返回 { "highlightLine": "...", "changeLine": "..." } 各 ≤40 字
       → 替换第 4 幕 warm 或第 5 幕一句
  → 失败：100% 本地池（用户无感）
```

**需要**：Prompt 禁词表、字数上限、缓存 `userId+weekKey`、超时 3～5s、会员/次数策略。  
**工作量**：backend 或 ai-proxy 1 个 endpoint + iOS 缓存键 + fallback，约 **2～4 人日**（不含 Prompt 调优）。

### 7.3 方案 D 为何不推荐默认开

- 切片卖点是 **本地、快、可离线**；等 AI 才能播违背产品承诺。  
- 同周重播 **AI 非确定性**，与「稳定 hash 轮换」冲突。  
- App Store 审核、弱网、未登录用户都要同一体验。  
- Token 成本 × 每周每用户 × 5 幕，长期高于维护静态池。

### 7.4 AI 扩池工作流（方案 B，最低风险）

1. 把 §2～§4 模板 + 变量说明喂给 AI。  
2. 要求：每幕再生成 10 条 warm / 5 条 plain，输出 JSON。  
3. 人工过一遍禁词与长度（幕内 ≤ 45 字为宜）。  
4. 合并进本文档或 JSON 资源，**仍走本地 hash 轮换**。

无需改播放架构，**复杂度 ★★☆**，适合你们现在「代码暂不改、先备弹药」的阶段。

---

## 8. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-04 | v0.2 首版：周/月全池、弱数据、条件分支、分类变体、AI 接入评估 |
