# 叙账 · 项目搭建说明

> 更新时间：2026-06-04  
> 产品版本：叙账 v0.1  
> 适用阶段：**主域 `xuzhangapp.com` HTTPS 已通**（Let's Encrypt，续期至 **2026-09-02**，certbot 自动续期）；API 子域见 §4.4

本文档汇总 **本机开发、生产 ECS、Staging 测试** 的搭建步骤。细节分支流程与 Staging 运维见 [`STAGING_ENV_SETUP.md`](STAGING_ENV_SETUP.md)。

---

## 1. 项目组成

```text
xuzhangapp/
├── NativeDemoApp/          # iOS 主工程（SwiftUI，iOS 17+）
├── NativeDemoApp.xcodeproj/
├── web-preview/            # Web 演示版（Windows 可跑，无需 Mac）
├── backend/                # 业务 API（默认 8790）
├── ai-proxy/               # AI 代理（默认 8787）
└── 文档/                   # PRD、API、TODO、本文件等
```

| 模块 | 技术 | 默认端口 | 说明 |
|------|------|----------|------|
| `backend` | Node.js + Express | 8790 | 登录、会员、账单同步、AI 转发 |
| `ai-proxy` | Node.js + Express | 8787 | 隐藏上游 Key、限流、JWT |
| `NativeDemoApp` | SwiftUI + MVVM | — | 主产品客户端 |
| `web-preview` | HTML/CSS/JS | 静态 | 本地打开或任意静态服务器 |

**运行时依赖**：Node.js 18+、npm；生产可选 PostgreSQL；iOS 需 macOS + Xcode 15+。

---

## 2. 快速开始（本机开发）

### 2.1 克隆仓库

```bash
git clone git@github.com:colivm/xuzhangapp.git
cd xuzhangapp
```

### 2.2 启动 ai-proxy

```bash
cd ai-proxy
npm install
cp .env.example .env
```

编辑 `ai-proxy/.env`（本地最小配置）：

```env
PORT=8787
AI_UPSTREAM_URL=https://api.deepseek.com/v1/chat/completions
AI_UPSTREAM_API_KEY=<你的 DeepSeek Key>
AI_UPSTREAM_MODEL=deepseek-chat
JWT_SECRET=<openssl rand -hex 32 生成>
REQUIRE_JWT=0
```

```bash
npm start
curl -s http://127.0.0.1:8787/health
```

### 2.3 启动 backend

```bash
cd backend
npm install
cp .env.example .env
```

编辑 `backend/.env`：

```env
PORT=8790
JWT_SECRET=<与 ai-proxy 验 JWT 策略一致或独立，开发可各写各的>
ALLOW_ORIGIN=http://localhost:8080
AI_PROXY_BASE_URL=http://127.0.0.1:8787
AI_PROXY_TOKEN=
DEV_ALLOW_SMS_CODE=123456
# 可选：不填则内存模式，重启丢数据
# DATABASE_URL=postgres://user:pass@127.0.0.1:5432/xuzhang
```

```bash
npm run dev
curl -s http://127.0.0.1:8790/health
```

### 2.4 Web 演示版（Windows / 任意 OS）

```bash
cd web-preview
# 直接用浏览器打开 index.html，或：
npx serve .
```

默认 AI 端点在 `app.js` 中为 `http://127.0.0.1:8787`；连远程 API 需改设置或常量。

### 2.5 iOS（Mac + Xcode）

1. 打开 `NativeDemoApp.xcodeproj`
2. 选择 iOS 17+ 模拟器，`Cmd + R` 运行
3. **设置 → 云端账号** 配置：

| 设置项 | 本机模拟器 | 真机（局域网） |
|--------|------------|----------------|
| 后端根地址 | `http://127.0.0.1:8790` | `http://<电脑局域网IP>:8790` |
| AI 接口地址 | `http://127.0.0.1:8790/v1/ai/insight/daily` | 同上 |
| 验证码 | `123456` | `123456` |

