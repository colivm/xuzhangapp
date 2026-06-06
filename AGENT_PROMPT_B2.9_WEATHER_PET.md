# Agent Prompt · Task B2.9 — 天气场景宠物陪伴（仅 iOS）

> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**（作规则对照源）。  
> 可与 **B2.8** 合并一次 PR：先 B2.8 → 再 B2.9，验收分节勾选（见文末）。

---

## 任务编号对照（必读）

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| **B2.8** | 智能分类推荐 | `CategoryRecommendService` | ⏳ 另任务 / 可合并 |
| **B2.9** | **天气宠物陪伴**（本 prompt） | `WeatherCompanionService` + `PetCompanionService` | ⏳ **待做** |
| **B2.10** | 场景备注池 | `ScenePackCopyPool.swift` | ✅ 已完成 |

设置里已有 `petCompanionEnabled`、`weatherCompanionEnabled` 开关，但 iOS **未接** Open-Meteo / 场景规则；记完账 `petMessage` 仍是 4 条固定句；点宠物按钮有 **管控式** 硬编码（须替换）。

---

## @ 文件（Agent 必须先 Read）

```text
@AGENT_PROMPT_B2.9_WEATHER_PET.md
@IMPLEMENTATION_FOR_CODEX.md
@PRODUCT_NORTH_STAR.md
@web-preview/app.js
@NativeDemoApp/ContentView.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/ViewModels/SettingsViewModel.swift
@NativeDemoApp/Views/SettingsView.swift
@NativeDemoApp/Models/AppSettings.swift
@NativeDemoApp/Info.plist
@TEST_CASES_v0.1.md
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task B2.9 — 天气场景宠物陪伴**（iOS 对齐 Web 本地规则；**不接 AI 作默认路径**）。

## 背景（北极星）
宠物是「省力记 + 温柔陪伴」，**不审判、不建议省钱、不骂乱花钱**。禁止管控式 copy（如「餐饮偏多、明天带饭」）。

## 现状（iOS）
- `AppSettings.petCompanionEnabled` / `weatherCompanionEnabled` 已有；Settings 有开关 UI
- `HomeViewModel.addManualRecord` 成功后：`petMessage` = 4 条固定 random（须改）
- `ContentView.petWidget` 点击：硬编码含「今天餐饮偏多，明天可以试试自己带饭」→ **必须删除**，对齐 Web `companion` / `lightScene`
- 无 CoreLocation、无 Open-Meteo、无 `PET_SCENE_RULES`

## 必须先 Read（Web 为唯一规则源，逐段移植）
`web-preview/app.js`：
- `petCopy`（companion / recordSaved / lightScene / weatherHint / weatherContext / weatherAiFallback）
- `PET_SCENE_RULES`（hotNoCool / rainyHome / monthEndSoft / weekendHealing / commuteSteady / groceryWarm / highSpendComfort / noExpenseCalm）
- `buildContextualPetMessage(recordLike)` — 记完账气泡主逻辑
- `fetchWeatherSnapshot` / `refreshWeatherInBackground` — Open-Meteo，缓存 30min
- 辅助：`isLateNight` / `isDrinkOrSnack` / `commuteExpenseCountToday` / `hasCoolingExpenseToday` / `isRainyWeatherCode` 等
- 宠物按钮 click（Web L4540+）：天气开 → 场景句；否则 companion / lightScene

**P2 不做**：`buildWeatherSpendPetMessage` 远程 AI（v0.1 只用 `weatherAiFallback` 本地句或不调用）

## 必做 — 新建 Service

### 1. `WeatherCompanionService.swift`
- CoreLocation `whenInUse`；坐标缓存 30min
- `fetchWeatherSnapshot()` → `{ temp, weatherCode, ts }` 对齐 Web
- GET `https://api.open-meteo.com/v1/forecast?latitude=…&longitude=…&current=temperature_2m,weather_code`
- 拒绝/无权限 → nil，不崩溃、不阻塞记账
- `startBackgroundRefresh()` / `stopBackgroundRefresh()` — 与设置开关联动

### 2. `PetCompanionCopy.swift`（或内嵌常量文件）
- Swift 移植 `petCopy` + `PET_SCENE_RULES` match 闭包/函数
- `{petName}` ← `AppSettings.petNickname`，空则「小窝」
- 文案须与 Web 语义一致（可微调标点，禁止新增预算/管控句）

