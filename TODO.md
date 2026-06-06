# 叙账 · 进度清单

> 更新时间：**2026-06-06**（代码核查：C1/F1 ✅ · B2.8 ❌）  
> 分支：`feature/生活切片和会员权益` · 工作区含 Release 门禁 / D1 等未提交改动  
> API：`https://api.xuzhangapp.com` · 登录：手机号验证码（v0.1）

---

## 🚀 下一步最先做什么（2026-06-06）

> C1 / F1 / D1 已在代码中；**唯一未做的 Agent 任务是 B2.8**。下一步：**真机回归 + B2.8**。

| 顺序 | 做什么 | 为什么先 | 预计 |
|------|--------|----------|------|
| **1** | **Mac 拉最新 → Archive → TestFlight**，按下方「回归 11 条」 | 验 C1 动线、F1 OCR、D1 分享、Release 门禁 | 0.5～1 天 |
| **2** | **Task B2.8 智能分类**（仍纯金额档，见 §核查） | 记账路径最后一格产品债 | Agent 1 次 |
| **3** | 购买 success **welcome 文案** + 用尽次数话术走读 | 付费瞬间温度 | 0.5 天 |
| **4** | **B2.5** 切片幕 UI 真机再看 | 内核「感染力」 | 1 天 |
| 并行 | 栏 B：备案、API 证续期、Spug 短信 | 上架 blocker | — |

**TestFlight 回归 11 条（哲学对齐版）**

1. 新装 → **首记** Toast「用 10 秒叙一下今天」→ 自动开今日回放（C1）  
2. 本周 ≥3 笔 → 看看花 Tab **角标** + 首页引导条（C1）  
3. 记 3 笔本周 → 看看花默认 **本周** → 播生活切片 **2 遍**，旁白有变化  
2. 展开场景包：travel 为 **旅行出发包**，副文案为 tagline（无「比如输入 ¥」）  
3. 手改分类 → 再改金额 → **分类不被覆盖**（B2.7）  
4. 小 AI 说 → **记一句本月收束** → 无下月 ¥ 数字  
5. OCR 选图 → 确认弹层 → 确认导入；取消/失败不扣次  
6. 登录 → 沙盒购 → verify → 会员切片无限  
7. 杀进程 → 数据仍在  
8. 设置页会员档显示 **年度会员** 非 yearly  
9. 弱数据（1～2 笔）播切片，copy 不尴尬  
10. 播完 CTA：主会员 / 次「想多聊一句」；**周播完** →「保存本周故事图」可导出 PNG（D1）  
11. **Release Archive**：设置/会员页 **无** Debug 写 tier 入口（TC-MEM-06）

Agent 下一任务：**B2.8**；见 [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) §10.13。

### 代码核查（2026-06-06）

| 任务 | 结论 | 依据 |
|------|------|------|
| **C1 动线** | ✅ 已做 | `PlaybackRouteGuidance` 三态；首记 Toast+回放；`ContentView` 看看花角标；`StatsWebView` ≥5 笔文案 |
| **F1 OCR** | ✅ 主链路 | `OCRConfirmSheet` 四步 + `OCRDraftPanel`；仅确认导入扣次；Release 无演示按钮 |
| **B2.8 智能分类** | ❌ **未做** | `recommendCategory` 仍 `<30 餐饮 / <80 交通…`；无 `CategoryRecommendService` |

---

## ✅ 已完成（2026-06-06 更新）

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
- [x] **Task D1 播完分享图**：周切片播完「保存本周故事图」→ `WeeklyShareCardView.snapshot()` → 系统分享；`PlaybackService.buildWeeklyShareCardPayload`；AI Tab「生成周度分享卡」同源

### 对外与部署
- [x] 生产 ECS、`api.xuzhangapp.com`、PG、ai-proxy 转发
- [x] 主域 HTTPS、官网截图、favicon、**新 App 图标**
- [x] 隐私 / 用户协议静态页（`legal/`）

---

## ⏳ 待办 · 两栏