生产 / Staging 配置见 **§5**。

---

## 3. 环境变量说明

| 文件 | 提交 Git | 用途 |
|------|----------|------|
| `backend/.env.example` | ✅ | backend 模板 |
| `backend/.env.staging.example` | ✅ | Staging backend 模板 |
| `ai-proxy/.env.example` | ✅ | ai-proxy 模板 |
| `backend/.env` / `ai-proxy/.env` | ❌ | 真实密钥，勿提交 |

**生产与 Staging 必须隔离**：`JWT_SECRET`、`DATABASE_URL`、端口、域名均不同。

### 3.1 生成 `JWT_SECRET`（保存此命令）

在 **Mac / Linux / ECS** 上执行，生成 64 位十六进制随机串：

```bash
openssl rand -hex 32
```

用法：

1. 将输出填入 **同一环境** 的 `backend/.env` 与 `ai-proxy/.env` 的 `JWT_SECRET=`（两行必须完全相同）。
2. **生产** 与 **Staging** 各用各的，不要共用。
3. 首次部署、轮换密钥、或 `.env` 曾泄露时执行；轮换后需 `pm2 restart` 对应进程，用户需 **重新登录**。

轮换步骤（Staging 示例）：

```bash
# 1. 生成
openssl rand -hex 32

# 2. 分别写入 xuzhangapp-staging/backend/.env 与 ai-proxy/.env 的 JWT_SECRET
# 3. 重启
pm2 restart backend-staging ai-proxy-staging
```

生产将 `backend-staging` / `ai-proxy-staging` 改为 `backend` / `ai-proxy`，目录改为 `/opt/xuzhang/xuzhangapp`。

---

## 4. 生产环境（阿里云 ECS）

### 4.1 服务器与域名

| 项目 | 值 |
|------|-----|
| ECS IP | `47.102.205.254` |
| **主域名** | `https://xuzhangapp.com`（Let's Encrypt，`/etc/letsencrypt/live/xuzhangapp.com/`，到期 **2026-09-02**） |
| API 域名 | `https://api.xuzhangapp.com`（**已配 SSL**，见 §4.4） |
| 代码目录（示例） | `/opt/xuzhang/xuzhangapp` |
| backend 端口 | 8790（仅本机，Nginx 反代） |
| ai-proxy 端口 | 8787（仅本机） |
| 数据库 | PostgreSQL `xuzhang` |

### 4.2 部署步骤（首次 / 更新）

```bash
ssh root@47.102.205.254

cd /opt/xuzhang/xuzhangapp
git fetch origin
git switch xuzhang1.0-release-2026    # 生产跟踪发版分支
git pull

cd ai-proxy && npm install --omit=dev
cd ../backend && npm install --omit=dev

pm2 restart ai-proxy backend
pm2 save
```

`.env` 仅在服务器维护，**不要**从 Git 拉取；新机器从 `.env.example` 复制后按生产值填写。

### 4.3 pm2 进程（生产）

```bash
pm2 list
# 期望：backend (8790)、ai-proxy (8787)

pm2 logs backend --lines 50
pm2 logs ai-proxy --lines 50
```

首次启动（在对应目录、已配置 `.env`）：

```bash
cd /opt/xuzhang/xuzhangapp/ai-proxy
pm2 start server.js --name ai-proxy

cd /opt/xuzhang/xuzhangapp/backend
pm2 start src/server.js --name backend

pm2 save
```

### 4.4 Nginx + SSL（API 子域 `api.xuzhangapp.com`）

站点配置：`/etc/nginx/sites-available/api.xuzhangapp.com`

| 项目 | 路径 |
|------|------|
| SSL 证书 | `/etc/nginx/ssl/api.xuzhangapp.com.pem` |
| SSL 私钥 | `/etc/nginx/ssl/api.xuzhangapp.com.key` |

查证书路径：

