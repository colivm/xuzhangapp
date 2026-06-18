# Agent Prompt · Task UI-T1 — 外观色彩主题 · 全链路细致实现（v0.2）

> **背景**：当前 `SettingsView` 外观 Sheet 仅有「跟随系统 / 浅色 / 深色」三档（`AppSettings.Appearance`），无色彩主题。产品 **尚未上线**，本功能 **不赶工**，按 Phase 慢做，但 **每一 Phase 必须闭环可验收**，禁止「设置能选、主界面不变」的半成品对外演示。  
> **会员定位**：主题 = 留存与情感溢价；**不修改** `PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md` §10.1 五条主文案。  
> **用法**：`按 @PROMPT_功能-外观色彩主题与会员方案-iOS.md 实现 Phase T{n}，仅 iOS，不要 commit`

---

## 〇、实施原则（必读）

| 原则 | 说明 |
|------|------|
| **一次 Phase 一个闭环** | 做完 T3 主 Tab，切换主题后 5 个 Tab 必须 **全部** 变色，不能留绿 |
| **禁止颜色孤岛** | 见 **§十 漏项清单**；任何 `Color(red:` / 本地 switch 分类色 / `settingsInkAccent` 都要纳入 |
| **Token 唯一来源** | 运行时只读 `ThemeResolver.current`；`AppColors` 退化为 accessor，不再硬编码 hex |
| **明暗 × 主题正交** | `appearance`（系统/浅/深）× `colorThemeId` = 最终 token；各 31×2 套 JSON 齐备后再标「完成」 |
| **性能** | 启动 parse 一次；`Color` 缓存；禁止在 `body` 内 parse hex |
| **会员过期** | 自动回退 `xuzhang_default` + toast 一次；不清用户 `appearance` |
| **走查矩阵** | 每 Phase 结束跑 **§十二 QA 矩阵** 中对应行，全勾才进下一 Phase |

---

## 一、现状（代码锚点）

| 位置 | 现状 |
|------|------|
| 设置首页 | `settingsFeatureGrid` 2×2：`账号会员` / `云端备份` / `陪伴语气` / **外观设置** |
| 外观入口 subtitle | `appearanceSummary` → 「跟随系统 / 浅色 / 深色」 |
| 外观 Sheet | `SettingsSheet.appearance` → 3 个 `webAppearanceButton` |
| 数据模型 | `AppSettings.appearance: .system \| .light \| .dark`；**无** `colorThemeId` |
| 色彩实现 | 全局 `AppColors` 硬编码；`ShareCardTheme` 仅分享图 |
| 会员判断 | `AppSettings.hasMemberAccess`；档位 `free / monthly / yearly / lifetime` |

---

## 二、设置页 · 外观 Sheet 排版方案

### 2.1 信息架构（自上而下）

```text
┌─ Sheet 标题：外观 ─────────────────────────────┐
│                                                │
│  §1  明暗                                    │
│      [ 跟随系统 ]          ← 全宽 pill         │
│      [ 浅色  |  深色 ]     ← 半宽 segmented   │
│      helper：跟随系统时，明暗随 iOS 设置切换。  │
│                                                │
│  ── 分隔线 ──                                  │
│                                                │
│  §2  色彩主题                                │
│      helper：只改界面颜色，不影响账本数据。       │
│      当前：叙账默认 ✓                          │
│                                                │
│      2a  日常（免费）                          │
│          ┌────┐ ┌────┐ ┌────┐                 │
│          │默认│ │留白│ │晴云│  ← 3 列 swatch  │
│          └────┘ └────┘ └────┘                 │
│                                                │
│      2b  会员主题                              │
│          副标题 + 🔒（非会员）                  │
│          按「主题族」折叠 Accordion：            │
│            ▼ 赛博朋克（5）                     │
│            ▶ 情绪气象（5）                     │
│            ▶ 纸境东方（5）                     │
│            …                                   │
│          每族内：2 列 swatch 网格               │
│          未解锁：swatch 上锁 + 点击 → 会员页    │
│                                                │
│      2c  预览条（可选 P2）                     │
│          迷你 mock：顶栏 + 1 张卡片 + Tab 色    │
│                                                │
│  §3  高级（P2 · 会员）                         │
│      Toggle：分享图使用当前主题                  │
│      Toggle：痕迹页使用当前主题（默认开）        │
│                                                │
│  footer  [ 恢复默认主题 ]  quiet link          │
└────────────────────────────────────────────────┘
```

