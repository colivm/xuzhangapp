# 叙账（xuzhangapp）项目分析



> 更新时间：2026-06-02  

> 仓库路径：`xuzhangapp`  

> 产品代号：叙账 v0.1  

> 当前分支：`feature/20260530-fix`（开发中；生产部署跟踪 `xuzhang1.0-release-2026`）



---



## 1. 项目概述



**叙账** 是一款本地优先的 AI 记账 App 全栈项目。核心思路：



- 默认无需登录即可记账

- 每天生成一条温和的消费复盘建议

- 可选云端同步与会员能力

- AI 复盘通过 backend → ai-proxy 调用大模型（**线上实际使用 DeepSeek**）



**搭建与部署** → 见 [`PROJECT_SETUP.md`](PROJECT_SETUP.md)  

**Staging 同机测试** → 见 [`STAGING_ENV_SETUP.md`](STAGING_ENV_SETUP.md)



---



## 2. 整体架构



项目由 **4 个子系统** 组成：



```text

┌─────────────────────────────────────────────────────────────┐

│                        客户端                                │

│  web-preview (HTML/JS)          NativeDemoApp (SwiftUI iOS17+) │

└───────────────┬─────────────────────────┬───────────────────┘

                │                         │

                ▼                         ▼

┌───────────────────────────┐   ┌─────────────────────────────┐

│  backend :8790            │   │  ai-proxy :8787             │

│  Express 业务 API         │──▶│  AI 转发 + 限流 + 密钥保护   │

│  auth / member / ledger    │   │                             │

└───────────────┬───────────┘   └──────────────┬──────────────┘

                │                              │

                ▼                              ▼

        PostgreSQL (生产已配)            DeepSeek API

```



**同机 Staging（规划中 / 部分待落地）**：backend **8791**、ai-proxy **8788**、库 **`xuzhang_staging`**、域名 `staging-api.xuzhangapp.com`。



| 模块 | 技术栈 | 用途 |

|------|--------|------|

| `NativeDemoApp/` | SwiftUI + MVVM | 主产品，iOS 17+ 原生 App |

| `web-preview/` | 纯 HTML/CSS/JS | Windows 下快速预览 UI 与交互 |

| `backend/` | Node.js + Express | 登录、会员、账单同步、分析、AI 转发 |

| `ai-proxy/` | Node.js + Express | 独立 AI 代理，限流、JWT、密钥保护 |



---



## 3. 核心功能



### 3.1 记账（本地优先）



- 手动录入：金额、分类、备注、日期

- OCR 识票：占位流程（`OCRService.swift`），可扩展为真实识别

- 6 大分类：餐饮、购物、交通、娱乐、日用、其他

- 本地存储：`UserDefaults` + JSON 文件（`LocalStore.swift`）



### 3.2 统计与复盘



- 本周 / 本月支出统计、分类占比

- **每日 AI 复盘**：3 行总结 + 1 条行动建议 + 鼓励语

- 支持日 / 周 / 月多周期 AI 洞察

- AI 失败时自动 fallback 到本地文案



### 3.3 会员与增长



- 会员档位：`free` / `monthly` / `yearly` / `lifetime`

- 场景化会员引导（通勤包、吃货包、旅行包、宠物包等）

- Nudge 策略：展示频率、dismiss 记录（前后端均有实现）

- 会员定价页（`MemberPricingView.swift`），IAP 验单为 stub



### 3.4 云端能力（可选）



- 手机号验证码登录（开发环境固定验证码 `123456`）

- 账单上行同步（`updatedAt` 冲突策略）

- Access Token 存 Keychain

- 微信登录、IAP 验单：**接口已预留，尚未实现**



---



## 4. iOS 端结构



采用 **SwiftUI + MVVM**，入口为 `NativeDemoAppApp.swift`，两个全局 ViewModel：



```text

NativeDemoApp/

├── Models/          HomeItem, AppSettings, DailyInsight

├── ViewModels/      HomeViewModel, SettingsViewModel

├── Services/        业务服务层

├── Views/           HomeView, SettingsView, MemberPricingView,
│                    RecordView, StatsWebView, InsightWebView, …

└── ContentView.swift  Tab 壳 + 主题 + RecordEditSheet（**~702 行**；Tab 视图已拆至 Views/）

```



| Service | 职责 |

|---------|------|

| `LocalStore` | 本地账单、设置、AI 报告读写 |

| `AIReportService` | 调用 AI 接口生成复盘 |

| `AIUsageLimiter` | 远程 AI 月度调用上限（默认 120 次） |

| `AuthService` | 手机号登录、会员状态查询 |

| `LedgerSyncService` | 云端账单同步 |

| `KeychainService` | API Key / Token 安全存储 |

| `MemberFlowService` | 会员 CTA 文案 |

| `MemberNudgePolicyService` | 会员引导策略 |

| `AnalyticsService` | 埋点上报 |

| `PlaybackService` | 今日消费回放 |

| `OCRService` | OCR 占位 |



