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

### 4.8 Lifetime 专属（3 · 见 §6.1-L 完整 token）

| id | 显示名 | 唤醒度 | 心理一句话 |
|----|--------|--------|------------|
| `lifetime_archive_gold` | 永享·档案金章 | 1.5 | 博物馆档案 + 古铜印鉴，**最耐用**，可替代默认 |
| `lifetime_gilded_circuit` | 永享·金线电路 | 2.0 | slate 沉金 PCB，理性结构感 |
| `lifetime_neon_cathedral` | 永享·琥珀礼拜堂 | 2.5 | 靛色 vault + 琥珀光束，夜间复盘（非 club 霓虹） |

> 色值、light/dark、分类色、验收：**§6.1-L**（禁止 §6.4 算法推导）。

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

> **全库科学配色 v1**：本章 §6.0～§6.4 为 **T1.5 / T9 唯一色值来源**；`ThemeCatalog.json` 须与本章一致。Lifetime 完整 token 另见 **§6.1-L**。

---

## 六、全库科学配色（色彩心理学精调 v1）

### 6.0 共用规则（31 款必守）

| 规则 | 参数 | 原因 |
|------|------|------|
| **分类色 Morandi** | S 35～45%，L 58～68%，8 色跨度 ≤12% | 读数据不靠「谁更艳」 |
| **正文色** | 永远不用 accent 写段落 | 高饱和 = 高唤醒 = 焦虑 |
| **lockGold** | 统一 `#C9A64A`（**禁止** `#FFD700`） | 会员锁 ≠ 警告黄 |
| **accent 预算** | 仅 Tab 选中 / 主 CTA / 今日 / TOP1 Chip | 防全页发绿/发粉 |
| **对比度** | 正文 ≥ 4.5:1，角标 ≥ 3:1 | WCAG + 长看耐用 |
| **赛博族** | UI chrome 可亮；**categoryColors 仍 Morandi** | 风格 ≠ 数据彩虹 |

**唤醒度分级（选皮 / swatch 排序用）**

```text
1.0–2.0  日常长看：默认、纸境、气象晨雾、自然苔藓、休眠、档案金章
2.0–2.8  复盘分享：晚霞、全息、舱窗晨、朱砂、lifetime 礼拜堂/金线
2.8–3.5  表达身份：赛博三款、雷阵雨、安全橙 — 不宜长期当主皮
```

**T1.5 任务（JSON 刷新）**：T1 基础设施已完成后，**只更新 `ThemeCatalog.json` 色值**对齐本章，不改 Swift。

---

### 6.0-A 31 款唤醒度总览