### 3. `PetCompanionService.swift`
```swift
buildContextualMessage(
  record: HomeItem?,
  weather: WeatherSnapshot?,
  settings: AppSettings,
  todayItems: [HomeItem]
) async -> String
```
逻辑对齐 Web `buildContextualPetMessage`：
1. `!weatherCompanionEnabled` → recordSaved 随机；偶发 weatherHint（带冷却，勿每次弹）
2. 无定位权限 → 温柔 fallback + 偶发 weatherHint
3. 有天气 → `PET_SCENE_RULES` 优先级第一条
4. 补充：coldDrink / weekendRelax / lateNightSnack
5. 兜底 recordSaved

另提供 `companionMessage(settings:)` / `lightSceneMessage()` 供宠物 **点击** 使用（对齐 Web pet click）

## 必做 — 接入点

### HomeViewModel
- `addManualRecord` 成功、`importOCRDrafts` 成功（可选至少 manual）：异步设置 `petMessage`
- 使用 **缓存天气**；勿阻塞 UI >100ms（先本地句，天气后台 refresh）
- 尊重 `petCompanionEnabled == false` → 不设置 petMessage

### ContentView.swift
- `petWidget` 点击：调用 `PetCompanionService`（非硬编码 4 句 + 禁止管控句）
- 已有 `.onChange(homeViewModel.petMessage)` 气泡展示逻辑保留
- 仅 `petCompanionEnabled` 时显示宠物 widget（若现有逻辑未 gate，补上）

### SettingsView + SettingsViewModel
- 开「天气场景暖心互动」→ 请求定位权限 + `WeatherCompanionService.startBackgroundRefresh()`
- 关 → `stopBackgroundRefresh()`，不清 pet 开关
- 关「宠物陪伴」→ 停天气 refresh（可选）+ 隐藏宠物 UI

### Info.plist
- 新增 `NSLocationWhenInUseUsageDescription`（中文）：用于根据本地天气生成温柔陪伴提醒，可随时在设置关闭；**不上传账单**

## 开关矩阵（必须实现）

| 宠物陪伴 | 天气互动 | 行为 |
|----------|----------|------|
| 关 | * | 不显示宠物 / 无 petMessage |
| 开 | 关 | recordSaved / companion / lightScene |
| 开 | 开 | 完整场景 + 天气规则 |

## 禁止
- 改 B2.8 分类推荐、ScenePackCopyPool、生活切片、StoreKit、小 AI 说
- 上传账单到天气 API（仅 lat/lon → open-meteo）
- 新增「省钱/带饭/餐饮偏多/控制预算」类宠物句
- 改 web-preview
- git commit 除非用户明确要求

## 验收（iOS）
- [ ] 设置开「天气互动」→ 首次定位权限弹窗
- [ ] 记一笔后气泡 **非** 固定 4 句之一（场景或 recordSaved 轮换）
- [ ] 雨天（可 mock weatherCode）→ rainyHome 类语境
- [ ] 高温且无冷饮消费 → hotNoCool 类提示
- [ ] 关天气 → 记完账仍有 recordSaved；无强制定位
- [ ] 关宠物 → 无气泡 / 无 widget
- [ ] 拒定位 → 不崩溃；通用句 + weatherHint 偶发（有冷却）
- [ ] 点宠物 → companion/lightScene，**无**「餐饮偏多/带饭」
- [ ] TC-REC-15（TEST_CASES_v0.1.md）可勾选

## 交付
1. 改动文件列表
2. Info.plist 定位说明原文
3. 与 Web 规则对照表（移植了哪些 rule）
4. 验收勾选
5. 未做项（远程 AI 天气句、Web 同步、前往设置深链）

最小 diff；先 Read Web 再移植。
```

---

## 与 B2.8 合并发送（可选）

若一次 PR 完成「记账更聪明 + 宠物有温度」，**同一条消息**内按顺序粘贴：

1. 整段 [`AGENT_PROMPT_B2.8_SMART_CATEGORY.md`](AGENT_PROMPT_B2.8_SMART_CATEGORY.md) 「复制发送」
2. 空一行
3. 整段 **上文「复制发送」**
4. 末尾加一句：

```text
## 合并交付顺序
先做 B2.8 CategoryRecommendService 并验收 → 再做 B2.9 天气宠物。
两个任务分别列出改动文件与验收勾选；禁止顺带改 ScenePackCopyPool / 生活切片。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-06 | 首版：B2.9 独立 prompt；合并 B2.8 说明；强调删管控式宠物句 |
