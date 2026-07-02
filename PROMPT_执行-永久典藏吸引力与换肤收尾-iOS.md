# Agent 按序执行 · 永久典藏吸引力 + 换肤收尾（仅 iOS · v1.0）

> **一键指令（复制整段给 Agent）**：
>
> ```text
> T1/T1.5/T2/T3/T8/UI-T8.1 与 ATTRACT-1/2 静态文案已完成，Vault/Accordion 勿重做。
> 按 @PROMPT_执行-永久典藏吸引力与换肤收尾-iOS.md 从 STEP-1 顺序执行到 STEP-9，
> 每 STEP 对照验收清单自检 Pass 后才进入下一步；任一步 Fail 则在本步内修复，不要跳步。
> 仅 iOS；不要 commit；最后输出总报告（每步 Pass/Fail + 改动文件列表）。
> ```

---

## 0. 基线（2026-06 代码审计 · 勿重复做）

| 项 | 状态 | 位置 / 说明 |
|----|------|-------------|
| Theme 基础设施 T1/T1.5 | ✅ | `NativeDemoApp/Theme/` |
| `colorThemeId` + `setTheme` + unlock T2 | ✅ | `AppSettings` / `SettingsViewModel` |
| 根注入 + `AppColors` T3 | ✅ | `NativeDemoAppApp` / `ContentView` |
| 外观 Sheet + Accordion + Vault UI-T8.1 | ✅ | `SettingsView.swift` `lifetimeThemeVault` |
| Vault 静态文案 + 三款副句 ATTRACT-2 | ✅ | helper + `lifetimeThemeCaption` |
| 分享图跟主题 T11 | ✅ | `shareCardUsesAppTheme` + `ShareCardTheme.appTheme` |
| `MemberPricingView` 脚注含「3 款专属皮肤」 | ⚠️ 部分 | `freeQuotaFootnote` + benefits 第 7 条已有，**非** lifetime 卡 bullet |
| Vault 点锁 → 会员页锚 lifetime | ❌ | 仅 `showMemberPricing = true` |
| lifetime 定价卡典藏 bullet | ❌ | `regularPlanButton` 仅 dailyHint |
| 轮播 helper / 试用 / 分享触达 / 身份角标 | ❌ | ATTRACT-2 可选 + ATTRACT-4～6 |
| T6 颜色孤岛清理 | ❌ | Views 内仍有大量 `Color(red:` |
| T9 contrast 走查 | ❌ | 未验收 |
| T12 全量 QA | ❌ | 未做 |

**气质约束**：永久 3 款 = 古铜/沉金/琥珀 Morandi 耐用皮（§6.1-L），**禁止** neon 当 permanent 卖点。

**会员约束**：`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` **§10.1.1 五条主文案禁止修改**（当前 `MemberPricingView.benefits` 为 8 条折叠列表，不是五条定稿——**本执行单不改 benefits 数组结构**，只在 lifetime 定价卡 + 脚注区加典藏表述）。

---

## 1. 边界

### 可改

| 文件 | 用途 |
|------|------|
| `NativeDemoApp/Views/MemberPricingView.swift` | lifetime 卡 bullet、锚定参数 |
| `NativeDemoApp/Views/SettingsView.swift` | 轮播 helper、Vault 点锁传参、身份 pill、试用 UI 壳 |
| `NativeDemoApp/Views/ContentView.swift` | 会员页 sheet 传 `highlightPlanId` 等 |
| `NativeDemoApp/ViewModels/SettingsViewModel.swift` | 试用过期回 default（轻量键） |
| `NativeDemoApp/Views/InsightWebView.swift` | 分享成功 quiet link |
| `PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` | §10.1.2 脚注追加一句（可选） |

### 禁止

- 重做 `lifetimeThemeVault` / Accordion / swatch 像素（UI-T8.1 已完成）
- 改 `ThemeCatalog.json` 色值（T1.5 已定）
- 改 `PlaybackService` / OCR / 次数 / IAP 核心逻辑
- 改 §10.1.1 五条主文案（若与产品 md 冲突，以「不改五条」为准）
- git commit（除非用户另行要求）
- web-preview / backend

### 参考（只读）

@PROMPT_产品-永久典藏主题吸引力-iOS.md
@PROMPT_功能-外观色彩主题与会员方案-iOS.md（§3.2 unlock 矩阵 · §6.1-L · §十 C 组）
@PROMPT_UI-外观主题选择页视觉优化-iOS.txt（✅ 已执行，验收对照）
@NativeDemoApp/Theme/ThemeCatalog.json
@NativeDemoApp/ViewModels/SettingsViewModel.swift

---

## 2. 永久主题 id（unlock tier = lifetime）

| id | 显示名 |
|----|--------|
| `lifetime_archive_gold` | 永享·档案金章 |
| `lifetime_gilded_circuit` | 永享·金线电路 |
| `lifetime_neon_cathedral` | 永享·琥珀礼拜堂 |

另：`cyber_silicon_vesper` = 标准库展示 + `unlockTier: lifetime`，逻辑不变。

---