```bash
grep -r "ssl_certificate" /etc/nginx/
openssl x509 -in /etc/nginx/ssl/api.xuzhangapp.com.pem -noout -dates
```

测试证有效期至 **2026-08-29**，到期前需续签或换 **Let's Encrypt**（见 §4.5 推荐方式）。

Nginx 将 `443` 反代到 `http://127.0.0.1:8790`；**8787 不对公网暴露**，AI 走 `POST /v1/ai/insight/daily` 由 backend 转发。

> **与主域关系**：`api.xuzhangapp.com` 与 `xuzhangapp.com` 为 **两个独立 Nginx server**、**两套证书**，互不影响。

### 4.5 主域 SSL + Nginx（`xuzhangapp.com`）

**现状**：主域已用 **certbot** 签发 HTTPS（2026-06 落地）；API 子域仍为独立测试证（§4.4）。  
**用途**：ICP 备案主站、App Store **隐私政策 URL**、用户协议链接（静态页后续部署，本节先打通 HTTPS + Nginx）。

#### 4.5.1 DNS（阿里云）

| 主机记录 | 类型 | 记录值 |
|----------|------|--------|
| `@` | A | `47.102.205.254` |
| `www` | A | `47.102.205.254`（或 CNAME → `xuzhangapp.com`） |

确认解析生效：

```bash
dig +short xuzhangapp.com
dig +short www.xuzhangapp.com
```

#### 4.5.2 静态目录（与代码同机，占位）

生产代码目录：**`/opt/xuzhang/xuzhangapp`**（与 §4.2 `git pull` 一致）。

**不要**把 Nginx `root` 指到仓库根目录（避免误暴露 `.env` 等）。仅暴露专用子目录：

```text
/opt/xuzhang/xuzhangapp/
├── backend/          # 不对外
├── site/             # 主域 Nginx 根（占位首页）
│   └── index.html
└── legal/            # 后续 Git 维护：privacy.html、terms.html
```

初始化占位（法务 HTML 尚未进仓库时）：

```bash
cd /opt/xuzhang/xuzhangapp
mkdir -p site legal
echo 'xuzhangapp' > site/index.html
# 后续：git pull 后 legal/*.html 出现在 /opt/xuzhang/xuzhangapp/legal/
chown -R www-data:www-data site legal   # Debian/Ubuntu；CentOS 用 nginx 用户
chmod -R o+rX site legal
```

对外 URL（静态页就绪后）：

```text
/opt/xuzhang/xuzhangapp/legal/privacy.html  → https://xuzhangapp.com/legal/privacy.html
/opt/xuzhang/xuzhangapp/legal/terms.html    → https://xuzhangapp.com/legal/terms.html
```

#### 4.5.3 Nginx 站点（HTTP，签证前）

新建 **`/etc/nginx/sites-available/xuzhangapp.com`**（与 `api.xuzhangapp.com` **分开文件**，互不影响）：

```nginx
# 主站 xuzhangapp.com — 静态（代码目录 /opt/xuzhang/xuzhangapp）
server {
    listen 80;
    listen [::]:80;
    server_name xuzhangapp.com www.xuzhangapp.com;

    root /opt/xuzhang/xuzhangapp/site;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # 法务页：仓库 legal/ 子目录（git pull 即更新）
    location /legal/ {
        alias /opt/xuzhang/xuzhangapp/legal/;
    }
}
```

**现有 API 配置保持不变**（`api.xuzhangapp.com` → 443 反代 `127.0.0.1:8790`）。  
两个 `server` 靠 `server_name` 区分，443 可并存多证书。

启用并重载：

```bash
ln -sf /etc/nginx/sites-available/xuzhangapp.com /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

浏览器可先测：`http://xuzhangapp.com/`（应看到占位页；**仍为 HTTP，属正常**）。

#### 4.5.4 申请 Let's Encrypt 证书（推荐，免费）

与 API 子域测试证 **独立**；主域建议用 certbot 自动续期：

