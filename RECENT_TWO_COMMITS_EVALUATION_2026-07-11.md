# 最近两次提交评估（2026-07-11）

## 1. 评估范围

- 分支：`feature/xuzhangapp-staging`
- 基线：`8b6069f3f8da6bac3d4dad3e0a3322ebb1db52b2`
- 提交一：`85c37de9d59942af5b4b1a26fbdd0a5c84de5304`，`fix: classify noodle bills as dining`
- 提交二：`44365d3acc01384c2b14674910b5b73d66a6d346`，`Add computation loading states`
- 合计变更：16 个文件，约 590 行新增、152 行删除。
- 评估方式：逐提交 diff、相关调用链、状态生命周期、回归脚本、静态检查和工程文件结构检查。
- 本次只产出评估文档，没有修改业务代码，没有提交 Git。

## 2. 总体结论

**结论：可作为后续迭代基线保留，但建议在正式发版前修复 1 个确定的中等风险竞态，并对大数据量下的主线程卡顿做一次真机验证。**

综合评估：**7.5/10，条件稳定**。

- `85c37de` 的修改目标清楚、链路覆盖较完整，现有语义回归通过，风险低。
- `44365d3` 统一了加载反馈，并补齐了部分失败提示，产品方向合理。
- 未发现明显崩溃路径、数据结构破坏、JSON 失效或 Xcode 工程引用缺失。
- 确认存在一个 OCR 导入取消竞态：用户关闭确认页后，延迟任务仍可能继续写入账本。
- 新增的快照整理仍在主线程执行。加载态会先出现，但计算期间动画和交互仍可能冻结，尚未真正解决大账本性能问题。
- 当前 Windows 环境没有 Xcode/Swift 工具链，因此“可编译、模拟器布局和真机动画”仍需在 macOS 上补验。

## 3. 提交一：面食账单归类为餐饮

### 3.1 修改目的

修复 OCR 或手动输入包含“牛肉面、兰州拉面、拉面、汤面、面馆、面食、面条、粉面”等文本时，账单不能稳定归入“餐饮”的问题，并让分类结果继续进入餐饮场景、情绪标签和生活标记链路。

### 3.2 实际覆盖范围

- 主词典：补充手动分类和 OCR 分类关键词。
- Swift 兜底词典：Bundle JSON 加载失败时仍能正确识别面食。
- 强手动备注覆盖：典型面食备注可以及时把分类切到餐饮。
- 情绪规则：命中 `meal`，避免只改分类但回放语义缺失。
- 场景语义：命中“日常一餐/快捷餐食”一类语义。
- 生活标记：进入“日常吃饭”。
- 回归数据：新增 OCR 和手动输入“寻味兰州纯汤牛肉面”两个样例。
- 回归脚本：增加新关键词存在性和分类/情绪结果检查。

### 3.3 评估结果

**稳定性：高；建议保留。评分：8.5/10。**

优点：

- 不只是补一个 JSON 词条，而是同步处理了主词典、兜底词典、情绪、场景和生活标记，避免下游语义断层。
- 新增样例同时覆盖 OCR 和手动输入，且 `life_semantic_regression.py` 实际通过。
- 使用“拉面、面馆、面食”等相对明确的词，没有引入单字“面”这种高误判词，边界总体克制。

剩余风险：

- 关键词仍分散在 JSON、Swift 兜底、场景服务和生活标记服务中，后续扩词容易漏改某一层。
- 新回归只覆盖目标商户文本，没有覆盖否定样例，例如“面膜”“面料”“桌面服务”等非餐饮文本。
- 回归脚本会跳过带 `history` 的分类样例，因此没有自动验证“面食语义与历史高频金额冲突”时的完整业务决策链。
- `粉面` 没进入 OCR 专用规则和强手动覆盖列表，但 OCR 仍会通过通用关键词规则命中餐饮；当前不是功能错误，只是规则层不完全对称。

### 3.4 后续优化建议

1. 增加 4 类边界样例：典型面食、OCR 噪声、与交通高频金额冲突、非餐饮同字文本。
2. 将“主 JSON 与 Swift 兜底的关键语义词必须同步”升级为集合级比较，而不只是若干字符串存在性检查。
3. 中期考虑从一份规范词表生成兜底与检查数据，减少多处人工同步。

## 4. 提交二：统一计算加载态

### 4.1 修改目的

让统计、复盘、OCR、购买、云同步、月度生成和分享图保存等操作在计算或等待期间有明确反馈，减少点击后短暂无响应的感受，并尽量在重计算前先让 SwiftUI 渲染一帧状态变化。

