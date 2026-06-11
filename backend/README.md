# qingzhang-backend (v0 bootstrap)

用于 iOS 迁移阶段的后端骨架，优先跑通：

- 手机号验证码登录（开发验证码）
- 会员状态读取与开发态切换
- 账单同步接口（用户级）
- AI 复盘转发到 `ai-proxy`
- IAP 验单接口（App Store Server API，需配置 Apple 密钥）
- 内容安全检查（昵称/备注/AI 输入输出的基础隐私与违规风险拦截）
- 短信验证码发送/校验限频
- 云端账本删除与账号注销接口

## 1. 安装与启动

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

默认启动：`http://localhost:8790`

## 2. 关键接口

- `GET /health`
- `POST /v1/auth/sms/send`
- `POST /v1/auth/sms/verify`
- `POST /v1/auth/wechat/login` (stub)
- `GET /v1/member/me`
- `POST /v1/member/dev/set-tier` (dev only; `NODE_ENV=production` 下不注册)
- `GET /v1/ledger`
- `POST /v1/ledger`
- `DELETE /v1/ledger/:id`
- `DELETE /v1/ledger`（删除当前登录用户的云端账本）
- `DELETE /v1/account`（注销当前登录用户账号并删除云端数据）
- `POST /v1/iap/verify`
- `POST /v1/ai/insight/daily`

## 3. 说明

- 当前是内存存储版本，重启服务后数据会清空。
- 支持 PostgreSQL：设置 `DATABASE_URL` 后自动切换 DB 存储。
- 微信登录仍为 stub；IAP 验单配置 `APPLE_*` 与 `IAP_*_PRODUCT_ID` 后可联调沙盒/生产。
- 账单上行采用 `updatedAt` 冲突策略（新版本覆盖旧版本）。
- 账单写入会校验 `title`、`amount` 等基础字段，并拦截手机号、证件号、银行卡号、链接/邮箱、明显不适内容和少量公共安全高风险短语。
- AI 转发前后会做基础内容安全检查；日志只记录拦截原因和脱敏样本，不应记录完整账单正文。
- 短信验证码有 60 秒冷却、每手机号/IP 小时级发送上限和验证码错误次数上限；生产环境应替换真实短信服务并接入更强的 IP/设备风控。
- 埋点 props 会过滤 token/key/signed 字段，并脱敏手机号、证件号、银行卡号、链接/邮箱。
- `DELETE /v1/account` 会删除用户、会话、云端账本、短信验证码、内存埋点和服务端 IAP 绑定记录；Apple 订阅本身仍由 App Store 管理。

## 4. 与 iOS `NativeDemoApp` 联调

1. 本机启动：`npm run dev`（默认 `8790`）。
2. 模拟器：在 App **设置 → 云端账号** 中后端地址填 `http://127.0.0.1:8790`。
3. 开发验证码：与 `.env` 中 `DEV_ALLOW_SMS_CODE` 一致（默认 `123456`）。
4. 真机：将地址改为电脑的 **局域网 IP**（如 `http://192.168.1.5:8790`），并保证防火墙放行端口。
