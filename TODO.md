# 叙账 · 进度清单

> 更新时间：**2026-06-08**（记账链路愿景 + F1.3 品牌池 + B2.13 习惯预填立项）  
> 分支：`feature/生活切片和会员权益`  
> API：`https://api.xuzhangapp.com` · 登录：手机号验证码（v0.1）

---

## 🚀 下一步最先做什么（2026-06-07）

> B2.8 / B2.9 / B2.11 / B2.12 / D1.1 / backend 生产门禁已在代码中。**现在最缺：真机回归（含分享海报气质、心意往来包、夜宵时段备注）+ 栏 B 上架项**。

| 顺序 | 做什么 | 为什么先 | 预计 |
|------|--------|----------|------|
| **1** | **Mac 拉最新 → Archive → TestFlight**，按下方「回归 16 条」 | 验 B2.8/B2.9/B2.11/B2.12、**D1.1 故事图非报表感**、Release 全门禁 | 0.5～1 天 |
| **2** | 购买 **welcome 文案** + 用尽次数话术走读 | 付费瞬间温度；与分享图「被看见」同频 | 0.5 天 |
| **3** | **B2.5** 切片 Sheet 播放过程 UI | 过程叙、产物叙不割裂 | 1 天 |
| **4** | **F1.2 → F1.3 → B2.13** 记账链路（见 [`RECORDING_CHAIN_VISION_v0.1.md`](RECORDING_CHAIN_VISION_v0.1.md)） | **缩短记账链路、叙事自动长出来** | F1.2 先；F1.3/B2.13 各 1 PR |
| 并行 | 栏 B：备案、Spug 短信、ASC Product ID | 上架 blocker | — |

**TestFlight 回归 16 条（哲学对齐版）**

1. 新装 → **首记** Toast「用 10 秒叙一下今天」→ 自动开今日回放（C1）  
2. 本周 ≥3 笔 → 看看花 Tab **角标** + 首页引导条（C1）  
3. 记 3 笔本周 → 看看花默认 **本周** → 播生活切片 **2 遍**，旁白有变化  
4. 展开场景包：travel 为 **旅行出发包**，副文案为 tagline（无「比如输入 ¥」）  
5. 手改分类 → 再改金额 → **分类不被覆盖**（B2.7）  
6. **B2.8**：工作日早 8 点 ¥4 → 推荐偏 **交通**；12 点 ¥25 → 偏 **餐饮**；备注含「地铁」→ 交通  
7. **B2.8/B2.10 补洞**：历史餐饮很多时，¥200/¥800 不应仍一律吃饭；同金额连续点一键备注可轮换；补记 23:30 餐饮 + 一键备注出现夜宵/深夜小食语境  
8. **B2.9**：开天气互动 → 定位授权；记一笔后宠物句 **非** 固定 4 句；点宠物 **无**「餐饮偏多/带饭」  
9. 小 AI 说 → **记一句本月收束** → 无下月 ¥ 数字  
10. OCR 选图 → 确认弹层 → 确认导入；取消/失败不扣次  
11. 登录 → 沙盒购 → verify → 会员切片无限  
12. 杀进程 → 数据仍在  
13. 播完 CTA + **周播完**「保存本周故事图」导出 PNG（D1）  
14. **D1.1 分享海报**：无 KPI 三格 / 环图 TOP%；主视觉为 headline + 收束句；播完导出与 AI Tab **同源气质**；像「生活周记」非「消费报告」  
15. **B2.11/B2.12**：手选人情 + 一键备注 → 心意往来包，无午餐/奶茶/红包/随礼；新建人情记录 emotionTag 为人情小记/心意往来  
16. **Release Archive**：设置/会员页无 Debug 写 tier；生产 API 无 `dev/set-tier`（`NODE_ENV=production`）

### 代码核查（2026-06-07 更新）

