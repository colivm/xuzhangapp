# 最近两次提交优化方案（2026-07-11）

## 1. 方案目标

基于 `RECENT_TWO_COMMITS_EVALUATION_2026-07-11.md`，将当前“条件稳定”提升到“稳定可发布”，同时保留这两次提交已经取得的收益：

- 保留面食账单的餐饮分类、情绪、场景和生活标记能力。
- 保留统一加载视觉、购买/同步反馈和分享图失败提示。
- 消除 OCR 关闭后仍写入账本的竞态。
- 移除无条件 `80ms` 人工延迟，避免为了显示加载态主动拖慢操作。
- 让统计与复盘的大数据计算逐步离开主线程，保证动画和交互连续。
- 建立可重复的正确性、并发、性能和无障碍验收基线。

## 2. 实施原则

1. **先正确性，后性能**：先修数据写入竞态，再调整加载体验，最后后台化计算。
2. **按风险拆分**：OCR 提交、加载状态、快照并发、语义治理分别实施，不放在一个大改动中。
3. **真实快才是快**：操作立即开始；加载态是结果，不应通过固定睡眠制造。
4. **已有内容优先**：刷新时保留旧内容可读，不用整页加载态替换，也不无条件锁住滚动。
5. **主线程只提交 UI**：纯数据过滤、分组、排序和文案输入准备可后台执行；SwiftUI、UIKit 截图和状态提交留在主线程。
6. **不使用逃避并发检查的方案**：迁移后台计算时不引入 `@unchecked Sendable`，先审核数据类型。

## 3. 优先级与预计投入

| 阶段 | 优先级 | 目标 | 预计投入 | 发布要求 |
|---|---|---|---:|---|
| Phase 0 | P0 | 修复 OCR 导入取消竞态 | 0.5-1 人日 | 必须完成 |
| Phase 1 | P1 | 收敛加载状态并移除固定延迟 | 1-2 人日 | 建议完成 |
| Phase 2 | P1 | 测量并优化统计/复盘主线程计算 | 2-4 人日 | 依据测量结果 |
| Phase 3 | P1 | 增加 XCTest、状态机和性能回归 | 1-2 人日 | 至少完成核心用例 |
| Phase 4 | P2 | 加强面食语义边界与词典一致性 | 1-1.5 人日 | 可独立迭代 |

总预计：**5.5-10.5 人日**。Phase 0 可独立快速落地；Phase 2 的实际投入应以 Instruments 数据为准。

### 当前实施状态（2026-07-11）

- Phase 0：已完成。OCR 已改为单次提交状态，提交期间禁止取消/下滑，任务可在页面消失前取消。
- Phase 1：已完成当前环境可验证部分。业务链路中的固定 `80ms` 已移除，缓存命中不再因 `onAppear` 重算，更新 Pill 改为只延迟显隐，旧内容刷新期间保留交互。
- Phase 2：未开始后台 Builder。需先在 macOS/Instruments 建立 100、1,000、5,000 条基线。
- Phase 3：已补静态状态约束和现有脚本回归；XCTest Target 尚待 macOS/Xcode 环境创建与执行。
- Phase 4：已补面膜、桌面服务、面料三条非餐饮反向样例；历史冲突和用户锁定用例仍待 XCTest。

## 4. Phase 0：修复 OCR 提交竞态

### 4.1 修改范围

- `NativeDemoApp/Views/OCRConfirmSheet.swift`
- `NativeDemoApp/Views/RecordView.swift`
- 可选：新增一个可测试的轻量 OCR 提交状态对象。

### 4.2 推荐实现

将当前 `isCollectingImport + importAction + 未保存 Task` 收敛成明确状态：

```swift
private enum ImportSubmissionState: Equatable {
    case idle
    case submitting(ImportAction)
}
```

执行顺序：

1. 用户点击导入，先从 `.idle` 原子切换到 `.submitting(action)`。
2. 立即禁用两个导入按钮和取消按钮。
3. Sheet 增加 `.interactiveDismissDisabled(isSubmitting)`，提交期间禁止下滑关闭。
4. 用保存的结构化任务执行提交；去掉 `Task.sleep(80ms)`。
5. 如需先提交当前 SwiftUI transaction，只执行一次 `await Task.yield()`。
6. `yield` 后检查 `Task.isCancelled`，再调用一次 `onConfirm`。
7. 返回数量大于 0 时关闭；返回 0 时恢复 `.idle` 并保留原错误状态。
8. `onDisappear` 取消尚未进入 `onConfirm` 的任务，并释放引用。

