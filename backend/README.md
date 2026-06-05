# qingzhang-backend (v0 bootstrap)

用于 iOS 迁移阶段的后端骨架，优先跑通：

- 手机号验证码登录（开发验证码）
- 会员状态读取与开发态切换
- 账单同步接口（用户级）
- AI 复盘转发到 `ai-proxy`
- IAP 验单接口（App Store Server API，需配置 Apple 密钥）

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
- `POST /v1/member/dev/set-tier` (dev only)
- `GET /v1/ledger`
- `POST /v1/ledger`
- `DELETE /v1/ledger/:id`
- `POST /v1/iap/verify`
- `POST /v1/ai/insight/daily`

## 3. 说明

- 当前是内存存储版本，重启服务后数据会清空。
- 支持 PostgreSQL：设置 `DATABASE_URL` 后自动切换 DB 存储。
- 微信登录仍为 stub；IAP 验单配置 `APPLE_*` 与 `IAP_*_PRODUCT_ID` 后可联调沙盒/生产。
- 账单上行采用 `updatedAt` 冲突策略（新版本覆盖旧版本）。

## 4. 与 iOS `NativeDemoApp` 联调

1. 本机启动：`npm run dev`（默认 `8790`）。
2. 模拟器：在 App **设置 → 云端账号** 中后端地址填 `http://127.0.0.1:8790`。
3. 开发验证码：与 `.env` 中 `DEV_ALLOW_SMS_CODE` 一致（默认 `123456`）。
4. 真机：将地址改为电脑的 **局域网 IP**（如 `http://192.168.1.5:8790`），并保证防火墙放行端口。
