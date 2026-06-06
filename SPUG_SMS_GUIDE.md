# 叙账 · Spug 短信接入指南

> 平台：[Spug 推送助手](https://push.spug.cc/)  
> 官方文档：[发送短信验证码](https://push.spug.cc/guide/sms-code)  
> 适用：个人开发者，无需企业认证

---

## 1. 为什么选 Spug

| 优势 | 说明 |
|------|------|
| 个人可用 | 微信扫码注册，无需企业资质 |
| 接入简单 | 一个 URL + POST 即可发码 |
| 适合本项目 | 登录验证码场景，与 `POST /v1/auth/sms/send` 匹配 |

---

## 2. Spug 控制台配置（3 步）

### ① 注册登录

访问 [push.spug.cc](https://push.spug.cc/) → 微信扫码登录

### ② 创建消息模板

路径：**消息模板 → 新建**

| 配置项 | 填什么 |
|--------|--------|
| 模板名称 | `叙账登录验证码` |
| 推送通道 | **短信** |
| 模板类型 | **验证码** |
| 推送对象 | **动态推送对象**（由 API 传手机号） |

平台提供的验证码模板正文类似：

```text
您的验证码是${code}，十分钟内有效，如非本人操作请忽略。
```

保存后记下 **模板 ID**（URL 中的一段，如 `A27LxxxxbgEY`）。

### ③ 安全设置（强烈建议）

个人中心 → **IP 白名单** → 填入服务器公网 IP：

```text
47.102.205.254
```

防止模板 URL 泄露后被盗刷。

---

## 3. Spug API 调用格式

**请求地址**：

```text
POST https://push.spug.cc/send/{模板ID}
Content-Type: application/json
```

**Request Body**：

```json
{
  "name": "叙账",
  "code": "836291",
  "targets": "13800138000"
}
```

| 参数 | 说明 | 本项目取值 |
|------|------|-----------|
| `name` | 应用名称 | `叙账` |
| `code` | 6 位验证码 | backend 随机生成 |
| `targets` | 手机号 | 用户输入的手机号 |

**curl 测试**（把 `模板ID` 换成你的）：

```bash
curl -X POST "https://push.spug.cc/send/你的模板ID" \
  -H "Content-Type: application/json" \
  -d '{"name":"叙账","code":"836291","targets":"13800138000"}'
```

---

## 4. backend 接入方案（待实现）

> 当前 backend 仍使用开发固定验证码（`DEV_ALLOW_SMS_CODE=123456`），尚未接入 Spug。  
> 以下为计划中的配置与改造说明，供后续开发参考。

### 计划中的环境变量

`backend/.env`：

```env
SMS_PROVIDER=spug
SPUG_SMS_TEMPLATE_ID=你的模板ID
SPUG_SMS_APP_NAME=叙账

# 生产务必删除或留空
# DEV_ALLOW_SMS_CODE=
```

### 计划中的 backend 改造点

1. 新增 `backend/src/sms.js`，封装 Spug 调用
2. 修改 `POST /v1/auth/sms/send`：
   - 生成随机 6 位验证码
   - 调用 Spug API 发送
   - 验证码存库，5 分钟过期
   - 60 秒发码冷却
3. `/v1/auth/sms/verify` 逻辑不变

### 开发 / 生产模式切换

| `SMS_PROVIDER` | 行为 |
|----------------|------|
| `dev` | 固定码 `123456`，不发短信 |
| `spug` | 随机 6 位码，调用 Spug 真实发送 |

---

## 5. 与本项目接口的关系

iOS 客户端**无需改动**，仍调用：

```http
POST https://api.xuzhangapp.com/v1/auth/sms/send
{"phone":"13800138000"}
```

接入 Spug 后的内部流程：

```text
校验手机号 → 60秒冷却检查 → 生成6位随机码
    → 调用 Spug API 发短信
    → 验证码存库（5分钟有效）
    → 返回 { "ok": true, "cooldownSec": 60 }
```

验证登录不变：

```http
POST https://api.xuzhangapp.com/v1/auth/sms/verify
{"phone":"13800138000","code":"836291"}
```

---

## 6. 费用与安全

- 短信约 **0.05 元/条**，按量计费，新用户有测试额度
- **不要**把模板 ID 提交到 git 或暴露给前端
- 模板 ID 存放在服务器 `backend/.env` 即可
- 在 Spug 控制台查看 **推送日志** 排查未收到短信的问题

---

## 7. 常见问题

| 问题 | 处理 |
|------|------|
| 没收到短信 | Spug 控制台 → 推送日志 |
| 余额不足 | 账户中心充值 |
| backend 返回发送失败 | 检查模板 ID、IP 白名单、余额 |
| 仍收到 `123456` | backend 尚未接入 Spug，仍走 dev 模式 |

---

## 8. 相关文档

- `SMS_TEMPLATE.md` — 短信文案模板（通用）
- `API_v0.1.md` — 短信接口说明
- `backend/README.md` — 后端联调
