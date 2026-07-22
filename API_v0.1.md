# 叙账 API v0.1

> 更新时间：2026-06-02  
> 线上 Base URL：`https://api.xuzhangapp.com`  
> 本地调试：`http://127.0.0.1:8790`

---

## 0. 架构概览

```text
iOS App / Web
      │
      ▼
https://api.xuzhangapp.com   (Nginx 443 → backend 8790)
      │
      ├── 认证 / 账单 / 会员 / 分析  → backend 直接处理
      │
      └── AI 复盘  POST /v1/ai/insight/daily
              │
              ▼
          ai-proxy 8787（仅内网，不对外暴露）
              │
              ▼
          DeepSeek API（deepseek-chat，由 ai-proxy/.env 配置）
```

**推荐客户端接入方式**：所有请求走 **backend**，AI 使用 `POST /v1/ai/insight/daily`，携带登录后的 JWT。  
ai-proxy 仅部署在服务器内网，客户端无需直连。

---

## 1. 通用约定

### 1.1 Base URL

| 环境 | 地址 |
|------|------|
| 生产 | `https://api.xuzhangapp.com` |
| Staging | `https://staging-api.xuzhangapp.com` |
| 本地 | `http://127.0.0.1:8790` |

### 1.2 请求头

```http
Content-Type: application/json
Authorization: Bearer <accessToken>   # 需登录的接口必填
```

> `Authorization` 必须包含 `Bearer ` 前缀（注意有空格）。

### 1.3 响应格式

backend 接口统一使用：

```json
{ "ok": true, ... }
```

或：

```json
{ "ok": false, "error": "ERROR_CODE", "message": "可选说明" }
```

ai-proxy 直连接口（仅服务端内部）使用 `{ "code": "...", "message": "..." }` 格式。

---

## 2. 健康检查

### `GET /health`

无需鉴权。

**Response 200**

```json
{
  "ok": true,
  "service": "qingzhang-backend",
  "now": "2026-06-01T03:00:00.000Z"
}
```

---

## 3. 认证

### 3.1 发送验证码

- **Method**: `POST`
- **Path**: `/v1/auth/sms/send`
- **Auth**: 无

**Request Body**

```json
{
  "phone": "13800138000"
}
```

**Response 200**

```json
{
  "ok": true,
  "cooldownSec": 60
}
```

**Errors**

| error | 说明 |
|-------|------|
| `INVALID_PHONE` | 手机号格式错误（须 11 位、1 开头） |

