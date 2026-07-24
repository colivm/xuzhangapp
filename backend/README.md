# qingzhang-backend (v0 bootstrap)

用于 iOS 迁移阶段的后端骨架，优先跑通：

- 手机号验证码登录（阿里云短信；验证码可存 Redis）
- 会员状态读取与开发态切换
- 账单同步接口（用户级）
- AI 复盘、`narrative_rewrite_batch` 证据润色与可选 `cover_director` 封面导演转发到 `ai-proxy`
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
- `GET/POST /v1/member/nudge/policy` (dev only; `NODE_ENV=production` 下不注册)
- `POST /v1/member/nudge/evaluate`、`POST /v1/member/nudge/dismiss`（生产固定正式频控）
- `GET /v1/ledger`
- `POST /v1/ledger`
- `DELETE /v1/ledger/:id`
- `DELETE /v1/ledger`（删除当前登录用户的云端账本）
- `DELETE /v1/account`（注销当前登录用户账号并删除云端数据）
- `POST /v1/iap/verify`
- `POST /v1/ai/insight/daily`

## 3. 说明

- 未配置外部存储时使用内存模式，重启服务后数据会清空。
- 支持 PostgreSQL：设置 `DATABASE_URL` 后自动切换 DB 存储；生产环境必须配置。
- 支持 Redis 存储短信验证码：设置 `REDIS_URL` 后验证码会带 TTL 写入 Redis，验证成功后删除；生产环境必须配置。
- 微信登录仍为 stub；IAP 验单配置 `APPLE_*` 与 `IAP_*_PRODUCT_ID` 后可联调沙盒/生产。
- 账单上行采用 `updatedAt` 冲突策略（新版本覆盖旧版本）。
- 手机号登录签发的访问令牌有效期为 90 天；用户主动退出、服务端轮换 `JWT_SECRET` 或接口明确返回 401 时仍需重新登录。
- 账单写入会校验 `title`、`amount` 等基础字段，并拦截手机号、证件号、银行卡号、链接/邮箱、明显不适内容和少量公共安全高风险短语。
- AI 转发前后会做基础内容安全检查；日志只记录拦截原因和脱敏样本，不应记录完整账单正文。
- AI 轻润色与封面导演继续复用 `POST /v1/ai/insight/daily`；backend 只做 JWT、内容安全和内网转发，结构化 fact-pack/rewrites 与 director JSON Schema 由 `ai-proxy` 严格校验。封面导演代理跳转另有 9 秒取消边界；部署新能力时必须同步重启 `ai-proxy`，否则客户端会安全回退本地文案或本地封面 Recipe。
- 短信验证码有 60 秒冷却、每手机号/IP 小时级发送上限和验证码错误次数上限；生产环境应使用 Redis 存储验证码并接入更强的 IP/设备风控。
- 短信服务支持 `SMS_PROVIDER=dev` 和 `SMS_PROVIDER=aliyun`。本地/staging 可用 `DEV_ALLOW_SMS_CODE`；生产使用阿里云云通信号码认证服务 `SendSmsVerifyCode`，需配置 AccessKey、签名、模板 Code，可按需配置 `ALIYUN_SMS_SCHEME_NAME`、`ALIYUN_SMS_COUNTRY_CODE` 和模板有效期变量 `ALIYUN_SMS_TEMPLATE_MIN`。
- 埋点 props 会过滤 token/key/signed 字段，并脱敏手机号、证件号、银行卡号、链接/邮箱。
- `DELETE /v1/account` 会删除用户、会话、云端账本、短信验证码、内存埋点和服务端 IAP 绑定记录；Apple 订阅本身仍由 App Store 管理。
- `NODE_ENV=production` 下会启用启动门禁：必须配置强 `JWT_SECRET`、`DATABASE_URL`、`REDIS_URL`、非 `*` 的 `ALLOW_ORIGIN`、`AI_PROXY_TOKEN`、`SMS_PROVIDER=aliyun` 和阿里云短信参数，并且不能继续使用开发短信码。

## 4. 与 iOS `NativeDemoApp` 联调

1. 本机启动：`npm run dev`（默认 `8790`）。
2. 模拟器：在 App **设置 → 云端账号** 中后端地址填 `http://127.0.0.1:8790`。
3. 开发验证码：如需跳过真实短信，显式设置 `.env` 中的 `DEV_ALLOW_SMS_CODE`。
4. 真机：将地址改为电脑的 **局域网 IP**（如 `http://192.168.1.5:8790`），并保证防火墙放行端口。