| id | 显示名 | tier | 唤醒 | 心理一句话 | cat盘 |
|----|--------|------|------|------------|-------|
| `xuzhang_default` | 叙账默认 | free | 1.4 | 青绿+暖纸，平衡被照顾 | A |
| `paperverse_blank` | 纸境·留白 | free | 1.6 | 宣纸留白，淡朱砂标记 | A |
| `mood_weather_clear` | 气象·晴云 | free | 1.5 | 天青开阔，低威胁 | B |
| `paperverse_seal` | 纸境·朱砂印 | std | 2.0 | 一点红印，郑重不怒 | C |
| `paperverse_ink_wash` | 纸境·湿墨 | std | 1.8 | 水墨晕染，痕迹感 | A |
| `paperverse_typecase` | 纸境·活字排 | std | 1.7 | 木活字褐，叙账排版 | C |
| `paperverse_faint_spectrum` | 纸境·淡彩谱 | std | 1.6 | 低饱和色卡，安静 | A |
| `mood_weather_dusk` | 气象·晚霞账 | std | 2.2 | 暮橙紫，月末复盘 | C |
| `mood_weather_mist` | 气象·薄雾晨 | std | 1.5 | 雾蓝灰，记录少也 calm | B |
| `mood_weather_storm` | 气象·雷阵雨 | std | 3.0 | 铅云电紫，集中支出日 | D |
| `mood_weather_aurora` | 气象·极光夜 | std | 2.8 | 绿紫极光，夜间能量 | D |
| `mood_weather_tide` | 气象·潮汐日志 | std | 1.8 | 潮汐蓝，周期感 | B |
| `bio_moss_terminal` | 自然·苔藓终端 | std | 1.6 | 苔藓绿，可持续 calm | A |
| `bio_coral_data` | 自然·珊瑚数据 | std | 2.0 | 珊瑚暖粉，有生命感 | C |
| `bio_mycelium` | 自然·菌丝网络 | std | 1.8 | 孢子金褐，连接感 | C |
| `bio_photosynth` | 自然·光合界面 | std | 1.7 | 新叶绿，成长习惯 | A |
| `orbital_window_dawn` | 太空·舱窗晨 | std | 2.2 | 舷窗晨橙，一天开始 | C |
| `orbital_zero_g` | 太空·无重力清单 | std | 1.9 | 冷白灰，效率清单 | B |
| `orbital_deep_stamp` | 太空·深空邮戳 | std | 2.0 | 邮戳红，记录寄出 | C |
| `orbital_sleep_mode` | 太空·休眠模式 | std | 1.4 | 休眠蓝，夜间护眼 | B |
| `brutal_concrete` | 工业·清水混凝土 | std | 1.8 | 灰阶块面，零装饰 | A |
| `brutal_safety_orange` | 工业·安全橙点 | std | 3.2 | 一点橙，仅 CTA | A |
| `brutal_grid_paper` | 工业·网格纸 | std | 1.7 | 网格蓝，表格清晰 | B |
| `cyber_neon_abyss` | 霓虹深渊 | std | 3.4 | 深紫品红，沉浸 mystery | D |
| `cyber_vector_camouflage` | 矢量迷彩 | std | 3.2 | 哑荧光绿，硬核不刺眼 | D |
| `cyber_holographic_dusk` | 全息黄昏 | std | 2.6 | 橙粉+青，最耐看的赛博 | D |
| `cyber_crystal_overload` | 晶体过载 | std | 3.3 | 冰蓝紫，脉冲能量 | D |
| `cyber_silicon_vesper` | 硅基晚祷 | std* | 2.8 | 暗紫香槟；lifetime 门控展示 | D |
| `lifetime_archive_gold` | 永享·档案金章 | life | 1.5 | 古铜档案，最耐用 | A |
| `lifetime_gilded_circuit` | 永享·金线电路 | life | 2.0 | slate 沉金，结构感 | B |
| `lifetime_neon_cathedral` | 永享·琥珀礼拜堂 | life | 2.5 | 靛 vault + 琥珀光 | D |

\* `cyber_silicon_vesper` 标准库展示，unlock 需 lifetime。

---

### 6.0-B 分类色 Morandi 四套（全主题复用）

```text
顺序：交通 · 餐饮 · 日用 · 购物 · 健康 · 社交 · 居家 · 住宿

A·中性 Morandi（默认/纸境/工业灰/lifetime 档案/苔藓/湿墨/淡彩/混凝土）
#6A9FA8 #B8957A #8FA888 #A892A8 #7FA882 #C4A67A #A89888 #8A96AA

B·冷灰 Morandi（气象/太空/网格/金线电路/休眠/潮汐/薄雾晨/晴云 dark）
#688898 #A89078 #789078 #908898 #689078 #B8A070 #988878 #788898

C·暖灰 Morandi（晚霞/珊瑚/舱窗/朱砂/菌丝/活字/邮戳/留白 accent 区）
#789098 #B89878 #8A9880 #A89088 #80A080 #C8A878 #A89880 #909088

D·紫灰 Morandi（赛博全系/极光/雷阵雨/硅基/琥珀礼拜堂 dark）
#7888A0 #A88878 #889078 #9888A8 #78A088 #B8A078 #988890 #8888A0
```

**dark mode 分类色**：同盘 hue，各通道 +8～12 亮度（或 §6.3 微调），**禁止**换盘。

---

### 6.0-C 主题 → 色盘分配

| 主题族 | cat 盘 |
|--------|--------|
| 默认、纸境（留白/湿墨/淡彩）、工业混凝土、lifetime 档案、苔藓、光合 | A |
| 气象（晴云/薄雾/潮汐/休眠）、太空（无重力）、网格纸、lifetime 金线 | B |
| 晚霞、珊瑚、舱窗晨、朱砂、菌丝、活字、邮戳、留白 | C |
| 赛博 5 款、极光、雷阵雨、硅基、lifetime 琥珀礼拜堂 | D |

