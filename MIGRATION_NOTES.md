# MIGRATION NOTES（历史记录）

> **更新时间：2026-06-02**  
> 本文档保留 **Web → iOS 迁移过程** 的历史记录。  
> **当前搭建、部署、进度请以以下文档为准：**
>
> - [`PROJECT_SETUP.md`](PROJECT_SETUP.md) — 本机 / 生产 / Staging 搭建
> - [`PROJECT_ANALYSIS.md`](PROJECT_ANALYSIS.md) — 架构与完成度
> - [`TODO.md`](TODO.md) — 待办与上线清单
> - [`STAGING_ENV_SETUP.md`](STAGING_ENV_SETUP.md) — Staging 同机部署

---

## 会话标识（历史）

- 会话 ID：`4a2dbc35-1846-4e11-88a4-f01611b17b23`

## 2026-04 已完成（Web 端）

- 修复保存后不回首页相关链路，统一为可靠跳转流程。
- 修复 `看看花` 列表空白问题（趋势图标签引用导致渲染中断）。
- 增加删除账单确认弹窗（应用内弹窗，非系统 confirm）。
- 优化金额输入焦点下的小助手点击。
- 收窄「记账主链路」、小帮手与智能分类联动。
- 稳定性 Sprint：`safeRender()`、状态机、`web-preview/STABILITY_SPRINT_E2E.md`。

## 2026-04 已完成（iOS 端准备）

- 复用 `NativeDemoApp` 工程（iOS 17+）。
- `IOS_REAL_INTEGRATION_CHECKLIST.md`、`AppSecrets.example.plist`
- `AuthService.swift` 等 Services 骨架
- iOS 默认 AI model 字段：`doubao-seed-1-6-flash-250828`（**服务端现用 DeepSeek，见 `PROJECT_SETUP.md`**）

## 2026-06 当前状态（已超越本文件初稿）

| 能力 | 状态 |
|------|------|
| 生产 HTTPS `api.xuzhangapp.com` | ✅ |
| backend + ai-proxy + PostgreSQL | ✅ |
| 手机号登录 + AI 日复盘（DeepSeek） | ✅ |
| iOS 模拟器联调 | ✅ |
| Staging 同机方案文档 | ✅ 见 `STAGING_ENV_SETUP.md` |
| 真机全流程 / ICP / 真实短信 / 微信 / IAP | ⏳ 见 `TODO.md` |

## 仍待接入

- 微信：`WeChatAppID`、Universal Link、URL Scheme
- 真实短信（Spug，见 `SPUG_SMS_GUIDE.md`）
- StoreKit 月/年/永久 Product ID 与验单
- OCR 真实识别（当前占位）

## iOS ↔ backend 手机号登录（已接通）

- 设置页 **云端账号**：后端根地址 + 验证码（开发默认 `123456`）。
- Token 存 **Keychain**；`cloudUserId` / `memberTier` 存 `AppSettings`。
- 详见 [`backend/README.md`](backend/README.md) §5。