```bash
# Debian/Ubuntu 示例
apt update
apt install -y certbot python3-certbot-nginx

certbot --nginx -d xuzhangapp.com -d www.xuzhangapp.com
```

按提示填写邮箱、同意条款。成功后 certbot 会：

- 写入 `listen 443 ssl` 与证书路径（通常在 `/etc/letsencrypt/live/xuzhangapp.com/`）
- 可选配置 HTTP → HTTPS 301

验证续期：

```bash
certbot renew --dry-run
```

#### 4.5.5 验收

```bash
curl -I https://xuzhangapp.com/
curl -I https://xuzhangapp.com/legal/terms.html   # 静态页上线前可能 404，但 HTTPS 应正常

openssl s_client -connect xuzhangapp.com:443 -servername xuzhangapp.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -dates
```

浏览器地址栏应显示 🔒。  
**App Store Connect / App 内链接须使用 `https://`，在 §4.5.4 完成后再填写。**

#### 4.5.6 常见问题

| 现象 | 处理 |
|------|------|
| certbot 报连接失败 | 安全组放行 **80**；DNS 是否指向 ECS |
| `www` 与裸域证书不一致 | 申请时 `-d` 同时包含两个域名 |
| 与 `api` 证书混淆 | `grep ssl_certificate /etc/nginx/sites-enabled/*` 分文件查看 |
| 只想先测 API | 法务 URL **不要**临时挂到 `api.xuzhangapp.com`（商店认主域） |

#### 4.5.7 后续（静态页，另任务）

1. 在仓库增加 `legal/privacy.html`、`legal/terms.html`，`git pull` 到 `/opt/xuzhang/xuzhangapp`  
2. iOS 设置页 / 会员页 / ASC 隐私 URL → `https://xuzhangapp.com/legal/...`  
3. 见 [`TODO.md`](TODO.md) 栏 B

### 4.6 生产验收（API）

```bash
curl -s https://api.xuzhangapp.com/health

curl -s -X POST https://api.xuzhangapp.com/v1/auth/sms/send \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000"}'

curl -s -X POST https://api.xuzhangapp.com/v1/auth/sms/verify \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","code":"123456"}'
# 返回 accessToken 后可用于 AI 接口
```

### 4.7 安全组建议

| 端口 | 公网 | 说明 |
|------|------|------|
| 80 / 443 | ✅ | 仅 Nginx |
| 8790 / 8787 | ❌ | 仅 127.0.0.1 |

上线前应：设置 `APP_PROXY_TOKEN`、关闭或替换 `DEV_ALLOW_SMS_CODE=123456`、接入真实短信（见 `SPUG_SMS_GUIDE.md`）。

---

## 5. 测试环境 Staging（同机）

与生产共用一台 ECS，**数据与密钥完全隔离**。

| 项目 | 生产 | Staging |
|------|------|---------|
| 域名 | `api.xuzhangapp.com` | `staging-api.xuzhangapp.com`（待 DNS + SSL） |
| 代码目录 | `/opt/xuzhang/xuzhangapp` | `/opt/xuzhang/xuzhangapp-staging` |
| backend | 8790 | **8791** |
| ai-proxy | 8787 | **8788** |
| 数据库 | `xuzhang` | **`xuzhang_staging`** |
| pm2 名 | `backend` / `ai-proxy` | `backend-staging` / `ai-proxy-staging` |
| 跟踪分支 | `xuzhang1.0-release-2026` | 测新功能：`feature/xuzhangapp-staging` |

**完整步骤**（DNS、建库、`.env`、Nginx、分支发版流程）→ [`STAGING_ENV_SETUP.md`](STAGING_ENV_SETUP.md)

iOS 内测包 Staging 配置：

| 设置项 | 值 |
|--------|-----|
| 后端根地址 | `https://staging-api.xuzhangapp.com` |
| AI 接口地址 | `https://staging-api.xuzhangapp.com/v1/ai/insight/daily` |

