# 叙账 PRD v0.1（可开发版）

> 战略层北极星见 **[`PRODUCT_NORTH_STAR.md`](PRODUCT_NORTH_STAR.md)**（生活回望、先叙后议、NSM）。

## 1. 产品目标

- **北极星**：生活回望——用「叙」把一段时间的花费温柔讲清楚（账为素材，叙为目的）。
- 本地优先，默认无需登录；记账主流程免费完整可用。
- 三种回看：**核心**为今日回放 + 统计页生活切片（周/月，本地模板叙事）；**可选**为小 AI 说远程复盘（先叙后议，无 AI 亦须能完成回望）。
- 支持手动记账与 OCR；AI 日复盘为增强能力，非产品主卖点。
- 可选登录与云端同步；会员售「省力记 + 深度叙」，详见 [`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md)。

## 2. 页面清单

### 2.1 首页（今日总览）
- 展示：本月支出、最近 3 笔消费。
- 快捷操作：手动记账、OCR 识票。
- 入口：今日 AI 消费小结卡片。

### 2.2 记账页
- 分段：手动录入 / OCR 识票。
- 金额输入、分类选择、备注、日期。
- 保存后写入本地账单。

### 2.3 统计页（看看花 / 账单）
- 时间维度：本周 / 本月 / 本年 / 自定义；分类筛选。
- 总览：总支出、近 30 天趋势图、趋势一句话。
- 记录列表。
- **规划**：筛选下方增加「生活切片」卡片（周度 5 幕 / 月度 6 章总结性回访），详见 [`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md)。

### 2.4 AI 复盘页
- 今日复盘：3 行以内总结 + 1 条行动建议。
- 历史复盘：按天查看，默认近 30 条。

### 2.5 设置页
- 主题模式、Face ID 锁（开关占位）、可选同步开关。
- 本地数据备份/恢复（v0.1 提供导出占位说明）。

## 3. 字段设计

### 3.1 TransactionRecord
- `id: UUID`
- `amount: Double`
- `category: Category`
- `note: String`
- `occurredAt: Date`
- `source: Source`（manual / ocr）
- `createdAt: Date`

### 3.2 DailyAIReport
- `id: UUID`
- `dayKey: String`（yyyy-MM-dd）
- `summary: String`
- `suggestion: String`
- `encourage: String`
- `createdAt: Date`

### 3.3 AppSettings
- `displayName: String`
- `notificationsEnabled: Bool`
- `appearance: Appearance`
- `biometricLockEnabled: Bool`
- `syncEnabled: Bool`
- `aiTone: AITone`

## 4. 每日 AI 报告 Prompt 模板

### 4.1 System Prompt
```text
你是“叙账”的温和消费复盘助手。
请根据消费聚合数据，输出简短复盘和一条可执行建议。
要求：语气像陪伴式周记，温柔具体；不提供投资买卖建议。
```

### 4.2 User Prompt
```text
日期：{{date}}
今日总支出：{{todayTotal}} 元
近7日平均日支出：{{weekAvg}} 元
本月累计支出：{{monthTotal}} 元
TOP分类：{{topCategories}}

请输出 JSON：
{
  "summary": "不超过80字",
  "action": "不超过50字",
  "encourage": "不超过30字"
}
```

## 5. 会员与回访（产品专篇）

免费/会员划界、今日回放、统计页生活切片、场景备注包、OCR 次数等，见 **[`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`](PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md)**。

## 6. iOS 技术实现结构（SwiftUI + 本地库 + 可选同步）

### 6.1 架构
- SwiftUI + MVVM
- 本地存储：JSON 持久化（v0.1），后续可平滑迁移 SwiftData/SQLite
- 网络层：预留 AI 与同步服务接口

### 6.2 关键模块
- `LocalStore`：设置、账单、AI 报告读写
- `HomeViewModel`：账单管理、统计聚合、日报生成
- `SettingsViewModel`：设置项与主题控制
- `RecordView / StatsView / InsightView`：核心业务页面

### 6.3 可选同步策略
- 默认关闭，不影响本地使用。
- 仅当用户手动开启同步后才上传（v0.1 为开关与文案占位）。
- 关闭同步后保留本地数据，云端策略后续版本补充。