提交边界：`onConfirm` 一旦开始调用，即视为用户已经确认提交，不再提供“看似取消、实际无法回滚”的操作。

### 4.3 防重复要求

- 同一次 Sheet 生命周期内，`onConfirm` 最多调用一次。
- 连续快速点击两个导入入口，只接受第一个动作。
- 提交失败恢复后允许重新操作。
- 直接导入与进入整理必须保留各自原有语义。

### 4.4 验收用例

| 用例 | 操作 | 预期 |
|---|---|---|
| 正常进入整理 | 点击一次“进入整理” | 只导入一次，进入待整理区 |
| 正常直接导入 | 点击一次“直接导入” | 只导入一次，写入正式账本 |
| 连续点击 | 100ms 内连续点击 5 次 | 只调用一次 `onConfirm` |
| 提交中点取消 | 点击导入后立刻点取消 | 取消按钮不可用，不出现关闭后导入 |
| 提交中下滑 | 点击导入后立刻下滑 Sheet | Sheet 不关闭 |
| 导入返回 0 | 模拟配额不足或无有效记录 | 恢复可操作状态，不停留在加载态 |
| 父级强制关闭 | 提交真正开始前外部关闭 Sheet | 任务取消，不写入、不扣额度 |

### 4.5 回滚边界

本阶段不修改 `HomeViewModel.importOCRDrafts` 的分类和写入逻辑。若出现 UI 回归，只回滚 Sheet 状态管理，不影响语义提交和数据模型。

## 5. Phase 1：收敛加载状态并移除固定延迟

### 5.1 修改范围

- `NativeDemoApp/ViewModels/HomeViewModel.swift`
- `NativeDemoApp/Views/InsightWebView.swift`
- `NativeDemoApp/Views/StatsWebView.swift`
- `NativeDemoApp/Views/SummaryPlaybackSheet.swift`
- `NativeDemoApp/Views/Components/ComputationLoadingView.swift`

### 5.2 删除固定睡眠

移除以下无条件 `Task.sleep(nanoseconds: 80_000_000)`：

- 月度回顾本地聚合。
- 统计页快照准备。
- 复盘页快照准备。
- OCR 确认导入。
- 两处分享图生成。

替代策略：

- 操作状态在点击时立即设置。
- 必须让 SwiftUI 先提交一帧时使用一次 `Task.yield()`，随后检查取消。
- 网络、StoreKit、相册保存本身已有 suspension，不需要人工等待。
- UIKit/SwiftUI 分享图截图仍在 `MainActor` 执行，但不应先固定等待。

### 5.3 按场景定义加载反馈

| 场景 | 状态反馈 | 内容策略 | 交互策略 |
|---|---|---|---|
| 首次进入且无快照 | 立即显示页面加载态 | 暂无旧内容 | 页面操作不可用 |
| 已有快照刷新 | 超过 120-150ms 再显示更新 Pill | 保留旧内容 | 保持滚动；只禁用依赖新数据的动作 |
| OCR 识别 | 立即显示带真实进度的卡片 | 保留说明 | 禁止重复选图 |
| 购买/恢复/云同步 | 立即显示现有反馈 | 保留原状态源 | 禁止重复提交 |
| 分享图生成 | 按钮立即变为“生成中” | 保留当前页面 | 只禁用同一保存按钮 |
| 快速本地聚合 | 不显示全屏加载 | 直接出结果 | 不制造延迟 |

### 5.4 避免无效重复计算

`InsightWebView`：

- `onAppear` 仅在 `preparedInsightSnapshot == nil` 时准备首个快照。
- 数据变化继续由 `onChange(of: homeViewModel.items)` 驱动。
- 已有快照刷新时移除整页 `.allowsHitTesting(false)`；保留滚动和阅读。
- 快速连续变化继续使用 task cancellation + request ID，确保只提交最后结果。

`StatsWebView`：

- 切换到已经存在且未失效的模式时直接展示，不重新计算。
- 只使受筛选条件影响的缓存失效，避免所有筛选都清空周/月快照。
- 当前只展示周卡时先构建周快照；月快照在空闲时低优先级预热，或用户首次翻页时构建。
- 删除已经无调用的 `buildTraceChapterSnapshot()` 无参数版本和 `traceEmptyChapterSnapshot(for:)`。

### 5.5 加载组件完善

`ComputationLoadingView` 保持现有视觉，补以下行为：