### 2.2 设置首页 Tile 文案

| 字段 | 现文案 | 新文案规则 |
|------|--------|------------|
| title | 外观设置 | 不变 |
| subtitle | 仅明暗 | `{明暗} · {主题短名}`，例：`跟随系统 · 叙账默认` / `浅色 · 全息黄昏` |

### 2.3 Swatch 组件规格

| 属性 | 参数 |
|------|------|
| 尺寸 | 72×88 pt（含标签） |
| 色块 | 56×56 pt，radius 14 |
| 色块内容 | 3 色点：`accent` + `background` 角 + `surface` 条 |
| 选中态 | 2px `accent` 描边 + ✓ 角标 |
| 锁定态 | 色块 `opacity(0.55)` + 居中 `lock.fill` 14pt |
| 标签 | 11pt Medium，1 行，`minimumScaleFactor 0.8` |
| 网格 | 免费区 3 列；会员区 2 列（Accordion 内） |

### 2.4 交互规则

| 操作 | 行为 |
|------|------|
| 点免费主题 | 立即应用 + 写 `colorThemeId` + haptic light |
| 点会员主题（已会员） | 同上 |
| 点会员主题（非会员） | Sheet 内 toast「开通会员解锁主题」+ 0.3s 后 `showMemberPricing = true` |
| 点 lifetime 专属（非 lifetime） | toast「年度/永久会员专属」+ 会员页并锚到 lifetime 卡 |
| 恢复默认 | `colorThemeId = "xuzhang_default"` + `appearance = .system` |
| 预览（P2） | 长按 swatch 500ms 全屏预览，松手取消 |

### 2.5 与明暗模式关系

```text
最终 UI 色 = ThemeToken[colorThemeId] × AppearanceMode[system|light|dark]
```

- **明暗**：继续用 `AppSettings.appearance`，全员免费，不可会员化。  
- **色彩主题**：独立字段 `colorThemeId: String`，默认 `xuzhang_default`。  
- 每个主题提供 **light + dark 两套 token**（或 dark 为 light 的算法变体，但 v1 建议显式两套）。

---

## 三、色彩主题 · 会员方案

### 3.1 战略定位（对齐 §10.1）

| 原则 | 说明 |
|------|------|
| 不抢核心转化 | 会员页 **五条不改**；主题写进 **§10.1.2 脚注** 或 `MemberPricingView` 折叠区第 6 条「彩蛋权益」 |
| 免费能用 App | 默认主题 + 2 款免费换肤 + 完整明暗 |
| 会员得「整库」 | 解锁 **标准主题库**（约 25 款） |
| 永久差异化 | **lifetime 专属 3 款**，yearly 不送 |
| 可试用 | 非会员可 **预览 15 秒**（Sheet 内 mini mock 自动套色，不写持久化） |

### 3.2 解锁矩阵

| 档位 | 明暗 | 免费主题 | 标准主题库 | Lifetime 专属 | 分享图主题 |
|------|------|----------|------------|---------------|------------|
| **free** | ✅ 全部 | ✅ 3 款 | ❌ 可预览 | ❌ | 仅默认 |
| **monthly** | ✅ | ✅ | ✅ 全部标准 | ❌ | ✅ |
| **yearly** | ✅ | ✅ | ✅ 全部标准 | ❌ | ✅ |
| **lifetime** | ✅ | ✅ | ✅ | ✅ 3 款 | ✅ |

### 3.3 主题分级 ID

```text
tier: free | standard | lifetime
```

| tier | 数量 | 策略 |
|------|------|------|
| `free` | 3 | 默认 + 2 款低饱和（与产品气质一致） |
| `standard` | 25 | monthly/yearly/lifetime 可用 |
| `lifetime` | 3 | 仅 `memberTier == lifetime` |

### 3.4 会员页文案（新增，不替换五条）

**§10.1.2 脚注追加一句：**

> 会员另可解锁 **25+ 界面色彩主题**（含赛博朋克、情绪气象等）；永久会员再享 **3 款专属皮肤**。

