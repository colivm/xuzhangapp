# 临时 IAP 失败诊断

此功能仅诊断真实购买/恢复请求，不修复支付、不授予会员，不改变原错误返回、账号绑定或 401 回退规则。不需要重新编译 iOS。App 连接生产业务 API 与 TestFlight 的 Apple Sandbox 交易是两个独立环境。

## 启用前

先确认诊断补丁已经单独交付并部署到相应服务器目录。不要把本机未提交代码当成已上线，也不要为了诊断同步其他 iOS 修复。保留现有 `.env`，只增加下面三个独立选项；不改 Apple endpoint、密钥、手机号登录、Redis 或数据库配置。

默认关闭，误配只禁用诊断，不阻止服务启动。精确匹配登录后服务器查到的账号手机号，不信任请求体传入的手机号。每个 Node 进程最多 5 次、60 秒冷却、同时最多 1 次；多 worker 各有独立预算。重启会重置次数，但原到期时间不会延长。

## 配置与检查

在生产 `/opt/xuzhang/xuzhangapp/backend` 的现有 `.env` 中设置：

```dotenv
IAP_DIAGNOSTICS_ENABLED=true
IAP_DIAGNOSTICS_PHONE=填写这次购买登录的完整手机号
IAP_DIAGNOSTICS_EXPIRES_AT=填写下一条命令生成的时间
```

时间必须带时区，启动时最长距到期 24 小时，建议只开 1 小时。生成时间的命令不会修改文件：

```bash
node -p 'new Date(Date.now() + 60 * 60 * 1000).toISOString()'
```

生产目录中只读核对（不打印手机号或密钥）：

```bash
cd /opt/xuzhang/xuzhangapp/backend &&
node --input-type=module -e 'import {iapDiagnosticStatus} from "./src/iapDiagnostics.js"; console.log(iapDiagnosticStatus());'
```

输出 `active: true` 后，运营者确认目录/服务正确，再重启**对应服务**加载代码与配置：

```bash
pm2 restart backend --update-env
curl --fail --silent --show-error --max-time 10 --retry 5 --retry-delay 1 https://api.xuzhangapp.com/health
```

这些是用户手动操作步骤，不表示代理已执行。首次重启短暂 502 不应忽略，需最终 health 成功后再测试。CLI 检查读取当前目录和 shell 环境，不是 PM2 内存环境快照；若之前在 PM2 中注入了同名变量，它可能覆盖 `.env`。不要贴 `pm2 env`/`pm2 jlist` 全量输出，里面可能有凭据。

staging 如需诊断，单独在 `/opt/xuzhang/xuzhangapp-staging/backend` 配置同样三个选项，检查后仅重启 `backend-staging`，health 使用 `https://staging-api.xuzhangapp.com/health`。不复制整份生产 `.env`，不改原两套 endpoint。诊断自身会向两个固定 Apple 地址作 GET 对照；正式验单的路由仍保持各环境原规则。

## 获取一次有效证据

1. 在当前 TestFlight 包确认登录的手机号与目标一致，点击一次“恢复购买”。先不要反复创建购买；若沙盒订阅已过期、恢复无有效交易，可能不会发起服务端查验，此时没有诊断日志，不等于诊断通过。
2. 原错误仍可能显示——此补丁不改变验单结果。在原失败响应之后，最多额外做两次只读 Apple GET，分别检查 Production/Sandbox；每次 8 秒上限、响应体最多 128 KiB、不跟随重定向。诊断与日志失败均不能开会员或覆盖原响应。
3. 只取诊断行，别发完整服务器日志：

```bash
pm2 logs backend --lines 200 --nostream | grep -F '[iap-diagnostic]'
```

日志不会输出私钥、Bearer/JWT、手机号、账号 ID、完整交易号、完整票据、原始 Apple 错误消息或任意客户端文本。