---

## 6. Git 分支与发版

```text
feature/*  →  feature/xuzhangapp-staging  →  xuzhang1.0-release-2026
  日常开发         Staging 测新功能              生产发版线
```

| 分支 | 用途 |
|------|------|
| `feature/*` | 功能开发 |
| `feature/xuzhangapp-staging` | 测试环境验收 |
| `xuzhang1.0-release-2026` | 生产 / 发版 |

**规则**：新功能先进测试分支 → Staging 验证 → 合并发版分支 → Staging 预发 → 再部署 Prod。

---

## 7. iOS 生产联调配置

| 设置项 | 值 |
|--------|-----|
| Bundle ID | `com.xuzhang.app` |
| 后端根地址 | `https://api.xuzhangapp.com` |
| AI 接口地址 | `https://api.xuzhangapp.com/v1/ai/insight/daily` |
| 开启远程 AI | ✅ |
| 开发验证码 | `123456`（上架前需关闭） |

真机全流程：登录 → 记账 → 同步 → AI 复盘 → 杀进程重开验证持久化。清单见 `NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md`。

---

## 8. AI 链路说明

当前线上 **实际使用 DeepSeek**（以服务器 `ai-proxy/.env` 为准）：

```env
AI_UPSTREAM_URL=https://api.deepseek.com/v1/chat/completions
AI_UPSTREAM_MODEL=deepseek-chat
```

推荐路径（iOS 已登录）：

```text
iOS → backend /v1/ai/insight/daily → ai-proxy → DeepSeek
```

`ai-proxy/.env` 中 `AI_UPSTREAM_MODEL` 优先级高于客户端传入的 model。

---

## 9. 文档索引

| 文档 | 说明 |
|------|------|
| **`PROJECT_SETUP.md`** | 本文件：搭建总览 |
| `PROJECT_ANALYSIS.md` | 架构与完成度分析 |
| `STAGING_ENV_SETUP.md` | Staging 同机部署与分支流程 |
| `TODO.md` | 进度与上线清单 |
| `PRD_v0.1.md` | 产品需求 |
| `API_v0.1.md` | 接口草案（部分待更新为 DeepSeek） |
| `backend/README.md` | backend 接口速查 |
| `ai-proxy/README.md` | AI 代理配置 |
| `SPUG_SMS_GUIDE.md` | 真实短信接入 |
| `NativeDemoApp/IOS_REAL_INTEGRATION_CHECKLIST.md` | iOS 上线参数 |

---

## 10. 常见问题

| 现象 | 处理 |
|------|------|
| `health` 502 | `pm2 list` 看进程；`pm2 restart backend ai-proxy` |
| iOS 连不上本机 backend | 真机改用局域网 IP；检查防火墙 |
| AI 返回 fallback | 查 `pm2 logs ai-proxy`；确认 `AI_UPSTREAM_API_KEY` 有效 |
| 登录 401 / AI 403 | JWT 过期重新登录；确认 backend 与 ai-proxy `JWT_SECRET` 一致（同环境） |
| 重启后用户数据丢失 | 未配置 `DATABASE_URL` 时为内存模式，生产必须配 PostgreSQL |
| Staging 像生产数据 | 确认 `DATABASE_URL` 为 `xuzhang_staging` |

---

## 11. 当前阶段下一步

1. **iPhone 真机**全流程验证（`https://api.xuzhangapp.com`）
2. **主域 HTTPS**（§4.5 Let's Encrypt + Nginx）
3. 完成 **ICP 备案**
4. 落地 **Staging**（DNS + SSL + pm2-staging，见 `STAGING_ENV_SETUP.md`）
5. 生产安全加固（`APP_PROXY_TOKEN`、真实短信、关闭 dev 验证码）
6. 主域部署隐私政策 / 用户协议静态页 → App Store / App 内链接
7. TestFlight 内测

进度细节见 [`TODO.md`](TODO.md)。
