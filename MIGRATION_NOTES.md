# MIGRATION NOTES

更新时间：2026-04-27

## 会话标识

- 会话 ID：`4a2dbc35-1846-4e11-88a4-f01611b17b23`

## 本次已完成（Web 端）

- 修复保存后不回首页相关链路，统一为可靠跳转流程。
- 修复 `看看花` 列表空白问题（趋势图标签引用导致渲染中断）。
- 增加删除账单确认弹窗（应用内弹窗，非系统 confirm）。
- 优化金额输入焦点下的小助手点击：无需先失焦，首次点击可生效。
- 收窄“记账主链路”：
  - 默认保留核心路径（金额/分类/保存）
  - 小帮手改为“一键生成备注 + 展开更多场景”
- 修复“一键生成备注”与智能分类不一致问题（分类变化后立即重渲染小帮手）。
- 编辑态退出优化：
  - 从账单编辑页返回“记一笔/快速记账”时，重置为新建草稿态。
- 稳定性 Sprint 已落地：
  - `safeRender()` 保护层（关键渲染 try/catch + 错误记录）
  - 最小状态机（Tab/Modal/InputFocus）
  - `web-preview/STABILITY_SPRINT_E2E.md`（10 条关键回归用例）

## 本次已完成（iOS 端准备）

- 发现并复用现有 `NativeDemoApp` 工程（iOS 17+）。
- 新增真实接入清单：`NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md`
- 新增配置模板：`NativeDemoApp/AppSecrets.example.plist`
- 新增认证服务骨架：`NativeDemoApp/Services/AuthService.swift`
- iOS 默认 AI 模型已更新为：`doubao-seed-1-6-flash-250828`
  - `NativeDemoApp/Models/AppSettings.swift`
  - `NativeDemoApp/Services/AIReportService.swift`

## 你换电脑后优先做什么

1. 同账号登录 Cursor，打开会话 ID 对应历史。
2. 拉取/同步仓库最新代码。
3. 先跑 Web 回归：
   - 重点验证保存跳转、账单筛选、删除确认、小帮手点击。
4. 在 Mac 打开 `NativeDemoApp.xcodeproj`，确认可编译运行。
5. 按 `IOS_REAL_INTEGRATION_CHECKLIST.md` 填真实参数。

## iOS 真接入仍待你提供

- 微信：
  - `WeChatAppID`
  - `WeChatUniversalLink`
  - URL Scheme
- 手机号：
  - 短信发送/校验接口地址与协议
- AI：
  - 线上 `AI_PROXY_BASE_URL`
  - `AI_PROXY_TOKEN` 或 JWT 方案
- 会员内购：
  - 月/年/永久 Product ID

## 下一步实施建议（按顺序）

1. 接 AI Proxy 真接口（先打通复盘线上链路）
2. 接手机号登录
3. 接微信快捷登录
4. 接 StoreKit 会员内购与会员状态同步

## iOS ↔ backend 手机号登录（已接通）

- 设置页 **云端账号**：填后端根地址、手机号、验证码（开发环境默认与 `backend/.env` 的 `DEV_ALLOW_SMS_CODE` 一致）。
- 访问令牌存 **Keychain**；`cloudUserId` / `memberTier` 存 `AppSettings`。
- 详见 `backend/README.md` 第 4 节。

