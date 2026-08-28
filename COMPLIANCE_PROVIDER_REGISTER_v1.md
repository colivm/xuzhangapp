# 叙账 · 个人信息处理与第三方服务登记表 v1

> 核对日期：2026-08-28
> 用途：作为官网、隐私政策、用户协议、App Store 隐私标签和上线复核的事实来源；不替代律师意见或服务商最新条款。

## 1. 个人信息处理者

| 字段 | 当前事实 | 发布要求 |
|------|----------|----------|
| 产品 | 叙账（xLife） | 已确认 |
| 个人信息处理者法定名称 | 王义磊 | 运营方于 2026-08-28 确认为个人主体；Apple 卖方显示名 `yilei wang` 为同一自然人的英文显示名 |
| 主体类型 | 个人（自然人） | 运营方已确认 |
| 联系地区 | 江苏省南京市浦口区 | 运营方于 2026-08-28 确认；个人主体公开文本只写到区级，不公开住宅门牌 |
| 用户支持邮箱 | `support@xuzhang.app` | 运营方于 2026-08-28 确认可收信；需建立权利请求处理流程 |
| 一般咨询邮箱 | `hello@xuzhang.app` | 运营方于 2026-08-28 确认可收信 |
| 网站 | `https://xuzhangapp.com/` | 已上线 |
| ICP 公示 | `苏ICP备2026035096号-1` | 运营方确认 ICP 已完成且主体为王义磊（个人）；仓库与线上已展示 |
| 公安安全审核 | 全国互联网安全管理服务平台显示：王义磊“新增主体”（2026-06-02）、叙账“新增 APP”（2026-06-11）、叙账“安全评估”（2026-06-22）均审核通过 | 该截图证明 App 主体、App 和安全评估审核状态，不等同于网站“苏公网安备”号码；当前没有网站公安备案号证据，官网不得虚构或强行展示 |

## 2. 自有服务与数据位置

| 服务 | 已核实事实 | 数据与目的 | 保存/删除 |
|------|------------|------------|-----------|
| API 与云同步 | `api.xuzhangapp.com`，阿里云 ECS `cn-shanghai`（中国大陆上海） | 手机号账号、用户 ID、会员状态、开启云同步后的账单字段及天气/城市派生上下文；用于登录、同步、会员和联网整理转发 | 用户注销会删除账号、会话、账单和购买绑定；2026-08-28 已修复并部署旧 JWT 注销后仍可访问的问题 |
| PostgreSQL | 生产 backend 使用 PostgreSQL | 保存上述账号、会话、账单与购买绑定 | 随账号注销事务删除；备份周期仍需另行确认 |
| Nginx 访问日志 | 生产 Nginx | IP、请求时间、路径、状态码等安全与故障信息 | 当前按日轮转并保留 14 份压缩日志，约 14 天 |
| PM2 应用日志 | backend 与 ai-proxy | 启动、错误、内容安全拒绝原因；代码已尽量避免完整账单和敏感字段 | 当前未安装 `pm2-logrotate`，缺少确定上限；发布前应设置明确期限并写入政策 |
| 本机照片分析 | Apple Vision 与 Core Image，本机执行 | 人脸区域框、注意力显著性、画质、裁切安全与动态色板，仅用于封面排版 | 不做人脸身份识别，不生成生物识别模板；照片、像素、人脸框与色样不上传服务器 |

## 3. 第三方服务清单

### 3.1 阿里云号码认证/短信服务

- 生产事实：`SMS_PROVIDER=aliyun`，接口为 `dypnsapi.aliyuncs.com` 的 `SendSmsVerifyCode`；签名为“速通互联验证码”。
- 服务主体：服务协议列明阿里巴巴云计算（北京）有限公司与阿里云计算有限公司。
- 传输数据：手机号、国家/地区码、验证码、模板与签名参数；服务端连接还会产生服务器 IP 和调用日志。
- 目的：发送登录验证码和防止滥用。
- 官方协议：<https://terms.aliyun.com/legal-agreement/terms/suit_bu1_ali_cloud/suit_bu1_ali_cloud202012111724_21199.html>
- 官方隐私政策：<https://terms.aliyun.com/legal-agreement/terms/suit_bu1_ali_cloud/suit_bu1_ali_cloud202112211045_86198.html>
- 未决项：阿里云控制台/合同对应的日志与手机号保存期限需要运营方确认；不得自行承诺一个未经合同证明的期限。

### 3.2 DeepSeek 开放平台

- 生产事实：ai-proxy 实际上游为 `https://api.deepseek.com/v1/chat/completions`，模型为 `deepseek-chat`；仓库默认智谱配置不代表当前生产事实。
- 服务主体：杭州深度求索人工智能基础技术研究有限公司。
- 传输数据：启用“联网整理”后发送经过客户端和 backend 约束、脱敏的结构化事实与提示信息；可能包含日期范围、分类、金额/次数汇总、受控场景标签、匿名证据代号及内容指纹。不会发送手机号、登录令牌、照片、图片引用、账单 UUID、人脸框或色样。
- 目的：生成今日/月度等联网润色、结构化叙事改写及匿名封面模板选择结果；本地规则仍负责事实与结果校验。
- 开放平台服务协议：<https://cdn.deepseek.com/policies/zh-CN/deepseek-open-platform-terms-of-service.html>
- 隐私政策：<https://cdn.deepseek.com/policies/zh-CN/deepseek-privacy-policy.html>
- 合同要求：叙账作为下游服务提供者需向终端用户告知委托处理，取得合法性基础，并对 AI 生成内容作明确标识；模型输出可能错误，仅供参考。
- 未决项：公开协议没有给出叙账 API 输入/输出的固定日志保留天数，需要通过开放平台工单或合同确认；确认前法律文本应如实写“按服务商规则在实现目的所需期限内处理”，不得宣称零留存或不用于训练。