- `progress != nil` 时给 VoiceOver 提供百分比 accessibility value。
- 加载状态增加适当的频繁更新/状态变化语义，避免只读一段静态详情。
- 检查 inline 图形在 320pt 宽度、超大动态字体下是否溢出；必要时让图形按布局尺寸真正缩小，而不是只用 `scaleEffect`。
- Reduce Motion 下保留明确的静态“处理中”信号，不依赖位移动画表达状态。

### 5.6 Phase 1 验收指标

- 缓存命中页面不再固定多等 80ms。
- 统计/复盘返回已有页面时不出现无意义的更新 Pill。
- 已有内容刷新期间可以正常滚动。
- 所有失败分支都能恢复按钮和状态。
- 快速切换 20 次筛选/模式后，最终内容只对应最后一次选择。
- 没有任务在页面消失后反写已经失效的页面状态。

## 6. Phase 2：统计与复盘性能优化

### 6.1 先建立测量基线

在改并发结构前，用 `OSSignposter` 或 Instruments 标记：

- `trace.week.snapshot`
- `trace.month.snapshot`
- `trace.clue.snapshot`
- `insight.week.snapshot`
- `monthly.local.aggregate`
- `share.week.snapshot`

记录字段只包含：条数区间、耗时、缓存是否命中、是否取消和结果类型，不记录备注、商户或金额明细。

测试数据规模：100、1,000、5,000 条；分别覆盖普通账单、带图片记忆、跨分类和大量同日记录。

建议性能目标：

- 主线程连续阻塞 P95 小于 16.7ms。
- 1,000 条统计/复盘聚合总耗时小于 150ms。
- 5,000 条聚合总耗时小于 400ms，且主线程仍可滚动和播放加载动画。
- 缓存命中后的内容提交小于 16.7ms。

### 6.2 优先做算法与缓存优化

先减少计算量，再迁移线程：

1. 一次遍历生成按日期、分类、总额、活跃日等基础索引，避免多个 helper 重复扫描 `items`。
2. `traceRhythmPoints` 使用日期桶计数，避免每个时间段再次过滤全量数组。
3. 周/月快照只构建当前需要的一个，另一份延迟预热。
4. 快照 key 只包含真正影响结果的字段，避免无关筛选造成缓存失效。
5. 已有快照与输入签名一致时直接返回，不在 `onAppear` 重建。

### 6.3 后台快照构建

仅当测量显示主线程阻塞超标时执行本步骤。

建议结构：

- `TraceSnapshotInput`：账单值快照、日期区间、会员状态和必要配置。
- `TraceSnapshotBuilder`：纯数据 builder，不引用 View、Color、EnvironmentObject 或 UIKit。
- `InsightSnapshotInput` / `InsightSnapshotBuilder`：同样只产出字符串和可发送的数据模型。
- builder 使用独立 actor 或非主线程 async 服务串行处理。
- View 在主线程抓取不可变输入，后台构建，最后在主线程校验 request ID 并提交。

并发约束：

- 审核 `HomeItem` 及嵌套类型后再声明 `Sendable`。
- 不使用 `@unchecked Sendable` 绕过编译器。
- 每个主要计算阶段检查 cancellation。
- 旧请求即使完成，也不能写入新筛选条件的页面。
- SwiftUI/UIImage 截图继续留在主线程；只把 payload 准备放到后台。

### 6.4 回退策略

- 保留同步 builder 作为实现对照，不保留两套业务规则。
- 后台构建失败或取消时继续显示最后有效快照，并提供重试，不清空页面。
- 性能改动单独发布，便于通过 crash/耗时数据判断是否回退。

## 7. Phase 3：测试体系补强

### 7.1 新增测试目标

当前 Xcode 工程只有 App Target，没有 XCTest Target。建议新增：

- `NativeDemoAppTests`：状态机、分类、快照 key、取消和失败复位。
- 后续需要时再增加 `NativeDemoAppUITests`，不在第一步同时扩大范围。

### 7.2 必测单元用例

OCR 提交：

- 只能从 idle 进入一次 submitting。
- 重复提交被拒绝。
- 调用前取消不执行写入闭包。
- 返回 0 恢复 idle。
- 成功后不会再次提交。

统计/复盘：

- request A 被 request B 替代后，A 不能提交。
- 相同输入签名命中缓存。
- items、日期范围、分类或会员状态变化时只失效相关缓存。
- 取消后 `isPreparing` 能回到一致状态，不永久显示加载。