---

### 6.1 叙账默认 · xuzhang_default（free · 回归基准 · 像素级勿改）

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
  categoryColors: [A 盘]
dark:
  background: "#0F1422"
  backgroundGradientEnd: "#121828"
  surface: "#192134"           # opacity 0.58
  surfaceWarm: "#1A2332"
  surfaceMuted: "#252D3D"
  stroke: "#94ABD3"              # opacity 0.21
  textPrimary: "#ECF1FF"
  textSecondary: "#9EABC2"
  textTertiary: "#7A8799"
  accent: "#78AE9E"
  accentDark: "#6A9E8E"
  lockGold: "#C9A64A"
  heroGradientPink: "#806878"
  heroGradientTeal: "#587878"
  categoryColors: [A 盘 dark +10% 亮度]
```

---

### 6.2 全库主 token 科学精调（light / dark）

> 每款列：`bg` / `accent` / `textPrimary` / `surfaceWarm` / `cat`（盘号）；`lockGold` 均为 `#C9A64A`；光斑 heroGradientPink/Teal 实现时 opacity **0.18～0.28**。  
> **Lifetime 3 款**不列于此表，见 **§6.1-L** 完整 YAML。

#### 6.2.1 免费（3）

**纸境·留白** `paperverse_blank` · A · 1.6  
| mode | bg | accent | textPrimary | surfaceWarm |
|------|-----|--------|-------------|-------------|
| light | `#F7F3EA` | `#B85C5C` | `#1C1C1C` | `#F7F3EA` |
| dark | `#1A1814` | `#C87070` | `#F0ECE4` | `#2A2824` |

**气象·晴云** `mood_weather_clear` · B · 1.5  
| light | `#F0F8FF` | `#7EB8D4` | `#2A3A4A` | `#FFF8F0` |
| dark | `#141C24` | `#8EC8E4` | `#E8F2F8` | `#1A2430` |

#### 6.2.2 纸境东方（4）

| id | cat | 唤醒 | light bg / accent / text | dark bg / accent / text |
|----|-----|------|-------------------------|-------------------------|
| `paperverse_seal` | C | 2.0 | `#F8F2EA` / `#B84848` / `#1E1A18` | `#1C1614` / `#C85858` / `#F0E8E0` |
| `paperverse_ink_wash` | A | 1.8 | `#F4F6F8` / `#486878` / `#1A2024` | `#141820` / `#587888` / `#E8EEF2` |
| `paperverse_typecase` | C | 1.7 | `#F2EDE4` / `#8B7355` / `#242018` | `#1E1A14` / `#9B8365` / `#ECE4D8` |
| `paperverse_faint_spectrum` | A | 1.6 | `#FAF8F6` / `#9090A8` / `#282830` | `#1E1C20` / `#A0A0B8` / `#EEECF0` |

#### 6.2.3 情绪气象（5）

| id | cat | 唤醒 | light bg / accent / text | dark bg / accent / text |
|----|-----|------|-------------------------|-------------------------|
| `mood_weather_dusk` | C | 2.2 | `#F5EEEA` / `#C87848` / `#2A2420` | `#2A2228` / `#D88858` / `#F0E8E0` |
| `mood_weather_mist` | B | 1.5 | `#E8EEF0` / `#88A8B8` / `#2A3238` | `#1A2024` / `#98B8C8` / `#E8EEF2` |
| `mood_weather_storm` | D | 3.0 | `#E4E8EE` / `#6878A0` / `#222830` | `#141820` / `#7888B0` / `#E4E8F0` |
| `mood_weather_aurora` | D | 2.8 | `#EEF2F4` / `#58A888` / `#1E2824` | `#0E1418` / `#68B898` / `#E8F4F0` |
| `mood_weather_tide` | B | 1.8 | `#EAF0F2` / `#5898A8` / `#243038` | `#121C22` / `#68A8B8` / `#E4F0F4` |

> **雷阵雨 / 极光 light**：背景 intentionally 浅灰/浅绿（「气象报告」语义），非误标 dark。

#### 6.2.4 自然演算（4）

