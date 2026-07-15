# 叙账 · App Store Connect 内购建品清单

> 更新时间：2026-06-04  
> 用途：在 ASC 创建商品时逐项勾选；建好后把 **Product ID** 填回 `NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md` §2，再开发 **E1**（StoreKit + `/v1/iap/verify`）。  
> 定价依据：[`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md) §13、§13.1

---

## 0. 前置（没做完无法卖订阅）

- [ ] **Apple Developer Program** 已付费生效（¥688/年）
- [ ] ASC 已创建 App，**Bundle ID** = `com.xuzhang.app`（与 Xcode 一致）
- [ ] **App 隐私**、**年龄分级**、基础元数据已填（可随版本迭代）
- [ ] **协议、税务和银行业务** 已签署（付费 App 协议 + 银行信息），状态为「有效」
- [ ] 隐私政策 URL：`https://xuzhangapp.com/legal/privacy.html`
- [ ] 支持邮箱：`support@xuzhang.app`

---

## 1. 建议 Product ID（创建时直接用这个，后续代码照抄）

| 档位 | 建议 Product ID | backend `memberTier` |
|------|-----------------|----------------------|
| 月度订阅 | `com.xuzhang.app.member.monthly` | `monthly` |
| 年度订阅 | `com.xuzhang.app.member.yearly` | `yearly` |
| 永久会员 | `com.xuzhang.app.member.lifetime` | `lifetime` |

> ID 一旦上架后**很难改**，请确认 Bundle 前缀一致。若你更偏好 `subscription` 命名，可自定，但三档须与 iOS / 验单映射表一致。

**建好后填写（给 E1 开发用）：**

```text
IAP_MONTHLY_PRODUCT_ID=com.xuzhang.app.member.monthly
IAP_YEARLY_PRODUCT_ID=com.xuzhang.app.member.yearly
IAP_LIFETIME_PRODUCT_ID=com.xuzhang.app.member.lifetime
```

---

## 2. 订阅组（月付 + 年付）

路径：**App → 功能 → App 内购买项目 → 订阅 → 创建订阅组**

### 2.1 订阅组

| 项 | 建议填写 |
|----|----------|
| 参考名称（内部） | `xuzhang_member` |
| 订阅组显示名称（简体中文） | `叙账会员` |

### 2.2 订阅 ① — 年度（主推，组内排第一）

| 项 | 值 |
|----|-----|
| 参考名称 | `Member Yearly` |
| **Product ID** | `com.xuzhang.app.member.yearly` |
| 订阅时长 | **1 年** |
| 价格（中国区） | **¥88** |
| 显示名称（简中） | `年度会员` |
| 描述（简中） | 周/月生活切片无限回看、场景备注包、OCR 不限、账单字段云端备份等；记忆照片仅保存在本机，可手动导出。详见 App 内会员页。 |
| 审核备注（可选） | 自动续期订阅；可在 iPhone 设置 → Apple ID → 订阅中取消。 |

- [ ] 在订阅组内将 **年付设为默认/推荐**（展示顺序优先）

### 2.3 订阅 ② — 月度

| 项 | 值 |
|----|-----|
| 参考名称 | `Member Monthly` |
| **Product ID** | `com.xuzhang.app.member.monthly` |
| 订阅时长 | **1 个月** |
| 价格（中国区） | **¥9** |
| 显示名称（简中） | `月度会员` |
| 描述（简中） | 与年付相同会员权益；按月订阅，随时可在系统设置中取消。 |

### 2.4 推介促销 — 新用户首月 ¥6（必配，在**月付**商品上）

路径：该月度订阅 → **订阅价格** → **推介促销优惠**（Introductory Offer）

| 项 | 值 |
|----|-----|
| 类型 | **随用随付** 或 **免费试用** 以外的「**首期折扣**」→ 选 **Pay as you go / 按期付费折扣**（以 ASC 当前中文界面为准） |
| 时长 | **1 个月** |
| 价格 | **¥6** |
| 资格 | **新订阅者**（Never subscribed） |

会员页文案须写清：**「新用户首月 ¥6，之后 ¥9/月」**（见 §13.1，勿在客户端私改价）。

- [ ] 推介促销已保存并随月付商品一起提交审核

---

## 3. 非消耗型 — 永久会员（与订阅分开建）

路径：**App 内购买项目 → 非消耗型项目**（Non-Consumable）

| 项 | 值 |
|----|-----|
| 参考名称 | `Member Lifetime` |
| **Product ID** | `com.xuzhang.app.member.lifetime` |
| 价格（中国区） | **¥168**（常备价） |
| 显示名称（简中） | `永久会员` |
| 描述（简中） | 一次购买，长期解锁会员权益（与订阅权益一致，见 App 内说明）。 |

### 3.1 首发促销 ¥148（可选，上架后 90 天内）

路径：该非消耗型 → **促销优惠** 或 **App 促销**（按 ASC 当前入口）

| 项 | 值 |
|----|-----|
| 促销价 | **¥148** |
| 说明 | 会员页 + 商店描述写清 **恢复 ¥168 的日期**（§13.1），勿假限时 |

- [ ] 若 v0.1 不做首发促销，可暂只上 ¥168，后续再加促销

---

## 4. 本地化与审核材料（每个商品都要）

对每个订阅 / 永久商品：

- [ ] **简体中文** 显示名称、描述已填
- [ ] **审核截图**：会员页 `MemberPricingView`（含价格、权益五条、取消说明）
- [ ] **审核备注**（英文或中文均可），建议包含：

```text
叙账为记账与生活回望 App。订阅解锁：周/月生活切片无限、场景备注包、OCR 不限、账单字段云端备份等；记忆照片仅保存在本机，可手动导出。
免费用户：本周切片每自然周 1 次、本月生活章终生 3 次、OCR 每日 3 次。
测试：沙盒账号登录 → 设置/会员页 → 购买。恢复购买在会员页底部。
隐私政策：https://xuzhangapp.com/legal/privacy.html
```

---

## 5. 沙盒测试账号

路径：**用户和访问 → 沙盒 → 测试员**

- [ ] 新建至少 **1 个** 沙盒 Apple ID（勿用真实 Apple ID）
- [ ] 在 iPhone **设置 → App Store → 沙盒账户** 登录该账号
- [ ] 真机安装 **Development / TestFlight** 包后再测购买（不要用生产 Apple ID）

---

## 6. App Store Server API（E1 后端验单用，可与建品并行）

路径：**用户和访问 → 集成 → App Store Server API**（或「密钥」）

- [ ] 生成 **In-App Purchase** 专用 **API 密钥**（.p8），记下 **Issuer ID**、**Key ID**
- [ ] `.p8` 仅放服务器 `backend/.env`，**勿提交 git**
- [ ] `backend/.env.example` 预留：`APPLE_ISSUER_ID`、`APPLE_KEY_ID`、`APPLE_BUNDLE_ID`、`APPLE_PRIVATE_KEY_PATH`

验单接口：`POST /v1/iap/verify`（当前为 501，见 [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) §10.10）。

---

## 7. 商店文案对齐（与内购一致）

订阅说明 / App 描述建议包含（见 [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md)）：

> 免费：周记每自然周 1 次 · 月章终生 3 次 · 今日回放每日 1 次 · OCR 每日 3 次 · 记账与基础统计免费。
> 会员：周/月切片无限 + 场景备注包 + OCR 不限等。  
> 价格：年付 ¥88/年（推荐）· 月付 ¥9/月（新用户首月 ¥6）· 永久 ¥168。

- [ ] App 描述、订阅条款与 App 内 `MemberPricingView` 价格一致

---

## 8. TestFlight · Beta 版 App 信息（简体中文）

路径：**TestFlight → 测试 → Beta 版 App 信息**

| 字段 | 填写 |
|------|------|
| 反馈电子邮件 | `support@xuzhang.app` |
| 营销网址 | `https://xuzhangapp.com/` |
| 隐私政策网址 | `https://xuzhangapp.com/legal/privacy.html` |

**Beta 版 App 描述**（可复制到 ASC，勿写沙盒密码）：

```text
【叙账 · 内测说明】

叙账 = 记账 + **周记 / 月章**：把这段时间的花费讲给你听，像日记一样温柔回望。记账与基础统计始终免费。

—— 生活切片是什么 ——
在底部 **「看看花」** 里，筛选 **本周** 或 **本月**，会看到 **生活切片** 卡片（笔数、金额、「播放」）。点播放后，约半分钟讲完 **本周生活切片**；切到本月可体验 **本月生活章**（多幕完整月叙）。首页还有 **今日生活回放**（约 10 秒叙完今天）。

—— 内测建议怎么测生活切片 ——
1. 先记 ≥3 笔（本周）或 ≥15 笔（本月），让切片卡片可播。
2. 看看花 → 本周 → 点 **生活切片** 播放，听完每一幕。
3. 切到本月，试 **月章**（免费用户终生共 3 次完整体验，卡片会显示剩余次数）。
4. 今日 Tab / 看看花入口，试 **今日生活回放**。
5. 播完后看会员引导是否合理；会员可无限周/月切片。

免费额度（与正式版一致）：周记每自然周 1 次 · 月章终生 3 次 · 今日回放每日 1 次。

—— 其他 ——
· **无需登录**即可记账、查看周记和月章、收听今日回放（数据在本地）。
· 若要云端同步 / 远程 AI / 会员状态：设置 → 后端 `https://api.xuzhangapp.com` → 手机号 + 验证码登录。
· 测内购：iPhone「设置 → App Store → 沙盒账户」登录 ASC 沙盒测试员。
· 若本构建未接 StoreKit，会员购买可能仍为演示流程。

问题与截图：support@xuzhang.app 或 TestFlight「发送 Beta 反馈」。感谢内测！
```

### 8.1 Beta 版 App 审核信息（同页下方）

路径：**TestFlight → 测试信息 → Beta 版 App 审核信息**

| 字段 | 填写 |
|------|------|
| 姓氏 / 名字 | **开发者真实姓名**（与开发者账号联系人一致即可） |
| 电话号码 | **+86 手机号**（审核可能来电，务必能接通） |
| 电子邮件 | `support@xuzhang.app`（或与上相同的企业邮箱） |
| **需要登录** | **不要勾选**（本地优先，打开即用；见 `TEST_CASES_v0.1.md` TC-BOOT-01） |
| 用户名 / 密码 | 留空 |

**审核备注**（英文或中文均可，可复制）：

```text
叙账 (xuzhang) — TestFlight review notes

No sign-in required for core review:
- Open app → use immediately (no login wall).
- 记账、周记、月章、今日回放、OCR、本地规则整理均支持离线优先。

Optional sign-in (only if testing cloud / remote AI / member sync):
1. Settings (设置) → API: https://api.xuzhangapp.com
2. Phone: 13800138000 (any valid mainland 11-digit mobile starting with 1)
3. Send SMS code → enter: 123456 (fixed test code on server for review)

Core feature — 生活切片 (Life Slice playback):
1. Add ≥3 expenses this week (记账 tab → add a few items)
2. Tab 看看花 → filter 本周 → tap 生活切片 card → Play → watch full weekly slice
3. Switch filter to 本月 → 本月生活章 (free users: 3 lifetime full plays; card shows remaining count)
4. 今日 tab → 今日生活回放 (~10s)

IAP (subscriptions / lifetime):
- Before purchase: iPhone Settings → App Store → Sandbox Account → sign in with our sandbox tester (configured in ASC; not used for app login above)
- Member page: yearly ¥88, monthly ¥10 (intro ¥6 first month CN), lifetime ¥168
- If build has no StoreKit yet, member purchase may be demo-only — cloud sync still works after SMS login

Privacy: https://xuzhangapp.com/legal/privacy.html
Support: support@xuzhang.app
```

> **注意**：`xuzhang001@tester.com` 等是 **沙盒 Apple ID**（仅内购），与 App 内手机号登录无关。若将来勾选「需要登录」，再填审核专用手机号 + 验证码说明。上线 Spug 真实短信后，须为「可选登录」路径保留审核专用号或固定码。

---

## 9. 建品完成自检

- [ ] 3 个 Product ID 在 ASC 状态为 **准备提交** 或 **等待审核**（随 App 版本提交）
- [ ] 月付已挂 **首月 ¥6** 推介促销
- [ ] 年付、月付在 **同一订阅组**
- [ ] 永久为非消耗型，Product ID 已记录
- [ ] 沙盒账号可登录
- [ ] §1 中三个 ID 已抄到 `IOS_REAL_INTEGRATION_CHECKLIST.md` §2

---

## 10. 建品之后（代码，非 ASC）

| 步骤 | 文档 |
|------|------|
| StoreKit 2 + 恢复购买 | `IMPLEMENTATION_FOR_CODEX.md` §10.10 E1 |
| 服务端验单 | `API_v0.1.md` §8、`backend/src/server.js` |
| 沙盒验收 | `TEST_CASES_v0.1.md` TC-API-07 |

**建议顺序**：ASC 建品 → 沙盒能弹出购买 → 再合入 E1 代码 → 最后才开正式收费 / 对外宣传订阅。

---

## 11. 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-04 | 首版：三档 Product ID、订阅组、推介 ¥6、永久 ¥168/首发 ¥148、沙盒与 Server API |
| 2026-06-04 | §8：TestFlight Beta 描述（突出生活切片 / 看看花 / 周月章） |
| 2026-06-04 | §8.1：Beta 审核信息（默认不勾选需要登录；可选登录 13800138000/123456） |