分享图：

- payload 为空、截图失败、相册拒绝时按钮均恢复。
- 连续点击只生成一次。

### 7.3 自动化脚本接入

在现有 `ci_pre_xcodebuild.sh` 基础上固定执行：

1. `copy_lint.py`
2. `life_semantic_regression.py`
3. `theme_catalog_check.py`
4. `experience_static_check.ps1` 的跨平台等价检查，或在 Windows Job 执行原脚本。
5. macOS Job 的 Debug/Release build。
6. `NativeDemoAppTests`。

### 7.4 手工真机矩阵

- iPhone SE/小屏、标准屏和大屏。
- Reduce Motion 开/关。
- VoiceOver 开启，验证 OCR 百分比、购买和同步状态。
- 100、1,000、5,000 条账本。
- 相册权限允许、拒绝、受限。
- StoreKit 成功、取消、失败、恢复为空。
- 云同步成功、超时、断网。

## 8. Phase 4：面食语义长期治理

### 8.1 近期低风险补强

新增回归样例：

- 正向：牛肉面、兰州拉面、汤面、面馆、粉面、OCR 拆行和噪声文本。
- 历史冲突：相同金额过去常为交通，但备注明确为牛肉面，最终必须是餐饮。
- 用户锁定：用户手动锁定其他分类时不应强制覆盖。
- 反向：面膜、面料、桌面服务、界面设计、面试资料，不得因为含“面”误归餐饮。

### 8.2 一致性检查

扩展 `life_semantic_regression.py`：

- 对主 JSON、Swift fallback、emotion、LifeScene 和 LifeMark 的面食规范词集合做差集检查。
- 明确哪些词允许只存在于 OCR 或强覆盖层，避免将“所有集合必须完全相等”误作规则。
- 为否定分类增加明确字段，例如 `expectedCategoryNot`，避免用字符串约定混入正常分类字段。

### 8.3 中期收敛

建立一份规范语义源，生成或校验以下消费者：

- 主关键词规则。
- OCR 增强规则。
- Swift 最小 fallback。
- 情绪规则关联。
- 场景/生活标记关联。

不建议第一步就重写全部词典。先用差集检查暴露漂移，确认规则模型稳定后再生成代码。

## 9. 建议拆分的开发批次

### 批次 A：正确性热修

- OCR 提交状态和交互关闭策略。
- 移除 OCR 的固定 80ms。
- 核心手工验收。

完成标准：不存在关闭后写入，正常导入只执行一次。

### 批次 B：加载态可靠性

- 移除其他固定 80ms。
- `onAppear` 缓存命中不重算。
- 已有内容刷新不锁整页交互。
- 加载组件 accessibility 和小屏修正。
- 删除失效辅助方法。

完成标准：快速操作无状态卡死、无人工延迟、无旧任务反写。

### 批次 C：测量与性能

- Signpost、数据规模基准、重复扫描优化。
- 根据数据决定是否引入后台 builder。

完成标准：达到主线程阻塞和大账本耗时目标。

### 批次 D：测试与语义治理

- XCTest Target、状态机测试、缓存测试。
- 面食边界与历史冲突测试。
- CI 固化。

完成标准：核心竞态、取消和语义边界都能自动回归。

## 10. 发布门槛

以下条件全部满足后，可评为“稳定可发布”：

- OCR 竞态修复，取消/关闭不会产生数据写入或额度消耗。
- 所有固定 `80ms` 睡眠均移除或有明确、可测的业务理由。
- Debug/Release 构建和 XCTest 通过，无新增 Swift concurrency warning/error。
- 1,000 条账本下统计/复盘交互连续；5,000 条下无不可接受的主线程冻结。
- 快速切换筛选/模式只展示最后请求结果。
- 分享、购买、同步的成功/取消/失败路径全部能复位状态。
- Reduce Motion、VoiceOver 和小屏布局通过。
- 面食正向、反向、历史冲突和用户锁定样例通过。

## 11. 推荐结论

推荐立即实施 **批次 A**，它改动小、收益明确，是发版前的必要修复。随后实施 **批次 B**，将加载态从“固定延迟后的视觉反馈”调整为“由真实操作状态驱动”。

**批次 C 不应直接凭感觉后台化**：先测量，优先减少重复扫描和无效重算，只有主线程阻塞仍超标时再引入 actor/builder。语义治理独立放在批次 D，避免加载态优化同时改变分类行为。
