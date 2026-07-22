# ai-proxy

用于 `轻账日记` 的最小后端代理层，目标是：

- 隐藏上游模型 API Key（不在 iOS 客户端暴露）
- 按 `feature` 代理并清洗模型输出：旧洞察保持 `summary/action/encourage`，证据润色返回受校验的 `rewrites`
- 代理前后做基础内容安全检查，避免隐私串或明显违规内容进入/离开模型
- 支持可选代理口令
- 支持服务端月度总调用上限

## 1. 本地启动

1. 复制环境变量：
   - `cp .env.example .env`（Windows 可手动复制）
2. 填写 `.env`：
   - `AI_UPSTREAM_URL=...`
   - `AI_UPSTREAM_API_KEY=...`
   - `AI_UPSTREAM_MODEL=...`
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
- `narrative_rewrite_batch`（日/周/月脱敏事实轻润色；每批最多 3 组）
- `quarterly`（会员专属）
- `yearly`（会员专属）

未列出的 feature 会在调用模型前返回 `UNSUPPORTED_FEATURE`，避免通过动态 feature 名称绕过按能力划分的限流。

当 `feature` 为 `quarterly/yearly` 时，服务端会强制校验 JWT 中的会员态。

返回示例：

```json
{
  "summary": "今天消费较平稳，主要在餐饮与交通。",
  "action": "明天先减少一次冲动小额消费。",
  "encourage": "你已经在认真管理支出了。"
}
```

`narrative_rewrite_batch` 还必须提供顶层 `factPacks`。代理会在调用模型前校验 scope、periodKey、字段白名单、脱敏的 userText/photo 标签、每组唯一 lead 和 `F1...F6`；返回时再次校验长度、scope/periodKey、lead 引用、证据子集、数字与禁用推断词。合法返回格式：

```json
{
  "rewrites": [
    {
      "scope": "week",
      "periodKey": "2026-W30",
      "headline": "这周留下几段具体记录",
      "summary": "5 笔记录分布在 3 个记录日。",
      "supportingLine": null,
      "evidenceIDs": ["F1"]
    }
  ]
}
```

该 feature 不改变 `daily/monthly/quarterly/yearly` 的历史响应格式。代理升级后需重启 `ai-proxy`；公开 `backend` 路由无需新增地址，仍由 `/v1/ai/insight/daily` 转发。

## 3. iOS 端接入

正式 App 不向用户开放接口地址或上游 API Key 配置。生产地址由客户端固定为：

`https://api.xuzhangapp.com/v1/ai/insight/daily`

用户只控制是否开启联网整理；登录 JWT 由客户端自动携带，`backend` 使用服务端 `AI_PROXY_TOKEN` 访问本代理。代码中保留的智谱直连分支仅供内部开发兼容，不属于用户功能，也不得在正式设置页暴露上游密钥。

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
