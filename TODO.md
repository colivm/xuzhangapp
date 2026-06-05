# 叙账 · 进度清单

> 更新时间：2026-06-04  
> API 域名：`https://api.xuzhangapp.com`  
> v0.1 登录：**手机号验证码**（微信登录不做，见 v0.2+）

---

## ✅ 已完成（摘要）

- [x] 全栈骨架（iOS / web-preview / backend / ai-proxy）+ 五大 Tab
- [x] 生产 ECS、HTTPS、`api.xuzhangapp.com`、PG 持久化、AI 经 backend 转发
- [x] 生活切片 Phase B、动线 C1/C2、StoreKit 客户端骨架（**未接真实验单**）
- [x] 会员 UI、次数 enforce、Web OCR 四步确认流程（演示）

---

## ⏳ 待办 · 两栏

> **用法**：左栏按 **用户路径** 逐条真机 polish；右栏可与左栏并行，但 **收费上架前** 右栏必清。

| **栏 A · 体验细调**（功能已有，抛光质量） | **栏 B · 接真环境 / 上架**（基础设施与发布） |
|-------------------------------------------|-----------------------------------------------|
| **路径 1 · 新用户首记** | **真机全流程** |
| - [ ] 首记 → 今日回放引导（C1 话术/频率再验） | - [ ] 登录 → 记账 → 同步 → AI → 杀进程重开 |
| - [ ] 记 ≥3 / ≥5 笔 → 看看花角标/卡片提示 | - [ ] 使用 `https://api.xuzhangapp.com` |
| - [ ] **记账分类锁定**（手改分类后，金额推荐/一键备注不覆盖）— §10.12 | |
| - [ ] **智能分类推荐**（历史 + 时段 + 金额，非固定档位）— §10.13 | |
| - [ ] **天气场景宠物陪伴**（记完账/点宠物：雨天/高温等暖心提示，对齐 Web）— §10.14 | |
| - [ ] **场景备注包文案池扩展**（四包 128 条 + 稳定轮换 + 历史增强）— §10.16 | |
| | |
| **路径 2 · 生活切片** | **备案与合规** |
| - [ ] **B2.5** 叙事/UI（旁白为主、少报表感）— [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) §10.8 | - [ ] ICP 备案完成 |
| - [ ] **D1** 播完分享图（B2.5 后）— §10.9 | - [ ] 隐私政策 / 用户协议静态页 URL |
| - [ ] 免费次数与会员页文案一致（周 1 / 月 3 / OCR 3） | - [ ] App Store 隐私问卷与 [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) 一致 |
| | |
| **路径 3 · 智能导入** | **生产安全** |
| - [ ] **F1** 支付宝/微信 **账单详情** OCR + Web 四步确认 — §10.11 | - [ ] 真实短信（Spug）或关闭 dev 码 `123456` |
| - [ ] iOS 对齐 Web：进度 → 确认弹层 → 草稿区 | - [ ] `APP_PROXY_TOKEN`、关公网 8790/8787 |
| - [ ] 识别失败 / 取消不扣次 | - [ ] pm2/systemd 进程守护 |
| - [ ] 去掉或 `#if DEBUG`「演示 OCR」 | - [x] **主域 HTTPS**（`xuzhangapp.com` Let's Encrypt，到期 2026-09-02） |
| | - [ ] API 子域 SSL 续期（测试证 2026-08-29 前；可改 Let's Encrypt） |
| | |
| **路径 4 · 会员与 AI** | **TestFlight → 商店** |
| - [ ] 用尽话术（切片 / OCR / 今日回放）走一遍 | - [ ] TestFlight 内测分发 |
| - [ ] 播完 CTA：主会员、次「想多聊一句」 | - [ ] ASC：Bundle ID、截图、订阅说明 |
| - [ ] AI fallback 与远程失败提示 | - [ ] 真机 + 内测反馈一轮 |
| | |
| **路径 5 · 设置 / 账号** | **真实支付（收费前）** |
| - [ ] 手机号登录 / 退出 / Token 持久化 | - [ ] **E1** ASC Product ID + 推介首月 ¥6 — §10.10 |
| - [ ] 同步开关与冲突提示 | - [ ] 沙盒购买 → `POST /v1/iap/verify`（替换 501） |
| - [ ] 设置页 copy 与 v0.1 能力一致 | - [ ] `GET /v1/member/me` 刷新 tier；恢复购买 |
| | - [ ] Release 禁止 Debug 直接写 `memberTier` |
| | |
| **可选 polish** | **v0.2+（本版不做）** |
| - [ ] Logo / 启动图与 [`LOGO_BRIEF.md`](LOGO_BRIEF.md) | - [ ] 微信登录（已从 v0.1 移除） |
| - [ ] 拆分 `ContentView.swift` 巨型文件 | - [ ] 账单列表长图 OCR 多条 |
| - [ ] 空状态、弱数据切片 copy 再读一遍 | - [ ] 手机号哈希存储、正式 DV 证 |

---

## 🎯 建议顺序

```text
1. 栏 B：真机全流程（1～2 天）
2. 栏 A：B2.5 → D1 → F1（按 IMPLEMENTATION 任务单）
3. 栏 B：备案 + 生产安全（并行等待）
4. TestFlight 免费内测
5. 栏 B：E1 真实支付 → 开订阅
```

**真机验收路径：**

```text
设置页 → https://api.xuzhangapp.com 登录
  → 记一笔 / OCR 导入确认
  → 看看花 · 本周生活切片播放
  → AI 复盘（远程 + fallback）
  → 杀 App 重开
```

| 设置项 | 值 |
|--------|-----|
| 后端根地址 | `https://api.xuzhangapp.com` |
| AI 接口 | `https://api.xuzhangapp.com/v1/ai/insight/daily` |
| 开启远程 AI / 同步 | 按需 ✅ |

---

## 进度一览

```text
[████████████████░░░░]  功能 MVP         ~85%  ✅ B/C + StoreKit 骨架
[████████░░░░░░░░░░░░]  体验细调（栏 A）  ~40%  ⏳ B2.5 / D1 / F1
[████████░░░░░░░░░░░░]  接真环境（栏 B）  ~35%  ⏳ 真机 + 备案 + E1
```

---

## 相关文档

| 文档 | 用途 |
|------|------|
| [`IMPLEMENTATION_FOR_CODEX.md`](IMPLEMENTATION_FOR_CODEX.md) | B2.5 / D1 / F1 / E1 任务与 Codex 对话 |
| [`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md) | 切片、次数、会员、OCR 规则 |
| [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) | 上架文案与截图 |
| [`NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md`](NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md) | iOS 生产参数（v0.1 仅手机号） |
| [`TEST_CASES_v0.1.md`](TEST_CASES_v0.1.md) | **v0.1 全量测试用例**（P0 冒烟 + ~117 条） |
