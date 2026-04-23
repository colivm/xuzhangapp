# ai-proxy

用于 `轻账日记` 的最小后端代理层，目标是：

- 隐藏智谱 API Key（不在 iOS 客户端暴露）
- 代理并清洗模型输出（统一返回 `summary/action/encourage`）
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

请求示例：

```json
{
  "model": "glm-4-flash",
  "messages": [
    { "role": "system", "content": "..." },
    { "role": "user", "content": "..." }
  ],
  "temperature": 0.6
}
```

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
