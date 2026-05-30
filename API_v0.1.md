# 轻账日记 API v0.1（客户端对接草案）

> 当前 iOS 客户端已内置对智谱 AI OpenAPI 的直连适配，也支持走后端代理。  
> 默认地址：`https://open.bigmodel.cn/api/paas/v4/chat/completions`  
> 默认模型：`glm-4-flash`

## 1. AI 每日复盘接口

- **Method**: `POST`
- **Path**: `/v1/insight/daily`
- **Auth**: `Authorization: Bearer <API_KEY>`（可选）
- **Content-Type**: `application/json`

### Request Body

```json
{
  "model": "glm-4-flash",
  "messages": [
    {"role": "system", "content": "系统提示词"},
    {"role": "user", "content": "用户提示词"}
  ],
  "temperature": 0.6
}
```

### Success Response（200）

```json
{
  "summary": "今天总支出较平稳，主要集中在餐饮和交通。",
  "action": "明天把咖啡消费减少一次，预算会更轻松。",
  "encourage": "你已经在认真管理消费了。"
}
```

## 1.1 推荐代理模式

- 代理地址示例：`POST https://your-domain.com/v1/insight/daily`
- 客户端可在 `x-proxy-token` 头中携带代理口令（可选）
- 代理层负责：
  - 保存 `ZHIPU_API_KEY`
  - 转发请求到智谱
  - 统一输出 `summary/action/encourage` JSON

### Error Response

```json
{
  "code": "UPSTREAM_TIMEOUT",
  "message": "model timeout"
}
```

## 2. 可选同步接口（预留）

### 2.1 Push 变更
- `POST /v1/sync/push`

### 2.2 Pull 变更
- `POST /v1/sync/pull`

### 2.3 清空云端副本
- `POST /v1/sync/reset`

## 3. 错误码约定

- `INVALID_ARGUMENT`：参数缺失或格式错误
- `UNAUTHORIZED`：认证失败
- `FORBIDDEN`：无权限
- `UPSTREAM_TIMEOUT`：模型超时
- `UPSTREAM_UNAVAILABLE`：模型服务不可用
- `INTERNAL_ERROR`：服务内部错误
