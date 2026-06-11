# ai-proxy

用于 `轻账日记` 的最小后端代理层，目标是：

- 隐藏智谱 API Key（不在 iOS 客户端暴露）
- 代理并清洗模型输出（统一返回 `summary/action/encourage`）
- 代理前后做基础内容安全检查，避免隐私串或明显违规内容进入/离开模型
- 支持可选代理口令
- 支持服务端月度总调用上限

## 1. 本地启动

1. 复制环境变量：
   - `cp .env.example .env`（Windows 可手动复制）
2. 填写 `.env`：
   - `ZHIPU_API_KEY=...`
3. 启动：
   - `npm start`

默认地址：`http://localhost:8787`

## 2. 接口

- 健康检查：`GET /health`
- AI 日报：`POST /v1/insight/daily`
- 本地调试签发 JWT：`POST /v1/auth/dev-token`

请求示例：

```json
{
  "model": "glm-4-flash",
  "feature": "daily",
  "messages": [
    { "role": "system", "content": "..." },
    { "role": "user", "content": "..." }
  ],
  "temperature": 0.6
}
```

`feature` 可选值：
- `daily`（普通）
- `monthly`（普通）
- `quarterly`（会员专属）
- `yearly`（会员专属）

当 `feature` 为 `quarterly/yearly` 时，服务端会强制校验 JWT 中的会员态。

返回示例：

```json
{
  "summary": "今天消费较平稳，主要在餐饮与交通。",
  "action": "明天先减少一次冲动小额消费。",
  "encourage": "你已经在认真管理支出了。"
}
```

## 3. iOS 端配置

在 App 设置页：

- 开启“远程 AI”
- `AI 接口地址` 填：`https://你的域名/v1/insight/daily`
- `AI API Key`：
  - 如果代理层配置了 `APP_PROXY_TOKEN`，这里填 token
  - 如果代理层未配置 token，可留空
- 模型可保留 `glm-4-flash`

## 4. 安全接入（防黑产）

### 4.1 鉴权
- 设置 `JWT_SECRET` 后，服务端支持 `Authorization: Bearer <token>`。
- 推荐开启 `REQUIRE_JWT=1`，强制所有请求带 JWT。

### 4.2 会员能力校验
- 服务端按 `feature` 判定能力等级。
- `quarterly/yearly` 必须是会员 JWT（`isMember=true` 或 `role=member`）。

### 4.3 限流
- `USER_RATE_LIMIT_PER_MINUTE`：普通能力每用户限流。
- `PREMIUM_RATE_LIMIT_PER_MINUTE`：会员专属能力每用户限流。
- `MONTHLY_REQUEST_LIMIT`：全局月度消耗上限。

### 4.4 内容安全
- AI 请求体会在转发前检查手机号、证件号、银行卡号、链接/邮箱、明显不适内容和少量公共安全高风险短语。
- AI 返回内容会在归一化前检查；未通过时返回 `AI_OUTPUT_REJECTED`。
- 风险日志只记录拦截原因和脱敏样本，不记录完整账单或完整 prompt。

### 4.5 本地开发快速拿 token
请求 `POST /v1/auth/dev-token`，示例 body：
```json
{
  "userId": "dev-user-001",
  "isMember": true,
  "expiresIn": "12h"
}
```
返回 `token` 后，前端可放到 `localStorage`：
- `qingzhang_ai_user_token`
- `qingzhang_ai_proxy_token`（可选，若你启用了 APP_PROXY_TOKEN）