### 3.3 Apple WeatherKit

- 决策与实现：运营方于 2026-08-28 选择 Apple WeatherKit；iPhone 在用户允许定位并启用天气互动后，通过系统 WeatherKit 请求当前位置的当前天气。旧 Open-Meteo 免费直连已从客户端实现移除，不再作为发布依赖。
- 传输数据：请求所需的纬度、经度以及网络连接产生的 IP；不发送手机号、登录令牌、照片、账单标题、金额、备注或账单 UUID。
- 目的：取得当前温度与天气状况，在本机派生雨、雪、炎热、寒冷或普通天气上下文，用于可选的天气互动和记录语境。30 分钟缓存、定位权限时机和 Apple `CLGeocoder` 城市反查边界保持不变。
- 归因：设置中的天气开关附近展示 Apple Weather 组合标记或文字回退，并链接 WeatherKit 返回的法律归因页；网络失败时天气为可选空值，不阻断记账。
- 发布条件：Apple Developer Portal 中必须为 App ID `com.xuzhang.app` 开启 WeatherKit capability，并让新的 Development/Distribution provisioning profile 包含 `com.apple.developer.weatherkit`；Xcode Debug/Release 签名和真机请求仍需验证。
- Apple WeatherKit 与隐私说明：<https://developer.apple.com/weatherkit/>；运行时法律归因页由 `WeatherService.shared.attribution` 提供。

### 3.4 Apple

- `CoreLocation` / `CLGeocoder`：用户授权后处理设备位置和位置查询，用于获取 WeatherKit 当前天气并将坐标转换为城市；Apple 说明定位服务会将位置数据和查询发送给 Apple 及其合作方。官方说明：<https://www.apple.com/legal/privacy/data/en/location-services/>。
- App Store / StoreKit：处理产品 ID、交易 ID、原始交易 ID、购买环境与会员期限；backend 当前调用 App Store Server API 验证购买。
- Photos / Vision / Core Image：照片授权由 iOS 管理；叙账的人脸区域与画面分析只在本机执行，不等同于向 Apple 或叙账服务器上传照片。
- 发布前需复核 App Store Connect 隐私标签及 Apple 当前协议，并确认生产购买验证同时正确处理 Production 与 TestFlight Sandbox 环境。

### 3.5 Cloudflare Email Routing

- 生产事实：`xuzhang.app` 的 MX 记录指向 `route1.mx.cloudflare.net`、`route2.mx.cloudflare.net` 与 `route3.mx.cloudflare.net`；`support@xuzhang.app` 和 `hello@xuzhang.app` 均已确认可收信。
- 传输数据：只有用户主动发信时，Cloudflare Email Routing 才处理发件/收件地址、邮件内容、时间、投递与反滥用元数据，并转发至运营方配置的目标邮箱。
- 目的：接收用户支持、一般咨询、个人信息权利请求和安全事件报告。
- 官方隐私政策：<https://www.cloudflare.com/privacypolicy/>。
- 边界：不在 App 内自动上传账单、照片、位置或账号数据到 Cloudflare；若用户自行在邮件中附带这些信息，按其主动发送内容处理。

## 4. App Store 隐私标签事实基线

- 联系信息：手机号（账号登录）。
- 标识符：叙账用户 ID；购买验证涉及 App Account Token/交易标识。
- 购买项目：产品 ID、交易 ID、会员状态和到期时间。
- 用户内容：用户主动开启云同步后的账单标题、金额、分类、日期、备注及派生上下文；照片不上传。
- 位置：天气功能会在授权后向天气服务发送精确或近似坐标；城市名、天气与“本城/外地”等派生信息可能写入账单并随云同步上传。
- 使用数据/诊断：自有服务器产生 IP、请求路径、时间、状态和错误日志；App 的本地可观测性不上传。
- 敏感内容边界：联网 AI 只接收经约束和脱敏的结构化事实；照片、账号凭据、手机号、账单 UUID 和用户明确敏感原句不进入模型请求。

## 5. 发布前未决清单

1. 运营主体已确认为王义磊（个人），公开联系地区为江苏省南京市浦口区；Apple 卖方显示名 `yilei wang` 已确认是同一自然人的英文显示名。
2. App 公安安全审核已确认通过，不再作为本轮阻塞项；若以后另行取得网站“苏公网安备”正式编号，再补官网公示。`support@xuzhang.app` 与 `hello@xuzhang.app` 已确认可收信。
3. WeatherKit 客户端迁移后，仍需在 Apple Developer Portal 开启 capability、刷新签名描述文件，并完成 Xcode/真机请求和归因验证；未完成前不得把天气迁移标记为生产验收通过。
4. 向阿里云和 DeepSeek 确认实际合同下的请求/日志保留期限、删除机制与安全事件联络方式，并复核 Cloudflare Email Routing 的实际保留与转发配置。
5. 为 PM2 日志设置确定轮转/删除期限，并确认数据库备份位置、周期和注销后的备份清除策略。
6. 生产 IAP 验证不能只固定 Sandbox；需要完成 Production + Sandbox 路由回归。
