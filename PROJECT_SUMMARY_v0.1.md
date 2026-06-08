# 叙账 · 项目总结 v0.1

> 更新时间：**2026-06-08**  
> 分支：`feature/生活切片和会员权益`  
> API：`https://api.xuzhangapp.com`  
> 读者：创始人、合作者、上架审核、新加入的 Agent/开发  
> 状态：**功能 MVP 基本完成 · 待 TestFlight 全量签收 + 栏 B 上架**

---

## 0. 一句话

**叙账** 不是「帮你省钱的记账 App」，而是 **帮用户温柔看见自己怎么过了一段日子** 的生活回望伴侣。

近期体验内核：

> **缩短记账链路、叙事自动长出来。**

详述：[`RECORDING_CHAIN_VISION_v0.1.md`](RECORDING_CHAIN_VISION_v0.1.md)

---

## 1. 产品哲学（不可妥协）

| 信念 | 含义 |
|------|------|
| **账是素材，叙是目的** | 记账为切片/回放提供可信数据，本身不是终点 |
| **先叙后议** | 先讲完这段生活，AI 建议才是可选项 |
| **理解而非审判** | 不做剁手提醒、消费评分、严预算教练 |
| **文案与 UI 并列重要** | 场景包、品牌池、情绪标签都是「被看见」的微观体验 |

