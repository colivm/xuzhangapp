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
- 账单上行采用 `updatedAt` 冲突策略（新版本覆盖旧版本）。删除为软删除：`ledgers.deleted_at` 记录墓碑并保留 180 天，`GET /v1/ledger` 同时返回 `tombstones`，让离线设备的旧副本不会把已删除记录重新推回云端；删除后又编辑（`updatedAt` 更晚）的记录会被恢复。清空云端账本也会批量写入墓碑，不再硬删除；客户端本机删除意图按账号持久化并在恢复联网后重试。
- IAP 绑定：交易首次绑定后 owner 不可改动；Production 和 Sandbox 对已有其他账号归属的交易都返回 `TRANSACTION_ALREADY_BOUND`。测试账号必须使用各自的专用沙盒 Apple ID；需要给另一个叙账账号独立开通时，应更换 Apple ID 后重新购买。
- 普通手机号登录签发的访问令牌有效期为 90 天；每个受保护请求在验签后还会核对账号当前是否存在。用户注销后旧令牌立即返回 401，不能重新写入账单或继续调用会员、AI 与分析接口；用户主动退出、服务端轮换 `JWT_SECRET` 或接口明确返回 401 时仍需重新登录。专用审核令牌的短期与撤销规则见第 5 节。
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

## 5. 可配置的专用 App Review 登录

只解决审核员无法收取短信的问题，不改变普通账号登录、会员/IAP、云端数据或 iOS 界面。默认关闭；模板在 `.env.review-login.example`，不得覆盖现有 `.env.example` / `.env.staging.example` 或两套线上环境文件。

启用前，选择自己控制、没有个人真实数据的专用手机号，并在安全的本地终端生成独立随机凭据。以下命令会显示敏感凭据，仅供运营者私密保管，不粘贴到 Git、公开文档、聊天日志或截图：

```bash
node --input-type=module -e "import {randomInt,createHash} from 'node:crypto'; const code=String(randomInt(0,1000000000000)).padStart(12,'0'); console.log('Private review credential:',code); console.log('REVIEW_LOGIN_CODE_SHA256='+createHash('sha256').update(code).digest('hex'));"
```

- 在各服务器私密 `.env` 单独添加 `REVIEW_LOGIN_ENABLED=true`、`REVIEW_LOGIN_PHONE`、`REVIEW_LOGIN_CODE_SHA256`、`REVIEW_LOGIN_EXPIRES_AT`。到期时间必须带时区，建议限定到审核窗口（例如 7–14 天），确保审核期间有效；服务器只存摘要，不存明文凭据。输入保留前导零，允许 8–12 位数字，建议使用上面生成的 12 位。
- staging/production 启用时都要求强 `JWT_SECRET` 和 Redis。Redis 按审核手机号原子计数：跨 IP、跨同环境 worker 每 10 分钟最多 10 次校验，包含成功，不因成功清零；原手机号/IP 限制保持。Redis 不可用时拒绝审核登录，不降级绕过。仅本地开发/测试可用内存计数。两环境继续使用各自 Redis/前缀与密钥。
- 配置只在进程启动时读取。按各环境现有部署方式重启所有 backend worker，若 PM2 也保存同名环境变量需同步更新；确认每个 worker 配置一致。不要重启或改动 AI proxy，不要复制其他环境的 JWT、数据库、IAP 或短信配置。
- 审核员同意协议后直接填手机号及专用凭据，点击“登录”；无需先发送短信。误点“发送验证码”保留原成功/冷却响应，但不会发送或轮换凭据。号码被启用配置保留期间（含已到期），错误凭据不能回退普通 SMS 校验；其他号码始终走原 SMS 路径。
- 审核凭据可重复登录；审核令牌最长 24 小时且不超过配置到期。停用、修改号码/摘要/到期时间并重启全部 worker 后，旧审核令牌返回 401；普通 90 天令牌不受影响。停用恢复该号码的普通短信流程。重新开启时必须生成新凭据，避免复用旧授权。注销账号仍使旧令牌失效。
- **不自动开会员、不预置个人数据。** 登录得到该账号的真实权益；提交前另行准备完整功能所需的专用测试数据/权限，并核对实际提审包能访问。不要通过开发会员接口在生产开后门。
- App Store Connect 勾选需要登录，用户名填专用手机号，密码栏填专用数字凭据，私密审核备注说明它对应 App 的“验证码”输入框。公开仓库不放真实手机号、摘要或凭据。
- 当前源码无需先发送短信、未限制验证码必须 6 位；仅修改 backend 即可兼容现有接口。仍须用实际提审 Build（本次 369）验证，不能只凭源码推断打包结果。正式包通常连接 production API，Apple Sandbox 并不等于 staging API。

部署后分别验证两环境：重复登录、误点发送不换码、普通短信登录、错码限流、会员实际可达；在专用测试环境验证停用/轮换/到期后旧令牌失效。对真实服务不要为了测试限流耗尽正在审核的账号预算。回退先关闭配置并重启，确认旧审核令牌失效；在此前签发的审核令牌全部过期前不要回退到不识别 `reviewGrant` 的旧 auth.js，否则旧代码可能继续接受这些令牌。