| id | cat | 唤醒 | light bg / accent / text | dark bg / accent / text |
|----|-----|------|-------------------------|-------------------------|
| `bio_moss_terminal` | A | 1.6 | `#EEF0EA` / `#6A9870` / `#222820` | `#141A14` / `#7AA880` / `#E8EEE8` |
| `bio_coral_data` | C | 2.0 | `#F5EEEC` / `#C88878` / `#2A2220` | `#201814` / `#D89888` / `#F0E8E4` |
| `bio_mycelium` | C | 1.8 | `#F0ECE6` / `#A89070` / `#282420` | `#1A1814` / `#B8A080` / `#ECE6DE` |
| `bio_photosynth` | A | 1.7 | `#EEF4EA` / `#78B068` / `#222820` | `#121A10` / `#88C078` / `#E8F2E4` |

#### 6.2.5 太空通勤（4）

| id | cat | 唤醒 | light bg / accent / text | dark bg / accent / text |
|----|-----|------|-------------------------|-------------------------|
| `orbital_window_dawn` | C | 2.2 | `#F5F0EC` / `#D88858` / `#2A2428` | `#181420` / `#E89868` / `#F0E8E0` |
| `orbital_zero_g` | B | 1.9 | `#F0F2F6` / `#586878` / `#222830` | `#101418` / `#687888` / `#E8ECF2` |
| `orbital_deep_stamp` | C | 2.0 | `#ECEEF2` / `#A85858` / `#242028` | `#121418` / `#B86868` / `#ECE8EC` |
| `orbital_sleep_mode` | B | 1.4 | `#E8ECF0` / `#688898` / `#283038` | `#0E1218` / `#7898A8` / `#E4ECF2` |

#### 6.2.6 工业柔光（3）

| id | cat | 唤醒 | light bg / accent / text | dark bg / accent / text |
|----|-----|------|-------------------------|-------------------------|
| `brutal_concrete` | A | 1.8 | `#ECECEC` / `#606060` / `#1A1A1A` | `#181818` / `#909090` / `#ECECEC` |
| `brutal_safety_orange` | A | 3.2 | `#F2F2F2` / `#D85018` / `#1A1A1A` | `#1A1A1A` / `#E86028` / `#F0F0F0` |
| `brutal_grid_paper` | B | 1.7 | `#F4F4F8` / `#6888B0` / `#242830` | `#181820` / `#7898C0` / `#ECEEF4` |

> **安全橙**：分类色用 **A 盘灰阶**，**禁止** category 重复 `#FF5F1F`。

#### 6.2.7 赛博朋克（5 · UI 亮 / 分类 Morandi 盘 D）

| id | 唤醒 | light bg / accent / text | dark bg / accent / text | 备注 |
|----|------|-------------------------|-------------------------|------|
| `cyber_neon_abyss` | 3.4 | `#EEEAF2` / `#B84888` / `#2A2230` | `#0E0818` / `#D85898` / `#F0E8F8` | dark 为 UI 场；**非** light 标 dark |
| `cyber_vector_camouflage` | 3.2 | `#E8EEE8` / `#5A9858` / `#1E281E` | `#141A14` / `#68A862` / `#E4F0E4` | accent 哑光绿 |
| `cyber_holographic_dusk` | 2.6 | `#F2ECEF` / `#D87868` / `#2A2228` | `#1A1418` / `#E88878` / `#F0E8EC` | 赛博最耐用 |
| `cyber_crystal_overload` | 3.3 | `#E8F0F4` / `#48A8B8` / `#1E2830` | `#080818` / `#58B8C8` / `#E8F4F8` | |
| `cyber_silicon_vesper` | 2.8 | `#F0ECEF` / `#9888A8` / `#282430` | `#141018` / `#A89860` / `#F0ECF0` | unlockTier lifetime |

> **旧版禁止项**：`#FF2D9A` / `#39FF14` / `#00FFFF` 作 categoryColors；`#FFD700` 作 lockGold。

---

### 6.3 与旧版 T1 JSON 差异（T1.5 必改清单）

