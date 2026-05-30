# iOS 真实接入清单（微信 / 手机号 / AI / 会员）

本文件用于把当前 Web 实现迁移为可上线 iOS 版本。你已具备前端产品逻辑，这里只补齐生产级依赖与配置。

## 1. 必须准备的账号与配置

### 微信快捷登录

- 微信开放平台 `AppID`
- Universal Links 域名（含 `apple-app-site-association`）
- iOS URL Scheme（微信 SDK 需要）
- 微信审核通过的应用资质

### 手机号登录

- 短信平台（阿里云/腾讯云/自建）
- 验证码发送接口：`POST /auth/sms/send`
- 验证码校验接口：`POST /auth/sms/verify`
- 每手机号和每 IP 限流规则

### AI 复盘

- AI Proxy 线上地址（非 localhost）
- 线上 `x-proxy-token` 或 JWT 策略
- 模型名（建议：`doubao-seed-1-6-flash-250828`）
- 超时策略（建议：daily 15s / weekly 22s / monthly 35s）

### 会员与支付

- App Store Connect 内购产品 ID（月/年/永久）
- 服务端验单接口（建议）
- 用户会员状态查询接口

## 2. 需要你提供给我的参数（可直接复制填写）

```text
IOS_BUNDLE_ID=
IOS_MIN_VERSION=17.0

WECHAT_APP_ID=
WECHAT_UNIVERSAL_LINK=
WECHAT_URL_SCHEME=

SMS_BASE_URL=
SMS_SEND_PATH=/auth/sms/send
SMS_VERIFY_PATH=/auth/sms/verify

AI_PROXY_BASE_URL=
AI_PROXY_TOKEN=
AI_MODEL=doubao-seed-1-6-flash-250828

IAP_MONTHLY_PRODUCT_ID=
IAP_YEARLY_PRODUCT_ID=
IAP_LIFETIME_PRODUCT_ID=
```

## 3. 当前工程建议的接入顺序（最稳）

1. 先接 AI Proxy（已有业务价值，改动最小）
2. 再接手机号登录（验证码链路）
3. 再接微信登录（SDK、回调、审核链路）
4. 最后接内购会员（验单与权限状态）

## 4. 验收标准（上线前）

- 登录：
  - 微信登录成功后拿到业务 token
  - 手机号验证码登录成功
- AI：
  - 开关开启走线上 AI
  - 网络失败自动 fallback 本地文案
- 会员：
  - 购买后会员权益立刻生效
  - 重装后可恢复购买状态
- 稳定性：
  - 关键路径无崩溃（记账、编辑、删除、筛选、复盘）