| 任务 | 结论 | 依据 |
|------|------|------|
| **backend dev/set-tier** | ✅ | `server.js` L87–99：`if (!isProduction)` 才注册 |
| **B2.8 智能分类** | ✅ | `CategoryRecommendService.swift`；`HomeViewModel.recommendCategoryResult`；`RecordView` 监听 amount/title/date |
| **B2.9 天气宠物** | ✅ | `WeatherCompanionService` + `PetCompanionCopy` + `PetCompanionService`；`enqueuePetMessage`；`Info.plist` 定位文案 |
| **B2.11 心意往来包** | ✅ | `ScenePackCopyPool.social` 4 档 × 8 条；`RecordView.guessScenePackId(.social)`；social chips 去敏感词 |
| **B2.12 情绪标签 polish** | ✅ | `HomeItem.inferEmotionTag` 七类已 soften；health/home/social 保持母版 |
| **C1 / F1 / D1** | ✅ | 见前序核查 |
| **D1.1 周分享海报** | ✅ 代码 | `WeeklyShareCardView` 叙事海报布局；`anchorLine` + `rhythmTexture`；删 KPI/环图；`PlaybackService.weeklyShareAnchorLine` |

---

## ✅ 已完成（2026-06-07 更新）

### 产品与文档
- [x] 北极星 §0 创始人哲学、§0.5 AI「议」边界
- [x] [`PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md`](PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md) 阶段总结 + App Store 草案
- [x] [`AI_ADVICE_BOUNDARY_AUDIT_v0.1.md`](AI_ADVICE_BOUNDARY_AUDIT_v0.1.md)、Task **A3/A4** Agent prompt
- [x] [`SCENE_PACK_COPY_POOL_v0.2.md`](SCENE_PACK_COPY_POOL_v0.2.md) §10 哲学对齐 + tagline

### iOS 功能（`0e315c4` 及前序）
- [x] 生活切片 Phase B/C、次数 enforce、默认 **本周**（`StatsWebView`）
- [x] **PlaybackCopyPool** 接入 `PlaybackService`（按幕 hash 轮换，iOS MVP）
- [x] **Task A3** 小 AI 说去预算化：记一句本月收束、fallback/Prompt §0.5
- [x] **Task A4** 场景包：旅行出发包、5 条替词、四包 tagline
- [x] **B2.7 骨架**：`categoryLockedByUser`，手改分类后推荐不覆盖
- [x] **结构债 · Tab 拆分**：`RecordView`、`StatsWebView`、`ScenePackSectionView`、**`InsightWebView`**（`ContentView` **~702 行**，壳 + Tab + 主题）
- [x] **Task C1 动线**：首记 → 今日回放；本周≥3 看看花角标；≥5 笔卡片文案；同会话单条引导
- [x] **Task F1 OCR**：Vision 识票 → 确认弹层 → 草稿区；取消/识别失败不扣次（Release 无「演示 OCR」）
- [x] **StoreKit + `/v1/iap/verify`** 客户端（`MemberPricingView` + `SettingsViewModel.verifyIAPPurchase`）
- [x] 会员 UI、**年度会员**中文档（`MemberPricingView` / `SettingsView`）
- [x] ScenePackCopyPool：4 档 × 8 条 + stable hash + 历史增强
- [x] TestFlight **首测闭环**（记、回放、切片、沙盒购、杀进程）
- [x] **Release 门禁（iOS）**：移除设置/会员页 Debug 写 tier；`MemberNudgePolicyService` 统一 prod 频控
- [x] **Task D1 播完分享图**（周章播完分享）
- [x] **Task D1.1 周分享海报 polish** — 叙事主视觉、删报表 KPI/环图、`anchorLine`、极淡 rhythm；播完 + AI Tab 同源（[`AGENT_PROMPT_D1.1_WEEKLY_SHARE_POSTER.md`](AGENT_PROMPT_D1.1_WEEKLY_SHARE_POSTER.md)）
- [x] **Task B2.8 智能分类**：`CategoryRecommendService`（历史 10% + 时段 20% + 金额 45% + 备注 35%，避免历史餐饮污染独裁）
- [x] **Task B2.9 天气宠物**：Open-Meteo + `PET_SCENE_RULES` + 记完账/点击宠物；删管控式硬编码
- [x] **Task B2.11 心意往来包**：social 包、映射、chips；人情一键备注不再走 food
- [x] **Task B2.12 情绪标签 polish**：7 类标签 soften；无奔波/开销/支出类标签
- [x] **夜宵时段备注**：一键备注传 `selectedDate`；餐饮按早/午/下午茶/晚/夜宵分支
- [x] **backend Release**：`dev/set-tier` 仅 `NODE_ENV !== production` 注册