创始人级评审问句（见 [`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) §0.3）：

> 这是在帮用户更温柔地看见自己的生活，还是在把叙账拉回「管钱工具」？

**对外主标语**：叙账 — 把生活开支，温柔地讲给你听。  
**省力记宣传语（可选）**：记一笔，生活自己叙出来。

---

## 2. 用户动线：记 → 叙 → 议

```text
记（输入）          叙（北极星）              议（可选）
─────────          ─────────────            ─────────
手动 / OCR    →    今日回放 ~10s       →    小 AI 说
场景备注包         看看花 · 周/月切片         播完后再导流
智能分类           生活配方 · 旁白
品牌叙事池         周分享海报（D1.1）
习惯预填
```

**Tab 顺序**：今日（日叙）→ 记账（输入）→ 看看花（周/月叙）→ 小 AI 说（议）→ 小窝（身份/会员）。

**订阅理由**：无限叙（切片/月章）+ 省力记（场景包、OCR、智能预填）——不是高级报表，不是 AI 诊断。

---

## 3. 技术架构

```text
┌──────────────────────────────────────────────────────────┐
│  iOS 17+ · SwiftUI · NativeDemoApp（本地优先）             │
│  UserDefaults + JSON · Vision OCR · StoreKit 2 · Keychain │
└────────────────────────────┬─────────────────────────────┘
                             │ 可选
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
   backend/            ai-proxy/           web-preview/
   auth · member       LLM 转发 · 限流      早期原型（与 iOS 有漂移）
   ledger · iap
```

| 组件 | 说明 |
|------|------|
| **iOS** | 主产品；真机/TestFlight/上架均以此为准 |
| **backend** | 登录、会员 tier、账本同步、IAP verify；生产禁 `dev/set-tier` |
| **ai-proxy** | 小 AI 说远程调用；不可用时不阻断切片闭环 |
| **web-preview** | 历史预览；上架前不与 iOS 强行对齐 |

---

## 4. 迭代脉络（Demo → 可上架）

| 阶段 | 任务/Commit 方向 | 成果 |
|------|------------------|------|
| 骨架 | Tab、本地记账、统计 | SwiftUI 原生壳 |
| **叙** | B2.5/B2.6、C1、PlaybackCopyPool | 生活切片、首记→今日回放动线 |
| **产物叙** | D1、D1.1 | 播完分享 → **叙事海报**（非 KPI 报表） |
| **议边界** | A3 | 小 AI 去预算化、本月收束 |
| **文案体系** | A4、B2.10、分类扩展、审计 | 8 场景包、10 分类、哲学对齐 |
| **省力记** | B2.7～B2.9 | 分类锁定、智能分类、天气宠物 |
| **人情/情绪** | B2.11、B2.12 | 心意往来包、情绪标签 soften |
| **OCR 真机** | F1、F1.2 | Vision 四步链路、微信/支付宝分流、看看花周界 |
| **记账链路 2.0** | F1.3、B2.13 | 20 品牌叙事池 + 个人习惯预填 |
| **合规壳** | 设置页协议/隐私/ICP 占位 | 上架准备 |

近端 commit 示例：`6103894` B2.13 · `f89b494` F1.3 · `0b71c3e` F1.2 · `19fa354` D1.1

---

## 5. 能力清单（当前代码）

### 5.1 记 · 输入层

| 能力 | 状态 | 主要文件/任务 |
|------|------|----------------|
| 手动记账 | ✅ | `RecordView`、`HomeViewModel` |
| 智能分类 B2.8 | ✅ | `CategoryRecommendService` |
| 分类锁定 B2.7 | ✅ | `categoryLockedByUser` |
| 场景备注包（8 包） | ✅ | `ScenePackCopyPool` |
| OCR 识票四步 | ✅ | `OCRService`、`OCRConfirmSheet` |
| OCR 真机修复 F1.2 | ✅ | 微信 title、Y 排序、完成整理等 |
| 品牌叙事池 F1.3 | ✅ 代码 | `MerchantBrandCatalog`、`NarrativeCopyResolver` |
| 习惯预填 B2.13 | ✅ 代码 | `RecordPrefillService` |
| Logo 识品牌 | 📋 | F1.3b 未纳入 |

**叙事 cascade（已实现）**：

```text
品牌命中（F1.3）→ 个人习惯（B2.13）→ ScenePack 通用池 → 用户纠正写回
```

### 5.2 叙 · 核心层

| 能力 | 状态 | 说明 |
|------|------|------|
| 今日回放 | ✅ | ~10 秒日叙 |
| 看看花 · 周/月生活切片 | ✅ | 本地旁白，`PlaybackService` |
| 生活配方环图 | ✅ | 结构叙，非审计报表 |
| 免费次数 quota | ✅ | 周切片/月章 enforce |
| 周分享海报 D1.1 | ✅ 代码 | `WeeklyShareCardView`，播完+AI Tab 同源 |
| 播放过程 UI B2.5 | ⏳ | 待真机观感验收 |

### 5.3 议 · 可选层

| 能力 | 状态 |
|------|------|
| 小 AI 说 daily/monthly | ✅ |
| AI 不可用降级 | ✅ |
| 非 Tab C 位、非商店首图 | ✅ 设计如此 |

### 5.4 身份 · 会员 · 合规

| 能力 | 状态 |
|------|------|
| 手机号登录、账本同步 | ✅ |
| StoreKit + `/v1/iap/verify` | ✅ |
| Release 禁 Debug 写 tier | ✅ |
| 用户协议 / 隐私政策链接 | ✅ |
| ICP 备案号 | ⏳ 待备案 |
| ASC Product ID 生产配置 | ⏳ |
| welcome / 用尽话术 polish | ⏳ |

### 5.5 陪伴（增温）

| 能力 | 状态 |
|------|------|
| 天气 + 宠物讲述 B2.9 | ✅ |
| 记完账 contextual 宠物句 | ✅ |

---

## 6. 文案架构（第一公民）

| 层级 | 载体 | 说明 |
|------|------|------|
| 场景包 | `ScenePackCopyPool` | 8 包 × 4 档；含时段子池（早/午/茶/晚/夜宵） |
| 切片旁白 | `PlaybackCopyPool` | 按幕 stable hash 轮换 |
| 品牌叙事 | `MerchantBrandCatalog` | 20 品牌，一牌一调性；非广告腔 |
| 情绪胶囊 | `NarrativeCopyResolver` | brand > ScenePack > 七类兜底 |
| 审计 | `CATEGORY_SCENE_COPY_AUDIT_v0.1.md` | 禁止词、哲学问句 |

原则：**错一次比空着更伤**——低置信宁可少填，不可乱贴品牌/习惯话术。

---

## 7. 代码结构（iOS 要点）

```text
NativeDemoApp/
├── ContentView.swift          # Tab 壳 ~700 行
├── Models/HomeItem.swift      # 10 分类 · emotionTag · merchantBrandId
├── ViewModels/HomeViewModel.swift   # 仍偏胖，v0.2 可继续抽域
└── Services/                  # 领域逻辑主力
    ├── PlaybackService.swift
    ├── OCRService.swift
    ├── CategoryRecommendService.swift
    ├── RecordPrefillService.swift
    ├── MerchantBrandCatalog.swift
    ├── NarrativeCopyResolver.swift
    ├── ScenePackCopyPool.swift
    └── …（IAP、Sync、Weather、Pet 等）
```

**结构债**：Tab 已拆分；`HomeViewModel`、部分 View 仍可瘦身；`web-preview` 与 iOS 漂移。

---

## 8. 完成度（2026-06-08 估）

```text
功能 MVP（记+叙+会员+OCR+智能预填）  ████████████████████  ~95%
体验细调（welcome、B2.5、TF 全量回归） ██████████████████░░  ~85%
上架就绪（备案、Spug、ASC、截图）      ███████████░░░░░░░░░  ~55%
结构健康度                            █████████████████░░░  ~80%
```

**当前瓶颈**：不是缺大功能，而是 **TestFlight 端到端签收 + 栏 B 上架物料**。

---

## 9. 建议的下一步

| 优先级 | 事项 |
|--------|------|
| **1** | TestFlight：回归 16 条 + 记账链路 8 条（F1.2/F1.3/B2.13 合并验） |
| **2** | 栏 B：ICP 备案、Spug 短信、ASC Product ID / 隐私问卷 |
| **3** | 商店：截图按 [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md)；副标题可用「记一笔，生活自己叙出来」 |
| **4** | welcome 文案、B2.5 播放 UI 真机 polish |
| **5** | 更新 [`README.md`](README.md)（仍写 OCR 占位，已过时） |
| **v0.2+** | F1.3b Logo、B2.13b 会话衰减、HomeViewModel 瘦身、web 对齐 |

---

## 10. 文档索引

| 文档 | 用途 |
|------|------|
| [`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) | 哲学、动线、§5.2 记账链路北极星 |
| [`RECORDING_CHAIN_VISION_v0.1.md`](RECORDING_CHAIN_VISION_v0.1.md) | 双引擎 cascade、guardrails |
| [`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md) | 切片、会员权益 |
| [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) | 名称、截图、关键词 |
| [`TODO.md`](TODO.md) | 进度、回归 16 条、栏 A/B |
| [`PROJECT_ANALYSIS.md`](PROJECT_ANALYSIS.md) | 早期架构分析（部分信息已旧，以本文为准） |
| [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) | Agent 分任务实现单 |
| `AGENT_PROMPT_*.md` | 各 Task 可复制 prompt |

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | 首版：多轮迭代后项目总结；对齐 F1.2/F1.3/B2.13 与记账链路愿景 |
