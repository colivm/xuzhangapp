# Agent Prompt · Task A4 — 场景包哲学对齐（iOS）

> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。  
> 与 **Task A3**（小 AI 说去预算化）并行不冲突：A3 不动场景包，A4 不动小 AI 说。

> **与 B2.10 的区别**：**A4** = 包名/tagline/5 条替词（哲学收束，小 diff）。**B2.10** = 四包×4档×8 条池 + stable hash + 历史增强（`ScenePackCopyPool` 主体结构）。你若已跑 B2.10，**不要**用 A4 prompt 再跑一遍；下一项应是 **B2.8**（[`AGENT_PROMPT_B2.8_SMART_CATEGORY.md`](AGENT_PROMPT_B2.8_SMART_CATEGORY.md)）。

---

## @ 文件

```text
@AGENT_PROMPT_SCENE_PACK_PHILOSOPHY.md
@SCENE_PACK_COPY_POOL_v0.2.md
@PRODUCT_NORTH_STAR.md
@NativeDemoApp/Services/ScenePackCopyPool.swift
@NativeDemoApp/Views/RecordView.swift
```

---

## 复制发送

```text
你在 xuzhangapp 实现 **Task A4 — 场景包哲学对齐（仅 iOS）**。

## 背景
叙账哲学：「理解而非审判 · 先叙后议」。场景备注包是 **记一笔时的生活化备注**（省力记），不是预算教练。
产品定稿见 **SCENE_PACK_COPY_POOL_v0.2.md §10**（必须先 Read）。

## 范围（严格）
**只改 iOS**：
- `NativeDemoApp/Services/ScenePackCopyPool.swift`

**可先 Read、不要改**：
- `NativeDemoApp/Views/RecordView.swift`（UI 经 `scenePackDesc` 读 `pack.desc`）

**禁止改**：
- `web-preview/**`
- 小 AI 说 / HomeViewModel insight（Task A3）
- 场景包 id、金额档、`note()` 选取算法
- git commit 除非用户明确要求

## 必做 — §10.2 包名

| id | 旧 label | 新 label |
|----|----------|----------|
| `travel` | 旅行预算包 | **旅行出发包** |

## 必做 — §10.3 备注替词（5 条，逐字一致）

commute: `共享单车月卡摊销`→**共享单车月卡里的一天**；`为准时到达的小投资`→**为一程准时到达**
travel: `一晚经济型住宿摊销`→**经济型住宿这一晚**；`两晚住宿预算`→**途中连住两晚**；`旅行套餐核心支出`→**行程里的重头戏**

仅改 tiers 内对应字符串；其它备注不动。

## 必做 — §10.4 四包 desc tagline（逐字一致）

| id | 新 desc |
|----|---------|
| commute | **把通勤记成日常一句** |
| food | **吃喝里的一小句生活** |
| travel | **路上的花费，也值得记下** |
| pet | **{petName} 相关的小开销** |

禁止「比如」「输入 ¥」「自动备注」。

## 自检 grep（NativeDemoApp / ScenePackCopyPool.swift 不应出现）
旅行预算包、两晚住宿预算、月卡摊销、小投资、住宿摊销、核心支出、比如：输入、自动备注

## 验收
- [ ] travel label = 旅行出发包
- [ ] 四包 desc = §10.4 tagline
- [ ] §10.3 五条备注已替换
- [ ] food/pet 的 tiers 备注未误改
- [ ] 未改 web-preview

## 交付
改动文件列表、验收勾选、未做项、travel D 档 notes 数组 spot-check

最小 diff；先 Read §10 再改。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-06 | 首版：Task A4 · iOS only |
| 2026-06-06 | 增补 §10.4 四包 desc tagline |
