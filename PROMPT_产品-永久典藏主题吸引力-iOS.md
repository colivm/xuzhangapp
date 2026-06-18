# Agent Prompt · 永久典藏主题吸引力方案 + 落地任务（仅 iOS · v1.1）

> **定位**：标准会员 = 25+ 主题 **随便换**；永久会员 = **3 款典藏皮 + 身份标识**，不是第 26～28 个皮肤。  
> **气质**：古铜 / 沉金 / 琥珀 Morandi 耐用皮（§6.1-L），**禁止**赛博 neon 当 permanent 卖点。  
> **用法**：`按 @PROMPT_产品-永久典藏主题吸引力-iOS.md 实现 ATTRACT-3 起，仅 iOS，不要 commit`

### 执行状态（2026-06）

| 任务 | 状态 | 说明 |
|------|------|------|
| UI-T8.1（`PROMPT_UI-外观主题选择页视觉优化-iOS.txt`） | ✅ 已执行 | Accordion + Vault + 64pt 金边 swatch 等已在 `SettingsView` |
| ATTRACT-1 Vault 橱窗 | ✅ 已由 UI-T8.1 覆盖 | **勿重复实现** |
| ATTRACT-2 叙事文案 | ⚠️ 部分完成 | 静态 helper + 三款副句已有；**轮播 helper 可选未做** |
| ATTRACT-3～6 | ❌ 待做 | 会员页锚定 / 试用 / 分享触达 / 身份角标 |

**下一步 Agent 指令**：从 **ATTRACT-3** 起，或补 ATTRACT-2 轮播 helper（可选）。**不要**再跑 UI-T8.1 或重做 Vault。

---

## 一、产品共识（必读）

### 1.1 卖什么 / 不卖什么

| 卖 | 不卖 |
|----|------|
| 典藏身份：「随账号一辈子的界面」 | 「多 3 个颜色」 |
| 比默认更耐用、更郑重（长看痕迹） | 比赛博更亮、更 neon |
| 情感溢价：叙账长期陪伴的视觉延伸 | 功能更多、数据更多 |

### 1.2 三款永久主题分工

| id | 显示名 | 唤醒度 | 心理 | helper | 最佳场景 |
|----|--------|--------|------|--------|----------|
| `lifetime_archive_gold` | 永享·档案金章 | 1.5 | 郑重、被保存 | 像把这段生活收进档案馆 | 日常主皮、长看痕迹 |
| `lifetime_gilded_circuit` | 永享·金线电路 | 2.0 | 精密、结构 | 细看构成和节奏的人 | 线索 Tab、数据型用户 |
| `lifetime_neon_cathedral` | 永享·琥珀礼拜堂 | 2.5 | 仪式、夜间复盘 | 傍晚复盘的一束光 | 夜间、多看一层、分享图 |

**色相分工**：暖档案 · 冷金线 · 靛琥珀 —— 避免三款「黑底金字」复制感。

### 1.3 与会员档关系（对齐主 prompt §3.2）

| 档位 | 标准 25+ 主题 | 永久典藏 3 款 |
|------|---------------|---------------|
| free | 3 免费 | ❌ 可预览 |
| monthly / yearly | ✅ | ❌ 点击 → 升级永久 |
| lifetime | ✅ | ✅ |

`cyber_silicon_vesper`（硅基晚祷）= 标准库 **展示** + lifetime **门控**，与上述 3 款典藏 **并列稀缺**，但 UI 上归入标准 Accordion，unlock 逻辑不变。

---

## 二、提高吸引力的六杠杆

### 2.1 视觉稀缺（P0 · UI）

| 手段 | 说明 |
|------|------|
| **独立 Vault 橱窗** | 永久 3 款 **不是** 第 8 个 Accordion；永远展开，首屏可见 |
| **64pt 金边 swatch** | 标准 56pt；1.5px 渐变金边 `#C9A961→#A68445` |
| **Vault 容器** | 渐变底 `#F5F0E8→#EEECF2` + 1px `#C9A64A` @ 25% 描边 + 圆角 16 |
| **pill 标签** | 「✦ 永久会员」/ 已解锁「已解锁 ✓」 |
| **「永享·」前缀 accent 着色** | 名称 Semibold，前缀用各 theme accent |

**详细 UI 规格** → `@PROMPT_UI-外观主题选择页视觉优化-iOS.txt` 任务 C（**✅ 已执行**，本 prompt 不重复像素级参数）。

### 2.2 叙事钩子（P0 · 文案壳）

Vault 内每 swatch 下 **9pt tertiary** 一句（静态，非算法）：

```text
档案金章   → 最耐用
金线电路   → 结构感
琥珀礼拜堂 → 夜间复盘
```

Vault 顶 **12pt secondary** 轮播 helper（可选 `@State` 索引，3 句轮换或随机 seed）：

```text
多数永久会员从「档案金章」开始当日常皮。
爱看构成和节奏，试试「金线电路」。
晚上复盘，「琥珀礼拜堂」更护眼。
```

