# Agent Prompt · Task TAB-NAV — 五 Tab 命名 + 暖 glyph 图标（iOS 主 · Web 同步）

> **状态：待做**  
> **目标**：去掉 demo 期 Tab 名与冷图标，对齐叙账「记 · 叙 · 议」气质  
> **范围**：iOS 必做；`web-preview` tabbar **文案+SVG 同步**（可选同 PR）  
> **禁止**：改 Tab 路由、各页业务逻辑、Playback/会员/记账引擎  
> 用法：整段复制 `PROMPT_底栏导航-任务正文-iOS.txt`

---

## 0. 为什么要改

| 现 Tab | 问题 |
|--------|------|
| 今日 | 与「我的小窝」图标都是房子，混淆 |
| 记一笔 | Tab/页标题不一致（记账） |
| 看看花 | demo 口语，页内是账单+切片 |
| 小 AI 说 | AI 进 Tab 名，违背「先叙后议」 |
| 我的小窝 | 隐喻幼；设置不应叫窝 |

**气质**：暖色 glass（`#7fb3a2` accent）、生活叙事，非工具图标库/SF Symbols 冷感。

---

## 1. 定稿命名（Tab · 顶栏 · 规则）

| case | 新 Tab 名（底栏） | 顶栏 pageTitle | 职责 |
|------|------------------|----------------|------|
| today | **今天** | 今日 | 今日小记、回放、今天痕迹 |
| record | **记下** | 记下这一笔 | life-slip 记账 |
| stats | **痕迹** | 账单与切片 | 流水、筛选、周/月/年回放 |
| insight | **复盘** | 生活复盘 | 周/月复盘；AI 仅在页内 |
| settings | **我的** | 设置 | 账号、会员、偏好 |

**规则**：

- Tab 名：2 字、导航用、短  
- pageTitle：页内语义完整，可与 Tab 不同  
- **禁止** Tab 名出现：小 AI、小窝、看看花、记账（作 Tab）

枚举 `AppTab` case 名 **不改**（`today/record/...`），只改 `title` / `pageTitle`。

---

## 2. 暖 glyph 图标规范

参考 [`LOGO_BRIEF.md`](LOGO_BRIEF.md)：

- 主色：`AppColors.accent`（`#7fb3a2`）
- 未选中：subtext + 少量 accent 混色
- 选中：accent 圆底（opacity ~0.34）+ glyph 略深
- 可保留 **1 个暖色点缀**（如淡粉小圆点），全 Tab 统一语法，不要每颗不同色
- **禁止**：SF Symbols 作为主方案、房子×2、聊天气泡、三心、计算器、硬加号圆

### 五枚隐喻（24×24 viewBox 等效）

| Tab | 造型 | 不要 |
|-----|------|------|
| 今天 | 地平线弧 + 小太阳 / 柔光升起的半圆 | 房子 |
| 记下 | 折角纸条 + 轻竖线或 tiny + | 大圆加号工具钮 |
| 痕迹 | 缓曲线 + 2～3 软圆点（时间线上的点） | 心形、花瓣 |
| 复盘 | 微张双页 / 书页扇形 | 对话气泡 |
| 我的 | 圆肩小人形轮廓（单线或软填） | 房子、齿轮 |

线条：圆角端点、略粗于 1pt 发丝线；造型 **留白 ≥40%**，小尺寸仍可辨。

---

## 3. iOS 实施

### 3.1 文件

```text
NativeDemoApp/ContentView.swift
  - AppTab.title / pageTitle
  - tabIcon / tabXxxGlyph → 重构

推荐新建（二选一，不要两套并存）：
  NativeDemoApp/Views/Components/TabGlyphs/TabGlyphStyle.swift   ← 颜色/选中态
  NativeDemoApp/Views/Components/TabGlyphs/TabTodayGlyph.swift
  NativeDemoApp/Views/Components/TabGlyphs/TabRecordGlyph.swift
  NativeDemoApp/Views/Components/TabGlyphs/TabTracesGlyph.swift
  NativeDemoApp/Views/Components/TabGlyphs/TabReviewGlyph.swift
  NativeDemoApp/Views/Components/TabGlyphs/TabProfileGlyph.swift

或 Assets.xcassets/TabIcons/*.pdf（Template Rendering）+ 薄包装 View
```

### 3.2 要求

- 保持现有 tabBar 布局、选中动画、stats 红点 badge 逻辑  
- `tabIcon(for:isSelected:)` 接口可保留，内部换 glyph  
- 五个 glyph **同一套笔画粗细与圆角半径**  
- Preview：`TabGlyphs_Previews` 展示选中/未选中各一

### 3.3 禁止改

```text
HomeView / RecordView / StatsWebView / InsightWebView / SettingsView 业务
HomeViewModel · PlaybackService · 路由 guidance 判定条件（badge 逻辑可保留）
```

---

## 4. Web 同步（同 PR 建议做）

```text
web-preview/index.html   — tabbar 五个 <span> 文案
web-preview/index.html   — 五个 tab SVG path（与 iOS 隐喻一致）
web-preview/app.js       — pageTitle 映射（若有）
```

保持现有 `.tab-icon` 圆底样式，只换 glyph path 与文字。

---

## 5. 验收

- [ ] 底栏：今天 | 记下 | 痕迹 | 复盘 | 我的  
- [ ] 顶栏 pageTitle 与上表一致  
- [ ] 五个图标隐喻正确、**无重复房子**、无气泡/三心  
- [ ] 选中/未选中对比清晰；与 glass UI 同温  
- [ ] 24pt 视觉可辨；不糊成一团  
- [ ] Tab 切换、stats 引导红点、各页功能不回归  
- [ ] Web tabbar 文案+图标与 iOS 一致（若本轮含 Web）

---

## 6. 禁止

- 改 Tab 数量、顺序、case 枚举名  
- 用 SF Symbols 替换全部自定义 glyph（可作 fallback 注释，不得上线）  
- git commit（除非用户要求）

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版：命名定稿 + 暖 glyph brief |