**MemberPricingView 折叠区可选第 6 条（默认收起）：**

| 标题 | 副文案 |
|------|--------|
| 🎨 25+ 色彩主题 + 分享图同款 | 痕迹、今天、复盘页统一换肤；永久会员再享 3 款限定主题。 |

### 3.5 转化路径（不骚扰）

- 设置 → 外观 → 点锁 swatch → 会员 Sheet（**不要**首页弹窗推主题）  
- 周分享图导出成功页：底部 quiet「用会员主题导出」→ 仅当当前非会员且用的是默认皮  
- **禁止**：记账流程中打断选主题

### 3.6 数据持久化（实现参考）

```swift
// AppSettings 新增
var colorThemeId: String  // default "xuzhang_default"
var shareCardUsesAppTheme: Bool  // default false, P2
```

云端：登录后 `colorThemeId` 随 settings sync（与 `memberTier` 校验 unlock）。

---

## 四、主题库目录（v1 · 31 款）

### 4.1 免费（3）

| id | 显示名 | tier | 族 |
|----|--------|------|-----|
| `xuzhang_default` | 叙账默认 | free | — |
| `paperverse_blank` | 纸境·留白 | free | 纸境东方 |
| `mood_weather_clear` | 气象·晴云 | free | 情绪气象 |

### 4.2 标准 · 赛博朋克（5）

| id | 显示名 |
|----|--------|
| `cyber_neon_abyss` | 霓虹深渊 |
| `cyber_vector_camouflage` | 矢量迷彩 |
| `cyber_holographic_dusk` | 全息黄昏 |
| `cyber_crystal_overload` | 晶体过载 |
| `cyber_silicon_vesper` | 硅基晚祷 ⚠️ 见下 |

> **注**：`cyber_silicon_vesper` 在 standard 库展示但 **实际 unlock 需 lifetime**（lifetime 专属占位，标准会员点击提示升级永久）。

### 4.3 标准 · 情绪气象（5）

| id | 显示名 |
|----|--------|
| `mood_weather_dusk` | 气象·晚霞账 |
| `mood_weather_mist` | 气象·薄雾晨 |
| `mood_weather_storm` | 气象·雷阵雨 |
| `mood_weather_aurora` | 气象·极光夜 |
| `mood_weather_tide` | 气象·潮汐日志 |

### 4.4 标准 · 纸境东方（4，留白已免费）

| id | 显示名 |
|----|--------|
| `paperverse_seal` | 纸境·朱砂印 |
| `paperverse_ink_wash` | 纸境·湿墨 |
| `paperverse_typecase` | 纸境·活字排 |
| `paperverse_faint_spectrum` | 纸境·淡彩谱 |

### 4.5 标准 · 自然演算（4）

| id | 显示名 |
|----|--------|
| `bio_moss_terminal` | 自然·苔藓终端 |
| `bio_coral_data` | 自然·珊瑚数据 |
| `bio_mycelium` | 自然·菌丝网络 |
| `bio_photosynth` | 自然·光合界面 |

### 4.6 标准 · 太空通勤（4）

| id | 显示名 |
|----|--------|
| `orbital_window_dawn` | 太空·舱窗晨 |
| `orbital_zero_g` | 太空·无重力清单 |
| `orbital_deep_stamp` | 太空·深空邮戳 |
| `orbital_sleep_mode` | 太空·休眠模式 |

### 4.7 标准 · 工业柔光（3）

| id | 显示名 |
|----|--------|
| `brutal_concrete` | 工业·清水混凝土 |
| `brutal_safety_orange` | 工业·安全橙点 |
| `brutal_grid_paper` | 工业·网格纸 |

### 4.8 Lifetime 专属（3）

| id | 显示名 |
|----|--------|
| `lifetime_gilded_circuit` | 永享·金线电路 |
| `lifetime_neon_cathedral` | 永享·霓虹礼拜堂 |
| `lifetime_archive_gold` | 永享·档案金章 |

---

## 五、ThemeToken 参数规范

### 5.1 单主题 JSON 结构

```json
{
  "id": "cyber_neon_abyss",
  "displayName": "霓虹深渊",
  "tier": "standard",
  "family": "cyber",
  "modes": {
    "light": { "...": "见 5.2" },
    "dark": { "...": "见 5.2" }
  }
}
```