### 对外与部署
- [x] 生产 ECS、`api.xuzhangapp.com`、PG、ai-proxy 转发
- [x] 主域 HTTPS、官网截图、favicon、**新 App 图标**
- [x] 隐私 / 用户协议静态页（`legal/`）

---

## ⏳ 待办 · 两栏

| **栏 A · 体验细调** | **栏 B · 接真环境 / 上架** |
|---------------------|----------------------------|
| **路径 1 · 新用户首记** | **真机全流程** |
| - [x] C1：首记 → 今日回放 / 看看花引导 | - [ ] 回归 **14** 条（见上文 §最先做；含 D1.1 真机看图） |
| - [x] 记 ≥3 笔 → 看看花角标/卡片提示 | - [ ] 生产 API 全链路再验 |
| - [x] B2.7 分类锁定（真机再验） | |
| - [x] **B2.8 智能分类** — `CategoryRecommendService` | |
| - [ ] **B2.13 个人习惯预填** — 只输金额 → 分类/备注/情绪 — [`AGENT_PROMPT_B2.13`](AGENT_PROMPT_B2.13_HABIT_PREFILL.md) | |
| - [x] **B2.9 天气宠物** — `WeatherCompanionService` / `PetCompanionService` | |
| - [x] **B2.10** 场景备注池 | |
| - [x] A4 场景包哲学 + tagline | |
| | |
| **路径 2 · 生活切片** | **备案与合规** |
| - [x] B2.5 叙事/UI P0（旁白为主、少报表感；待真机观感验收）— §10.8 | - [ ] ICP 备案 |
| - [x] B2.6 PlaybackCopyPool 接入（MVP；对照 md 可补全条数） | - [x] 隐私 / 协议 URL 上线 |
| - [x] D1 播完分享图 — §10.9（周章；月章 v0.2） | - [ ] ASC 隐私问卷 + [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) |
| - [x] **D1.1** 分享海报叙事化（代码）— [`AGENT_PROMPT_D1.1`](AGENT_PROMPT_D1.1_WEEKLY_SHARE_POSTER.md) | |
| - [x] **心意往来包** B2.11 — [`AGENT_PROMPT_B2.11_SOCIAL_SCENE_PACK.md`](AGENT_PROMPT_B2.11_SOCIAL_SCENE_PACK.md) | |
| - [x] **情绪标签 polish** B2.12（7 类；health/home/social 不动）— [`AGENT_PROMPT_B2.12_EMOTION_TAGS.md`](AGENT_PROMPT_B2.12_EMOTION_TAGS.md) | |
| - [ ] 免费次数话术与 App 内 enforce 再走一遍 | |
| | |
| **路径 3 · 智能导入 · 记账链路** | **生产安全** |
| - [x] F1：OCR 四步主链路（`OCRConfirmSheet` + 草稿区） | - [ ] Spug 短信 / 收紧 dev 码 |
| - [ ] **F1.2** OCR 真机回归 — [`AGENT_PROMPT_F1.2`](AGENT_PROMPT_F1.2_OCR_STATS_REGRESSION.md) | - [ ] `APP_PROXY_TOKEN`、防火墙 |
| - [ ] **F1.3** 品牌叙事池 — [`AGENT_PROMPT_F1.3`](AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md) | - [ ] pm2/systemd |
| - [ ] F1.3b Logo 识别（可选二期） | - [x] 主域 HTTPS |
| - [ ] F1 可选：删 `#if DEBUG`「演示 OCR」（Release 已不可见） | - [ ] API 子域 SSL 续期（2026-08-29 前） |
| - [x] 识别失败 / 取消不扣次（逻辑已有，真机再验） | |
| | |
| **路径 4 · 会员与 AI** | **TestFlight → 商店** |
| - [x] A3 AI 议边界（iOS） | - [x] TestFlight 首测通过 |
| - [ ] 购买 welcome 文案；用尽话术走读 | - [ ] **新一轮** TestFlight（含 D1.1 + B2.8/B2.9） |
| - [ ] 播完 CTA 文案 polish（按钮区；分享图已 D1.1） | - [ ] ASC 截图（按 STAGE_REVIEW §6） |
| - [ ] 远程 AI 抽测 daily/monthly | - [ ] 内测反馈一轮 |
| | |
| **路径 5 · 设置** | **真实支付（收费前）** |
| - [ ] 登录 / 同步 / 冲突提示 polish | - [x] backend `/v1/iap/verify` 已实现 |
| - [ ] 设置页 copy 与能力一致 | - [ ] ASC Product ID + 推介 ¥6 生产配置 |
| | - [x] Release 禁 Debug 写 tier（`SettingsView` / `MemberPricingView` 模拟入口已删） |
| | - [x] 生产 backend 禁 `POST /v1/member/dev/set-tier`（`NODE_ENV=production` 不注册） |
| | |
| **可选 · 工程** | **v0.2+** |
| - [x] Logo / 图标；Tab 级 `ContentView` 拆分（含 Insight） | Web 预览与 iOS 对齐（A3/A4/copy） |
| - [ ] `WeeklyShareCardView` → `Views/Components/`（D1.1 已 polish；迁文件为小改） | 微信登录、长图 OCR 多条 |
| - [ ] `HomeViewModel` 按域瘦身（分类/OCR/Insight 可抽 Service） | |
| - [ ] `AppColors` / `GlassPanel` → `Theme.swift`；`RecordEditSheet` 迁 Record | |
| - [ ] 空状态、弱数据 copy 再读 | |

