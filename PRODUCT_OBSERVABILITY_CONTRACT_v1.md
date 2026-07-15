# 叙账产品与性能可观测性契约 v1

> 生效日期：2026-07-15
> 默认实现：仅保存在本机 `UserDefaults`，不联网、不上传

## 1. 目标

本轮只回答以下产品问题：

- 第一笔是否成功保存，首个今日回放提示是否出现，用户是否明确开始回放。
- 用户是否打开并完成周记/月章回看。
- AI 指令台是否运行、结果属于哪类、是否保存了补记。
- 用户从哪个场景进入会员页，购买/恢复是否成功、失败、被阻止或无可恢复权益。
- 痕迹、复盘、AI 指令、月度整理、周/月回看在不同账本规模下处于哪个粗粒度耗时档位。

## 2. 禁止采集

任何事件都不得包含：

- 金额或总额，包括精确值和可反推精确值的统计。
- 备注、标题、商户、品牌、OCR 原文、AI 输入原文或生成正文。
- 照片、图片路径、哈希、城市、地点、天气明细、情绪原文。
- 账单 ID、用户 ID、手机号、云端账号 ID、设备 ID 或稳定匿名 ID。
- 精确账单条数、精确耗时；只保存下表定义的桶。

启动 v2 时必须删除旧 `ios_analytics_events_v1`，因为旧格式曾允许金额等自由属性。

## 3. 最小匿名事件表

| 漏斗 | 事件 | 允许属性 |
|---|---|---|
| 启动 | `app_opened` | `ledger_size_bucket` |
| 首记 | `record_saved` / `first_record_saved` | `source`、`is_first`、`ledger_size_bucket` |
| 首播 | `today_playback_prompt_shown` / `today_playback_started` / `today_playback_completed` | `prompt`、`is_first`、`progress_bucket` |
| 周/月回看 | `summary_playback_started` / `summary_playback_completed` | `range`、`progress_bucket` |
| AI 指令 | `ai_command_run_completed` / `ai_command_records_saved` | `result_kind`、`outcome`、账本规模桶、保存数量桶 |
| 会员 | `member_entry_opened` / `member_purchase_completed` / `member_restore_completed` | `scene`、`plan`、`outcome` |
| 性能 | `performance_measured` | `operation`、`duration_bucket`、`ledger_size_bucket`、`outcome` |

其余本地事件只允许无内容的动作名，或同一白名单中的桶/枚举属性。

## 4. 桶定义

- 数量/账本规模：`0`、`1`、`2_4`、`5_9`、`10_49`、`50_99`、`100_999`、`1000_4999`、`5000_plus`。
- 耗时：`under_50ms`、`50_149ms`、`150_399ms`、`400_999ms`、`1_2s`、`3s_plus`。
- 完成度：`under_80`、`80_plus`。

## 5. 存储与生命周期

- 最多保留 1,000 条、最多 30 天，超出后本机自动裁剪。
- 不建立跨安装、跨设备或跨账号稳定标识。
- 当前版本无上传端点、无后台上传任务、无第三方分析 SDK。
- 若未来需要上传，必须先单独评审用户开关、隐私政策、服务端保留和删除机制；不得直接复用本地日志扩大范围。

## 6. 性能边界

- 计时使用系统单调时钟，只持久化粗粒度耗时桶。
- 观测代码不得改变任务优先级、结果、取消规则、额度或交互状态。
- 被取消的旧请求不得反写新结果；是否记录取消只影响事件，不影响业务。

## 7. 自动门禁

- `AnalyticsService` 只提供类型化事件和属性键，不提供任意字符串事件接口。
- `scripts/observability_lint.py` 禁止网络依赖、敏感字段和精确金额/数量属性回流。
- `AnalyticsPrivacyBoundaryTests` 覆盖旧日志清理、白名单过滤、数量/耗时桶和 30 天保留。