| **栏 A · 体验细调** | **栏 B · 接真环境 / 上架** |
|---------------------|----------------------------|
| **路径 1 · 新用户首记** | **真机全流程** |
| - [x] C1：首记 → 今日回放 / 看看花引导 | - [ ] 回归 11 条（见上文 §最先做） |
| - [x] 记 ≥3 笔 → 看看花角标/卡片提示 | - [ ] 生产 API 全链路再验 |
| - [x] B2.7 分类锁定（真机再验） | |
| - [ ] **B2.8 智能分类** — §10.13（**代码未改，仍金额档**） | |
| - [ ] B2.9 天气宠物（Open-Meteo；开关已有）— §10.14 | |
| - [x] 场景包哲学 + tagline（A4）；B2.10 128 条 **iOS 已 32×4**，防连重复可选 | |
| | |
| **路径 2 · 生活切片** | **备案与合规** |
| - [ ] B2.5 叙事/UI（旁白为主、少报表感）— §10.8 | - [ ] ICP 备案 |
| - [x] B2.6 PlaybackCopyPool 接入（MVP；对照 md 可补全条数） | - [x] 隐私 / 协议 URL 上线 |
| - [x] D1 播完分享图 — §10.9（周章；月章 v0.2） | - [ ] ASC 隐私问卷 + [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) |
| - [ ] 免费次数话术与 App 内 enforce 再走一遍 | |
| | |
| **路径 3 · 智能导入** | **生产安全** |
| - [x] F1：OCR 四步主链路（`OCRConfirmSheet` + 草稿区） | - [ ] Spug 短信 / 收紧 dev 码 |
| - [ ] F1 可选：删 `#if DEBUG`「演示 OCR」（Release 已不可见） | - [ ] `APP_PROXY_TOKEN`、防火墙 |
| - [x] 识别失败 / 取消不扣次（逻辑已有，真机再验） | - [ ] pm2/systemd |
| | - [x] 主域 HTTPS |
| | - [ ] API 子域 SSL 续期（2026-08-29 前） |
| | |
| **路径 4 · 会员与 AI** | **TestFlight → 商店** |
| - [x] A3 AI 议边界（iOS） | - [x] TestFlight 首测通过 |
| - [ ] 购买 welcome 文案；用尽话术走读 | - [ ] **新一轮** TestFlight（含 0e315c4） |
| - [ ] 播完 CTA polish | - [ ] ASC 截图（按 STAGE_REVIEW §6） |
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
| - [ ] `WeeklyShareCardView` → `Views/Components/`（D1 已接播完 + AI Tab；迁文件为小改） | 微信登录、长图 OCR 多条 |
| - [ ] `HomeViewModel` 按域瘦身（分类/OCR/Insight 可抽 Service） | |
| - [ ] `AppColors` / `GlassPanel` → `Theme.swift`；`RecordEditSheet` 迁 Record | |
| - [ ] 空状态、弱数据 copy 再读 | |

---

## 🧱 结构债状态（2026-06-06）

> Insight 拆完后 **无 🔴 高风险**；B2.8 未做时不阻塞 TestFlight，但记账推荐仍偏工具感。

| 级别 | 项 | 行数/位置 | 建议时机 |
|------|-----|-----------|----------|
| 🟢 已解 | 巨型 `ContentView` | **~702** Tab 壳 | — |
| 🟡 中等 | `HomeViewModel` | ~866 | **B2.8** 抽 `CategoryRecommendService` |
| 🟡 中等 | `InsightWebView` | ~805 | 可选迁 `WeeklyShareCardView` |
| 🟡 低 | `WeeklyShareCardView` 位置 | `InsightWebView` 末尾 | 独立 Components（小改） |
| 🟡 低 | 主题/编辑 sheet | `ContentView` 内 | v0.2 整理 |
| 🟡 非结构 | Web 漂移 | web-preview | 上架前（iOS/backend tier 门禁 ✅） |


## 进度一览

```text
[████████████████████]  功能 MVP         ~92%  ⏳ B2.8
[██████████████░░░░░░]  体验细调（栏 A）  ~65%  ✅ C1/F1/D1
[██████████░░░░░░░░░░]  接真环境（栏 B）  ~50%  ✅ Release tier 门禁
[████████████████░░░░]  结构健康度        ~75%  ✅ Tab 拆分；VM 待 B2.8
```

---

## 相关文档

| 文档 | 用途 |
|------|------|
| [`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md) | §0 哲学、§0.5 议边界 |
| [`PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md`](PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md) | 阶段总结、商店文案、§7 polish |
| [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) | **B2.8**（待做）/ B2.5 / welcome |
| [`AGENT_PROMPT_AI_ADVICE_BOUNDARY.md`](AGENT_PROMPT_AI_ADVICE_BOUNDARY.md) | Task A3（已完成 iOS） |
| [`AGENT_PROMPT_SCENE_PACK_PHILOSOPHY.md`](AGENT_PROMPT_SCENE_PACK_PHILOSOPHY.md) | Task A4（已完成 iOS） |
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