### 5.2 每 mode 必填 token（与现有 AppColors 对齐）

| token | 用途 | 类型 |
|-------|------|------|
| `background` | 页面底 | `#RRGGBB` 或 gradient 数组 |
| `backgroundGradientEnd` | 渐变终点 | `#RRGGBB` |
| `surface` | 玻璃卡片底 | `#RRGGBB` + opacity |
| `surfaceWarm` | Hero 纸章 | `#RRGGBB` |
| `surfaceMuted` | Chip / 空柱槽 | `#RRGGBB` |
| `stroke` | 卡片描边 | `#RRGGBB` |
| `textPrimary` | 主文字 | `#RRGGBB` |
| `textSecondary` | 副文字 | `#RRGGBB` |
| `textTertiary` | 角标 | `#RRGGBB` |
| `accent` | 主强调 | `#RRGGBB` |
| `accentDark` | 按下 / 深色强调 | `#RRGGBB` |
| `lockGold` | 会员锁 | `#RRGGBB` |
| `categoryColors` | 8 分类色 | `[#RRGGBB × 8]` |
| `heroGradientPink` | 背景光斑 1 | `#RRGGBB` |
| `heroGradientTeal` | 背景光斑 2 | `#RRGGBB` |

### 5.3 分类色顺序（固定）

```text
transport, dining, daily, shopping, health, social, home, lodging
```

---

## 六、全量主题色值表（light mode · dark 见 6.2 规则）

### 6.0 叙账默认 · xuzhang_default（free）

```yaml
light:
  background: "#EEF0F4"
  backgroundGradientEnd: "#EEF0F4"
  surface: "#FFFFFF"          # opacity 0.72
  surfaceWarm: "#FFF7EC"
  surfaceMuted: "#F0F2F5"
  stroke: "#E8EDF2"
  textPrimary: "#253041"
  textSecondary: "#5D697E"
  textTertiary: "#8A95A8"
  accent: "#7FB3A2"
  accentDark: "#78AE9E"
  lockGold: "#C9A64A"
  heroGradientPink: "#FFC5DE"  # opacity 0.34
  heroGradientTeal: "#B0E0DB"  # opacity 0.30
  categoryColors:
    - "#6A9FA8"  # transport
    - "#B8957A"  # dining
    - "#8FA888"  # daily
    - "#A892A8"  # shopping
    - "#7FA882"  # health
    - "#C4A67A"  # social
    - "#A89888"  # home
    - "#8A96AA"  # lodging
dark:
  background: "#0F1422"
  surface: "#192134"         # opacity 0.58
  surfaceWarm: "#1A2332"
  surfaceMuted: "#252D3D"
  stroke: "#94ABD3"            # opacity 0.21
  textPrimary: "#ECF1FF"
  textSecondary: "#9EABC2"
  textTertiary: "#7A8799"
  accent: "#78AE9E"
  accentDark: "#6A9E8E"
  lockGold: "#C9A64A"
  categoryColors: [同上略降亮度 10%]
```

### 6.1 标准主题 · light mode 参数

#### paperverse_blank（free）

```yaml
background: "#F7F3EA"
surfaceWarm: "#F7F3EA"
surfaceMuted: "#EDE8DC"
stroke: "#E0D8C8"
textPrimary: "#1C1C1C"
textSecondary: "#4A4A4A"
textTertiary: "#8A8580"
accent: "#C84C4C"
accentDark: "#A83E3E"
heroGradientPink: "#F5E6D3"
heroGradientTeal: "#E8E4DC"
categoryColors: ["#6A7A8A","#B8957A","#8FA888","#A892A8","#7FA882","#C4A67A","#A89888","#8A96AA"]
```

#### mood_weather_clear（free）

```yaml
background: "#F0F8FF"
surfaceWarm: "#FFF8F0"
surfaceMuted: "#E8F0F8"
stroke: "#D8E8F0"
textPrimary: "#2A3A4A"
textSecondary: "#5A6A7A"
textTertiary: "#8A9AAA"
accent: "#87CEEB"
accentDark: "#6BB8D8"
heroGradientPink: "#FFE8D0"
heroGradientTeal: "#B0E0FF"
categoryColors: ["#6A9FB8","#D4A574","#8FB888","#A898B8","#7FB892","#C4B07A","#A89888","#8898B0"]
```