## STEP-1 · ATTRACT-3 会员页锚定（必做）

### 目标

非 lifetime 用户从 Vault 点锁后，会员页**自动展开永久档并 scroll/highlight**；永久定价卡上可见典藏 bullet。

### 任务

**1.1 lifetime 定价卡第二行 bullet**

在 `MemberPricingView` 的 **永久会员** `regularPlanButton`（或等价 lifetime plan UI）中，在 `dailyHint` 下方增加 secondary 文案：

```text
✦ 3 款永久典藏界面（档案金章 / 金线电路 / 琥珀礼拜堂）
随账号永久保留，年度会员不可用
```

样式：11pt `AppColors.subtext`，行距 2；古铜强调可用 `#A68445` / `AppColors.lockGold`，勿 neon 金。

**1.2 锚定参数**

- `MemberPricingView` 增加可选入参，例如 `highlightPlanId: String? = nil`（值 `"lifetime"`）
- `ContentView`（或 sheet 呈现处）持有 `@State var pricingHighlightPlanId: String?`
- Vault 内「了解永久会员 →」、点锁 permanent swatch 失败路径：设置 `pricingHighlightPlanId = "lifetime"` 再 `showMemberPricing = true`

**1.3 打开会员页时**

- `onAppear` / `.task`：若 `highlightPlanId == "lifetime"` → `morePlansExpanded = true`
- `ScrollViewReader` scroll 到 lifetime plan id（或 lifetime 按钮加 `.id("lifetime")`）
- 可选：lifetime 卡 2s 浅金描边 pulse（静态高亮亦可）

**1.4 脚注（二选一或都做）**

- UI：`freeQuotaFootnote` 追加「永久会员另享 3 款仅永久可用的典藏皮肤；年度会员可使用 25+ 标准主题。」（若已有类似句则去重合并）
- 文档：`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` §10.1.2 同步同句

### 验收

- [ ] 五条主 benefits 标题/结构未改（不替换为 §10.1.1 定稿五条）
- [ ] lifetime 卡展开后可见「3 款典藏」bullet（含三款名）
- [ ] Vault 点锁 → 会员页自动展开「查看更多套餐」并滚到 lifetime
- [ ] yearly/monthly 用户仍无法 `setTheme` permanent id
- [ ] 记账 / OCR / 播放零回归

---

## STEP-2 · ATTRACT-2 轮播 helper（可选 · 建议做）

### 目标

Vault 顶栏 helper 在 3 句间轮换，强化三款故事。

### 任务

在 `lifetimeThemeVault` 内，静态 helper 下方或替换为轮播（`@State private var vaultHelperIndex = 0`）：

```text
多数永久会员从「档案金章」开始当日常皮。
爱看构成和节奏，试试「金线电路」。
晚上复盘，「琥珀礼拜堂」更护眼。
```

- 12pt secondary；切换间隔 5～8s 或随 Vault `onAppear` 随机 seed
- **不**影响已有静态句「三款典藏皮肤，随永久会员账号保留。」（保留在上，轮播在下）

### 验收

- [ ] 三句循环/随机，无 VIP 管家语气
- [ ] Vault 布局不挤、不挡 swatch

---

## STEP-3 · ATTRACT-4 预览与试用（P1 · 可选）

### 目标

降低挫败、提高转化；**不**破坏 tier 锁。

### 任务

**3.1 长按预览 15s**

- permanent swatch 加 `onLongPressGesture(minimumDuration: 0.5)` → 全屏 overlay mini mock（用 `lifetimePreviewBackground/Accent` 已有 helper）
- **不写入** `colorThemeId`；松手或 15s 自动 dismiss

**3.2 终生 1 次 24h 试用**

- `UserDefaults`：`lifetimeThemeTrialUsedAt`（TimeInterval）、`lifetimeThemeTrialThemeId`（String）
- 非 lifetime 首次点锁 permanent swatch：alert/sheet offer「试一天典藏皮」
- 接受后临时允许该 id 的 `setTheme`（仅在 ViewModel 层判断试用窗口，**勿**改 IAP）
- 试用中：设置 Tab 或外观 Sheet 顶 small「试用中」
- 到期：`enforceCurrentThemeAccess` 或 timer 静默回 `xuzhang_default` + toast 一次
- `silicon_vesper` 试用逻辑 **不适用**（仍须 lifetime tier）

### 验收

- [ ] 长按预览不写 id
- [ ] 试用仅 1 次；到期回 default 不锁死 appearance
- [ ] 试用中 yearly 仍不可用 silicon_vesper

---

## STEP-4 · ATTRACT-5 分享图触达（P1 · 可选）

### 目标

周分享图导出成功后，quiet 引导到 Vault（非打断式）。

### 任务

`InsightWebView`：`generateAndShareWeeklyCard` 成功保存后，若满足：

- `memberTier != lifetime`
- 当前 `colorThemeId` 非 permanent 三款之一

则在成功 toast 区域下方加 quiet link：

```text
用典藏主题导出分享图 →
```

点击：打开设置 → 外观 Sheet → scroll 到 Vault（可通过 Notification / binding / callback 到 `SettingsView`）。