**5 个 Tab**：今日 / 记账 / 统计 / AI 复盘 / 设置。UI 采用玻璃拟态（Glass Panel），配色与 `web-preview` 保持一致。



**Bundle ID**：`com.xuzhang.app`



---



## 5. 后端 API 概览



`backend` 默认端口 **8790**，支持内存存储或 PostgreSQL（`DATABASE_URL`）：



| 类别 | 接口 |

|------|------|

| 健康检查 | `GET /health` |

| 认证 | `POST /v1/auth/sms/send`, `/verify`；微信登录 stub |

| 会员 | `GET /v1/member/me`，开发态切换 tier |

| 账单 | `GET/POST/DELETE /v1/ledger` |

| AI | `POST /v1/ai/insight/daily` → 转发到 ai-proxy |

| 分析 | `POST/GET /v1/analytics/events`，`GET /summary` |

| Nudge | policy / evaluate / dismiss |

| 回放 | `GET /v1/playback/today` |

| IAP | stub（501） |



`ai-proxy` 默认端口 **8787**，负责：



- 隐藏上游 API Key

- `x-proxy-token` 或 JWT 鉴权

- 月度 / 分钟级限流

- 统一输出 `{ summary, action, encourage }` JSON



---



## 6. AI 调用链路



### 6.1 实际运行配置



```env

AI_UPSTREAM_URL=https://api.deepseek.com/v1/chat/completions

AI_UPSTREAM_MODEL=deepseek-chat

```



`ai-proxy/server.js` 中 **`.env` 的 `AI_UPSTREAM_MODEL` 优先级最高**，会覆盖 iOS 客户端默认 model。



### 6.2 文档 vs 实际



| 来源 | 模型/厂商 | 说明 |

|------|----------|------|

| 旧版 `API_v0.1.md` | 智谱 `glm-4-flash` | 历史文档 |

| `ai-proxy/.env.example` | 火山引擎豆包 | 示例模板 |

| iOS `AppSettings` 默认 | `doubao-seed-1-6-flash-250828` | 客户端默认 |

| **服务器 `ai-proxy/.env`** | **DeepSeek `deepseek-chat`** | **运行时生效** |



### 6.3 推荐接入方式



| 方式 | 地址 | 鉴权 |

|------|------|------|

| 经 backend 转发（推荐） | `https://api.xuzhangapp.com/v1/ai/insight/daily` | 登录后 JWT |

| 直连 ai-proxy | 仅内网 `8787`（不对公网） | `x-proxy-token` / JWT |



---



## 7. Web 预览版



`web-preview/` 是约 4800 行的单文件 SPA（`app.js`），用于在 Windows 上无需 Mac 即可验证产品逻辑：



- 本地 `localStorage` 持久化

- 与 iOS 共享同一套分类、会员场景包、AI 端点配置

- 已完成稳定性 Sprint（`safeRender`、状态机、E2E 用例见 `web-preview/STABILITY_SPRINT_E2E.md`）



---



## 8. 环境变量与 Git



| 文件 | 是否提交 git | 用途 |

|------|-------------|------|

| `.env.example` / `.env.staging.example` | ✅ | 配置模板 |

| `.env` | ❌ | 真实密钥，程序实际读取 |



新环境初始化见 [`PROJECT_SETUP.md` §2–§3](PROJECT_SETUP.md)。



---



## 9. 部署与联调状态



### 9.1 生产（已完成）



| 项目 | 状态 |

|------|------|

| ECS `47.102.205.254` + git 部署 | ✅ |

| pm2：`backend` (8790)、`ai-proxy` (8787) | ✅ |

| PostgreSQL `xuzhang` | ✅ |

| HTTPS `api.xuzhangapp.com` | ✅ |

| SSL 测试证（至 2026-08-29） | ✅ |

| 短信 / 登录 / AI 全链路 curl | ✅ |

| iOS 模拟器联调 | ✅ |



**SSL 路径**（ECS）：



| 项目 | 路径 |

|------|------|

| Nginx 站点 | `/etc/nginx/sites-available/api.xuzhangapp.com` |

| 证书 | `/etc/nginx/ssl/api.xuzhangapp.com.pem` |

| 私钥 | `/etc/nginx/ssl/api.xuzhangapp.com.key` |



**代码目录（示例）**：`/opt/xuzhang/xuzhangapp`



### 9.2 Staging（文档就绪，待完整落地）



| 项目 | 状态 |

|------|------|

| 操作文档 `STAGING_ENV_SETUP.md` | ✅ |

| 环境变量模板 `backend/.env.staging.example` | ✅ |

| DNS `staging-api.xuzhangapp.com` | ⏳ |

| Staging SSL + Nginx | ⏳ |

| 独立目录 + pm2-staging + 库 `xuzhang_staging` | ⏳ |



### 9.3 域名



| 域名 | 用途 |

|------|------|

| `xuzhangapp.com` | 主域名 |

| `api.xuzhangapp.com` | 生产 API（HTTPS → 8790） |

| `staging-api.xuzhangapp.com` | 测试 API（规划 → 8791） |



ICP 备案进行中。



### 9.4 iOS 生产配置