#### cyber_neon_abyss（standard）

```yaml
background: "#0A0612"
backgroundGradientEnd: "#12082A"
surface: "#1A1030"           # opacity 0.75
surfaceWarm: "#221840"
surfaceMuted: "#2A1F4A"
stroke: "#FF2D9A"              # opacity 0.18
textPrimary: "#F0E8FF"
textSecondary: "#B8A8D0"
textTertiary: "#8878A8"
accent: "#FF2D9A"
accentDark: "#E02080"
lockGold: "#FFD700"
heroGradientPink: "#FF2D9A"    # opacity 0.25
heroGradientTeal: "#0033FF"    # opacity 0.20
categoryColors: ["#00E5FF","#FF2D9A","#39FF14","#BF00FF","#FF6B35","#FFD700","#8A8A8A","#4A00E0"]
```

#### cyber_vector_camouflage（standard）

```yaml
background: "#1A1F1A"
surfaceWarm: "#222822"
surfaceMuted: "#2A322A"
stroke: "#39FF14"              # opacity 0.15
textPrimary: "#E0FFE8"
textSecondary: "#A0B8A8"
textTertiary: "#708878"
accent: "#39FF14"
accentDark: "#2DD10F"
heroGradientPink: "#2A3A2A"
heroGradientTeal: "#39FF14"    # opacity 0.12
categoryColors: ["#39FF14","#FF4444","#FFFF00","#00FFFF","#FF8800","#FF00FF","#888888","#004400"]
```

#### cyber_holographic_dusk（standard）

```yaml
background: "#1A1420"
surfaceWarm: "#2A1F28"
surfaceMuted: "#322838"
stroke: "#FF7E67"              # opacity 0.20
textPrimary: "#FFF0E8"
textSecondary: "#C8B0A8"
textTertiary: "#988880"
accent: "#FF7E67"
accentDark: "#E86850"
heroGradientPink: "#FFB3C6"
heroGradientTeal: "#67E8FF"
categoryColors: ["#67E8FF","#FF7E67","#FFDAB9","#DDA0DD","#98FB98","#F0E68C","#E6B8A2","#B0C4DE"]
```

#### cyber_crystal_overload（standard）

```yaml
background: "#080818"
surfaceWarm: "#101028"
surfaceMuted: "#181838"
stroke: "#00FFFF"              # opacity 0.22
textPrimary: "#E8F8FF"
textSecondary: "#A0C8E0"
textTertiary: "#6898B8"
accent: "#00FFFF"
accentDark: "#00CCCC"
heroGradientPink: "#BF00FF"    # opacity 0.20
heroGradientTeal: "#00FFFF"    # opacity 0.18
categoryColors: ["#00FFFF","#BF00FF","#FF00FF","#0080FF","#00FF80","#FF0080","#8040FF","#40FFFF"]
```

#### cyber_silicon_vesper（lifetime 门控 · standard 展示）

```yaml
background: "#120818"
surfaceWarm: "#1A1020"
surfaceMuted: "#221828"
stroke: "#D4AF37"              # opacity 0.20
textPrimary: "#F0E8F0"
textSecondary: "#B8A8B8"
textTertiary: "#887898"
accent: "#D4AF37"
accentDark: "#B89830"
lockGold: "#D4AF37"
heroGradientPink: "#4A2040"
heroGradientTeal: "#D4AF37"    # opacity 0.15
categoryColors: ["#D4AF37","#8B6080","#608080","#806080","#808060","#608860","#887860","#606880"]
```

#### mood_weather_dusk（standard）

```yaml
background: "#2A2438"
surfaceWarm: "#3A3248"
accent: "#FF8C42"
textPrimary: "#FFF0E8"
categoryColors: ["#6B5B95","#FF8C42","#FF6B6B","#C4A07A","#7FA882","#E8A0BF","#A89888","#8898B0"]
# 其余 token 按 accent 降饱和规则从 light 推导，实现时补全
```

#### mood_weather_aurora（standard）

