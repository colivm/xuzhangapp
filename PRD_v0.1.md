# 轻账日记 PRD v0.1（可开发版）

## 1. 产品目标

- 本地优先的 AI 轻记账 App，默认无需登录。
- 支持手动记账与 OCR 识别入账（v0.1 为可运行占位识别流程）。
- 每天生成 1 条温和消费复盘建议，不说教。
- 保留可选同步开关，为后续远程同步预留结构。

## 2. 页面清单

### 2.1 首页（今日总览）
- 展示：本月支出、最近 3 笔消费。
- 快捷操作：手动记账、OCR 识票。
- 入口：今日 AI 消费小结卡片。

### 2.2 记账页
- 分段：手动录入 / OCR 识票。
- 金额输入、分类选择、备注、日期。
- 保存后写入本地账单。

### 2.3 统计页
- 时间维度：本周 / 本月。
- 分类占比列表与近期账单列表。

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
你是“轻账日记”的温和消费复盘助手。
请根据消费聚合数据，输出简短复盘和一条可执行建议。
要求：不说教，不批判，不给投资买卖建议。
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

## 5. iOS 技术实现结构（SwiftUI + 本地库 + 可选同步）

### 5.1 架构
- SwiftUI + MVVM
- 本地存储：JSON 持久化（v0.1），后续可平滑迁移 SwiftData/SQLite
- 网络层：预留 AI 与同步服务接口

### 5.2 关键模块
- `LocalStore`：设置、账单、AI 报告读写
- `HomeViewModel`：账单管理、统计聚合、日报生成
- `SettingsViewModel`：设置项与主题控制
- `RecordView / StatsView / InsightView`：核心业务页面

### 5.3 可选同步策略
- 默认关闭，不影响本地使用。
- 仅当用户手动开启同步后才上传（v0.1 为开关与文案占位）。
- 关闭同步后保留本地数据，云端策略后续版本补充。