### 4.2 实际覆盖范围

- 新增统一的 `ComputationLoadingView`，支持页面、卡片、行内和可选进度值。
- 统计页和复盘页先生成数据快照，再一次性展示内容；数据变化时显示更新提示。
- OCR 识别、每日/每月复盘、AI 指令、云同步、会员购买恢复统一为新加载样式。
- OCR 批量确认、月度本地聚合和分享图生成前增加 `80ms` 延迟，让状态先渲染。
- 两处分享图生成补充“无有效内容/截图生成失败”的可见错误提示。
- Xcode 工程已加入新 Swift 文件引用和 Sources 构建项。

### 4.3 评估结果

**稳定性：中等；建议修复 OCR 竞态后再作为发布基线。评分：6.8/10。**

优点：

- 加载文案和视觉语言统一，覆盖范围完整。
- `ComputationLoadingView` 处理了 Reduce Motion，并为 OCR 保留确定进度条。
- 统计/复盘快照使用任务取消和 request ID 双重防旧结果覆盖，新请求不会被旧任务反写。
- 分享图失败不再静默，状态也能在失败路径复位。
- 会员购买、恢复购买和云同步复用了原有业务状态，没有另造容易失配的状态源。

## 5. 问题清单

### P2：OCR 确认页关闭后仍可能导入账单（确定问题）

位置：

- `NativeDemoApp/Views/OCRConfirmSheet.swift:91`
- `NativeDemoApp/Views/OCRConfirmSheet.swift:134`
- `NativeDemoApp/Views/RecordView.swift:1758`
- `NativeDemoApp/ViewModels/HomeViewModel.swift:358`

原因：

1. 用户点击“进入整理”或“直接导入”后，页面先设置 `isCollectingImport = true`。
2. 真正的 `onConfirm` 被放进一个延迟 `80ms` 的未保存任务中。
3. 两个导入按钮被禁用，但“取消”按钮仍可点击，Sheet 也没有禁止下滑关闭。
4. 关闭页面不会取消这个任务；80ms 后 `onConfirm` 仍会调用 `importOCRDrafts`，插入账本并消耗 OCR 导入额度。

影响：用户明确执行取消/关闭后，数据仍可能被写入。窗口很短，但属于行为与用户意图不一致的数据修改竞态。

建议修复：

- 导入进行中禁用“取消”，并加 `.interactiveDismissDisabled(isCollectingImport)`；或
- 将任务保存在 `@State`，在取消/onDisappear 时取消，并在调用 `onConfirm` 前检查取消状态；
- 若只是需要让出一次渲染机会，优先用结构化任务和 `Task.yield()`，避免固定时间窗口。

建议验收：点击导入后立即点取消或下滑，账本条数和 OCR 配额都不得变化；正常导入仍只能执行一次。

### P2：快照计算仍运行在 MainActor，加载动画可能在重计算时冻结（性能风险）

位置：

- `NativeDemoApp/Views/StatsWebView.swift:343`
- `NativeDemoApp/Views/StatsWebView.swift:352`
- `NativeDemoApp/Views/InsightWebView.swift:357`
- `NativeDemoApp/Views/InsightWebView.swift:361`
- `NativeDemoApp/ViewModels/HomeViewModel.swift:916`

原因：统计和复盘任务明确声明为 `@MainActor`。`80ms` 睡眠只保证加载态有机会先显示，之后的过滤、分组、生活标记、节奏点和文案整理仍在主线程同步执行。统计页还从“只构建当前卡面”变成首次同时构建周/月两个快照，首屏计算量会上升。

影响：小数据量下体感会改善；大账本下可能表现为“先看到加载卡，随后动画停止、页面仍卡住”。因此当前实现解决的是反馈时机，不是计算性能。

建议修复：

- 先用 Instruments/Signpost 测量 100、1,000、5,000 条记录下的构建耗时。
- 把纯数据聚合抽成不依赖 View/Color/Environment 的快照构建器，在后台处理 `Sendable` 输入；只在主线程提交最终状态。
- 暂时无法离开主线程的逻辑，可拆批并在批次间 `Task.yield()`，同时避免重复扫描全量 `items`。
- 统计页按当前可见卡面懒构建，或缓存后台预热另一卡面，避免首屏强制双算。

### P3：固定 `80ms` 带来可见的人工延迟和重复刷新（体验风险）

位置：