```yaml
background: "#0F172A"
accent: "#34D399"
accentSecondary: "#A78BFA"
textPrimary: "#F1F5F9"
categoryColors: ["#34D399","#A78BFA","#38BDF8","#F472B6","#FBBF24","#60A5FA","#94A3B8","#6366F1"]
```

#### brutal_safety_orange（standard）

```yaml
background: "#F5F5F5"
surfaceWarm: "#FFFFFF"
accent: "#FF5F1F"
textPrimary: "#1A1A1A"
textSecondary: "#4A4A4A"
categoryColors: ["#FF5F1F","#1A1A1A","#808080","#404040","#FF5F1F","#606060","#909090","#303030"]
```

#### lifetime_gilded_circuit（lifetime）

```yaml
background: "#0A0A0F"
surfaceWarm: "#141420"
accent: "#E8C547"
stroke: "#E8C547"              # opacity 0.25
textPrimary: "#F5F0E0"
heroGradientPink: "#E8C547"    # opacity 0.12
heroGradientTeal: "#1A2040"
categoryColors: ["#E8C547","#C0A030","#8090A0","#6080B0","#A08040","#608860","#887860","#506070"]
```

> **31 款 × light/dark**：T2 阶段先完成 JSON 骨架 + 8 款人工精调色；T9 阶段补齐全库并人工抽检 contrast。不允许长期只支持 8 款却 UI 展示 31 款锁图。

### 6.2 dark mode 推导规则（批量生成用）

```text
background:     light 亮度 × 0.15，饱和 × 0.8
surface:        background 亮度 +8%
textPrimary:    亮度 ≥ 0.90，饱和 ≤ 0.10
textSecondary:  亮度 0.65，饱和 0.08
accent:         light accent 亮度 −5%，饱和 +5%
categoryColors: 各 hue 不变，亮度 → 0.65–0.75
```

---

## 七、实现 Phase（12 步 · 慢做闭环）

每 Phase **独立 PR**；合并前必须勾选该 Phase 验收项 + 跑对应 QA 矩阵行。

| Phase | 名称 | 交付物 | 验收标准（摘要） |
|-------|------|--------|------------------|
| **T1** | 基础设施 | `Theme/`：`ThemeCatalog.json`、`ThemeTokens`、`ThemeResolver`、`AppThemeKey` Environment | 单元测试：parse 31 id；resolve light/dark；unknown id → default |
| **T2** | 数据持久化 | `AppSettings.colorThemeId` + migrate；`SettingsViewModel.setTheme()` 含 unlock 校验 | 杀进程重启后 theme 保留；非法 id 回 default |
| **T3** | 根注入 | `NativeDemoAppApp` / `ContentView` 注入 `@Environment(\.appTheme)`；`AppColors` 改 accessor | 改 `colorThemeId` 后 **Tab 栏 + 顶栏 + 背景渐变** 即时变色 |
| **T4** | 主 Tab 五屏 | `HomeView` `RecordView` `StatsWebView` `InsightWebView` `SettingsView` 主列表 | 五 Tab 内 **零** 旧绿色 accent 残留（霓虹主题走查） |
| **T5** | Sheet / 弹层 | 见 **§十 B 组** 全部 sheet | 打开任一 sheet 颜色与主屏一致 |
| **T6** | 颜色孤岛清理 | 删除/替换 **§十 C 组** 本地色 | `rg "Color\\(red:" NativeDemoApp/Views` 仅剩 Theme 层 |
| **T7** | 分类色统一 | `traceClueColor` / `traceAccentColor` / slip 色条 → `theme.categoryColors` | 换主题后痕迹构成条 + 首页 slip 同步 |
| **T8** | 外观设置 UI | §2 排版 + swatch + Accordion + 预览条 | 选主题 → **T3～T7 已接好**，全 App 即时生效 |
| **T9** | 全库 31×2 JSON | 补全色值 + contrast 脚本/人工表 | 每 theme dark 正文 ≥4.5:1 |
| **T10** | 会员门控 | unlock 矩阵 §3.2 + 过期回退 + `MemberPricingView` 脚注 | 非会员 / 过期 / lifetime 边界全过 |
| **T11** | 分享图 | `ShareCardTheme` ← theme；`shareCardUsesAppTheme` toggle | 导出 PNG 与 App 同色 |
| **T12** | 全量 QA | §十二矩阵 100% + 性能抽检 | 无漏屏、无 crash、切换 <200ms 主观无卡 |