| 旧问题 | 新方案 |
|--------|--------|
| 赛博 category 满饱和霓虹 | 统一 Morandi **盘 D** |
| 多款 `#FFD700` lockGold | 统一 `#C9A64A` |
| 纸境留白 accent `#C84C4C` 过艳 | `#B85C5C` |
| 工业橙 category 重复 accent | 改 **A 盘灰阶** |
| lifetime 金线 light 底 `#0A0A0F` | light 改 `#EEF1F4` slate（见 §6.1-L） |
| lifetime 礼拜堂 `#D946EF` 霓虹 | 改琥珀 `#D4A574`（见 §6.1-L） |
| 仅 light 或算法 dark | 每款 **light/dark 成对人工定** |

---

### 6.4 dark 推导规则（仅作补 token 参考 · Lifetime / 本章表内主题禁用）

```text
background:     light 亮度 × 0.15，饱和 × 0.8
surface:        background 亮度 +8%
textPrimary:    亮度 ≥ 0.90，饱和 ≤ 0.10
textSecondary:  亮度 0.65，饱和 0.08
accent:         light accent 亮度 −5%，饱和 +5%
categoryColors: 同盘 hue，亮度 → 0.65–0.75
```

**T9 验收**：31 款 × 2 mode 须与本章 + §6.1-L 一致；contrast 人工表归档；赛博 category 饱和均值 ≤45%。

---

### 6.1-L  Lifetime 专属 · 完整 token（light + dark · 人工精调）

> **设计约束**：唤醒度 1.5～2.5/5；禁止满饱和霓虹；分类色 Morandi 同明度；Lifetime **禁止 §6.4 算法推导**。

| id | 心理原型 | 最适合 |
|----|----------|--------|
| `lifetime_archive_gold` | 博物馆档案 + 黄铜印鉴 | 日常默认替代、长看痕迹 |
| `lifetime_gilded_circuit` | ENIG 金线 PCB + slate | 偏理性、爱看结构 |
| `lifetime_neon_cathedral` | 暮色彩窗琥珀光 | 夜间复盘、分享图 |

**三款色相分工**：档案=暖｜金线=冷｜礼拜堂=靛+琥珀。**accent 预算**：仅 Tab/CTA/今日/TOP1 Chip。

#### lifetime_archive_gold · 永享·档案金章

**色彩心理学**：暖灰纸 + 古铜 accent → **永久、可信赖、被正式保存**；激活「档案柜 / 蜡封 / 账册」而非「奢侈品橱窗」。古铜 `#A68445` 比亮金 `#FFD700` 唤醒度低约 40%，长看不易烦。

**/helper 文案**：像把这段时间收进档案馆，不抢戏，只更郑重。

```yaml
light:
  background: "#F2EBE0"
  backgroundGradientEnd: "#EBE3D6"
  surface: "#FFFCF7"           # opacity 0.78
  surfaceWarm: "#F7F0E4"
  surfaceMuted: "#E8DFD0"
  stroke: "#D4C8B4"
  textPrimary: "#2A2622"
  textSecondary: "#5C534A"
  textTertiary: "#8A8178"
  accent: "#A68445"
  accentDark: "#8B6F38"
  lockGold: "#A68445"
  heroGradientPink: "#E8D4B8"   # opacity 0.26
  heroGradientTeal: "#C8D0C4"   # opacity 0.20
  categoryColors:
    - "#7A8E96"  # transport  铅灰蓝
    - "#B8957A"  # dining     陶土
    - "#8A9878"  # daily      橄榄灰
    - "#9A8898"  # shopping   藕灰
    - "#7A9478"  # health     苔灰
    - "#C4A67A"  # social     沙金
    - "#A89888"  # home       亚麻
    - "#8890A0"  # lodging    钢灰

dark:
  background: "#1A1714"
  backgroundGradientEnd: "#221E1A"
  surface: "#262220"           # opacity 0.74
  surfaceWarm: "#2A2520"
  surfaceMuted: "#332E28"
  stroke: "#A68445"            # opacity 0.20
  textPrimary: "#F0EBE3"
  textSecondary: "#B8AFA4"
  textTertiary: "#8A8278"
  accent: "#C9A961"
  accentDark: "#A68445"
  lockGold: "#C9A961"
  heroGradientPink: "#A68445"  # opacity 0.12
  heroGradientTeal: "#3A4540"  # opacity 0.16
  categoryColors:
    - "#8A9EA6"
    - "#C8A88A"
    - "#9AAA88"
    - "#AA98A8"
    - "#8AAA88"
    - "#D4B68A"
    - "#B8A898"
    - "#98A0B0"
```

