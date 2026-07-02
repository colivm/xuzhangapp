# Agent Prompt · Task B2.12 — 情绪标签 polish（7 分类 · 仅 iOS）

> **状态：待做**  
> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。  
> **格式**：「复制发送」为单一 ` ```text ` 块，块内**不要**再嵌套 ` ``` `，否则复制会截断。

---

## 任务编号对照

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| **B2.12** | **情绪标签 polish**（本 prompt） | `HomeItem.inferEmotionTag` | ✅ 已完成 |
| **B2.11** | 心意往来包 | 见 [`PROMPT_功能-B2.11_心意往来场景包-iOS.md`](PROMPT_功能-B2.11_心意往来场景包-iOS.md) | ✅ 已完成 |

**展示位置**：首页今日列表、回放 Sheet 条目副行（`emotionTag` 字段，随分类/金额自动推断）。

---

## @ 文件（Agent 必须先 Read）

```text
@PROMPT_功能-B2.12_情绪标签polish-iOS.md
@CATEGORY_SCENE_COPY_AUDIT_v0.1.md
@PRODUCT_NORTH_STAR.md
@NativeDemoApp/Models/HomeItem.swift
@NativeDemoApp/Views/HomeView.swift
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task B2.12 — 情绪标签 polish**（仅 iOS；**不改 web-preview**）。

## 背景
`HomeItem.inferEmotionTag(category:amount:)` 为每笔账自动赋 **情绪标签**，展示在列表/回放中。
标签气质 = 「这笔生活在发生什么」，不是「这笔花得值不值」。

## 黄金参照 — 以下三分类 **禁止修改**（产品已认可）

Read 现码，这三档为 polish 母版，其它 7 类向其对齐：

| 分类 | amount 低档 | amount 高档 | 阈值 |
|------|-------------|-------------|------|
| **健康** `.health` | 健康小照顾 | 认真照顾自己 | 100 |
| **居家** `.home` | 居家小补给 | 把家安顿好 | 300 |
| **人情** `.social` | 人情小记 | 心意往来 | 100 |

## 必改 — 以下 7 分类各 2 档标签（共 14 字符串）

只改 `HomeItem.inferEmotionTag` 内 switch 的 **dining / transport / shopping / daily / entertainment / lodging / other** 分支。
**不要**改 `.health` / `.home` / `.social` 分支。
阈值（amount 比较界点）**可微调 ±20%** 若新标签语义需要；改动须在交付说明理由。

### 现稿 vs 问题（Agent 须解决）

| 分类 | 现低档 | 现高档 | 问题 |
|------|--------|--------|------|
| 餐饮 `.dining` | 日常补给 | 小确幸时刻 | 「日常补给」与购物低档重复；可更「一口饭」生活感 |
| 交通 `.transport` | 日常通勤 | **远途奔波** | 「奔波」偏疲累/打工 KPI；应对齐 health 的温柔 |
| 购物 `.shopping` | **生活补给** | 给自己加点好心情 | 低档与餐饮重复；高档 OK |
| 日用 `.daily` | 细水长流 | 用心生活 | 整体 OK，可略 polish 防与其他类撞词 |
| 娱乐 `.entertainment` | 忙里偷闲 | 难得放松 | 整体 OK |
| 住宿 `.lodging` | 短暂停留 | 旅途休憩 | 整体 OK，可更「停下来」叙事 |
| 其他 `.other` | 日常碎片 | 特别时刻 | 整体 OK |

### 写作规则（与 health/home/social 同标准）

1. **4～8 字** 为主，最长 **10 字**（列表副行展示）
2. **温柔、无评判**：禁止 乱花、浪费、超支、剁手、冲动、奢侈、没必要、控一控
3. **无会计词**：禁止 支出、开销、成本、预算、科目
4. **无 KPI 感**：禁止 偏多、超标、奔波赶、打工人（交通类尤其）
5. **描述生活气质**，不描述金额对错
6. 同一标签 **不要** 在 7 类中重复出现（现「生活补给」撞词须消掉）
7. 高档标签 = 同分类下「更值得记一笔」的生活时刻，不是「花得更多所以要反省」

### 建议方向（非强制逐字，须过规则自检）

| 分类 | 低档方向 | 高档方向 |
|------|----------|----------|
| 餐饮 | 日常一口 / 暖胃时刻 | 小确幸时刻（可保留） |
| 交通 | 日常出行 / 顺路一段 | 路途中 / 去远一点 |
| 购物 | 顺手添置 / 小物入袋 | 给自己加点好心情（可保留） |
| 日用 | 细水长流（可保留） | 用心生活（可保留） |
| 娱乐 | 忙里偷闲（可保留） | 难得放松（可保留） |
| 住宿 | 短暂停留（可保留） | 旅途休憩（可保留） |
| 其他 | 日常碎片（可保留） | 特别时刻（可保留） |

Agent 定稿后输出 **完整 7×2 对照表**（旧 → 新）。

## 实现约束

- **只改** `NativeDemoApp/Models/HomeItem.swift` 的 `inferEmotionTag`
- 不改 `emotionTag` 字段结构、不改 Codable、不改 UI
- 已有账单 **不会** 自动回溯；仅新记/改分类/改金额时重算（现有 HomeViewModel 逻辑已如此）
- **不**在本任务扩成 3～4 条池 + hash（v0.2）；仍保持每分类 2 档

## 禁止

- 修改 health / home / social 三分类标签或阈值
- 改 ScenePackCopyPool、B2.11 social 包、CategoryRecommendService
- 改 web-preview
- git commit 除非用户明确要求

## 验收

- [ ] grep inferEmotionTag：**无** 奔波、乱花、浪费、超支、支出、开销
- [ ] 7 类 14 个标签 **互不重复**
- [ ] 与 health「健康小照顾 / 认真照顾自己」并排读，气质同一套
- [ ] 餐饮 ¥15 → 低档；餐饮 ¥50 → 高档（阈值合理）
- [ ] 交通高档 **无** 「奔波」
- [ ] 模拟器记一笔购物 + 餐饮，emotionTag 不同且均非评判语气

## 交付

1. 改动文件列表
2. **14 行对照表**：分类 | 阈值 | 旧低档→新低档 | 旧高档→新高档
3. 未改动的 health/home/social 三档确认
4. 验收勾选

最小 diff；先 Read 现 inferEmotionTag 与 HomeView 展示再改。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-07 | 首版：Task B2.12 七分类情绪标签 polish |
| 2026-06-07 | 状态更新：七分类标签已落地，health/home/social 保持母版 |