### 验收

- [ ] 不阻塞「已保存到相册」主路径
- [ ] lifetime 用户不显示
- [ ] 不在记账/OCR/播放流程弹窗

---

## STEP-5 · ATTRACT-6 身份外显（P2 · 可选）

### 任务

**5.1** 设置页身份卡：`memberTier == lifetime` 时 small pill「典藏」，色 `#A68445`，非大 VIP 金。

**5.2** Vault helper 追加一句：「随账号永久保留，不可转让。」

**5.3**（可选）分享图 watermark toggle 仅 lifetime 可见，文案「叙账·永久」极小水印。

### 验收

- [ ] pill 仅 lifetime
- [ ] 非 lifetime 无 watermark toggle

---

## STEP-6 · T6 颜色孤岛清理（换肤收尾 · 建议做）

### 目标

`NativeDemoApp/Views` 内 `Color(red:` 仅保留 Theme 层必要项；其余改读 `AppColors` / theme token。

### 任务

对照 `@PROMPT_功能-外观色彩主题与会员方案-iOS.md` **§十 C 组**，优先清理：

- `SettingsView.swift`（appearance 区 lifetime 预览色可保留或迁到 ThemeCatalog preview token）
- `InsightWebView.swift`
- `SummaryPlaybackSheet.swift`
- `RecordView.swift` / `StatsWebView.swift`

**原则**：换主题后五 Tab + 主要 Sheet accent 跟色；不 refactor 无关 UI。

### 验收

- [ ] `rg "Color\\(red:" NativeDemoApp/Views` 数量显著下降（目标：仅 preview/不可避免项）
- [ ] 切换 `xuzhang_default` ↔ 赛博主题，五 Tab 无旧绿 accent 残留

---

## STEP-7 · T9 JSON 与 contrast（建议做）

### 任务

- 对照主 prompt **§六** 审计 `ThemeCatalog.json`：31 id × light/dark 齐全；`lockGold` 统一；赛博 `categoryColors` 用 Morandi 盘
- 新建或更新 `NativeDemoApp/Theme/ThemeContrastReport.md`：lifetime 三款 + 默认 dark 正文 contrast ≥4.5:1 人工记录

### 验收

- [ ] 31 theme id 无缺失
- [ ] §6.1-L2 checklist 全勾
- [ ] 报告文件存在

---

## STEP-8 · T10 会员门控收尾（建议做）

### 任务

- 验证 unlock 矩阵 §3.2：free 3 / standard 25+ / lifetime 3 + silicon_vesper
- 会员过期：`enforceCurrentThemeAccess` 回 default + message
- 与 STEP-1 脚注一致；**仍不改五条主文案**

### 验收

- [ ] free 只能设 3 免费 theme
- [ ] yearly 不能设 permanent 三款
- [ ] lifetime 全开
- [ ] 过期回 default

---

## STEP-9 · T12 全量 QA（必做 · 收尾）

### 任务

对照 `@PROMPT_功能-外观色彩主题与会员方案-iOS.md` **§十二** QA 矩阵走查；重点：

1. 外观 Sheet：选主题 → 全 App 变色
2. Vault / Accordion 回归
3. STEP-1 锚定漏斗
4. 分享图 toggle + 导出
5. 杀进程重启 theme 保留

### 输出

Agent 最终消息必须包含：

```text
## 执行总报告
| STEP | 结果 | 备注 |
| STEP-1 | Pass/Fail | ... |
...
## 改动文件
- path/to/file
## 未做 / 阻塞
- ...
```

---

## 3. 推荐执行范围

| 范围 | 包含 STEP | 适用场景 |
|------|-----------|----------|
| **最小闭环** | 1 | 只做会员转化锚定 |
| **产品完整** | 1 → 2 → 3 → 4 → 5 | 永久典藏吸引力全做 |
| **换肤 + 产品** | 1 → … → 9 | 上线前完整收尾 |

默认：**STEP-1 必做**；STEP-2～5 按表内「可选」可跳过但顺序不变；STEP-6～9 换肤收尾。

---

## 4. 产品速查（Agent 不必再读长 doc）

**卖**：典藏身份、耐用郑重、长期陪伴  
**不卖**：多 3 个色、neon 永久皮、记账流程弹窗  

**永久三款副句**：最耐用 / 结构感 / 夜间复盘  

**unlock**：`SettingsViewModel.isThemeUnlocked` — `lifetime` tier 仅 `memberTier == lifetime`

---

## 5. @ 文件清单

@PROMPT_执行-永久典藏吸引力与换肤收尾-iOS.md
@PROMPT_产品-永久典藏主题吸引力-iOS.md
@PROMPT_功能-外观色彩主题与会员方案-iOS.md
@PROMPT_UI-外观主题选择页视觉优化-iOS.txt
@NativeDemoApp/Views/SettingsView.swift
@NativeDemoApp/Views/MemberPricingView.swift
@NativeDemoApp/Views/ContentView.swift
@NativeDemoApp/Views/InsightWebView.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md