**对比度抽检**：light `textPrimary` on `background` ≈ 11:1；dark `textSecondary` on `surface` ≈ 5.8:1 ✅

---

#### lifetime_gilded_circuit · 永享·金线电路

**色彩 psychology**：Slate 冷灰底 + ENIG 沉金 `#B8985C` → **精密、秩序、连接**；满足「数码感」但不触发 gamer RGB 警觉。灵感：高端 PCB 显微摄影、Braun 工业美学。

**/helper 文案**：像电路板上的金线，细而准，适合爱看结构的人。

```yaml
light:
  background: "#EEF1F4"
  backgroundGradientEnd: "#E6EAEE"
  surface: "#FAFBFC"           # opacity 0.80
  surfaceWarm: "#F4F6F8"
  surfaceMuted: "#E4E8EC"
  stroke: "#C8D0D8"
  textPrimary: "#1C2228"
  textSecondary: "#4A5560"
  textTertiary: "#78848F"
  accent: "#B8985C"
  accentDark: "#9A8048"
  lockGold: "#B8985C"
  heroGradientPink: "#D4C4A8"  # opacity 0.22
  heroGradientTeal: "#A8C0D0"  # opacity 0.24
  categoryColors:
    - "#688898"  # transport  板岩蓝
    - "#A89070"  # dining     铜棕
    - "#789078"  # daily      灰绿
    - "#908898"  # shopping   灰紫
    - "#689078"  # health     板绿
    - "#B8A070"  # social     淡金棕
    - "#988878"  # home       暖灰
    - "#788898"  # lodging    雾蓝

dark:
  background: "#0E1218"
  backgroundGradientEnd: "#141A22"
  surface: "#1A2030"           # opacity 0.76
  surfaceWarm: "#1E2430"
  surfaceMuted: "#252C38"
  stroke: "#B8985C"            # opacity 0.18
  textPrimary: "#E8EDF2"
  textSecondary: "#A0AEB8"
  textTertiary: "#708090"
  accent: "#C9AE7A"
  accentDark: "#B8985C"
  lockGold: "#C9AE7A"
  heroGradientPink: "#B8985C"  # opacity 0.10
  heroGradientTeal: "#284058"  # opacity 0.18
  categoryColors:
    - "#7898A8"
    - "#B8A080"
    - "#88A088"
    - "#A098A8"
    - "#78A088"
    - "#C8B080"
    - "#A89888"
    - "#8898A8"
```

**与档案金章区分**：背景更冷（蓝灰 vs 暖褐）；accent 更「金属沉金」而非「古铜印章」。

---

#### lifetime_neon_cathedral · 永享·琥珀礼拜堂

**色彩心理学**（名称保留「礼拜堂」，执行上 **禁止 club 霓虹**）：深靛 vault `#100E1A` + 琥珀光束 `#D4A574` → ** contemplation、仪式、暮色复盘**。彩窗隐喻：紫灰 ` #6A5890` 作环境光，琥珀作 **唯一暖源**——单一暖点比双色霓虹更耐看（Hülscher 色彩平衡原则）。

**/helper 文案**：像傍晚从彩窗落下的一束光，适合夜间打开复盘。