- `NativeDemoApp/Views/StatsWebView.swift:325`
- `NativeDemoApp/Views/InsightWebView.swift:345`
- `NativeDemoApp/ViewModels/HomeViewModel.swift:921`
- `NativeDemoApp/Views/SummaryPlaybackSheet.swift:2274`
- `NativeDemoApp/Views/InsightWebView.swift:4499`

说明：即使数据很少、缓存可立即命中，页面仍至少等待 80ms。统计和复盘每次 `onAppear` 都重新安排准备任务；复盘更新期间还会临时禁止滚动和点击。这可能产生轻微闪动、更新提示频繁出现和“本来秒开却被强制变慢”的感受。

建议：以真实状态和耗时阈值决定是否显示加载态。低于约 100-150ms 的操作通常无需全量加载卡；缓存命中时直接展示；超过阈值再渐显加载反馈。

### P3：自动化测试未覆盖新增加载状态机（测试缺口）

现有检查覆盖文案、关键词、JSON 和若干静态结构，但没有验证：

- 任务取消后状态是否复位；
- 快速切换统计模式/筛选时是否只提交最后一次快照；
- OCR 导入取消是否真正阻止写入；
- 分享图 payload 为空、截图失败、相册拒绝三个分支；
- Reduce Motion、VoiceOver 进度值和小屏布局。

另外，`ComputationLoadingView` 为组合元素手动覆盖了 accessibility value；传入 OCR `progress` 时，VoiceOver 可能只读详情而不读百分比。建议补上进度可访问值和 UI 测试。

### P3：新增后遗留两个未使用的统计辅助方法（维护性）

位置：

- `NativeDemoApp/Views/StatsWebView.swift:2605`
- `NativeDemoApp/Views/StatsWebView.swift:2609`

`buildTraceChapterSnapshot()` 无参数版本和 `traceEmptyChapterSnapshot(for:)` 在新快照流程中已无调用。不会造成运行错误，但会让后续维护者误判仍存在旧的惰性卡面策略，建议在下一次整理时删除。

## 6. 验证记录

已通过：

- `git diff --check`：两次提交均无空白错误。
- `RecordSceneLexicon.json` 和回归 JSON：PowerShell JSON 解析通过。
- `scripts/life_semantic_regression.py`：`OK`。
- `scripts/experience_static_check.ps1`：全部检查通过。
- `scripts/theme_catalog_check.py`：31 个主题 ID、明暗模式、分类色和 fallback 检查通过。
- `scripts/copy_lint.py`：通过；有 7 条 soft-term warning，无 error，且与本次核心修改无直接阻断关系。
- Xcode 工程静态检查：新文件同时存在 FileReference、Group 和 Sources 引用；新增 ID 数量与括号/花括号结构未见异常。
- 评估前工作区干净。

未执行：

- `xcodebuild`、Swift 编译、iOS 模拟器和真机测试。原因是当前环境为 Windows，未安装 Xcode/Swift 工具链。
- 真实相册权限、StoreKit 购买恢复、云同步网络和大账本性能测试。

## 7. 建议的后续迭代顺序

1. **发版前**：修复 OCR 延迟导入的取消竞态，并补 1 个状态机单测或 UI 测试。
2. **发版前**：在 macOS 执行 Debug/Release 编译，并走一遍 OCR、购买恢复、云同步、月度生成、两类分享图保存。
3. **性能迭代**：测量统计/复盘在 100、1,000、5,000 条数据下的主线程耗时，再决定后台快照或分批计算方案。
4. **体验迭代**：移除无条件固定 80ms；采用延迟显示加载态或耗时阈值，缓存命中直接展示。
5. **测试迭代**：补任务取消、快速筛选、旧任务不反写、失败状态复位、Reduce Motion/VoiceOver 用例。
6. **语义迭代**：补面食否定样例和历史冲突样例，并逐步收敛多份关键词源。

## 8. 推荐发布门槛

满足以下条件后，可将综合结论从“条件稳定”提升为“稳定可发布”：

- OCR 导入关闭竞态已修复并回归通过。
- Xcode Debug 与 Release 构建通过，无新增 concurrency warning/error。
- 1,000 条账本下统计与复盘切换无明显动画冻结，主线程单次阻塞处于可接受范围。
- 两种分享图均验证成功、无内容失败、相册拒绝三条路径，按钮状态均能复位。
- 会员购买/恢复覆盖成功、取消、失败，加载遮罩不会卡住或吞掉结果提示。