---

## 🧱 结构债状态（2026-06-07）

> B2.8 Service 已抽出；`HomeViewModel` 仍偏胖，v0.2 可继续瘦身。

| 级别 | 项 | 行数/位置 | 建议时机 |
|------|-----|-----------|----------|
| 🟢 已解 | 巨型 `ContentView` | **~702** Tab 壳 | — |
| 🟢 已解 | B2.8 分类 Service | `CategoryRecommendService.swift` | — |
| 🟡 中等 | `HomeViewModel` | ~950+ | OCR/Insight 等可继续抽 |
| 🟡 中等 | `InsightWebView` | ~840 | D1.1 后仍含 `WeeklyShareCardView`；可选迁 Components |
| 🟡 低 | `WeeklyShareCardView` 位置 | `InsightWebView` 末尾 | 独立 `Views/Components/`（小改） |
| 🟡 低 | 主题/编辑 sheet | `ContentView` 内 | v0.2 整理 |
| 🟡 非结构 | Web 漂移 | web-preview | 上架前（iOS/backend tier 门禁 ✅） |


## 进度一览

```text
[█████████████████████]  功能 MVP         ~95%  ✅ B2.8/B2.9
[██████████████████░░]  体验细调（栏 A）  ~85%  ⏳ welcome / D1.1+B2.5 真机验
[███████████░░░░░░░░░]  接真环境（栏 B）  ~55%  ✅ iOS+backend Release 门禁
[█████████████████░░░]  结构健康度        ~80%  ✅ Tab 拆分 + 分类 Service
```

---

## 相关文档