| 设置项 | 值 |

|--------|-----|

| 后端根地址 | `https://api.xuzhangapp.com` |

| AI 接口地址 | `https://api.xuzhangapp.com/v1/ai/insight/daily` |

| 开启远程 AI | ✅ |



---



## 10. 完成度评估



| 能力 | 状态 |

|------|------|

| 本地记账 / 统计 | ✅ 可用 |

| AI 日复盘（backend → ai-proxy → DeepSeek） | ✅ 已接通 |

| Web 演示版 | ✅ 功能完整 |

| iOS UI 与 Web 对齐 | ✅ 基本完成 |

| 手机号登录 + 云端同步 | ✅ 开发环境可用 |

| HTTPS 生产 API | ✅ |

| PostgreSQL 持久化 | ✅ 生产已配 |

| 项目搭建文档 | ✅ `PROJECT_SETUP.md` |

| Staging 同机环境 | ⏳ 文档完成，待部署 |

| iPhone 真机全流程 | ⏳ 待验证 |

| 真实短信（Spug） | ⏳ 文档已备，代码待接入 |

| ICP 备案 | ⏳ 进行中 |

| 微信登录 / StoreKit IAP | ⏳ stub |

| OCR 真实识别 | ⏳ 占位 |

| 生产安全加固（token、关 dev 码） | ⏳ |



**进度概览**（与 `TODO.md` 一致）：



```text

服务端基础设施  ~80%   ✅

iOS 客户端联调  ~60%   ⏳ 差真机

上线准备        ~20%   ⏳ 备案 + 安全 + TestFlight

商业化          ~0%    ⏳ 微信 + IAP

```



---



## 11. Git 分支



```text

feature/*  →  feature/xuzhangapp-staging  →  xuzhang1.0-release-2026

```



| 分支 | 角色 |

|------|------|

| `feature/*` | 日常开发（当前：`feature/20260530-fix`） |

| `feature/xuzhangapp-staging` | Staging 测新功能 |

| `xuzhang1.0-release-2026` | 生产发版线 |



---



## 12. 文档索引



| 文档 | 说明 |

|------|------|

| **`PROJECT_SETUP.md`** | **项目搭建总览（本阶段最新）** |

| `STAGING_ENV_SETUP.md` | Staging 同机部署、分支发版、SSL 路径 |

| `TODO.md` | 进度与上线清单 |

| `PRD_v0.1.md` | 页面清单、字段设计、Prompt |

| `API_v0.1.md` | API 草案（部分待更新） |

| `MIGRATION_NOTES.md` | Web/iOS 迁移进度 |

| `SMS_TEMPLATE.md` / `SPUG_SMS_GUIDE.md` | 短信接入 |

| `NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md` | iOS 上线参数 |

| `backend/README.md` / `ai-proxy/README.md` | 子模块说明 |

| `LOGO_BRIEF.md` | 品牌 Logo 需求 |



---



## 13. 技术特点与潜在问题



### 优点



1. **本地优先**：不登录也能完整使用

2. **分层清晰**：iOS Services 与 backend 模块对应

3. **双端对齐**：Web 原型 + iOS 正式版

4. **AI 安全**：Key 不进客户端，走 proxy + 限流

5. **环境隔离设计**：Prod / Staging 分支与端口规划清晰



### 需关注



1. **Tab 级拆分已完成**：`ContentView` **~702 行**（壳）；`InsightWebView` ~805、`HomeViewModel` ~866 为 🟡 可排期债（见 [`TODO.md`](TODO.md) §结构债）

2. **文档与客户端默认 model**：服务端已统一 DeepSeek；iOS `AppSettings` 默认仍为历史豆包字段，以 `ai-proxy/.env` 为准

3. **SSL 测试证 90 天**：2026-08-29 前续签

4. **Staging 尚未完全部署**：避免与 prod 混用目录或 `.env`

5. **上架前必须**：真机验证、备案、关 dev 验证码、配置 `APP_PROXY_TOKEN`；**iOS/backend Release tier 门禁 ✅**



---



## 14. 建议的下一步



1. iPhone **真机**全流程（登录 → 记账 → 同步 → AI）

2. 按 `STAGING_ENV_SETUP.md` **落地 Staging**（DNS、SSL、pm2、独立库）

3. 完成 **ICP 备案**

4. 生产安全（Spug 短信、`APP_PROXY_TOKEN`、安全组）

5. TestFlight 内测 → App Store Connect



---



## 15. 目录结构速查



```text

xuzhangapp/

├── NativeDemoApp/              # iOS SwiftUI 主工程

├── NativeDemoApp.xcodeproj/

├── web-preview/                # Web 演示版

├── backend/                    # 业务后端 (8790)

├── ai-proxy/                   # AI 代理 (8787)

├── PROJECT_SETUP.md            # 项目搭建说明（最新）

├── STAGING_ENV_SETUP.md        # Staging 部署说明

├── PROJECT_ANALYSIS.md         # 本文件

├── TODO.md

├── PRD_v0.1.md

├── API_v0.1.md

└── README.md

```


