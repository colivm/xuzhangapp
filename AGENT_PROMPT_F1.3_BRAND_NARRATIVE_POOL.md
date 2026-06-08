# Agent Prompt · Task F1.3 — 品牌叙事池（仅 iOS）

> **状态：iOS 代码已完成（待 TestFlight 验收）**  
> 战略依据：[`RECORDING_CHAIN_VISION_v0.1.md`](RECORDING_CHAIN_VISION_v0.1.md) — **缩短记账链路、叙事自动长出来**  
> 依赖：**F1.2 OCR 回归完成后**再开（数据正确优先）；可与 B2.13 分 PR，但须共用 `NarrativeCopyResolver`。  
> 用法：**整段复制下方「复制发送」** 发给 Agent。  
> **仅 iOS**；`web-preview` 本轮 **不要改**。

---

## 任务编号对照

| ID | 做什么 | 主要文件 | 状态 |
|----|--------|----------|------|
| F1.2 | OCR 真机回归 | `OCRService` 等 | ✅ 已完成 |
| **F1.3** | **本 prompt · 品牌词典 + 专用叙事池** | `MerchantBrandCatalog` + `NarrativeCopyResolver` | ✅ 代码完成 · ⏳ TF 验 |
| F1.3b | Logo 图像匹配（可选二期） | Vision feature print | 📋 未纳入本 PR |
| B2.13 | 个人习惯预填 | `RecordPrefillService` | ⏳ 见另 prompt |

---

## 产品结论（Agent 须先理解）

**文案与 UI 并列重要。** 明确识别出品牌时，必须用 **该品牌调性的专用文案池**；识别不到则走通用池（ScenePack / 分类 contextual），**禁止**用 A 品牌话术贴 B 品牌。

**叙事句，非广告句：**

- ✅ 「早班路上，顺手续一口」
- ❌ 「小蓝杯，年轻就要瑞幸」

过 [`CATEGORY_SCENE_COPY_AUDIT_v0.1.md`](CATEGORY_SCENE_COPY_AUDIT_v0.1.md) §2 问句 + 禁止词表。

---

## 数据模型

### `HomeItem` 扩展（Codable 向后兼容）

```swift
var merchantBrandId: String?  // nil = 未识别或低置信；写回用于改金额/分类时重算 emotion
```

`title` 仍存备注/商户名；`emotionTag` 存最终展示句（列表胶囊）。

### `MerchantBrandDefinition`

```swift
struct MerchantBrandDefinition {
    let id: String              // e.g. "luckin"
    let displayName: String     // 「瑞幸咖啡」
    let aliases: [String]       // OCR/备注命中，大小写不敏感
    let category: HomeItem.Category
    let tiers: [ScenePackTier]  // 复用 ScenePackCopyPool 的 tier 结构
    // 可选：toneNote: String — 仅注释，给文案审计，不进 UI
}
```

### `NarrativeCopyResolver`（本 PR 必建，B2.13 共用）

```swift
enum NarrativeCopyResolver {
    struct Context {
        let brandId: String?
        let category: HomeItem.Category
        let amount: Double
        let date: Date
        let seed: String           // 稳定选句
    }

    static func resolveTitle(brandId: String?, fallback: String) -> String
    static func resolveCategory(brandId: String?, fallback: HomeItem.Category) -> HomeItem.Category
    static func resolveEmotionTag(context: Context) -> String
}
```

**Cascade：**

```text
brandId 命中且 catalog 有池 → 品牌 tiers（+ 可选时段 contextual，仿 ScenePackCopyPool）
否则 → ScenePack contextualNotes / category 通用池
最后 → inferEmotionTag（仅兜底，逐步弱化）
```

---

## 必做 1 · `MerchantBrandCatalog.swift`

1. 新建 catalog，**首批 20 个高频品牌**（见下表，可微调 id/aliases）
2. 每个品牌 **4 档 × 6～8 条** emotion 向生活句（写入 `tiers[].notes`）
3. 品牌句须 **distinct 调性**（咖啡三品牌不可同句换名）
4. 提供 `matchBrand(in text: String) -> MerchantBrandDefinition?` — 最长 alias 优先，避免「咖啡」误 hit

### 首批 20 品牌（MVP）