**Phase 顺序不可跳**：T8（设置 UI）排在 T3～T7 **之后**，避免「能选不变色」。

---

## 八、架构要求（防漏）

### 8.1 推荐目录

```text
NativeDemoApp/Theme/
  ThemeCatalog.json          # 31 themes × 2 modes
  ThemeTokens.swift          # Codable struct，15+ tokens
  ThemeResolver.swift        # resolve(id, appearance) → cached ThemeTokens
  AppTheme.swift             # EnvironmentKey + View extension
  AppColors+Theme.swift      # static var accent { ThemeResolver.current.accent }
  CategoryColors.swift       # HomeItem.Category → theme.categoryColors[i]
  ThemeContrastReport.md     # T9 人工/contrast 记录（可选）
```

### 8.2 AppColors 迁移规则

```swift
// 前（删 hex）
static let accent = Color(red: 0.498, ...)

// 后
static var accent: Color { ThemeResolver.shared.colors.accent }
```

所有 View **继续写 `AppColors.accent`** 即可，不强制改调用点——降低漏改风险。  
**例外**：§十 C 组必须改为读 theme 或删除。

### 8.3 扩展 token（AppColors 现有字段全覆盖）

除 §5.2 外，JSON 必须包含现有 `AppColors` 全部 key，避免 Settings 等专用色遗漏：

```text
panel, panelStrong, line, paperBorder, paperCrease, paperMist,
tabActiveBg, tabInactiveBg, tabInactiveGlyph,
floatingPetPanel, settingsIdentityPanel, settingsChapterPanel,
tracePlaybackButtonBg, traceAppendixBg, monthlyInsightBg,
settingsEnvelopeIvory/Warm/Mint/Sage/DeepSage（或合并为 settings* 5 token）
```

`xuzhang_default` 的 light 值 **必须与当前 AppColors 像素级一致**（回归基准）。

---

## 九、验收清单（按模块）

### 9.1 设置页
- [ ] Tile subtitle：`{明暗} · {主题名}`
- [ ] §1 明暗 / §2 主题分区；helper 文案
- [ ] 免费 3 / 会员 Accordion / lifetime 区
- [ ] 选中 swatch 后 **全 App 变色**（非仅设置页）
- [ ] 恢复默认 → `xuzhang_default` + appearance 可选是否联动 system

### 9.2 会员
- [ ] §10.1 五条未改；脚注或折叠第 6 条
- [ ] free / monthly / yearly / lifetime 矩阵 §3.2
- [ ] 过期：回退 default + 不锁明暗
- [ ] 云端 sync：`colorThemeId` 随 settings；服务端校验 tier（若已有 sync 通道）

### 9.3 无障碍与性能
- [ ] 31×2 contrast 表归档
- [ ] 高饱和主题正文不用 accent
- [ ] 主题切换无 main thread 卡顿；列表滚动 FPS 与 default 主题无明显差

---

## 十、漏项清单（颜色孤岛 · 必须清零）

### A 组 · AppColors 引用文件（~900 处 · 通过 accessor 自动受益，但需走查）

| 文件 | AppColors 约 | T4/T5 优先级 |
|------|-------------|--------------|
| `StatsWebView.swift` | 103 | P0 |
| `SettingsView.swift` | 94 | P0 |
| `InsightWebView.swift` | 90 | P0 |
| `HomeView.swift` | 74 | P0 |
| `OCRConfirmSheet.swift` | 69 | P1 |
| `ContentView.swift`（含 Tab/RecordEditSheet） | 62 | P0 |
| `RecordView.swift` | 56 | P0 |
| `SummaryPlaybackSheet.swift` | 51 | P1 |
| `MemberPricingView.swift` | 44 | P1 |
| `ScenePackAngleSheet.swift` | 24 | P1 |
| `LifeEntryPreviewCard.swift` | 17 | P1 |
| `ScenePackSectionView.swift` | 13 | P2 |
| `MinimalOnboardingSheet.swift` | 6 | P2 |
| `StatCardView.swift` | 待 grep | P2 |

### B 组 · Sheet / 弹层（T5 必须逐个打开走查）