| 文档 | 用途 |
|------|------|
| [`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) | §0 哲学、§0.5 议边界 |
| [`PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md`](PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md) | 阶段总结、商店文案、§7 polish |
| [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) | B2.5 / welcome / ASC |
| [`AGENT_PROMPT_AI_ADVICE_BOUNDARY.md`](AGENT_PROMPT_AI_ADVICE_BOUNDARY.md) | Task A3（✅） |
| [`AGENT_PROMPT_B2.8_SMART_CATEGORY.md`](AGENT_PROMPT_B2.8_SMART_CATEGORY.md) | Task B2.8（✅ 已完成） |
| [`AGENT_PROMPT_B2.9_WEATHER_PET.md`](AGENT_PROMPT_B2.9_WEATHER_PET.md) | Task B2.9（✅ 已完成） |
| [`AGENT_PROMPT_D1.1_WEEKLY_SHARE_POSTER.md`](AGENT_PROMPT_D1.1_WEEKLY_SHARE_POSTER.md) | Task D1.1 分享海报（✅ 代码；真机验 ⏳） |
| [`AGENT_PROMPT_B2.11_SOCIAL_SCENE_PACK.md`](AGENT_PROMPT_B2.11_SOCIAL_SCENE_PACK.md) | Task B2.11 心意往来包（✅） |
| [`AGENT_PROMPT_B2.12_EMOTION_TAGS.md`](AGENT_PROMPT_B2.12_EMOTION_TAGS.md) | Task B2.12 情绪标签 7 类（✅） |
| [`RECORDING_CHAIN_VISION_v0.1.md`](RECORDING_CHAIN_VISION_v0.1.md) | **缩短记账链路、叙事自动长出来** — 双引擎 + cascade |
| [`AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md`](AGENT_PROMPT_F1.3_BRAND_NARRATIVE_POOL.md) | Task F1.3 品牌叙事池（⏳） |
| [`AGENT_PROMPT_B2.13_HABIT_PREFILL.md`](AGENT_PROMPT_B2.13_HABIT_PREFILL.md) | Task B2.13 个人习惯预填（⏳） |
| [`CATEGORY_SCENE_COPY_AUDIT_v0.1.md`](CATEGORY_SCENE_COPY_AUDIT_v0.1.md) | 分类/场景包内核审计 |
| [`AGENT_PROMPT_SCENE_PACK_PHILOSOPHY.md`](AGENT_PROMPT_SCENE_PACK_PHILOSOPHY.md) | Task A4（已完成；≠ B2.10） |
| [`TEST_CASES_v0.1.md`](TEST_CASES_v0.1.md) | 全量测试用例 |
| [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) | 上架截图与自检 |

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-04 | 栏 A/B 两栏、建议顺序 |
| 2026-06-06 | 对齐 `0e315c4`：已完成 A3/A4/B2.6/拆分/IAP；§最先做 + 回归 10 条 |
| 2026-06-06 | InsightWebView 拆分完成；§结构债状态；可选工程债清单 |
| 2026-06-06 | iOS Release 门禁 ✅：删 Debug 写 tier；Nudge 统一 prod |
| 2026-06-06 | Task D1 播完分享图 ✅ |
| 2026-06-06 | 代码核查：C1/F1 ✅；**B2.8 未做** |
| 2026-06-06 | 新增 AGENT_PROMPT_B2.8；§10.15 任务编号对照 |
| 2026-06-06 | 新增 AGENT_PROMPT_B2.9 天气宠物 + B2.8 合并说明 |
| 2026-06-06 | 核查：B2.8/B2.9/backend dev 路由 ✅；回归 13 条 |
| 2026-06-07 | **D1.1** 周分享海报 polish ✅；回归扩 **14** 条；体验 ~80% |
| 2026-06-08 | 记账链路愿景 + **F1.3** 品牌叙事池 + **B2.13** 习惯预填 Agent prompt；北极星 §5.2 |