### 2.3 预览与诱惑（P1 · 交互）

| 策略 | 行为 | 持久化 |
|------|------|--------|
| **清晰预览** | 非永久用户 Vault opacity **0.92**（禁止 0.55 糊片） | — |
| **长按预览 15s** | 全屏 mini mock 套色 | **不写入** colorThemeId |
| **一次 24h 试用**（P1 可选） | 非 lifetime 终生 **1 次** 试用任一款 permanent theme | 到期回 `xuzhang_default` + toast |
| **点锁转化** | toast + `MemberPricingView` **锚 lifetime 卡** | 不写入 id |

试用键（若做 P1）：`UserDefaults` `lifetimeThemeTrialUsedAt` / `lifetimeThemeTrialThemeId`；**勿**进会员核心逻辑文件。

### 2.4 永久档价格锚定（P1 · 文案）

**MemberPricingView 永久档卡片** 增加 **第 2 可见 bullet**（第 1 条仍是切片/OCR 核心，不改五条主列表）：

```text
✦ 3 款永久典藏界面（档案金章 / 金线电路 / 琥珀礼拜堂）
  随账号永久保留，年度会员不可用
```

**§10.1.2 脚注**（`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`）追加一句：

```text
永久会员另享 3 款仅永久可用的典藏皮肤；年度会员可使用 25+ 标准主题。
```

**五条主文案禁止修改。**

### 2.5 触达时机（P1 · 轻量）

| 时机 | 动作 | 频率 cap |
|------|------|----------|
| 设置 → 外观 | Vault 常驻 | — |
| 周分享图导出成功 | quiet link「用典藏主题导出？」 | 非会员 + default 时；每周 ≤1 |
| yearly 续费 / 升级页 | 对比行「升级永久保留典藏皮」 | 仅到期前后 |
| 全 App 非设置入口 | 任意推广 permanent Vault | **每周 ≤1** |

**禁止**：记账 / OCR / 播放流程中弹窗推永久皮。

### 2.6 身份外显（P2 · 可选）

| 手段 | 说明 |
|------|------|
| 设置身份卡 small「典藏」角标 | 古铜 `#A68445`，非大 VIP 金 |
| 分享图可选极小水印「叙账·永久」 | 仅 `shareCardUsesAppTheme` + lifetime |
| 文案「随账号永久保留，不可转让」 | Vault helper 内一句 |

---

## 三、反模式（禁止）

- 永久皮比赛博还 neon → 与「理解式叙账」打架  
- 三款全是黑底金字 → 无差异  
- 标准会员可买断 permanent 单款 → 破坏稀缺  
- 首屏强推 / 高频弹窗 → 伤品牌  
- 锁态糊到看不清 → 无欲望只有挫败  

---

## 四、效果指标（上线后）

| 指标 | 含义 |
|------|------|
| Vault 曝光 → 点 swatch | 吸引力 |
| 点锁 → 会员页 → 选 lifetime | 转化漏斗 |
| lifetime 用户 3 款 adoption | 是否真在用 |
| yearly → lifetime 升级率 | 典藏是否成为升级理由 |
| 分享图 + 典藏 theme 导出占比 | 外显身份 |

---

## 五、落地任务（Agent 执行）

### 边界

| 可改 | 禁止 |
|------|------|
| `SettingsView.swift` Vault UI + helper 文案壳 | `ThemeCatalog.json` 色值（T1.5 已定） |
| `MemberPricingView.swift` 永久卡 bullet + 脚注区 | §10.1 **五条主文案** |
| `InsightWebView` 分享成功 quiet link（P1） | PlaybackService / OCR / 次数逻辑 |
| `UserDefaults` 试用键（P1 可选） | web-preview / backend |
| `SettingsViewModel` 试用过期回 default（P1） | git commit（除非用户要求） |

**依赖**：T8 + UI-T8.1 已完成（Vault / Accordion 已在 `SettingsView`）。

---

### ATTRACT-1 · Vault 典藏橱窗（P0）· ✅ 已完成（UI-T8.1）

> 已由 `@PROMPT_UI-外观主题选择页视觉优化-iOS.txt` 任务 A/B/C 落地。**Agent 跳过本节**，仅作验收对照。

1. 永久 3 款 **独立 `LifetimeThemeVault`**，不在 7 族 Accordion 内  
2. 永远展开；渐变底 + 金描边 + pill  
3. swatch Style `.lifetime`：64pt、金边、锁角标、名称 accent  
4. 非 lifetime：opacity 0.92 + 「了解永久会员 →」  
5. 点击锁 → toast + 会员页锚 lifetime  

**验收**：
- [ ] 不进 Accordion 列表  
- [ ] 首屏滚动少即可见 3 款  
- [ ] 与标准 swatch 一眼可区分  

---

### ATTRACT-2 · 叙事文案（P0）· ⚠️ 部分完成