| UI | 入口 |
|----|------|
| `RecordEditSheet` | 首页/痕迹编辑 |
| `OCRConfirmSheet` | 记账 OCR |
| `SummaryPlaybackSheet` | 听听这一段 |
| `ScenePackAngleSheet` | 场景包 |
| `MemberPricingView` | 会员 |
| `MinimalOnboardingSheet` | 新手引导 |
| Settings sheets | 备份/外观/陪伴/隐私 |
| Account sheet | 账号会员 |
| Stats sheets | period/category/trace detail |
| Alert / Confirmation overlay | Settings 删账等 |

### C 组 · 本地硬编码色（T6 必须改或删）

| 位置 | 问题 |
|------|------|
| `StatsWebView.traceClueColor` | 8 色 switch 独立于 AppColors |
| `StatsWebView.traceAccentColor` | 同上 |
| `SettingsView.settingsInkAccent` 等 6 色 | 信封/Tile 专用 palette |
| `ContentView` Tab 宠物/红点 `Color(red: 1.0, 110/255...)` | 硬编码 |
| `InsightWebView.ShareCardTheme.journal` | 分享图独立 theme |
| `StatsWebView.traceGlassPanel` tint 参数 | 局部 accent.opacity |
| 各 View `Color.white.opacity(0.xx)` | **保留**（语义透明），但 stroke/fill 应用 `theme.surface` 替代 white  where 表示卡片底 |

### D 组 · 非 View 漏项

| 项 | 处理 |
|----|------|
| `LocalStore` / settings encode | `colorThemeId` 字段 |
| `LedgerSyncService` settings sync | 若同步 settings JSON，带上 theme |
| `App Icon / Launch Screen` | **不跟主题**（系统级） |
| Widget / Live Activity | 暂无则 N/A；有则 default only |
| 截图 /  App Store | 用 default 主题素材 |

### E 组 · 状态边界（T10）

| 场景 | 期望 |
|------|------|
| 非会员选会员 theme | 拦截 + 会员页；**不写入** id |
| 会员过期且当前为会员 theme | 启动回 default + toast |
| lifetime 主题 + monthly 用户 | 拦截 + 提示升级永久 |
| 登录换机 sync | theme 从云端恢复；tier 不符则回 default |
| 系统 dark + 主题 dark token | 正确取 `modes.dark` |
| 系统 light + 霓虹深渊 | 取 `modes.light`（深色系主题 light 仍可以是深色 UI） |

---

## 十一、Modifier 与组件（T4 子任务）

以下 **ContentView** 内 modifier 必须读 theme，否则大面积漏色：

| 组件 | 文件 |
|------|------|
| `GlassPanel` | ContentView.swift |
| `PaperChapterPanel` | ContentView.swift |
| `traceGlassPanel` | StatsWebView.swift |
| `webCardBackground` / `webAppearanceButton` | SettingsView.swift |
| `bgGradient` / `topBar` / `tabBar` | ContentView.swift |
| 宠物浮动 panel | ContentView.swift |

---

## 十二、QA 矩阵（T12 全量 · 抽测最小集）

**维度**：`5 Tab × 3 appearance × 3 theme（default / 霓虹 / 纸境留白）= 45 格**

每格检查：背景、Tab 选中色、主卡片、主按钮、分类色条、Sheet 任一个。

| 屏 | 必测点 |
|----|--------|
| 今天 | Hero、slip 列表、宠物 panel |
| 记下 | 分类 chip、场景包、OCR 入口 |
| 痕迹 | 生活/线索 Tab、Hero、构成条、多看一层 |
| 复盘 | 章节卡、分享图预览 |
| 我的 | 四宫格 Tile、外观 Sheet |

**主题切换瞬态**：连切 5 个主题 × 快速切换 Tab，无 crash、无色块闪白。

---

## 十三、@ 文件

@NativeDemoApp/Views/SettingsView.swift
@NativeDemoApp/Models/AppSettings.swift
@NativeDemoApp/ContentView.swift（AppColors）
@NativeDemoApp/Views/MemberPricingView.swift
@PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md（§10.1）
@PROMPT_UI-痕迹-iOS线索视图色彩层级优化.txt（分类色盘对齐）