> **当前实现（开发模式）**：验证码固定为 `backend/.env` 中 `DEV_ALLOW_SMS_CODE`（默认 `123456`），不发送真实短信。  
> **计划接入**：[Spug 推送助手](https://push.spug.cc/) 发送真实验证码，详见 `SPUG_SMS_GUIDE.md`。

---

### 3.2 验证码登录

- **Method**: `POST`
- **Path**: `/v1/auth/sms/verify`
- **Auth**: 无

**Request Body**

```json
{
  "phone": "13800138000",
  "code": "123456"
}
```

**Response 200**

```json
{
  "ok": true,
  "user": {
    "userId": "f44ce25e-bcdd-46b3-8ab2-f987ef82b921",
    "displayName": "用户8000",
    "memberTier": "free",
    "memberExpiresAt": null
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Errors**

| error | 说明 |
|-------|------|
| `INVALID_CODE` | 验证码错误或已过期 |

`accessToken` 有效期 **7 天**，客户端应存入 Keychain。

---

### 3.3 微信登录（预留）

- **Method**: `POST`
- **Path**: `/v1/auth/wechat/login`
- **Status**: `501 WECHAT_NOT_IMPLEMENTED`

---

## 4. 会员

### 4.1 查询会员状态

- **Method**: `GET`
- **Path**: `/v1/member/me`
- **Auth**: Bearer JWT

**Response 200**

```json
{
  "ok": true,
  "memberTier": "free",
  "memberExpiresAt": null
}
```

会员档位：`free` / `monthly` / `yearly` / `lifetime`

---

### 4.2 开发态切换会员（仅 dev）

- **Method**: `POST`
- **Path**: `/v1/member/dev/set-tier`
- **Auth**: Bearer JWT

**Request Body**

```json
{ "tier": "monthly" }
```

---

### 4.3 会员 CTA 文案

- **Method**: `GET`
- **Path**: `/v1/member/cta-copy?scene=default`
- **Auth**: Bearer JWT

---

### 4.4 会员 Nudge 策略

| Method | Path | 说明 |
|--------|------|------|
| `GET` | `/v1/member/nudge/policy` | 读取策略与状态（仅本地/staging；生产不注册） |
| `POST` | `/v1/member/nudge/policy` | 更新调试策略（仅本地/staging；生产不注册） |
| `POST` | `/v1/member/nudge/evaluate` | 评估是否展示引导 |
| `POST` | `/v1/member/nudge/dismiss` | 记录用户关闭 |

生产默认固定为正式频控：每天最多一次，用户关闭同一场景后冷却 7 天；请求体不能切换到 90 秒调试冷却。

---

## 5. 账单同步

客户端本地账单字段参考 `HomeItem`：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID 字符串 | 账单唯一 ID |
| `title` | string | 备注 |
| `amount` | number | 金额 |
| `category` | string | 分类（餐饮/购物/交通/娱乐/日用/住宿/其他） |
| `source` | string | `manual` / `ocr` |
| `createdAt` | ISO8601 | 创建时间 |
| `updatedAt` | ISO8601 | 更新时间（冲突策略：新版本覆盖旧版本） |
| `emotionTag` | string | 情绪标签（可选） |

### 5.1 拉取账单

- **Method**: `GET`
- **Path**: `/v1/ledger`
- **Auth**: Bearer JWT

**Response 200**

```json
{
  "ok": true,
  "items": [ { "id": "...", "title": "午餐", "amount": 35.0 } ]
}
```

---

### 5.2 上传 / 更新账单

- **Method**: `POST`
- **Path**: `/v1/ledger`
- **Auth**: Bearer JWT

**Request Body**：完整 `HomeItem` JSON 对象（须含 `id`、`createdAt`）

**Response 200**

```json
{ "ok": true }
```

---

### 5.3 删除账单

- **Method**: `DELETE`
- **Path**: `/v1/ledger/:id`
- **Auth**: Bearer JWT

**Response 200**

```json
{ "ok": true }
```

---

## 6. AI 每日复盘（推荐路径）

### 6.1 经 backend 转发（iOS 推荐）

- **Method**: `POST`
- **Path**: `/v1/ai/insight/daily`
- **Auth**: `Authorization: Bearer <accessToken>`（**必填**）
- **Content-Type**: `application/json`

**Request Body**

```json
{
  "model": "deepseek-chat",
  "feature": "daily",
  "messages": [
    { "role": "system", "content": "你是温和消费复盘助手，只输出 JSON，字段为 summary/action/encourage" },
    { "role": "user", "content": "今日支出50元，主要餐饮。输出 summary/action/encourage JSON" }
  ],
  "temperature": 0.6
}
```

**feature 可选值**

| 值 | 说明 |
|----|------|
| `daily` | 日复盘 |
| `monthly` | 月复盘 |
| `narrative_rewrite_batch` | 日/周/月脱敏事实轻润色；服务端重建提示词并校验证据 |
| `quarterly` | 季度复盘（会员，ai-proxy 校验） |
| `yearly` | 年度复盘（会员，ai-proxy 校验） |

> 实际上游模型由 `ai-proxy/.env` 中 `AI_UPSTREAM_MODEL` 决定（当前为 `deepseek-chat`），客户端传的 `model` 为备选。

**Success Response 200**

```json
{
  "summary": "今天总支出较平稳，主要集中在餐饮。",
  "action": "今天的记录先停在这里。",
  "encourage": "这些具体片段已经留在账本里。"
}
```

`narrative_rewrite_batch` 不接受客户端自定义 messages，backend 会完整转发结构化 `factPacks`，ai-proxy 校验后自行生成模型提示词：

```json
{
  "model": "deepseek-chat",
  "feature": "narrative_rewrite_batch",
  "tone": "gentle",
  "factPacks": [
    {
      "scope": "week",
      "periodKey": "2026-W30",
      "facts": [
        {
          "id": "F1",
          "role": "lead",
          "kind": "rhythm",
          "label": "记录节奏",
          "statement": "这周有 5 笔记录，分布在 3 个记录日。",
          "evidenceCount": 5
        }
      ]
    }
  ],
  "temperature": 0.25
}
```

成功返回：

```json
{
  "rewrites": [
    {
      "scope": "week",
      "periodKey": "2026-W30",
      "headline": "这周留下几段记录",
      "summary": "5 笔记录分布在 3 个记录日。",
      "supportingLine": null,
      "evidenceIDs": ["F1"]
    }
  ]
}
```

**curl 示例**

```bash
# 1. 登录拿 token
curl -X POST https://api.xuzhangapp.com/v1/auth/sms/verify \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","code":"123456"}'

# 2. 调用 AI（注意 Bearer 前缀）
curl -X POST https://api.xuzhangapp.com/v1/ai/insight/daily \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <accessToken>" \
  -d '{
    "model": "deepseek-chat",
    "feature": "daily",
    "messages": [
      {"role":"system","content":"你是温和消费复盘助手，只输出JSON"},
      {"role":"user","content":"今日支出50元，主要餐饮"}
    ],
    "temperature": 0.6
  }'
```

---

### 6.2 ai-proxy 直连（仅服务端内部 / 调试）

- **内网地址**: `http://127.0.0.1:8787/v1/insight/daily`
- **Auth**: 可选 `x-proxy-token`（当 `APP_PROXY_TOKEN` 已配置时）
- **上游**: DeepSeek `https://api.deepseek.com/v1/chat/completions`

