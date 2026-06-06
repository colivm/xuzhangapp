# Agent Prompt · Task B2.11 — 心意往来包（人情分类 · 仅 iOS）

> **状态：待做**  
> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。  
> **格式**：「复制发送」为单一 ` ```text ` 块，块内**不要**再嵌套 ` ``` `，否则复制会截断。

---

## 任务编号对照

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| **B2.11** | **心意往来包**（本 prompt） | `ScenePackCopyPool` + `RecordView` + `HomeViewModel` | ⏳ 本任务 |
| B2.10 | 场景备注池 128 条 | 四包基础 | ✅ |
| care / home | 照顾自己 / 居家安顿 | 已上线 | ✅ 气质母版 |

**依据**：[`CATEGORY_SCENE_COPY_AUDIT_v0.1.md`](CATEGORY_SCENE_COPY_AUDIT_v0.1.md) §8.1

---

## @ 文件（Agent 必须先 Read）

```text
@AGENT_PROMPT_B2.11_SOCIAL_SCENE_PACK.md
@CATEGORY_SCENE_COPY_AUDIT_v0.1.md
@PRODUCT_NORTH_STAR.md
@SCENE_PACK_COPY_POOL_v0.2.md
@NativeDemoApp/Services/ScenePackCopyPool.swift
@NativeDemoApp/Views/RecordView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Models/HomeItem.swift
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task B2.11 — 心意往来包**（人情分类场景备注；**仅 iOS**）。

## 背景（北极星）
叙账卖的是「生活被看见」，不是报表/礼账。人情类 copy 容易尴尬；「红包 / 随礼 / 份子 / 家人开销 / 人情债」敏感且偏账本。
当前 **P0 bug**：`RecordView.guessScenePackId` 把 `.social`（人情）映射到 `food` 吃货包 → 一键备注出餐饮句，与分类语义打架。

## 气质母版（须对齐，Read care/home 包）
- `ScenePackCopyPool` 中 **照顾自己包 `care`**、**居家安顿包 `home`**
- 周记式、8～18 字为主、最长不超过 24 字
- 记「这一刻的关系」，不记礼数 KPI

## 必做 — 1. 新增场景包 `social`

在 `ScenePackCopyPool.definitions` 增加（插入顺序建议：home 之后、travel 之前）：

- id: **social**
- emoji: **🎁**
- label: **心意往来包**
- desc: **关系里的一小句记录**（禁止「比如输入 ¥」）
- category: **`.social`**（HomeItem.Category.social = 人情）
- tiers: **4 档 × 每档 8 条 = 32 条**（与 commute/food/care 同结构）

### 金额档（定稿）

| 档 | maxAmount | 气质 |
|----|-----------|------|
| A | 30 | 顺路小小心意、咖啡叙旧、轻量伴手 |
| B | 100 | 请一顿、聚会分摊、节日小礼、同事小聚 |
| C | 300 | 探望、家庭聚餐、值得记下的场合 |
| D | 9999 | 长途探望、重要仪式 **只写场景不写礼数/金额** |

### 32 条文案 — 你必须撰写（勿从 food/travel 复制）

写作原则：
- ✅ 探望、聚会、带份心意、叙旧、记挂、团圆、给家人的小物
- ❌ 红包、随礼、份子钱、礼金、还人情、欠人情、社交支出、家人开销、人情债、该请、该还
- ❌ 预算、摊销、投资、核心支出、乱花、剁手、超支
- 验收问句：**用户愿不愿让熟人看见这条备注？** 会羞耻 → 重写

每条备注写完后自检；档内 8 句勿高度重复。

## 必做 — 2. 修复映射 `RecordView.guessScenePackId`

在 `categoryToPackId` 中：
- **`.social: "social"`**（替换现有 `.social: "food"`）
- 确认 `visibleScenePacks` / definitions 含 `social` 包

金额 fallback 链 **不要** 把人情导向 food；无映射时 fallback 逻辑保持不变即可（人情已有映射）。

## 必做 — 3. 人情 chips `HomeViewModel.noteSuggestions`

替换 `.social` 三条（禁止红包/家人开销）：

建议方向（可微调用词，须过禁止词表）：
- 「带份小小心意」
- 「聚会叙旧」
- 「探望记挂」

## 必做 — 4. 展开列表

`ScenePackSectionView` 经 `RecordView.scenePackDesc` 读 `pack.desc` — 确保 social 包 desc 为 **关系里的一小句记录**。

## 禁止

- 改 web-preview
- 改 health/home/care 已有 tiers
- 改 emotionTag（属 Task B2.12）
- 改 B2.8 分类推荐、D1.1 分享图、StoreKit
- git commit 除非用户明确要求

## 验收

- [ ] 手选 **人情** + 一键生成备注 → 来自 **social** 包，**无** 餐饮/午餐/奶茶句
- [ ] 展开列表可见 **🎁 心意往来包** + tagline
- [ ] 32 条 grep：**无** 红包、随礼、份子、礼金、人情债、家人开销、社交支出
- [ ] 随机抽 10 条 → 3 秒测试均为「生活句」
- [ ] care/home/food/commute 行为不变
- [ ] chips 三条无敏感账本词

## 交付

1. 改动文件列表
2. social 包 32 条全文（表格：档 | ID | 备注）
3. 验收勾选
4. 未做项：SCENE_PACK_COPY_POOL_v0.2.md 文档同步（可选，若改须增 §social）

最小 diff；先 Read care/home 包再写 social。
```

---

## 与 B2.12 合并发送（可选）

若同 PR 做 **情绪标签 polish**，先粘贴 [`AGENT_PROMPT_B2.12_EMOTION_TAGS.md`](AGENT_PROMPT_B2.12_EMOTION_TAGS.md)「复制发送」，再粘贴本文件「复制发送」，末尾加：

```text
同一 PR：B2.11 只做 social 包+映射+chips；B2.12 只改 inferEmotionTag 七分类，勿动 health/home/social 三档。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-07 | 首版：Task B2.11 心意往来包 |