| id | displayName | category | aliases 示例 |
|----|-------------|----------|--------------|
| luckin | 瑞幸咖啡 | dining | 瑞幸, luckin |
| starbucks | 星巴克 | dining | 星巴克, starbucks |
| manner | Manner Coffee | dining | manner, Manner |
| mixue | 蜜雪冰城 | dining | 蜜雪冰城, 蜜雪 |
| heytea | 喜茶 | dining | 喜茶, HEYTEA |
| naixue | 奈雪的茶 | dining | 奈雪 |
| mcdonalds | 麦当劳 | dining | 麦当劳, mcdonald |
| kfc | 肯德基 | dining | 肯德基, kfc |
| meituan | 美团 | dining | 美团, 美团外卖 |
| eleme | 饿了么 | dining | 饿了么, 饿了吗 |
| didi | 滴滴出行 | transport | 滴滴, didi |
| metro_transit | 地铁/公交 | transport | 地铁, 轨道交通, 公交 |
| alipay_ride | 支付宝出行 | transport | 哈啰, 青桔, 美团单车 |
| freshippo | 盒马 | daily | 盒马, 盒马鲜生 |
| dingdong | 叮咚买菜 | daily | 叮咚, 叮咚买菜 |
| familymart | 全家 | daily | 全家, FamilyMart |
| lawson | 罗森 | daily | 罗森, LAWSON |
| miniso | 名创优品 | shopping | 名创优品, MINISO |
| taobao | 淘宝 | shopping | 淘宝, 天猫, 支付宝-淘宝 |
| jd | 京东 | shopping | 京东, JD |

未命中专用池的 alias → **仅填 displayName + category**，emotion 走 **该 category 的 ScenePack 通用池**，不要凑第 21 个假品牌池。

---

## 必做 2 · OCR 接入

**文件**：`OCRService.swift`、`HomeViewModel.importOCRDrafts`

1. 列表/详情 parse 完成后，对 `windowText` + `title` 调 `MerchantBrandCatalog.matchBrand`
2. 命中 → `title = brand.displayName`（若当前 title 为泛 fallback：`账单记录`/`微信消费`/纯金额）
3. `category = brand.category`（支付宝 `alipayListCategory` 可并存；冲突时 **品牌优先** 若置信 alias 完整匹配）
4. 写入 draft 时携带 `merchantBrandId`（扩展 `OCRReceiptDraft` 或在 import 时算一次）

---

## 必做 3 · 手动记账接入

**文件**：`HomeViewModel.addManualRecord`、`RecordView`

1. 用户输入 `inputTitle` 或保存时，对 title 做 brand match
2. 命中 → 设 `merchantBrandId`；emotion 走 `NarrativeCopyResolver`
3. `updateOCRDraftCategory` / 改金额时：若 `merchantBrandId != nil`，重算 emotion **走品牌池**，勿掉回 `inferEmotionTag` 七选一

---

## 必做 4 · 通用池升级（兜底）

1. `resolveEmotionTag` 兜底链必须接 `ScenePackCopyPool.contextualNotes` 逻辑（或抽 public），**不要**长期依赖 `inferEmotionTag` 七选一
2. `noteSuggestions(for:)` 可选：品牌命中时在 chip 区置顶 `displayName`（小 diff 可做可不做）

---

## 禁止

- 本 PR 不做 Logo 图像匹配（留 F1.3b）
- 不改 B2.13 习惯统计（另 PR）
- 不改 StoreKit、Playback、D1.1 分享图
- 全局硬编码「9.9=咖啡」类人口学规则
- git commit 除非用户明确要求

---

## 验收

- [ ] OCR 微信/支付宝列表：含「瑞幸」→ title 瑞幸咖啡，emotion 来自 luckin 池而非「日常一口」
- [ ] 手动备注含「星巴克」→ merchantBrandId 写入，改金额后 emotion 仍来自 starbucks 池
- [ ] 无品牌命中 → 与现 B2.8/B2.12 行为一致或更好（ScenePack contextual 兜底）
- [ ] 误命中防护：纯「咖啡」二字不绑 luckin
- [ ] Codable 旧数据：`merchantBrandId` 缺省 nil 不 crash

---

## @ 文件