客户端 **不应** 直连 ai-proxy；密钥与限流均由 proxy 层管理。

---

### 6.3 iOS 内置生产配置

| 设置项 | 生产值 |
|--------|--------|
| 后端根地址 | `https://api.xuzhangapp.com` |
| AI 接口地址 | `https://api.xuzhangapp.com/v1/ai/insight/daily` |
| 开启远程 AI | ✅ |
| 上游 AI API Key | 仅服务器环境变量保存，App 不存储也不展示 |

上述地址不是用户设置项。正式 App 只展示联网整理开关；登录后 `AIReportService` 会自动在 `Authorization` 头附加 `Bearer <accessToken>`，上游 API Key 只存在于 ai-proxy 环境变量。

---

## 7. 分析与回放

### 7.1 埋点上报

- **Method**: `POST`
- **Path**: `/v1/analytics/events`
- **Auth**: Bearer JWT

**Request Body**

```json
{
  "event": "ai_daily_generated",
  "props": { "mode": "live" }
}
```

---

### 7.2 埋点查询

- **Method**: `GET`
- **Path**: `/v1/analytics/events?limit=200`
- **Auth**: Bearer JWT

---

### 7.3 埋点汇总

- **Method**: `GET`
- **Path**: `/v1/analytics/summary?days=7`
- **Auth**: Bearer JWT

---

### 7.4 今日消费回放

- **Method**: `GET`
- **Path**: `/v1/playback/today`
- **Auth**: Bearer JWT

---

## 8. 内购验单（预留）

- **Method**: `POST`
- **Path**: `/v1/iap/verify`
- **Status**: `501 IAP_VERIFY_NOT_IMPLEMENTED`

---

## 9. 错误码

### backend

| error | HTTP | 说明 |
|-------|------|------|
| `UNAUTHORIZED` | 401 | 未携带 Token 或格式错误（缺 `Bearer ` 前缀） |
| `INVALID_TOKEN` | 401 | Token 无效或过期 |
| `INVALID_PHONE` | 400 | 手机号格式错误 |
| `INVALID_CODE` | 400 | 验证码错误 |
| `INVALID_LEDGER_ITEM` | 400 | 账单字段缺失 |
| `INVALID_TIER` | 400 | 会员档位无效 |
| `INVALID_EVENT` | 400 | 埋点 event 为空 |
| `UPSTREAM_ERROR` | 502 | ai-proxy 转发失败 |
| `WECHAT_NOT_IMPLEMENTED` | 501 | 微信登录未接入 |
| `IAP_VERIFY_NOT_IMPLEMENTED` | 501 | 内购验单未接入 |

### ai-proxy（内部）

| code | 说明 |
|------|------|
| `UNAUTHORIZED` | proxy token 或 JWT 无效 |
| `FORBIDDEN` | 会员专属 feature 权限不足 |
| `RATE_LIMIT` | 触发限流 |
| `INVALID_ARGUMENT` | 参数缺失 |
| `UPSTREAM_ERROR` | DeepSeek 上游失败 |
| `PARSE_ERROR` | 模型输出无法解析为 JSON |
| `CONFIG_ERROR` | 服务端配置缺失 |
| `INTERNAL_ERROR` | 内部错误 |

---

## 10. 环境变量速查

### backend（`backend/.env`）

| 变量 | 说明 |
|------|------|
| `PORT` | 默认 8790 |
| `JWT_SECRET` | JWT 签名密钥 |
| `AI_PROXY_BASE_URL` | ai-proxy 内网地址，如 `http://127.0.0.1:8787` |
| `AI_PROXY_TOKEN` | 转发 ai-proxy 时的可选口令 |
| `DEV_ALLOW_SMS_CODE` | 开发固定验证码（生产应移除） |
| `DATABASE_URL` | PostgreSQL 连接串（可选） |

### ai-proxy（`ai-proxy/.env`）

| 变量 | 说明 |
|------|------|
| `AI_UPSTREAM_URL` | 当前：`https://api.deepseek.com/v1/chat/completions` |
| `AI_UPSTREAM_API_KEY` | DeepSeek API Key |
| `AI_UPSTREAM_MODEL` | 当前：`deepseek-chat` |
| `APP_PROXY_TOKEN` | 可选，防滥用 |
| `MONTHLY_REQUEST_LIMIT` | 代理层月度总调用上限 |

---

## 11. 相关文档

- `PROJECT_ANALYSIS.md` — 项目整体分析
- `TODO.md` — 项目进度清单
- `SPUG_SMS_GUIDE.md` — Spug 短信接入（计划）
- `SMS_TEMPLATE.md` — 短信申请模板
- `backend/README.md` — 后端安装与联调
- `ai-proxy/README.md` — AI 代理部署说明