```yaml
light:
  background: "#EEECF2"
  backgroundGradientEnd: "#E6E4EA"
  surface: "#FAF9FC"           # opacity 0.78
  surfaceWarm: "#F2F0F5"
  surfaceMuted: "#E4E0EA"
  stroke: "#D0CAD8"
  textPrimary: "#221E28"
  textSecondary: "#544E5C"
  textTertiary: "#847E8C"
  accent: "#9E7B6A"
  accentDark: "#856658"
  lockGold: "#A68445"
  heroGradientPink: "#C4A882"  # opacity 0.24  琥珀雾
  heroGradientTeal: "#9080A8"  # opacity 0.18  紫灰窗
  categoryColors:
    - "#708090"  # transport
    - "#B09080"  # dining     偏暖
    - "#809078"  # daily
    - "#9888A0"  # shopping   紫灰
    - "#789078"  # health
    - "#B89878"  # social     琥珀调
    - "#A09088"  # home
    - "#808898"  # lodging

dark:
  background: "#100E1A"
  backgroundGradientEnd: "#161222"
  surface: "#1A1728"           # opacity 0.76
  surfaceWarm: "#1E1A2E"
  surfaceMuted: "#282434"
  stroke: "#D4A574"            # opacity 0.16
  textPrimary: "#EDE8F0"
  textSecondary: "#A8A0B0"
  textTertiary: "#787080"
  accent: "#D4A574"
  accentDark: "#B89060"
  lockGold: "#C9A961"
  heroGradientPink: "#D4A574"  # opacity 0.11  光束
  heroGradientTeal: "#6A5890"  # opacity 0.14  环境靛
  categoryColors:
    - "#8090A0"
    - "#C0A090"
    - "#90A088"
    - "#A898B0"
    - "#88A088"
    - "#C8A880"
    - "#B0A098"
    - "#9098A8"
```

**对比度抽检**：dark `textPrimary` on `background` ≈ 13:1；accent 仅小面积，正文 **禁止** 用 `#D4A574` ✅

### 6.1-L2  Lifetime 验收（T9 必勾）

- [ ] 三款 light/dark 各人工走查 15 分钟，无 eye strain
- [ ] 三款 categoryColors 明度跨度 ≤ 12%（同 mode 内）
- [ ] 与 `xuzhang_default` 比，Lifetime accent 面积占比 ≤ 80%
- [ ] 与 `cyber_neon_abyss` 比，Lifetime 分类色饱和均值 ≤ 45%
- [ ] swatch 上可辨：暖档案 / 冷金线 / 靛琥珀 三色块差异

> **31 款 × light/dark**：**T1.5** 按 §6.0～§6.4 + §6.1-L 刷新 JSON；**T9** contrast 走查全勾。

---

## 七、实现 Phase（13 步 · 慢做闭环）

每 Phase **独立 PR**；合并前必须勾选该 Phase 验收项 + 跑对应 QA 矩阵行。

| Phase | 名称 | 交付物 | 验收标准（摘要） |
|-------|------|--------|------------------|
| **T1** | 基础设施 | `Theme/`：`ThemeCatalog.json`、`ThemeTokens`、`ThemeResolver`、`AppThemeKey` Environment | 单元测试：parse 31 id；resolve light/dark；unknown id → default |
| **T1.5** | 科学配色 JSON | 仅更新 `ThemeCatalog.json` 对齐 **§六** | 31 id 齐全；赛博 category 用盘 D；lockGold 统一；与旧 T1 JSON diff 过 §6.3 |
| **T2** | 数据持久化 | `AppSettings.colorThemeId` + migrate；`SettingsViewModel.setTheme()` 含 unlock 校验 | 杀进程重启后 theme 保留；非法 id 回 default |
| **T3** | 根注入 | `NativeDemoAppApp` / `ContentView` 注入 `@Environment(\.appTheme)`；`AppColors` 改 accessor | 改 `colorThemeId` 后 **Tab 栏 + 顶栏 + 背景渐变** 即时变色 |
| **T4** | 主 Tab 五屏 | `HomeView` `RecordView` `StatsWebView` `InsightWebView` `SettingsView` 主列表 | 五 Tab 内 **零** 旧绿色 accent 残留（霓虹主题走查） |
| **T5** | Sheet / 弹层 | 见 **§十 B 组** 全部 sheet | 打开任一 sheet 颜色与主屏一致 |
| **T6** | 颜色孤岛清理 | 删除/替换 **§十 C 组** 本地色 | `rg "Color\\(red:" NativeDemoApp/Views` 仅剩 Theme 层 |
| **T7** | 分类色统一 | `traceClueColor` / `traceAccentColor` / slip 色条 → `theme.categoryColors` | 换主题后痕迹构成条 + 首页 slip 同步 |
| **T8** | 外观设置 UI | §2 排版 + swatch + Accordion + 预览条 | 选主题 → **T3～T7 已接好**，全 App 即时生效 |
| **T9** | 全库 31×2 JSON | 对照 **§六** 补全 + contrast 人工表 | 每 theme dark 正文 ≥4.5:1；§6.1-L2 全勾 |
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