```text
@RECORDING_CHAIN_VISION_v0.1.md
@AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md
@NativeDemoApp/Services/OCRService.swift
@NativeDemoApp/Services/ScenePackCopyPool.swift
@NativeDemoApp/Models/HomeItem.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/RecordView.swift
@CATEGORY_SCENE_COPY_AUDIT_v0.1.md
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task F1.3 — 品牌叙事池**（仅 iOS；**同一 PR**；F1.2 已完成）。

## 北极星句
**缩短记账链路、叙事自动长出来。** 明确识别品牌 → 专用调性文案池；否则 → 通用池。

## 背景
文案与 UI 并列重要。明确识别出品牌时，必须用 **该品牌调性的专用文案池**；识别不到则走通用池（ScenePack / 分类 contextual），**禁止**用 A 品牌话术贴 B 品牌。

叙事句，非广告句：
- ✅ 「早班路上，顺手续一口」
- ❌ 「小蓝杯，年轻就要瑞幸」

过 CATEGORY_SCENE_COPY_AUDIT_v0.1.md §2 问句 + 禁止词表。

## 执行顺序（必须按此顺序改）
1. **必做 1** — MerchantBrandCatalog + NarrativeCopyResolver（基础设施）
2. **必做 2** — OCR 接入 brand match
3. **必做 3** — 手动记账接入
4. **必做 4** — 通用池兜底升级

## 必须先 Read
@RECORDING_CHAIN_VISION_v0.1.md
@AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md
@NativeDemoApp/Services/OCRService.swift
@NativeDemoApp/Services/ScenePackCopyPool.swift
@NativeDemoApp/Models/HomeItem.swift
@NativeDemoApp/ViewModels/HomeViewModel.swift
@NativeDemoApp/Views/RecordView.swift
@CATEGORY_SCENE_COPY_AUDIT_v0.1.md

---

## 必做 1 · MerchantBrandCatalog + NarrativeCopyResolver（最先做）

### HomeItem 扩展（Codable 向后兼容）
var merchantBrandId: String?  // nil = 未识别；改金额/分类时重算 emotion 用

title 仍存备注/商户名；emotionTag 存列表胶囊展示句。

### MerchantBrandDefinition
struct MerchantBrandDefinition {
    let id: String              // e.g. "luckin"
    let displayName: String     // 「瑞幸咖啡」
    let aliases: [String]       // OCR/备注命中，大小写不敏感
    let category: HomeItem.Category
    let tiers: [ScenePackTier]  // 复用 ScenePackCopyPool 的 tier 结构
}

### NarrativeCopyResolver（本 PR 必建，B2.13 将共用）
enum NarrativeCopyResolver {
    struct Context {
        let brandId: String?
        let category: HomeItem.Category
        let amount: Double
        let date: Date
        let seed: String
    }
    static func resolveTitle(brandId: String?, fallback: String) -> String
    static func resolveCategory(brandId: String?, fallback: HomeItem.Category) -> HomeItem.Category
    static func resolveEmotionTag(context: Context) -> String
}

Cascade：
brandId 命中且 catalog 有池 → 品牌 tiers（+ 可选时段 contextual，仿 ScenePackCopyPool）
否则 → ScenePack contextualNotes / category 通用池
最后 → inferEmotionTag（仅兜底，逐步弱化）

### MerchantBrandCatalog.swift 要求
1. 新建 catalog，**首批 20 个高频品牌**（见下表，可微调 id/aliases）
2. 每个品牌 **4 档 × 6～8 条** emotion 向生活句（写入 tiers[].notes）
3. 品牌句须 **distinct 调性**（咖啡三品牌不可同句换名）
4. `matchBrand(in text: String) -> MerchantBrandDefinition?` — **最长 alias 优先**，避免「咖啡」误 hit

### 首批 20 品牌（MVP）

| id | displayName | category | aliases 示例 |
| luckin | 瑞幸咖啡 | dining | 瑞幸, luckin |
| starbucks | 星巴克 | dining | 星巴克, starbucks |
| manner | Manner Coffee | dining | manner, Manner |
| mixue | 蜜雪冰城 | dining | 蜜雪冰城, 蜜雪 |
| heytea | 喜茶 | dining | 喜茶, HEYTEA |
| naixue | 奈雪的茶 | dining | 奈雪 |
| mcdonalds | 麦当劳 | dining | 麦当劳, mcdonald |
| kfc | 肯德基 | dining | 肯德基, kfc |
| meituan | 美团 | dining | 美团, 美团外卖 |
| eleme | 饿了么 | dining | 饿了么, 饿了吗 |
| didi | 滴滴出行 | transport | 滴滴, didi |
| metro_transit | 地铁/公交 | transport | 地铁, 轨道交通, 公交 |
| alipay_ride | 支付宝出行 | transport | 哈啰, 青桔, 美团单车 |
| freshippo | 盒马 | daily | 盒马, 盒马鲜生 |
| dingdong | 叮咚买菜 | daily | 叮咚, 叮咚买菜 |
| familymart | 全家 | daily | 全家, FamilyMart |
| lawson | 罗森 | daily | 罗森, LAWSON |
| miniso | 名创优品 | shopping | 名创优品, MINISO |
| taobao | 淘宝 | shopping | 淘宝, 天猫, 支付宝-淘宝 |
| jd | 京东 | shopping | 京东, JD |

未命中专用池的 alias → **仅填 displayName + category**，emotion 走 **该 category 的 ScenePack 通用池**，不要凑假品牌池。

**验收 1**：
- [ ] catalog 含 20 品牌，每品牌 4 档完整
- [ ] Resolver cascade 可单测或手动验证
- [ ] 纯「咖啡」二字 **不** 绑 luckin

---

## 必做 2 · OCR 接入

**文件**：`OCRService.swift`、`HomeViewModel.importOCRDrafts`

1. 列表/详情 parse 完成后，对 `windowText` + `title` 调 `MerchantBrandCatalog.matchBrand`
2. 命中 → `title = brand.displayName`（若当前 title 为泛 fallback：`账单记录`/`微信消费`/纯金额）
3. `category = brand.category`（支付宝 `alipayListCategory` 可并存；冲突时 **品牌优先** 若 alias 完整匹配）
4. 扩展 `OCRReceiptDraft` 或在 import 时写入 `merchantBrandId` + `emotionTag`（走 Resolver）

**验收 2**：
- [ ] OCR 微信/支付宝列表含「瑞幸」→ title 瑞幸咖啡，emotion 来自 luckin 池

---

## 必做 3 · 手动记账接入

**文件**：`HomeViewModel.addManualRecord`、`RecordView`

1. 用户 `inputTitle` 或保存时，对 title 做 brand match
2. 命中 → 设 `merchantBrandId`；emotion 走 `NarrativeCopyResolver`
3. `updateOCRDraftCategory` / 改金额时：若 `merchantBrandId != nil`，重算 emotion **走品牌池**，勿掉回 `inferEmotionTag` 七选一

**验收 3**：
- [ ] 手动备注含「星巴克」→ merchantBrandId 写入
- [ ] 改金额后 emotion 仍来自 starbucks 池

---

## 必做 4 · 通用池升级（兜底）

1. `resolveEmotionTag` 兜底链必须接 `ScenePackCopyPool` contextualNotes 逻辑（或抽 public），**不要**长期依赖 `inferEmotionTag` 七选一
2. `noteSuggestions(for:)` 可选：品牌命中时 chip 区置顶 `displayName`（小 diff 可做可不做）

**验收 4**：
- [ ] 无品牌命中 → 与现 B2.8/B2.12 一致或更好（ScenePack contextual 兜底）

---

## 禁止

- Logo 图像匹配（留 F1.3b）
- B2.13 习惯引擎（另 PR）
- web-preview、StoreKit、Playback、D1.1 分享图
- 全局硬编码「9.9=咖啡」类人口学规则
- git commit 除非用户明确要求

---

## 总验收（TestFlight 快验）

- [ ] OCR 瑞幸/星巴克：专用 emotion，非「日常一口」
- [ ] 手动品牌命中 + 改金额 emotion 不掉池
- [ ] 无品牌：通用池兜底正常
- [ ] Codable 旧数据：merchantBrandId 缺省 nil 不 crash

---

## 交付

1. 改动文件列表（按执行顺序 1→2→3→4）
2. 20 品牌 emotion 样例（每品牌 2 条即可，全文在 catalog）
3. 验收勾选
4. 未做项：F1.3b Logo、B2.13 习惯预填

最小 diff；文案过 CATEGORY_SCENE_COPY_AUDIT 问句。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | 首版：20 品牌 MVP + NarrativeCopyResolver + OCR/手动接入 |
| 2026-06-08 | 复制发送块扩全：对齐 F1.2 格式（背景/执行顺序/必做 1～4/验收/交付） |