1. Vault helper：「三款典藏皮肤，随永久会员账号保留。」 — **✅ 已有**  
2. 每 swatch 下 9pt：最耐用 / 结构感 / 夜间复盘 — **✅ 已有**  
3. 可选：顶栏 3 句轮播 helper（见 §2.2） — **❌ 未做，可选补**  

**验收**：
- [x] 三款各有副句，非重复  
- [x] 无「解锁 VIP」「尊享」等管家语气  
- [ ] 轮播 helper（可选）  

---

### ATTRACT-3 · 会员页锚定（P1）

1. `MemberPricingView` lifetime 卡增加 §2.4 bullet  
2. `PRODUCT_PLAYBACK_MEMBERSHIP` 脚注一句（可选同步 md，或仅 UI 字符串）  
3. 从 Vault 点锁打开 pricing 时 scroll / highlight lifetime tier  

**验收**：
- [ ] 五条主列表未改  
- [ ] lifetime 卡可见「3 款典藏」  

---

### ATTRACT-4 · 预览与试用（P1 · 可选）

1. 长按 permanent swatch 15s 全屏预览（不写 id）  
2. 终生 1 次 24h 试用：  
   - 首次点锁可 offer「试一天典藏皮」  
   - 试用中 Tab 显示 small「试用中」  
   - 到期静默回 default + toast 一次  

**验收**：
- [ ] 试用结束不锁死 appearance  
- [ ] 试用仍不可用 silicon_vesper 若 tier 不符  

---

### ATTRACT-5 · 分享图触达（P1 · 可选）

1. 周分享图导出成功页底部 quiet link  
2. 条件：非 lifetime + 当前非 permanent theme  
3. 文案：「用典藏主题导出分享图 →」→ 外观 Sheet 并 scroll 到 Vault  

**验收**：
- [ ] 不阻塞导出成功主路径  
- [ ] 每周同类触达可忽略（实现简单即可，精细 cap P2）  

---

### ATTRACT-6 · 身份角标（P2 · 可选）

1. 设置页身份卡：lifetime 显示 small「典藏」pill  
2. 分享图 watermark toggle 仅 lifetime 可见  

---

## 六、实施顺序

```text
✅ 已完成：UI-T8.1（含 ATTRACT-1）+ ATTRACT-2 静态文案
下一步 P1：ATTRACT-3 + ATTRACT-4 + ATTRACT-5（会员锚定 + 试用 + 分享触达）
可选 P2：ATTRACT-2 轮播 helper + ATTRACT-6（角标 / watermark）
```

UI-T8.1 已单独落地，后续 **ATTRACT-3 起** 可开新 PR。

---

## 七、验收总清单

产品：
- [ ] 永久主题卖「典藏身份」而非「多三个色」  
- [ ] yearly 无法用 3 款 permanent；lifetime 全开  
- [ ] 触达不以记账流程打断为主  

UI（UI-T8.1 已覆盖）：
- [x] Vault 独立、金边、64 swatch  
- [x] 非会员能看清 permanent 长什么样  
- [ ] 点锁 → lifetime 定价卡（需 ATTRACT-3 锚定）  

文案：
- [ ] 五条主文案未改  
- [ ] lifetime 卡有「3 款典藏」bullet  

回归：
- [ ] setTheme / unlock 矩阵与主 prompt §3.2 一致  
- [ ] 标准 25 主题 Accordion 不受影响  

---

## 八、Agent 短指令模板

**推荐：会员页锚定（下一步）**

```text
UI-T8.1 已完成，Vault 勿重做。
按 @PROMPT_产品-永久典藏主题吸引力-iOS.md 实现 ATTRACT-3。
不改五条主文案，不要 commit。
```

**P1 全量（不含已完成的 Vault UI）**

```text
UI-T8.1 已完成。按 @PROMPT_产品-永久典藏主题吸引力-iOS.md 实现 ATTRACT-3～5，
每任务自检后再下一项。不要重做 SettingsView Vault/Accordion。不要 commit。
```

**可选：补轮播 helper**

```text
按 @PROMPT_产品-永久典藏主题吸引力-iOS.md §2.2 为 Vault 顶栏加 3 句轮播 helper。
仅改 SettingsView 文案壳，不要 commit。
```

---

## 九、@ 文件

@PROMPT_产品-永久典藏主题吸引力-iOS.md
@PROMPT_UI-外观主题选择页视觉优化-iOS.txt
@PROMPT_功能-外观色彩主题与会员方案-iOS.md（§3.2 §6.1-L）
@NativeDemoApp/Views/SettingsView.swift
@NativeDemoApp/Views/MemberPricingView.swift
@NativeDemoApp/Views/InsightWebView.swift
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md（§10.1）

---

## 十、一句话总结

> **永久主题吸引力 = 看得见（Vault）+ 讲得清（三款故事）+ 买不到标准版（tier 锁）+ 用得久（Morandi 耐用色）+ 偶尔被看见（分享/定价锚定）** —— 不是第四个霓虹皮肤。
