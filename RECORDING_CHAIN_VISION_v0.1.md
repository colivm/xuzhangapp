# 叙账 · 记账链路愿景 v0.1

> 更新时间：2026-06-08  
> 状态：定稿（战略层；实现见 F1.3 / B2.13 Agent prompt）  
> 读者：产品、文案、开发

---

## 0. 一句话

**缩短记账链路、叙事自动长出来。**

用户 ideally **只输入金额**（或 OCR 一张图）；分类、备注、情绪标签在 **高置信** 下自动填好，且语气像「懂我的生活」，不像模板报表。

---

## 1. 与北极星的关系

| 北极星 | 记账链路愿景 |
|--------|----------------|
| 账是素材、叙是目的 | 记得越省力，「可叙之材」越常更新 |
| 先叙后议 · 理解而非审判 | 自动填的是 **生活句**，不是审计标签 |
| 文案与 UI 并列重要 | 品牌池 / 习惯预填的核心产出是 **叙事文案** |

记账 Tab 不是「填表终点」，而是 **把生活片段送进账本的最短路径**；列表上的情绪胶囊、备注，已经是微型「叙」。

**记账页 UI 北极星**（[`RECORD_PAGE_DESIGN_v0.1.md`](RECORD_PAGE_DESIGN_v0.1.md)）：

> **把一段生活放进账本，不是填写金额表单。**

---

## 2. 终态体验（分阶段，非 Day 1）

```text
输入层          推断层                    输出（用户一眼可改）
────────        ──────                    ────────────────────
金额            ┐
OCR 截图    ──→ │ 信号 cascade  →  分类 + 备注(title) + 情绪(emotionTag)
（可选）        │                  + 可选 merchantBrandId
                ┘
```

**用户感受**：「我打了个 9.9，它已经像我会写的那样记好了。」

---

## 3. 双引擎（缺一不可）

### 3.1 强信号 · 品牌叙事池（F1.3）

**何时用**：OCR / 备注 / 账单文字 **明确识别出品牌**（高置信）。

- 专用 **品牌调性文案池**（每个品牌独立 tier + 时段，禁止广告腔）
- 分类、title、emotionTag 走品牌 catalog
- 识别不到品牌 → **不硬贴**，交给习惯引擎或通用池

详见 [`AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md`](AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md)

### 3.2 弱信号 · 个人习惯预填（B2.13）

**何时用**：无品牌强信号；用户已有 **足够本地存量**（约 20～50 笔起渐准）。

- 从 **本机账本** 学：时段 × 工作日/周末 × 金额档 × 近期会话
- **个人先验为主**，人口学规则仅冷启动兜底
- 置信度低 → 只预填分类，或只高亮推荐 chip，不全填

详见 [`AGENT_PROMPT_B2.13_HABIT_PREFILL.md`](AGENT_PROMPT_B2.13_HABIT_PREFILL.md)

### 3.3 统一 cascade

```text
① 品牌识别（F1.3）     confidence ≥ 阈值
        ↓ 否
② 个人习惯（B2.13）    confidence ≥ 阈值
        ↓ 否
③ 场景包 / 分类通用池   ScenePackCopyPool + inferEmotionTag 升级路径
        ↓
④ 用户手改 → 写回习惯模型（纠正即学习）
```

---

## 4. 实施顺序（建议）

| 顺序 | 任务 | 原因 |
|------|------|------|
| 1 | **F1.2** OCR 回归 | 数据正确优先 |
| 2 | **F1.3** 品牌词典 + 叙事池 + `NarrativeCopyResolver` | 有 OCR 即可验证强信号 |
| 3 | **B2.13** 习惯预填 A 阶段（分类 + 备注） | 手动只输金额的主路径 |
| 4 | B2.13 B 阶段（情绪接 resolver）+ 纠正学习 | 依赖 resolver 已存在 |
| 5 | F1.3 二期 Logo 素材库（可选） | 纯 icon 无文字 case |

F1.3 与 B2.13 **可分两 PR**；须 **共用** `NarrativeCopyResolver`，避免两套 emotion 逻辑。

---

## 5. 产品 guardrails

1. **预填 ≠ 静默入账** — 高置信可默认填好，保存前可改；叙账不是审计工具，但用户仍感到掌控。
2. **错一次比空着更伤** — 置信度不足时宁可少填，不可乱填品牌/习惯话术。
3. **理解感，非监控感** — 禁止「检测到您周末频繁小额消费」类报表腔；只用叙事生活句。
4. **习惯会漂移** — 个人先验需时间衰减（如 90 天窗口），避免换工作/换城市后越用越错。
5. **文案过哲学问句** — 同 [`CATEGORY_SCENE_COPY_AUDIT_v0.1.md`](CATEGORY_SCENE_COPY_AUDIT_v0.1.md) §2。

---

## 6. 相关文档

| 文档 | 用途 |
|------|------|
| [`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) §5.2 | 能力层级补充 |
| [`AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md`](AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md) | 品牌叙事池实现 |
| [`AGENT_PROMPT_B2.13_HABIT_PREFILL.md`](AGENT_PROMPT_B2.13_HABIT_PREFILL.md) | 个人习惯预填实现 |
| [`CategoryRecommendService.swift`](NativeDemoApp/Services/CategoryRecommendService.swift) | B2.8 现有基线 |
| [`ScenePackCopyPool.swift`](NativeDemoApp/Services/ScenePackCopyPool.swift) | 通用叙事池 |

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | 首版：双引擎 + cascade + 与 F1.3/B2.13 挂钩 |