| 字段 | 含义 |
|---|---|
| `diagnosticId` | 随机的一次诊断关联号，不是交易号 |
| `failedLookupEnvironment / failedLookupStatus` | 正常验单最终失败的那次 Apple 查询，不一定是首个查询；原 Production 404→Sandbox 401 会记 Sandbox |
| `clientEnvironmentHint` | 从客户端票据读取的环境提示；`clientHintVerified=false`，不是可信验单结果 |
| `checks[].environment / httpStatus / appleErrorCode` | 本次真实交易在各 Apple 端点的只读响应 |
| `clockDifferenceSeconds` | Apple HTTP Date 与服务器读取时刻的大致差值，包含网络延迟 |
| `productMatches / transactionMatches / bundleMatches / accountMatches` | 返回载荷与这次请求的匹配布尔值，不输出原始标识 |
| `expired / revoked` | 载荷的过期/撤销观察值；缺失有效期时为 null |
| `signatureVerified=false / grantsMembership=false` | 诊断没有新增 JWS 签名验证，也永不授予会员；HTTP 200 不代表完整支付验收通过 |
| `outcome` | `timeout`、`body_limit` 或 `probe_failed` 等固定诊断失败枚举 |

Production 401＋Sandbox 200 且各匹配项 true：获得真实沙盒交易可查询的证据，再安排独立路由修复。两端均 401：继续查密钥/授权。Sandbox 404：不能假装查询成功。任何账号/商品/应用不匹配、过期或撤销都不能据此开会员。Production 401 本身仍须在正式收费前另行关闭。

没有日志时依次核对：是否已部署/重启、开关/到期/精确手机号、是否真的发出验单请求、是否 Apple 查单错误（仅 LOOKUP_FAILED/TRANSACTION_NOT_FOUND/BAD_RESPONSE）、是否在 60 秒冷却或已到 5 次进程上限。诊断不在未登录、未知商品或账号绑定失败时运行。

## 结束与回退

收到所需日志后，将 `IAP_DIAGNOSTICS_ENABLED=false`，重启对应服务；不要通过重启不断刷诊断预算。到期会自动停止新的诊断，已在途的单次探测最多再运行 8 秒。生产与 staging 分别关闭，不能改用另一个环境的配置。

回退优先关闭诊断并重启。原验单/会员逻辑未改，不需要撤销交易、删除订单、关闭审核登录或换 Apple 密钥。不得因测试沙盒通过而忽略仍未关闭的正式生产验单或既有 JWS 签名链安全缺口。

## 后续 Sandbox 路由补丁的诊断边界

独立路由补丁不会自动开启诊断，也不依赖诊断开关。生产业务 API 收到大小不超过 32 KiB、结构可解析且 header.alg=ES256 的客户端 JWS，只有其中 Sandbox 提示的交易号、商品和 bundle 都与请求/本服务一致时，才直接查询固定 Apple Sandbox 地址。格式与字段匹配不是签名验证；客户端 JWS 不作为权益依据，仍重新向 Apple 查询并执行原校验。其余请求维持配置的主端点及原交易不存在回退，401 不新增回退；staging 仍只查询 Sandbox。

因此补丁部署后，同一恢复请求可能从 Production 401 变成真正的账号归属拒绝：旧 staging 购买与当前生产账号的内部 ID 可能不同，即使手机号和 Apple ID 相同。缺少票据账号标识与已有其他账号绑定仍按原规则处理，不自动迁移或改绑。`accountMatches=false` 本身不能区分标识缺失、不同或数据库归属，也不应据此直接开会员。

匹配的 Sandbox 请求不再经过 Production，所以成功或账号校验失败时没有新的诊断日志是预期行为（诊断只监听 Apple 查询错误）。旧 iOS 的“没有可恢复权益”通用提示本轮未改；无日志不能单独证明恢复成功，需检查服务端返回/会员状态。此路由补丁不代表 Production 401 的授权原因已经修复，也没有补齐既有 Apple JWS 签名链验证。
