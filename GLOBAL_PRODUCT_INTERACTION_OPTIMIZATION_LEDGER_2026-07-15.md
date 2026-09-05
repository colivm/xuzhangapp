# 叙账全局产品与交互优化执行台账

> 创建日期：2026-07-15
> 当前基线提交：`d425389`（`fix trace snapshot type checking`）
> 状态：第二轮全局收口进行中；本文档仍是唯一顺序与状态来源
> 适用范围：`NativeDemoApp` iOS 主产品；历史 `web-preview` 已于 2026-07-22 退役，正式官网与法律页面分别位于 `site/`、`legal/`

---

## 0. 使用规则

### 0.1 唯一台账

每次开始全局产品、交互、性能、存储、会员或信息架构优化前，必须先完整阅读本文档。

不得根据聊天记忆、旧评估文档或“顺手优化”跳过本文档中的顺序、边界和状态。

### 0.2 一次只做一个任务

- 同一时间最多一个任务标记为 `IN_PROGRESS`。
- 当前任务达到 `VERIFIED` 后，才进入下一个任务。
- 若只能完成代码、无法执行 Xcode/真机验证，状态写为 `CODE_DONE`，不得冒充 `VERIFIED`。
- 遇到环境或外部账号阻塞，写明阻塞原因和解除条件，不得通过改动其他模块绕过。
- 不允许在完成 A 时顺手重构 B；不允许为了修 B 改变已验证的 A；不允许在做 C 时重写 A/B 的规则。

### 0.3 状态定义

| 状态 | 含义 |
|---|---|
| `NOT_STARTED` | 尚未开始 |
| `IN_PROGRESS` | 当前唯一正在执行的任务 |
| `CODE_DONE` | 代码与当前环境检查完成，但缺 Xcode、真机、账号或外部环境签收 |
| `VERIFIED` | 代码、自动检查、要求的真机/外部验收全部通过 |
| `BLOCKED` | 存在明确阻塞，已记录原因与解除条件 |

### 0.4 每个任务的强制流程

1. 读取本文档和任务卡。
2. 执行 `git status --short`，记录并保护已有修改。
3. 将唯一目标任务改为 `IN_PROGRESS`，填写开始日期。
4. 只修改任务卡“允许修改”范围内的文件和行为。
5. 逐项检查“冻结边界”，确认没有顺带改变。
6. 运行任务要求的专项检查和全局回归。
7. 更新任务状态、证据、修改文件、残留风险和下一步。
8. 当前任务未达到规定状态前，不开始下一项。

### 0.5 完成定义

一个任务只有同时满足以下条件才能标记为 `VERIFIED`：

- 目标场景通过。
- 反向场景和取消/失败路径通过。
- 冻结边界未变化，或变化已获得用户明确批准。
- 自动回归通过。
- 涉及 SwiftUI 生命周期、StoreKit、相册、权限、同步或性能时，完成对应的 Xcode/真机检查。
- 本文档已更新实际结果，不只写计划。

---

## 1. 创建台账时的工作区现场

创建本文档时，工作区并非干净状态。后续任务必须重新执行 `git status --short`，不得覆盖以下现场修改：

| 文件 | 创建台账时状态 | 归属说明 |
|---|---|---|
| `NativeDemoApp/Views/Components/StatCardView.swift` | 已修改 | 既有修改，当前任务不处理 |
| `web-preview/app.js` | 已修改 | 创建台账时的历史现场；经确认仅换行差异，已按 WEB-RETIRE-01 明确退役 |
| `PROMPT_UI-痕迹月度月历热力与复盘微调-iOS.md` | 未跟踪 | 用户既有文件，保留 |
| `NativeDemoApp/Views/InsightWebView.swift` | 已修改 | 包含 AI 指令台白屏与通勤未来时段修复 |
| `scripts/life_semantic_regression.py` | 已修改 | 包含上述两项修复的静态边界检查 |

禁止使用 `git reset --hard`、`git checkout --` 或其他会覆盖现场修改的操作。

---

## 2. 全局冻结边界

除非当前任务卡明确允许，以下行为保持冻结：

1. 账单分类、语义识别、情绪标签和场景包判断规则。
2. 账单金额、日期、标题的保存含义。
3. OCR 识别、确认、导入和待整理区的数据规则。
4. 今日、周、月、OCR、深度线索的免费额度常量。
5. 会员 Product ID、价格、购买与恢复逻辑。
6. 本地 JSON 编码字段和云端 DTO 字段。
7. 生活回放、周章、月章的文案选择规则。
8. `site/` 正式官网行为和视觉；法律文本只在独立合规任务中修改。
9. 用户现有主题、宠物、天气和同步偏好。
10. 首页“状态驱动主动作”长期框架：根据未完成草稿、当日回放、周/月内容成熟度和已完成回看状态选择一个主动作，并始终保留合理的次入口；不得在局部修复、文案优化、宠物调整、性能治理或页面拆分中退回固定按钮集合，也不得未经独立产品任务调整状态优先级、成熟门槛或主次入口关系。

若任务必须突破冻结边界，先更新本文档并写清：为什么必须改、受影响场景、迁移方案、回滚方式和新增回归。

---

## 3. 当前已完成代码、待签收事项

### FIX-001：AI 指令台确认保存后空白

- 状态：`CODE_DONE`
- 代码位置：`NativeDemoApp/Views/InsightWebView.swift`
- 处理：结果内容清空后，滚动位置回到指令台顶部。
- 已验证：
  - `git diff --check`
  - `python scripts/life_semantic_regression.py`
  - `scripts/experience_static_check.ps1`
  - `scripts/check_copy_experience.ps1`
  - `python scripts/copy_lint.py`
- 待验证：iPhone 真机上批量保存、最后一条单笔保存、清空输入三条路径均不出现空白。
- 冻结边界：不改变 AI 指令理解、会员判断、草稿导入和保存数据规则。

### FIX-002：今天尚未到晚高峰却生成晚间通勤

- 状态：`CODE_DONE`
- 代码位置：`NativeDemoApp/Views/InsightWebView.swift`
- 处理：只生成时间不晚于当前时刻的通勤草稿；历史日期仍按早晚生成。
- 已验证：同 FIX-001 的静态与文案回归。
- 待验证：
  - 工作日 08:30 前：今天不生成未来通勤。
  - 工作日 08:30～18:29：今天只生成早高峰。
  - 工作日 18:30 后：今天可生成早晚两条。
  - 昨天、上周等历史范围：早晚两条规则不受影响。
  - 周末和节假日：继续遵守原工作日规则。
- 冻结边界：不改变历史补记、重复检测、金额推断和会员判断。

---

## 4. 总执行顺序

| 顺序 | ID | 任务 | 当前状态 | 进入条件 |
|---:|---|---|---|---|
| 0 | GATE-00 | 当前两项修复真机签收 | `BLOCKED` | FIX-001、FIX-002 已 `CODE_DONE`；等待 macOS/Xcode 与 iPhone 真机 |
| 1 | INT-01 | 保存后交互统一编排 | `CODE_DONE` | Windows 实现与回归完成；等待 macOS/Xcode 与 iPhone 真机签收 |
| 2 | NAV-01 | Sheet 与跨页面路由状态统一 | `CODE_DONE` | Windows 实现与回归完成；等待 macOS/Xcode 与 iPhone 真机签收 |
| 3 | NAV-02 | Tab 状态与滚动上下文保留 | `CODE_DONE` | Windows 实现与回归完成；等待 macOS/Xcode 与 iPhone 真机签收 |
| 4 | TEST-01 | XCTest/UI 状态回归基线 | `CODE_DONE` | XCTest Target、共享 Scheme 与状态用例完成；等待 macOS/Xcode 运行 |
| 5 | DATA-01 | 长期存储迁移设计与迁移样本 | `CODE_DONE` | 设计、模型、样本与只读校验完成；等待 Xcode/真机评审签收 |
| 6 | DATA-02 | 照片文件化，移出账单 JSON | `CODE_DONE` | 图片引用化、旧数据迁移、缺图恢复与测试接线完成；等待 Xcode/真机签收 |
| 7 | DATA-03 | 账单元数据增量持久化 | `CODE_DONE` | SQLite 增量 CRUD、迁移激活、回滚保护与测试接线完成；等待 Xcode/真机签收 |
| 8 | DATA-04 | 云端照片边界与备份承诺对齐 | `CODE_DONE` | 方案 B、全入口边界文案、本地备份包与测试接线完成；等待 Xcode/真机签收 |
| 9 | PERF-01 | 痕迹页按需构建当前周/月快照 | `CODE_DONE` | 当前可见快照优先、旧内容承接与空闲预热完成；等待 Xcode/真机签收 |
| 10 | PERF-02 | 复盘与 AI 指令重计算移出主线程 | `CODE_DONE` | 周/月复盘与 AI 指令后台计算、最新请求保护及 1,000 条测试接线完成；等待 Xcode/真机签收 |
| 11 | PROD-01 | 痕迹与复盘职责收敛 | `CODE_DONE` | 周/月完整章节归痕迹、查账/对比/补记/继续问归复盘；等待 Xcode/真机签收 |
| 12 | PROD-02 | 全局术语统一 | `CODE_DONE` | 术语表、iOS 当前文案、上架说明与术语 lint 完成；等待 Xcode/真机签收 |
| 13 | MEMBER-01 | 免费额度与会员价值简化 | `CODE_DONE` | “省力记 + 长期回望”展示、规则表、迁移边界和常量守卫完成；共享额度池未获批且未实施 |
| 14 | AI-01 | AI 助手能力承诺与真实能力对齐 | `CODE_DONE` | 本机规则/远程模型/回退状态、事实边界和能力 lint 完成；等待 Xcode/真机签收 |
| 15 | A11Y-01 | 小字号、对比度、Dynamic Type 与 VoiceOver | `CODE_DONE` | 核心页面语义字体、自适应操作、44pt 触控、VoiceOver 与 Reduce Motion 门禁完成；等待 Xcode/真机签收 |
| 16 | OBS-01 | 产品漏斗与性能可观测性 | `CODE_DONE` | 本机类型化匿名事件、敏感字段白名单、关键漏斗与耗时桶完成；等待 Xcode/真机签收 |
| 17 | RELEASE-01 | 100/1,000/5,000 条与完整发版门禁 | `CODE_DONE` | 确定性夹具、Windows 自动门禁、Debug 隔离装载与统一真机矩阵完成；等待 macOS/Xcode、StoreKit 和 iPhone 集中签收 |
| 18 | DISCOVER-MEMORY-WALL-01 | 线索详情生活片段墙 | `CODE_DONE` | 确定性照片拼贴与日期时间线完成；等待 `FLOW-103` 的 macOS/Xcode、无障碍、照片生命周期与 TestFlight/Instruments 签收 |
| 19 | TRACE-CUSTOM-RANGE-FIX-01 | 细查自定义日期一次应用与范围回显 | `CODE_DONE` | 草稿/已提交范围分离、真实日期回显、后台单次快照与无动画原子发布完成；等待 `FLOW-104` 的 macOS/Xcode、XCTest、TestFlight 与 Instruments 签收 |
| 20 | LIFE-JOURNEY-RETURN-FIX-01 | 跨城返程证据与闭环终点识别 | `CODE_DONE` | 同日短窗口内的明确返程道路/长途证据已成为真实完成锚点；Windows 门禁完成，等待 macOS/Xcode、XCTest、真机与 Instruments 签收 |
| 21 | PERF-FIRST-SCREEN-01 | 两阶段首屏与渐进整理 | `CODE_DONE` | 两阶段首屏、陈旧发布保护、生命周期、顺序预热、双阶段 signpost 与规模等价测试源码完成；等待 `FLOW-106` 的 macOS/Xcode、XCTest、TestFlight 真机与 Instruments 签收 |

当前签收策略：后续仍需补全部 `CODE_DONE` 任务的 Xcode/真机证据；用户于 2026-07-15 再次明确要求“不要再问，全部改完后一起真机验证”，授权按台账顺序连续完成后续代码任务。该持续授权允许前一项达到 `CODE_DONE` 后直接进入下一项，但不得把任何未真机验证任务标为 `VERIFIED`，且仍须保持同一时间最多一个 `IN_PROGRESS`。

---

## 5. 顺序任务卡

### GATE-00：当前两项修复真机签收

目标：先确认已经修改的 A/B 真正稳定，再开始 C。

允许修改：

- 若真机发现问题，只允许修复 FIX-001、FIX-002 直接相关逻辑和对应回归。

冻结边界：

- 不调整 AI 指令能力、会员、额度、通勤金额、工作日判断和其他 UI。

验收：

- 完成 FIX-001、FIX-002 中列出的全部真机场景。
- Xcode Debug 和 Release 编译通过。
- 无新增 concurrency warning/error。

执行结果（2026-07-15）：

- Windows 可执行回归全部通过：
  - `git diff --check`
  - `python scripts/life_semantic_regression.py`
  - `scripts/experience_static_check.ps1`
  - `scripts/check_copy_experience.ps1`
  - `python scripts/copy_lint.py`
- 当前环境：Windows 10；`xcodebuild` 不可用；Swift 工具链不可用。
- 当前状态：`BLOCKED`。
- 阻塞原因：无法完成 Debug/Release 编译、并发警告检查和 iPhone 真机交互签收。
- 解除条件：在 macOS/Xcode 环境完成以下检查，并把结果补回本文档：
  1. Debug 与 Release 编译通过，无新增 concurrency warning/error。
  2. AI 指令台批量保存后不空白。
  3. 保存最后一条单笔草稿后不空白。
  4. 清空指令结果后回到顶部，不停留在空白滚动区域。
  5. 工作日 08:30 前、08:30～18:29、18:30 后分别验证通勤草稿数量。
  6. 昨天/上周、周末/节假日边界不受影响。

### INT-01：保存后交互统一编排

目标：保存一笔后只出现一个明确承接，不自动替用户播放、不自动消耗回放额度，不让照片、奖励、宠物和回放同时抢占界面。

允许修改：

- 手动保存成功后的页面承接。
- 首笔今日回放引导的展示时机。
- 照片提示、场景奖励提示和宠物消息的排队顺序。
- 必要的单一 post-save 状态模型。

冻结边界：

- 不改变账单实际保存内容。
- 不改变 `PhotoMemoryPromptPolicy`、场景奖励的触发资格。
- 不改变回放内容和免费额度常量。
- 不改变 OCR 和 AI 批量导入行为，除非只接入同一成功队列且数据规则不变。

验收：

- 第一笔保存后不会未经确认自动播放或扣额度。
- 用户可选择“继续记”或“听今日回放”。
- 同一时间只有一个提示层。
- 连续快速保存两笔不会重复弹层或漏提示。
- 杀进程重开不会重复消费额度。

专项回归：手动保存、首笔、普通后续笔、照片候选、场景奖励候选、会员/非会员。

执行结果（2026-07-15）：

- 第一笔保存不再自动播放，也不再自动调用回放额度扣减。
- 第一笔明确提供“继续记”和“听今日回放”：
  - “继续记”返回记录页。
  - “听今日回放”只有在用户点击后才开始回放并扣减一次额度。
  - 免费额度已用完时改为会员入口，不绕过额度判断。
- 第一笔若是补记历史日期，不弹出无内容的今日回放。
- 照片提示和场景奖励改为 FIFO 队列；连续保存不会用后一条覆盖前一条。
- 用户选择继续记录时，待处理照片/奖励不会覆盖记录页；再次回到首页后继续按队列展示。
- 照片跳过、添加、取消选择、压缩失败、预览关闭和重新选择均会释放队列。
- 今日回放播放期间保持后续提示等待；回放 Sheet 关闭后才继续。
- 宠物气泡在第一笔提示、照片提示、奖励提示或会员 Sheet 出现时让位。
- 冻结边界复核：未改变账单保存字段、照片/奖励资格、额度常量、OCR、AI 补记、分类语义和会员购买逻辑。
- 修改文件：
  - `NativeDemoApp/ContentView.swift`
  - `NativeDemoApp/Views/HomeView.swift`
  - `scripts/experience_static_check.ps1`
- Windows 验证：
  - `git diff --check` 通过。
  - `python scripts/life_semantic_regression.py` 通过。
  - `scripts/experience_static_check.ps1` 通过，新增“明确选择、禁止自动额度、单队列”约束。
  - `scripts/check_copy_experience.ps1` 通过。
  - `python scripts/copy_lint.py` 通过；仅保留既有 7 条 soft-term warning。
- 当前状态：`CODE_DONE`。
- 待真机验收：
  1. 全新账本第一笔选择“继续记”，额度不变，记录页可继续输入。
  2. 全新账本第一笔选择“听今日回放”，只扣一次；关闭回放后才展示后续照片/奖励。
  3. 第一笔为昨天或其他历史日期，不出现今日回放提示。
  4. 免费回放额度为 0 时不允许直接播放，会员入口关闭后继续后续队列。
  5. 连续保存两笔，照片和奖励不重叠、不重复、不丢失。
  6. 照片选择取消、加载失败、预览下滑关闭和重新选择后，队列不会卡住。
  7. 宠物气泡不会覆盖第一笔、照片、奖励或会员提示。

### NAV-01：Sheet 与跨页面路由状态统一

目标：移除依靠固定 `asyncAfter` 猜测 Sheet 关闭完成的跨页面跳转。

允许修改：

- 根级路由枚举、Sheet destination 和关闭后目标队列。
- AI 指令台、痕迹详情、回放、会员页、记录详情之间的跳转编排。

冻结边界：

- 不改变各 CTA 最终目的地。
- 不改变会员入口上下文和购买方案高亮。
- 不改变 Sheet 内容、数据处理和取消语义。

验收：

- 快速点击、下滑关闭、重复点击不会出现空白、重复 Sheet 或目标丢失。
- 所有原入口仍进入正确页面和正确会员上下文。
- 不再使用固定延迟作为 Sheet-to-Sheet 的必要条件。

执行中（2026-07-15）：

- 用户风险例外：在 `GATE-00` 仍为 `BLOCKED`、`INT-01` 仍为 `CODE_DONE` 的情况下，用户再次明确要求继续下一项；本次例外仅授权执行 `NAV-01` 代码与 Windows 回归，不视为前序 Xcode/真机验收通过。
- 工作区保护：开始前已重新执行 `git status --short`；保留现有 `StatCardView.swift`、`web-preview/app.js`、用户提示文档以及 FIX/INT 已有修改，不覆盖、不回退。
- 完成实现：
  - AI 指令台、月度复盘 Sheet 的会员入口先登记目标，当前 Sheet `onDismiss` 后再打开会员页。
  - 场景包角度 Sheet 的锁定入口由 `RecordView` 持有待跳转状态，关闭后继续进入原 `.scenePack(nil)` 上下文。
  - 今日回放与周/月回放的会员、进入复盘、切回本周动作改为父级 Sheet `onDismiss` 路由；原 `.playbackQuota` 上下文保持不变。
  - 首页“今天全部记录”、记录编辑、记忆详情，以及痕迹细查、记录编辑、记忆详情之间的跳转统一为待处理目标；补图与图片重选也不再依赖固定等待时间。
  - 设置页账号 Sheet、外观等设置 Sheet 关闭后再打开会员页；普通设置与永久会员高亮上下文保持原值。
  - 快速重复点击只覆盖同一待处理目标；普通下滑关闭因无待处理目标，不会误开下一层。
- 冻结边界复核：未改变 CTA 最终目的地、会员入口上下文/方案高亮、Sheet 内容、数据处理、取消语义、记录/OCR/AI/语义/额度规则及 `web-preview`。
- 修改文件：
  - `NativeDemoApp/ContentView.swift`
  - `NativeDemoApp/Views/HomeView.swift`
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `NativeDemoApp/Views/RecordView.swift`
  - `NativeDemoApp/Views/ScenePackAngleSheet.swift`
  - `NativeDemoApp/Views/SettingsView.swift`
  - `NativeDemoApp/Views/StatsWebView.swift`
  - `NativeDemoApp/Views/SummaryPlaybackSheet.swift`
  - `scripts/experience_static_check.ps1`
- Windows 验证：
  - `git diff --check` 通过。
  - `python scripts/life_semantic_regression.py` 通过。
  - `scripts/experience_static_check.ps1` 通过；新增 Sheet 路由必须等待 `onDismiss`、禁止关闭后固定延时跳转的守卫。
  - `scripts/check_copy_experience.ps1` 通过。
  - `python scripts/copy_lint.py` 通过；仅保留既有 7 条 soft-term warning。
- 当前环境复核：`xcodebuild` 与 Swift 工具链均不可用，不能执行编译或真机交互签收。
- 待 Xcode/真机验收：
  1. AI 指令台和月度复盘会员 CTA 快速连点，只出现一次正确 `.aiCommand` 会员页。
  2. 场景包锁定入口快速连点、下滑关闭，分别不重复跳转、不误开会员页，会员上下文仍为 `.scenePack(nil)`。
  3. 今日回放结束后打开会员页，关闭后继续 INT-01 的照片/奖励队列，不叠层。
  4. 周/月回放的“了解会员”“想多聊一句”“先看本周”分别到原目标；下滑关闭不触发任何目标。
  5. 首页“今天全部记录”进入带图记录、普通编辑补图后进入记忆详情，均无空白、重复或目标丢失。
  6. 痕迹细查进入带图记录、普通编辑补图后进入记忆详情，均无空白、重复或目标丢失。
  7. 记忆详情“继续补图”和图片预览“重新选择”能稳定打开系统相册；取消、失败和下滑关闭语义不变。
  8. 设置账号 Sheet 的免费/续费/已解锁入口进入普通设置会员上下文；外观永久主题入口继续高亮 lifetime。
  9. 所有入口在快速重复点击和交互式下滑关闭时，不出现 `Attempt to present...`、空白 Sheet 或重复 Sheet。
- 当前状态：`CODE_DONE`。

### NAV-02：Tab 状态与滚动上下文保留

目标：用户从痕迹或复盘临时去记账，再回来时保留筛选、模式和合理的滚动上下文。

允许修改：Tab 容器和页面状态归属。

冻结边界：不改变五个 Tab 的顺序、名称和业务内容；名称调整留到 PROD-02。

验收：

- 痕迹的生活/线索模式、周/月选择、自定义筛选不因切 Tab 丢失。
- 记录页草稿保留规则明确；主动保存/清空后才重置。
- 不引入多个页面同时执行高成本 `onAppear` 任务。

执行中（2026-07-15）：

- 用户持续授权：从本任务起，后续任务按台账顺序完成代码与当前环境回归，最后统一进行 Xcode/真机签收；不再逐项请求继续授权。
- 工作区保护：开始前已重新执行 `git status --short`，继续保留既有 FIX/INT/NAV 修改、`StatCardView.swift`、`web-preview/app.js` 和用户提示文档。
- 完成实现：
  - `ContentView` 持有记录、痕迹和复盘的 Tab 会话状态，但仍使用 `switch selectedTab` 只构建当前页面。
  - 痕迹页保留生活/线索模式、周/月/年选择、分类、自定义日期、生活卡范围、深度线索展开与问题焦点。
  - 痕迹页保留滚动锚点和已准备的周/月/线索快照；返回时先显示旧内容，再按现有刷新规则更新。
  - 复盘页保留滚动锚点、展开状态、月度生成结果/版本和已准备页面快照；账本变化时通过来源修订重新刷新。
  - 记录页把输入模式、面板展开、场景包选择、用户语义意图和自定义金额键盘状态收进 `RecordTabSession`。
  - 金额、备注、分类、日期等实际草稿继续由 `HomeViewModel` 持有；存在未提交草稿时不再因切 Tab 或定时刷新改变草稿日期。
  - 手动保存成功后才调用 `resetAfterCommittedDraft()` 重置记录会话，保持“切页不清空、提交后重置”。
- 冻结边界复核：未改变五个 Tab 的顺序、名称、业务内容、保存字段、筛选含义、语义规则、额度规则和 `web-preview`。
- 修改文件：
  - `NativeDemoApp/ContentView.swift`
  - `NativeDemoApp/Views/RecordView.swift`
  - `NativeDemoApp/Views/StatsTraceModels.swift`
  - `NativeDemoApp/Views/StatsWebView.swift`
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `scripts/experience_static_check.ps1`
- Windows 五项回归全部通过；新增 Tab 状态归属、滚动锚点、记录草稿提交重置和仅构建当前 Tab 的静态守卫。
- 待 Xcode/真机验收：
  1. 痕迹切到线索、选择月/分类/自定义日期并滚动后，去记账再返回，模式、筛选和位置保留。
  2. 痕迹生活卡停在月章后切 Tab 返回，仍停在月章且旧内容先显示。
  3. 复盘滚动到关键词/下一章、展开更多复盘并生成月度内容后切 Tab 返回，状态和位置保留。
  4. 记录页输入金额、备注、分类、日期和场景包后切 Tab 返回，保存结果与离开前一致。
  5. 未手动编辑日期但已有金额/备注草稿时，离开超过一分钟再返回，草稿日期不漂移。
  6. 保存成功后再次进入记录页，旧草稿和面板状态已重置，新记录可正常开始。
  7. Instruments/日志确认切 Tab 时没有五个页面同时触发高成本 `onAppear`。
- 当前状态：`CODE_DONE`。

### TEST-01：XCTest/UI 状态回归基线

目标：在高风险存储改造前建立可重复验证的测试底座。

允许修改：Xcode Test Target、测试夹具、测试专用注入点。

冻结边界：不得为了方便测试改写产品业务结论。

最低覆盖：

- 保存后状态机。
- Sheet 路由取消与重复提交。
- AI 通勤时间边界。
- OCR 单次导入与取消。
- 回放额度只在明确开始后扣除。
- 旧任务不得反写新筛选状态。

执行中（2026-07-15）：

- 按用户持续授权，在 `NAV-02` 待真机签收状态下继续建立测试代码；不把未运行的 XCTest 标为通过。
- 完成实现：
  - 新增 `NativeDemoAppTests` Unit Test Target，并加入共享 `NativeDemoApp` Scheme 的 Test Action。
  - 新增可复用纯状态模型：`UniqueFIFOQueue`、`DeferredRouteQueue`、`LatestRequestGate`，生产代码同步接入。
  - 保存后照片/奖励队列使用唯一 FIFO，测试覆盖顺序和去重。
  - AI/月度 Sheet 待路由使用可消费队列，测试覆盖重复请求、取消和只消费一次。
  - 痕迹/复盘异步准备使用最新请求门，测试覆盖旧任务不得反写。
  - OCR 导入提取 `OCRImportSubmissionGate`，测试覆盖提交中拒绝第二次操作、重置后可再次提交。
  - 通勤时间边界提取 `AICommuteDraftSchedule`，测试覆盖 08:29、08:30、18:29、18:30 与历史日期。
  - 回放额度测试确认查询/可播放判断不扣次数，只有 `markTodayPlaybackStarted` 扣一次。
  - 记录 Tab 会话与痕迹/复盘状态保留加入状态回归。
- 冻结边界复核：测试注入未改变保存内容、OCR 导入结果、AI 通勤结论、额度常量、Sheet 目的地和筛选业务规则。
- 修改/新增文件：
  - `NativeDemoApp.xcodeproj/project.pbxproj`
  - `NativeDemoApp.xcodeproj/xcshareddata/xcschemes/NativeDemoApp.xcscheme`
  - `NativeDemoApp/Models/InteractionStateModels.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `NativeDemoApp/ContentView.swift`
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `NativeDemoApp/Views/OCRConfirmSheet.swift`
  - `NativeDemoApp/Views/StatsWebView.swift`
  - `scripts/experience_static_check.ps1`
  - `scripts/life_semantic_regression.py`
- Windows 五项回归全部通过；工程文件、测试源文件、共享 Scheme 和最低覆盖名称均有静态守卫。
- 待 macOS/Xcode：运行 Debug/Release 编译及 `xcodebuild test`，修正任何目标接线、actor isolation 或模拟器差异后才能标为 `VERIFIED`。
- 当前状态：`CODE_DONE`。

### DATA-01：长期存储迁移设计与迁移样本

目标：在写迁移代码前确定新旧格式、失败回滚和数据完整性校验。

允许修改：设计文档、迁移模型、只读分析脚本和测试样本。

冻结边界：本任务不切换生产存储，不删除旧 JSON，不改云端协议。

必须产出：

- 旧 JSON 字段清单。
- 图片文件目录与命名规则。
- 元数据数据库模型。
- 幂等迁移步骤。
- 中断恢复和回滚方案。
- 含旧单图、多图、无图、OCR 草稿、记忆上下文的迁移样本。

执行中（2026-07-15）：

- 严格遵守本任务边界：只新增设计文档、迁移模型、只读分析/校验工具和测试样本，不切换 `LocalStore` 生产读写，不删除旧 JSON，不改云端 DTO。
- 完成产出：
  - `DATA_MIGRATION_DESIGN_v1.md`：完整旧字段、目标目录、SQLite 表、图片命名、幂等步骤、中断恢复、回滚和后续边界。
  - `LedgerMigrationModels.swift`：manifest、v2 元数据、图片资产、checkpoint 与审计模型。
  - 旧账本与预期 v2 样本，覆盖旧单图、多图、无图、OCR 草稿、记忆上下文。
  - `analyze_legacy_ledger.py`：只读输出字段、金额分、分类和图片摘要。
  - `validate_migration_samples.py`：校验数量、金额、分类、顺序、封面、byte count 和 SHA-256。
- 冻结边界复核：未修改 `LocalStore` 生产读写路径，未删除旧 JSON，未改云端 DTO，也未提前实现 DATA-02/03 切换。
- Windows 五项基础回归与迁移样本专项校验全部通过。
- 当前状态：`CODE_DONE`。

### DATA-02：照片文件化

目标：图片二进制移出 `HomeItem` 主 JSON，记录只保存稳定引用。

冻结边界：不压缩或丢弃用户已有图片；封面索引、图片顺序和展示结果保持一致。

验收：

- 旧数据完整迁移。
- 中途失败可再次执行。
- 删除账单会清理孤立图片；删除单图不影响其他图片。
- 图片读取失败有占位和恢复路径，不导致整账本解码失败。

执行中（2026-07-15）：

- 本项只把图片二进制移出 `HomeItem` JSON，并实现迁移/清理/读取失败边界；元数据仍可整文件原子写入，增量数据库切换留给 DATA-03。
- 完成实现：
  - `HomeItem` 自定义 Codable 同时兼容旧单图、旧多图和新引用格式；引用完整时 JSON 只编码 `memoryImageReferences`，引用不完整时保守回退图片字节，避免静默丢图。
  - 图片保存到 `Documents/LedgerStore/images/<record-id>/<sha256>.jpg`；相同内容重试幂等，删除或重排前面的图片不会改变其余引用。
  - `LocalStore` 首次迁移前保留一次性 `home_items_v1.pre_image_migration.json`；图片写入与元数据原子持久化成功后才清理孤立文件，任一步失败继续返回旧数据并允许下次重试。
  - 冷启动优先读取有效主 JSON，主文件无效时回退 UserDefaults 备份；引用图片加载失败只生成该位置占位，不让整个账本解码失败。
  - 新增/删图由 `HomeItem` 统一维护图片数据、引用、缺图索引和封面索引的对齐关系。
  - 缺图 UI 显示“图片暂时不可用”，原有删除和重新添加入口继续作为恢复路径。
  - 新增 `LedgerImageStoreTests` 并接入 `NativeDemoAppTests` Target，覆盖引用化与顺序、删单图只清理对应孤儿、缺文件不破坏账本三类回归。
- 冻结边界复核：未压缩或主动丢弃已有图片；未改变封面索引、图片顺序、记录字段含义、云端 DTO；元数据仍整文件写入，未提前实施 DATA-03。
- 修改/新增文件：
  - `NativeDemoApp/Models/HomeItem.swift`
  - `NativeDemoApp/Services/LedgerImageStore.swift`
  - `NativeDemoApp/Services/LocalStore.swift`
  - `NativeDemoApp/ViewModels/HomeViewModel.swift`
  - `NativeDemoApp/Views/Components/MemoryAttachmentViews.swift`
  - `NativeDemoAppTests/LedgerImageStoreTests.swift`
  - `NativeDemoApp.xcodeproj/project.pbxproj`
  - `DATA_MIGRATION_DESIGN_v1.md`
  - `qa/migration_samples/expected_ledger_v2.json`
  - `scripts/analyze_legacy_ledger.py`
  - `scripts/experience_static_check.ps1`
- Windows 验证：五项基础回归、迁移样本校验、共享 Scheme XML 解析和 XCTest 工程接线静态检查全部通过；文案检查仍仅有既有 7 条 soft warning。
- 待 Xcode/真机验收：
  1. 从旧单图/多图账本首次启动后，记录数、金额、顺序、封面和图片均一致，JSON 不再包含图片 Base64。
  2. 在图片写入、JSON 写入或清理阶段模拟失败，原账本仍可打开，重启可幂等重试。
  3. 新增多图、删除中间一图、换封面、删除整条记录后，其余图片引用和展示不变，孤立文件正确清理。
  4. 手动移走一张图片文件后，账本可正常进入并只在对应位置显示占位；删除或重新添加可恢复。
  5. Debug/Release 编译和 `xcodebuild test` 通过，无新增 actor/concurrency 警告。
- 当前状态：`CODE_DONE`。

### DATA-03：账单元数据增量持久化

目标：新增、编辑、删除单笔账单不再同步重写整个账本和全部照片。

冻结边界：排序、字段含义、同步冲突规则和用户可见结果保持一致。

验收：

- 新增/编辑/删除为增量写入。
- 迁移前后记录数、金额总和、分类、日期和图片引用一致。
- 冷启动失败不会静默返回空账本覆盖原数据。

执行中（2026-07-15）：

- 按用户持续授权从 DATA-02 `CODE_DONE` 直接进入；该授权不代表 DATA-02 已完成 Xcode/真机验收。
- 本项只切换本地账单元数据的增量持久化与迁移激活；排序、字段含义、云端 DTO、同步冲突规则和照片文件格式保持冻结。
- 完成实现：
  - 新增 `LedgerMetadataStore`，以 SQLite `records`/`image_assets` 表保存账单元数据与图片引用，启用外键、索引、事务、WAL、`user_version` 和 `quick_check`。
  - 首次切换使用 staging 数据库；逐条 UPSERT 后以记录摘要、ID、金额分、图片数量/顺序/引用做审计，原子替换数据库，最后写 `manifest.activeStore = metadataV2`。
  - 正常保存只读取 SQLite 的 ID/更新时间；新增、编辑、删除仅写变化行，不再编码或覆盖整份账本 JSON。
  - 已文件化且引用完整的图片在元数据保存时不再重新读取、哈希或写入；只有新图/变更图进入文件持久化路径。
  - SQLite 同时保存原始 `amount_value REAL` 和审计用 `amount_minor_units`，避免少数非两位小数历史金额被迁移截断。
  - 相同内容图片允许在同一记录中占据不同 ordinal，保留重复图片及其原顺序；删除记录由外键级联删除引用，物理孤儿在元数据提交后清理。
  - 活跃数据库打开、schema 或完整性检查失败时，回退保留的旧 JSON 并将 manifest 切回 legacy；若主 JSON 和 UserDefaults 备份都不可读，则返回明确错误并阻止所有新增/编辑/删除，避免空数组覆盖原文件。
  - 增量写入失败时才使用完整 JSON 作为应急回滚快照并切回 legacy；正常路径不双写整份 JSON。
  - `HomeViewModel` 在不可写状态下阻止手动、OCR、AI、编辑、删图、删记录、清空和云端合并；保存中途失败会重载最后可读账本，不继续上报“已保存”。
  - 新增 `LedgerMetadataStoreTests`，覆盖全字段/重复图片迁移、无变化/新增/更新/删除计数、损坏 SQLite 回退、两个旧源不可读时禁止覆盖。
  - 新增可在 Windows 执行的 SQLite schema/UPSERT 校验脚本，实际执行表结构、UPSERT、重复路径和级联删除。
- 冻结边界复核：未改变首页日期排序规则、账单字段含义、OCR/AI 导入结论、云端 DTO、云端合并冲突规则、照片文件路径和用户可见业务结果；仅在 `updateItem` 最终提交时统一刷新 `updatedAt`，确保增量版本判断与实际编辑一致。
- 修改/新增文件：
  - `NativeDemoApp/Services/LedgerMetadataStore.swift`
  - `NativeDemoApp/Services/LedgerHomeItemsRepository.swift`
  - `NativeDemoApp/Services/LocalStore.swift`
  - `NativeDemoApp/Services/LedgerImageStore.swift`
  - `NativeDemoApp/ViewModels/HomeViewModel.swift`
  - `NativeDemoApp/Models/LedgerMigrationModels.swift`
  - `NativeDemoAppTests/LedgerMetadataStoreTests.swift`
  - `NativeDemoApp.xcodeproj/project.pbxproj`
  - `DATA_MIGRATION_DESIGN_v1.md`
  - 迁移样本/分析/校验脚本与体验静态检查。
- Windows 验证：五项基础回归、迁移样本、SQLite schema 实际执行、Scheme XML 与 Xcode 工程接线静态检查全部通过；文案仍仅有既有 7 条 soft warning。
- 待 Xcode/真机验收：
  1. 旧 JSON 首次切 SQLite 后记录数、ID、原始金额、金额分、分类、日期、草稿、记忆上下文、图片顺序和封面一致。
  2. 分别新增、编辑、删除一笔，确认只变化对应 SQLite 行，旧 JSON 和已有照片文件修改时间不变。
  3. OCR/AI 批量导入、云端合并、清空本机数据仍保持原业务结论，重新启动后结果一致。
  4. 模拟 staging、manifest、SQLite 写入和孤儿清理失败，确认回滚源不被覆盖且可重试。
  5. 损坏活跃 SQLite 时显示恢复说明并回退旧账本；同时损坏两个旧源时禁止新增、编辑、删除和同步覆盖。
  6. 1,000 条含图账本新增/编辑一笔时，主线程交互无明显卡顿；5,000 条压力门禁留 RELEASE-01 统一签收。
  7. Debug/Release 编译与全部 XCTest 通过，无 SQLite 链接、actor 或 concurrency 新警告。
- 当前状态：`CODE_DONE`。

### DATA-04：云端照片边界与备份承诺对齐

目标：明确并落实“换机备份”是否包含记忆照片。

先决策后实现：

- 方案 A：支持照片备份，补上传、下载、配额、隐私和失败恢复。
- 方案 B：暂不支持，所有入口明确写“账单字段备份，照片仅保存在本机”，并提供本地导出。

冻结边界：不得继续使用含糊文案让用户误以为照片已备份。

执行中（2026-07-15）：

- 按用户持续授权从 DATA-03 `CODE_DONE` 直接进入；前序存储代码仍等待 Xcode/真机签收。
- 当前唯一目标：基于现有云端 DTO、服务端能力、隐私与恢复边界，先形成明确方案，再只实现该方案所需的文案、导出和测试；不顺带改变同步冲突规则。
- 产品决策：采用方案 B。现有 iOS `LedgerDTO` 与后端 `/v1/ledger` 仅支持 JSON 账单字段，没有对象存储、图片上传/下载、配额、隐私删除和失败恢复能力；本版本不伪装为照片云备份。
- 完成实现：
  - 新增 `CLOUD_PHOTO_BACKUP_BOUNDARY_v1.md`，固定“云端只同步账单字段；记忆照片仅本机；换机前手动导出”的承诺、升级条件和回滚边界。
  - 设置首页、备份 Sheet、登录合并、删除云端、清空本机、注销账号、会员页、状态反馈等 iOS 入口均明确：金额、分类、备注、日期等字段可同步；照片不上传、不能从云端恢复。
  - “清空本机后同步云端”危险动作明确写出会删除本机照片，避免用户误以为照片可从云端找回。
  - 隐私政策、用户协议、App Store IAP 配置和当前会员/商店文案同步方案 B；移除“换机不丢”等无边界承诺。
  - 新增 `.xuzhangbackup` 本地包导出：`ledger.json` 保存字段/照片顺序/封面引用，`images/` 保存当前可读取照片，`manifest.json` 记录照片引用数、实际文件数、缺图数及 `cloudPhotoBackupSupported: false`，并附 README。
  - 相同内容照片文件只导出一份，但账单引用顺序可重复；已有稳定引用但文件缺失时继续导出账单并明确报告缺图数量；数据和引用都缺失时不声称导出成功。
  - 导出从“备份与联网”当前 Sheet 发起，先显示整理状态并在准备期间禁止下滑关闭，避免从父级重复呈现文件选择器。
  - 新增 `LedgerLocalBackupDocumentTests`，覆盖引用化包结构、重复照片、缺图报告和无引用缺图拒绝。
- 冻结边界复核：未增加云端照片字段、上传接口、对象存储或后台任务；未改变账单 DTO、云端冲突规则、同步开关偏好、删除 API 和会员价格；`web-preview` 按全局冻结边界未修改。
- 修改/新增文件：
  - `CLOUD_PHOTO_BACKUP_BOUNDARY_v1.md`
  - `NativeDemoApp/Services/LedgerLocalBackupDocument.swift`
  - `NativeDemoApp/Views/SettingsView.swift`
  - `NativeDemoApp/Views/MemberPricingView.swift`
  - `NativeDemoApp/ViewModels/SettingsViewModel.swift`
  - `NativeDemoApp/ViewModels/HomeViewModel.swift`
  - `NativeDemoAppTests/LedgerLocalBackupDocumentTests.swift`
  - `NativeDemoApp.xcodeproj/project.pbxproj`
  - `legal/privacy.html`、`legal/terms.html`
  - App Store/会员/商店当前文案文档与体验静态检查。
- Windows 验证：五项基础回归、迁移/SQLite 专项校验、Xcode 工程接线静态解析和含糊云备份承诺扫描全部通过；仍仅有既有 7 条 soft warning。
- 待 Xcode/真机验收：
  1. 未登录、已登录未开同步、已开同步三种状态下，设置首页/备份页/会员页均明确照片仅本机。
  2. 从备份 Sheet 导出、取消、失败、快速重复点击和下滑手势均不产生重复文件选择器或空白 Sheet。
  3. 导出的 `.xuzhangbackup` 可在“文件”和电脑中保留为完整包；账单数、照片引用、封面、重复照片和 README/manifest 正确。
  4. 有缺图时仍导出账单并显示准确缺图数；无数据也无引用时显示失败，不声称完整。
  5. 两台设备同账号同步后账单字段一致，但照片不会跨设备出现；界面说明与结果一致。
  6. “删除云端字段”“清空本机”“删除本机记录和照片，再同步字段”三条危险路径结果与提示一致。
  7. Debug/Release 编译与全部 XCTest 通过，确认自定义 package UTType 和 `FileDocument` 在 iOS 17 文件导出器可用。
- 当前状态：`CODE_DONE`。

### PERF-01：痕迹页按需构建快照

目标：初次进入只构建当前可见周/月内容，另一份空闲预热。

冻结边界：周/月叙事结果、缓存键和额度判断不变。

验收：缓存命中即时展示；切换月卡时有旧内容或轻量加载，不出现整页空白。

执行中（2026-07-15）：

- 按用户持续授权从 DATA-04 `CODE_DONE` 直接进入；前序文件导出与云端边界仍等待 Xcode/真机签收。
- 本项只调整痕迹页周/月快照的构建时机、缓存与空闲预热，不改变周/月叙事结果、缓存键、额度判断、筛选或卡片信息结构。
- 完成实现：
  - 初次进入生活痕迹只准备当前可见的周卡或月卡，不再把两份内容同时作为首屏阻塞条件。
  - 当前可见快照使用 `.userInitiated` 优先级；内容发布后，另一范围才以 `.utility` 在空闲路径预热。
  - 周、月刷新状态分离；另一范围待刷新时不会重复构建当前已可见范围。
  - 周/月快速切换且目标尚未完成时，继续显示已有卡片，并用“正在整理本周/本月”轻提示承接，不出现整页空白。
  - 缓存命中直接发布；`LatestRequestGate`、任务取消和页面离开失效共同阻止旧筛选/旧范围结果反写。
  - 新增 `TraceLifePreparationPolicy` 与 XCTest，覆盖首屏只准备当前范围、缺少月卡时以周卡承接、另一范围预热时不重算当前范围。
- 冻结边界复核：未改变周/月叙事生成输入与输出、缓存键、额度判断、筛选含义、卡片信息结构或 `web-preview`。
- 修改文件：
  - `NativeDemoApp/Views/StatsWebView.swift`
  - `NativeDemoApp/Views/StatsTraceModels.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/experience_static_check.ps1`
- Windows 验证：
  - 五项基础回归全部通过；文案检查仍仅有既有 7 条 soft warning。
  - `python scripts/validate_migration_samples.py` 与 `python scripts/validate_metadata_store_schema.py` 通过，确认前序数据边界未回退。
  - 对改动路径完成并发/取消人工复核：预热仅在当前结果发布后开始，取消请求不会清空已有卡片，旧请求不能覆盖新范围。
- 待 Xcode/真机验收：
  1. 冷启动进入痕迹周卡时，周卡先出现，月卡后台预热；反向以月卡进入同理。
  2. 1,000 条记录下首屏滚动、滑动周/月卡和切 Tab 无明显卡顿或整页白屏。
  3. 预热完成前快速周/月来回切换，旧卡稳定承接，目标卡完成后正确替换，无旧结果反写。
  4. 切换分类、日期范围、会员状态或修改账本后，缓存键与叙事结果保持原规则。
  5. 页面离开、任务取消和快速返回后无悬挂加载、重复计算或 concurrency warning。
  6. Debug/Release 编译与全部 XCTest 通过。
- 当前状态：`CODE_DONE`。

### PERF-02：复盘与 AI 指令重计算移出主线程

目标：大账本下滚动、输入和加载动画不中断。

冻结边界：相同输入必须得到相同结果；旧请求不得覆盖新请求。

验收：1,000 条记录聚合时可持续滚动和输入；任务取消、切 Tab、修改指令均无旧结果反写。

执行中（2026-07-15）：

- 按用户持续授权从 PERF-01 `CODE_DONE` 直接进入；PERF-01 与前序任务继续等待统一 Xcode/真机签收。
- 当前唯一目标：审计复盘快照与 AI 指令生成路径，把大账本聚合移出主线程，并保持相同输入/输出、取消语义和最新请求写入边界。
- 完成实现：
  - 新增 `InsightComputationService`，周复盘快照、关键词气泡、月度本地小结和远程 AI 所需统计都基于一次不可变账本快照在后台任务计算。
  - 周复盘页面只在主线程读取输入、显示加载状态和发布最终快照；账本变化、切 Tab 或页面离开会取消并使旧请求失效。
  - 月度复盘的本地叙事、当日/月度/周均统计和前三分类移出主线程；远程请求、额度、错误回退和埋点结论保持原逻辑。
  - AI 指令的筛选、排序、重复核对、生活线索、通勤草稿和图表生成收敛到不可变 `AICommandEngine`；主线程只处理输入校验、加载态和结果发布。
  - AI 指令新增独立 `LatestRequestGate`：快速重跑、清空、关闭 Sheet、切 Tab 后，旧任务即使稍后完成也不能覆盖新结果或恢复旧加载态。
  - 移除原 90ms 人工等待；计算任务使用 `.userInitiated`，输入中的账本、会员、金额和当前时刻在发起时固定，避免计算途中状态漂移。
  - 新增 1,000 条记录确定性测试入口，验证同一账本/时间/指令的周复盘与 AI 结果摘要一致，并覆盖旧请求失效。
- 冻结边界复核：未改变 AI 指令类型判断、查询/对比/重复/补记结论、通勤未来时段边界、周/月复盘文案选择、会员/额度、保存和远程 AI 回退规则；仅改变计算线程和发布时机。
- 修改/新增文件：
  - `NativeDemoApp/Services/InsightComputationService.swift`
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `NativeDemoApp/ViewModels/HomeViewModel.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `NativeDemoApp.xcodeproj/project.pbxproj`
  - `scripts/experience_static_check.ps1`
- Windows 验证：
  - 五项基础回归全部通过；文案仍仅有既有 7 条 soft warning。
  - 迁移样本与 SQLite schema 专项回归通过，前序数据边界未回退。
  - 新增 Swift 文件括号/字符串词法检查、Xcode 工程引用计数检查通过。
  - 静态门禁确认周/月复盘和 AI 指令均通过任务组离开主线程、无 90ms 人工延迟、服务已接入 App Target、1,000 条测试已接线。
- 待 Xcode/真机验收：
  1. 1,000 条记录下复盘页持续滚动、展开、生成月度复盘时动画和输入不中断。
  2. AI 指令连续输入三条不同查询，只有最后一条结果落地；清空、关闭 Sheet、切 Tab 后旧结果不回写。
  3. 通勤补记、重复检查、生活线索、最大一笔、分类汇总和对比指令与当前版本同输入结果一致。
  4. 本地月度复盘、远程 AI 成功、配额耗尽、缺 API Key 和网络失败回退路径结论与额度不变。
  5. 100/1,000 条记录分别观察主线程卡顿、任务取消、加载态复位和内存；5,000 条留 RELEASE-01 统一压力门禁。
  6. Debug/Release 编译与全部 XCTest 通过，无 Sendable、actor isolation 或任务组新警告。
- 当前状态：`CODE_DONE`。

### PROD-01：痕迹与复盘职责收敛

目标：落实“痕迹负责叙，复盘负责继续问”。

冻结边界：本任务先调整信息架构，不同时改额度和会员价格。

验收：用户能回答“看周/月去哪、继续问去哪”；同一周记/月记不在多个入口重复争主位。

执行中（2026-07-15）：

- 按用户持续授权从 PERF-02 `CODE_DONE` 直接进入；前序后台计算仍等待统一 Xcode/真机签收。
- 当前唯一目标：盘点痕迹、复盘、今日回放和 AI 继续聊入口，收敛为“痕迹看周/月生活章，复盘继续问与行动”，本项不调整额度、价格或底层叙事生成。
- 完成实现：
  - 复盘首页不再重复把完整周记作为首屏主内容，改为“继续问”入口，明确承接查账、对比、补记和按记录继续解读。
  - 复盘首页保留一条简短的本周节奏上下文与真实记录关键词，用作提问依据，不再与痕迹的完整周/月章节争主位。
  - 新增从复盘直达痕迹本周/本月的范围路由；进入后统一切到生活模式、对应周/月卡并滚到章节位置，清除自定义范围干扰。
  - 痕迹深层线索解锁后继续展示证据与节奏，但不再在痕迹页内展开问答芯片和回答；统一提供“去复盘查账、对比或继续问”。
  - 周/月回放 Sheet 原有“想多聊一句”仍通过关闭后路由进入复盘，NAV-01 的 Sheet 边界不变。
  - 月度生成入口在复盘中改为“继续问这个月/生成一次月度整理”，并提供“去痕迹看本月完整章节”，区分请求式整理与完整章节。
  - `StatsTabState.openLifeChapter` 提取为可测试范围路由，XCTest 覆盖从复盘返回本月痕迹后的模式、范围、自定义筛选和滚动锚点。
- 冻结边界复核：未改变周/月叙事生成、回放内容、AI 指令能力、深度线索额度、月度体验额度、会员价格或购买逻辑；只调整入口主次和跨 Tab 路由。
- 修改文件：
  - `NativeDemoApp/ContentView.swift`
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `NativeDemoApp/Views/StatsWebView.swift`
  - `NativeDemoApp/Views/StatsTraceModels.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/experience_static_check.ps1`
- Windows 验证：五项基础回归全部通过；文案仍仅有既有 7 条 soft warning；静态门禁确认复盘不再渲染完整周记主卡、痕迹不再本地展开问答芯片、周/月范围路由可测试。
- 待 Xcode/真机验收：
  1. 用户从底部 Tab 进入痕迹，能直接看到本周/本月完整章节；进入复盘，首屏明确是继续问而非第二份周记。
  2. 复盘“看本周痕迹”和“去痕迹看本月完整章节”分别落到正确周/月卡，模式、滚动和自定义范围正确。
  3. 痕迹深层线索解锁、免费额度耗尽和会员三种状态下，证据展示与额度结论不变，继续问统一进入复盘。
  4. 周/月回放 Sheet 的“想多聊一句”关闭后进入复盘，不叠层、不丢目标。
  5. 小屏与大字下复盘首卡两个入口不截断、不拥挤；VoiceOver 能区分看章节和继续问。
  6. Debug/Release 编译与全部 XCTest 通过。
- 当前状态：`CODE_DONE`。

### PROD-02：全局术语统一

目标：统一“今日回放、周记、月章、生活线索、AI 继续聊”等产品词。

冻结边界：只改命名和说明，不改变功能、额度和付费权益。

执行中（2026-07-15）：

- 按用户持续授权从 PROD-01 `CODE_DONE` 直接进入；前序信息架构仍等待统一 Xcode/真机签收。
- 当前唯一目标：建立术语映射并统一 iOS 可见入口、状态、按钮和会员说明；只改命名与解释，不改功能、额度、价格和权益。
- 完成实现：
  - 新增 `PRODUCT_TERMINOLOGY_v1.md`，固定 `今日回放`、`周记`、`月章`、`生活线索`、`复盘`、`AI 指令台`、`继续问`、`月度整理` 的含义、组合规则和停用旧称。
  - 当前 iOS 周/月播放标题统一为 `周记` 与 `月章`；完成态、额度说明、会员说明、设置页和引导提示同步统一。
  - `生活印记`、`深度线索` 的用户可见叫法统一为 `生活线索`；代码类型、存储字段和服务类名保持不变。
  - AI Sheet 统一称 `AI 指令台`，从回放或痕迹进入的动作统一称 `继续问`；移除“AI生活助手”“想多聊一句”“继续解读”等并行叫法。
  - 复盘中的请求式月度结果统一称 `月度整理`，与痕迹中的完整 `月章` 区分；保存、换语气、体验次数和空态说明同步调整。
  - 修正机械替换可能造成的“本周记节”“月章节”“本月章录”“这个月章下来”等组合错误，并补充可执行 `scripts/terminology_lint.py` 防止旧称回流。
  - App Store 当前设置说明与用户协议中的周/月名称同步当前术语；历史 v0.1 设计文档按术语表边界保留原文。
- 冻结边界复核：未修改任何功能入口目的地、免费额度、会员权益、Product ID、价格、购买/恢复逻辑、数据字段或叙事生成结论。
- 修改/新增文件：
  - `PRODUCT_TERMINOLOGY_v1.md`
  - `NativeDemoApp` 当前用户可见文案涉及的播放、复盘、会员、设置、记录和场景文件
  - `APP_STORE_IAP_SETUP.md`
  - `legal/terms.html`
  - `scripts/terminology_lint.py`
  - `scripts/experience_static_check.ps1`
- Windows 验证：五项基础回归全部通过；`terminology_lint.py` 扫描 74 个 Swift 文件通过；文案检查仍仅有既有 7 条 soft warning。
- 待 Xcode/真机验收：
  1. 首页、痕迹、复盘、周/月播放完成页、额度用尽弹层、会员页和设置页不再出现并行旧称。
  2. 周记/月章在小屏、Dynamic Type 和 VoiceOver 下表达完整，次数文本不截断。
  3. AI 指令台、继续问和月度整理的页面职责与 PROD-01 一致，不让用户误以为存在第二份月章。
  4. App Store 描述、用户协议与 App 内术语一致。
  5. Debug/Release 编译与全部 XCTest 通过。
- 当前状态：`CODE_DONE`。

### MEMBER-01：免费额度与会员价值简化

目标：从多套计数规则收敛为用户能理解的“省力记 + 长期回望”。

冻结边界：先提交产品规则表和迁移方案，用户确认后才能改常量与历史额度。

执行中（2026-07-15）：

- 按用户持续授权从 PROD-02 `CODE_DONE` 直接进入；术语代码仍等待统一 Xcode/真机签收。
- 当前唯一目标：先审计所有免费次数与会员入口，形成产品规则表、历史迁移和回滚方案；在未获得针对新常量的明确确认前，只允许简化展示与价值表达，不修改常量或历史计数。
- 完成实现：
  - 新增 `MEMBERSHIP_VALUE_AND_QUOTA_RULES_v1.md`，列明当前六套真实体验规则、刷新/存储边界、展示层方案，以及未来共享“长期回望体验”池的候选迁移/回滚要求。
  - 当前生产常量明确保持：今日回放 3/日、OCR 3/日、周记 3/周、月章 10 次长期体验、生活线索 5/月、月度整理 5 次体验。
  - 会员页从默认折叠的七条权益收敛为始终可见的两项核心价值：`省力记` 与 `长期回望`。
  - 免费/会员对比从三类细项收敛为两行，明确手动记账、基础统计和本地保存始终免费；具体次数只在对应功能入口显示。
  - 设置账号页的会员权益列表同步两层模型，不再同时堆叠周记、月章、今日回放、OCR、AI 等六条并行卖点。
  - 新增 `MembershipQuotaBaseline` 与 XCTest，锁定全部现有常量；月度整理的 5 次体验改为引用同一冻结基线，数值不变。
  - 新增 `membership_value_lint.py`，防止会员页重新回到七条折叠清单或规则文档/两层价值缺失。
- 决策边界：共享额度池只作为未来候选写入文档，未获得针对新常量的明确产品确认，因此本轮没有修改任何额度、历史计数或迁移字段；这不是遗漏，而是遵守任务卡冻结边界。
- 修改/新增文件：
  - `MEMBERSHIP_VALUE_AND_QUOTA_RULES_v1.md`
  - `NativeDemoApp/Views/MemberPricingView.swift`
  - `NativeDemoApp/Views/SettingsView.swift`
  - `NativeDemoApp/Models/InteractionStateModels.swift`
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/membership_value_lint.py`
  - `scripts/experience_static_check.ps1`
- Windows 验证：五项基础回归、术语/会员价值 lint、迁移样本与 SQLite schema 回归全部通过；文案仍仅有既有 7 条 soft warning。
- 待 Xcode/真机验收：
  1. 免费用户从会员页能明确理解手动记账免费，会员核心是省力记与长期回望。
  2. 会员页不需要展开即可看到两项核心价值；小屏、大字和 VoiceOver 下两行对比可读。
  3. 今日回放/OCR/周记/月章/生活线索/月度整理的入口次数与本任务前完全一致。
  4. 购买、取消、失败、恢复、登录/退出和永久会员路径不变。
  5. Debug/Release 编译与全部 XCTest 通过。
- 未实施项：共享额度池与历史迁移等待未来明确产品确认；不得根据本文件自动修改常量。
- 当前状态：`CODE_DONE`。

### AI-01：AI 助手能力承诺对齐

目标：开放输入的承诺与本地规则/远程模型真实能力一致。

冻结边界：不把本地推断包装成已调用远程 AI；不生成账本中不存在的生活事实。

执行中（2026-07-15）：

- 按用户持续授权从 MEMBER-01 `CODE_DONE` 直接进入；会员常量、价格和历史计数继续冻结。
- 当前唯一目标：逐一审计 AI 指令台、月度整理、今日建议、会员页与设置文案，把本地规则、远程 AI、失败回退和不支持能力说清，并增加事实边界回归。
- 完成实现：
  - 新增 `AI_CAPABILITY_CONTRACT_v1.md`，明确 AI 指令台、周记/月章、生活线索、今日小记、月度整理和 OCR 的真实执行方式、联网边界和禁止承诺。
  - AI 指令台首屏明确显示“本机规则 · 不联网”，说明只按时间、分类、金额和备注匹配；移除“先理解”“我理解的是”等开放理解暗示。
  - AI 指令台的加载态改为“正在按本机规则整理”，本地引擎静态检查禁止依赖 `AIReportService`、`URLSession`、远程开关或端点。
  - 今日小记加载说明明确：联网开时尝试远程模型，失败自动用本地规则；联网关时按本地记录和规则整理。
  - 月度整理增加真实状态：正在尝试远程模型、远程模型已生成、本地规则已生成、远程模型未接通已用本地规则、缺 API Key 将用本地规则。
  - 设置页说明联网开关只影响今日小记和月度整理；AI 指令台、周记、月章和生活线索始终本机处理。
  - 会员页移除“AI 会长期整理/AI 能整理”等泛化承诺；AI 指令台入口改为支持范围、先预览后保存、真实账本和不联网说明。
  - OCR 的用户可见名称从“智能导入”改为“账单识别”，不再暗示图片上传远程模型；导入规则和来源枚举值不变。
  - 远程服务错误统一称“远程模型”，并明确失败后使用本地规则。
  - 新增不支持问题回归：询问账本外“老板心情”时必须返回 unsupported，不能复述或编造该事实。
  - 新增 `ai_capability_lint.py`，扫描当前 Swift 用户文案和本地引擎依赖，防止旧承诺回流。
- 冻结边界复核：未新增远程调用、未改变 AI 指令结果、OCR 数据规则、批量保存、会员判断、额度、价格或后端协议；不改变已有本地/远程模型输出内容，只对齐状态和承诺。
- 修改/新增文件：
  - `AI_CAPABILITY_CONTRACT_v1.md`
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `NativeDemoApp/Views/SettingsView.swift`
  - `NativeDemoApp/Views/MemberPricingView.swift`
  - `NativeDemoApp/ViewModels/HomeViewModel.swift`
  - `NativeDemoApp/Services/AIReportService.swift`
  - `NativeDemoApp/Services/PlaybackSupportServices.swift`
  - `NativeDemoApp/Models/HomeItem.swift`
  - `NativeDemoApp/Views/RecordView.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/ai_capability_lint.py`
  - `scripts/experience_static_check.ps1`
- Windows 验证：五项基础回归、AI/术语/会员专项 lint、迁移样本与 SQLite schema 回归全部通过；文案仍仅有既有 7 条 soft warning。
- 待 Xcode/真机验收：
  1. 关闭联网时 AI 指令台、今日小记、月度整理均可使用，且无网络请求误导。
  2. 开启联网后，月度整理远程成功、缺 Key、额度耗尽、内容保护和网络失败五条状态与实际来源一致。
  3. AI 指令台支持查账、对比、重复、最大一笔、生活线索、通勤补记；不支持开放聊天时不编造。
  4. OCR 入口显示“账单识别”，识别、取消、确认和待整理规则不变。
  5. 会员页和设置页不再把所有本地规则包装成远程 AI。
  6. Debug/Release 编译与全部 XCTest 通过。
- 当前状态：`CODE_DONE`。

### A11Y-01：可访问性与阅读性

目标：处理小字号、低对比度、Dynamic Type、VoiceOver、Reduce Motion 和触控热区。

冻结边界：不借可访问性改造重做产品结构或主题体系。

执行中（2026-07-15）：

- 按用户持续授权从 AI-01 `CODE_DONE` 直接进入；前序 AI 能力边界仍等待统一 Xcode/真机签收。
- 完成实现：
  - 新增 `ACCESSIBILITY_READABILITY_CONTRACT_v1.md`，固定语义字体、44pt 触控、文字对比、VoiceOver、Reduce Motion 和发版检查边界。
  - 底部五个 Tab 改为 Dynamic Type 语义字号，触控高度提高并补选中状态、页面名称和提示；引导角标不再被单独朗读。
  - 复盘首卡的“继续问/看痕迹”、AI 指令输入操作、补记金额操作和额度弹层使用 `ViewThatFits`，宽度或大字不足时纵向承接。
  - AI 指令台的标题、说明、状态、结果卡、记录列表和主要按钮改为语义字体与最小 44pt；柱状图和记录行增加完整 VoiceOver 摘要；Reduce Motion 下取消预览缩放、弹簧和自动滚动动画。
  - 痕迹周/月切换、场景标签、细查、生活线索解锁和“继续问”修正字号与触控；节奏图增加摘要；痕迹编辑动画统一受 Reduce Motion 控制。
  - 会员页两项价值、免费/会员对比、套餐、隐私和协议入口改为可缩放排版；对比表在大字/窄屏改成纵向“免费/会员”说明并合并 VoiceOver。
  - 记录页手动/账单识别模式、截图入口、细节开关、OCR 状态和会员提示补 44pt、选中状态、朗读与 Reduce Motion；固定 17pt 说明高度已移除。
  - OCR 确认、场景选择和回放 Sheet 的关闭、日期/时间、确认/导入、完成页主操作统一 44pt；并排操作在空间不足时纵向排列。
  - 新增 `AccessibilityLayoutPolicy` 与 XCTest，锁定 44pt、0.72 文字透明度底线、主操作纵向策略和 Reduce Motion 结论。
  - 新增 `scripts/accessibility_lint.py` 并接入体验静态门禁，防止底部 Tab、小触控区、缺失自适应布局和 Reduce Motion 守卫回退。
- 冻结边界复核：未改变产品信息架构、主题体系、账单字段、OCR/AI 导入规则、额度、会员价格、购买恢复、周记/月章内容或页面职责；只调整字号、布局、触控、辅助朗读和装饰动画。
- 修改/新增文件：
  - `ACCESSIBILITY_READABILITY_CONTRACT_v1.md`
  - `NativeDemoApp/ContentView.swift`
  - `NativeDemoApp/Models/InteractionStateModels.swift`
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `NativeDemoApp/Views/StatsWebView.swift`
  - `NativeDemoApp/Views/MemberPricingView.swift`
  - `NativeDemoApp/Views/RecordView.swift`
  - `NativeDemoApp/Views/OCRConfirmSheet.swift`
  - `NativeDemoApp/Views/ScenePackAngleSheet.swift`
  - `NativeDemoApp/Views/SummaryPlaybackSheet.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/accessibility_lint.py`
  - `scripts/experience_static_check.ps1`
- Windows 验证：五项基础回归、术语/会员/AI/无障碍专项 lint、迁移样本和 SQLite schema 回归全部通过；文案仍仅有既有 7 条 soft warning。
- 待 Xcode/真机验收：
  1. iPhone 小屏、常规屏分别检查默认、特大和至少一个无障碍字号，确认底部 Tab、复盘首卡、会员对比和 OCR 底部操作不截断。
  2. VoiceOver 依次走五个 Tab、AI 指令查询/补记、痕迹周/月卡与节奏图、会员对比、记录模式、OCR 确认、回放完成页。
  3. Reduce Motion 下检查 AI 预览、痕迹切换、记录/OCR 待整理层、会员状态和回放章节，无非必要位移/缩放/弹簧。
  4. Debug/Release 编译与全部 XCTest 通过，修正任何 SwiftUI 泛型推断或可访问性 API 版本差异。
- 当前状态：`CODE_DONE`。

### OBS-01：产品与性能可观测性

目标：能够观察首记、首播、周回看、AI 使用、付费入口和性能耗时。

冻结边界：不上传备注、商户、照片、金额明细等敏感内容；先定义最小匿名事件表。

执行中（2026-07-15）：

- 按用户持续授权从 A11Y-01 `CODE_DONE` 直接进入；前序无障碍修改仍等待统一 Xcode/真机签收。
- 完成实现：
  - 新增 `PRODUCT_OBSERVABILITY_CONTRACT_v1.md`，固定本机默认、不联网、不上传、无稳定用户/设备标识、1,000 条/30 天保留和未来上传必须另行评审的边界。
  - 重写 `AnalyticsService` 为类型化事件与属性键；移除任意字符串事件接口，并在启动 v2 时清除曾允许自由属性的 `ios_analytics_events_v1`。
  - 属性按事件白名单和枚举值双重过滤；金额、备注、标题、商户、OCR/AI 原文、照片、地点、账单 ID、账号/设备 ID 均没有可写入口。
  - 账本规模、保存数量和图片数量只保存粗粒度桶；性能只保存 `under_50ms` 至 `3s_plus` 桶，不保存精确条数或精确耗时。
  - 首记漏斗接入手动、OCR、AI 三种来源；首播接入首笔提示、首次提示、明确开始与退出完成度；不会改变额度扣减时机。
  - 周/月回看接入开始、退出完成度和后台生成耗时；复盘/痕迹快照、AI 指令、月度整理接入账本规模桶与耗时桶。
  - AI 指令只记录结果类型、成功/阻止结论和账本规模桶，不记录用户输入、结果正文、金额或分类明细。
  - 会员漏斗接入统一入口场景、购买方案与成功/失败/阻止、恢复成功/失败/无权益；不记录账号或交易 ID。
  - 新增 `AnalyticsPrivacyBoundaryTests`，覆盖旧敏感日志删除、属性过滤、数量/耗时分桶、30 天过期与无稳定标识。
  - 新增 `scripts/observability_lint.py` 并接入体验静态门禁，禁止网络 SDK、自由字符串事件和敏感字段回流。
- 冻结边界复核：未新增网络请求或第三方 SDK；未上传任何事件；未改变保存、OCR/AI 结果、回放额度、会员价格/购买恢复、任务优先级、取消与页面状态。
- 修改/新增文件：
  - `PRODUCT_OBSERVABILITY_CONTRACT_v1.md`
  - `NativeDemoApp/Services/AnalyticsService.swift`
  - `NativeDemoApp/ViewModels/HomeViewModel.swift`
  - `NativeDemoApp/ContentView.swift`
  - `NativeDemoApp/Views/HomeView.swift`
  - `NativeDemoApp/Views/StatsWebView.swift`
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `NativeDemoApp/Views/MemberPricingView.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/observability_lint.py`
  - `scripts/experience_static_check.ps1`
- Windows 验证：五项基础回归、术语/会员/AI/无障碍/可观测性专项 lint、迁移样本和 SQLite schema 回归全部通过；文案仍仅有既有 7 条 soft warning。
- 待 Xcode/真机验收：
  1. 真机走完第一笔→首播提示→明确开始→完成，检查本机事件顺序和完成度桶，不出现金额/标题/商户等属性。
  2. 周/月回看、AI 指令、月度整理和痕迹/复盘在 100、1,000、5,000 条夹具下生成正确操作名、规模桶与耗时桶。
  3. 会员入口、未登录阻止、购买成功/失败、恢复成功/无权益只记录场景、方案和结果。
  4. Debug/Release 编译与全部 XCTest 通过，确认 MainActor 与测试隔离无新警告。
- 当前状态：`CODE_DONE`。

### RELEASE-01：发版门禁

必须完成：

- 100、1,000、5,000 条记录基线。
- 含照片、OCR 草稿、跨年记录和多分类。
- Debug/Release 编译。
- 首记、手动、OCR、AI 补记、今日回放、周/月章、痕迹细查、购买/恢复、同步、权限拒绝。
- VoiceOver、Dynamic Type、Reduce Motion。
- 数据迁移前后总数、总额、图片数一致。

执行中（2026-07-15）：

- 按用户持续授权从 OBS-01 `CODE_DONE` 直接进入；所有前序代码仍等待统一 Xcode/真机签收。
- 当前唯一目标：建立确定性的 100/1,000/5,000 条混合账本夹具、可执行的数据完整性/静态门禁、macOS Xcode 命令和覆盖全部高风险路径的统一真机签收清单；本项不修改业务结论。
- 完成实现：
  - 新增 `qa/release_fixtures/ledger_100.json`、`ledger_1000.json`、`ledger_5000.json` 和确定性 `manifest.json`；三档均使用稳定 ID，覆盖 2024/2025/2026、全部十个分类、旧单图/多图、非零封面、有效 PNG、OCR pending/resolved、记忆上下文和场景字段。
  - 固定金额分总和分别为 2,462,750、25,077,500、125,487,500；图片数分别为 15、153、769；OCR 草稿数分别为 10、91、455。
  - 新增 `scripts/generate_release_fixtures.py`；相同代码重复生成相同 JSON，夹具集合摘要固定为 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`。
  - 新增 `scripts/validate_release_gate.py`：Windows 可校验精确记录数、金额分总和、分类/跨年、图片 PNG/数量/顺序/封面、OCR 状态和摘要；统一 `windows` 阶段串行执行全部当前环境回归，macOS `all` 阶段继续执行 Debug/Release build 和 XCTest。
  - 增加 `device-audit`：从 Xcode 下载的 App Container 中只读检查 SQLite quick check/schema、记录/金额/分类/OCR、图片 SHA/顺序/封面/byte count 与迁移 manifest，防止只凭 UI 估算迁移结果。
  - Debug 新增 `-QAReleaseFixtureCount 100|1000|5000` 与 `-QAReleaseFixtureReset`；夹具先以旧 JSON 写入隔离目录，再走真实图片文件化和 SQLite 激活，普通账本不被覆盖；夹具模式停用 `HomeViewModel` 自动云端上传/删除/合并，R-11 留给专用测试账号单独验证。
  - XCTest 新增三档 JSON 与 Swift 工厂一致性、`UIImage(data:)` 图片解码、跨年/分类/OCR/封面、旧 JSON→图片文件→SQLite 迁移总数/总额/图片顺序/封面一致，以及 100/1,000/5,000 条复盘和 AI 结果确定性测试。
  - 新增 `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`，统一 FIX-001/002、R-01～R-12、全部前序任务、VoiceOver、Dynamic Type、Reduce Motion、位置/相册权限拒绝、StoreKit 购买恢复、同步、迁移、离线和三档性能签收顺序及证据格式。
  - 体验静态门禁已接入发布文档、生成器、验证器、Debug 隔离存储、云端保护和三档 XCTest 的防回退检查。
- 冻结边界复核：未改变账单字段/分类/语义、OCR/AI 结果、额度常量、会员 Product ID/价格/购买恢复、同步 DTO/冲突规则、回放/周记/月章结论或 `web-preview`；仅新增 QA 数据、Debug 显式装载、自动校验和签收文档。
- 修改/新增文件：
  - `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`
  - `qa/release_fixtures/`
  - `scripts/generate_release_fixtures.py`
  - `scripts/validate_release_gate.py`
  - `NativeDemoApp/Models/InteractionStateModels.swift`
  - `NativeDemoApp/Services/LocalStore.swift`
  - `NativeDemoApp/ViewModels/HomeViewModel.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/experience_static_check.ps1`
  - 本文档。
- Windows 验证：
  - `python scripts/validate_release_gate.py --phase windows` 整体通过。
  - 该统一命令内的 `git diff --check`、生活语义、体验静态、文案体验、文案 lint、术语/会员/AI/无障碍/可观测性专项、迁移样本与 SQLite schema 均通过。
  - 文案仍仅有既有 7 条 soft warning，没有新增硬错误。
- 待统一 Xcode/真机签收：
  1. macOS 执行统一 `--phase all`，确认 Debug/Release、全部 XCTest 与 concurrency/actor/Sendable/SQLite/SwiftUI 可访问性编译日志。
  2. iPhone 依次装载 100/1,000/5,000 条，执行矩阵并下载容器运行 `device-audit`；记录启动、滚动、保存和后台计算证据。
  3. 完成 FIX-001/002、R-01～R-12、全部前序交互、VoiceOver/Dynamic Type/Reduce Motion、权限拒绝和离线回退。
  4. 关闭 QA 参数，以 StoreKit 沙盒和专用同步账号完成购买/取消/失败/恢复及两设备同步/退出登录/危险操作。
- 当前状态：`CODE_DONE`。代码优化顺序已全部结束；后续只做统一签收及签收发现问题的定向修复，不新增范围。

---

## 6. 每项都要跑的基础回归

当前 Windows 环境可运行：

```powershell
git diff --check
python scripts/life_semantic_regression.py
powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1
powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1
python scripts/copy_lint.py
```

macOS/Xcode 环境补充：

```bash
xcodebuild -project NativeDemoApp.xcodeproj -scheme NativeDemoApp -configuration Debug build
xcodebuild -project NativeDemoApp.xcodeproj -scheme NativeDemoApp -configuration Release build
xcodebuild test -project NativeDemoApp.xcodeproj -scheme NativeDemoApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

任何检查失败都要记录失败原因；不得只运行最后一个命令掩盖前面失败的退出码。

---

## 7. 固定回归矩阵

| 编号 | 场景 | 关键边界 |
|---|---|---|
| R-01 | 手动只输金额保存 | 分类/标题预填正确，保存一次 |
| R-02 | 手动改分类、备注、日期 | 用户锁定不被自动推荐覆盖 |
| R-03 | 第一笔保存 | 不自动扣回放额度，提示不叠层 |
| R-04 | OCR 识别、取消、确认、待整理 | 不重复导入，不关闭后偷偷写入 |
| R-05 | AI 通勤补记 | 今天不生成未来时段，历史不受影响 |
| R-06 | AI 保存与清空 | 不白屏，不重复保存 |
| R-07 | 今日回放 | 明确开始才扣额度，暂停/重播/关闭正确 |
| R-08 | 周/月生活章 | 周月切换、额度、空数据和弱数据正确 |
| R-09 | 痕迹筛选与快速切换 | 旧任务不反写，筛选状态不丢失 |
| R-10 | 照片新增、删图、换封面 | 顺序和封面稳定，失败不破坏账本 |
| R-11 | 云端合并与退出登录 | 本地数据不被意外清空，冲突规则稳定 |
| R-12 | 会员购买、取消、失败、恢复 | 遮罩复位、权益正确、无重复购买 |

---

## 8. 执行记录

每次只追加，不删除历史记录。

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-15 | DOC-00 建立全局执行台账 | `IN_PROGRESS` → `VERIFIED` | 本文档、`AGENTS.md` | 文档检查、状态检查 | 已建立唯一顺序、状态、边界和回归规则 | GATE-00 |
| 2026-07-15 | FIX-001 AI 保存后空白 | `NOT_STARTED` → `CODE_DONE` | `InsightWebView.swift`、语义回归脚本 | Windows 静态/语义/文案检查通过 | 待 Xcode/真机签收 | GATE-00 |
| 2026-07-15 | FIX-002 今天提前生成晚通勤 | `NOT_STARTED` → `CODE_DONE` | `InsightWebView.swift`、语义回归脚本 | Windows 静态/语义/文案检查通过 | 待时间边界与历史范围真机签收 | GATE-00 |
| 2026-07-15 | GATE-00 当前两项修复真机签收 | `NOT_STARTED` → `IN_PROGRESS` → `BLOCKED` | 无业务代码修改，仅更新台账 | Windows 五项回归通过；确认 `xcodebuild`/Swift 不可用 | 等待 macOS/Xcode 编译与 iPhone 真机六项签收；不得进入 INT-01 | GATE-00 |
| 2026-07-15 | INT-01 保存后交互统一编排 | `NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE` | `ContentView.swift`、`HomeView.swift`、体验静态检查 | Windows 五项回归通过；新增保存后队列与自动扣额度防回归 | 待 Xcode/真机 7 项签收；GATE-00 风险继续保留 | INT-01 真机签收 |
| 2026-07-15 | NAV-01 Sheet 与跨页面路由状态统一 | `NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE` | `ContentView.swift`、`HomeView.swift`、`InsightWebView.swift`、`RecordView.swift`、`ScenePackAngleSheet.swift`、`SettingsView.swift`、`StatsWebView.swift`、`SummaryPlaybackSheet.swift`、体验静态检查 | Windows 五项回归通过；新增 `onDismiss` 路由和固定延时防回归 | 待 Xcode/真机 9 项签收；GATE-00、INT-01 风险继续保留 | NAV-01 真机签收 |
| 2026-07-15 | NAV-02 Tab 状态与滚动上下文保留 | `NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE` | `ContentView.swift`、`RecordView.swift`、`StatsTraceModels.swift`、`StatsWebView.swift`、`InsightWebView.swift`、体验静态检查 | Windows 五项回归通过；新增 Tab 会话状态、滚动锚点和草稿日期守卫 | 待 Xcode/真机 7 项签收；前序风险继续保留 | TEST-01 |
| 2026-07-15 | TEST-01 XCTest/UI 状态回归基线 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入；确认 Windows 无 Xcode/Swift | 先实现测试目标、夹具和静态门禁，最终统一在 macOS 运行 | TEST-01 |
| 2026-07-15 | TEST-01 XCTest/UI 状态回归基线 | `IN_PROGRESS` → `CODE_DONE` | Xcode 工程、共享 Scheme、交互状态模型、`StateRegressionTests.swift`、相关生产接入与静态检查 | Windows 五项回归通过；最低六类状态回归均已接线 | XCTest 尚未在 macOS 执行 | DATA-01 |
| 2026-07-15 | DATA-01 长期存储迁移设计与迁移样本 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入并复核冻结边界 | 仅设计、只读工具与样本；不切生产存储 | DATA-01 |
| 2026-07-15 | DATA-01 长期存储迁移设计与迁移样本 | `IN_PROGRESS` → `CODE_DONE` | 迁移设计文档、迁移模型、两份样本、只读分析与样本校验脚本、Xcode 工程接线 | Windows 五项回归与迁移样本校验通过 | 待 macOS 编译和设计签收 | DATA-02 |
| 2026-07-15 | DATA-02 照片文件化 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入并锁定 DATA-03 边界 | 图片文件化与旧数据迁移，不做元数据增量数据库 | DATA-02 |
| 2026-07-15 | DATA-02 照片文件化 | `IN_PROGRESS` → `CODE_DONE` | `HomeItem.swift`、`LedgerImageStore.swift`、`LocalStore.swift`、`HomeViewModel.swift`、缺图 UI、图片存储测试、Xcode 工程与迁移样本/静态门禁 | Windows 五项回归、迁移样本、Scheme XML 与测试接线检查通过 | 待 Xcode 编译、XCTest 和旧数据/失败恢复真机签收 | DATA-03 |
| 2026-07-15 | DATA-03 账单元数据增量持久化 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，冻结云端和同步冲突规则 | 先实现本地增量元数据与可回滚迁移 | DATA-03 |
| 2026-07-15 | DATA-03 账单元数据增量持久化 | `IN_PROGRESS` → `CODE_DONE` | SQLite 元数据 Store、启动/回滚 Repository、`LocalStore`、`HomeViewModel` 写保护、图片快速路径、迁移模型/设计/样本、XCTest、工程接线与 schema 校验 | Windows 五项回归、两项迁移/SQLite 专项校验、工程静态解析通过 | 待 Xcode 编译、XCTest、迁移失败注入与 1,000 条真机流畅度签收 | DATA-04 |
| 2026-07-15 | DATA-04 云端照片边界与备份承诺对齐 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，先审计真实云端能力再定方案 | 不改同步冲突规则，不含糊承诺照片备份 | DATA-04 |
| 2026-07-15 | DATA-04 云端照片边界与备份承诺对齐 | `IN_PROGRESS` → `CODE_DONE` | 云端边界决策文档、本地备份 `FileDocument`、设置/会员/状态文案、隐私/协议/App Store 文案、XCTest、工程与静态门禁 | Windows 五项回归、迁移专项、工程解析与误导文案扫描通过 | 待 iOS 文件导出、缺图、跨设备和危险操作真机签收 | PERF-01 |
| 2026-07-15 | PERF-01 痕迹页按需构建快照 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，冻结叙事结果/缓存键/额度 | 先审计当前周/月同时构建与预热路径 | PERF-01 |
| 2026-07-15 | PERF-01 痕迹页按需构建快照 | `IN_PROGRESS` → `CODE_DONE` | `StatsWebView.swift`、`StatsTraceModels.swift`、`StateRegressionTests.swift`、体验静态检查 | Windows 五项基础回归与迁移/SQLite 专项回归通过；并发取消人工复核完成 | 当前范围优先、旧卡承接与空闲预热完成；待 Xcode/1,000 条真机签收 | PERF-02 |
| 2026-07-15 | PERF-02 复盘与 AI 指令重计算移出主线程 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，冻结相同输入输出与最新请求边界 | 先审计复盘和 AI 指令的主线程聚合路径 | PERF-02 |
| 2026-07-15 | PERF-02 复盘与 AI 指令重计算移出主线程 | `IN_PROGRESS` → `CODE_DONE` | 后台复盘计算服务、AI 指令引擎、`HomeViewModel`、1,000 条 XCTest、工程与静态门禁 | Windows 五项基础回归、迁移/SQLite 专项、词法和工程接线检查通过 | 待 Xcode 编译、XCTest 与 1,000 条真机流畅度签收 | PROD-01 |
| 2026-07-15 | PROD-01 痕迹与复盘职责收敛 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，冻结额度、价格与叙事生成 | 先盘点重复入口和主次职责 | PROD-01 |
| 2026-07-15 | PROD-01 痕迹与复盘职责收敛 | `IN_PROGRESS` → `CODE_DONE` | `ContentView.swift`、复盘/痕迹页面、范围路由状态、XCTest 与静态门禁 | Windows 五项基础回归通过；职责与路由守卫通过 | 待 Xcode/真机确认周/月章节与继续问入口主次 | PROD-02 |
| 2026-07-15 | PROD-02 全局术语统一 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，冻结功能、额度和付费权益 | 先建立术语表并扫描所有 iOS 可见文案 | PROD-02 |
| 2026-07-15 | PROD-02 全局术语统一 | `IN_PROGRESS` → `CODE_DONE` | 术语表、iOS 当前文案、App Store/协议、术语 lint 与静态门禁 | Windows 五项基础回归与 74 文件术语扫描通过 | 待 Xcode/真机确认全入口显示与可访问性 | MEMBER-01 |
| 2026-07-15 | MEMBER-01 免费额度与会员价值简化 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入；常量与历史计数保持冻结 | 先输出规则表、迁移方案，再做展示层简化 | MEMBER-01 |
| 2026-07-15 | MEMBER-01 免费额度与会员价值简化 | `IN_PROGRESS` → `CODE_DONE` | 会员/额度规则表、会员页、设置页、冻结基线 XCTest、会员价值 lint | Windows 五项基础回归、专项 lint 和数据回归通过 | 共享额度池未获明确确认且未实施；待真机确认两层价值和原次数不变 | AI-01 |
| 2026-07-15 | AI-01 AI 能力承诺对齐 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，冻结会员/额度与真实事实边界 | 先审计本地规则、远程 AI 与回退文案 | AI-01 |
| 2026-07-15 | AI-01 AI 能力承诺对齐 | `IN_PROGRESS` → `CODE_DONE` | AI 能力契约、指令台/月度/今日/设置/会员文案、OCR 名称、事实 XCTest 与 AI lint | Windows 五项基础回归、专项 lint 和数据回归通过 | 待远程成功/失败状态与不支持问题真机签收 | A11Y-01 |
| 2026-07-15 | A11Y-01 可访问性与阅读性 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，冻结产品结构和主题体系 | 先审计字号、固定尺寸、触控、VoiceOver 与 Reduce Motion | A11Y-01 |
| 2026-07-15 | A11Y-01 可访问性与阅读性 | `IN_PROGRESS` → `CODE_DONE` | 无障碍契约、核心 Tab/Sheet/会员/记录/痕迹/复盘、策略 XCTest 与 lint | Windows 五项基础回归、专项 lint、迁移/SQLite 回归通过 | 待 Xcode 编译、Dynamic Type、VoiceOver 与 Reduce Motion 真机签收 | OBS-01 |
| 2026-07-15 | OBS-01 产品与性能可观测性 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，锁定本地匿名与敏感字段禁采边界 | 先定义事件白名单和本地存储，再接入关键漏斗与耗时 | OBS-01 |
| 2026-07-15 | OBS-01 产品与性能可观测性 | `IN_PROGRESS` → `CODE_DONE` | 可观测性契约、本机类型化事件、首记/首播/周月/AI/会员/性能接入、隐私 XCTest 与 lint | Windows 五项基础回归、专项 lint、迁移/SQLite 回归通过 | 待 Xcode 编译、本机事件核对和 100/1,000/5,000 真机耗时签收 | RELEASE-01 |
| 2026-07-15 | RELEASE-01 发版门禁 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 按持续授权进入，冻结全部产品与数据结论 | 建立混合夹具、自动门禁和统一真机/Xcode 清单 | RELEASE-01 |
| 2026-07-15 | RELEASE-01 发版门禁 | `IN_PROGRESS` → `CODE_DONE` | 三档发布夹具/manifest、生成与统一验证脚本、Debug 隔离装载、三档 XCTest、统一真机矩阵、体验静态门禁 | `python scripts/validate_release_gate.py --phase windows` 整体通过；集合摘要固定，既有 7 条文案软提示 | Windows 代码阶段完成；仍缺 macOS Debug/Release/XCTest、StoreKit 沙盒和 iPhone 全矩阵/device-audit | 统一 Xcode/真机签收 |
| 2026-09-04 | DISCOVER-MEMORY-WALL-01 线索详情生活片段墙 | `NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE` | `StatsTraceModels.swift`、`StatsWebView.swift`、`StateRegressionTests.swift`、体验静态门禁、发布矩阵与本文档 | Windows 基础回归、布局 XCTest 静态接线、体验静态检查和 `validate_release_gate.py --phase windows` 通过；发布门禁 `release_repository_gate: OK` | 照片墙改为确定性 hero/pair 拼贴，记录墙按日期时间线分组；待 macOS/Xcode、照片解码、无障碍和 TestFlight/Instruments 真机签收 | FLOW-103 真机签收 |

---

## 9. 当前交接状态

- 当前无 `IN_PROGRESS`；`ARCH-FIX-01`、`ARCH-01`、`ARCH-02` 已完成 Windows 代码与回归，`RELEASE-02` 继续因缺少 Xcode、iPhone、StoreKit 沙盒与权限/无障碍真机条件而 `BLOCKED`。
- 保留阻塞任务：`GATE-00`，等待后续 macOS/Xcode 与真机补签收。
- 用户例外授权：2026-07-15 第一次允许启动 `INT-01`，第二次允许启动 `NAV-01`；第三次明确要求后续任务不再逐项询问、全部代码完成后统一真机验证。所有授权均不代表前序 Xcode/真机验收通过。
- 当前代码完成待签收：`INT-01`、`NAV-01`、`NAV-02`、`TEST-01`、`DATA-01`、`DATA-02`、`DATA-03`、`DATA-04`、`PERF-01`、`PERF-02`、`PROD-01`、`PROD-02`、`MEMBER-01`、`AI-01`、`A11Y-01`、`OBS-01`、`RELEASE-01`、`COPY-01`、`PERF-03`、`DATA-05`、`PERF-04`、`INT-02`、`DATA-06`、`MEMBER-02`、`DISCOVER-MEMORY-WALL-01`。
- 当前阶段：Windows 代码阶段和完整 repository gate 已完成；等待 macOS/Xcode、iPhone、短信/同步测试账号与 StoreKit 沙盒补签收，只允许处理签收发现的定向问题。
- 后续策略：只处理统一签收发现的定向问题；每个修复必须回填所属任务、边界和回归，不得重新展开产品范围。

---

## 10. 第二轮全局收口队列（2026-07-16）

用户指定以下顺序连续执行，不再逐项请求继续授权。一次只允许一个任务为 `IN_PROGRESS`；前一项达到 `CODE_DONE` 或 `VERIFIED` 并回填证据后，才能进入下一项。

| 顺序 | ID | 任务 | 当前状态 | 进入边界 |
|---:|---|---|---|---|
| 1 | COPY-01 | 修复用户可见乱码 | `CODE_DONE` | 只修复已发现的乱码区域并增加防回流检查，不改弹层结构或业务动作 |
| 2 | PERF-03 | 照片缩略图与按需加载 | `CODE_DONE` | 启动只读取元数据；保持原图、顺序、封面和缺图语义 |
| 3 | DATA-05 | 变化记录与图片增量保存 | `CODE_DONE` | 只处理变化集；保持排序、字段、回滚和同步冲突规则 |
| 4 | PERF-04 | 真实尺寸照片性能门禁 | `CODE_DONE` | 只新增真实尺寸 QA 夹具、测量和证据，不借测试改业务结论 |
| 5 | INT-02 | 保存后提示预算 | `CODE_DONE` | 减少主动打断；不改变照片/奖励资格、回放扣额和会员常量 |
| 6 | DATA-06 | 本地备份导入与恢复 | `CODE_DONE` | 校验、预览、冲突与回滚优先；不得覆盖现有账本后才报告失败 |
| 7 | MEMBER-02 | 会员登录直达与登录后续购 | `CODE_DONE` | 保持 Product ID、价格、权益验证与账号绑定规则 |
| 8 | RELEASE-02 | 统一 Xcode/真机签收 | `BLOCKED` | 最后执行 Debug/Release、XCTest、iPhone、StoreKit、权限和无障碍矩阵 |

### COPY-01：修复用户可见乱码

目标：修复会员购买结果、免费场景包更换确认和典藏主题试用弹层中的 UTF-8 乱码，并阻止同类字符串重新进入生产 Swift 文案。

允许修改：

- `MemberPricingView.swift` 中购买结果弹层文案。
- `ScenePackAngleSheet.swift` 中免费场景包更换确认弹层文案。
- `SettingsView.swift` 中典藏主题试用弹层文案。
- 现有文案 lint/静态门禁与本台账。

冻结边界：

- 不改变弹层出现条件、按钮动作、会员状态、场景包更换规则和 24 小时窗口。
- 不改变套餐、价格、Product ID、额度、主题试用资格或持续时间。
- 不修改照片、存储、保存队列、备份、登录和 `web-preview`。

验收：

- 上述弹层全部显示正常中文，按钮语义与原动作一致。
- 全量 Swift 用户文案扫描不存在 C1 控制字符或常见 UTF-8→Latin-1 乱码片段。
- 五项基础回归通过；无法在当前环境完成的 Xcode/真机显示签收记录为待办，不得标为 `VERIFIED`。

### 后续任务固定边界

- `PERF-03` 不顺带改保存协议；`DATA-05` 不重新设计 UI。
- `PERF-04` 只建立真实压力证据，性能修复必须回到所属任务定向处理。
- `INT-02` 不删除用户主动打开的功能，只限制系统主动打断。
- `DATA-06` 导入前必须只读校验和预览，恢复失败必须保留原账本与照片。
- `MEMBER-02` 登录成功后只恢复原购买意图一次，取消/失败不得自动购买。
- `RELEASE-02` 只做统一签收及签收发现问题的定向修复，不新增功能范围。

### 第二轮执行记录

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | 第二轮顺序与边界建档 | `NOT_STARTED` → `VERIFIED` | 本文档 | 顺序、单一 `IN_PROGRESS`、冻结边界复核 | 已按用户指定八项建立唯一队列；保留既有工作区修改 | COPY-01 |
| 2026-07-16 | COPY-01 用户可见乱码 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 全量乱码扫描定位 3 个弹层共 10 条受损字符串 | 只修复文案与防回流门禁 | COPY-01 |
| 2026-07-16 | COPY-01 用户可见乱码 | `IN_PROGRESS` → `CODE_DONE` | `MemberPricingView.swift`、`ScenePackAngleSheet.swift`、`SettingsView.swift`、`copy_lint.py`、本文档 | 全量乱码扫描无残留；五项基础回归通过；仅保留既有 7 条 soft warning | 弹层结构、按钮动作、会员/场景/主题规则未改；待 Xcode/真机显示签收 | PERF-03 |
| 2026-07-16 | PERF-03 照片缩略图与按需加载 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 先审计图片模型、存储与所有消费点 | 不改保存协议、图片顺序、封面或缺图语义 | PERF-03 |
| 2026-07-16 | PERF-03 照片缩略图与按需加载 | `IN_PROGRESS` → `CODE_DONE` | `HomeItem.swift`、图片/元数据 Repository、图片视图、首页/痕迹/回放、备份导出、XCTest、静态门禁、本文档 | 启动路径无 `hydrate`；缩略图/原图按需加载门禁通过；五项基础回归、迁移样本与 SQLite schema 通过 | 启动只保留元数据/引用/字节数；列表异步缩略图、详情原图；待 Xcode 编译和真实照片真机签收 | DATA-05 |
| 2026-07-16 | DATA-05 变化记录与图片增量保存 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 盘点 15 个持久化入口与 Repository 全量预处理路径 | 只改本地变化集持久化，不改 UI、同步冲突或字段含义 | DATA-05 |
| 2026-07-16 | DATA-05 变化记录与图片增量保存 | `IN_PROGRESS` → `CODE_DONE` | `HomeViewModel.swift`、`LocalStore.swift`、`LedgerHomeItemsRepository.swift`、`LedgerMetadataStore.swift`、`LedgerImageStore.swift`、XCTest、静态门禁、本文档 | 变化集/定向图片门禁、五项基础回归、迁移样本与 SQLite schema 通过 | 正常写入只处理显式 upsert/delete；全量路径仅用于迁移和失败回退；待 Xcode/XCTest/大账本真机签收 | PERF-04 |
| 2026-07-16 | PERF-04 真实尺寸照片性能门禁 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 审计现有 1×1 PNG 夹具与发布验证器 | 只新增真实照片 QA 资产、测量入口和证据格式 | PERF-04 |
| 2026-07-16 | PERF-04 真实尺寸照片性能门禁 | `IN_PROGRESS` → `CODE_DONE` | 3 张 12MP JPEG、生成/验证脚本、Debug realistic profile、Xcode 资源、启动耗时事件、XCTest、真机矩阵、本文档 | 真实照片尺寸/字节/SHA、资源接线与全量 Windows 门禁通过 | REAL-01～06 仍为 `NOT_RUN`，等待最后 Xcode/iPhone/Instruments 统一签收 | INT-02 |
| 2026-07-16 | INT-02 保存后提示预算 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 审计首笔回放、照片、奖励、宠物的保存后触发顺序 | 不改资格、额度或用户主动入口，只限制强提示频率 | INT-02 |
| 2026-07-16 | INT-02 保存后提示预算 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`ContentView.swift`、XCTest、静态门禁、真机矩阵、本文档 | 每日 2 次、20 分钟冷却、首笔/奖励/照片共享预算的回归通过 | 奖励仍待领取、照片仍可主动添加、回放仍明确点击才扣额；待真机节奏签收 | DATA-06 |
| 2026-07-16 | DATA-06 本地备份导入与恢复 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 审计 `.xuzhangbackup` 导出结构、设置入口与变化集回滚能力 | 先只读校验/预览，再安全合并；不做无预览覆盖 | DATA-06 |
| 2026-07-16 | DATA-06 本地备份导入与恢复 | `IN_PROGRESS` → `CODE_DONE` | `LedgerLocalBackupDocument.swift`、`HomeViewModel.swift`、`SettingsView.swift`、备份 XCTest、静态门禁、真机矩阵、本文档 | 包结构/字段/重复 ID/路径/SHA/清单只读校验；显式预览确认；按 ID 且仅较新备份胜出；缺图保位；持久化成功前不替换内存账本；七项 Windows 回归通过 | 不提供清空覆盖；取消零写入，失败保留原账本与照片；待 Xcode/XCTest、文件 App 与 1,000 条真实照片真机签收 | MEMBER-02 |
| 2026-07-16 | MEMBER-02 会员登录直达与登录后续购 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 审计会员购买/恢复的未登录分支、根路由和账号登录回调 | 保留套餐、Product ID、价格、StoreKit 验证和账号绑定；登录后不自动扣款 | MEMBER-02 |
| 2026-07-16 | MEMBER-02 会员登录直达与登录后续购 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`SettingsViewModel.swift`、`MemberPricingView.swift`、XCTest、静态门禁、真机矩阵、本文档 | 未登录购买/恢复直达登录 Sheet；失败可重试、取消清意图；登录成功保留原套餐/恢复意图并只续接一次；再次明确点击才调用 StoreKit；七项 Windows 回归通过 | Product ID、展示价格来源、交易验证、finish 与 appAccountToken 绑定未改；待 Xcode、短信账号和 StoreKit 沙盒签收 | RELEASE-02 |
| 2026-07-16 | RELEASE-02 统一 Xcode/真机签收 | `NOT_STARTED` → `IN_PROGRESS` | 本文档、统一矩阵 | 开始完整 Windows release gate、差异审计与外部环境可用性检查 | 只做签收及定向修复；Xcode/iPhone/StoreKit/权限/无障碍缺少环境时如实标记 `NOT_RUN`/`BLOCKED` | RELEASE-02 |
| 2026-07-16 | RELEASE-02 统一 Xcode/真机签收 | `IN_PROGRESS` → `BLOCKED` | 本文档、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` | `python scripts/validate_release_gate.py --phase windows` 全通过；确认 Windows 10 下 `xcodebuild`、`swift`、`simctl`、`instruments` 全不可用；矩阵逐项回填 | Windows repository gate `PASS`；Debug/Release/XCTest、100/1,000/5,000、REAL-01～05、文件恢复、短信登录续购、StoreKit、同步、权限、VoiceOver/Dynamic Type/Reduce Motion 均保持 `BLOCKED`/`NOT_RUN`，未冒充已验证 | macOS/Xcode 与 iPhone 统一补签收 |

---

## 11. 核心页面体积治理（2026-07-16）

本轮只做可审计的机械拆分；不改变页面状态所有权、业务规则、文案、路由、数据保存和视觉结果。每次只移动一个独立类型，编译错误或回归未清零前不得继续下一块。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 0 | ARCH-FIX-01 | 修复拆分后首批编译错误 | `CODE_DONE` | 只修复名称遮蔽、闭包捕获与 Binding，不改变计算结果 |
| 1 | ARCH-01 | 从痕迹页抽离 `FocusedRecordEditor` | `CODE_DONE` | 只移动完整顶层类型并接线工程，不修改编辑/照片/删除动作 |
| 2 | ARCH-02 | 拆分 `ContentView` 的编辑与日期组件 | `CODE_DONE` | 根路由、Tab 与保存后队列保持原所有权 |
| 2.1 | ARCH-FIX-02 | 修复 `PlaybackService` 候选闭包缺少返回 | `CODE_DONE` | 只补齐闭包显式返回，不改变回放候选、评分或照片加载语义 |
| 3 | ARCH-03 | 拆分设置、首页、记录、复盘与回放页面 | `NOT_STARTED` | 每次只拆一个职责，逐项回归 |

### ARCH-03 启动前新增冻结边界（2026-07-16）

用户再次强调：首页、痕迹和复盘已经经历较大产品、交互、性能与视觉调整，后续页面拆分不得把这些稳定结果重新改乱。启动 `ARCH-03` 时必须额外遵守：

1. 以提交 `7aa2f6e` 及其后真机定向修复为冻结基线；最新基线未完成 Xcode 编译和核心真机流程前，不开始大页面迁移。
2. 首页、痕迹、复盘属于高风险页面。拆分只允许移动一个完整、自包含的 View、Modifier 或辅助类型，不重组页面层级，不顺手改文案、卡片、间距、颜色、动画或任务入口。
3. 页面状态所有权保持原处；不得在拆分时改动 `@State`、`@Binding`、`EnvironmentObject`、异步任务门、缓存键、`sourceRevision`、滚动锚点、Sheet 路由或保存后队列的生命周期。
4. 痕迹的周/月按钮、图片横滑、按需图片加载和快照预热保持不变；复盘的查/比/补数据口径、懒加载、主题 Token 和补记确认边界保持不变；首页主动作优先级、草稿/OCR 承接和提示预算保持不变。
5. 不为了减少文件间参数而新建跨页面全局状态或共享抽象；允许暂时保留显式参数和局部重复，等所有拆分完成并真机验证后再单独评审抽象。
6. 每个子项开始前先记录迁出类型、原文件、目标文件、调用方和冻结行为；完成后必须逐项核对差异、工程 Sources 接线、Windows 门禁和 Xcode 编译。当前子项出现编译或真机回归时，只修当前迁移，不进入下一块。

`ARCH-03` 继续保持 `NOT_STARTED`；本段只加固未来执行边界，不代表已经授权或启动拆分。

### 核心页面体积治理执行记录

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | ARCH-FIX-01 首批编译错误 | `NOT_STARTED` → `CODE_DONE` | `InsightComputationService.swift`、`InsightWebView.swift`、`StatsTraceFilters.swift`、本文档 | `Self.items` 消除函数/数组遮蔽；惰性闭包显式 `self`；日期使用显式 `Binding<Date>`；`git diff --check` 与体验静态门禁通过 | 当前 Windows 无 Xcode，需 macOS 再确认完整编译；未改计算、筛选或日期含义 | ARCH-01 |
| 2026-07-16 | ARCH-01 痕迹页独立编辑器拆分 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 确认 `FocusedRecordEditor` 为完整顶层类型，首页和痕迹页共同调用 | 只移动类型到独立文件并更新 Xcode 工程 | ARCH-01 |
| 2026-07-16 | ARCH-01 痕迹页独立编辑器拆分 | `IN_PROGRESS` → `CODE_DONE` | `StatsWebView.swift`、`FocusedRecordEditor.swift`、Xcode 工程、静态门禁、本文档 | 编辑器 608 行完整迁出；痕迹根文件 7,022 → 6,411 行；唯一类型定义和工程 Sources 接线检查通过；五项基础回归通过 | 编辑、照片、日期、删除闭包与状态保持原样；待 Xcode 编译确认 | ARCH-02 |
| 2026-07-16 | ARCH-02 `ContentView` 编辑与日期组件拆分 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 确认 `WarmRecordDatePanel` 与 `RecordEditSheet` 均为独立顶层类型并被多页面复用 | 只移动完整类型并更新工程；不改根路由、Tab 或保存后队列 | ARCH-02 |
| 2026-07-16 | ARCH-02 `ContentView` 编辑与日期组件拆分 | `IN_PROGRESS` → `CODE_DONE` | `ContentView.swift`、`WarmRecordDatePanel.swift`、`RecordEditSheet.swift`、Xcode 工程、静态门禁、本文档 | 两个完整顶层类型共 742 行迁出；`ContentView.swift` 2,401 → 1,653 行；唯一类型定义、跨页面调用和工程 Sources 接线通过；完整 Windows release gate 通过 | 根 Tab、Sheet、保存后提示队列、编辑/日期/照片/删除行为未改；待 Xcode 编译确认 | ARCH-03 |
| 2026-07-16 | ARCH-FIX-02 回放候选闭包返回 | `NOT_STARTED` → `IN_PROGRESS` | `PlaybackService.swift`、本文档 | Xcode 报告 `Missing return in closure expected to return 'MemoryAnchorSelectionPolicy.Candidate'`，定位为多语句 `map` 闭包缺少显式返回 | 仅补 `return Candidate(...)`；回放候选内容、排序、去重、评分和图片按需加载保持不变 | ARCH-FIX-02 |
| 2026-07-16 | ARCH-FIX-02 回放候选闭包返回 | `IN_PROGRESS` → `CODE_DONE` | `PlaybackService.swift`、`experience_static_check.ps1`、本文档 | `map` 闭包改为 `return Candidate(...)`；新增显式返回防回流检查；完整 Windows release gate 通过 | 当前 Windows 无 Swift/Xcode，需在 macOS 重新编译确认；未改变候选内容、评分、去重、排序或图片加载语义 | ARCH-03 |
| 2026-07-16 | ARCH-03 启动边界加固 | `NOT_STARTED`（保持） | 本文档 | 固化当前首页、痕迹、复盘的状态、手势、缓存、主题、按需加载、路由与产品动作边界 | 未启动拆分；后续必须先完成最新基线 Xcode/核心真机签收，再按一个完整职责逐项机械迁移 | 统一 Xcode/真机签收 |

---

## 12. 痕迹性能与产品逻辑收敛（2026-07-16）

用户明确要求把痕迹页掉帧/误切原因修复与前述产品逻辑收敛合并执行。`ARCH-03` 保持 `NOT_STARTED`，本队列完成前不继续页面拆分。每次只允许一个任务为 `IN_PROGRESS`；编译错误或回归未清零前不得进入下一项。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | PERF-05 | 痕迹页周/月切换、图片横滑与渲染掉帧 | `CODE_DONE` | 不改周/月内容、额度、照片选择和回放数据，只调整手势所有权、图片解码缓存与切换渲染 |
| 2 | LOGIC-01 | 全局下一步动作与提示优先级 | `CODE_DONE` | 不改变保存数据、奖励/照片资格和回放额度 |
| 3 | LOGIC-02 | 手动记账与 OCR 主链缩短 | `CODE_DONE` | 金额、分类、标题、日期保存含义和 OCR 确认规则不变 |
| 4 | LOGIC-03 | 痕迹周/月时间范围与筛选语义统一 | `CODE_DONE` | 不改变周/月聚合、配额和历史数据 |
| 5 | LOGIC-04 | 复盘任务化：查、比、补 | `CODE_DONE` | 不扩张 AI 事实能力；补记仍须预览确认 |
| 6 | LOGIC-05 | 回放完成承接与内容成熟度 | `CODE_DONE` | 不改额度常量、扣次存储和章节事实来源 |
| 7 | LOGIC-06 | 会员触发与登录续购节奏 | `CODE_DONE` | Product ID、价格、StoreKit 验证、账号绑定和一次性续接不变 |
| 8 | LOGIC-07 | 新用户七日渐进路径 | `CODE_DONE` | 不增加强制引导页、不阻断免费手动记账 |
| 9 | LOGIC-08 | 状态矩阵、全量回归与统一真机清单 | `CODE_DONE` | Windows 不冒充 Xcode/真机签收 |

### 本轮统一产品状态优先级

1. OCR 待整理内容。
2. 未保存的手动草稿。
3. 今天没有记录：记下一笔。
4. 今天有新增且未回放：今日回放。
5. 本周内容成熟且未回看：本周痕迹。
6. 月末且本月章节未回看：本月章节。
7. 当前周/月回放已完成：可选进入复盘查、比、补。
8. 其余状态：继续记录，回看保持次入口。

通勤补记、宠物消息、照片、奖励和系统会员提示不得覆盖前四级动作；用户主动点击的功能入口仍然可达。

### 合并执行记录

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | PERF-05 痕迹页横滑与掉帧 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 代码审计确认整卡 `simultaneousGesture` 与内部横向 ScrollView 同时接收手势；图片在 SwiftUI `body` 中 `UIImage(data:)`；同图双实例并实时模糊；整卡移动弹簧切换 | 先解除手势竞争，再移出主线程解码、复用解码图并降低整卡过渡成本 | PERF-05 |
| 2026-07-16 | PERF-05 痕迹页横滑与掉帧 | `IN_PROGRESS` → `CODE_DONE` | `StatsWebView.swift`、`MemoryAttachmentViews.swift`、静态门禁、本文档 | 整卡横滑改为显式本周/本月按钮；内部照片/关键词横滑不再触发时间切换；图片后台降采样解码并缓存 `UIImage`；移除同图双实例实时模糊；整卡过渡改为轻量淡入；完整 Windows release gate 通过 | 待 iPhone 用真实 12MP 照片确认 Core Animation hitch、横滑和内存；周/月内容、额度与照片数据未改 | LOGIC-01 |
| 2026-07-16 | LOGIC-01 全局下一步动作 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 开始把 OCR 待整理、手动草稿、今日回放和周/月回看收敛为一个可测试的首页主动作 | 保留用户主动入口，不改保存、额度或系统提示资格 | LOGIC-01 |
| 2026-07-16 | LOGIC-01 全局下一步动作 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`PlaybackSupportServices.swift`、`ContentView.swift`、`HomeView.swift`、XCTest、静态门禁、本文档 | 首页主动作按 OCR 待整理→手动草稿→今日回放→本周→本月→继续记录计算；次入口始终保留记录/回放；今日回放完成后记录账单签名，新增或编辑才再次提示；完整 Windows release gate 通过 | 回放次数、保存内容、奖励/照片资格未改；待 Xcode 与真机确认动态按钮布局和跨 Tab 恢复 | LOGIC-02 |
| 2026-07-16 | LOGIC-02 手动记录与 OCR 主链 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 收拢保存前选择，只在尚未开始手动草稿时提示 OCR；分类、备注和日期统一为可选补充 | 保存含义、OCR 预览确认和草稿保留规则不变 | LOGIC-02 |
| 2026-07-16 | LOGIC-02 手动记录与 OCR 主链 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`RecordView.swift`、XCTest、静态门禁、本文档 | 尚未输入金额时保留截图导入；进入手动草稿后不再用 OCR 抢主任务；分类、备注、日期统一收进“补充细节”；金额键盘和普通页面均保留保存入口；完整 Windows release gate 通过 | 保存失败、切换 OCR 和返回手动均保留草稿；保存字段与 OCR 确认规则未改；待真机确认小屏/大字下三项补充操作 | LOGIC-03 |
| 2026-07-16 | LOGIC-03 痕迹时间范围统一 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 让生活章节、明细时间筛选和首页跳转共享本周/本月状态；自定义时间与分类只影响细查/线索 | 周/月聚合、额度与历史记录不变 | LOGIC-03 |
| 2026-07-16 | LOGIC-03 痕迹时间范围统一 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`StatsWebView.swift`、`StatsTraceFilters.swift`、XCTest、静态门禁、本文档 | 本周/本月主卡、首页跳转和细查筛选共享同一映射；自定义时间与分类只刷新线索/明细，不再使生活章节缓存失效；完整 Windows release gate 通过 | 周/月聚合、额度和历史记录未改；待真机确认从细查返回主卡的范围一致和切换流畅度 | LOGIC-04 |
| 2026-07-16 | LOGIC-04 复盘任务化 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 首屏收敛为查记录、做对比、补遗漏三类明确任务；完整周记/月章继续归痕迹 | 不扩张本机指令能力，不跳过补记预览确认 | LOGIC-04 |
| 2026-07-16 | LOGIC-04 复盘任务化 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`InsightWebView.swift`、`PRODUCT_TERMINOLOGY_v1.md`、术语 lint、XCTest、静态门禁、本文档 | 复盘首屏固定为查记录、做对比、补遗漏，分别进入真实支持的本机规则指令；完整周/月章节只回痕迹；不再从首屏打开重复今日/月度内容；完整 Windows release gate 通过 | AI 能力、事实边界和补记预览确认未改；旧月度/今日实现仍保留但不争首屏，待后续稳定后再决定是否清理 | LOGIC-05 |
| 2026-07-16 | LOGIC-05 回放承接与成熟度 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 把首页周/月推荐成熟度和回放完成后的唯一主动作变成可测试规则 | 不改额度常量、扣次时点或章节事实来源 | LOGIC-05 |
| 2026-07-16 | LOGIC-05 回放承接与成熟度 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`HomeView.swift`、`SummaryPlaybackSheet.swift`、XCTest、静态门禁、本文档 | 首页周记至少 3 笔才推荐，月章至少 3 笔且到 25 日后才推荐；周/月回放完成统一为一个主动作，会员完成退出、非会员进入对应会员价值页；完整 Windows release gate 通过 | 额度常量、扣次存储、章节事实来源和次级保存/继续问入口未改；待 Xcode/真机确认完成区布局 | LOGIC-06 |
| 2026-07-16 | LOGIC-06 会员触发与登录续购节奏 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 自动会员提示统一纳入每日频率、场景冷却和拒绝后的跨场景冷却；用户主动点击受限能力不等待自动提示预算 | Product ID、展示价格、StoreKit 校验、账号绑定和登录后一次性续接不变 | LOGIC-06 |
| 2026-07-16 | LOGIC-06 会员触发与登录续购节奏 | `IN_PROGRESS` → `CODE_DONE` | `MemberNudgePolicyService.swift`、`HomeView.swift`、`HomeViewModel.swift`、XCTest、静态门禁、本文档 | 自动会员提示区分于用户主动入口，受每日一次、场景冷却及拒绝后的跨场景冷却约束；今日回放的“稍后再说”会记录冷却；移除未实际展示却消耗预算的后台提示；旧状态可兼容解码；登录后购买/恢复的一次性续接回归仍通过；完整 Windows release gate 通过 | Product ID、价格、StoreKit 校验、账号绑定和主动受限入口未改；待真机确认提示关闭后跨页面不再连续出现 | LOGIC-07 |
| 2026-07-16 | LOGIC-07 新用户七日渐进路径 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 用一个可测试阶段描述空账本、首笔回放、周记成熟、月章成熟和回放后复盘；零数据不展示空复盘或会员推销 | 不增加强制引导页，不阻断免费手动记账 | LOGIC-07 |
| 2026-07-16 | LOGIC-07 新用户七日渐进路径 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`HomeView.swift`、`ContentView.swift`、`InsightWebView.swift`、XCTest、静态门禁、本文档 | 空账本→记第一笔，有未回放记录→今日回放，成熟周/月数据→对应痕迹，完成当前周/月回放→可选复盘；首页仍保留继续记录次入口；空账本进入复盘直接提示记一笔，不执行空聚合、不展示会员动作；完整 Windows release gate 通过 | 未新增强制引导页，免费手动记账和已有用户主动 Tab 不受阻；待真机确认空态与动态按钮布局 | LOGIC-08 |
| 2026-07-16 | LOGIC-08 状态矩阵与统一收口 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 汇总数据成熟度、草稿、回放、会员、取消/失败、照片横滑和周/月范围的回归矩阵，并统一列出 Xcode/真机待签项 | Windows 只签静态、脚本和仓库门禁，不冒充 Xcode、StoreKit 或 iPhone 性能结论 | LOGIC-08 |
| 2026-07-16 | LOGIC-08 状态矩阵与统一收口 | `IN_PROGRESS` → `CODE_DONE` | `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、静态门禁、本文档 | 新增 FLOW-01～14 产品状态矩阵与 REAL-06 痕迹手势/掉帧真机项；完整 Windows release gate 再次通过，夹具、差异、语义、交互、文案、迁移和 SQLite schema 均通过 | 当前无 `IN_PROGRESS`；PERF-05、LOGIC-01～08 均为 `CODE_DONE`；Xcode Debug/Release、XCTest、iPhone 真实照片/掉帧、StoreKit、权限和无障碍仍为 `BLOCKED/NOT_RUN`；`ARCH-03` 保持 `NOT_STARTED` | 统一 Xcode/真机签收 |

### 本轮收口结论

- 本轮队列已全部完成 Windows 代码与仓库门禁，当前无 `IN_PROGRESS`。
- `ARCH-03` 页面继续拆分保持 `NOT_STARTED`，没有在本轮产品逻辑收敛中夹带继续拆分。
- 真机统一按 `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 的 REAL-01～06、FLOW-01～16、R-01～12、StoreKit、权限和无障碍矩阵执行；未执行项不得写为 `VERIFIED`。

---

## 13. AI 指令台对比可视化（2026-07-16）

用户真机反馈“做对比”仍主要依赖文字阅读，简图只展示当前周期，相关记录也只列当前周期，无法直观看出两段差异来源。本项只优化对比结果的数据承载与呈现，不改变查询、补记、额度、会员和账本写入边界。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | LOGIC-09 | AI 指令台双周期对比与证据分组 | `CODE_DONE` | 对比仍只读；不改变查询/补记结果、AI 事实来源、额度或保存规则 |

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | LOGIC-09 AI 对比可视化 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 定位到对比计算虽读取两段数据，但结果模型只向 UI 输出当前周期的柱图和记录 | 增加双周期总览、同尺度金额条、分类变化和两段证据记录；本周/月按同期口径比较 | LOGIC-09 |
| 2026-07-16 | LOGIC-09 AI 对比可视化 | `IN_PROGRESS` → `CODE_DONE` | `InsightWebView.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、体验静态门禁、本文档 | 双周期金额/笔数卡、同尺度金额条、分类双条、增减提示和两段证据分组已接线；XCTest 数据用例与防回流检查已补齐；完整 Windows release gate 通过 | 汇总按全部记录计算，证据每段最多保留 30 条、默认展示 5 条并可展开；本周/月按上一周期相同已过天数比较；Xcode 编译、iPhone 动态布局和真实数据可读性仍为 `BLOCKED`/`NOT_RUN` | 统一 Xcode/真机签收 |

### 本项收口结论

- `LOGIC-09` 已完成 Windows 代码、数据用例、静态护栏和仓库门禁，当前无 `IN_PROGRESS`。
- 对比页从“阅读文字结论”调整为“先看两段总览与同尺度差异，再看分类变化，最后核对两段原始记录”；查询、补记和写入路径未改。
- Xcode Debug/Release、XCTest、iPhone 小屏/大字布局、长列表展开和真实账本可读性尚未执行，不标记为 `VERIFIED`。

---

## 14. 复盘任务工作台完善（2026-07-16）

用户确认复盘已收敛为真正的任务入口，并要求数据表达更直观、UI 更完整。本项把首屏、任务切换和查/比/补结果统一为同一套任务工作台；不恢复重复周记/月章，不扩张本机规则能力，也不改变补记确认、会员、额度和账本写入边界。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | LOGIC-10 | 复盘数据看板、任务导航与三类结果视觉统一 | `CODE_DONE` | 查/比保持只读；补记确认前零写入；不改变 AI 事实来源、额度、会员或痕迹章节 |

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | LOGIC-10 复盘任务工作台 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 审计确认首屏只有说明文字和三个同质按钮；近 7 天事实未形成看板；进入任务后仍共用通用标题、输入和结果层级 | 增加后台聚合的近 7 天/前 7 天看板、带真实上下文的任务卡、任务内切换、可执行分类入口，以及查询/对比/补记专用结果总览 | LOGIC-10 |
| 2026-07-16 | LOGIC-10 复盘任务工作台 | `IN_PROGRESS` → `CODE_DONE` | `InsightComputationService.swift`、`InsightWebView.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、体验/无障碍静态门禁、本文档 | 首屏看板、同期差额、每日分布、任务上下文、分类快捷查找、任务内切换、查询指标、对比笔数/分类、补记候选汇总与长列表展开已接线；完整 Windows release gate 通过 | 聚合一次在后台快照完成，不在 SwiftUI `body` 遍历账本；查/比仍只读，补记确认前零写入；Xcode 编译、iPhone 默认/特大/无障碍字号与真实长列表仍为 `BLOCKED`/`NOT_RUN` | 统一 Xcode/真机签收 |

### 本项收口结论

- `LOGIC-10` 已完成 Windows 代码、确定性数据用例、静态护栏和仓库门禁，当前无 `IN_PROGRESS`。
- 复盘首屏现在先展示真实数据，再给出带上下文的查记录、做对比、补遗漏任务；原先不可操作的动态词泡改成带明确时间与分类的快捷查找。
- 三种任务在同一指令台内可切换，但拥有各自标题、说明、输入提示、推荐指令、加载态和结果总览；完整周记/月章仍只在痕迹。
- Xcode Debug/Release、XCTest、iPhone 小屏/大字、VoiceOver、长候选展开和真实账本视觉密度尚未执行，不标记为 `VERIFIED`。

---

## 15. AI 指令台多主题感知渲染减负（2026-07-16）

用户确认当前默认主题下的指令台视觉方向保持不变，同时要求针对全部主题分析卡片适配边界，并定向处理上下滚动掉帧。本项只替换高成本合成实现和不正确的固定白色叠层，不改变现有圆角、间距、信息结构、色彩角色或产品逻辑。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | PERF-06 | AI 指令台多主题感知渲染减负 | `CODE_DONE` | 不改查/比/补数据口径、输入与保存流程、额度、会员、全局主题组件或其他页面视觉 |

### 主题适配边界

- 必须适配主题：页面与导航背景、普通卡片、输入框、任务切换、记录列表、指标卡、文字、边框、分割线和当前周期强调色。
- 保持稳定语义：支出增减、警告、疑似重复、确认前写入等状态色不能被任意主题色替代；天气蓝可保留为装饰，但承载内容的底色、文字和边框必须使用主题 Token。
- 禁止全局扩散：不修改 `AppSemanticSurface` 或主题目录语义；只新增 AI 指令台局部轻量 Surface，避免影响其他页面和约 31 套主题。
- 性能边界：移除滚动区域实时材质模糊、固定白色叠层、重复大阴影与多层渐变；比例条改为低布局成本实现；长记录容器使用真正懒加载。

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | PERF-06 AI 指令台主题与滚动性能 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 完整读取台账并保护既有脏工作区；开始审计主题目录、深浅模式、指令台卡片与滚动合成路径 | 仅允许修改 AI 指令台局部渲染、专项静态门禁和统一真机矩阵 | PERF-06 |
| 2026-07-16 | PERF-06 AI 指令台主题与滚动性能 | `IN_PROGRESS` → `CODE_DONE` | `InsightWebView.swift`、`experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档 | 31 套主题/62 组 light-dark Token 校验通过；AI 指令台滚动区固定白色、Material、`GeometryReader` 和大阴影均清零；比例条改为异步 `Canvas`，记录/证据/候选改为 `LazyVStack`；推荐指令缓存复用 `sourceRevision`；完整 Windows release gate 通过 | 默认圆角、间距、信息结构和语义色角色保持；查询/对比只读、补记确认前零写入、额度/会员/保存未改；Xcode 编译和 FLOW-17 多主题/iPhone Core Animation 仍为 `BLOCKED`/`NOT_RUN` | 统一 Xcode/真机签收 |

### 本项收口结论

- 普通承载层全部改用主题 `background`、`panelStrong`、`surfaceMuted`、`stroke`、`text`、`subtext` 和 `accent`；默认主题仍保持原有柔和纸张层级，深色、霓虹、工业和永享主题不再被固定白卡覆盖。
- 支出增加继续使用稳定橙色提醒；疑似重复/确认前写入继续使用警示金色角色；雨天保留天气蓝装饰，但内容底色、文字和边框跟随主题。
- 没有修改全局 `AppSemanticSurface`、主题目录、其他页面视觉、查/比/补数据口径、保存流程、会员或额度。
- 真机按 `FLOW-17` 覆盖默认、纸质、深色霓虹、天气、工业和永久主题的 light/dark、长列表和 30 秒连续滚动；未执行前状态保持 `CODE_DONE`。

---

## 16. AI 指令台自然语言识别与可信边界（2026-07-16）

用户明确要求 AI 指令台不能被少量固定关键词限制，也不能因为模糊关联而把问题识别到过远的能力。本项只优化 AI 指令台运行时的自然语言归一化、意图识别、槽位提取与置信边界，使不同口语、语序和同义表达可以落到同一受支持任务，同时保证所有结论可回到明确账本条件和原始证据。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | AI-02 | AI 指令台宽容识别与可信边界 | `CODE_DONE` | 只改指令台识别和测试；不改记账分类、OCR、账本字段、时间事实、补记写入确认、额度、会员或远程 AI 边界 |

### 冻结边界例外与控制

- 必须修改原因：当前部分能力依赖固定短语和分散的 `contains` 判断，同义表达、口语语序和轻微错别字容易漏识别；继续只增加关键词会越来越脆弱，也更容易误命中。
- 允许修改：输入规范化、短语/同义词概念组、任务意图评分、时间/分类/金额/排序槽位、冲突消解、低置信度回退，以及对应 XCTest/静态门禁。
- 禁止扩张：不新增账本外知识，不把开放聊天包装成支持；不根据单个弱词跨任务跳转；不改变 `HomeItem` 分类推断、OCR 导入、生活回放、保存字段、通勤时点或重复判定的数据规则。
- 可信策略：强动作词决定任务方向，时间/分类/金额等槽位限定范围，账本证据决定结果；冲突或信息不足时返回明确的受支持提示，不猜测用户生活事实。
- 数据迁移与回滚：识别结果不持久化，无数据迁移；实现集中在可测试的纯识别策略中，回滚只需恢复识别策略，不触碰账本或图片。

### 验收边界

- 同义表达和常见口语语序可识别，例如“这礼拜吃饭用了多少”“最近坐车花销”“这个月跟上个月差在哪”。
- 否定、弱关联和账本外问题不误命中，例如“不要补记”“老板是不是心情不好”“交通不错吗”不能因为单个词进入写入或统计路径。
- 查询、对比、重复、最大一笔、记忆查找和补记之间存在明确优先级；补记必须有强写入意图且继续遵守预览确认。
- 相同输入保持确定性；识别结果能输出受支持任务和提取到的范围/分类证据，便于回归。

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | AI-02 AI 指令台自然语言识别 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 完整复读台账并保护既有脏工作区；开始审计指令分支、关键词、时间/分类槽位、否定和不支持边界 | 先建立可解释识别策略与反例矩阵，再替换分散的脆弱判断 | AI-02 |
| 2026-07-16 | AI-02 AI 指令台自然语言识别 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`InsightWebView.swift`、`StateRegressionTests.swift`、`AI_CAPABILITY_CONTRACT_v1.md`、统一真机矩阵、体验静态门禁、本文档 | 统一归一化/意图/槽位/置信与否定保护接入；自然口语、繁体、隐式对比、最近一笔/范围查询、否定与普通生成通勤、主观/账本外反例 XCTest 已接线；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 查/比只读、补记强动作且确认前零写入；未改分类推断、OCR、账本字段、额度、会员、远程 AI 或时间事实；当前 Windows 无 Xcode/Swift，新增 XCTest 与 FLOW-18 仍待 macOS/iPhone 验证 | 统一 Xcode/真机签收 |

### 本项收口结论

- 指令台不再由 `buildAICommandResult` 中分散的固定短语直接决定任务，统一先做口语/繁简体/全半角归一化，再输出可测试的意图、置信度和证据槽位。
- 查询、对比、重复、最大一笔、记忆、生活线索、最近一笔和通勤补记拥有明确优先级；“上次买可乐”和“这周打车是哪天”不再串路。
- “补上昨天通勤”可进入待确认补记；“不要补记今天通勤”“生成今天通勤”“减少这周餐饮记录”均不生成候选；带明确“统计/查账”的表达仍可安全只读。
- “交通不错吗”“老板今天怎么样”“为什么这个月比上个月多”等主观、外部主体和原因问题不会借时间/分类弱词进入账本结论。
- 没有引入编辑距离或开放式猜测；未识别输入继续明确回退。`ARCH-03` 保持 `NOT_STARTED`，没有夹带页面拆分。

---

## 17. AI 指令台对比依据双层收敛（2026-07-16）

用户真机确认当前“主要分类变化”和“对比依据”分处上下两个区域，下面的原始记录容易被理解成逐条配对。用户选择方案 C：保留顶部两段总览，把分类变化与原始证据合并为“差异来源 / 原始记录”双层切换。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | LOGIC-11 | AI 对比差异来源与原始记录双层呈现 | `CODE_DONE` | 只改对比结果的信息层级；不改时间范围、分类筛选、金额/笔数、证据集合、排序上限、只读边界、主题体系或其他指令结果 |

### 实施与验收边界

- 顶部“本周对比上周同期”和“两段对比”金额、笔数、同尺度金额条保持原口径。
- 移除“两段对比”卡内重复的“主要分类变化”；其数据迁入默认的“差异来源”。
- “差异来源”按分类已有金额与笔数识别新增、消失、增加、减少、持续，不进行商户或标题模糊配对。
- 变化占比使用各分类金额差绝对值在全部分类变化绝对值中的占比，只表达差异构成，不声称消费原因或因果。
- “原始记录”继续按两个周期分组、时间倒序、默认各 5 笔、每段最多 30 笔；汇总仍按全部匹配记录计算。
- 新结果、清空和任务切换必须回到默认“差异来源”并收起扩展内容；切换只影响展示，不触发重新计算或写入。
- 保持 AI 指令台当前主题 Token、轻量 Surface、LazyVStack、44pt 触控、VoiceOver 和 Reduce Motion 边界。
- `ARCH-03` 继续保持 `NOT_STARTED`，本项不得夹带页面拆分。

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | LOGIC-11 AI 对比双层呈现 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 完整复读台账并保护既有脏工作区；确认方案 C 合并“主要分类变化”和“对比依据” | 先保持计算模型不变，只重组对比结果视图、状态与专项门禁 | LOGIC-11 |
| 2026-07-16 | LOGIC-11 AI 对比双层呈现 | `IN_PROGRESS` → `CODE_DONE` | `InteractionStateModels.swift`、`InsightWebView.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`experience_static_check.ps1`、本文档 | 顶部两段总览保持；分类变化迁入默认“差异来源”；新增/消失/增加/减少/持续和绝对变化占比策略已测试；“原始记录”保留两段分组、时间倒序、5/30 笔边界；新结果、清空、任务切换重置默认态；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 未改对比时间、筛选、金额/笔数、证据集合、查询/补记、额度、会员、保存或主题；当前无 Xcode/Swift，编译、Dynamic Type、VoiceOver、主题和 FLOW-19 真机切换仍待验证 | 统一 Xcode/真机签收 |

### 本项收口结论

- 对比结果仍先展示结论和两段金额/笔数；“两段对比”卡不再重复承载分类变化。
- 下一层默认显示“差异来源”，按现有分类金额与笔数标记新增、消失、增加、减少和持续，并展示分类金额变化占比；不进行标题、商户或场景模糊配对。
- 用户可切换到“原始记录”核对原来的两段账单；记录集合、排序、默认显示数量和证据上限没有变化。
- 切换只改变 SwiftUI 展示状态，不重新聚合账本、不产生写入；新指令、清空和任务切换回到默认差异来源。
- `ARCH-03` 保持 `NOT_STARTED`，本项没有拆分页面或调整其他页面。

---

## 18. AI 指令结果后续动作去重复（2026-07-16）

用户确认同一账本与同一指令下“重新整理一次”只会得到重复内容，普通结果应改为更有价值的连续提问入口。本项只收敛结果底部动作，不改变查/比/补计算、方案 C 信息层级、主题或保存边界。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | LOGIC-12 | AI 结果“继续问”与快速回顶 | `CODE_DONE` | 只改普通结果的后续动作和输入焦点；不改指令识别、结果数据、补记动作、额度、会员、主题或页面拆分 |

### 实施与验收边界

- 查询、对比、记忆和重复核对等普通结果移除“重新整理一次”，改为“继续问”。
- 点击“继续问”保留当前指令，不触发重算、不写入账本；收起当前结果后快速回到顶部并聚焦输入框，用户可直接修改或追加问题。
- 补记候选继续只显示现有保存/冲突动作；缺金额和不支持结果保持现有处理。
- 清空、任务切换、新结果和方案 C“差异来源 / 原始记录”重置规则保持不变。
- 保持现有主题 Token、卡片、间距、44pt 触控、VoiceOver 与 Reduce Motion 边界。
- `ARCH-03` 继续保持 `NOT_STARTED`，本项不夹带页面拆分。

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | LOGIC-12 AI 结果后续动作 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 完整复读台账并保护既有脏工作区；确认确定性本机规则下重复运行没有新增价值 | 只替换普通结果动作，并补快速回顶、输入焦点、静态门禁和真机矩阵 | LOGIC-12 |
| 2026-07-16 | LOGIC-12 AI 结果后续动作 | `IN_PROGRESS` → `CODE_DONE` | `InsightWebView.swift`、`experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档 | 普通结果移除确定性重复运行，改为保留原指令的“继续问”；结果收起后以 0.16 秒轻量过渡回顶并请求输入焦点；静态门禁确认零重算、零清空；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 补记保存、缺金额、不支持、方案 C、识别、额度、会员、主题和写入均未改；Windows 无 Xcode/Swift，编译、键盘焦点、VoiceOver、Reduce Motion 与 FLOW-20 真机路径仍待签收 | 统一 Xcode/真机签收 |

### 本项收口结论

- 普通结果底部不再提供没有信息增量的“重新整理一次”，统一改为“继续问”。
- “继续问”只处理展示状态：保留当前指令、收起结果、重置结果展开态、快速回到顶部并聚焦输入框；不会重新执行计算，也不会写入账本。
- 补记候选仍只走原保存与冲突处理；缺金额和不支持结果没有新增误导动作。
- 完整 Windows release gate 已通过；`ARCH-03` 保持 `NOT_STARTED`，当前无 `IN_PROGRESS`。

---

## 19. AI 对比状态语义卡视觉强化（2026-07-16）

用户真机确认方案 C 的数据层级正确，但“消失、减少、持续”等状态仍主要依靠小标签和文字辨认，卡片颜色、金额结果与条形对比区分不足；同时结果底部“继续问”的 `text.cursor` 图标缩小后容易被看成字母 A/光标。本项按已确认效果图强化状态视觉，并替换歧义图标。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | LOGIC-13 | 差异来源状态语义卡与“继续问”图标 | `CODE_DONE` | 只改差异来源卡片视觉和继续问图标；不改状态判定、分类排序、金额/笔数、占比算法、原始记录、识别、写入、主题体系或页面拆分 |

### 实施与验收边界

- 差异来源标题下增加当前结果中新增、消失、增加、减少、持续的状态数量概览，只统计既有分类结果。
- 五种状态使用稳定语义图标与局部色彩：新增/增加、消失、减少、持续必须一眼可区分；主题背景、正文和边框仍使用现有 Token。
- 卡片增加轻量状态线、状态色边框/底色、强化主变化金额和状态说明；不使用材质、模糊、大阴影或高成本布局读取。
- 消失状态用零点与虚线差异轨迹表示本期归零；减少状态用浅色差异尾段表示缩短；上一周期仍使用中性色，全部条形继续共用原有最大金额尺度。
- 持续状态主结果显示等号与当前金额，辅助说明“金额持平 / 两段一致”；不改变底层 `steady` 判定。
- “继续问”保留 LOGIC-12 的回顶、保留指令和聚焦逻辑，只把歧义 `text.cursor` 替换为明确的向上箭头。
- 保持 44pt 触控、Dynamic Type、VoiceOver、Reduce Motion、LazyVStack 和多主题边界；`ARCH-03` 保持 `NOT_STARTED`。

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | LOGIC-13 状态语义卡视觉强化 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 完整复读台账、保护既有脏工作区并审计当前状态标签、统一卡片、双条金额和 `text.cursor` 图标 | 按确认效果图只实现局部语义视觉、专项门禁和真机矩阵 | LOGIC-13 |
| 2026-07-16 | LOGIC-13 状态语义卡视觉强化 | `IN_PROGRESS` → `CODE_DONE` | `InsightWebView.swift`、`experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档 | 增加五状态数量概览；新增/消失/增加/减少/持续接入独立图标、局部语义色、状态线、主金额与说明；消失/新增用零点虚线、减少用浅色差异尾段、持续显示等号金额；“继续问”改为向上箭头；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 金额、笔数、分类排序、状态判定、占比、原始记录、识别、写入和主题 Token 未改；Windows 无 Xcode/Swift，编译、默认/深色主题、Dynamic Type、VoiceOver、滚动和 FLOW-21 仍待真机签收 | 统一 Xcode/真机签收 |

### 本项收口结论

- 差异来源现在先显示当前结果的状态数量概览，再用状态图标、局部语义色和左侧状态线区分五种分类变化；整张卡仍由主题 Token 承载，没有固定白卡扩散。
- 消失/新增通过零点和虚线轨迹表达从有到无或从无到有；减少用浅色尾段呈现缩短；持续主结果显示等号金额，并在笔数相同时说明“两段一致”、笔数不同时明确“笔数不同”。
- 条形仍使用方案 C 原最大金额尺度，上一周期保持中性色；没有修改金额、笔数、分类集合、排序、占比或证据。
- “继续问”只把 `text.cursor` 替换为 `arrow.up`，LOGIC-12 的回顶、保留指令、聚焦、零重算和零写入边界保持不变。
- 完整 Windows release gate 已通过；`ARCH-03` 保持 `NOT_STARTED`，当前无 `IN_PROGRESS`。

---

## 20. 复盘入口稳定性、任务切换性能与首屏视觉收敛（2026-07-16）

用户真机反馈复盘首屏仍可压缩；从“查记录 / 做对比”打开 AI 指令台时预设指令偶尔未显示，任务内切换仍有卡顿。本队列按状态一致性、切换性能、视觉密度依次执行，三项不得混改；`ARCH-03` 继续保持 `NOT_STARTED`。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | FIX-003 | AI 指令台默认输入单一状态源 | `CODE_DONE` | 只修输入显示与父状态同步；不改预设文案、识别、执行、结果或保存 |
| 2 | PERF-07 | AI 指令台任务切换零主线程聚合 | `CODE_DONE` | 只移动推荐指令准备时机；不改推荐内容、任务分类、账本口径或缓存失效语义 |
| 3 | UI-01 | 复盘首屏视觉密度收敛 | `CODE_DONE` | 保持现有主题、数据、任务顺序和入口；只调整首屏层级、间距与重复视觉 |

### 统一边界

- 查记录与做对比继续只读；补遗漏确认前零写入。
- 三类默认指令文案、自然语言识别、时间/分类/金额口径、对比证据和补记时点保持不变。
- 不修改全局主题 Token、其他页面视觉、会员、额度、图片、存储、路由或 `web-preview`。
- 不使用材质、实时模糊、大阴影或布局读取换取视觉效果；Dynamic Type、VoiceOver、44pt 触控与 Reduce Motion 边界继续保持。
- 每项达到 `CODE_DONE` 并回填验证后才进入下一项；Windows 不冒充 Xcode/iPhone 签收。

### 执行记录

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-16 | FIX-003 AI 默认输入一致性 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 代码审计确认父级 `aiCommandText` 与输入组件局部 `draftText` 为双状态源，Sheet 复用时存在预设已写入但输入框仍为空的生命周期风险 | 先收敛为单一文本状态源，不改执行与预设文案 | FIX-003 |
| 2026-07-16 | FIX-003 AI 默认输入一致性 | `IN_PROGRESS` → `CODE_DONE` | `InsightWebView.swift`、`experience_static_check.ps1`、本文档 | 输入框直接绑定父级 `aiCommandText`，移除局部 `draftText` 初始化和同步；`git diff --check` 与完整体验静态门禁通过 | 预设、用户编辑、清空和执行共享单一状态源；Windows 无 Xcode，Sheet 复用与键盘路径仍待真机签收 | PERF-07 |
| 2026-07-16 | PERF-07 AI 任务切换性能 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 审计确认推荐指令在 SwiftUI `body` 中冷缓存同步扫描最近记录、完整历史和生活线索；缓存按任务与 `sourceRevision` 分裂 | 只移动准备时机并复用一次不可变输入，不改推荐结果 | PERF-07 |
| 2026-07-16 | PERF-07 AI 任务切换性能 | `IN_PROGRESS` → `CODE_DONE` | `InsightComputationService.swift`、`InsightWebView.swift`、`StateRegressionTests.swift`、`experience_static_check.ps1`、本文档 | 查/比/补推荐基于一个不可变账本快照在后台一次生成；页面出现、账本/会员变化和打开任务时按账本修订准备；`body` 只读取已准备数组或固定回退；`git diff --check` 与完整体验静态门禁通过 | 任务切换不再触发账本扫描或生活线索聚合；推荐内容、每类最多 5 条和修订失效语义保持；待 Xcode/XCTest 与 1,000 条真机切换签收 | UI-01 |
| 2026-07-16 | UI-01 复盘首屏视觉密度 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 截图与代码审计确认顶部标题留白、看板卡中套卡和三张任务入口共同占满首屏，分类快捷入口露出不足 | 保持当前柔和主题与三任务信息架构，只压缩层级和重复动作表达 | UI-01 |
| 2026-07-16 | UI-01 复盘首屏视觉密度 | `IN_PROGRESS` → `CODE_DONE` | `ContentView.swift`、`InsightWebView.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`experience_static_check.ps1`、本文档 | 复盘页标题定向缩小；首卡标题、间距和内边距收敛；三指标从三张独立子卡合并为一个轻量数据条；柱图和任务卡降高，默认字号下移除重复动作文字只保留明确箭头；新增 FLOW-22；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 主题 Token、三任务顺序、真实数据、入口、Dynamic Type/VoiceOver/44pt 边界保持；Xcode 编译、默认/深色/大字和 1,000 条真机视觉与 hitch 仍待签收 | 统一 Xcode/真机签收 |

### 本项收口结论

- `FIX-003`、`PERF-07`、`UI-01` 均已达到 `CODE_DONE`，当前无 `IN_PROGRESS`；`ARCH-03` 继续保持 `NOT_STARTED`。
- AI 指令输入不再维护父子两份文本；首屏预设、任务切换、用户编辑、清空和继续问都读取同一个 `aiCommandText`。
- 推荐指令按账本修订、会员和天气生成一个查/比/补共享快照，后台一次准备；SwiftUI `body` 与任务切换只读数组，不再扫描账本或执行生活线索聚合。
- 复盘首屏保留现有柔和主题、近 7 天数据和三个任务，只减少重复层级与高度，让分类快捷入口更早进入视野。
- 完整 Windows repository gate 通过；当前环境不能执行 Xcode、XCTest、Dynamic Type、VoiceOver 或完整 FLOW-22，未覆盖项继续保持 `NOT_RUN`。

### 真机补充反馈（2026-07-16）

- 用户在 iPhone 真机确认：AI 指令台整体“丝滑了不少”，连续使用后“没有掉帧感”，本轮核心性能目标达到预期。
- 结论归属：`PERF-07` 的“任务切换不在主线程扫描账本、三任务共享变化驱动快照”核心真机路径通过；证明主要瓶颈确为 SwiftUI 重绘路径中的同步聚合，而非账本结果本身。
- 状态保持 `CODE_DONE`：用户反馈足以补充真实交互性能证据，但尚未完成 1,000 条夹具、Core Animation hitch 数值、XCTest、Dynamic Type、VoiceOver 和完整 FLOW-22，因此不标记为 `VERIFIED`。
- `FIX-003` 的反复清空/关闭/重新打开默认输入矩阵，以及 `UI-01` 的多主题和大字视觉矩阵仍按 FLOW-22 统一补签收。

---

## 21. 全局“只在数据真正变化时重算”审计（计划 2026-07-17）

用户确认变化驱动重算对交互流畅度非常关键，要求下一工作日全局排查其他页面是否仍存在“视图重绘或普通 UI 状态变化触发账本扫描、聚合、排序、签名、图片解码或冷缓存”的同类问题。今天只登记任务，不开始代码审计或修改。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | PERF-AUDIT-01 | 全局变化驱动重算审计 | `VERIFIED` | 先只读审计并形成证据清单；不在审计时顺手改代码、拆页面或改变业务/UI |

### 审计范围

1. 首页、记录、痕迹、复盘、我的五个 Tab，以及回放、会员、OCR 和常用 Sheet。
2. SwiftUI `body`、计算属性、`ForEach` 输入和 ViewBuilder 中是否直接遍历、筛选、分组、排序或哈希完整账本。
3. `onAppear`、`onChange`、Sheet 打开、Tab 切换、主题/展开/键盘/焦点变化是否重复启动相同任务。
4. 缓存键是否包含与结果无关的 UI 状态，是否按页面或模式分裂导致第一次切换反复冷计算。
5. 图片解码、缩略图、日期格式化、生活线索和语义聚合是否严格由真实数据修订驱动，并在后台准备。
6. 旧请求取消、最新请求保护、页面离开和数据更新后是否可能重复发布或反写。

### 必须产出

- 按页面列出：计算入口、触发条件、主/后台线程、数据规模、当前缓存键、是否只随真实数据变化、风险等级和建议任务。
- 明确区分“确有主线程重算”“轻量 UI 重绘”“已有正确快照/缓存”三类，不凭文件体积或主观感觉下结论。
- 发现问题后按风险拆成独立任务，一次只允许一个 `IN_PROGRESS`；先修高频主线程路径，再做真机对照，不夹带 `ARCH-03` 页面拆分。
- 保护现有首页、痕迹、复盘和 AI 指令台已验证交互，不以全局抽象重写当前稳定方案。

### 当前状态

- `PERF-AUDIT-01` 于 2026-07-17 完成只读审计并标记为 `VERIFIED`，当前无 `IN_PROGRESS`。
- 工作区保护：继续保留 `StatCardView.swift`、`web-preview/app.js`、用户提示文档和 `scripts/__pycache__/`；本项只修改本文档，未修改生产代码。
- 下一步：按下方顺序从 `PERF-08` 开始定向修复；未收到继续执行指令前，全部保持 `NOT_STARTED`。

### 审计结论

这次没有发现“所有页面都在反复重算”。复盘和痕迹主章节已经采用正确的后台快照；真正与 AI 指令台旧问题同类的路径集中在记录页、首页和今日回放，其共同特征是：SwiftUI 普通状态变化会调用完整账本筛选或 `LifeMarkService.aggregates`，而该服务即使缓存命中也需要先过滤并为完整历史生成签名。

| 页面/路径 | 代码证据 | 当前触发方式 | 判断 | 风险 |
|---|---|---|---|---|
| 记录页输入辅助 | `RecordView.swift:779` 在预览 ViewBuilder 中用草稿和完整账本调用 `LifeMarkService.aggregates`；`HomeViewModel.swift:1346` 的 `refreshRecordPrefill()` 会筛选 180 天记录；`HomeViewModel.swift:1650` 还会再次筛选、分组和排序常用金额 | 金额每次变化立即执行；备注输入虽有 220ms 防抖，但焦点、日期和分类变化也会触发；页面重绘还会再次生成生活线索 | 确有主线程重复重算，和本轮 AI 指令台旧问题最相似 | `P0` |
| 首页主动作与通勤候选 | `HomeView.swift:567` 每次读取主动作时统计完整记录并再筛周/月；同一轮渲染在 `HomeView.swift:601` 再读取一次；`HomeViewModel+Dashboard.swift:41/155/344` 会扫描 120 天通勤习惯并分组排序 | 首页任意状态变化、宠物/提示层变化、焦点变化及每 60 秒计时器都会让相关计算重新进入 | 确有主线程重复重算；首页是最高频页面 | `P0` |
| 首页可见记录的生活线索 | `HomeView.swift:2073` 的 `homeLifeMarkText(for:)` 对每个可见记录单独调用 `LifeMarkService.aggregates`，最近三笔和“今天全部记录”都会使用 | 首页或今日记录 Sheet 的任意编辑、滑动、提示和动画状态重绘；可见 N 条时会重复生成 N 次完整历史签名 | 确有按行放大的主线程重算 | `P0` |
| 今日回放 | `HomeView.swift:2665` 每次读取都重新筛选/排序今天记录；`HomeView.swift:2671/3309` 的 `playbackMoments` 每次重建章节，并调用场景、分类和完整历史生活线索聚合 | `activeIndex` 播放推进、暂停、完成态和动效都会触发 body；同一轮 body 又多次读取 `todayItems`、`playbackMoments`、时长和进度 | 确有动画期间反复重算；内容应在 Sheet 打开时冻结成快照 | `P0` |
| 会员页长期档案 | `MemberPricingView.swift:207` 的 `lifetimeArchiveItemsSignature` 在 `.onChange` 值中遍历并哈希完整账本；`MemberPricingView.swift:921/990` 又在主线程筛选、统计并调用生活线索聚合 | 套餐选择、购买遮罩、登录续接、滚动相关状态等普通重绘都会先求完整签名；真正刷新也仍在主线程 | 确有主线程重算，但页面使用频率低于首页/记录 | `P1` |
| 我的页账号统计 | `SettingsView.swift:651/665` 的账号摘要每次读取都会筛完整账本、生成天/月/周集合并计算最长连续天数；账号详情 `SettingsView.swift:2916` 再读取一次 | 登录状态、输入焦点、设置开关、Sheet 和页面普通重绘 | 确有主线程重复统计 | `P1` |
| 痕迹“细查这一段”列表 | `StatsWebView.swift:207/236/240/5218` 分别重复计算筛选结果、ID、总额和按日分组排序；`StatsWebView.swift:5044` 还把计算后的 ID 数组作为 `.onChange` 值 | 展开日期面板、分类切换、行编辑、滑动删除和 Sheet 状态变化 | 主章节快照正确；仅细查列表仍存在同一筛选结果多次构建 | `P1` |
| 回放分享自定义背景 | `SummaryPlaybackSheet.swift:2007/3378` 在两个 ViewBuilder 中直接 `UIImage(data:)` | 切换分享样式、选项或其他分享 UI 状态时可能重复解码同一张已压缩图片 | 单图且已限制到 1600px，不是账本扫描；属于低优先级解码缓存问题 | `P2` |

### 已正确采用变化驱动的路径

- 复盘首页、AI 指令结果和推荐指令：不可变输入在后台计算，使用最新请求门；推荐指令按账本修订、会员和天气一次准备查/比/补三组，普通切换只读数组。
- 痕迹周/月章节与生活线索主板：当前范围优先、另一范围空闲预热，缓存和 `LatestRequestGate` 已阻止旧任务反写；筛选变化只刷新相关快照。
- `HomeViewModel` 的今天/本周/本月/本年记录：`ItemDerivedCache` 只在 `items.didSet` 或日期跨天时重建，是可复用的正确基线。
- 记忆照片：`MemoryAttachmentViews.swift` 使用 `.task(id:)`、后台降采样和图片缓存；列表 body 不直接解码原图。
- OCR 确认、本地备份、云端同步和保存：高成本工作由用户明确动作触发，不在普通 ViewBuilder 中循环执行；本地保存继续使用变化集。
- 周/月 `SummaryPlaybackSheet`：主体消费已经准备好的 `SummaryPlayback` 数据；除自定义分享背景外，没有重新扫描完整账本。

### 不列为当前修复的问题

- `InsightWebView` 和 `StatsWebView` 仍通过 `.onChange(of: homeViewModel.items)` 感知账本变化，但当前真机复盘已流畅，且高成本计算不在 body；先作为 Instruments 观察项，不为了统一形式立即改全局发布模型。
- 少量 `DateFormatter`、小数组 `filter/map`、单条 `firstIndex` 和用户明确点击后的筛选属于轻量或低频工作，不与完整账本主线程重算等同。
- 痕迹文件中仍有未被当前入口调用的旧辅助计算函数；本次不借性能审计清理死代码，避免与 `ARCH-03` 混改。

### 后续定向任务顺序

| 顺序 | ID | 任务 | 状态 | 允许范围 |
|---:|---|---|---|---|
| 1 | PERF-08 | 记录页输入辅助变化驱动快照 | `CODE_DONE` | 只处理预填、常用金额和预览生活线索的准备时机；保存字段、分类结论和输入 UI 不变 |
| 2 | PERF-09 | 首页旅程、通勤候选与可见线索快照 | `CODE_DONE` | 只把首页完整账本统计和按行生活线索收敛为账本修订/时间桶驱动；主动作、提示优先级和通勤规则不变 |
| 3 | PERF-10 | 今日回放不可变内容快照 | `CODE_DONE` | Sheet 打开时一次准备今天记录与章节；播放期间只推进索引；额度、文案和完成动作不变 |
| 4 | PERF-11 | 会员长期档案后台快照 | `CODE_DONE` | 移除 body 中完整账本签名和主线程聚合；套餐、登录续购与 StoreKit 不变 |
| 5 | PERF-12 | 我的页账号统计快照 | `CODE_DONE` | 只缓存记录数、周/月数和连续天数；设置、同步、会员展示语义不变 |
| 6 | PERF-13 | 痕迹细查列表筛选快照 | `CODE_DONE` | 让 ID、总额和按日分组共用一次筛选结果；主章节、筛选含义和编辑删除不变 |
| 7 | PERF-14 | 分享自定义背景解码缓存 | `CODE_DONE` | 只复用已选背景的解码图；分享样式、压缩、隐私和导出结果不变 |

### 执行记录

| 日期 | 任务 | 状态变化 | 修改文件 | 验证 | 结果/残留风险 | 下一项 |
|---|---|---|---|---|---|---|
| 2026-07-17 | PERF-AUDIT-01 全局变化驱动重算审计 | `NOT_STARTED` → `IN_PROGRESS` → `VERIFIED` | 本文档 | 完整复读台账；使用 `rg` 全量扫描五个 Tab、回放、会员、OCR、常用 Sheet 的账本访问、生命周期、图片解码、签名和任务门；逐条追踪到调用方和触发状态 | 确认 4 组 `P0`、3 组 `P1`、1 组 `P2`；同时确认复盘、痕迹主快照、图片按需加载和增量保存没有回退；本项未修改生产代码 | PERF-08 |
| 2026-07-17 | PERF-08 记录页输入辅助变化驱动快照 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 完整复读台账并复核脏工作区；锁定预填、常用金额与预览生活线索三条重复计算路径 | 只允许把计算移出普通 SwiftUI 重绘并改为草稿输入/账本修订驱动；保存字段、分类结论、输入 UI、文案和 `ARCH-03` 保持冻结 | PERF-08 |
| 2026-07-17 | PERF-08 记录页输入辅助变化驱动快照 | `IN_PROGRESS` → `CODE_DONE` | `HomeViewModel.swift`、`RecordView.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`experience_static_check.ps1`、本文档 | 常用金额按账本修订/有效日期上下文生成一次历史快照；预填和分类推荐按草稿键在后台生成；预览生活线索改为 `.task(id:)` 后台快照；三组确定性 XCTest、静态防回流和 FLOW-23 已接线；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 保存字段、分类优先级、预填文案、会员边界和录入 UI 未改；新草稿开始时旧预填立即失效，旧任务不能覆盖新草稿；Windows 无 Xcode/Swift，编译、XCTest、1,000 条输入/键盘/滚动 hitch、Dynamic Type、VoiceOver 与 Reduce Motion 仍待真机签收 | PERF-09 |
| 2026-07-17 | PERF-09 首页旅程、通勤候选与可见线索快照 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 复核首页主动作、120 天通勤习惯和可见记录逐行生活线索三条 P0 路径 | 只允许改为账本修订/必要时间桶驱动快照；首页主动作优先级、提示预算、通勤规则、记录行 UI 和 `ARCH-03` 保持冻结 | PERF-09 |
| 2026-07-17 | PERF-09 首页旅程、通勤候选与可见线索快照 | `IN_PROGRESS` → `CODE_DONE` | `HomeViewModel.swift`、`HomeViewModel+Dashboard.swift`、`HomeView.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`experience_static_check.ps1`、本文档 | 首页旅程计数并入现有日期派生缓存；今天记录的生活线索按账本修订/日期/会员后台生成字典；通勤建议按账本修订和分钟桶基于不可变输入后台生成并用最新请求门发布；四组确定性 XCTest、静态防回流和 FLOW-24 已接线；修正专项检查中的 `+` 文件路径；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 主动作优先级、提示预算、通勤时段/金额/标题/重复阻止、一键保存和记录行 UI 未改；普通重绘、宠物/弹层状态和滚动只读快照；Windows 无 Xcode/Swift，编译、Sendable/actor 警告、1,000 条首页滚动/计时器 hitch、Dynamic Type、VoiceOver 与真实时间边界仍待真机签收 | PERF-10 |
| 2026-07-17 | PERF-10 今日回放不可变内容快照 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 定位 `TodayPlaybackSheet` 在播放索引、暂停、完成和动效重绘时重复筛选/排序今天记录并重建全部章节 | 只允许在 Sheet 输入变化时准备不可变记录与章节快照；额度扣次、章节文案、播放节奏、会员提示和完成动作保持冻结 | PERF-10 |
| 2026-07-17 | PERF-10 今日回放不可变内容快照 | `IN_PROGRESS` → `CODE_DONE` | `HomeView.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`experience_static_check.ps1`、本文档 | 打开今日回放前按当前账本修订一次生成当天记录、章节、顺序和总时长；Sheet 的记录/章节 getter 只读快照，播放索引、暂停、胶片、重播和完成动效不再筛选或聚合账本；确定性/密集日 XCTest、静态防回流和 FLOW-25 已接线；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 原 0/普通/密集记录章节文案、时间顺序、LifeMark/场景输入、额度扣次、会员提示、完成度结算和关闭动作未改；跨午夜或播放中账本变化不会污染本次内容，下次打开读取新快照；Windows 无 Xcode/Swift，编译、XCTest 与 1,000 条播放 hitch 仍待真机签收 | PERF-11 |
| 2026-07-17 | PERF-11 会员长期档案后台快照 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 定位会员页 `.onChange` 值每次重绘遍历完整账本生成签名，长期档案刷新又在主线程筛选、统计和生成生活线索 | 只允许改为账本修订驱动的不可变后台快照；套餐选择、登录续购、购买/恢复、Product ID、价格和 StoreKit 保持冻结 | PERF-11 |
| 2026-07-17 | PERF-11 会员长期档案后台快照 | `IN_PROGRESS` → `CODE_DONE` | `MemberPricingView.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`experience_static_check.ps1`、本文档 | 移除重绘时完整账本 `Hasher` 签名；会员证明与长期档案共用账本修订驱动的不可变输入，在 utility 任务中一次完成筛选、连续天/周/月统计和生活线索聚合，最新请求门阻止旧修订反写；两组确定性 XCTest、静态防回流和 FLOW-26 已接线；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 原草稿排除、连续记录、月份跨度、生活线索和全部档案文案保持；套餐切换、登录续购、Product ID、价格、购买/恢复、交易验证与 StoreKit 未改；Windows 无 Xcode/Swift，编译、XCTest、1,000 条套餐切换/滚动 hitch 与沙盒购买矩阵仍待真机签收 | PERF-12 |
| 2026-07-17 | PERF-12 我的页账号统计快照 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 定位设置首页账号摘要和账号详情在登录状态、输入焦点、开关与 Sheet 重绘时分别重复筛选完整账本、生成周/月集合和最长连续天数 | 只允许按账本修订缓存记录数、周/月数和连续天数并复用；设置、同步、会员展示、登录与危险操作语义保持冻结 | PERF-12 |
| 2026-07-17 | PERF-12 我的页账号统计快照 | `IN_PROGRESS` → `CODE_DONE` | `SettingsView.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`experience_static_check.ps1`、本文档 | 设置首页账号摘要与账号详情改为复用账本修订驱动的后台统计快照；有效记录筛选、日期集合、最长连续天、周记素材和月份数只计算一次，旧请求不能覆盖新修订；两组确定性 XCTest、静态防回流和 FLOW-27 已接线；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 原零金额排除、记录数、最长连续天、周/月数量与所有账号文案未改；设置、同步、会员展示、登录、备份和清空/删除危险操作语义保持；Windows 无 Xcode/Swift，编译、XCTest 与 1,000 条“我的”滚动/输入/Sheet hitch 仍待真机签收 | PERF-13 |
| 2026-07-17 | PERF-13 痕迹细查列表筛选快照 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 定位细查列表的匹配记录、ID、总额和按日分组由多个计算属性及 `.onChange` 值重复构建，同一筛选在编辑/删除/Sheet/滚动重绘时多次执行 | 只允许让细查列表派生值共用一次筛选快照；痕迹主章节、筛选含义、编辑删除、滚动和路由保持冻结 | PERF-13 |
| 2026-07-17 | PERF-13 痕迹细查列表筛选快照 | `IN_PROGRESS` → `CODE_DONE` | `StatsWebView.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`experience_static_check.ps1`、本文档 | 新增账本修订/时间/分类键驱动的细查快照；自定义范围或周/月/年基础记录只筛选一次，同时生成匹配记录、ID、正金额合计和日期倒序分组；列表、元信息和编辑态共用结果；两组确定性 XCTest、静态防回流和 FLOW-28 已接线；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 原记录数量、零金额显示、金额合计、日期/同日排序、空态与筛选含义未改；编辑删除、筛选外关闭编辑态、痕迹主章节/缓存/额度/手势/路由保持；Windows 无 Xcode/Swift，编译、XCTest 与 1,000 条筛选/滚动 hitch 仍待真机签收 | PERF-14 |
| 2026-07-17 | PERF-14 分享自定义背景解码缓存 | `NOT_STARTED` → `IN_PROGRESS` | 本文档 | 定位周/月回放分享编辑器的两个 ViewBuilder 直接对同一份已压缩背景 `UIImage(data:)`，分享样式和选项重绘可能重复解码 | 只允许缓存当前选择背景的解码图并按数据变化失效；分享样式、压缩、隐私、导出内容和其他图片路径保持冻结 | PERF-14 |
| 2026-07-17 | PERF-14 分享自定义背景解码缓存 | `IN_PROGRESS` → `CODE_DONE` | `SummaryPlaybackSheet.swift`、`StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`experience_static_check.ps1`、本文档 | 选择背景时一次完成 1600px/JPEG 规范化并产出 Data 与已解码 UIImage；选择器预览、最终分享卡和保存快照共用同一图片，移除时同步清空；两组 UIKit XCTest、静态防回流和 FLOW-29 已接线；`python scripts/validate_release_gate.py --phase windows` 完整通过 | 原尺寸上限、JPEG 质量、相册选择/权限、隐私确认、样式、保存提示和导出视觉来源保持；`UIImage(data:)` 只保留在用户选择后的规范化动作中，不在 ViewBuilder；Windows 无 Xcode/iPhone，编译、XCTest、12MP 内存/切换 hitch 与相册保存仍待真机签收 | 统一 Xcode/真机签收 |

### PERF-08 收口结论

- 空金额状态的常用金额不再由 `RecordView.body` 重复筛选、分组和排序；相同账本修订与有效日期上下文只读取同一份已发布快照，普通重绘、展开和焦点变化不会重新扫描账本。
- 预填标题、自动分类和分类网格推荐继续使用原优先级与 180/90 天口径，但计算基于不可变历史输入在后台完成；金额、备注、日期或账本修订变化才生成新草稿请求，相同请求直接复用。
- 预览生活线索的 ViewBuilder 不再调用 `LifeMarkService.aggregates` 或拼接完整账本；只在草稿、会员或账本修订键变化时后台准备，失焦/回焦和普通卡片重绘复用已完成结果。
- 新请求开始会清除不匹配的旧预填和分类提示，保存路径额外核对预填金额，避免快速修改金额后误用上一草稿标题；用户锁定分类、场景包和显式备注边界保持原样。
- 完整 Windows repository gate 通过；`FLOW-23`、Xcode Debug/Release、XCTest 和 iPhone Instruments 尚未执行，因此状态为 `CODE_DONE`，不标记 `VERIFIED`。

### PERF-09 收口结论

- 首页主动作不再在 SwiftUI 重绘时重新遍历全部账本；总记录、本周和本月成熟度计数与今天/周/月缓存一起只在账本修订或跨日时重建。
- 首页最近记录和“今天全部记录”的生活线索只读取 `item.id` 对应的已发布文本；完整历史聚合在账本修订、日期或会员状态变化时于后台准备，普通滚动、编辑态和提示层变化不会按行重算。
- 通勤建议保留原工作日、早间/午间补记/晚间、120 天习惯、稳定金额、标题、置信度、今日重复阻止和一键保存规则；首页每分钟只触发一次后台快照请求，相同分钟内的普通重绘直接复用结果，旧账本或旧时间桶不能反写。
- `HomeView` 的当前 UI、主动作优先级、提示预算、宠物与保存后承接均未调整；`ARCH-03` 继续保持 `NOT_STARTED`。
- 完整 Windows repository gate 通过；`FLOW-24`、Xcode Debug/Release、XCTest、Swift 并发诊断与 iPhone 1,000 条/真实时间边界尚未执行，因此状态为 `CODE_DONE`，不标记 `VERIFIED`。

### PERF-10 收口结论

- 今日回放在展示 Sheet 前按当前账本修订和当天日期生成一份不可变内容快照，包含按时间排序的当天记录、普通/密集日章节和完整播放时长。
- `BillPlaybackSheet` 的 `body`、当前章节、进度、胶片和播放任务只读取快照；播放索引、暂停、完成态、主题/宠物等普通状态变化不会重新筛选、排序或调用 `LifeMarkService.aggregates`。
- 关闭时仍用本次冻结记录计算完成度；播放期间新增或同步进来的记录不改变正在播放的章节，只在下一次打开时进入新快照，避免中途跳章和签名漂移。
- 今日回放的额度仍只在用户明确开始时扣除；0 笔空态、章节文案、时长公式、会员提示、完成动作和 UI 视觉均保持原样，`ARCH-03` 继续保持 `NOT_STARTED`。
- 完整 Windows repository gate 通过；`FLOW-25`、Xcode Debug/Release、XCTest 与 iPhone 1,000 条连续播放/胶片滑动 Instruments 尚未执行，因此状态为 `CODE_DONE`，不标记 `VERIFIED`。

### PERF-11 收口结论

- 会员页不再把完整账本内容哈希成 `.onChange` 值；刷新触发改为复用 `HomeViewModel` 的账本修订号，套餐选择、购买遮罩、登录续购和滚动不会先遍历账本。
- 顶部会员证明与“永久会员专属”长期档案共用一份后台快照，筛选有效记录、连续天数、周/月跨度和 `LifeMarkService` 聚合只在账本修订变化时执行一次。
- 新修订会取消旧任务并通过请求 ID 保护发布；刷新期间保留上一份档案，旧结果不能覆盖新账本，页面离开后任务会取消并允许重新进入时安全准备。
- 草稿排除、记录数、连续天、月份/周记素材、生活线索和全部用户文案未变；套餐、登录续购、价格、Product ID、购买/恢复、交易验证与 StoreKit 路径完全冻结，`ARCH-03` 继续保持 `NOT_STARTED`。
- 完整 Windows repository gate 通过；`FLOW-26`、Xcode Debug/Release、XCTest、1,000 条会员页滚动/套餐切换和 StoreKit 沙盒尚未执行，因此状态为 `CODE_DONE`，不标记 `VERIFIED`。

### PERF-12 收口结论

- “我的”首页账号摘要与账号 Sheet 的记忆卡不再各自筛选完整账本；两处共用一份按账本修订生成的 `AccountMemoryStats`。
- 有效记录筛选、日期集合、最长连续天、周记素材数和月份数在 utility 任务中一次完成；昵称输入、登录状态、同步/联网/宠物开关和 Sheet 开关只读取快照。
- 新修订取消旧任务并通过请求 ID 保护发布；页面离开会取消准备，重新进入可安全恢复，旧统计不会覆盖新增、编辑或删除后的结果。
- 零金额排除、统计口径、账号/会员文案、设置与同步行为、登录流程、备份和清空/删除危险操作全部保持，`ARCH-03` 继续保持 `NOT_STARTED`。
- 完整 Windows repository gate 通过；`FLOW-27`、Xcode Debug/Release、XCTest 与 iPhone 1,000 条“我的”滚动/输入/Sheet Instruments 尚未执行，因此状态为 `CODE_DONE`，不标记 `VERIFIED`。

### PERF-13 收口结论

- 痕迹“细查这一段”现在按账本修订、周/月/年或自定义日期和分类组成快照键；同一组合只执行一次匹配与排序。
- 匹配记录、记录 ID、正金额合计和按日分组从同一快照发布，元信息、列表和行内编辑态不再分别调用 `filteredItems`、`map`、`reduce` 与 `Dictionary(grouping:)`。
- 自定义范围继续按起止日闭区间语义转换为 `DateInterval`；周/月/年继续复用原派生记录，分类、零金额显示、日期倒序和同日时间倒序结果保持。
- 编辑、删除、筛选外关闭编辑态、痕迹主章节与预热、额度、照片横滑、路由和当前 UI 均未调整，`ARCH-03` 继续保持 `NOT_STARTED`。
- 完整 Windows repository gate 通过；`FLOW-28`、Xcode Debug/Release、XCTest 与 iPhone 1,000 条长列表筛选/滚动 Instruments 尚未执行，因此状态为 `CODE_DONE`，不标记 `VERIFIED`。

### PERF-14 收口结论

- 自定义分享背景在用户选图后一次完成原有 1600px 上限与 0.84 JPEG 规范化，同时保存规范化 Data 和由该 Data 解码出的 `UIImage`。
- 分享选择器预览、周/月分享卡预览与最终保存快照共用这一个已解码图片；样式切换、选择器展开、滚动和其他重绘不再在 ViewBuilder 中执行 `UIImage(data:)`。
- 移除背景会同时清空 PhotosPicker 项、Data 和 Image；重新选择只使用新图，选择失败继续保留原背景，行为与改前一致。
- 相册权限、隐私确认、分享样式、压缩规则、保存提示、导出结果来源和其他照片路径均未调整，`ARCH-03` 继续保持 `NOT_STARTED`。
- 完整 Windows repository gate 通过；`FLOW-29`、Xcode Debug/Release、UIKit XCTest 与 iPhone 12MP 连续样式切换/内存/相册保存尚未执行，因此状态为 `CODE_DONE`，不标记 `VERIFIED`。

### 本轮变化驱动重算收口结论

- `PERF-08`～`PERF-14` 已全部达到 `CODE_DONE`，当前无 `IN_PROGRESS`；记录、首页、今日回放、会员、我的、痕迹细查和分享背景的高成本路径均已改为真实数据修订或明确用户动作驱动。
- 完整 Windows repository gate 在每项收口后均通过；新增 `FLOW-23`～`FLOW-29` 统一留给 macOS/Xcode、XCTest、iPhone Instruments、StoreKit、权限和无障碍矩阵补签收。
- `ARCH-03` 页面拆分仍为 `NOT_STARTED`，本轮没有改变首页、痕迹、复盘现有 UI 风格、产品职责、主题 Token、路由、额度、存储、购买或同步规则。

### 2026-07-17 上午恢复执行记录

- 任务归属：继续执行 `RELEASE-02` 统一签收的当前环境部分；状态保持 `BLOCKED`，未新建或启动其他任务，当前仍无 `IN_PROGRESS`。
- 范围与文件：完整复读本文档并复核脏工作区；本次未修改生产代码、测试代码、主题、产品逻辑或真机矩阵，仅回填本文档的最新验证证据。
- 验证证据：`python scripts/validate_release_gate.py --phase windows` 再次完整通过；100/1,000/5,000 条夹具摘要稳定，3 张 12MP JPEG 的尺寸、字节数与 SHA 校验通过，生活语义、交互静态、术语、会员、AI、无障碍、可观测性、迁移样本和 SQLite schema 全部通过；文案仍只有既有 7 条 soft warning，没有新增错误。
- 环境确认：Windows 10 当前仍无 `xcodebuild`、`swift`、`xcrun`、`simctl` 和 `instruments`，因此不能补签 Debug/Release、全部 XCTest、Swift concurrency/actor/Sendable、iPhone Instruments、StoreKit、权限与无障碍证据。
- 剩余风险：`PERF-08`～`PERF-14` 继续保持 `CODE_DONE`，不得标记为 `VERIFIED`；`ARCH-03` 继续保持 `NOT_STARTED`，不能在最新基线完成 Xcode 与核心真机签收前启动。
- 下一项：在 macOS/Xcode 与 iPhone 环境按 `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 执行统一签收；只修复签收暴露的具体编译、并发或真机回归，不扩张范围。

---

## 22. AI 查询指标、周记/月章活人感文案与首页宠物帧动画方案（2026-07-17）

用户根据 TestFlight 真机截图新增三项产品反馈：

1. AI 指令台已经明确查询单一分类时，结果总览仍显示“金额最高：该分类”和“该类金额”，信息重复且语义容易被理解为最高单笔。
2. 周记与月章播放文案存在模板拼接、抽象比喻、标签复述和主文/辅助文重复，不像认真看过记录的人在自然说话；目标不是强行煽情，而是增加具体、克制、可信的“活人感”。
3. 首页宠物当前直接渲染猫 emoji，缺少独立产品形象和动作反馈；用户要求改为帧动画方案，不再使用 emoji。

本节属于用户明确新增的产品范围。本次只完成问题归因、方案、任务顺序、冻结边界和验收设计；不修改任何生产代码、测试代码、资源、UI 或业务状态。三项任务全部保持 `NOT_STARTED`，当前仍无 `IN_PROGRESS`。

### 新增任务顺序

| 顺序 | ID | 任务 | 状态 | 进入边界 |
|---:|---|---|---|---|
| 1 | PET-01 | 首页宠物透明帧动画替换 emoji | `CODE_DONE` | 独立像素帧组件、正式资源、首页替换、策略测试与 FLOW-30 已完成；等待 Xcode/iPhone 签收 |
| 2 | LOGIC-14 | AI 查询总览按显式查询范围切换指标 | `CODE_DONE` | 显式单分类与跨分类指标已分流；测试、静态门禁和 FLOW-31 完成，等待 Xcode/iPhone 签收 |
| 3 | COPY-02 | 周记/月章播放文案活人感收敛 | `CODE_DONE` | v2 事实证据、周/月职责、同期比较、主辅去重、测试与门禁完成；等待 Xcode/XCTest 和 iPhone FLOW-42 签收 |

用户于 2026-07-17 在三组像素帧与透明拆帧完成后明确调整执行顺序：先完成 `PET-01`，再修复 `LOGIC-14`，最后处理 `COPY-02`；其中 `COPY-02` 必须先给方案确认，不能根据已有方向直接改文案代码。该顺序覆盖本节首次建档时的原顺序。`ARCH-03` 继续保持 `NOT_STARTED`；三项仍须一次只启动一项，前一项完成代码、边界复核和当前环境回归后才能进入下一项。

### LOGIC-14：AI 查询总览按显式查询范围切换指标

#### 当前问题与原因

- AI 指令已识别“餐饮”等明确分类，并先把记录集合筛成单一分类。
- 通用查询总览随后又对筛选结果计算“金额最高分类”；单分类结果必然再次得到“餐饮”。
- “该类金额”与总金额相同；“金额最高”标题还可能被误解为最高单笔，而实际值是分类名称。
- 数据筛选、2 笔记录、总额和最高单笔均正确，问题仅在查询范围没有传递到总览指标选择层。

#### 方案

1. 查询结果显式携带识别阶段的分类范围，不根据“结果碰巧只有一个分类”猜测查询类型。
2. 明确单分类查询的三项指标改为：
   - 有记录：活跃天数。
   - 平均每笔：分类总金额 / 有效记录数。
   - 最高单笔：当前结果中最高一笔的金额。
3. 未指定分类、跨分类或用户明确询问“哪类最多/分类构成”时，继续展示：
   - 有记录：活跃天数。
   - 最高分类：金额最高的分类。
   - 该类金额：最高分类的金额。
4. 0 笔时平均值和最高单笔显示明确空态；1 笔时平均每笔与最高单笔允许相同，但标题必须准确。
5. “金额最高的是某条记录”的正文仍表示最高单笔；指标标题不得再把最高分类和最高单笔混用。

#### 计划修改范围

- `NativeDemoApp/Views/InsightWebView.swift`
- 必要时扩展 `AICommandResult` 的只读查询范围字段；不修改识别器的分类结论。
- `NativeDemoAppTests/StateRegressionTests.swift`
- 对应体验静态门禁、真机矩阵和本文档。

#### 冻结边界

- 不改变自然语言识别、分类槽位、时间范围、筛选记录、金额合计、排序和证据列表。
- 查询与对比继续只读；不触碰补记确认、额度、会员、保存、存储和同步。
- 不调整 AI 指令台现有主题 Token、卡片层级、圆角、间距、动画和其他任务结果。

#### 验收

- “最近 7 天餐饮记录”不再出现“金额最高：餐饮/该类金额”等同义重复。
- “最近 7 天记录”仍能正确显示最高分类及其金额。
- 未指定分类但结果碰巧只有一类时，仍按“未指定分类”的口径展示，证明判断来自查询范围而非结果猜测。
- 0、1、多笔记录及 Dynamic Type、VoiceOver 下标题和数值语义正确。

### COPY-02：周记/月章播放文案活人感收敛

#### 当前问题与原因

- 文案池存在“前十天不用讲得很满”“今天回到家的路也有了位置”“这个月的气味藏在……里”“这次它又回来了”等抽象模板，语言像系统在努力写散文，不像自然回顾。
- “公共交通一段”“咖啡饮品第 30 次”“热天路上辛苦了”等内部标签或自动语义被直接拼入句子，产生机器味和不必要的情绪判断。
- 主标题、正文、辅助说明和标签可能复述同一句事实，例如正文已经说晚间通勤，辅助说明再次原样重复。
- 周记与月章共用相似句式和比喻，只是替换时间、标题和标签，缺少周度“近、具体”和月度“回望、取舍”的差异。

#### “活人感”定义

活人感不等于每章都煽情，也不等于增加更多形容词。目标是：像一个认真看过记录、知道什么时候该多说一句、什么时候只把事实讲清楚的人。

1. **事实先行**：先说哪天、什么记录、什么变化，不用抽象概念代替事实。
2. **只做一层观察**：从事实中挑一个最值得说的关系，不把分类、场景、情绪和次数全部堆进一句话。
3. **情绪可选**：只有用户明确备注、照片说明、用户确认的情绪，或时间/天气等强事实足够支持时，才增加克制回应；自动情绪标签不能单独证明用户感受。
4. **说完就收住**：不强行升华、不总结人生、不把每笔账都写成故事。
5. **证据可回看**：任何具体说法都能回到日期、记录、照片或真实同期变化；不虚构原因、关系和动机。

#### 周记与月章的不同说法

| 范围 | 叙述重点 | 建议长度 | 语气 |
|---|---|---:|---|
| 周记 | 一两个具体日子、最近出现的节奏、最值得记住的一笔 | 1～2 句 | 近、直接、像刚发生过 |
| 月章 | 一条主线、一次真实变化、少量有代表性的记忆 | 2～3 句 | 有回望感，但不堆标签、不写空泛散文 |

#### 文案生成方案

1. 为每章先选择一个叙述角色：`事实`、`具体记忆`、`节奏变化`、`克制回应`，一章只承担一个主要角色。
2. 生成顺序固定为“事实锚点 → 一层观察 → 可选回应”，证据不足时只输出事实锚点。
3. 周记优先使用具体日期、记录标题和一周内的节奏；月章优先选择一个月内最有代表性的记忆或与上月有证据的变化。
4. 内部分类名、场景名、次数标签和情绪标签必须先转成自然表达；无法自然表达时宁可不说。
5. 主文与辅助说明分工：主文负责自然叙述，辅助说明只提供日期、金额或证据，不允许换个前缀重复主文。
6. 章节标题允许在不改变章节数量和顺序的前提下收敛，例如评审“月初的一句”“变化点”“常冒头的词”是否需要更自然的当前语境名称。
7. 建立确定性文案夹具，覆盖空数据、弱数据、密集记录、重复通勤、照片、显式备注、自动情绪标签、跨月变化和无变化。
8. 新增文案防回流规则，拦截空泛升华、内部标签直出、主辅文重复和无证据情绪判断；不依赖远程 AI 才能得到自然结果。

#### 语气示例（方向示意，非最终上线文案）

- 原：“前十天不用讲得很满，记住「下班地铁」就有画面。”
- 方向：“7 月 4 日，你记下了一趟下班地铁。月初最先留下来的，是这段回家路。”
- 原：“晚上一点多的通勤记下来了，今天回到家的路也有了位置。”
- 方向：“这个月有一趟很晚的下班路。上个月也出现过一笔相似记录。”
- 原：“7 月的气味，藏在早晚路上、公共交通一段、晚高峰通勤、咖啡续航……”
- 方向：“这个月反复出现的是通勤和咖啡：早晚路上记了几次，咖啡也常常跟着出现。”

#### 计划修改范围

- `NativeDemoApp/Services/PlaybackCopyPool.swift`
- `NativeDemoApp/Services/PlaybackService.swift`
- `NativeDemoApp/Views/SummaryPlaybackSheet.swift` 中只与主文/辅助证据文案有关的部分。
- 文案夹具、页面 copy snapshot、文案 lint、XCTest、真机矩阵和本文档。

#### 冻结边界

- 不改变周记/月章的记录筛选、章节事实来源、章节数量、章节顺序、照片选择、回放时长规则和完成动作。
- 不改变免费额度、扣次、会员、保存、分享、主题和播放控制 UI。
- 不把本地模板包装成远程 AI，不生成账本里没有的人物、地点、原因、关系和感受。
- 不借文案优化重新设计月章卡片、照片区或播放控制器。

#### 验收

- 同一章主文与辅助证据不再复述同一句话。
- 弱数据只说事实，不硬写情绪；有明确备注或强上下文时才出现克制回应。
- 周记读起来像近况，月章读起来像回望，两者不只是替换“本周/本月”。
- 逐条人工评审文案夹具：事实准确、自然程度、情绪分寸、重复度和证据可追溯均通过。
- 小屏、大字和 VoiceOver 下文案长度可读；不因换文案破坏 6 章播放和进度状态。

### PET-01：首页宠物透明帧动画替换 emoji

#### 当前问题与原因

- 首页 `todayPetStamp` 当前直接使用 `Text("🐱")`，展示依赖系统 emoji 字形，不是产品自有视觉资产。
- emoji 在不同系统版本可能存在视觉差异，无法表达待机、点击、说话等状态，也无法建立稳定的产品角色。
- 仓库当前没有宠物帧序列或 sprite 资源；消息生成与提示优先级已经存在，本项只替换视觉和动作承载。

#### 推荐技术方案

采用**透明 PNG 帧序列 + 明确动画状态清单**，不使用 emoji、GIF 或持续 60fps 动画。

1. 首期只做一个宠物角色，不同时扩张宠物选择系统。
2. 最小状态集：
   - `idle`：低频待机循环，轻微呼吸/眨眼。
   - `react`：用户点击后的单次回应动作。
   - `speak`：气泡出现期间的短循环动作。
3. 建议规格：画布约 192×192 透明像素；待机 8～12 帧、6～8fps；回应 10～16 帧、8～10fps；说话循环控制在 8～12 帧。
4. 每次只加载当前状态需要的帧；切换状态时取消旧计时，不让三个序列同时常驻。
5. 动画视图独立于首页主体状态，帧推进不得让首页账本、卡片和提示层重新计算。
6. App 进入后台、首页不可见或宠物被关闭时立即暂停；回到前台从稳定帧恢复，不追赶丢失帧。
7. Reduce Motion 下使用对应状态的静态首帧；低电量模式允许降低帧率或停在静态待机帧。
8. 资源缺失时显示产品宠物静态首帧或隐藏，不回退系统 emoji。

#### 视觉与交互边界

- 宠物本体使用统一原创或已获得商用授权的帧资产，不随主题整体染色；承载底板、描边和气泡继续使用现有主题 Token。
- 保留当前 52pt 左右的点击热区，实际触控面积不低于 44pt；不得因为透明帧缩小可点区域。
- 点击仍调用现有 `PetCompanionService.petClickMessage`；保存后消息仍沿用现有 `petMessage`，不重写文案服务。
- 宠物继续服从现有提示优先级：第一笔、照片、奖励、会员和其他强提示出现时让位，不覆盖首页主动作。
- VoiceOver 使用“宠物助手，点按听一句”等稳定标签，不逐帧朗读；装饰帧对辅助功能隐藏。
- 31 套主题及 light/dark 下检查边缘、底板、气泡和对比度；不为宠物修改全局主题体系。

#### 性能与资源预算

- 活跃序列解码内存目标不超过约 4MB；首期全部宠物资源包目标控制在约 1.5MB 内，最终以真实资产测量为准。
- 冷启动不预加载全部动作；首页首次需要宠物时只准备待机帧，点击前不加载回应序列。
- 用 Instruments 验证 60 秒待机、连续点击、气泡出现/消失和切 Tab：无持续主线程 hitch、无帧资源累积、无首页普通状态重算。

#### 资产前置条件

- 开始生产代码前必须先确定角色外观、帧数、动作分镜、透明边缘、授权归属和 1x/2x/3x 导出规范。
- 本次没有生成、下载或加入任何宠物图片；后续资产制作需单独确认，不能用临时 emoji 或来源不明素材占位后直接进入发布包。

#### 计划修改范围

- 新增独立宠物帧动画 View/状态模型文件。
- `NativeDemoApp/Views/HomeView.swift` 仅替换 `todayPetStamp` 的宠物图像承载，不调整首页其他结构。
- `NativeDemoApp/Assets.xcassets` 中的宠物帧资源与清单。
- 必要的状态 XCTest、资源静态检查、性能真机矩阵和本文档。

#### 冻结边界

- 不改变宠物开关、消息内容、天气联动、保存后提示预算、首页主动作、路由和账本逻辑。
- 不加入联网下载动画、第三方动画 SDK、视频循环或不可控 GIF 解码。
- 不借宠物动画调整首页卡片、颜色、布局、主题、会员或其他页面。

#### 验收

- 首页不再出现系统猫 emoji；待机、点击、说话三种状态切换自然且可恢复。
- 动画隐藏、切 Tab、进后台、Reduce Motion 和低电量路径没有持续计时或资源泄漏。
- 连续点击不会重叠创建多个动画任务或多个消息气泡。
- 多主题、Dynamic Type、VoiceOver 和 60 秒真机性能矩阵通过后，才允许标记为 `VERIFIED`。

### 本节建档结果

- `LOGIC-14`、`COPY-02`、`PET-01` 均为 `NOT_STARTED`，当前无 `IN_PROGRESS`。
- 本次只修改本文档；没有修改生产代码、测试、资源、UI、文案池或业务规则。
- 新任务不视为 `RELEASE-02` 已解除阻塞，也不授权启动 `ARCH-03`。
- 后续开始执行时，第一项为 `LOGIC-14`；每项都必须单独记录修改文件、验证证据、剩余风险和下一项。

### PET-01 资产概念确认记录（2026-07-17）

- 状态：`PET-01` 仍为 `NOT_STARTED`；本次仅完成用户单独确认的角色概念图，不启动生产代码、帧资源接入或相邻路线任务，也不新增 `IN_PROGRESS`。
- 范围：同一只原创暖奶油色猫，炭灰耳朵与尾巴、低饱和薄荷绿项圈；2×2 分镜覆盖平静待机、轻柔眨眼/呼吸、抬起一只前爪的点击回应、轻微张嘴的说话回应。
- 文件：`brand-assets/source/pet-concepts/bookkeeping-cat-four-pose-concept-v1.png`，仅作为后续逐帧设计源稿，不加入 `NativeDemoApp/Assets.xcassets` 或发布包。
- 验证证据：1254×1254 PNG；SHA-256 `D3C74554F5F0E7CCBE00ACC6D906454133F258F1F0A70F111C9EC7FCEF446772`；人工检查四格角色外观、比例、视角、配色一致，完整身体可见，无文字、标签、气泡、UI、Logo 或水印。
- 冻结边界：未修改生产代码、测试、宠物开关、消息、天气、提示优先级、首页结构、主题、会员、路由或账本逻辑。
- 剩余风险：该图是暖白背景概念稿而非透明逐帧交付物；52pt 实机可读性、透明边缘、动作补间帧、1x/2x/3x 导出、资源体积与商用发布归属声明仍需在 `PET-01` 正式启动后单独验收。
- 下一任务：仍按既定顺序执行 `LOGIC-14`；不得因本概念图提前启动 `PET-01` 代码或资源接入。

### PET-01 像素关键帧预览确认记录（2026-07-17）

- 状态：`PET-01` 仍为 `NOT_STARTED`；本次仅新增用户确认的像素风四关键帧预览，不启动动画 View、状态模型、资源清单或首页接入。
- 范围：同一只暖奶油色原创猫，深灰耳朵和尾巴、低饱和薄荷绿项圈；2×2 覆盖睁眼待机、闭眼呼吸、抬起前爪点击回应、轻微张嘴说话回应。
- 文件：`brand-assets/source/pet-concepts/bookkeeping-cat-pixel-four-keyframes-v1.png`，768×768 PNG；按 192×192 主网格设计并以 4 倍最近邻放大，对应每格约 96×96 像素。
- 验证证据：固定 12 色；纯色暖米白边缘连通背景；所有输出像素按 4×4 同色块放大，无抗锯齿或渐变；SHA-256 `4535E435FF7F5768C05A74FDE44C13D655B21EB391A4DBE7660D69B94009A52C`；人工检查四格角色比例、视角、基线、尾巴方向与身份一致。
- 冻结边界：未修改 `NativeDemoApp/Assets.xcassets`、生产代码、测试、首页结构、宠物消息、提示优先级、主题、会员、路由或账本逻辑。
- 剩余风险：该文件仍是带背景的预览稿，不是透明逐帧发布资源；动作补间、逐帧轮廓一致性、52pt 真机辨识、透明边缘、1x/2x/3x 导出、资源预算和授权声明仍需在 `PET-01` 正式启动后验收。
- 下一任务：继续按台账顺序执行 `LOGIC-14`，不因像素预览完成而提前接入 `PET-01`。

### PET-01 待机 8 帧精灵表生产候选记录（2026-07-17）

- 状态：`PET-01` 仍为 `NOT_STARTED`；本次只制作用户明确要求的独立待机精灵表候选，不启动动画代码、资源目录接入、首页替换或其他动作序列。
- 角色来源：仅使用 `brand-assets/source/pet-concepts/bookkeeping-cat-pixel-four-keyframes-v1.png` 左上待机帧作为像素母版；未采用生成模型重绘结果，避免脸型、比例、配色和尾巴漂移。
- 文件：`brand-assets/source/pet-sprites/bookkeeping-cat-idle-8f-magenta-v1.png`，384×192 RGB PNG，4 列×2 行，每格严格 96×96 像素。
- 动作：8 帧依次为睁眼、胸口局部吸气、半闭眼、闭眼、半开眼、尾尖移动、尾尖回落、首帧复原；除指定局部外均复制同一母版。
- 验证证据：所有帧非背景包围盒均为 `(25,14)–(82,87)`，脚底基线均为 `y=87`；第 1 与第 8 帧逐像素一致；帧 2～7 相对首帧仅变化 9/16/20/16/6/1 个像素；角色使用参考帧颜色子集，背景唯一颜色为 `#FF00FF`；SHA-256 `8767906CC4BF9A3194269FF298F257E4DF5074AD46F38A7799285FFFF80C5D43`。
- 冻结边界：未修改 `NativeDemoApp/Assets.xcassets`、生产代码、测试、首页、宠物消息、提示优先级、主题、会员、路由或账本逻辑；未制作点击或说话序列。
- 剩余风险：该文件是洋红抠图生产候选，尚未执行透明背景移除、逐帧 alpha 边缘检查、1x/2x/3x 导出、52pt 真机循环预览、资源体积与 Instruments 验收，也未接入发布包。
- 下一任务：继续按既定顺序执行 `LOGIC-14`；`PET-01` 正式启动前不得将本候选接入 App。

### PET-01 点击回应 8 帧精灵表生产候选记录（2026-07-17）

- 状态：`PET-01` 仍为 `NOT_STARTED`；本次只制作用户明确要求的点击回应精灵表候选，不启动动画代码、资源目录接入、首页替换或说话动作序列。
- 角色来源：第 1/8 帧逐像素复制 `bookkeeping-cat-idle-8f-magenta-v1.png` 的正常待机首帧；抬爪局部仅取自同角色四姿势参考图并对齐到待机坐标，生成模型候选因身份漂移未采用。
- 文件：`brand-assets/source/pet-sprites/bookkeeping-cat-tap-react-8f-magenta-v1.png`，384×192 RGB PNG，4 列×2 行，每格严格 96×96 像素。
- 动作：待机、耳尖/眼神注意、同一画面左侧前爪低位抬起、中位抬起、完整抬起、完整抬起并轻微闭眼、低位回落、待机复原；未制作说话口型。
- 验证证据：第 1/8 帧与待机母版逐像素一致；8 帧脚底基线均为 `y=87`；第 2 帧仅改变 5 个耳尖/眼睛像素；帧 3～7 的主体变化限制在抬爪局部 `(23,41)–(44,87)`，第 6 帧另含眼睛局部；角色使用参考图颜色子集，背景唯一颜色为 `#FF00FF`；SHA-256 `C48A7E501F88D64E1461447FA7144EFDF9C3D0F64A6071502802F3E95E3F0B2C`。
- 冻结边界：未修改 `NativeDemoApp/Assets.xcassets`、生产代码、测试、首页、宠物消息、提示优先级、主题、会员、路由或账本逻辑；未改变待机精灵表文件。
- 剩余风险：该文件仍是洋红抠图生产候选；尚未执行透明背景移除、逐帧 alpha 边缘检查、48pt/52pt 真机可读性、一次性播放时序、1x/2x/3x 导出、资源预算与 Instruments 验收，也未接入发布包。
- 下一任务：继续按既定顺序执行 `LOGIC-14`；`PET-01` 正式启动前不得将本候选接入 App。

### PET-01 说话回应 8 帧精灵表生产候选记录（2026-07-17）

- 状态：`PET-01` 仍为 `NOT_STARTED`；本次只制作用户明确要求的说话回应精灵表候选，不启动动画代码、资源目录接入、首页替换或其他动作序列。
- 角色来源：全部帧逐像素复制 `bookkeeping-cat-idle-8f-magenta-v1.png` 的正常待机首帧后，仅修改固定鼻口、眼睛和单个耳尖坐标；生成模型候选因角色重绘未采用。
- 文件：`brand-assets/source/pet-sprites/bookkeeping-cat-speak-react-8f-magenta-v1.png`，384×192 RGB PNG，4 列×2 行，每格严格 96×96 像素。
- 动作：待机闭嘴、轻开 1 像素、克制 2×2 开口、轻开并移动单个耳尖、闭嘴半眨眼停顿、再次轻开、闭嘴恢复、待机复原；无抬爪、尾巴或身体动作。
- 验证证据：所有帧非背景包围盒均为 `(25,14)–(82,87)`，脚底基线均为 `y=87`；第 1/7/8 帧与待机母版逐像素一致；帧 2/3/4/6 的变化仅位于鼻口 `(38,43)–(42,44)`，第 4 帧另增加单个耳尖像素，第 5 帧仅改变眼睛局部；角色使用参考图颜色子集，背景唯一颜色为 `#FF00FF`；SHA-256 `7F93DD3C66A506B721CB703DDC962FD458D5414011AB17265F3EF30220C9A566`。
- 冻结边界：未修改 `NativeDemoApp/Assets.xcassets`、生产代码、测试、首页、宠物消息、提示优先级、主题、会员、路由或账本逻辑；未改变待机和点击回应精灵表文件。
- 剩余风险：该文件仍是洋红抠图生产候选；尚未执行透明背景移除、逐帧 alpha 边缘检查、48pt/52pt 口型辨识、气泡期间播放时序、1x/2x/3x 导出、资源预算与 Instruments 验收，也未接入发布包。
- 下一任务：继续按既定顺序执行 `LOGIC-14`；`PET-01` 正式启动前不得将本候选接入 App。

### PET-01 正式启动与透明逐帧接入边界（2026-07-17）

- 状态：`PET-01` 从 `NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`，`LOGIC-14` 与 `COPY-02` 保持 `NOT_STARTED`。
- 用户授权：停止继续绘图，使用已经验收的像素猫素材完成首页帧动画；完成后继续 `LOGIC-14`，`COPY-02` 先交付方案、确认后再改代码。
- 已确认输入：
  - `brand-assets/source/pet-sprites/bookkeeping-cat-idle-8f-magenta-v1.png`
  - `brand-assets/source/pet-sprites/bookkeeping-cat-tap-react-8f-magenta-v1.png`
  - `brand-assets/source/pet-sprites/bookkeeping-cat-speak-react-8f-magenta-v1.png`
  - `tmp/pet-frames-v1/idle|tap|speak/*.png` 共 24 张 96×96 RGBA 透明帧。
- 输入验证：三组各 8 帧；四角透明；无不透明 `#FF00FF`；非背景 RGB 逐像素保持；各组第 1/8 帧一致；三组第 1 帧一致；预览时序和 `validation-report.md` 通过独立复核。
- 允许修改：独立像素宠物动画 View/状态模型、宠物正式资源、`HomeView.todayPetStamp` 的图像承载、必要的 XCTest/静态门禁/真机矩阵和本文档。
- 冻结边界：不改变宠物开关、消息生成、天气联动、气泡文案、4 秒关闭规则、保存后提示预算、首页主动作、现有遮挡优先级、主题体系、路由、会员、账本、图片和同步；不修改其他首页卡片。
- 动画边界：待机低频循环；点击只播放一个可取消的抬爪序列；气泡可见时播放说话短循环；App 非活跃、宠物隐藏、Reduce Motion 或低电量时停止持续帧推进并显示稳定帧；连续点击不得堆叠任务。
- 性能边界：帧推进封装在独立 View 内，不观察账本，不触发首页统计、生活线索、通勤或卡片重算；只缓存当前已使用序列，资源缺失时显示静态产品宠物帧或隐藏，禁止回退系统 emoji。
- 计划文件：`NativeDemoApp/Views/Components/PixelPetAnimationView.swift`、`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/Assets.xcassets` 宠物资源、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 下一步：先完成资源接入、动画状态和首页替换，再运行完整 Windows repository gate；Xcode/iPhone 的帧时序、内存、主题、VoiceOver、Reduce Motion 与低电量仍只能标记为待签收。

### PET-01 代码收口与 LOGIC-14 启动记录（2026-07-17）

- `PET-01` 状态：`IN_PROGRESS` → `CODE_DONE`；`LOGIC-14` 状态：`NOT_STARTED` → `IN_PROGRESS`；`COPY-02` 保持 `NOT_STARTED`，当前唯一 `IN_PROGRESS` 为 `LOGIC-14`。
- 完成实现：
  - 新增独立 `PixelPetAnimationView`，从 4×2 sprite sheet 按当前 `UIImage.scale` 裁出 8 帧，以 `.interpolation(.none)` 保持像素边缘。
  - 待机、点击、说话分别使用已验收时序；新点击优先播放一次，结束后按气泡状态进入说话或待机。
  - 点击触发在组件重建时初始化为已消费，避免强提示遮挡、切 Tab 或重新显示后重播旧点击。
  - Reduce Motion、低电量、非活跃 scene 和资源缺失均停止持续推进并显示稳定产品帧或透明降级；SwiftUI `.task(id:)` 随状态和视图生命周期自动取消旧序列。
  - 首页仅把 `Text("🐱")` 替换为 48pt 像素宠物，保留 52pt 底板、主题、气泡、消息服务、4 秒关闭、提示优先级和原点击热区；VoiceOver 只朗读宠物助手和操作提示。
  - 三组正式 imageset 均含 2x/3x RGBA 资源；动画源接入 App Target；新增策略 XCTest、静态防回流和 `FLOW-30` 真机矩阵。
- 修改/新增文件：
  - `NativeDemoApp/Views/Components/PixelPetAnimationView.swift`
  - `NativeDemoApp/Views/HomeView.swift`
  - `NativeDemoApp/Assets.xcassets/PetIdleFrames.imageset/`
  - `NativeDemoApp/Assets.xcassets/PetTapFrames.imageset/`
  - `NativeDemoApp/Assets.xcassets/PetSpeakFrames.imageset/`
  - `NativeDemoApp.xcodeproj/project.pbxproj`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/experience_static_check.ps1`
  - `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`
  - 本文档。
- 验证证据：三组资源清单、RGBA 模式、384×192/576×288 尺寸与工程接线专项检查通过；`python scripts/validate_release_gate.py --phase windows` 完整通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：未改变宠物开关、消息生成、天气联动、气泡文案、4 秒关闭、保存后提示预算、首页主动作、强提示遮挡优先级、主题、路由、会员、账本、图片、存储或同步；未修改其他首页卡片。
- 剩余风险：Windows 无 Xcode/Swift/iPhone，sprite 裁切编译、真实帧时序、连续点击、切后台、低电量、Reduce Motion、多主题、VoiceOver、60 秒 hitch 与内存仍按 `FLOW-30` 保持 `NOT_RUN`，因此不得标记 `VERIFIED`。
- 下一项：执行 `LOGIC-14`，仅把显式单分类查询的三项指标切换为活跃天数、平均每笔和最高单笔；不修改识别、筛选、记录、总额、主题或写入。

### LOGIC-14 代码收口与 COPY-02 方案评审启动记录（2026-07-17）

- `LOGIC-14` 状态：`IN_PROGRESS` → `CODE_DONE`；`COPY-02` 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS` 为 `COPY-02`，且仅处于方案评审阶段。
- 完成实现：
  - 查询指标模型显式携带识别阶段的范围：`singleCategory(HomeItem.Category)` 或 `crossCategory`，不根据结果中实际出现的分类数量猜测。
  - 明确单分类查询显示“有记录 / 平均每笔 / 最高单笔”；0 笔后两项显示空态，1 笔允许平均值与最高单笔相同。
  - 未指定分类、多分类语义、生活线索或明确询问分类构成时继续显示“有记录 / 最高分类 / 该类金额”；即使结果碰巧只有一类，也保持跨分类口径。
  - 正文“金额最高的是某条记录”继续表示最高单笔；指标中原“金额最高”改为准确的“最高分类”，消除分类与单笔混用。
  - 新增确定性测试摘要，覆盖显式餐饮、未指定但只有餐饮、0 笔和 1 笔边界；新增静态防回流和 `FLOW-31` 真机矩阵。
- 修改文件：
  - `NativeDemoApp/Views/InsightWebView.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/experience_static_check.ps1`
  - `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`
  - 本文档。
- 验证证据：专项静态门禁通过；`python scripts/validate_release_gate.py --phase windows` 完整通过，生活语义、交互、文案、迁移和 SQLite schema 均无新增失败，仍只有既有 7 条 soft warning。
- 冻结边界复核：未改变自然语言识别、分类槽位、时间范围、筛选记录、金额总计、排序、原始证据、查询/对比只读、补记确认、额度、会员、保存、存储、同步、主题 Token、卡片结构、圆角、间距或动画。
- 剩余风险：Windows 无 Xcode/Swift/iPhone，新增枚举与 ViewBuilder 分支编译、XCTest、0/1/多笔真机数据、Dynamic Type 和 VoiceOver 仍按 `FLOW-31` 保持 `NOT_RUN`，因此不得标记 `VERIFIED`。
- 下一项：`COPY-02` 只输出周记/月章文案结构、证据规则、样例与验收方案供用户确认；确认前不得修改 `PlaybackCopyPool.swift`、`PlaybackService.swift`、`SummaryPlaybackSheet.swift` 或任何播放文案。

### COPY-02 可评审方案 v1（2026-07-17，待用户确认）

- 当前状态：仅完成只读审计与方案整理，未修改 `PlaybackCopyPool.swift`、`PlaybackService.swift`、`SummaryPlaybackSheet.swift`、文案夹具或播放 UI；`COPY-02` 继续保持 `IN_PROGRESS`。
- 代码审计结论：
  - 当前模板大量使用“格、胶片、气味、画面、生活开头”等抽象容器；同一事实经模板、`sceneMemoryLine` 和 `supportLineText` 多次转述，形成机器式重复。
  - `scentText`、`displayEmotionTag`、生活线索标题和 recurring token 可能直接进入主文或辅助文，导致“公共交通一段”“第 30 次”“这次它又回来了”等内部标签感。
  - 周记与月章主要共享同一类句式，只替换范围和标题；周度不够贴近最近几天，月度也没有把真实变化和代表记录排出主次。
- 推荐方案：
  1. 每章只承担一个角色：事实概况、具体记录、节奏变化、同期变化或克制回应；不在一句里同时塞分类、情绪、场景、次数和升华。
  2. 主文固定为“事实锚点 → 一层观察 → 可选回应”；证据不足时只说事实，不补情绪。
  3. 周记优先日期、星期、最近一笔和一周内重复节奏；月章优先月内代表记录、前后段差异和有证据的上月变化。
  4. 用户编辑标题、明确备注、照片说明、日期、时间、天气、金额和确定性计数可直接使用；自动情绪标签、内部场景名和里程碑标签只能帮助选材，不能原样进入文案。
  5. 主文与辅助证据拆分：主文自然说一件事，辅助层只列日期/金额/笔数/同期数字；若两层包含同一标题和同一事实，辅助层改为数字证据或隐藏。
  6. 保留现有周记/月章章节数量、顺序、时长、照片、进度和 UI 结构，只评审收敛章节标题和文案内容。
- 建议章节标题：
  - 周记：`这一周`、`记录最多的一天`、`这一笔`、`这周反复出现`、`这周先到这里`。
  - 月章：`7 月回看`、`月初留下的`、`后来留下的`、`和上个月相比`、`这个月反复出现`、`这个月先到这里`。
- 方向样例：
  - 弱数据周记：`这周记了 2 笔，分别在周二和周五。先从周五的「下班地铁」看起。`
  - 周度节奏：`周三记了 3 笔，是这周记录最集中的一天。其中有一趟下班地铁。`
  - 月初记录：`7 月 4 日，你记下了「下班地铁」。这是月初最早的一笔通勤记录。`
  - 月度变化：`和 6 月同期相比，交通少了 ¥42，餐饮多了 ¥18。`
  - 反复出现：`这个月反复出现的是通勤和咖啡：通勤 8 次，咖啡 5 次。`
  - 明确备注才回应：用户写了“终于到家”时可说 `你在备注里写了「终于到家」。这句比自动分类更值得留下。`；只有自动标签时不输出“辛苦了”“松了一口气”等感受判断。
- 计划实现范围（仅在用户确认后）：
  - `PlaybackCopyPool.swift`：按周/月与叙述角色重写模板池，删除抽象升华和内部标签直出模板。
  - `PlaybackService.swift`：增加证据等级、自然化标签、同期变化事实和主文/辅助去重输入；不改变记录选择、章节数量与顺序。
  - `SummaryPlaybackSheet.swift`：只调整章节标题与辅助证据文案，保留现有布局、动画和播放控制。
  - 增加空/弱/密集、重复通勤、照片、明确备注、自动情绪、跨月增减和无变化夹具，以及文案 lint、XCTest、copy snapshot 和真机矩阵。
- 待用户确认点：是否采用上述单一方案及章节标题方向；确认前代码保持冻结。

### COPY-02 可评审方案 v2（2026-07-17，待用户确认）

- 方案登记时状态：`COPY-02` 为唯一 `IN_PROGRESS` 且只处于方案评审；随后因用户 Xcode 编译错误被 `PERF-FIX-01` 定向插队并退回 `NOT_STARTED`。本段未修改 `PlaybackCopyPool.swift`、`PlaybackService.swift`、`SummaryPlaybackSheet.swift`、文案夹具、测试或播放 UI。
- 新增方案文档：`PLAYBACK_COPY_LIVING_VOICE_PLAN_v2.md`，将 v1 方向落成证据等级、周记 0/1/2/3+ 分支、月章 6 章分工、主辅去重、跨章节去重、内部标签隔离、敏感记录边界、长度预算、24 类场景矩阵、完整模拟文案和实施/验收顺序。
- 核心决策：`displayEmotionTag`、生活线索标题、场景包与里程碑在缺少用户来源证明时只帮助选材，不原样进入主文；`warm` 与 `plain` 必须共享同一事实，证据不足时允许完全相同。
- 周记边界：0 笔不生成章节；1～2 笔保持 3 章，只说日期、记录和收尾；3 笔以上保持 5 章，概况、集中日、代表记录、可靠重复和收尾各自分工。
- 月章边界：固定 6 章；月初无记录、后段无记录或前后候选为同一笔时必须显式降级，不得拿同一记录冒充两个阶段。
- 建议事实口径例外：当前月未结束时，“变化章”比较本月 1 日至今天与上个月相同日序，避免残月对完整月；完整历史月仍做完整月环比。该例外只影响变化章对照记录，必须随用户对 v2 的确认一并获得授权；若未授权则降级为“不对未结束月份做完整月环比”。
- UI 与结构边界：只允许调整章节标题和已有辅助文案；章节数量、顺序、时长、照片、进度、额度、会员、分享、主题、播放控制和完成动作继续冻结。
- 工作区保护：继续保留 `StatCardView.swift`、`web-preview/app.js`、用户提示文档、`brand-assets/`、`tmp/` 与 `scripts/__pycache__/` 的既有修改或未跟踪内容；本次只新增方案文档并更新本文档。
- 下一步：向用户提交 v2 方案评审；确认前不得开始播放文案代码，`ARCH-03` 继续保持 `NOT_STARTED`。

### COPY-02 v2 代码实施启动记录（2026-07-20）

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS` 为 `COPY-02`。
- 用户授权：在确认问题仍存在后，要求“改一下看看效果”；本轮按 `PLAYBACK_COPY_LIVING_VOICE_PLAN_v2.md` 实施，不再停留在方案评审。
- 允许范围：`PlaybackCopyPool.swift`、`PlaybackService.swift`、`SummaryPlaybackSheet.swift` 中播放主文、章节标题与辅助证据，以及对应确定性测试、文案 lint、真机矩阵和本文档。
- 冻结边界：周记弱数据 3 章/成熟数据 5 章、月章 6 章及其顺序、播放时长、记录筛选、照片选择、进度、额度、会员、分享、主题、播放控制和完成动作全部保持；不改今日回放、痕迹首屏文案、AI 指令、首页动态主动作或 `ARCH-03`。
- 工作区保护：保留 `UI-FIX-03`、`FIX-010`、`StatCardView.swift`、`web-preview/app.js`、用户提示文档、素材与 `tmp/` 的现有修改/未跟踪内容，不覆盖、不回退、不纳入本项。
- 实施顺序：先建立事实证据与安全标题规则，再收敛周/月模板和主辅去重，最后补确定性边界回归与全量 Windows 门禁；当前月变化章采用 v2 的上月同期口径。

#### COPY-02 v2 代码收口（2026-07-20）

- 状态：`IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`，`ARCH-03` 继续保持 `NOT_STARTED`。
- 周记结果：0 笔仍不生成章节；1～2 笔仍为 3 章，改为“这一周 / 这一笔 / 这周先到这里”；3 笔以上仍为 5 章，按概况、唯一/并列/分散日期、具体记录、可靠重复和收尾分工。集中日只说聚合事实，不再复述代表标题；重复章优先不与代表章撞标题的安全标题，其次使用分类计数，无可靠重复时明确说明分散。
- 月章结果：继续固定 6 章和原时长，改为“本月回看 / 月初留下的 / 后来留下的 / 和上月同期相比 / 这个月反复出现 / 这个月先到这里”。月初无记录、当前未到 11 日、11 日后无记录均有明确降级；月初与后来只从各自日期段选择，不再用同一记录补两个章节。
- 变化口径：本月只统计 1 日至今天，并与上个月相同日序比较；上月同期少于 3 笔或总额为 0 时明确不做环比。样本充足时按既有可靠阈值最多陈述两项分类增减、新增或消失并给原始金额；没有可靠分类变化时才使用同期总额/笔数的持平或整体变化事实。
- 可信边界：播放正文不再读取或输出 `displayEmotionTag`、生活线索标题、`sceneMemoryLine`、`scentWords`、里程碑或宠物代言；这些 C 级信号仍可在既有选材层帮助确定记录，但正文只使用日期、时间、分类、金额、安全标题和可复算计数。`warm/plain` 共享同一事实，当前无额外证据时完全一致。
- 主辅去重：每章显式携带 `supportLine`；辅助层只显示独立的分类、金额、组成或同期范围，若与当前正文归一化后相同/被正文包含则隐藏。新章节不再生成重复的词条 chip；收尾和无新增证据章节不填充辅助卡。
- 模板治理：`PlaybackCopyPool` 收敛为显式 `mainLine/teaserLine` 渲染，删除胶片、气味、画面、生活开头、未来天气/路线、宠物代言等抽象模板；旧周/月重复、环比和情绪拼接的不可达辅助实现一并从播放服务移除，避免后续误接回生产路径。
- 修改文件：`NativeDemoApp/Services/PlaybackCopyPool.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`qa/page_copy_snapshots.json`、`scripts/playback_copy_lint.py`、`scripts/check_copy_experience.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 自动回归：新增 5 组确定性 XCTest，覆盖周记 0/1/2/3+、同日/并列集中、具体金额小数、自动情绪隔离、周月章节数量/时长、月初空缺、后段记录、上月同期截断和数据不足；新增 `playback_copy_lint.py`、页面 copy snapshot 与 `FLOW-42`。`check_copy_experience.ps1` 现在会在任一子检查失败时返回失败，避免嵌套 PowerShell 掩盖退出码。
- 验证证据：`python scripts/playback_copy_lint.py`、`scripts/check_copy_experience.ps1`、`scripts/experience_static_check.ps1`、`git diff --check` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条夹具摘要、真实 12MP 照片、生活语义、文案、主题、迁移和 SQLite schema 均通过；只保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改周记弱数据 3 章/成熟数据 5 章、月章 6 章及顺序/时长，未修改记录筛选、照片选择、进度、额度/扣次、会员、分享、主题、播放控制、完成动作、今日回放、痕迹首屏、AI 指令、首页动态主动作、存储同步或 `ARCH-03`；`UI-FIX-03`、`FIX-010` 与用户既有脏工作区保持原样。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 Swift 文案策略、`NumberFormatter`、View 辅助去重与 XCTest 尚未实际编译；主文长度、默认/深色主题、特大字号、VoiceOver、宠物开关、真实账本选材和同期复算需要按 `FLOW-42` 真机签收。完成前不得标记 `VERIFIED`。
- 下一步：在 Xcode 执行 Debug/Release 与全部 XCTest，然后用 iPhone 对周记 0/1/2/3+、月初/后段空缺、自动标签、同期不足/变化/持平及多主题/大字/VoiceOver 逐章试听；发现问题只修 `COPY-02` 对应规则，不调整播放结构或相邻页面。

### PERF-FIX-01 记录预填 `now` 字段归属编译修复（2026-07-17）

- 用户优先级例外：用户在 Xcode 报告 `HomeViewModel.swift` 四处编译错误，要求先恢复编译；`COPY-02` 从方案评审 `IN_PROGRESS` 退回 `NOT_STARTED`，已完成的 v2 文档保留，播放文案代码继续冻结。
- 当前状态：`PERF-FIX-01` 为唯一 `IN_PROGRESS`。
- 错误：`RecordPrefillPreparationKey` 初始化缺少 `now` 两处、`RecordPrefillPreparationInput` 初始化多余 `now` 一处、计算访问不存在的 `input.now` 一处。
- 根因：`now` 属性误放到预填缓存键；现有计算和确定性 XCTest 均按 `RecordPrefillPreparationInput.now` 使用。若把精确 `Date()` 留在缓存键，还会导致相同账本与草稿在普通重绘时无法命中缓存。
- 允许修改：只修正 `RecordPrefillPreparationKey` / `RecordPrefillPreparationInput` 的字段归属，并增加对应静态防回流；必要时更新同一测试夹具，但不得改变预填结果。
- 冻结边界：不改变 180/90 天历史口径、标题/分类推荐优先级、用户锁定、日期语义、后台计算、账本修订缓存、记录保存、UI、播放文案或 `ARCH-03`。
- 工作区保护：继续保留 `StatCardView.swift`、`web-preview/app.js`、用户提示文档、`PLAYBACK_COPY_LIVING_VOICE_PLAN_v2.md`、`brand-assets/`、`tmp/` 与 `scripts/__pycache__/` 的既有修改或未跟踪内容。

#### PERF-FIX-01 收口

- 状态：`IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`，`COPY-02` 保持 `NOT_STARTED` 且 v2 方案完整保留待用户确认。
- 修复：从 `RecordPrefillPreparationKey` 移除 `now`，并恢复 `RecordPrefillPreparationInput.now`；`prefillSnapshot`、生产初始化和既有 XCTest 重新使用同一签名，四处缺少 / 多余参数及不存在成员错误由同一字段归位修复。
- 行为边界：精确 `Date()` 不再进入缓存键，避免普通重绘导致相同账本 / 金额 / 日期 / 备注 / 分类上下文的预填缓存失效；90 天分类推荐仍使用计算发起时的 `now`，180 天历史快照、推荐优先级和用户锁定均未改变。
- 修改文件：`NativeDemoApp/ViewModels/HomeViewModel.swift`、`scripts/experience_static_check.ps1`、本文档。
- 验证：`git diff --check` 通过；体验静态门禁通过并新增 `now` 字段归属防回流；`python scripts/validate_release_gate.py --phase windows` 完整通过，生活语义、交互、文案、迁移样本、SQLite schema、100/1,000/5,000 条夹具和真实照片夹具均无新增失败，仍只有既有 7 条文案 soft warning。
- 剩余风险：当前 Windows 无 Xcode / Swift，必须由用户在原 Xcode 环境重新编译确认这四处错误清零；不得在未复编译前标记为 `VERIFIED`。
- 下一步：先由 Xcode 重新编译；若无新增编译错误，再等待用户确认 `COPY-02` v2 后启动播放文案代码。`ARCH-03` 继续保持 `NOT_STARTED`。

### UI-FIX-02 记账页重复“补充细节”移除与时间入口恢复（2026-07-17）

- 用户真机反馈：金额预览卡已经提供“自己写一句”和“改分类”，下方仍出现“补充细节 / 改分类 / 写点细节 / 改时间”，形成重复；原先直接可见的时间修改入口被收进折叠层后，用户认为功能消失。
- 历史归因：`048cdd4`（2026-06-08）首次加入“补充细节”折叠；`c1cd8e4`（2026-07-16，`LOGIC-02`）移除独立 `recordDateQuietActions`，把 `WarmRecordDatePanel` 与“改时间”一起迁入折叠层，导致上方已有动作和下方折叠动作重复。
- 状态：`UI-FIX-02` 为当前唯一 `IN_PROGRESS`；`COPY-02` 保持 `NOT_STARTED`，播放文案方案和代码均不受本项影响。
- 用户指定 UI 冻结基线：以用户提供的旧版真机截图和 `c1cd8e4^` 的记账主表单顺序为准，不重新设计。顺序固定为金额 → 预览卡 → 放进账本 → 截图导入 → 居中日期时间入口 → 按需展开日期 / 分类 / 备注面板。
- 允许修改：移除记账主表单的“补充细节”折叠及其重复按钮；恢复原独立 `recordDateQuietActions` 与原位置；恢复金额已填写时仍可见的截图导入入口；分类、备注和日期面板继续由原状态打开。
- 冻结边界：不改变金额、标题、分类、日期的保存含义，不改变预填 / 用户锁定 / OCR / 场景包 / 会员 / 保存按钮 / 草稿跨 Tab 保留，不调整记账页其他卡片、颜色、主题或路由。
- 边界处理：无有效金额时不展示预览与时间入口；截图导入入口按截图基线始终可见；时间面板关闭 / 切 Tab / 保存成功后的状态复位保持；分类、备注、时间只能各自展开原面板，不新增第二套编辑状态；不得把“改时间”改放进预览卡。
- 工作区保护：保留现有 `StatCardView.swift`、`web-preview/app.js`、用户提示文档、`brand-assets/`、`tmp/` 和 `scripts/__pycache__/`，不提交或覆盖。

#### UI-FIX-02 收口

- 状态：`IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`，`COPY-02` 保持 `NOT_STARTED`，`ARCH-03` 保持 `NOT_STARTED`。
- UI 恢复：记账主表单重新使用截图基线顺序：金额 → 原预览卡 → 放进账本 → 截图导入 → 居中日期时间入口 → 按需编辑面板；恢复 `recordDateQuietActions` 和原 `WarmRecordDatePanel` 展开位置。
- 去重复：删除“补充细节”折叠、`改分类 / 写点细节 / 改时间` 三个重复按钮及只为该折叠服务的 `recordDetailsExpanded` 状态；分类和备注仍由原预览卡动作打开原 `categorySection` / `noteSection`。
- 用户指定冻结复核：`LifeEntryPreviewCard.swift` 零差异；“换说法 / 换个角度 / 自己写一句 / 改分类”的会员、预览层级、免费场景包与轮换显示条件完全未改。
- OCR 边界：按用户截图恢复金额已填写时仍显示“有账单截图？从截图导入”；仅撤销 `c1cd8e4` 对该入口的隐藏策略，不改 OCR 模式、草稿、额度、识别或确认导入。
- 日期边界：独立日期时间文字继续调用原 `recordDateBinding`，更新仍走 `updateSelectedDate(..., userInitiated: true)`；只补无视觉变化的 VoiceOver“修改时间，当前……”标签。
- 修改文件：`RecordView.swift`、`InteractionStateModels.swift`、`StateRegressionTests.swift`、`accessibility_lint.py`、`experience_static_check.ps1`、本文档。
- 验证：`git diff --check`、生活语义回归、体验静态门禁、无障碍 lint 均通过；`LifeEntryPreviewCard.swift` 差异为空；`python scripts/validate_release_gate.py --phase windows` 完整通过，仍只有既有 7 条文案 soft warning。
- 剩余风险：Windows 无 Xcode / iPhone，需真机确认默认 / 会员 / 非会员、预览弱态 / 确认态、日期展开、分类 / 备注展开和截图导入位置与用户基线截图一致；未真机前不得标记 `VERIFIED`。
- 下一步：提交推送后由用户真机签收本页；签收前不继续改记账页 UI。

#### UI-FIX-02 用户确认的 OCR 入口例外

- 用户复核后确认 `c1cd8e4` 中一项逻辑合理：未输入金额时显示截图导入；金额框仅获得焦点但仍为空时继续显示；一旦存在金额草稿则隐藏截图导入，避免 OCR 与手动记账同时争主路径。
- 状态：`UI-FIX-02` 从 `CODE_DONE` 回到唯一 `IN_PROGRESS`，仅恢复 `showsOCRSideDoor(hasAmountDraft:)` 这一条策略及对应测试 / 静态门禁；“补充细节”删除、独立日期入口和预览卡按钮冻结结论不变。
- 禁止扩张：不得恢复 `showsOptionalDetails`、`recordDetailsFold` 或重复的分类 / 备注 / 时间按钮；不得修改 `LifeEntryPreviewCard` 的动作显示条件。

- 收口状态：`IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 最终规则：`RecordFlowVisibilityPolicy` 只保留 `showsOCRSideDoor(hasAmountDraft:)`；金额为空（包括只有焦点、未输入）显示截图导入，存在任何金额草稿后隐藏。没有恢复可选细节策略或折叠层。
- 验证补充：新增两态 XCTest 和静态门禁；`LifeEntryPreviewCard.swift` 继续零差异；完整 Windows release gate 再次通过，仍只有既有 7 条文案 soft warning。
- 真机待签：金额框未点、仅聚焦未输入、输入金额、清空金额四个状态下核对截图导入显隐；其余 UI 按用户基线截图核对。

---

## 23. 2026-07-18 TestFlight 定向问题收集与优化序列

用户开始提交新一轮 iPhone 真机问题。本节先逐项完成截图核对、代码根因、影响边界和验收设计，不在问题收集阶段修改生产代码；待问题收齐后按本表顺序定向修复。当前无 `IN_PROGRESS`，`COPY-02` 与 `ARCH-03` 继续保持 `NOT_STARTED`。

| 顺序 | ID | 问题 | 优先级 | 状态 | 当前结论 |
|---:|---|---|---|---|---|
| 1 | FIX-004 | AI 通勤补记未识别同日、非标准时刻的已有通勤 | `P0` | `CODE_DONE` | 强方向词可跨标准窗口阻止对应候选；无方向通勤按早/晚时刻回退；普通交通/旅行不误挡，Windows 全门禁通过 |
| 2 | FIX-007 | 今日回放首次打开误用空快照 | `P0` | `CODE_DONE` | 内容、Sheet 与扣次统一为可识别 payload；未准备快照不能呈现，合法空账本不扣次，快速重复点击不重复启动 |
| 3 | FIX-005 | 痕迹细查首次打开错误显示 0 笔，十几秒后才出现 | `P0` | `CODE_DONE` | 初始筛选快照随 `.sheet(item:)` payload 原子交付，首帧不再把未准备状态当 0 笔；筛选后继续复用单次快照 |
| 4 | FIX-006 | 咖啡等单类语义查询仍显示最高分类 | `P1` | `CODE_DONE` | 指标 scope 读取生活线索真实分类定义域；单类主题使用聚焦指标，多类与显式分类构成保持跨分类指标 |
| 5 | COPY-03 | 单条情绪标签事实化与跨记录叙事归位 | `P1` | `CODE_DONE` | 停车费与周末餐饮改为本条事实；跨记录周末故事停止写入，首页第一笔只描述当前记录，Windows 全门禁通过 |
| 6 | PET-02 | 宠物消息生命周期与可信上下文文案 | `P1` | `CODE_DONE` | 触摸/保存后消息共用可取消生命周期；账单事实优先、记录天气与当前天气分离、敏感降级与近期去重完成，Windows 全门禁通过 |
| 7 | INT-03 | 全局记录时间选择交互 | `P1` | `CODE_DONE` | 六个记录/OCR入口改为局部双列滚轮和完成时一次提交；取消/切记录零写入，痕迹范围保持仅日期，Windows 全门禁通过 |
| 8 | MEMBER-03 | 会员详情按权益状态去重复 | `P1` | `CODE_DONE` | 非会员单一价值对比、订阅状态/管理、永久档案直达与照片/同步边界完成；StoreKit 和续购路径冻结，Windows 全门禁通过 |
| 9 | AI-03 | 高价值语义标签与自然短语查询 | `P1` | `CODE_DONE` | 天气＋通勤、兴趣与外地可信 facet、查记录名词短语、暖标签排除和任务写入边界完成，Windows 全门禁通过 |

### 首页状态驱动主动作长期冻结确认（2026-07-18）

- 用户真机确认首页交互流畅度明显提升，并明确认可“不同状态启动时，首页按钮跟随当前阶段变化，引导用户探索下一项功能”的产品方案。
- 方案来源：`LOGIC-01` 建立统一下一步动作，`LOGIC-05` 增加周/月内容成熟度与回放后承接，`LOGIC-07` 形成记录→今日回放→周/月痕迹→复盘的渐进路径，`PERF-09` 将首页旅程事实改为账本修订/日期驱动快照，避免普通重绘重复扫描。
- 长期框架：未完成 OCR 或手动草稿优先承接；全新账本先记第一笔；今天有未回放记录时进入今日回放；周/月内容成熟后引导查看痕迹；完成周/月回看后进入复盘查、比、补；其余状态继续记录。
- 主次关系：每个时刻只突出一个最值得执行的主动作，同时保留“继续记录”或与当前状态匹配的安全次入口；引导可以变化，但不能阻断免费手动记账或覆盖未完成内容。
- 冻结要求：`FIX-004`～`FIX-007`、`INT-03`、`MEMBER-03`、`COPY-03`、`PET-02`、`AI-03` 和未来 `ARCH-03` 均不得修改该状态顺序、成熟判断、动作目的地和主次结构；按钮局部文案、无障碍说明或性能实现若必须调整，用户可见职责和路由结果保持一致。
- 变更门槛：未来如需调整状态优先级、周/月成熟门槛、复盘出现时机或次入口，必须新建独立产品任务，提供全状态矩阵、反向场景、回滚方式和真机证据，不得在相邻修复中顺手改变。
- 当前状态：该产品决策记为长期冻结边界；本次只更新台账，没有修改生产代码、首页 UI、按钮逻辑、快照、路由或测试，当前无 `IN_PROGRESS`。

### 九项问题最终执行顺序锁定（2026-07-18）

用户确认本轮问题暂时收集完毕。以下顺序覆盖本节各任务早期记录中的临时“下一项”描述；后续执行以本段和上方总表为准，不再根据聊天顺序或文件相邻关系调整。

| 最终顺序 | ID | 先做原因 | 完成边界 |
|---:|---|---|---|
| 1 | FIX-004 | AI 补记可能把已有通勤再次作为可保存候选，属于写入正确性风险 | 只修同日通勤方向与重复判断；未来时点、工作日、金额和确认流程不变 |
| 2 | FIX-007 | 今日回放假空态可能在内容未正确呈现时已经消耗免费次数，涉及用户权益与状态损失 | 快照、Sheet 和扣次原子化；回放内容、额度常量、播放 UI 和完成动作不变 |
| 3 | FIX-005 | 痕迹细查首次显示假 0 笔，破坏数据可信度，但属于只读展示路径 | 使用独立 payload 原子呈现；保留 `PERF-13` 单次筛选快照、筛选含义和列表 UI |
| 4 | FIX-006 | `LOGIC-14` 的遗漏范围小，可先封闭单类查询指标回归，再进入更广文案/语义任务 | 只改指标 scope；查询结果、证据、识别、主题和写入不变 |
| 5 | COPY-03 | 先校正单条事实标签和跨记录归属，为宠物与后续语义能力建立可信事实层 | 精确修系统标签与首页第一笔表达；不模糊改用户文本，不碰周/月播放文案 |
| 6 | PET-02 | 宠物上下文必须消费 COPY-03 后的稳定事实边界，避免放大弱标签 | 统一气泡生命周期与高置信消息策略；像素动画、首页主动作、提示预算和主题不变 |
| 7 | INT-03 | 共用时间面板影响 6 个入口，范围较广，放在事实/首页定向问题稳定后单独实施 | 使用局部草稿和完成时一次提交；日期语义、保存、OCR 和页面布局不变 |
| 8 | MEMBER-03 | 会员页需按身份重排信息，但与 StoreKit、登录续购和入口上下文相邻，必须独立回归 | 只做状态化信息层级和去重复；价格、Product ID、交易验证、恢复和权益不变 |
| 9 | AI-03 | 这是九项中唯一明显扩张查询能力的任务，语义矩阵与反例面最广，应在事实层稳定后最后实施 | 只新增可信 facet 与只读查询；不降低补记写入门槛，不依赖暖文案，不新增远程调用 |

#### 执行纪律

1. 同一时间只允许一个任务为 `IN_PROGRESS`；每项完成代码、专项回归、全局 Windows 门禁和台账回填后，才进入下一项。
2. 每项保持独立差异和独立回滚点；即使 `FIX-007` 与 `FIX-005` 都采用 `.sheet(item:)`/payload 原子交付，也不得合并成全局 Sheet 重构。
3. 先修现有优化暴露的竞态，不撤销 `PERF-10`、`PERF-13`、`PERF-09` 的不可变快照、单次派生和变化驱动计算。
4. 首页状态驱动主动作、一个主入口＋安全次入口、路由目的地和成熟度框架全程冻结。
5. `COPY-02` 周记/月章活人感文案继续等待单独确认；`ARCH-03` 页面拆分继续 `NOT_STARTED`，不得夹带进入九项修复。
6. 不触碰或提交用户既有 `StatCardView.swift`、`web-preview/app.js`、提示文档、`brand-assets/`、`tmp/` 和 `scripts/__pycache__/` 现场。
7. Windows 检查通过只允许标记 `CODE_DONE`；最终统一完成 Xcode Debug/Release、XCTest、iPhone、StoreKit、权限、Dynamic Type、VoiceOver、Reduce Motion 与真实数据矩阵后才能标记 `VERIFIED`。

#### 当前记录

- 状态：九项任务顺序与冻结边界已锁定，全部保持 `NOT_STARTED`；当前无 `IN_PROGRESS`，未修改任何生产代码。
- 修改文件：仅本文档。
- 验证证据：汇总本节九组 TestFlight 截图、代码根因、历史归属、用户确认的动态首页冻结决策，以及各任务既有验收矩阵；`git diff --check` 作为文档门禁。
- 剩余风险：实施时的 Swift/Xcode 编译、并发、Sheet 生命周期、StoreKit、六入口时间选择和真实语义召回仍须逐项验证，不能由当前方案评审替代。
- 下一项：用户明确开始执行后，从 `FIX-004` 进入唯一 `IN_PROGRESS`，不得跳到视觉、会员、宠物或 AI 扩能任务。

### 后续产品级优化候选（不进入本轮九项队列）

以下候选沿用首页动态主动作的核心思想：让产品根据真实状态给出一个合适的下一步，同时保留退出和自由选择。当前仅登记方向，不创建 `IN_PROGRESS`，不授权修改代码。

#### 候选 A：全局“完成后下一步”承接

- 把首页已经验证的“一主一次”原则扩展到任务完成页，而不是扩张首页按钮。
- 示例：查完记录后可主推“做同期对比”；对比完成后主推“看原始记录”；补记确认后主推“回到今天”；备份完成后主推“查看恢复说明”。
- 价值：用户完成一个动作后不掉进死胡同，也不需要重新猜应该去哪个 Tab。
- 边界：每个页面单独立项，不新建全局万能路由，不改变首页主动作，不自动执行下一步。

#### 候选 B：功能成熟度的可解释提示

- 当前系统已经知道周/月内容何时成熟，但用户只在按钮出现后看到结果；可以在不抢主入口的前提下，用一句轻提示解释“为什么现在推荐”。
- 示例：`本周已有 12 笔，可以回看了`、`这个月还在积累，先继续记录`。
- 价值：动态按钮不显得随机，用户逐渐理解记录如何沉淀成今日回放、周痕迹、月章和复盘。
- 边界：只解释已有判断，不改变成熟门槛，不做打卡进度条，不制造“还差一笔”的压力或会员诱导。

#### 候选 C：中断任务的统一恢复

- 将 OCR 待整理、手动草稿、备份导入预览、登录后续购等“做到一半”的状态统一描述为可恢复任务，并在原入口或合适的承接页显示一次明确继续动作。
- 价值：减少用户担心数据丢失，也避免每个模块各自设计恢复提示。
- 边界：只恢复用户已经主动开始的任务；不自动购买、不自动导入、不自动保存，不把多个 Sheet 同时拉起。

#### 候选 D：结果驱动的连续探索

- 在复盘、痕迹和 AI 指令结果中，根据这一次真实结果提供一个有信息增量的后续动作，而不是固定“继续问”或重复运行。
- 示例：单类查询后建议看同期变化；发现明显增减后建议核对差异来源；0 结果时建议放宽时间或清除分类。
- 价值：让“查、比、补”形成自然学习路径，进一步提升功能发现率。
- 边界：建议必须由当前结果决定，只读动作不写账；补记继续需要强写入意图与确认，不生成账本外原因。

#### 候选优先级建议

九项问题全部达到 `CODE_DONE` 且统一真机签收后，优先评审 `候选 A → 候选 B`。两项最接近当前动态首页已经验证的成功模式，并且可以先从一个页面做小范围试点；`候选 C/D` 涉及更多状态与语义，放在后续独立评审。

### FIX-004：AI 通勤补记同日重复方向识别

#### 真机现象与证据

- 2026-07-17 首页已有两笔明确通勤相关记录：`上班`，13:48，¥4.75；`通勤路上记一笔`，22:55，¥4.75。
- 21:57 打开 AI 指令台补记时，7 月 17 日的 `早高峰通勤 08:30` 和 `晚高峰通勤 18:30` 仍显示绿色可新增状态，而不是疑似已有冲突。
- 同一结果中，7 月 13～16 日落在固定时间窗内的记录能够正常显示黄色冲突，说明账本快照、日期范围和金额推断已进入计算，问题不属于旧数据、缓存未刷新或异步结果反写。

#### 根因

- `AICommuteDraftSchedule` 只负责阻止生成尚未到时点的候选：当天候选时间不晚于 `now` 才可进入。真机时间 21:57 已晚于 18:30，因此 17 日晚高峰可以生成，这部分符合现有规则。
- `existingCommuteLikeItem` 的重复检测在读取标题语义前，先要求现有记录小时落入候选固定窗口：早高峰 `6...10`、晚高峰 `16...21`。
- 17 日 `上班 13:48` 因不在 `6...10` 被排除；`通勤路上记一笔 22:55` 因不在 `16...21` 被排除。两条记录虽然同日、同分类、同金额且具备通勤语义，均无法进入后续语义匹配。
- 因此该问题是“重复方向识别过度依赖标准小时窗口”，不是未来通勤过滤失效，也不是数据没有更新。

#### 定向优化方案

1. 保留当前候选时点规则：今天尚未到 08:30 / 18:30 时不得提前生成对应候选，历史日期规则不变。
2. 重复检测改为“同日通勤语义 + 方向识别 + 原金额容差”，不再把固定小时窗作为唯一入口。
3. 方向识别优先使用强语义：`上班 / 早高峰 / 到岗` 归早向；`下班 / 晚高峰 / 回家` 归晚向。
4. 只有缺少方向词的通勤记录才使用时间作为回退；同日较早记录只阻止早向，较晚记录只阻止晚向，禁止一条模糊记录同时吞掉早晚两条候选。
5. 继续排除普通交通、旅行和非通勤记录；不能因为同日存在任意一笔交通消费就隐藏通勤候选。
6. 保留当前冲突展示方式：命中的 17 日记录标为不可保存并说明已有哪一笔，不直接静默隐藏，也不改变批量确认 UI。

#### 冻结边界

- 不改变通勤工作日/节假日判断、08:30 / 18:30 候选时间、历史补记范围、最多工作日数量、金额推断和金额容差。
- 不改变自然语言识别、查询/对比、补记确认前零写入、批量保存、分类、标题、会员、额度、存储和同步。
- 不修改首页通勤快捷卡规则，不借本项调整 AI 指令台视觉、主题或页面结构。
- `COPY-02` 播放文案与 `ARCH-03` 页面拆分继续冻结。

#### 必须补齐的回归

1. `上班 13:48` 能阻止同日早高峰，但不阻止同日晚高峰。
2. 无方向词的通勤记录 `22:55` 能阻止同日晚高峰，但不阻止早高峰。
3. 同日早晚各有一笔时，两条候选均为冲突，批量可保存数量不包含当天。
4. 只有一笔早通勤时，已到 18:30 后仍可补晚通勤；反向同理。
5. 同日普通打车、旅行、金额接近但无通勤证据的交通记录不能误阻止。
6. 08:30 前、08:30～18:29、18:30 后的当天候选数量保持 `FIX-002` 原边界。
7. 历史日期、周末/节假日、金额不匹配、0 笔和多笔记录结果保持稳定。

#### 当前记录

- 日期：2026-07-18。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前唯一任务切换为 `FIX-007`。
- 实现：新增 `AICommuteDuplicatePolicy`；上班/早高峰/到岗与下班/晚高峰/回家等强方向词优先，明确方向可跨固定小时窗；无方向但有通勤证据的记录按 15:00 前后回退为早/晚向；保留金额容差与工作日边界，并移除“任意低金额交通都算重复”的兜底。
- 修改文件：`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/life_semantic_regression.py`、本文档。
- 验证证据：新增 13:48 上班、22:55 无方向通勤、普通打车/高铁出差、金额不匹配与既有 08:29/08:30/18:29/18:30 测试；`git diff --check`、生活语义回归、体验静态门禁和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：候选时间、工作日/节假日、历史范围、金额推断、确认 UI、批量保存、分类、会员、额度、首页通勤卡和动态主动作均未改变。
- 剩余风险：Windows 无 Xcode/Swift/iPhone，新增纯策略与测试仍需 macOS 编译/XCTest，并用真机 13:48/22:55 真实记录确认冲突展示；因此不标记 `VERIFIED`。
- 下一项：按锁定顺序执行 `FIX-007`，只原子化今日回放快照、呈现和扣次，不修改回放内容或 `FIX-005`。

### FIX-005：痕迹细查快照与 Sheet 首帧原子交付

#### 真机现象与补充证据

- 痕迹本周主卡已经明确显示 `12 笔`，点击“细查这一段 · 12 笔”后，Sheet 首次却显示 `本周 · 全部分类 · 0 笔 · 合计 ¥0.00` 和“这一段没有匹配的痕迹”。
- 不切换时间范围也会在十几秒后自动出现全部 12 条；切换时间或分类只是能够更快触发同一结果刷新。
- 主卡与稍后出现的细查列表金额、数量一致，说明数据、周范围和筛选结果本身正确；错误集中在 Sheet 第一次呈现时的状态交付。

#### 根因与历史归属

- `PERF-13`（提交 `01aaf6b`）为了避免细查列表在每次 SwiftUI 重绘时重复筛选、求和和分组，新增 `TraceDetailListSnapshot`，并把数量、总额、ID 和按日分组统一改为只读该快照。该优化方向和单次计算模型正确，不能回退为在 `body` 中重复扫描账本。
- 当前快照是独立的可空 `@State traceDetailListSnapshot`，Sheet 仍由另一个 `@State showTraceDetailSheet: Bool` 呈现。打开动作在同一次事件里先写快照、再把 Bool 设为 `true`，但 Bool Sheet 的首次内容可能仍来自写入前的视图状态。
- 细查视图把 `nil` 快照直接映射为 `[]`、`0` 和 `¥0.00`，没有区分“尚未收到快照”和“有效快照确实为空”，因此首帧出现了错误空态。
- 后续痕迹周/月后台准备、预热或其他状态发布会引发父视图再次重绘；此时 Sheet 才读到此前已经计算完成的 12 条，所以用户观察到不操作也会在十几秒后自动出现。
- `LazyVStack` 只负责已有分组中可见行的按需构建，不参与筛选快照生成，也不会让 12 条数据等待十几秒；本问题不是列表懒加载速度，而是 Sheet 首帧使用了陈旧状态。

#### 定向优化方案

1. 把“是否呈现细查”和“本次细查初始快照”合并为一个可识别的 Sheet payload，使用原子 destination / `.sheet(item:)`，只有有效快照准备好后才呈现。
2. 从周/月主卡进入时，优先把该卡已经准备好的同一份 `TraceChapterSnapshot.items` 传入细查 payload，确保主卡 `12 笔` 与 Sheet 首帧来自相同范围、账本修订和记录集合。
3. 保留 `PERF-13` 的单次筛选、总额和按日分组快照，不允许为了修首帧问题恢复 `body` 内多次 `filter / reduce / Dictionary(grouping:)`。
4. Sheet 打开后切换本周、本月、本年、自定义时间或分类时，继续按新 key 更新同一份快照；旧 key 结果不得覆盖新筛选。
5. 快照尚未准备好或账本刚发生变化时，显示明确的轻量整理态或保留上一份有效内容，禁止把 `nil` 当作真实 0 笔；只有有效计算结果为空时才显示“没有匹配的痕迹”。
6. 保留 `LazyVStack`、当前卡片、筛选器、编辑/删除、Sheet 高度和主题视觉，不借本项重做细查 UI。

#### 冻结边界

- 不改变本周/本月/本年、自定义日期和分类筛选含义，不改变记录数量、金额合计、日期排序和同日排序。
- 不改变痕迹周/月主章节快照、空闲预热、照片按需加载、额度、回放、编辑、删除、补图和路由语义。
- 不恢复主线程重复扫描，不引入固定 `asyncAfter` 等待 Sheet，也不以人为延迟掩盖状态竞态。
- 不修改首页、复盘、AI 指令台、主题体系、存储、同步、会员、`COPY-02` 或 `ARCH-03`。

#### 必须补齐的回归

1. 主卡显示 12 笔时，第一次点击细查的首个有效画面即为 12 笔，不能先出现 0 笔空态。
2. 不做任何操作、不依赖后台周/月任务完成，细查内容仍应即时稳定显示。
3. 关闭后立即重开、快速重复点击、周/月主卡分别进入，数量与对应主卡一致且不串范围。
4. Sheet 内切换本周、本月、本年、自定义时间和分类时，只显示当前 key 的结果，旧结果不得延迟回写。
5. 打开期间新增、编辑、删除记录后，快照按新账本修订更新；刷新过程中不闪成 0 笔。
6. 真实 0 笔范围仍显示正确空态，必须与“快照尚未就绪”明确区分。
7. 100 / 1,000 条和真实照片账本下，首次进入、筛选和长列表滚动无明显 hitch；`LazyVStack` 和单次派生快照不得回退。
8. Dynamic Type、VoiceOver、Reduce Motion 和交互式下滑关闭不产生重复 Sheet、空白或陈旧结果。

#### 当前记录

- 日期：2026-07-18。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前唯一任务切换为 `FIX-006`。
- 实现：新增 `TraceDetailPresentationPayload`，打开细查时同步完成一次 `TraceDetailListSnapshot` 并通过 `.sheet(item:)` 携带；Sheet 首帧直接使用 payload 的初始快照，后续筛选、账本修订和编辑删除继续发布同一 key 模型的新快照；移除独立 Bool 呈现状态，快速重复打开只接受一个 payload。
- 修改文件：`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、本文档。
- 验证证据：新增 payload 初始记录/金额与重复 Sheet 请求测试；静态门禁确认 `.sheet(item:)`、初始快照参数和零 Bool 分离；`git diff --check`、体验静态门禁和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：`PERF-13` 单次筛选、ID/总额/日期分组、`LazyVStack`、本周/月/年/自定义筛选、排序、编辑删除、照片、痕迹主章节/预热、主题和路由目的地均未改变；没有抽象全局 Sheet。
- 剩余风险：Windows 无 Xcode/iPhone，需真机确认首个有效画面即为主卡数量、筛选切换时旧内容承接、交互式关闭与 1,000 条滚动；因此不标记 `VERIFIED`。
- 下一项：按锁定顺序执行 `FIX-006`，只修查询指标 scope。

### FIX-007：今日回放快照、呈现与额度原子化

#### 真机现象

- 首页已经显示“今天记下了 3 笔”、今日合计 ¥19.40，记录列表也能看到三条真实记录。
- 点击“听今日回放”后，首次打开的回放 Sheet 却显示 `今天还没有记录，先记一笔吧`，证明回放首帧没有拿到首页当前账本内容。
- 该现象与 `FIX-005` 的“主卡 12 笔、细查首帧 0 笔”高度一致，但今日回放还涉及免费次数扣减和完成状态，风险更高。

#### 根因与历史归属

- `PERF-10`（提交 `01aaf6b`）把今日记录、播放章节和时长收敛为 `BillPlaybackSheet.ContentSnapshot`，避免播放索引和动画推进时反复扫描完整账本。不可变快照方向正确，不能回退。
- `HomeView` 同时保留 `@State showPlayback: Bool` 和独立 `@State playbackContentSnapshot`；后者初始为 `ContentSnapshot.empty`。
- `presentTodayPlaybackSheet()` 在同一次事件中先写入真实快照、更新 ID，再把 Bool 设为 `true`；Bool Sheet 的首次内容可能仍捕获写入前的 `.empty`，随后 `BillPlaybackSheet` 按 `todayItems.isEmpty` 显示真实空账本文案。
- 这不是 3 条记录计算缓慢，也不是回放章节生成失败；真实快照已同步计算，但没有与 Sheet destination 原子交付。
- 免费用户路径在 `presentTodayPlaybackSheet()` 之前调用 `markTodayPlaybackStarted`，因此若首帧误用 `.empty` 后用户直接关闭，本次免费回放次数可能已经消耗；空快照的 `onDisappear` 不会标记 80% 完成，但无法回退已扣次数。

#### 定向优化方案

1. 用一个可识别的 `TodayPlaybackPresentation`（或等价 destination）同时持有本次 `ContentSnapshot`、唯一 ID 和必要的来源状态，使用 `.sheet(item:)` 原子呈现，移除 Bool 与内容分离的首帧竞态。
2. `.empty` 不再作为“尚未准备”的可呈现哨兵；真正 0 笔也必须是一份带当前 `sourceRevision` 和 `dayKey` 的有效快照，明确区分“合法空账本”和“未准备状态”。
3. 先基于当前账本修订生成并校验快照，再接受播放开始；非空快照成功进入唯一 presentation 后才记录开始/扣减额度，快速重复点击不得扣两次。
4. 真实空账本继续展示现有空态，但不扣回放次数、不记录已开始，也不伪装成一次完成。
5. Sheet 关闭时只使用本次 presentation 内的不可变快照计算进度和完成签名；播放期间新增/编辑记录仍留到下次打开，不污染当前章节。
6. 保留 `PERF-10` 的“打开时一次生成、播放期间只推进索引”，不恢复 `body` 内筛选、排序或 `LifeMarkService` 聚合。
7. 不使用固定延迟或下一轮 `asyncAfter` 猜测状态提交；修复依靠 destination 数据完整性，而不是等待重绘。

#### 冻结边界

- 不改变今日回放记录筛选、章节内容、章节顺序、时长公式、播放节奏、暂停/重播、胶片、完成动作和现有 UI。
- 不改变免费额度常量、会员权益、首次提示、第一笔保存承接、会员提示和“明确开始才扣次数”的产品原则。
- 不改变首页主动作、今日记录列表、宠物、保存后提示预算、路由、主题、存储或同步。
- 不借本项修改 `COPY-02` 播放文案、周记/月章、`FIX-005` 细查实现或 `ARCH-03` 页面拆分。

#### 必须补齐的回归

1. 首页有 3 笔时，第一次点击回放的首个有效画面即包含这 3 笔对应章节，不能先显示空账本文案。
2. 关闭后立即重开、连续快速点击和从第一笔提示进入时，均只呈现一个 Sheet、使用一份快照、扣一次额度。
3. 免费用户的首次提示、普通后续播放和额度剩余 1 次路径，只有有效非空回放开始后才扣一次；空页或呈现失败不得扣次。
4. 会员路径不受次数限制，但同样不能出现 `.empty` 首帧或重复开始事件。
5. 真实 0 笔账本显示现有空态且次数不变；0 笔与未准备状态不能共用同一哨兵。
6. 播放期间新增、编辑或同步记录不改变当前章节；关闭后再次打开才使用新账本修订。
7. 跨午夜、切 Tab、进后台、交互式下滑关闭和会员页续接不出现旧快照、重复 Sheet、错误完成或路由丢失。
8. 100 / 1,000 条账本和真实照片下，快照生成、Sheet 首帧和连续播放无明显 hitch；播放期间不重新扫描账本。
9. XCTest 同时覆盖内容快照确定性和 presentation/额度状态机，不能只测试 `makeContentSnapshot` 的纯计算结果。

#### 当前记录

- 日期：2026-07-18。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前唯一任务切换为 `FIX-005`。
- 实现：新增 `TodayPlaybackPresentationPayload` 与接收/扣次策略；父页面改为 `.sheet(item:)` 原子传入不可变 `ContentSnapshot`，移除独立 `showPlayback`、`playbackContentSnapshot` 和手工 Sheet ID；只有准备完成且非空的 payload 才记录播放开始和扣次，合法空账本可显示原空态但不扣次，已有 presentation 时忽略重复启动。
- 修改文件：`NativeDemoApp/Views/HomeView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、本文档。
- 验证证据：新增未准备快照拒绝、单一活跃 payload、合法空账本零扣次测试；体验静态门禁确认零 Bool/快照分离；`git diff --check`、生活语义、体验静态门禁和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：`PERF-10` 内容生成、章节、顺序、时长、播放控制、完成动作、会员提示、额度常量、第一笔承接、首页动态主动作、主题和路由目的地均未改变。
- 剩余风险：Windows 无 Xcode/iPhone，`.sheet(item:)` 的 SwiftUI 生命周期、快速连点、交互式关闭、跨午夜与真实剩余 1 次路径仍需真机签收；因此不标记 `VERIFIED`。
- 下一项：按锁定顺序执行 `FIX-005`，仅原子化痕迹细查 payload，不抽象为全局 Sheet 框架。

### FIX-006：单类语义主题的结果总览指标

#### 真机现象

- 输入 `这周咖啡饮品几次？` 后，查询结果正确找到 2 笔咖啡饮品、合计 ¥19.80，最高单笔正文也正确。
- 下方结果总览仍显示 `最高分类：餐饮 / 该类金额：¥19.80`，与“本周的咖啡饮品记录”和总金额重复；用户已经明确限定咖啡主题，不需要再次被告知这些记录属于餐饮。
- 该问题与 `LOGIC-14` 修复的“查餐饮仍显示最高分类：餐饮”本质相同，只是咖啡通过生活线索意图进入，遗漏了同一指标策略。

#### 根因与历史归属

- `LOGIC-14` 新增 `AICommandResultMetrics.Scope.crossCategory / singleCategory`，普通 `categoryIntent` 明确只有一个分类时使用“有记录 / 平均每笔 / 最高单笔”。
- 当前 `aiCommandQueryMetricScope` 首先要求 `lifeMarkIntent == nil`；只要识别到生活线索，无论该线索实际覆盖一个还是多个分类，都会直接返回 `.crossCategory`。
- `咖啡` 同时能命中餐饮分类意图和 `coffee_drink` 生活线索；查询优先使用生活线索筛选，因此指标范围被强制判为跨分类。
- 昨日 XCTest 只覆盖“明确餐饮”“未指定分类”和 0/1 笔边界，没有覆盖咖啡、奶茶、雨天通勤等“语义主题但底层只有一个分类”的路径。

#### 定向优化方案

1. 指标范围由识别阶段的**有效结果域**决定，不再简单用“是否存在 lifeMarkIntent”二分。
2. 普通单分类意图，以及 categories 明确只有一个分类的生活线索/语义 facet，统一使用聚焦指标：`有记录 / 平均每笔 / 最高单笔`。
3. 咖啡饮品、奶茶、可乐、雨雪冷热通勤等底层只允许一个分类的主题，都属于聚焦范围；结果不再重复显示该基础分类。
4. 兴趣装备、旅行出行、健身恢复、宠物照护等确实可能跨多个分类的语义集合，继续保留 `最高分类 / 该类金额`，因为分类构成仍有信息价值。
5. 用户明确询问“分类、构成、哪类最多、占比”时，无论当前主题是否单类，都进入分类分布结果；不能因为聚焦范围隐藏用户主动请求的分类信息。
6. 未指定任何范围的查询，即使实际结果碰巧只有一个分类，也继续使用跨分类指标，保持 `LOGIC-14` 的“不能根据结果猜查询意图”边界。
7. 只调整指标 scope 元数据和测试，不改变查询结果、标题、正文、证据列表、图表、主题和布局。

#### 冻结边界

- 不改变咖啡/餐饮/生活线索的识别、时间范围、记录集合、金额、排序和最高单笔正文。
- 查询继续只读；不修改补记、对比、额度、会员、保存、存储、同步或远程 AI。
- 不根据结果中出现的分类数量反推范围；范围必须来自识别到的分类或语义定义。
- 不借本项实施 `AI-03` 的高温、爱好等新能力，也不修改 `COPY-02` 或 `ARCH-03`。

#### 必须补齐的回归

1. `这周咖啡饮品几次 / 这周咖啡花了多少` 使用聚焦指标，不显示“最高分类：餐饮”。
2. 奶茶、可乐等单类子主题同样使用平均每笔和最高单笔。
3. 雨天通勤以及后续 `AI-03` 的高温/冷天/雪天通勤若底层仅交通，也使用聚焦指标。
4. 明确餐饮查询继续保持 `LOGIC-14` 当前正确结果。
5. 未指定分类但结果碰巧全是餐饮时，仍显示跨分类指标。
6. 兴趣装备、旅行等多分类语义集合保留最高分类；若用户明确询问分类构成，继续展示分类分布。
7. 0、1、多笔以及同额记录下平均每笔、最高单笔、活跃天数语义正确。
8. Dynamic Type、VoiceOver 和多主题下仅文案值变化，不引起卡片结构、滚动性能或可访问性回退。

#### 当前记录

- 日期：2026-07-18。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前唯一任务切换为 `COPY-03`。
- 实现：`aiCommandQueryMetricScope` 不再以“存在生活线索”强制判定跨分类，而是读取 `LifeMarkQueryIntent.categories` 或普通分类意图的去重定义域；单一分类使用“有记录 / 平均每笔 / 最高单笔”，多分类或用户明确询问分类/构成/占比时继续使用“最高分类 / 该类金额”。
- 修改文件：`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、本文档。
- 验证证据：新增咖啡饮品单类、健身恢复多类和咖啡显式分类构成测试；静态门禁锁定语义定义域；`git diff --check`、生活语义、体验静态门禁和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：咖啡/生活线索识别、时间范围、记录集合、金额、最高单笔正文、证据列表、图表、查询只读、补记、额度、会员、主题与布局均未改变，没有为咖啡写特殊分支。
- 剩余风险：Windows 无 Xcode/iPhone，需真机验证咖啡/奶茶/通勤与多分类生活线索的指标标题、Dynamic Type 和 VoiceOver；因此不标记 `VERIFIED`。
- 下一项：按锁定顺序执行 `COPY-03`，先建立事实化单条标签，再进入宠物上下文。

### INT-03：全局日期面板的时间选择交互

#### 真机现象与全局范围

- 记账主页打开修改时间后，小时和分钟只能分别点击 `- / +` 单步调整；从 22:55 改到较远时间需要连续点击很多次，分钟最多可能点击几十次，操作不够直接。
- 当前小时在 23 与 0、分钟在 59 与 0 之间循环，但不会联动日期或小时；用户需要理解两套独立步进规则，且容易在连续点击中越过目标值。
- 全局盘点确认以下 6 个入口复用 `WarmRecordDatePanel`，具有相同问题：
  1. 记账主页 `RecordView`。
  2. 普通账单编辑 `RecordEditSheet`。
  3. 首页/痕迹共用聚焦编辑器 `FocusedRecordEditor`。
  4. 痕迹内联编辑 `StatsTraceInlineRecordEditor`。
  5. 记忆详情编辑 `MemoryAttachmentViews`。
  6. OCR 确认编辑 `OCRConfirmSheet`。
- 痕迹筛选中的开始/结束日期只调整“天”，不编辑小时和分钟，不属于本项，避免把记录时间选择与统计范围选择混改。

#### 产品判断

当前 `+ / -` 适合微调，不适合作为唯一时间输入方式。推荐保留现有暖色日历和页面结构，把时间区域收敛为两层操作：

1. **直接选择**：点击当前时间 `22:55`，打开系统语义一致的小时/分钟滚轮，可快速滑到任意 `00:00～23:59`。
2. **轻量微调**：时间区域仍可保留小型前后调整动作，但只作为可选辅助；不能要求用户依靠连续点击完成大跨度修改。

不推荐直接在每个页面内常驻大型滚轮，因为会显著拉高日历面板高度，并挤压痕迹内联编辑等窄宽场景；也不推荐自由文本输入 `HH:mm` 作为主路径，容易产生格式、键盘和无效时间问题。

#### 推荐交互方案

1. `WarmRecordDatePanel` 保留月份、星期和日期网格；底部小时/分钟步进器改为一个清晰的时间入口，例如 `时间  22:55  ›`，视觉继续使用当前主题 Capsule/圆角 Token。
2. 点击时间入口后，在紧凑 Sheet 或适配尺寸的弹出层中展示双列滚轮：小时 `00～23`、分钟 `00～59`；小屏、内联编辑和大字模式统一使用 Sheet，避免被父容器裁切。
3. 滚轮使用局部 `draftTime`，滑动时只更新选择器内部显示；点击“完成”后才把小时、分钟一次写回原 `Date` 并调用一次 `onSelectionChanged`。
4. 点击“取消”或下滑关闭不修改原时间；重新打开从当前真实 selection 开始，不保留上一次未提交草稿。
5. 可提供 `现在` 快捷动作，但只在所选日期为今天时显示；点击后使用当前小时分钟并立即更新本地草稿，仍需“完成”提交。历史日期不显示含义模糊的“现在”。
6. 日期只由日历网格修改；时间滚轮跨过 23/0 不自动改变日期，避免用户无意跨天。秒继续规范为 0，保持当前保存结果。
7. 若外部 selection 在选择器打开期间因记录切换、OCR 行切换或同步更新而改变，关闭当前时间选择并以新记录状态为准，禁止把旧草稿写到新记录。
8. 不使用持续按压计时器或高频绑定驱动主页面；滚轮滑动不得触发预填、分类推荐、生活线索聚合、SQLite 保存或 OCR 提交。

#### 为什么必须一次提交

- 记账主页的日期变化会参与预填、分类推荐和记录输入辅助；滚轮若每经过一个分钟都写 Binding，会制造连续后台请求和界面更新。
- 记忆详情的 `onSelectionChanged` 当前会调用 `saveDraftChanges()`；直接绑定滚轮可能在一次滑动中产生大量增量保存。
- OCR 确认会在日期变化后提交当前行日期；逐刻度写入会增加状态竞争和误保存风险。
- 因此性能和数据边界要求统一采用“选择器内部预览，完成时一次提交”，而不是简单换成实时绑定的系统滚轮。

#### 冻结边界

- 不改变日期、时间的保存含义、时区、分类推荐最终规则、用户锁定、OCR 识别/确认、编辑保存和草稿跨 Tab 行为。
- 不改变记账主页金额、预览卡、保存按钮、OCR 入口、独立日期入口及 `UI-FIX-02` 已冻结的条件显示逻辑。
- 不调整日历视觉、月份切换、页面卡片、主题、会员、额度、路由、存储或同步。
- 本项只处理记录时间编辑；不顺带重做痕迹统计日期范围、周/月选择或 `ARCH-03` 页面拆分。
- 是否禁止未来日期/时间属于独立业务规则，本项保持当前可选范围，不在交互优化中暗改历史数据语义。

#### 日期与时间边界

1. 小时范围 `00～23`，分钟范围 `00～59`，显示固定两位；提交后秒为 0。
2. 选择 00:00、23:59、月初/月末、闰年 2 月 29 日时保持所选日期，不因时间滚动跨日。
3. 日历月份切换不改变实际 selection，只有点击某一天才提交日期；时间选择不改变当前展示月份。
4. DST 不存在的本地时间应通过 Calendar 的有效时间策略规范化，不能产生无效 Date 或崩溃；重复时刻使用确定性规则。
5. 取消、下滑关闭、切记录、切 OCR 行和页面消失必须零写入；“完成”重复点击只提交一次。

#### 无障碍与反馈

- 时间入口触控区域不低于 44pt，VoiceOver 朗读“修改时间，当前 22 点 55 分”。
- 滚轮使用可调整语义，支持 VoiceOver 上/下滑改变值；“取消”“现在”“完成”顺序明确。
- Dynamic Type 下操作纵向承接，不把小时和分钟压缩到不可读；Reduce Motion 下不使用弹簧位移。
- 选择完成可提供轻量触觉反馈，但不逐分钟震动。

#### 必须补齐的回归

1. 6 个共用入口均可点击时间直接滚动选择，不再需要几十次单步点击。
2. 从 22:55 改到 08:05、00:00、23:59 均只提交一次，日期保持不变。
3. 滚轮快速滑动时，预填/分类任务、记忆详情保存和 OCR 更新不会逐刻度触发。
4. 取消、下滑、切记录、切 OCR 行和页面离开均保留原时间；完成后各入口保存结果一致。
5. 今天显示“现在”，历史日期不显示；使用“现在”不会意外改回今天。
6. 新建记录、已有记录编辑、补图后的记忆详情、OCR 单条和多条确认均不串行、不写错记录。
7. 00/23 小时、00/59 分钟、月末、闰日、时区/DST 有效性通过纯策略 XCTest。
8. iPhone 小屏、常规屏、特大/无障碍字号、VoiceOver、Reduce Motion 和多主题布局通过。
9. 完整 Windows 门禁、Xcode Debug/Release、XCTest 和真机快速滚动/连续开关选择器无编译、状态或性能回归。

#### 当前记录

- 日期：2026-07-18。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前唯一任务切换为 `MEMBER-03`。
- 实现：`WarmRecordDatePanel` 将小时/分钟 `- / +` 步进器替换为 44pt 时间入口；紧凑 Sheet 内使用 00～23 与 00～59 双列滚轮和局部草稿，只有“完成”通过 `RecordTimeSelectionPolicy` 一次写回并把秒归零。取消、下滑、页面离开或外部记录/OCR 行变化时不提交；“现在”只在所选日期为今天时显示，且只更新草稿。痕迹自定义开始/结束日期显式传入 `showsTimeSelection: false`，继续仅调整天。
- 修改文件：`NativeDemoApp/Views/Components/WarmRecordDatePanel.swift`、`NativeDemoApp/Views/StatsTraceFilters.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`scripts/experience_static_check.ps1`、本文档。
- 验证证据：新增 22:55→08:05、00:00/23:59、闰日、越界夹取和 DST 有效时间测试；静态门禁确认滚轮局部草稿、旧步进器移除、痕迹范围保持日级；`git diff --check`、生活语义回归、体验静态门禁和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：未修改日期/时间保存含义、时区来源、分类推荐、用户锁定、OCR 识别/确认、各编辑器保存与草稿跨 Tab 规则；未调整日历月份/日期视觉、记账主页条件入口、主题、会员、额度、路由、存储、同步或未来时间业务规则。
- 剩余风险：Windows 无 Xcode/iPhone；嵌套 Sheet、滚轮 VoiceOver、超大字号、小屏、DST 真机区域设置和六入口逐一保存仍需真机签收，因此不标记 `VERIFIED`。
- 下一项：按锁定顺序执行 `MEMBER-03`，只按身份收敛会员信息层级，不改变 StoreKit 或权益。

### MEMBER-03：会员详情状态化与信息去重复

#### 真机现象

- 永久会员详情页顶部已经显示“你的永久记录已开启 / 永久有效 / 把生活长期留住”。
- 紧接着的“免费与会员的差别”再次用 `省力记 / 长期回望` 解释免费与会员。
- 下一段“会员核心价值”第三次用同样的 `省力记 / 长期回望` 展开近似说明。
- 页面继续向下才进入真正与当前永久会员有关的个性化档案、连续记录天数、记录条数和月份等内容；有效信息被重复销售文案推迟。

#### 为什么被改成现在这样

- 2026-06 版本原本存在两套不同层级：
  - `boundaryRows` 用三行说明生活场景、生活回放和账单整理的免费/会员差异。
  - `benefits` 用七条具体权益说明无限回放、AI 分析、周月内容、连续导入、完整场景、今日回放和主题，并默认折叠。
- 2026-07-15 的 `MEMBER-01` 为了解决权益过多、额度体系难理解和折叠后核心价值不可见，将两套内容都收敛为 `省力记 + 长期回望`：
  - 对比区继续承担“免费与会员有什么不同”。
  - 权益区改为始终可见的两项核心价值。
- 同一提交又把已购会员顶部文案改成“按真实记录长期整理”，修正过去把本地规则泛称为 AI 的承诺问题。
- 三项修改分别有合理目的，但没有按“未购买 / 已订阅 / 永久会员”重新编排页面，因此同一双层价值在永久会员状态下连续出现，形成明显重复。

#### 产品判断

重复感成立，问题不是单句写得不好，而是页面没有根据用户当前任务切换职责：

- **未购买用户**需要回答：会员比免费多什么、为什么值得买、选哪个套餐。
- **已订阅用户**需要回答：当前权益是否有效、什么时候续费、已解锁什么、如何管理订阅。
- **永久会员**需要回答：永久状态是否生效、当前档案积累了什么、照片/同步边界是什么；不需要再次接受免费与会员销售对比。

当前页面对三种状态使用同一组 `memberBoundarySection + benefitsSection`，因此购买完成后仍像购买页，而不像会员详情页。

#### 定向优化方案

1. 建立状态化信息顺序，不改变同一 Sheet 和现有主题：
   - **非会员**：入口场景 Hero → 套餐 → 一张合并后的“免费与会员”双价值对比 → 永久会员预览 → 隐私/协议。
   - **月度/年度会员**：权益状态与有效期 → 一张精简“已解锁”摘要 → 订阅管理/恢复 → 当前长期档案 → 边界说明。
   - **永久会员**：永久状态 → 直接进入个性化长期档案 → 必要的同步/照片边界 → 隐私/协议；不再显示免费对比和重复核心价值卡。
2. 非会员页面保留 `省力记 / 长期回望` 两行，但把“差别”和“核心价值”合并为同一个组件：每行同时说明免费边界、会员提升和用户价值，不再上下重复。
3. 已购会员如需表达已解锁内容，只显示一条紧凑摘要或两个状态标签，例如 `连续整理已开启 / 长期回望已开启`，不再重复整段营销文案。
4. 永久会员顶部文案只承担状态确认：永久权益已生效、账号/本机边界准确；价值证明交给下方真实档案数字和代表记录，不再增加第三句抽象升华。
5. 将 `benefits` 与 `boundaryRows` 收敛为一份可测试的 `MembershipValueDefinition`（或等价模型），由页面状态决定呈现方式，避免两组数组以后再次发生文案漂移和重复。
6. 保留不同入口 `entryContext` 的购买 Hero；用户从 OCR、回放、场景包或 AI 指令台进入时，仍先解释当前受限能力，不因全局去重丢失上下文。

#### 推荐保留与删除

| 当前区域 | 非会员 | 月/年会员 | 永久会员 |
|---|---|---|---|
| 场景化 Hero | 保留 | 改为状态摘要 | 改为永久状态摘要 |
| 免费与会员的差别 | 保留并合并价值说明 | 删除 | 删除 |
| 会员核心价值两张卡 | 合并进对比区后删除 | 改为紧凑已解锁状态 | 删除 |
| 套餐选择 | 保留 | 仅在续费/升级需要时展示 | 删除 |
| 永久会员档案 | 预览/说明 | 保留 | 提前到状态卡之后，作为页面主内容 |
| 隐私、协议、照片边界 | 保留 | 保留 | 保留 |

#### 冻结边界

- 不改变会员 Product ID、价格来源、套餐顺序、交易验证、`finish`、恢复购买、账号绑定和登录后续购。
- 不改变免费额度常量、会员权益、共享额度池未实施结论、购买/取消/失败状态和 StoreKit 沙盒行为。
- 不删除法律、隐私、照片仅本机和账单字段同步边界；不得用“永久记录”暗示记忆照片已云备份。
- 不修改会员长期档案的数据口径、后台快照、记录数、连续天、周/月跨度和生活线索聚合。
- 不借本项重做全局主题、首页、设置页或其他会员入口，也不启动 `ARCH-03`。

#### 必须补齐的回归

1. 未购买用户仍能在不展开隐藏内容的情况下理解免费边界、两项会员价值和套餐选择，但同一价值只出现一次。
2. 月度/年度会员看到有效期、已解锁状态和管理入口，不再看到完整免费对比销售页。
3. 永久会员首屏确认永久生效，随后直接看到真实长期档案；“省力记 / 长期回望”不连续重复两遍。
4. 从设置、OCR、回放、场景包、AI 指令台、痕迹和永久主题入口打开时，场景化信息与当前状态不冲突。
5. 未登录购买、登录续购、购买失败/取消、恢复无权益、恢复成功和永久会员路径均不因条件布局丢失按钮或目标。
6. 会员状态切换后页面立即采用正确结构，不短暂显示另一身份的销售内容。
7. 账单字段同步、照片仅本机和本地备份说明保持准确，不出现“照片永久随账号保留”的误导。
8. 小屏、Dynamic Type、VoiceOver 和 Reduce Motion 下层级清晰；VoiceOver 不连续朗读两组相同价值。
9. 完整 Windows 门禁、Xcode Debug/Release、XCTest 和 StoreKit 真机矩阵通过。

#### 当前记录

- 日期：2026-07-18。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前唯一任务切换为 `AI-03`。
- 实现：新增 `MembershipDetailPresentationPolicy`，按非会员、订阅会员、永久会员决定页面层级；`MembershipValueDefinition` 合并原 `benefits` 与 `boundaryRows`。非会员保留入口场景 Hero、原套餐顺序/价格与唯一一张“免费与会员”对比；订阅会员显示权益状态、紧凑已解锁摘要、App Store 管理/恢复入口和长期档案；永久会员从“永久会员已生效”直接进入真实档案，不再出现套餐、免费对比或重复价值卡。已购状态增加准确的账单字段同步/照片仅本机与本地备份边界，并保留协议、隐私入口。
- 修改文件：`NativeDemoApp/Views/MemberPricingView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`scripts/membership_value_lint.py`、`scripts/accessibility_lint.py`、`scripts/experience_static_check.ps1`、本文档。
- 验证证据：新增三种会员身份结构测试；会员价值 lint 改为单一定义并禁止旧重复区域，体验静态门禁锁定状态化结构和 StoreKit 真机矩阵；`git diff --check`、生活语义、文案、会员、无障碍与体验门禁及 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：未修改 Product ID、价格来源、套餐顺序、购买/取消/失败、交易验证、`finish`、恢复、账号绑定、未登录购买→登录后续购、免费额度、会员权益、长期档案口径/快照、主题或其他会员入口路由。
- 剩余风险：Windows 无 Xcode/iPhone/StoreKit；身份切换瞬间布局、App Store 管理链接、各入口 Hero、未登录续购、恢复成功/失败、VoiceOver 和小屏仍需统一真机签收，因此不标记 `VERIFIED`。
- 下一项：按锁定顺序执行最后一项 `AI-03`，仅新增可信只读 facet 与名词短语识别，不修改补记写入门槛、远程能力或暖标签事实边界。

### COPY-03：单条标签事实化与跨记录叙事归位

#### 真机现象

- `停车费` 的单条情绪标签显示 `车停稳了`；首页第一笔摘要进一步拼成“车停稳了，这一天刚翻开第一页”，拟人化和模板痕迹明显，既不自然，也没有增加可回看的事实。
- 周末早餐 `巧婆红汤馄饨（云密城店）` 的情绪标签显示 `周末路上和饭点都有了`。同日存在一笔停车费，系统便把交通与餐饮组合成一次周末出行，但停车费未必代表出游，两笔也未必属于同一事件。
- 该组合标签显示在单条早餐编辑页，用户无法理解“路上”来自另一笔记录；如果后来删除或修改停车费，已存早餐标签仍可能保留，形成陈旧叙事。

#### 根因与历史归属

- `车停稳了` 由提交 `0fc1de3`（2026-07-06）加入 `HomeItem.refinedEmotionTag`，目标是把交通分类从“日常出行”改成更具体、更有温度的场景标签；停车费被直接映射为拟人化结果，没有区分“动作完成”和“费用记录”。
- `weekendOutingLine` 由提交 `b785e9f`（2026-06-22）引入，目标是利用天气、周末和同日记录给单笔增加上下文；当前条件只要求：
  - 日期为周末/节假日；
  - 同日存在任意交通分类；
  - 当前或同日存在餐饮分类。
- 条件满足后，即使没有景区、电影、公园、旅行、朋友或聚餐等强证据，也返回 `周末/假期路上和饭点都有了`；有弱娱乐词时则返回 `出门玩了一趟`。
- 该跨记录结果在新增记录时写入 `emotionTag`，但之后不会随相关记录编辑/删除自动重算，因此把动态的“当天组合观察”错误固化成单笔属性。
- 首页第一笔摘要又直接把 `displayEmotionTag` 与“这一天刚翻开第一页”拼接，放大了基础标签的不自然表达。

#### 产品判断

情绪标签可以有温度，但必须先守住归属：

1. **单条标签只描述单条记录**：停车费、早餐、咖啡、药品等标签只能使用该记录的标题、分类、时间和自身结构字段。
2. **跨记录关系属于聚合层**：同日交通＋餐饮、周末出游、一天的路线和饭点，应由今日小记、今日回放、痕迹或生活线索在读取当前账本时动态生成。
3. **暖语气不能替代事实**：`车停稳了`、`路上和饭点都有了` 看似有氛围，但不如 `停车费记下`、`周末早餐` 清楚。
4. **证据变化后叙事应变化**：跨记录观察必须按当前账本实时或快照计算，不能永久存进其中一笔记录。

#### 定向优化方案

1. 停车/停车费/车位的单条标签改为克制事实表达，推荐 `停车费记下`；不推断车辆已停稳、停车原因或地点。
2. 周末早餐使用单条事实标签，现有 `weekendDiningTag` 已能按时间输出 `周末早餐 / 周末午餐 / 周末晚饭`，应优先使用该规则。
3. `RecordMemoryContextService.enhancedEmotionTag` 不再把 `weekendOutingLine` 的跨记录组合写入单条 `emotionTag`；天气＋当前记录这类同记录上下文仍可保留。
4. 若同日确有交通、餐饮和景区/电影/公园/旅行/朋友等强证据，可在今日小记、回放或痕迹中动态说“一次周末外出”，但不能回写到早餐或停车费的单条标签。
5. 首页第一笔摘要不再机械使用任意情绪标签加“这一天刚翻开第一页”；优先输出一条具体事实，例如 `早上 7:47，先记下了一笔停车费。`，没有可靠细节时再使用克制通用句。
6. 为已存历史记录增加精确的旧系统标签校正，不做模糊全文迁移：
   - 标题/分类确认停车费且旧标签精确为 `车停稳了` 时，展示为新停车标签。
   - 餐饮记录旧标签精确为 `周末/假期路上和饭点都有了` 时，按该记录自身日期与时间回退为 `周末/假期早餐、午餐或晚饭`。
   - 不修改用户标题、备注，不根据金额或其他记录重新编造历史情节。
7. 复核 `周末出门玩了一趟 / 周末出门的路线 / 假期...` 等同源旧标签；只有确认属于该弱跨记录规则的精确系统文案才做展示校正，避免误伤用户原文。

#### 冻结边界

- 不改变分类推断、金额、日期、标题、用户“自己写一句”、场景包、OCR、保存、存储和同步语义。
- 不修改天气高温/雨雪等有结构字段支持的单记录上下文；不借本项重写全部情绪标签池。
- 不修改周记/月章播放文案；`COPY-02` 继续等待单独确认，本项只处理单条记录标签与首页第一笔摘要。
- 不在本项实现 `AI-03` 查询能力，但要保证新查询不依赖这些暖文案作为事实。
- 不调整首页卡片结构、主题、宠物、会员、额度、路由或 `ARCH-03`。

#### 文案准则

- 首选：`对象/动作 + 记下`，例如 `停车费记下`、`周末早餐`。
- 可用：有当前记录强证据的一层上下文，例如 `热天补点清爽`、`雨天通勤`；暖语气不得隐去事实主体。
- 禁止：无证据完成态（车停稳了）、无归属组合态（路上和饭点都有了）、价值判断（值得/划算）、感受代言（你很开心/辛苦）和把同日两笔自动解释成同一行程。

#### 必须补齐的回归

1. 停车费新记录显示事实化标签，首页第一笔摘要自然且包含停车费事实，不出现“车停稳了”。
2. 周末早上新增早餐，即使当天已有停车、地铁或打车，也只显示 `周末早餐` 或等价单条表达。
3. 同日停车＋早餐不会把早餐固化成“路上和饭点都有了”；删除交通记录后标签和首页叙事不残留旧组合。
4. 周末交通＋餐饮＋明确景区/电影/朋友证据可在聚合层形成周末外出观察，但两条单记录标签仍各自独立。
5. 历史精确旧标签可在不批量改写用户数据的情况下正确显示新文案；非目标标签保持不变。
6. 工作日早餐、周末午餐/晚饭、节假日餐饮、停车费/车位/停车场等同义词和 0/1/多条同日记录通过确定性测试。
7. 今日小记 1 笔、2 笔、3 笔以上都不机械放大低价值标签；天气、晚归通勤等高证据优先级保持。
8. AI 指令台、生活线索和回放不因旧暖标签校正而误丢真实分类/标题证据。
9. 文案 lint 增加弱组合句和无证据完成态防回流；完整 Windows、Xcode、XCTest 与真机页面矩阵通过。

#### 当前记录

- 日期：2026-07-18。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前唯一任务切换为 `PET-02`。
- 实现：停车/停车费/车位的新标签改为 `停车费记下`；历史记录只有在分类与标题证明停车且旧标签精确为 `车停稳了` 时展示校正。餐饮记录中精确命中旧周末组合系统文案时，按本条日期与时刻回退为周末/假期早餐、午餐或晚饭；交通记录回退为本条路线标签。`RecordMemoryContextService` 不再把同日交通＋餐饮组合故事写入单条记录；首页只有一笔时改由 `singleRecordTodayStoryLine` 描述时刻与当前记录，不再拼接任意暖标签。
- 修改文件：`NativeDemoApp/Models/HomeItem.swift`、`NativeDemoApp/Services/RecordMemoryContextService.swift`、`NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`scripts/life_semantic_regression.py`、本文档。
- 验证证据：新增停车新旧标签、周末早餐不受同日交通污染、历史弱组合精确回退与首页第一笔事实句测试；`git diff --check`、生活语义回归、体验静态门禁和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：未修改用户标题/备注/“自己写一句”、分类、金额、日期、场景包、天气结构字段、OCR、保存、存储、同步、周/月播放文案、首页卡片结构、主题、会员、额度、路由与动态主动作。
- 剩余风险：Windows 无 Xcode/iPhone；历史精确校正在真实旧账本中的展示、节假日餐饮和首页大字号仍需真机签收，因此不标记 `VERIFIED`。
- 下一项：按锁定顺序执行 `PET-02`，只统一宠物气泡生命周期和可信上下文消息，不改变像素动画、提示预算或首页主动作。

### AI-03：高价值语义维度查询与可信边界

#### 真机现象与当前缺口

- 痕迹列表中的通勤记录已经显示 `热天路上辛苦了`，其 `HomeItem.MemoryContext` 可保存 `weatherKind: hot` 和温度；AI 指令台输入 `高温通勤` 却返回“未识别”。
- 当前识别器能从 `通勤` 得到交通分类，但 `高温` 不属于已有天气/生活线索意图；同时 `高温通勤` 没有“查一下、多少、哪天”等动作词和时间范围，查询评分不足，最终落入低置信度阻止。
- 即使用户改成“查一下高温通勤”，现有普通分类查询也可能只筛出全部交通/通勤，因为高温尚未作为独立上下文槽位进入结果过滤。
- `兴趣装备` 已有强关键词和 `interest_gear` 生活线索，但自然总称 `爱好类消费 / 兴趣消费` 尚未形成稳定别名；不能依赖展示文案 `爱好里的小投入` 偶然命中。

#### 产品判断

需要扩大指令台的可查询语义，但不能把全部 `displayEmotionTag` 当成事实索引。展示标签同时包含“事实”和“语气”，两者必须拆开：

| 类型 | 示例 | 是否可查询 | 依据与边界 |
|---|---|---|---|
| 结构化上下文 | 高温、低温、雨、雪、城市、外地、周末/节假日 | 是 | 以 `memoryContext`、日期和日历规则为主，展示文字只做受控旧数据回退 |
| 强场景语义 | 通勤、兴趣装备、学习、健身、宠物/宝宝照护、医疗、数字订阅、买菜、车主日常 | 是 | 必须由分类与明确标题/备注/稳定词组共同证明，不因单个宽泛词跨场景猜测 |
| 用户原文 | 用户自己写的标题、备注、商户或照片说明 | 是 | 可按原文查找，但结果必须展示原始记录作为证据 |
| 系统暖语气 | 辛苦了、给今天一点甜、认真吃一顿、添点好看、小投入 | 否 | 只负责界面温度，不能证明心情、原因、价值判断或金额大小 |

因此：

- `热天路上辛苦了` 中可查询的是 `高温/热天 + 通勤`，`辛苦了` 不进入事实判断。
- `爱好里的小投入` 中可查询的是有强物品或场景证据的 `兴趣装备/爱好消费`，`小投入` 不得解释为低金额或消费合理。
- 文案以后更换说法时，查询结果不能随展示 copy 失效；查询应绑定稳定 facet ID，而不是绑定完整标签句子。

#### 推荐的首批查询维度

1. **天气与出行组合**：高温通勤、冷天通勤、雨天通勤、雪天通勤；结构化天气优先，历史记录允许受控匹配 `热天路上 / 冷天出门 / 雨天通勤 / 雪天通勤` 等稳定事实片段。
2. **兴趣与成长**：兴趣装备/爱好消费、健身恢复、学习成长；“爱好消费”只聚合有明确装备、活动或课程证据的记录，不能把全部购物或娱乐都算进去。
3. **照护与家庭**：宝宝用品、宠物照护、医疗用药、家庭补给；继续使用现有强语义边界，避免“猫”“宝宝”等弱词误命中普通商品。
4. **固定与重复支出**：房租水电物业、手机话费、数字订阅、车主日常；依靠已有稳定定义，不根据温暖标签扩张。
5. **时间与地点上下文**：晚归/深夜通勤、周末/节假日相聚、外地/城市/旅行；只复述时间、日历和地点字段，不推断加班、关系或出行原因。

暂不纳入：孤立的“辛苦、开心、治愈、放松、值得、冲动、划算”等情绪或价值词；除非来自用户明确原文，也只能作为文本证据，不能上升为系统结论。

#### 定向优化方案

1. 新增稳定的 `AICommandSemanticFacet`（或等价纯模型），用 canonical ID 表示天气、场景、爱好、照护、固定支出和地点上下文；同义词只负责把自然语言归一到 facet。
2. 查询匹配优先使用结构化字段：`memoryContext.weatherKind / temperatureCelsius / cityName / semanticPlace`、日期、分类和现有生活线索定义；仅对缺字段的旧记录使用白名单标签片段回退。
3. 把当前“查记录 / 做对比 / 补遗漏”的任务选择传入识别上下文。在用户已经位于“查记录”任务时，`高温通勤`、`爱好类消费` 这类包含两个高置信实体的名词短语可直接视为只读查询，不再强迫补写“查一下”。
4. 任务先验只能降低只读查询的动作词要求，不能降低写入门槛；在任何任务下，缺少 `补记 / 补上 / 补录` 等强动作时不得创建候选或写账本。
5. 组合条件必须同时成立：`高温通勤` 只返回高温上下文中的通勤记录，不能返回全部通勤，也不能返回高温餐饮；`爱好消费` 只返回有明确兴趣证据的记录，不能返回普通衣服、日用品或全部娱乐。
6. 结果标题和依据明确说明匹配维度，例如“高温天气 · 通勤 · 2 笔”；不展示内部 facet ID，不声称用户辛苦、喜欢或消费合理。
7. 无匹配结果时区分“已识别但没有记录”和“无法识别”；历史记录缺少天气字段时明确说明证据不足，不能用当前天气补写历史。

#### 冻结边界

- 不把本地规则包装成远程 AI，不新增网络调用，也不生成账本中不存在的天气、地点、爱好、关系、原因或感受。
- 不修改 `HomeItem` 分类推断、OCR、保存字段、现有天气记录阈值、生活线索原始定义、补记确认、额度、会员和写入规则。
- 现有会员上下文能力保持原访问边界；识别到受限维度时应展示正确能力边界，不能改成“未识别”，也不能借本项调整价格或权益。
- 不修改列表页情绪标签文案、周记/月章播放文案或主题 UI；`COPY-02` 与 `ARCH-03` 继续冻结。

#### 必须补齐的回归

1. 在“查记录”任务输入 `高温通勤 / 热天通勤 / 酷热天上班`，均进入只读查询并只返回 `hot + commute` 记录。
2. 高温餐饮、普通天气通勤和无通勤证据的高温交通记录不得误入 `高温通勤`。
3. `辛苦了 / 热天辛苦 / 今天很热吗` 等弱语气或主观问题不能单独触发账本事实查询。
4. 结构化 `weatherKind == hot` 优先；旧记录只有受控标签片段时可回退；普通暖文案不能作为天气证据。
5. `爱好类消费 / 兴趣消费 / 兴趣装备` 能命中渔具、露营、骑行、摄影、模型/手办、乐器等强证据记录，不能吞入普通购物。
6. `小投入` 不作为金额范围；`爱好值得吗 / 买这个划算吗` 继续落入主观问题边界。
7. “查记录”任务允许高置信名词短语；“补遗漏”任务中同样输入不得生成补记；明确 `补记高温通勤` 仍只能进入现有受支持的通勤补记规则，不能伪造历史天气。
8. 雨、雪、冷、热、城市、外地、兴趣、学习、健身、宠物/宝宝、医疗、订阅等同义词和反例形成确定性 XCTest；相同输入与账本结果稳定。
9. 查询结果保留原始记录证据、Dynamic Type、VoiceOver 和多主题可读性；不引入新的主线程全账本扫描。

#### 当前记录

- 日期：2026-07-18。
- 状态：`IN_PROGRESS` → `CODE_DONE`；本轮九项全部达到 `CODE_DONE`，当前无 `IN_PROGRESS`。
- 实现：新增 `AICommandSemanticFacet` 与可解释的 `LifeMarkQueryIntent` 证据元数据。`高温/热天/酷热、冷天、雨天、雪天 + 通勤` 归一为结构化天气＋通勤组合，匹配时要求两个 facet 同时成立；优先读取记录自身 `memoryContext.weatherKind`，缺字段旧记录只允许 `热天路上 / 冷天出门 / 雨天通勤 / 雪天通勤` 等受控事实片段回退，不再以低金额交通推断通勤。`爱好类消费 / 兴趣消费 / 兴趣装备` 只匹配渔具、露营、骑行、摄影、模型手办、乐器等具体标题/场景，`爱好里的小投入` 等暖标签不进入可信查询文本；新增外地上下文 facet。AI 引擎接收当前 `ReviewTaskIntent`：仅“查记录”允许高置信名词短语直接进入只读查询；“补遗漏”中同样文本保持零候选零写入，明确 `补记高温通勤` 仍走原通勤预览且不附会天气。无结果时显示“已识别但无匹配”和证据不足说明；结果详情展示匹配维度并保留原始记录。
- 修改文件：`NativeDemoApp/Models/InteractionStateModels.swift`、`NativeDemoApp/Services/LifeMarkService.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`AI_CAPABILITY_CONTRACT_v1.md`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`scripts/life_semantic_regression.py`、`scripts/experience_static_check.ps1`、本文档。
- 验证证据：新增高温/冷热/雨雪同义词、查询任务名词短语、补遗漏零写入、hot＋commute 双条件、兴趣强证据/普通购物反例、暖语气/主观价值词阻止、已识别无记录、非会员能力边界与外地 facet 测试；生活语义门禁确认可信查询文本不读取 `emotionTag/displayEmotionTag`，查询匹配不再使用低金额兜底。最终 `git diff --check`、生活语义、体验、文案、会员、AI 能力、无障碍、可观测性、主题、迁移、真实照片夹具及 `python scripts/validate_release_gate.py --phase windows` 全部通过；仍只有既有 7 条文案 soft warning。
- 冻结边界复核：未新增网络调用，未修改分类推断、天气记录阈值、OCR、保存字段、补记确认、金额/工作日/候选时间、额度、会员价格/权益、存储、同步、主题、列表标签、周/月播放文案、首页动态主动作或 `ARCH-03`。
- 剩余风险：Windows 无 Xcode/Swift/iPhone；Swift 编译/XCTest、真实旧记录天气回退、会员锁定结果、Dynamic Type/VoiceOver、多主题和 1,000 条账本耗时仍需统一真机签收，因此不标记 `VERIFIED`。
- 下一项：本轮不再进入新代码任务；按用户要求统一执行 Xcode Debug/Release、XCTest、iPhone、StoreKit、权限、Dynamic Type、VoiceOver、Reduce Motion 与真实数据矩阵。

### 九项问题代码收口（2026-07-18）

- 最终状态：`FIX-004 / FIX-007 / FIX-005 / FIX-006 / COPY-03 / PET-02 / INT-03 / MEMBER-03 / AI-03` 全部 `CODE_DONE`；当前无 `IN_PROGRESS`。
- 最终 Windows 证据：完成新增 Swift 接线人工复核，修正 `HomeView` 的 VoiceOver 与前后台环境值误挂到通勤浮卡的问题；随后 `git diff --check`、`python scripts/life_semantic_regression.py`、`scripts/experience_static_check.ps1` 和 `python scripts/validate_release_gate.py --phase windows` 全部通过。门禁覆盖 100/1,000/5,000 条确定性夹具、真实尺寸照片夹具、迁移/元数据、生活语义、体验、文案、会员、AI 能力、无障碍、可观测性与主题检查；仅保留基线已有 7 条 soft copy warning。
- 真机编译补充修正（2026-07-18）：Xcode 报告 `lifetimeArchiveSectionTitle` 与 `membershipPresentationPolicy` 作用域不可见。根因是标题计算属性误放入 `LifetimeArchiveSnapshotComputation`；现已移回 `MemberPricingView`，快照计算层继续保持纯数据。`membership_value_lint.py` 新增作用域守卫，会员专项、体验静态检查与完整 Windows 发布门禁重新通过；会员三态、价格、Product ID、购买验证、恢复和登录续购均未改变。
- 边界总复核：首页状态驱动主动作及一个主入口＋安全次入口冻结；`PERF-09/10/13` 的变化驱动、不可变快照和单次派生未回退；`COPY-02` 周/月播放文案与 `ARCH-03` 页面拆分仍为 `NOT_STARTED`；未触碰用户既有 `StatCardView.swift`、`web-preview/app.js`、提示文档、`brand-assets/`、`tmp/` 和 `scripts/__pycache__/` 内容。
- 统一真机验收入口：按 `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 的 `FLOW-30`～`FLOW-34` 及原发版矩阵执行；未完成前九项不得标记 `VERIFIED`。

### PET-02：宠物消息生命周期与可信上下文文案

#### 真机现象

- 像素帧宠物的待机、点击和说话效果真机表现可接受，`PET-01` 的视觉方向保留。
- 点击宠物后出现的气泡不会按保存后消息的 4 秒规则自动消失，需要再次点击宠物才收起；如果消息请求返回较慢，用户提前收起后还可能被迟到结果重新打开。
- 同一时间、同一天账单情况下连续点击，截图分别出现“外面在下雨，家里的花费可以按日常记”和“雨天记录先放轻，记清这一笔就好”，能看出当前主要是在固定雨天数组中随机取句。
- 当天真实记录是 13:48 的上班通勤和 17:32 的咖啡，记录自身还保存了热天上下文；宠物却只因当前天气为雨便说“家里的花费”，既没有回应通勤/咖啡，也把没有证据的“家里”场景说成了事实。

#### 根因与历史归属

- `HomeView` 对保存后 `homeViewModel.petMessage` 的监听会安排 4 秒后关闭气泡；宠物按钮的 `petClickMessage` 路径只切换 `petBubbleVisible` 并异步写回文案，没有安排同一关闭任务，因此两类消息生命周期不一致。
- 点击请求没有 request ID、取消句柄或消息版本。用户在请求返回前再次点击关闭时，旧任务完成后仍会执行 `petBubbleVisible = true`，存在“已经收起又自己弹回”的竞态。
- `PetCompanionCopy` 主要由静态数组组成；`petClickMessage` 最终对 `companion + lightScene` 或 `weatherContext[key]` 做随机选择，没有近期去重和上下文稳定性。
- `pickSceneLocalPetMessage` 的雨天条件只检查当前缓存天气码，命中后立即返回 `rainyHome`；该文案池包含“家里的花费 / 居家小开销”，但规则没有检查当天是否存在居家、日用或家庭补给记录。
- 当前规则虽然会统计当日总额、交通笔数、买菜和清凉消费，但优先级是天气单点覆盖账单事实；也没有区分“当前实时天气”和“记录发生时保存的天气”，容易把现在下雨错误地套到下午热天记录上。
- 高置信情绪/场景输入没有独立模型。若直接使用 `displayEmotionTag`，又会继承 `COPY-03` 已确认的弱标签、跨记录固化和系统暖语气问题，因此不能靠扩大关键词池解决。

#### 产品目标

宠物不是第二个复盘页，也不是随机提示器。它只需要在短气泡里做一件事：基于当前可靠事实，给出一句自然、克制、与此刻有关的回应。

1. **先有事实，再有语气**：天气、时间、当天记录和用户明确文字决定能说什么；静态文案只负责表达方式。
2. **高置信才回应情绪**：可以回应用户自己写下的感受，或结构化天气＋明确场景；不能把系统生成的“辛苦了 / 治愈 / 值得”当成用户真实心情。
3. **区分现在与当时**：实时天气只能说“现在外面在下雨”；记录的 `memoryContext` 才能说“下午那趟通勤是在热天里记下的”。
4. **一句话就收住**：不复述首页总览，不给消费评价，不推测原因、关系、地点或生活状态。
5. **用户随时可控**：点击出现后自动收起；再次点击立即收起；迟到任务不能重新打开；强提示出现时继续让位。

#### 高置信信号分级

| 等级 | 可用证据 | 宠物可做的回应 | 禁止边界 |
|---|---|---|---|
| A | 用户自己写的标题、备注或“自己写一句”中明确表达，如“终于到家”“今天好累”“第一次带猫看医生” | 可克制复述用户原意，如“你写了‘终于到家’，这笔我替你留好了。” | 不扩写成更强情绪，不诊断、不评价关系或消费 |
| B | 记录自身的结构化天气、时间、分类和强场景共同成立，如 `hot + commute`、雨天通勤、深夜回家、周末早餐 | 可给事实型暖回应，如“下午这趟通勤是在热天里记下的。” | 当前天气不能冒充记录时天气；单个分类不能证明感受 |
| C | 当天两笔以上形成的稳定事实，如一趟通勤＋一杯咖啡、两笔通勤、买菜＋日用补给 | 可做轻量当天总结，如“今天记了一趟通勤，也留下一杯咖啡。” | 不自动解释成加班、犒劳、焦虑、出游或同一事件 |
| D | 没有足够上下文 | 使用更自然的静态陪伴句 | 不读取弱系统情绪标签来强行个性化 |

以下内容不能单独作为高置信证据：系统生成的 `displayEmotionTag` 完整句、`辛苦了 / 治愈 / 开心 / 值得 / 划算 / 冲动`、单个宽泛分类、当前天气对历史记录的反推，以及 `COPY-03` 正在处理的跨记录固化标签。

#### 推荐消息决策顺序

1. 刚保存的记录存在 A 级用户明确表达：只回应这条记录。
2. 刚保存的记录存在 B 级结构化场景：回应“当时的记录事实”。
3. 用户主动点击且今天有记录：从 C 级当天事实生成一句，最多提两个对象，不报商户和精确金额。
4. 当前实时天气与今天后续行动相关时，可追加一层“现在”的事实，但不能覆盖账单内容；例如“今天记了一趟通勤和一杯咖啡，现在外面在下雨。”
5. 没有可靠上下文时才进入 D 级静态池；静态池按 0 笔、1 笔、2 笔以上和时段分组，不再把“奶茶 / 咖啡也可以留一句”随机说给已经记过咖啡的用户。
6. 同一上下文短时间内排除最近 3 条消息 ID；候选不足时宁可重复一个准确事实，也不随机扩张场景。

#### 静态文案方向

- 0 笔：`今天还没记账，也不用硬凑。`
- 1 笔：`今天已经留下一笔了，想起别的再补。`
- 2 笔以上：`今天的几笔都在，晚点回看也来得及。`
- 晚间：`今天先记到这里也可以。`
- 普通陪伴：`我在这儿，想起一笔就记一笔。`

上述为方向示例，正式实现需建立短句长度、敏感类别、重复度和事实准确性夹具；不直接把示例扩成大量随机句。

#### 气泡生命周期方案

1. 保存后消息和触摸消息统一进入一个 `PetBubblePresentation`（或等价状态），包含消息 ID、来源、展示时间和自动关闭任务。
2. 新消息出现时取消上一关闭任务，默认展示约 4 秒后自动收起；根据文字长度可在严格上限内增加少量阅读时间，但不常驻。
3. 气泡可见时再次点击：立即关闭、取消当前消息请求和自动关闭任务，不再请求下一句。
4. 气泡不可见时点击：启动一个带版本号的请求；只有仍为最新请求且宠物仍可展示时才发布结果。
5. 连续点击、切 Tab、页面消失、App 进后台、关闭宠物、第一笔/照片/奖励/会员等强提示出现时，取消请求与关闭任务；迟到结果不得重新开气泡。
6. 新保存消息到来时可以替换普通点击消息，但仍服从现有提示预算和遮挡优先级；不得堆叠两个气泡或多个说话动画任务。
7. Reduce Motion 只取消位移/缩放，不取消文字的可读展示与自动关闭；VoiceOver 聚焦气泡时给予足够朗读时间，关闭行为保持可预测。

#### 敏感与隐私边界

- 医疗、债务、成人、关系、账号、地址等敏感记录默认使用类别中性的“这笔已记下”，不在首页气泡复述标题、商户或备注。
- 普通记录也不在宠物气泡展示精确金额、完整商户名或长备注；需要详情时由首页记录卡承担。
- 所有判断继续本机完成，不新增网络请求，不把宠物包装成远程 AI。

#### 计划修改范围

- `NativeDemoApp/Views/HomeView.swift`：统一气泡 presentation、关闭任务、请求版本和页面生命周期。
- `NativeDemoApp/Services/PetCompanionService.swift`：建立可信上下文快照、信号分级与消息选择优先级。
- `NativeDemoApp/Services/PetCompanionCopy.swift`：按事实角色重组静态短句、增加消息 ID 与近期去重，不扩成无边界随机池。
- 必要时增加独立纯模型文件；不得把逻辑塞入 `PixelPetAnimationView`，动画组件继续只负责帧播放。
- `NativeDemoAppTests/StateRegressionTests.swift`、体验/文案静态门禁、统一真机矩阵和本文档。

#### 冻结边界

- 不改变 `PET-01` 的像素角色、三组帧资源、帧率、裁切、52pt 底板、主题适配和动画状态含义。
- 不改变宠物开关、天气开关、定位权限、保存后提示预算、首页主动作、第一笔/照片/奖励/会员遮挡优先级和 4 秒基准。
- 不修改账单分类、标题、金额、日期、情绪标签保存、OCR、AI 指令台、回放、会员、存储和同步。
- 不直接依赖 `COPY-03` 的暖文案作为事实；`COPY-03` 先修单条标签归属，`PET-02` 只消费稳定结构字段或受控高置信信号。
- 不借本项调整首页卡片布局、宠物位置、气泡视觉、全局主题或启动 `ARCH-03`。

#### 必须补齐的回归

1. 点击宠物后气泡自动收起；可见时再次点击立即收起，不需要第三次操作。
2. 请求返回前手动收起、切 Tab、进后台或出现强提示，迟到结果均不能重新打开气泡。
3. 连续点击 20 次最多保留一个请求、一个气泡和一个说话动画任务；新关闭任务会取消旧任务。
4. 保存后消息与触摸消息使用同一生命周期，分别验证替换、关闭、遮挡和 4 秒基准。
5. 截图场景中，今天有通勤和咖啡、当前外面下雨时，不再说无证据的“家里的花费”；应优先描述真实记录，并把“现在下雨”与记录时天气分开。
6. `hot + commute`、雨天通勤、深夜记录、用户明确“终于到家”等高置信场景可得到克制回应；只有系统标签“辛苦了 / 治愈”时不能代言用户感受。
7. 0、1、2+ 笔，早/午/晚，晴/雨/热/冷，咖啡/通勤/买菜/普通消费和敏感记录均有确定性结果与反例。
8. 最近消息去重稳定；同一上下文不会连续重复两句雨天模板，也不会因随机选择生成与账本矛盾的内容。
9. 账本或天气真正变化后才更新上下文；普通首页重绘、宠物帧推进和气泡动画不得重新扫描完整账本。
10. 多主题、Dynamic Type、VoiceOver、Reduce Motion、低电量和 60 秒 Instruments 下无布局、朗读、hitch、任务或内存回归。

#### 当前记录

- 日期：2026-07-18。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前唯一任务切换为 `INT-03`。
- 实现：`HomeView` 用单一 `PetBubblePresentation` 承接保存后与触摸消息，统一可取消的自动关闭任务；普通模式约 4 秒关闭，VoiceOver 延长阅读时间。再次点击、切 Tab/页面消失、进后台、关闭宠物或出现第一笔/照片/奖励/会员等强提示时同时取消消息请求和关闭任务，request ID 阻止迟到结果重新打开。`PetCompanionMessagePolicy` 只读取标题/分类/场景包、记录自身天气和当前天气：触摸时优先通勤＋咖啡等当天事实，记录时天气与“现在下雨/冷热”分开；敏感记录降级为中性短句，系统暖标签不作为用户情绪，高置信用户原文仅在 `userEditedTitle` 且白名单安全表达时克制复述。静态池按 0/1/多笔和晚间分组，消息 ID 排除最近三条，不再随机输出无证据的“家里的花费”。
- 修改文件：`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/Services/PetCompanionService.swift`、`NativeDemoApp/Services/PetCompanionCopy.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`scripts/experience_static_check.ps1`、本文档。
- 验证证据：新增通勤＋咖啡＋当前雨、记录时高温、暖标签不可作为事实、用户明确文字/敏感降级和 0/1/多笔确定性测试；静态门禁锁定单一可取消生命周期、近期去重和随机雨天模板禁用；`git diff --check`、生活语义回归、体验静态门禁和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：未修改 `PET-01` 像素资源、帧率、裁切、动画状态、52pt 底板、主题适配、宠物/天气开关、定位权限规则、首页布局、动态主动作、保存后提示预算和遮挡优先级；未修改分类、金额、日期、OCR、AI、回放、会员、存储或同步。
- 剩余风险：Windows 无 Xcode/iPhone；SwiftUI Task 生命周期、VoiceOver 7 秒朗读、20 次快速点击、后台/锁屏和真实天气切换仍需真机签收，因此不标记 `VERIFIED`。
- 下一项：按锁定顺序执行 `INT-03`，只改共用记录时间面板的局部滚轮与一次提交，不改变日期或保存规则。
- 验证证据：用户提供的同一时间两次宠物点击 TestFlight 截图；只读核对 `HomeView` 的 `petBubbleVisible / petHint / petMessage onChange / todayPetStamp`、`PetCompanionService.petClickMessage / pickSceneLocalPetMessage`、`PetCompanionCopy.weatherContext` 和 `PET-01 FLOW-30`；`git blame` 确认触摸气泡状态沿用 2026-06-12 逻辑，帧动画接入只增加点击动画触发，没有重写文案服务或关闭状态机。
- 剩余风险：用户所说“高置信情绪化账单”必须与用户原文、结构字段和系统暖标签严格分级；否则会把 `COPY-03` 的错误放大到宠物气泡。VoiceOver 自动关闭时长、敏感记录脱敏和实时天气/记录时天气冲突需在 Xcode/iPhone 上验证。
- 下一项：继续收集后续真机问题；问题收齐后先处理三个 `P0`，P1 按 `FIX-006 → INT-03 → MEMBER-03 → COPY-03 → PET-02 → AI-03` 逐项执行，`COPY-02` 与 `ARCH-03` 继续冻结。

---

## 24. LOGIC-15：回放完成承接与内容推荐条件解释（2026-07-18）

- 状态：`IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 用户确认：继续优化此前 `LOGIC-05` 中没有做好的两处——非会员完成回放后被会员页替代自然完成动作，以及周/月“成熟度”只按笔数/日期判断、用户无法理解为什么没有主动推荐。
- 目标：所有用户完成周记/月章后先获得可关闭的完成动作；复盘是可选后续，会员价值只在额度接近用尽时作为低优先级入口。把内部“功能成熟度”收敛为“内容主动推荐条件”，结合有效记录笔数与活跃天数，并用自然文案解释“现在仍可手动查看”。
- 允许修改：`InteractionStateModels.swift` 的回放完成与推荐条件纯策略、首页既有旅程事实快照与副文案、`SummaryPlaybackSheet.swift` 完成区动作层级、`StatsWebView.swift` 的低优先级会员提示资格、对应 XCTest/静态门禁/真机矩阵和本文档。
- 冻结边界：首页状态驱动主动作的优先顺序、OCR/手动草稿/今日回放优先级、周/月手动入口、回放内容和完成判定、免费额度及扣次、会员价格/Product ID/StoreKit/登录续购、存储同步、主题、AI、宠物和 `ARCH-03` 均不改变。
- 验收：非会员完成回放的主按钮不再直达会员页；周/月均可选进入复盘；会员入口不抢主动作且普通剩余额度下不反复出现。周记至少覆盖 3 笔且 2 个记录日、月章至少覆盖 5 笔且 3 个记录日并到 25 日后才主动推荐；未达到时首页只做自然解释，用户仍可从痕迹手动查看。
- 实现：`PlaybackMaturityPolicy` 增加活跃天数条件，周记主动推荐要求 3 笔且覆盖 2 天，月章要求 5 笔、覆盖 3 天并到 25 日后；首页旅程事实缓存一次性准备周/月活跃天数，普通重绘不扫描账本。未满足时“继续记录”卡片用自然副文案说明周记/月章会在内容更完整时主动出现，并明确月章仍可随时去痕迹查看。回放完成区会员/非会员主按钮统一为“完成”，周记与月章均保留规范术语“继续问”进入复盘；会员入口只在免费额度剩余不超过 1 次时显示，且位于保存故事、留下记忆句、复盘和本周入口之后。
- 修改文件：`NativeDemoApp/Models/InteractionStateModels.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：XCTest 更新周/月笔数＋活跃天数＋日期边界、会员/非会员统一完成动作和低优先级会员入口；静态门禁锁定首页单次事实快照、自然解释、主动作不跳会员和近额度才展示会员入口；新增 `FLOW-35` 真机矩阵。`git diff --check`、生活语义回归、体验静态检查和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仅保留既有 7 条 soft copy warning。
- 冻结边界复核：首页 OCR→草稿→今日回放→周→月→复盘→继续记录的状态顺序未改，周/月手动入口未锁；回放内容、完成标记、免费额度常量、扣次、会员价格/Product ID/StoreKit/登录续购、存储同步、主题、AI、宠物、`COPY-02` 和 `ARCH-03` 未改；用户既有 `StatCardView.swift`、`web-preview/app.js`、提示文档、素材与 `tmp` 未覆盖。
- 剩余风险：Windows 无 Xcode/Swift/iPhone；需要真机确认完成区多按钮在小屏/大字下的层级、周/月“继续问”路由、会员入口仅在剩余 1 次时出现，以及跨周/月、时区和 24/25 日边界。完成 `FLOW-35` 前保持 `CODE_DONE`，不得标记 `VERIFIED`。
- 下一项：本轮不启动其他产品任务，等待 Xcode 编译与 iPhone 真机签收。

---

## 25. FIX-008：云端登录令牌过期后仍显示已登录（2026-07-18）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 真机确认：云端账单字段无法同步；退出云端账号并重新用短信验证码登录后立即恢复，确认线上服务并非整体不可用，故障与旧登录会话直接相关。
- 线上证据：`https://api.xuzhangapp.com/health` 返回 200；未授权访问 `/v1/account/me` 与 `/v1/ledger` 正常返回 401；DNS、TLS、Nginx、Express 和账单路由均在线。
- 根因：后端访问令牌有效期为 7 天且当前没有 refresh token；客户端 `hasCloudSession` 只判断 Keychain 中是否存在非空令牌。令牌自然过期或服务端轮换 `JWT_SECRET` 后，账号刷新与账单同步收到 401，但设置页仍显示已登录，同步层又把状态码和响应体统一折叠成“暂时没同步成功”，用户无法知道需要重新登录。
- 用户追加确认：记账类 App 不应每 7 天要求重新登录；本项将新签发访问令牌有效期调整为 90 天。90 天是当前无 refresh token 架构下的体验与风险折中；服务端密钥轮换、明确 401 和用户主动退出仍立即结束会话。
- 目标：新登录会话 90 天内保持有效；服务端明确返回 401 时原子失效本机会话，关闭云端同步、清理旧访问令牌并提示重新登录；网络中断、超时、400 校验错误和 500 服务错误不得误退出。
- 允许修改：后端 JWT 新签发有效期；新增最小会话失效协调器；`SettingsViewModel` 的账号刷新和授权请求错误处理；`HomeViewModel` 的手动同步、单条上传与删除错误处理；对应后端测试、纯策略/XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不修改 JWT 签名算法/密钥、短信登录、会员 Product ID/价格/StoreKit/登录后续购、账单 DTO、字段校验、冲突合并、照片仅本机、本地账本/图片、同步开关账号偏好、首页动态主动作、主题、AI、回放、宠物或 `ARCH-03`。
- 数据安全：401 只清理会话和当前本机同步启用态，不删除本机账本、照片、备份或云端记录；原账号的同步偏好继续按账号保存，重新登录后仍走现有显式合并确认。
- 验收：新签发 JWT 的 `exp - iat` 为 90 天；启动账号刷新、手动同步、自动上传、删除云端字段和同步开关回写遇到 401 时均立即显示“登录已过期，请重新登录”；界面不再保持假登录状态；同一轮重复 401 只执行一次失效；离线、超时、400、500 继续保留会话并显示对应非退出错误。
- 工作区保护：保留未提交的 `LOGIC-15`、`StatCardView.swift`、`web-preview/app.js`、提示文档、宠物素材、`tmp/` 与 `scripts/__pycache__/`，不覆盖、不回退、不提交相邻任务。
- 实现：后端新签发 JWT 改为固定 90 天，并增加运行时 `exp - iat` 校验脚本。iOS 新增纯 `CloudSessionFailurePolicy`，只有 `AuthServiceError` 或 `LedgerSyncError` 的 HTTP 401 才失效会话；400、500、离线和超时保持原会话。`CloudSessionInvalidationService` 在主线程保存原账号同步偏好、清理旧 Keychain token、关闭当前本机同步态并清除账号派生会员状态，不删除本机账本、图片、备份或云端记录；通知 `SettingsViewModel` 立即切换为未登录并显示明确重新登录说明。账号刷新、同步开关回写、昵称同步、云端字段删除、账号注销失败、手动账本合并、合并后回传、单条自动上传和云端删除均接入同一 401 处理。
- 修改文件：`backend/src/auth.js`、`backend/scripts/verify-auth-token-ttl.mjs`、`backend/package.json`、`backend/README.md`、`NativeDemoApp/Services/AuthService.swift`、`NativeDemoApp/ViewModels/SettingsViewModel.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：Node 运行时校验确认新 token TTL 为 `7,776,000` 秒（90 天）；XCTest 增加 Auth/Ledger 401、400、500、离线反例及设置失效后仅清除账号态的纯策略覆盖；静态门禁锁定 90 天、所有同步入口 401 处理和 `FLOW-36`。`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过；完整门禁仍只有既有 7 条文案 soft warning。
- 冻结边界复核：未修改 JWT 签名算法或密钥、短信登录、StoreKit、会员 Product ID/价格/交易验证、登录续购、账单 DTO、字段校验、`updatedAt` 冲突规则、照片边界、本地账本/图片/备份、首页动态主动作、主题、AI、回放、宠物和 `ARCH-03`；未覆盖 `LOGIC-15` 或用户既有脏工作区。
- 剩余风险：Windows 无 Xcode/iPhone，Combine 通知到 `@MainActor` 的生命周期、真机 401 后页面即时退出状态、重复 401、离线/400/500 反例和重新登录合并仍需按 `FLOW-36` 签收，因此不标记 `VERIFIED`。生产后端尚未部署本次 90 天改动；部署前签发的 token 仍保留原到期时间，部署后需重新登录一次才会获得 90 天新 token。
- 下一步：在生产服务器部署后端并重启 `backend`，随后重新登录一次；再用 Xcode/iPhone 执行 `FLOW-36`。未完成部署和真机签收前不启动相邻同步重构。

---

## 26. 周记分享图保存竞态与模板收敛方案（2026-07-18）

本节先完成 TestFlight 截图、代码路径、历史归属、产品问题和实施方案评审；用户于 2026-07-18 确认按锁定顺序执行。`FIX-009` 与 `UI-02` 均已达到 `CODE_DONE`，当前无 `IN_PROGRESS`。

### 执行顺序

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | FIX-009 | 分享图图片准备与渲染原子化 | `CODE_DONE` | 只修图片读取、解码、准备状态与截图输入；不改分享事实、模板选择、照片顺序、相册权限和回放完成动作 |
| 2 | UI-02 | 周记分享模板数量、信息层级与真实二维码边界 | `CODE_DONE` | FIX-009 稳定后再改模板；不改周记/月章播放内容、额度、分享隐私确认、主题体系或原账本 |

### 真机现象与确认结论

- 用户提供的两张 9:16 分享图均把“正在加载图片”与进度指示保存进最终图片；一张为单图沉浸式模板，一张为浅色周记模板。
- 周记数据已正确显示 `16 笔记录 / 1 张照片`，证明分享 payload、照片引用数量和周范围已经进入卡片；错误集中在照片实体尚未完成读取/解码时就执行截图。
- 问题确认存在，且并非只需增加固定延迟：大图、冷缓存、文件 IO、解码和设备负载的完成时间不确定，任何固定等待都可能继续截到占位态。

### 根因

1. `saveWeeklyStoryCard()` 新建 `WeeklyStoryShareCardView`，只执行一次 `Task.yield()`，随后立即调用 `snapshot()`。
2. 分享卡的照片由 `MemoryAttachmentThumbnail` 在 `.task(id:)` 中异步读取文件、后台解码并更新 `@State loadedImage`；新建的离屏卡首帧必然从 `nil` 开始。
3. `snapshot()` 用新的 `UIHostingController` 与 `UIWindow` 同步布局并 `drawHierarchy`，不会等待子 View 的异步任务完成。因此占位态是合法首帧，却被错误当作最终可保存画面。
4. `posterImage` 为同一照片同时创建模糊背景和前景两个异步缩略图 View；即使共享缓存，离屏新 View 仍需等待任务发布状态。
5. 保存按钮只受 `isSavingShareCard` 控制，没有“本模板所需照片已准备完成”的资格；照片引用存在就先按 `1 张照片` 生成标题、模板和指标，文件缺失或解码失败也不会及时降级。

### 模板侧已确认的问题

- 单图标题/副文案是按数量生成的 `这一周，一张照片 / 当时拍下的一张图`，上下只重复“有一张图”，没有说明日期、记录或这张图为何被选中。
- 自动模板可把唯一一张照片铺满整张 540×960 海报；一旦照片未就绪或不可用，整张卡约三分之二面积只剩加载占位，失败影响被最大化。
- 当前预设包含 8 种模板，数据条件与模板能力没有严格配对；同一组弱数据可能进入强依赖照片的胶片/沉浸样式，质量波动较大。
- 浅色模板同时存在顶部品牌、底部 112pt 品牌条和二维码，品牌层级重复，真实记录内容反而被压缩。
- 当前 `appStoreQRCodePlaceholder` 是 Canvas 绘制的仿二维码，辅助说明也明确为“预留位”，不能真实扫码；在分享成品中展示会形成产品可信度问题。仓库当前没有正式 App Store 商品 URL。
- 海报继续使用默认缩略图变体，长边最多约 900px；导出为 540×960@3x 时，沉浸式照片即使加载成功也存在清晰度不足风险。

### FIX-009 推荐方案：先准备，再预览与保存

1. 新增不可变 `PreparedShareCardRenderInput`（或等价模型），固定本次 payload、模板、文案和最多 3 张已解码 `UIImage`；预览与保存必须消费同一个输入。
2. 打开分享预览时只加载当前模板实际使用的照片，后台读取并按海报目标尺寸降采样/预解码；同一张照片只读取、解码一次，模糊背景和前景共用同一 `UIImage`。
3. 导出卡 View 不再使用带 `.task` 的 `MemoryAttachmentThumbnail`，只同步渲染已准备的 `Image(uiImage:)` 或确定性的事实卡片；导出树中禁止出现 ProgressView 和“正在加载图片”。
4. 准备期间把加载反馈放在分享操作层，保存按钮显示“正在准备分享图”并禁用；不能把加载态画进海报内容。
5. 文件缺失、损坏或解码失败时不无限等待：将该照片从可用集合移除，按 0/1/2/3 张真实可用照片重新选择安全模板和指标，并提示“有 1 张照片暂不可用，本次按记录生成”；仍允许保存无图事实模板。
6. 保存时锁定 render input，防止换模板、照片任务或父 View 重绘改变结果；快速重复点击只保留一个准备/渲染/相册写入任务。
7. 优先使用 SwiftUI `ImageRenderer` 或等价同步渲染器；若保留现有 snapshot，前提也是导出树零异步依赖，不能用固定 `asyncAfter` 或多次 `yield` 猜加载完成。

### UI-02 推荐方案：从 8 个模板收敛为 4 种数据能力

1. **无图记录卡**：0 张可用照片；用一条事实主线、活跃天数和记录数，不制造图片区。
2. **单图记忆卡**：1 张可用照片；主图约占 45%～55%，标题优先使用安全的记录标题/日期/场景，例如 `7 月 17 日，这杯咖啡被留下来`，副文只补一层事实，不再重复“一张照片”。
3. **周记拼页**：2～3 张可用照片；照片网格＋一条本周事实，指标统一为 `记录数 / 活跃天数 / 照片数`。
4. **自定义背景**：只由用户主动选择，不参与自动推荐；保持现有隐私确认。

自动推荐只在上述前三种安全模板中选择；`Full Photo / Film / Scrapbook` 等强风格若保留，降为手动样式，并增加照片已准备、最小像素、可接受宽高比和非截图/收据等质量门槛。用户可见样式名改为中文，不再把英文内部风格名作为主要说明。

### 信息层级建议

- 顶部：`周记 · 2026.07.13—07.19`，只保留一次品牌识别。
- 主标题：真实记录事实或代表照片，不用照片数量充当主题。
- 副文：最多一层观察；与标题、照片说明和指标去重。
- 照片说明：优先 `日期 · 安全记录标题`；无可靠文字时只显示日期，不输出“当时拍下的一张图”。
- 指标：`16 笔记录 / 5 个记录日 / 1 张照片`，移除信息量较低的 `周 回顾`。
- 底部：缩成轻量 `叙账 · 生活记录` 品牌签名；正式 App Store URL 未确定前移除仿二维码。未来有正式 URL 后，用系统二维码生成真实可扫码图并验证安静区、对比度和真机扫码距离。

### 冻结边界与边界处理

- 不改变照片选择、封面、顺序、账本引用和本地按需加载体系；只为分享输出增加独立准备层。
- 不改变周记/月章播放章节、文案选择、额度、完成动作、会员、分享隐私确认和相册权限语义。
- 不把本地模板包装成 AI，不生成账本外人物、地点、原因或感受；模板事实继续来自现有 `WeeklyShareCardPayload` 与 `SummaryMemoryAnchor`。
- 0 图、缺图、损坏图、1/2/3+ 图、12MP、低内存、切后台、关闭 Sheet、快速换模板、连续保存和相册拒绝均需有确定结果；页面关闭后取消未完成任务并释放解码图。
- `COPY-02` 周记/月章播放活人感文案继续独立冻结；本项只处理分享海报文案与布局，不借机修改播放正文。

### 验收设计

1. 冷启动、未命中缓存和 12MP 照片下，最终保存图永远不包含加载指示、占位文案或空白图片区。
2. 预览与保存使用同一模板、同一照片、同一文案；换一版后保存不串回上一模板。
3. 缺失/损坏照片自动降级为事实模板，照片数按真实可用数显示，本机账本和图片引用不被修改。
4. 1 张照片不重复三次表达“有一张图”；主标题、副文、照片说明和指标各自承担不同信息。
5. 0/1/2/3 张和无照片的周记均有稳定模板；弱数据不进入全屏照片，低像素图不被强行放大。
6. 成品不出现不可扫码的仿二维码；未来真实二维码必须用两台设备实扫通过。
7. 100/1,000 条账本、3 张真实 12MP 照片下，准备、换模板和保存无主线程长卡顿、重复解码或持续内存增长。
8. Xcode Debug/Release、XCTest、相册权限、Dynamic Type、VoiceOver、Reduce Motion 和多主题矩阵完成前保持 `CODE_DONE`，不得标记 `VERIFIED`。

### 下一步

#### FIX-009 当前记录

- 日期：2026-07-18。
- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；随后才将 `UI-02` 切换为唯一 `IN_PROGRESS`。
- 实现：分享隐私层出现后只为最多三张候选照片建立独立准备任务；后台从原图引用读取并按导出最长边 2880px 降采样、预解码，同一张图只生成一个 `UIImage`，前景与模糊背景复用。预览和保存统一消费锁定的 `PreparedWeeklyShareCardRenderInput`，导出树不再包含 `MemoryAttachmentThumbnail`、加载文案或异步图片任务；保存按钮在准备完成前禁用，准备反馈只显示在操作层。缺失/损坏图片按真实可用 ID 保序降级并显示说明，零图仍生成事实卡；保存中冻结样式、拒绝重复任务，关闭页面取消未完成任务并释放准备图片。
- 修改文件：`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增可用照片保序、三张上限、全部损坏和额外已加载 ID 不可越界的纯策略 XCTest；静态门禁锁定原图后台降采样、单一不可变渲染输入、导出树零异步缩略图和禁止 `Task.yield` 猜等待；新增 `FLOW-37` 覆盖冷缓存、12MP、缺图/损坏图、20 次连续保存、关闭页面、相册拒绝和无障碍。`git diff --check`、生活语义回归、体验静态门禁和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：未修改播放章节/正文、额度、完成动作、照片选择/顺序/引用、账本、分享隐私确认、相册权限、会员、主题、宠物、AI、存储同步、`COPY-02` 或 `ARCH-03`；保留 `LOGIC-15`、`FIX-008` 与用户既有脏工作区。
- 剩余风险：Windows 无 Swift/Xcode/iPhone；Swift 严格并发、`UIHostingController` 同步渲染、真实 12MP 峰值、相册权限、后台取消、Dynamic Type、VoiceOver、Reduce Motion 和多主题仍需 `FLOW-37` 真机签收，因此不得标记 `VERIFIED`。

#### UI-02 当前启动

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 实现：用户可见模板按真实可用照片数收敛为三种数据能力：0 图自动使用“记录摘要”，1 图自动使用“单图记忆”，2～3 图自动使用“周记拼页”；手动列表只展示当前数据能力允许的安全模板，自定义背景继续必须由用户明确选择。全屏照片、胶片、杂志等未建立像素/比例/内容质量门槛的强模板不再出现在用户选择列表。图片准备失败导致数量下降时会自动回到允许模板，不保留失效手动选择。
- 信息层级：周期统一为 `周记 · 日期范围`；单图主标题优先使用 `日期 + 安全照片说明`，主图底部补 `日期 · 安全说明`，副文从真实周事实中去重选择，不再用“这一周，一张照片”充当主题。指标统一为 `记录数 / 记录日 / 真实照片数`，0 图显示 0 张而非“3 段内容”，移除低价值的“周 回顾”。健康与照护照片标题强制降级为类别中性说明，不复述具体标题、备注或检查/用药内容。
- 视觉收敛：保留既有主题 Token、背景质感和卡片语言；品牌只在顶部出现一次，底部改为紧凑事实指标，不再重复大面积品牌条。删除 Canvas 仿二维码、预留位辅助语义和所有成品引用；正式 App Store URL 未确定前不展示二维码。
- 修改文件：`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增 0/1/2/3+ 图自动能力、手动允许集合、敏感健康/照护标题中性化的纯策略 XCTest；静态门禁锁定真实周期/照片说明/记录日指标、禁止仿二维码和数量型标题；新增 `FLOW-38` 覆盖四种模板能力、缺图降级、自定义背景、敏感文字、主题、大字和 VoiceOver。最终 `git diff --check`、生活语义回归、体验静态门禁和 `python scripts/validate_release_gate.py --phase windows` 全部通过，仍只有既有 7 条文案 soft warning。
- 冻结边界复核：未修改 FIX-009 图片读取/顺序/引用规则，未修改周记/月章播放章节与正文、额度、完成动作、分享隐私确认、相册权限、账本、主题 Token、会员、AI、宠物、存储同步、`COPY-02` 或 `ARCH-03`；旧强模板实现仅保留为不可达内部代码，没有借本项启动页面拆分或删除式重构。
- 剩余风险：Windows 无 Swift/Xcode/iPhone；模板实际排版、`UIImage` 严格并发诊断、540×960@3x 清晰度、0/1/2/3 图、真实 12MP 峰值、小屏/大字、VoiceOver、Reduce Motion、多主题和相册权限需按 `FLOW-37`～`FLOW-38` 真机签收，因此不得标记 `VERIFIED`。
- 下一步：用 Xcode Debug/Release 与 iPhone 执行 `FLOW-37`～`FLOW-38`；签收前不启动 `ARCH-03`，也不继续改播放文案或相邻页面。

---

## 27. 痕迹周记/月章三态产品评审效果图（2026-07-18）

- 工作性质：本次仅生成产品评审用高保真 UI 资产，不修改 iOS 代码、业务计数、导航结构、主题 Token、周记/月章播放正文或既有路线图状态；当前仍无 `IN_PROGRESS`。
- 设计范围：同一横向画布并列展示“周记有照片”“月章有照片”“月章无照片”三个完整 iPhone 页面；周记以具体馄饨照片和单条记录为中心，月章有图以主题、真实依据、记录节奏和右侧封面照片为中心，月章无图以 31 天热力月历、节奏曲线和场景指标为中心。
- 冻结边界：保留 `痕迹 / 这一段痕迹`、`生活 / 线索`、`本周 / 本月` 和现有五个底部导航；未使用抽象客厅插画、仿二维码、会员入口、营销口号或被禁止的通用文案；未把周记与月章设计为相同的大图卡。
- 生成资产：`brand-assets/mockups/xuzhang-trace-week-month-review-v1.png`，PNG，1740×904，约 1.39 MB。
- 验证证据：已在本地打开成图核对三台手机完整边界、周/月选中态、主卡差异、写实馄饨照片、无照片月历热力与节奏曲线、关键词/日记下段和五栏底部导航；文件可读取且尺寸检查通过。
- 剩余风险：当前会话没有收到用户所述的原始馄饨参考图，仓库内 `QARealPhotos` 为压力测试夹具而非可用生活照片，因此成图使用生成式写实馄饨照片；图片模型生成的中文在最终实施前仍需由设计稿或 SwiftUI 组件逐字复核，不能直接视为代码验收证据。
- 下一步：由产品/设计评审三态信息层级；若方向确认，再单独建立并启动对应 iOS 实施任务，继续遵守一次仅一个 `IN_PROGRESS` 和既有冻结边界。

---

## 28. UI-03：痕迹周记/月章首屏价值与三态封面实施（2026-07-18）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 用户反馈：现有周记与月章首页虽然视觉完整，但主标题和说明仍偏抽象、像模板；月章顶部使用抽象房间插画，忽略下方已经存在的真实照片和记录节奏，用户需要先读很多文字才能理解这一页的价值。
- 产品分工：周记回答“这周发生了哪一幕”，以一条具体日期/记录和代表照片为主；月章回答“这个月形成了什么”，以记录分布、活跃天数、最高频分类和最长连续记录等确定事实为主。月章照片只作为编辑式封面证据，不放大成第二张周记大图。
- 三态边界：
  1. 周记有照片：主标题使用代表照片对应的日期与安全记录事实，辅助句只补本周笔数、活跃天数和最高频分类，不使用“被留下”“有画面”等空泛句。
  2. 月章有照片：顶部采用文字/数据为主、右侧小封面照片为辅的编辑式结构；封面照片从下方“本月日记”首屏排除，避免同一张图连续重复。
  3. 月章无照片：顶部使用本月记录热力/节奏与确定性事实，不显示空图片区，不使用抽象房间插画。
- 允许修改：`StatsTraceModels.swift` 中只读事实与文案策略；`StatsTraceSnapshotStore.swift` 的章节快照事实准备；`StatsWebView.swift` 的周记标题/说明、月章顶部三态结构和本月日记封面去重；对应 XCTest、体验静态门禁、真机矩阵和本文档。
- 冻结边界：不修改周记/月章播放章节和正文、额度、扣次、完成动作、会员、AI 指令台、复盘、首页动态主动作、痕迹筛选/细查、照片选择/顺序/引用/按需加载、主题 Token、存储同步或 `ARCH-03`。不根据情绪标签、照片内容或模板猜测人物、地点、原因和感受。
- 性能边界：所有标题与辅助事实只消费已经准备好的 `TraceChapterSnapshot`；不得在 SwiftUI `body` 中重新扫描完整账本、解码图片或同步计算生活线索。普通周/月切换、照片横滑和主题变化不得触发额外账本聚合。
- 验收：空数据、弱数据、周记有/无照片、月章有/无照片、封面图片缺失、同分类并列、0/1/多活跃日均有确定结果；周/月职责一眼可区分；文案明确“笔数占比”而非含糊百分比；Dynamic Type、VoiceOver、多主题和真实 12MP 照片矩阵完成前只能标记 `CODE_DONE`。
- 工作区保护：继续保留并不提交 `StatCardView.swift`、`web-preview/app.js`、用户提示文档、`brand-assets/`、`tmp/` 与 `scripts/__pycache__/` 的既有修改或未跟踪内容。
- 实现：新增 `TraceChapterCoverFacts` 与 `TraceChapterCoverPolicy`，随现有后台 `TraceChapterSnapshot` 一次准备代表记录、活跃天数、最高频分类、分类笔数占比、最长连续记录、月历日计数和封面 ID。周记标题改为代表记录的真实日期与安全短标题，辅助句明确本周记录数、记录日和最高频分类；健康标题降级为类别中性说明，商户括号后缀只用于封面短标题收敛，不改原账本。
- 月章三态：有照片时采用文字/数据为主、右侧 112pt 小封面为辅的编辑式结构；无照片时直接展示本月记录日热力，不制造空图片区；旧抽象房间插画和“生活有了轮廓/拼出完整生活”等模板句从渲染路径移除。顶部指标统一为记录、记录日和最长连续；`按记录笔数整理` 明确最高频与百分比口径。
- 去重边界：新增 `TraceMonthDiaryPolicy`，按封面记录 ID 排除该记录的全部照片锚点和记录卡，避免封面在下方“本月日记”首屏重复；当本月只有封面记录时显示明确承接说明，不伪装为空数据。
- 修改文件：`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增周记代表照片事实、月章最高频分类/笔数占比/活跃日/最长连续、无照片空热力、分类并列和封面日记去重 XCTest；静态门禁锁定章节快照准备、周/月三态渲染、抽象房间/被动模板禁用和 `FLOW-39`。`git diff --check`、生活语义、体验静态、文案、会员、AI、无障碍、可观测性、主题、迁移、SQLite、100/1,000/5,000 条夹具、真实 12MP 夹具及 `python scripts/validate_release_gate.py --phase windows` 全部通过；当前仅有既有 5 条 soft copy warning。
- 冻结边界复核：未修改周记/月章播放章节或正文、额度/扣次/完成动作、会员、AI 指令台、复盘、首页动态主动作、痕迹筛选与细查、照片选择/顺序/引用/按需加载、主题 Token、存储同步、`COPY-02` 或 `ARCH-03`；未覆盖 `StatCardView.swift`、`web-preview/app.js`、用户提示文档、素材和 `tmp/`。
- 剩余风险：Windows 无 Swift/Xcode/iPhone；`TraceChapterCoverFacts` 新字段的 Swift 编译、SwiftUI 固定/自适应布局、真实缺图占位、默认/深色/高对比主题、特大字号、VoiceOver、Reduce Motion、真实 12MP 滚动和封面去重需按 `FLOW-39` 真机签收，因此不得标记 `VERIFIED`。
- 下一步：在 Xcode Debug/Release 与 iPhone 执行 `FLOW-39`；签收发现问题时只定向修复本项，不启动 `ARCH-03` 或顺带修改播放文案。

---

## 29. UI-FIX-03：痕迹页统一加载遮罩与稳定快照发布（2026-07-20）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 用户真机反馈：“本月痕迹”和“线索”进入整理状态时，提示位置乱跳、不在可视区域中间，也没有遮罩；旧内容与新范围控件会短暂混在一起，完成替换时有明显布局跳动。
- 根因：页面同时存在无快照时的滚动内容内 `.page` 加载卡、有旧快照时顶部更新 Pill，以及月章目标快照未完成时卡片右上角进度胶囊三套反馈；加载卡位于 ScrollView 内容并使用不对称上下留白，无法相对 viewport 居中；快照、提示消失和内容高度变化又被包进同一个整页动画事务，叠加滚动锚点修正后放大跳动。
- 目标：痕迹与线索统一为一个挂在 ScrollView 可视 viewport 上的居中加载层；轻量主题遮罩阻止下层误触；只让遮罩淡入淡出，快照发布不执行布局动画；本月痕迹与本月线索使用准确文案。
- 允许修改：`StatsTraceModels.swift` 的纯加载呈现策略；`StatsWebView.swift` 的加载状态、viewport 遮罩和快照发布事务；必要的 XCTest、体验静态门禁、统一真机矩阵与本文档。
- 冻结边界：不修改痕迹数据口径、周/月/线索计算、筛选、快照缓存键、后台任务、请求取消、`LatestRequestGate`、旧快照承接、照片按需加载、周/月封面内容、额度、会员、AI、首页动态主动作、主题 Token、存储同步、`COPY-02` 或 `ARCH-03`；不修改或提交用户既有 `StatCardView.swift`、`web-preview/app.js`、提示文档、素材与 `tmp/`。
- 边界处理：首次无快照立即遮罩；已有旧快照的快速刷新延迟约 150ms 再显示，避免缓存命中闪烁；同一时刻只能存在一个加载反馈；真实空数据仍由有效快照展示空态；页面离开、请求取消、快速周/月/生活/线索切换时旧任务不得重新显示遮罩或覆盖新请求。
- 验收：首次进入、本周/本月快速切换、生活/线索快速切换、缓存命中、旧快照刷新、真实空数据与任务取消均无重复提示、错误旧内容误触或整页布局跳动；遮罩在可视区域中央并适配主题、Dynamic Type、VoiceOver 与 Reduce Motion。Windows 只能完成代码与静态门禁，Xcode/iPhone 签收前不得标记 `VERIFIED`。
- 开始现场：分支 `feature/xuzhangapp-staging`；保留 `StatCardView.swift`、`web-preview/app.js` 及既有未跟踪素材/提示/tmp 现场，本项不覆盖、不回退。
- 实现：新增 `TraceLoadingPresentationPolicy`，按生活/线索、周/月/年/自定义范围生成准确文案；首次无快照零延迟展示，有旧快照时延迟 150ms，避免缓存命中闪烁。`StatsWebView` 将加载状态收敛为单一可选 presentation，加载层挂在 `GeometryReader` viewport 的顶层 `ZStack`，使用 `AppColors.bg` 轻遮罩与 `.card` 加载卡居中展示，同时禁用下层滚动与辅助功能焦点。
- 去重复与稳定发布：移除痕迹页滚动内容内 `.page` 加载卡、顶部 `ComputationUpdatePill` 和周/月卡片右上角进度胶囊；无快照时只保留稳定透明占位。快照与刷新标记通过禁用动画的 `Transaction` 一次发布，随后只淡出统一遮罩；快速切换会取消旧延迟任务并继续由 `LatestRequestGate` 阻止旧结果反写。
- 修改文件：`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增首次本月痕迹、旧快照 150ms 延迟、本月线索与自定义线索文案纯策略 XCTest；静态门禁锁定单一 viewport 遮罩、交互阻止、无重复提示和无动画快照发布；新增 `FLOW-40` 覆盖无缓存、缓存命中、旧快照、本月痕迹/线索、快速切换、取消、空数据、1,000 条和无障碍矩阵。`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，包含 `git diff --check`、生活语义、文案、主题、迁移、SQLite、100/1,000/5,000 条和真实 12MP 夹具；仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改痕迹数据口径、筛选、周/月/线索计算、缓存键、后台任务、取消与最新请求保护、旧快照承接、照片、封面内容、额度、会员、AI、首页动态主动作、主题 Token、存储同步、`COPY-02` 或 `ARCH-03`；未覆盖或提交用户既有脏工作区。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 Swift 类型与 SwiftUI viewport 布局仍需 Xcode Debug/Release 和 XCTest；遮罩实际居中、Safe Area、快速切换、默认/深色/高对比主题、特大字号、VoiceOver、Reduce Motion 与 1,000 条切换流畅度需按 `FLOW-40` 真机签收，因此不得标记 `VERIFIED`。
- 下一步：在 Xcode/iPhone 执行 `FLOW-40`；如有问题只定向修复 UI-FIX-03，不启动 `ARCH-03` 或顺带修改周/月内容和相邻页面。

---

## 30. FIX-010：首页一键通勤前台恢复刷新（2026-07-20）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 代码与全仓门禁已完成，不冒充 macOS/Xcode 编译通过。
- 用户反馈：工作日早上首页“一键快捷记通勤”没有出现，要求修复后全局复核边界与交互卡顿。
- 已确认根因：`PERF-09` 将通勤候选从 SwiftUI 重绘时同步计算改为账本修订＋分钟桶驱动的后台快照，方向正确；但当前只在首页 `onAppear`、60 秒 Timer、账本修订和会员变化时准备快照。App 前一晚停留首页、早上从后台直接恢复时，`scenePhase` 变为 active 只处理宠物状态，不立即刷新当前分钟，因而会继续读取旧空快照，直到下一个 Timer 才可能出现。
- 目标：Home Tab 从 inactive/background 回到 active 时，立即以当前时间请求现有首页快照；同一分钟/同账本继续命中 key 并零重算，跨分钟或跨日才启动后台准备。保持旧请求 ID 与 key 双重保护，禁止旧时间候选反写。
- 允许修改：`HomeView.swift` 的前后台生命周期接线；对应首页快照 XCTest、体验静态门禁、真机矩阵和本文档。只有发现直接必要的快照失效缺口时才允许定向修改 `HomeViewModel+Dashboard.swift`，不得扩张为首页重构。
- 冻结边界：首页 OCR 待整理→手动草稿→今日回放→周/月痕迹→复盘→继续记录的动态主动作顺序不变；通勤仍不得覆盖更高优先级任务。工作日、06:00～10:30 总窗口、个人时间窗口、120 天样本、最低 4 笔/3 天、稳定金额、今日重复阻止、按钮文案、保存字段与一键写入规则均不变。
- 性能边界：前台恢复只调用已有变化驱动准备入口，不在 `body`、`scenePhase` 回调或主线程重新筛选完整账本；同一分钟重复 active、短暂来电/控制中心切换和 `onAppear + active` 连续触发必须由快照 key 去重；后台计算、取消和最新请求保护保持。
- 边界验收：冷启动、前台过夜恢复、同一分钟重复前后台、跨分钟、跨日、工作日/周末、个人窗口前后、已有早通勤、早餐等非通勤记录、OCR/手动草稿/今日回放主动作、用户主动关闭同一候选、快速切 Tab 和 1,000 条账本均有确定结果；不新增通知、不自动保存、不放宽识别。
- 开始现场：继续保护 `UI-FIX-03` 未提交修改以及 `StatCardView.swift`、`web-preview/app.js`、提示文档、素材、`tmp/` 和 `scripts/__pycache__/`；本项不覆盖、不回退、不提交相邻文件。
- 实现：`HomeView` 的 `scenePhase` 进入 active 时立即以 `Date()` 调用现有 `prepareHomeDashboardSnapshots`；inactive/background 仍按原规则关闭宠物气泡。首页首次出现与前台恢复标记为生命周期刷新，若分钟/账本 key 已变化，先移除上一时段可操作的旧通勤卡，再在 `.utility` 后台任务生成当前候选；普通 60 秒 Timer 不清旧卡，避免每分钟周期性闪烁。
- 去重与取消边界：新增纯 `HomeQuickRecordRefreshPolicy`。同一分钟、同账本的 `onAppear + active` 或多次 inactive→active 直接命中 `HomeQuickRecordSnapshotKey` 并返回，不创建新任务；跨分钟/跨日会取消旧任务、更新 request ID，发布时继续同时核对 request ID 与 key，旧时间结果不能反写。生命周期刷新只有 key 真正变化时才清旧候选，用户关闭的同一候选 ID 不会被强制重开。
- 修改文件：`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 测试与矩阵：新增后台过夜跨日 key、生命周期刷新只清陈旧候选、个人通勤窗口前不出现、窗口内符合样本可出现、已有今日早通勤继续阻止的 XCTest；`FLOW-41` 覆盖冷启动、后台过夜、同一分钟 20 次前后台、跨分钟/跨日、周末、不满足样本、早餐、OCR/草稿/今日回放高优先级、1,000 条与卡顿观察。
- 全局边界复核：`highConfidenceQuickRecordSuggestionForSnapshot`、`minimumCommuteSupport`、`isMorningCommutePromptTime`、个人时间窗、稳定金额、`hasTodayCommuteRecord`、一键保存与 `shouldShowHighConfidenceQuickRecord` 均无差异；首页动态主动作顺序、宠物关闭行为、Timer、会员、回放、存储、AI、痕迹和其他 Tab 未改。没有新增通知、自动保存、主线程账本扫描或 SwiftUI `body` 计算。
- 性能复核：前台入口先比较 day/member/minute/revision key；无变化路径在构造账本输入和后台任务前返回。真正跨日时生活线索和通勤继续复用一次不可变输入、`.utility` 任务与请求 ID，不在主线程执行候选筛选；快速前后台不会堆叠任务，Timer 路径不清卡、不制造每分钟视觉闪烁。
- 验证证据：`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过；包括 `git diff --check`、生活语义、体验、文案、会员、AI、无障碍、可观测性、主题、迁移、SQLite、100/1,000/5,000 条和三张真实 12MP 夹具，仅保留既有 5 条 soft copy warning。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 剩余风险：Windows 无 Swift/Xcode/iPhone；`ScenePhase` 生命周期接线、严格并发/XCTest、真实锁屏过夜、同一分钟 20 次前后台、个人时间窗口与 1,000 条前台恢复 hitch 仍需 `FLOW-41` 真机签收，因此不得标记 `VERIFIED`。
- 下一步：用 Xcode Debug/Release、XCTest 和 iPhone 执行 `FLOW-41`；如仍不显示，先核对真机当时是否满足个人时间窗口、历史稳定样本、今日重复和首页高优先级动作，不得直接放宽规则或改首页动态主动作。

---

## 31. FIX-011：痕迹热点与首页周记推荐状态统一（2026-07-20）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 用户真机反馈：本周已有 3 笔记录，痕迹页可手动“回看这一段”，首页没有出现周记跳转提示，但痕迹 Tab 显示黄色热点；进入痕迹页再返回后热点仍存在。
- 已确认根因：首页动态主动作已经使用 `LOGIC-15` 的周记主动推荐门槛（至少 3 笔且覆盖 2 个记录日），并保持今日回放优先；旧 `PlaybackRouteGuidance` 仍仅按本周 3 笔生成 `.weekSliceReady`，独立驱动 Tab 热点。原首页固定 `routeGuidanceContent` 已从渲染层移除，旧引导却未完整退场；进入痕迹 Tab 也不再消费该状态，导致首页、热点和手动入口三套语义分叉。
- 目标：手动查看继续随时可达；首页周记推荐和痕迹热点共用同一成熟度、播放资格与完成事实；热点只表达“本周成熟痕迹尚未实际看到”，在生活/本周有效快照显示后消费，但不得把进入页面记作周记播放完成。
- 允许修改：`InteractionStateModels.swift` 的纯热点策略；`HomeViewModel.swift` 的当前周已查看状态与旧周引导退场；`ContentView.swift` 的热点条件与痕迹回调；`StatsWebView.swift` 在生活/本周有效快照发布后的查看确认；必要的 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：首页 OCR→手动草稿→今日回放→周/月痕迹→复盘→继续记录的动态主动作顺序、`3 笔＋2 个记录日` 与月章门槛不变；手动痕迹入口、周记内容、播放资格、额度/扣次、80% 完成判定、痕迹加载/缓存/预热、主题、会员、AI、宠物、存储同步与 `ARCH-03` 不变。
- 边界处理：3 笔但仅 1 个记录日不亮热点；今日回放可继续覆盖首页主动作，但成熟周记可以作为低干扰热点存在；只有生活模式、本周范围且有效快照已经发布时才记为已查看，进入本月/线索、加载取消或空的未准备状态不消费；同一 ISO 周只提醒一次，未成熟时提前进入不影响之后成熟提醒；查看只清热点，不写播放完成。
- 性能边界：复用 `homeJourneyLedgerFacts` 和已准备的 `TraceChapterSnapshot`，不得在 `ContentView`、Tab 点击或 SwiftUI `body` 新增完整账本筛选、分组或签名；已查看状态只进行一次小型持久化写入。
- 验收：覆盖 3 笔/1 天、3 笔/2 天＋今日未回放、本周有效快照消费、本月/线索不消费、同周不重复、跨周重置、额度不足、已完成播放、加载取消和 80% 完成边界；Windows 只可标记 `CODE_DONE`，Xcode/iPhone 签收前不得标记 `VERIFIED`。
- 开始现场：继续保护 `COPY-02`、`UI-FIX-03`、`FIX-010` 及 `StatCardView.swift`、`web-preview/app.js`、提示文档、素材与 `tmp/` 的既有修改/未跟踪内容；本项不覆盖、不回退、不提交相邻任务。
- 实现：新增纯 `WeekTraceDiscoveryPolicy`，热点成熟度直接复用 `PlaybackMaturityPolicy.weekIsReady`；显示条件统一为周记达到 3 笔＋2 个记录日、仍可播放、当前周未完成且当前周未查看。`HomeViewModel` 复用既有 `homeJourneyLedgerFacts` 与 `SummaryPlaybackQuotaStore`，按 ISO 周持久化一个轻量已查看 key；清空本机账本时同步清理该 key，周记达到 80% 完成时也记为已查看，但不改变原完成存储。
- 有效查看边界：`StatsWebView` 只在生活模式、本周范围、非自定义范围、当前周刷新完成且 `TraceChapterSnapshot` 已发布时消费热点；旧快照刷新中、进入本月/线索、自定义范围、任务取消和未成熟周均不写已查看。后台预热本周时因当前可见范围不是本周，不会误消费。
- 旧状态退场：移除 `.weekSliceReady`、`.fiveRecordsNeverPlayed` 的生成、首页不可达提示条和 Tab 热点依赖；`PlaybackRouteGuidance` 只保留首笔今日回放承接。首页动态主动作、今日回放优先和周/月动作目的地保持不变；历史分析事件白名单保留旧值以兼容既有本机日志，不再产生新事件。
- 修改文件：`NativeDemoApp/Models/InteractionStateModels.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/ContentView.swift`、`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增 3 笔/1 天不成熟、3 笔/2 天显示热点、有效快照才消费、已查看/已完成/无额度不显示，以及“今日回放仍优先但成熟痕迹可亮低干扰热点”的确定性 XCTest；静态门禁锁定统一成熟度、ISO 周已查看状态、有效快照消费和旧周引导清零；新增 `FLOW-43`。`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，包含生活语义、文案、会员、AI、无障碍、可观测性、主题、迁移、SQLite、100/1,000/5,000 条和三张真实 12MP 夹具；仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改首页 OCR→草稿→今日回放→周/月痕迹→复盘→继续记录顺序、`3 笔＋2 天`/月章门槛、手动痕迹入口、周记内容、额度/扣次、80% 完成判定、痕迹缓存/预热/加载遮罩、主题、会员、AI、宠物、通勤、存储同步、`COPY-02` 或 `ARCH-03`；未覆盖用户既有脏工作区。
- 剩余风险：Windows 无 Swift/Xcode/iPhone；新增 `@Published` 已查看状态、SwiftUI Tab 热点刷新、痕迹快照发布回调、跨 ISO 周、额度 0、80% 完成和快速进入/退出仍需 Xcode Debug/Release、XCTest 与 iPhone 按 `FLOW-43` 签收，因此不得标记 `VERIFIED`。
- 下一步：在 Xcode/iPhone 执行 `FLOW-43`；如有问题只定向修复热点显示或消费，不降低成熟门槛、不改变首页主动作顺序，也不启动 `ARCH-03`。

---

## 32. COPY-FIX-01：播放章节元素方法缺少显式返回（2026-07-20）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- Xcode 错误：`SummaryPlaybackSheet.swift:1029` 报告 `Missing return in instance method expected to return '[(symbol: String, text: String)]'`。
- 根因：`chapterElementChips(for:)` 在 `supportLine` 分支之后还有第二条表达式，属于多语句方法；Swift 不会对末尾的 `chapterSignals(...).map(...)` 执行单表达式隐式返回，因此非 `supportLine` 路径缺少显式 `return`。
- 允许修改：只为该映射结果补显式返回，并增加静态防回流与本文档记录。
- 冻结边界：不修改章节 signal 集合、顺序、图标、标签、`supportLine` 隐藏规则、播放文案、章节数量/时长、照片、进度、额度、会员、分享、痕迹热点或其他 UI。
- 开始现场：提交 `00e5ff4` 已推送；继续保护未提交的 `StatCardView.swift`、`web-preview/app.js`、提示稿、素材、`tmp/` 与缓存目录，本项不覆盖、不暂存这些文件。
- 修复：将非 `supportLine` 路径的 `LifeStorySignalService.chapterSignals(from: chapter).map(...)` 改为显式 `return`；空数组分支与映射内容保持原样。
- 修改文件：`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`scripts/experience_static_check.ps1`、本文档。
- 验证证据：新增显式返回静态防回流；`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，覆盖生活语义、文案、会员、AI、无障碍、主题、迁移、SQLite、100/1,000/5,000 条和真实 12MP 照片夹具；仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改 signal 筛选/顺序、图标、标签、`supportLine` 行为、SwiftUI 布局、播放文案、章节、时长、照片、进度、额度、会员、分享、痕迹热点、通勤或存储同步；用户未提交现场保持原样。
- 剩余风险：Windows 无 Swift/Xcode，必须在原 Xcode 环境重新编译确认该错误清零；完成编译前不得标记 `VERIFIED`。
- 下一步：Xcode 重新编译；若仍有错误，只修同一编译链，不扩张为播放 UI 或文案调整。

---

## 33. 首页首帧、宠物陪伴与今日列表定向收口（2026-07-21）

用户真机反馈并确认连续修复以下问题：保存一笔返回首页时宠物偶发只剩外框、账单发生闪动；宠物需要支持拖动换位与长按隐藏，并恢复基于真实天气和当天账单的自然关怀；“今天留下的痕迹”全量列表密度过松；首页无记录时今日小记与宠物语气生硬。本轮按下列顺序执行，一次只允许一个任务为 `IN_PROGRESS`。

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | UI-FIX-04 | 保存后首页首帧与账单稳定发布 | `CODE_DONE` | 只修宠物首帧、今日小记计算时机、账单元数据发布与保存高亮；不改账单数据、宠物形象或首页动作 |
| 2 | PET-03 | 宠物拖动定位与长按隐藏 | `CODE_DONE` | 只新增宠物局部交互、位置持久化和恢复说明；不改首页布局、设置含义或提示优先级 |
| 3 | PET-04 | 天气＋真实账单可信关怀文案 | `CODE_DONE` | 只扩展可解释宠物消息策略；不把暖标签当事实，不推断消费原因、感受或历史天气 |
| 4 | UI-04 | “今天留下的痕迹”列表密度收敛 | `CODE_DONE` | 保留点击编辑、左滑删除、照片、主题与记录信息；只调整层级、间距和重复汇总 |
| 5 | COPY-04 | 首页与宠物空态语气收敛 | `CODE_DONE` | 只改无记录文案；不改变首页动态主动作优先级、目的地或成熟门槛 |

### UI-FIX-04：保存后首页首帧与账单稳定发布

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 代码与全仓门禁已完成，不冒充 macOS/Xcode 编译通过。
- 现象与根因：`ContentView` 只构建当前 Tab，保存后返回会重新创建 `HomeView`；`PixelPetAnimationView.currentFrame` 初始为 `nil`，外框先出现而首帧等待 `.task` 加载裁切。`todayStoryNarrative` 仍在 SwiftUI 视图计算中调用完整生活线索聚合，延后宠物任务。账本变化又会立即清空 `homeLifeMarkTextsByItemID`，后台完成后重新插入标签并改变行高；最新手工记录同时播放约 1.45 秒高亮，且存在多个安排入口，共同形成非必现闪动。
- 目标：宠物承载出现时立即有稳定产品首帧；今日小记只在账本修订、日期或会员真正变化时准备；旧账单元数据在新快照发布前保持稳定，新记录不因晚到标签改变首帧高度；每个保存 ID 最多安排一次不改变布局的轻量反馈。
- 允许修改：`PixelPetAnimationView.swift` 的同步稳定帧承接；`HomeViewModel+Dashboard.swift` 的今日小记/生活线索首页快照；`HomeView.swift` 的只读消费与保存反馈；必要的纯策略 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：首页 OCR→草稿→今日回放→周/月痕迹→复盘→继续记录的状态顺序、主次入口、账单保存字段、今日列表排序、生活线索结论、宠物像素资源/帧率/开关、提示预算、主题、会员、AI、痕迹、回放、存储同步与 `ARCH-03` 均不改变。
- 性能边界：不得在 SwiftUI `body`、宠物帧推进、拖动或高亮动画中重新扫描完整账本、生成生活线索签名或解码全部 sprite；保持账本修订驱动、后台计算、取消和最新请求保护。
- 验收：冷缓存与热缓存返回首页都不出现空宠物框；手工保存、快捷通勤和编辑后三条路径账单不发生行高二次跳动或重复高亮；0/1/多笔、带/不带生活线索、1,000 条账本和低电量/Reduce Motion 均保持稳定。
- 开始现场：分支 `feature/xuzhangapp-staging`，提交 `18caea8`；保护用户既有 `StatCardView.swift`、`web-preview/app.js`、提示文档、`brand-assets/`、`tmp/` 与缓存目录，本轮不覆盖、不回退、不提交相邻现场。
- 实现：`PixelPetAnimationView` 在初始化时同步取得已缓存/可裁切的产品待机首帧，动画 `.task` 只负责后续帧推进；首页今日小记改为读取随 `HomeLifeMarkSnapshot` 后台准备的 `todayPrimaryLine`，SwiftUI 渲染不再调用完整账本生活线索聚合。账本修订时，同一天且会员身份不变会保留旧行线索直到新快照一次替换；跨日或会员身份变化仍立即清空，避免权限边界穿透。移除首页出现、最近记录 ID 变化和快捷通勤保存后的自动发光安排；行内明确编辑仍保留原一次反馈。
- 修改文件：`PixelPetAnimationView.swift`、`HomeViewModel+Dashboard.swift`、`HomeViewModel.swift`、`HomeView.swift`、`StateRegressionTests.swift`、`experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增生活线索主文确定性、同日/跨日/会员变化保留策略测试和 `FLOW-44`；静态门禁锁定同步首帧、渲染路径零聚合、自动发光退场与会员边界。`git diff --check`、体验静态检查及 `python scripts/validate_release_gate.py --phase windows` 全部通过，100/1,000/5,000 条、真实 12MP、生活语义、主题、迁移、SQLite 均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：首页动态主动作、账单字段/排序、生活线索结论、宠物像素资源/帧率/开关、提示预算、主题、会员、AI、痕迹、回放、存储同步和 `ARCH-03` 未改；用户既有脏工作区未覆盖。
- 状态：`IN_PROGRESS` → `CODE_DONE`；Windows 无 Xcode/iPhone，Swift 编译、冷/热缓存首帧、1,000 条首页返回、低电量与 Reduce Motion 仍需按 `FLOW-44` 真机签收，因此不得标记 `VERIFIED`。
- 下一步：启动 `PET-03`，只实现宠物拖动、位置安全边界、持久化与长按隐藏/恢复，不提前修改天气文案。

### PET-03：宠物拖动定位与长按隐藏

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 代码与全仓门禁已完成，不冒充 SwiftUI 真机布局签收。
- 历史归因：提交 `5fb76d2` 曾出现“长按我就能把我藏起来”文案，但历史视图只有普通点击按钮，没有宠物拖动位置、长按手势或持久化实现；本项补齐真实交互，不恢复虚假承诺。
- 目标：用户可拖动宠物在首页安全区域内换位，松手吸附最近左右边缘并保存相对位置；长按约 0.6 秒后明确隐藏，继续复用现有宠物开关，可从“我的”恢复；拖动、点击、长按互不误触。
- 允许修改：新增独立宠物浮层位置策略/本机 Store/交互 View；`HomeView` 只接入局部浮层；必要时使用现有 `SettingsViewModel` 宠物开关方法；对应 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不改变像素帧资源、帧率、点击消息生命周期、天气/定位权限、首页主动作、强提示遮挡、提示预算、底部 Tab、主题、账单、会员、AI、回放、存储同步或其他页面布局。隐藏只改变宠物开关，不删除账本或宠物素材。
- 性能与手势边界：拖动临时位移由独立组件局部持有，只在结束时持久化；首页不得随每个拖动帧重算账本。位置需按可用 viewport 夹取，避开顶部、底部 Tab 与 Safe Area；尺寸变化后旧位置必须重新夹取。长按成功不能再触发点击消息，拖动结束不能误触点击。
- 实现：新增 `MovablePixelPetOverlay`、`HomePetOverlayPositionPolicy` 与本机位置 Store。拖动使用组件内 `@GestureState`，只在结束时按 viewport 夹取垂直位置、吸附最近左右边缘并持久化；气泡按左右位置朝屏幕内侧展开。点击、10pt 短拖与 0.6 秒长按通过临时点击抑制隔离；长按复用 `SettingsViewModel.petCompanionEnabled = false`，页面显示“可在我的重新开启”。VoiceOver 增加隐藏、移到左侧和移到右侧动作。
- 修改文件：`PixelPetAnimationView.swift`、`HomeView.swift`、`StateRegressionTests.swift`、`experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增左右吸附、上下边界、小 viewport 与 UserDefaults 归一化测试，新增 `FLOW-45`；静态门禁锁定局部拖动、位置持久化、长按真实开关和恢复路径。`git diff --check`、体验静态检查及完整 Windows release gate 全部通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改像素资源/帧率、点击消息生命周期、天气权限、首页主动作、强提示遮挡、提示预算、底部 Tab、主题、账单、会员、AI、回放、存储同步或其他页面布局。
- 状态：`IN_PROGRESS` → `CODE_DONE`；Windows 无 Xcode/iPhone，复合手势优先级、真实 Safe Area、尺寸变化、VoiceOver 自定义动作、20 次连续点击/拖动/长按仍需 `FLOW-45` 真机签收，不得标记 `VERIFIED`。
- 下一步：启动 `PET-04`，只补可信关怀文案与交互提示，不改变刚完成的移动/隐藏实现。

### PET-04：天气＋真实账单可信关怀文案

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 历史归因：`5fb76d2` 曾包含高温、冷饮、咖啡、雨天等大池，但会鼓励消费、推断居家/治愈/值得，并把当前天气套到历史记录；`e3979e5` 为修复可信边界移除这些池，保留真实账单事实和简单天气后缀，却同时丢失自然关怀与饮品组合。
- 目标：建立可解释消息角色：低频交互提示、当前天气关怀、当前天气＋当天真实账单组合、记录发生时天气事实、无上下文陪伴。高温、降温、雨雪可以给克制行动提醒；咖啡、普通饮料和明确冷饮必须分级，不能把咖啡自动说成冷饮或声称用户已经饮用。
- 允许修改：`PetCompanionCopy.swift` 的带 ID 短句池；`PetCompanionService.swift` 的纯候选策略、受控关键词与频率；必要的轻量本机提示状态、XCTest、文案/体验门禁、真机矩阵和本文档。
- 冻结边界：不读取 `displayEmotionTag` 作为事实，不根据金额推断奖励/冲动/价值，不推断消费原因、用户感受、人物关系、居家状态或历史天气；不新增网络调用，不改变天气权限、宠物交互、账单、首页主动作、提示预算和其他页面文案。
- 事实边界：当前天气只用于“现在”的提醒；记录自身 `memoryContext.weatherKind` 才能描述该笔发生时天气。咖啡可与高温并列并独立提醒补水，只有标题明确含冰/冷饮/雪糕等才能说“清凉”；购买记录只能说“记下”，不能声称已经喝完或使用。
- 实现：新增一次性可执行交互提示，首次点击说明“拖动换位、长按休息”，后续恢复真实上下文消息。当前高温、降温、雨雪分别提供克制的防晒补水、添衣、带伞和脚下提醒；当前天气只在快照不晚于 1 小时时使用，并始终以“现在”表达。当天通勤、咖啡、饮品、明确冷饮和热饮可与当前天气组合；普通咖啡不会被称为冷饮，只有餐饮分类且标题明确含冰饮/冷饮/雪糕等证据才使用冷饮表达，购物类同词不误判。
- 保存边界：当天刚保存的记录可在原记录事实后追加当前关怀；历史补记只使用该记录自身 `memoryContext`，不继承当前天气。咖啡、饮品和冷饮只说“记下”，不声称已经饮用；系统暖标签、金额、消费原因、居家状态、关系和感受均未进入判断。
- 修改文件：`NativeDemoApp/Services/PetCompanionCopy.swift`、`NativeDemoApp/Services/PetCompanionService.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增普通咖啡＋高温、明确冷饮、购物同词反例、当天保存＋当前关怀、历史补记、过期天气和首次提示一次性 XCTest；静态门禁锁定天气新鲜度、同日边界、餐饮证据和 `FLOW-46`。`git diff --check`、体验静态检查及 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、真实 12MP、生活语义、主题、迁移与 SQLite 均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改宠物气泡生命周期、拖动/长按、像素帧、天气/定位权限、账单字段、首页动态主动作、提示预算、主题、会员、AI、回放、存储同步或其他页面文案；用户既有脏工作区未覆盖。
- 状态：`IN_PROGRESS` → `CODE_DONE`；Windows 无 Swift/Xcode/iPhone，真实天气切换、首次提示持久化、多主题/VoiceOver 和当天/历史记录组合仍需按 `FLOW-46` 真机签收，不得标记 `VERIFIED`。
- 下一步：启动 `UI-04`，只收敛“今天留下的痕迹”全量列表密度、层级和重复汇总，不修改首页摘要卡、记录操作、主题或宠物。

### UI-04：“今天留下的痕迹”列表密度收敛

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 目标：全量列表在保留标题、金额、分类、时刻、情绪/生活线索和照片的前提下减少无意义留白；一屏可多看到记录，同时不牺牲点击编辑、左滑删除和图片入口。
- 允许修改：`HomeView.swift` 中 `todayRecordsSheet`、`todayRecordInlineRow`、`todayRecordSummary` 与底部汇总的间距、字号层级和重复信息；对应静态门禁、真机矩阵和本文档。
- 冻结边界：首页摘要卡和动态主动作、今天记录顺序、记录字段、点击有图进入详情/无图进入编辑、左滑删除、照片缩略图、情绪与生活线索资格、主题 Token、会员、宠物、回放、存储同步和 `ARCH-03` 均不改变。
- 边界处理：顶部不再重复底部的笔数/合计，但保留“点任一条可调整”的操作提示；情绪与生活线索可同排承接，空间不足时仍可纵向显示；照片保持原 82pt 可辨识高度，不以压缩图片换取密度；大字、VoiceOver 和空/单/多记录仍需稳定。
- 实现：页面外层间距、行间距、行内垂直留白和标题/金额字号做定向收敛；顶部只保留操作提示，笔数与合计仅在底部出现一次。情绪标签与生活线索使用 `ViewThatFits`，宽度足够时同排、空间不足时纵向承接；照片缩略图继续保持 82pt。
- 修改文件：`NativeDemoApp/Views/HomeView.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：静态门禁锁定紧凑间距、单一汇总、适应式标签和照片高度；新增 `FLOW-47` 覆盖 0/1/8 笔、有图/无图、编辑删除、小屏/大字与无障碍。`git diff --check`、体验静态检查及 `python scripts/validate_release_gate.py --phase windows` 全部通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：点击有图进入详情、无图进入编辑、左滑删除、记录顺序/字段、照片加载、情绪/生活线索资格、首页摘要与动态主动作、主题、会员、宠物、回放和存储同步均未修改；没有新增账本扫描或页面拆分。
- 状态：`IN_PROGRESS` → `CODE_DONE`；Windows 无 Xcode/iPhone，`ViewThatFits` 实际换行、特大字号、VoiceOver、滑动删除和长列表滚动仍需按 `FLOW-47` 真机签收，不得标记 `VERIFIED`。
- 下一步：启动 `COPY-04`，只把首页与宠物无记录状态从催促式记账指令收敛为平静事实和陪伴语气。

### COPY-04：首页与宠物空态语气收敛

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 目标：首页今日小记在 0 笔时平静说明当前事实，已有可信历史节奏时只呈现一层观察；宠物只做陪伴，不再重复“硬凑、先记、只输金额”等记账指令。
- 允许修改：`HomeViewModel+Dashboard.swift` 的 0 笔标题/副文案；`PetCompanionCopy.swift` 的 0 笔短句；必要的纯文案策略测试、静态门禁、真机矩阵和本文档。
- 冻结边界：首页动态主动作优先级、按钮标题、目的地、成熟门槛、常用金额/场景计算、1 笔以上今日小记、宠物天气/账单候选、交互提示、气泡生命周期、主题、会员、账单与存储同步均不改变。
- 实现：新增纯 `HomeEmptyTodayCopyPolicy`。0 笔标题统一为“今天还没有记录”；有稳定常用金额时只陈述往常该时段常见金额/分类，有本周主场景时只陈述该事实，无可靠历史时说明“今天这一页暂时还是空的”。移除“从这里开始、只输金额、先放进账本”等催促式语气。宠物 0 笔短句改为“我在这儿陪你 / 我就在旁边”，不再说“硬凑、先记、想起一笔再写”。
- 修改文件：`NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift`、`NativeDemoApp/Services/PetCompanionCopy.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增首页无记录建议/场景/纯空态与宠物陪伴语气 XCTest；静态门禁禁止旧催促式短句回流，新增 `FLOW-48` 覆盖无历史/常用金额/主场景、天气开关、多主题、大字与 VoiceOver。`git diff --check`、体验静态检查及 `python scripts/validate_release_gate.py --phase windows` 全部通过，100/1,000/5,000 条、真实 12MP、生活语义、文案、主题、迁移与 SQLite 均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：首页动态主动作顺序、按钮标题/目的地、周/月成熟门槛、常用金额与场景计算口径、1 笔以上今日小记、宠物天气/真实账单候选、首次交互提示、气泡生命周期、主题、会员、存储同步和 `ARCH-03` 均未修改。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 无 Xcode/iPhone，真实字体排版、VoiceOver 朗读、历史建议命中与天气优先级仍需按 `FLOW-48` 真机签收，因此不得标记 `VERIFIED`。
- 本轮收口：`UI-FIX-04`、`PET-03`、`PET-04`、`UI-04`、`COPY-04` 均达到 `CODE_DONE`；后续只按 `FLOW-44`～`FLOW-48` 做 Xcode/iPhone 定向签收，不启动 `ARCH-03` 或相邻产品改造。

---

## 34. AI-04：复盘推荐指令证据化与通用兜底（2026-07-21）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 用户确认：复盘首页“近 7 天 / 前 7 天”与指令台“本周 / 上周同期”可保留不同用途；“同期”继续按相同日序，不要求精确到同一时刻。需要修复的是推荐指令动态程度不足，以及交通/通勤作为固定兜底会对非上班用户形成错误假设。
- 目标：具体分类、天气和补记推荐必须由真实账本证据产生；固定兜底只保留不假设生活方式的通用查账/对比动作。复盘首页点击“做对比”继续承接首页已经展示的“近 7 天 / 前 7 天”口径；用户主动输入“本周”时仍使用现有自然周同期规则。
- 允许修改：`InsightComputationService.swift` 的推荐候选、证据门槛、排序和通用兜底；`InteractionStateModels.swift` 的安全默认指令；`InsightWebView.swift` 的任务入口承接、动态默认指令和空推荐行；对应 XCTest、体验静态门禁、真机矩阵和本文档。
- 冻结边界：不修改 AI 自然语言识别、时间范围解析、本周/上周同期与本月/上月同期计算、查询/对比结果、证据集合、补记确认前零写入、通勤候选时点/金额/重复判断、会员/额度、主题、首页动态主动作、痕迹、宠物、存储同步或 `ARCH-03`。
- 推荐边界：交通、餐饮、兴趣、雨天通勤等具体主题不得出现在固定兜底；分类对比需满足跨两段的记录数、记录日或明显新增/消失证据；通勤补记需有明确通勤语义且跨多个日期，不再以低金额交通代替通勤；当前下雨不能单独推出“上一次雨天通勤”。没有可靠补记候选时允许不展示推荐词，不为凑满数量制造生活假设。
- 性能边界：继续按账本修订、会员和有效天气上下文在后台一次准备查/比/补三组快照；普通任务切换、输入、滚动和 SwiftUI 重绘只读缓存，不恢复主线程账本扫描或随机推荐。
- 开始现场：分支 `feature/xuzhangapp-staging`，基线提交 `ddb8216`；继续保护未提交的 `StatCardView.swift`、`web-preview/app.js`、提示文档、素材、`tmp/` 与缓存目录，本项不覆盖、不回退、不提交相邻现场。
- 实现：固定查账兜底收敛为“最近 7 天 / 最高单笔 / 重复账单”，固定对比兜底只保留最近 7 天、本周和本月三种通用时间段，补遗漏在无可靠证据时不展示推荐；每类最终最多 3 条，避免为了填满横滑区制造生活假设。分类查询必须在最近 7 天至少出现 2 笔且覆盖 2 个日期；分类对比必须具备跨两段的重复证据，或某一段至少 2 笔且覆盖多个日期的新增/消失证据，并按金额变化、笔数与稳定分类顺序排序。
- 通勤与天气边界：通勤只接受 `scenePackId == commute` 或标题中的通勤、上班、下班、早/晚高峰、到岗等强语义；低金额交通、地铁/公交单词、停车费和普通旅行不再代替通勤。补记推荐要求最近 7 天至少 2 条明确通勤且覆盖 2 个日期；当前下雨不能单独生成“上一次雨天通勤”，必须存在记录自身带雨天上下文的真实通勤。
- 入口与口径：复盘首页“做对比”默认承接“最近 7 天和前 7 天”，对应引擎继续使用现有上一等长区间；用户主动输入本周或本月时，原上周/上月同期日序规则保持。查记录可优先承接当前快照中证据最强的动态建议；补遗漏没有证据时保持空输入和既有示例占位，不伪造默认通勤。
- 缓存与流畅度：推荐在复盘首屏 `onAppear` 及账本修订/会员变化时，基于一次不可变输入在 utility 后台任务同时生成查/比/补三组快照；缓存键继续由账本修订、会员和有效天气组成。已移除 `selectReviewTask` 中的准备调用，点击任务和任务内切换只读缓存，未准备完成时使用通用兜底，不扫描全局账本；补遗漏推荐为空时不渲染空横滑容器。
- 修改文件：`NativeDemoApp/Services/InsightComputationService.swift`、`NativeDemoApp/Models/InteractionStateModels.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：更新并新增确定性 XCTest，覆盖安全默认指令、空账本/非通勤、单笔停车费、真实餐饮跨期证据、同日与跨 2 日明确通勤、当前雨但无历史雨天通勤、真实雨天通勤、最近 7 天/前 7 天范围，以及每组最多 3 条。静态门禁锁定固定兜底零分类假设、低金额交通不可推通勤、任务点击零准备/零账本扫描、复盘首屏预生成和 `FLOW-49`。`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、真实 12MP 照片、生活语义、文案、主题、迁移和 SQLite 均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改自然语言识别、时间范围解析、本周/上周同期与本月/上月同期计算、查询/对比结果、原始证据、补记候选时点/金额/重复判断、确认前零写入、会员/额度、主题、首页动态主动作、痕迹、宠物、存储同步或 `ARCH-03`；用户既有脏工作区未覆盖。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 Swift 推荐策略、`@ViewBuilder` 空推荐分支、XCTest、真实 1,000 条首屏预生成耗时、20 次任务切换、Dynamic Type 和 VoiceOver 仍需按 `FLOW-49` 完成 Xcode Debug/Release 与 iPhone 签收，因此不得标记 `VERIFIED`。
- 下一步：只执行 `FLOW-49` 与既有统一 Xcode/真机矩阵；签收发现问题时定向修复 `AI-04`，不放宽证据门槛、不恢复点击时全账本计算，也不启动 `ARCH-03` 或相邻产品改造。

---

## 35. PERF-15：账本变动后的缓存失效与稳定发布（2026-07-21）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 用户目标：账本新增、编辑、删除、OCR/AI 批量导入、照片变化和云端合并后，首页、痕迹与复盘不得因为多份缓存各自失效而连续闪现、卡顿或堆积后台任务；普通滚动、任务切换和页面动画继续只读已经准备好的快照。
- 已确认主因：首页 `ItemDerivedCache` 在 `items.didSet` 后只标记过期，下一次 SwiftUI getter 会在 `@MainActor` 同步排序、筛选今天/周/月/年并统计旅程事实；同一次账本变动还立即清空首页主文和通勤建议。复盘页面快照与推荐快照分别发布，页面快照整体使用布局动画；痕迹虽已有旧快照承接和无动画发布，随后仍会预热另一范围，快速连续修订时存在后台竞争余量。
- 允许修改：`HomeViewModel` 的派生缓存后台准备、账本修订与最新请求保护；首页相关快照的同日/同会员稳定承接和无动画原子发布；AI 复盘快照的无布局动画发布；痕迹预热的新修订取消/让步；直接必要的逻辑提交合并；对应 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不修改账本字段、排序结果、分类/OCR/AI 识别、周记/月章/回放文案、会员/额度/StoreKit、云端 DTO 与冲突规则、主题/UI 布局、路由、首页动态主动作顺序与成熟门槛、痕迹筛选/证据、宠物、照片按需加载和持久化语义；`ARCH-03` 保持 `NOT_STARTED`。
- 稳定性边界：同日且同会员身份时保留上一份可见首页主文，直到新修订完整快照一次替换；跨日或会员身份变化立即清除不安全旧内容。旧修订不得覆盖新修订；快速连续修改必须取消或合并旧任务，不因等待新快照把真实空数据和“尚未准备”混为一谈。
- 性能边界：完整账本排序/筛选/统计不得由 SwiftUI getter 或主线程缓存未命中触发；一个逻辑账本提交尽量只产生一次修订。复盘与痕迹保留旧内容刷新，发布时禁用布局动画；痕迹可见范围始终优先，预热只能在当前结果稳定且修订仍有效时执行。
- 开始现场：分支 `feature/xuzhangapp-staging`，基线提交 `ddb8216`；保留未提交 `AI-04`、`StatCardView.swift`、`web-preview/app.js`、提示文档、素材、`tmp/` 与缓存目录，本项不覆盖、不回退、不提交相邻现场。
- 计划验证：覆盖 1 次账本变动只接受 1 次最新派生发布、旧修订不能反写、同日/同会员内容稳定、跨日/会员清理、快速 20 次修改任务收敛、100/1,000/5,000 条边界、首页/复盘发布零布局动画及痕迹预热取消；Windows 完成静态与确定性门禁，Xcode/iPhone Instruments 前只能标记 `CODE_DONE`。
- 实现：首页派生缓存收敛为 `ItemDerivedCacheSnapshot`，一次包含今天/最近三笔/周/月/年、旅程事实与今日回放输入；账本变动后先经过 40ms 可取消合并窗口，再在 utility 子任务排序、筛选和统计。SwiftUI getter 只读取当前或同日上一份快照，不再同步重建；跨日未准备时返回安全空快照。发布同时核对请求 ID、待发布 key 与当前账本修订/日期，旧任务不能覆盖新修订。
- 首页稳定发布：账本变化先使旧可操作通勤候选失效，但同日同会员继续保留上一份今日主文和行级生活线索；新快照完成后一次发送可见更新。跨日或会员身份变化立即清空旧主文与线索。首页生活线索与通勤准备会等待对应派生修订，不会用“新 revision＋旧 todayItems”生成错误缓存。
- 逻辑提交合并：OCR 草稿状态、分类、金额、批量 resolved/pending，以及照片新增、删除和换封面均改为先修改局部 `HomeItem`/数组副本，最后一次赋回 `items`；正常编辑、手动/AI/OCR 批量、删除、备份恢复和云端合并继续沿用原变化集与同步入口。修复后生产 `HomeViewModel` 不再存在 `items[idx].field = ...` 的逐字段发布。
- 复盘与痕迹：复盘页面快照仍保留旧内容与独立推荐缓存，但最终替换使用禁用动画事务，不再对整页布局做 0.18 秒交叉动画；痕迹可见范围发布后先让出 250ms，再以 utility 优先级预热另一范围，期间新修订、切换或离页均可取消，原缓存键、旧快照承接与 `LatestRequestGate` 保持。
- 修改文件：`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增 5,000 条原子派生快照、旧修订/旧请求拒绝、首页同日/跨日/会员保留策略和痕迹延迟预热 XCTest 接线；静态门禁锁定后台 utility 计算、40ms 合并、getter 零同步重建、逻辑提交单次赋值、首页稳定发布、复盘零布局动画、痕迹可取消预热及 `FLOW-50`。`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、三张真实 12MP、AI-04、生活语义、文案、主题、迁移和 SQLite 均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改账本字段/排序结果、分类/OCR/AI 识别、查询/对比/补记结论、周记/月章/回放文案、会员/额度/StoreKit、云端 DTO/冲突规则、主题/UI/路由、首页动态主动作与成熟门槛、痕迹筛选/证据、宠物、照片按需加载、持久化语义或 `ARCH-03`；未覆盖用户既有脏工作区和未提交 `AI-04`。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增并发快照类型、`@MainActor` 请求接力、严格 Sendable 诊断与 XCTest 尚未实际编译；100/1,000/5,000 条保存后 2 秒 Main Thread Hitches、SwiftUI 更新次数、快速 20 次编辑的任务回落、首页同日/跨日/会员切换、复盘替换和痕迹预热仍需按 `FLOW-50` 完成 Xcode Debug/Release、XCTest 与 iPhone Instruments 签收，因此不得标记 `VERIFIED`。
- 下一步：只执行 `FLOW-50` 与既有统一 Xcode/iPhone 矩阵；签收若出现编译、并发或真机闪动，仅定向修复 `PERF-15`，不回退后台快照和单次提交，也不启动 `ARCH-03` 或相邻产品任务。

---

## 36. PET-FIX-01：宠物固定锚点、拖动手势与默认位置修复（2026-07-21）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 真机现象：宠物无法可靠拖动；普通点击打开/关闭气泡时，宠物会在页面中部与右侧两个位置之间跳；用户要求默认恢复到帧动画改造前的右下角。
- 根因：`MovablePixelPetOverlay` 的 `ZStack` 先按宠物栈自身尺寸布局，再扩展为全屏；无气泡时栈宽 52pt、出现气泡后栈宽最多 210pt，扩展后的栈整体保持居中，导致右对齐的宠物本体随气泡宽度横向移动。拖动又以 `simultaneousGesture` 挂在首页纵向 `ScrollView` 内，真机上会与页面滚动竞争。
- 目标：宠物本体始终锚定同一屏幕坐标，气泡只向屏幕内侧展开；拖动优先于父级滚动并只在超过阈值后提交；点击、长按和拖动互不误触；首次默认位置精确复用旧版 `.bottomTrailing + trailing 16 + bottom 102`。
- 允许修改：`PixelPetAnimationView.swift` 的浮层布局、纯位置/交互策略与手势组合；对应 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不修改像素资源、帧率、气泡文案/生命周期、天气与账单上下文、长按隐藏含义、宠物开关、首页动态主动作/卡片/滚动内容、提示预算、主题、会员、AI、回放、账本、存储同步或 `ARCH-03`；保留已经持久化的有效用户位置，不用修复强制重置用户选择。
- 验收：默认与气泡显隐时宠物中心均保持旧版右下角；点击 20 次位置不变；从宠物本体向四向拖动可跟手、松手吸附左右边缘并保存，页面不抢滚；小于阈值的手指抖动不提交位置；长按只隐藏不点击。Windows 完成策略/静态门禁，Xcode/iPhone 复合手势签收前只能标记 `CODE_DONE`。
- 实现：移除“内容尺寸 `ZStack` 先布局、再扩展到全屏”的错误层级，改为先给宠物栈保留旧版右 16pt/底 102pt 内边距，再由全屏 frame 按左右边缘对齐；气泡出现只向屏幕内侧增加宽度，宠物本体中心不再移动。拖动从与父滚动平级的 `simultaneousGesture` 改为宠物本体的 `highPriorityGesture`；统一 8pt 欧氏距离门槛，未超过门槛不更新临时位置、不持久化、不触发选中反馈，超过后才抑制点击并在结束时吸附/保存。
- 默认与存储边界：`HomePetOverlayPlacement.defaultPlacement` 继续为 `.right + verticalFraction 0`，实际对应帧动画改造前 `.bottomTrailing + trailing 16 + bottom 102`；没有改 UserDefaults key，也没有清空已经保存的有效位置。左右吸附、上下夹取、尺寸变化与 VoiceOver 移位动作继续复用原策略。
- 修改文件：`NativeDemoApp/Views/Components/PixelPetAnimationView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增旧版右下角默认锚点、零位移提交稳定和 1～7pt 抖动/8pt 拖动门槛 XCTest；静态门禁锁定 viewport 边缘对齐、旧内容尺寸 ZStack 退场、高优先级拖动、零 `simultaneousGesture(dragGesture)` 和 `FLOW-51`。`git diff --check`、体验静态检查及 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、真实 12MP、AI、生活语义、文案、主题、迁移与 SQLite 均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改宠物帧资源/帧率、气泡文字/生命周期、天气/账单消息策略、长按隐藏和设置恢复、首页内容/动态主动作/滚动数据、提示预算、主题、会员、AI、回放、账本、存储同步或 `ARCH-03`；用户既有 `StatCardView.swift`、`web-preview/app.js`、提示稿、素材、`tmp/` 与缓存目录未覆盖。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，`highPriorityGesture` 与 `ScrollView`、点击和 0.6 秒长按的真实识别优先级，气泡过渡中的像素坐标、小屏 Safe Area、既有四类持久化位置和 VoiceOver 自定义动作仍需按 `FLOW-51` 真机签收，因此不得标记 `VERIFIED`。
- 下一步：在 Xcode Debug/Release 编译并用 iPhone 执行 `FLOW-51`；发现问题时只调整宠物局部手势组合和锚点，不改首页滚动结构、气泡文案或相邻产品逻辑。

---

## 37. AI-FIX-05：省略主语的上周期对比语义修复（2026-07-21）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 真机现象：输入“对比上周”会得到“上周 对比 前一周”；只有输入“这周对比上周”才得到用户日常语义预期的“本周 对比 上周同期”。同类“对比上月”也存在把上月当主体继续向前推一个月的风险。
- 根因：对比识别已经正确命中只读 `compare`，但通用时间解析把指令中唯一出现的“上周/上月”直接当成当前段；随后上一周期策略再减一周/一月。解析没有区分“省略主体后的参照对象”和“明确历史主体”。
- 目标：对比指令只有上周/上月、没有本周/本月且没有前一周/前一个月等历史参照时，按生活化省略语义补全为“本周对比上周同期 / 本月对比上月同期”；明确“上周对比前一周 / 上月对比前一个月”继续按历史双周期执行。
- 允许修改：`InteractionStateModels.swift` 中仅限“和/跟/与上周期比、比比上周期”的受控自然表达识别，`InsightWebView.swift` 中仅供 `compare` 使用的基准周期消歧；对应 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不修改普通“查上周/查上月”与生活总结的时间范围；不修改“这周对比上周”“本月对比上月”、明确历史双周期、周同星期日序/月同月日序、金额/笔数/分类/证据/排序、结果 UI、推荐缓存、查询与补记识别、确认前零写入、主题、会员、首页、痕迹、宠物、存储同步或 `ARCH-03`。
- 验收：`对比上周 / 和上周比 / 比比上周` 均为本周对比上周同期；`对比上月` 为本月对比上月同期；显式当前周期保持；`上周对比前一周 / 比较上周和前一周 / 上月对比前一个月` 保持历史比较；`查上周记录 / 查上月记录` 仍只查指定历史周期且不进入对比。
- 实现：AI 引擎只在识别结果为 `compare` 时进入专用基准周期消歧。只有上周/上月参照、没有本周/本月且没有前一周/前一个月、上上周/上上月等明确历史参照时，才复用既有“本周/本月”范围生成器；因此周同期、月同期的日期计算仍由原 `aiCommandPreviousRange` 唯一负责。普通查询、生活总结和最近周期范围继续走原解析器。
- 自然表达边界：在既有“对比/比较/相比”之外，仅增加带明确上周期参照的“和/跟/与上周（上月）比”和“比比上周（上月）”；没有时间/分类/账本范围的泛化“比”仍不会被当成查账对比。明确写出历史双周期时不补当前周期。
- 修改文件：`NativeDemoApp/Models/InteractionStateModels.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增端到端确定性 XCTest，覆盖“对比上周 / 和上周比 / 比比上周 / 这周对比上周”“对比上月 / 本月对比上月”、明确“上周对比前一周 / 比较上周和前一周 / 上月对比前一个月”，以及普通“查上周/上月”不进入对比；新增静态门禁和 `FLOW-52`。`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、真实 12MP、生活语义、文案、主题、迁移和 SQLite 均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改周/月日期口径、金额/笔数/分类/证据/排序、对比结果 UI、推荐与缓存、查询和补记写入边界、会员、主题、首页、痕迹、宠物、存储同步或 `ARCH-03`；未覆盖用户既有 `StatCardView.swift`、`web-preview/app.js`、提示稿、素材、`tmp/` 与缓存目录，也未回退未提交的 `PET-FIX-01`。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 Swift 分支与 XCTest 尚未实际编译；繁体省略表达、真实金额周期命中和 VoiceOver 标题仍需按 `FLOW-52` 在 Xcode/iPhone 签收，因此不得标记 `VERIFIED`。
- 下一步：在 Xcode Debug/Release 编译并执行对应 XCTest，再用 iPhone 按 `FLOW-52` 核对真实周期金额；发现问题时只调整本项短语消歧，不改对比日期计算和结果层级。`PET-FIX-01` 的 `FLOW-51` 可在同一轮真机矩阵一起签收。

---

## 38. PET-FIX-02：宠物拖动坐标稳定与跟手性修复（2026-07-21）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 真机现象：`PET-FIX-01` 修复点击时位置跳变后，拖动宠物仍持续抖动，视觉位置在手指附近来回摆动且明显不跟手。
- 根因：拖动手势使用 `.local` 坐标，而同一个宠物控件又按该手势的 translation 实时 `.offset`；控件移动后局部坐标原点也跟着移动，下一帧 translation 被反向抵消，形成“位移—归零—再位移”的反馈振荡。首次越过阈值时 `onChanged` 还会写入 `tapSuppressionID`，使活跃手势中途触发视图重建；450ms 后再次清除状态，长拖期间又增加一次无关更新。
- 目标：拖动全程以不随宠物移动的 viewport 坐标采样；拖动过程中只更新轻量手势位移，不写持久状态、不启用隐式动画；结束时一次原子提交吸附位置并抑制误点。横向、纵向和斜向拖动都连续跟手，父级首页滚动不抢手势。
- 允许修改：`PixelPetAnimationView.swift` 的拖动坐标空间、手势内状态时点和无动画提交；对应 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不修改默认右下角、边缘吸附、上下安全区、位置存储 key、气泡布局/文案/生命周期、像素帧、点击说话、0.6 秒长按隐藏、VoiceOver 动作、首页滚动结构/账本/主动作、主题、会员、AI、回放、同步或 `ARCH-03`。
- 验收：慢速与快速拖动均不出现往返振荡，宠物中心与手指位移连续一致；越过 8pt 后由宠物接管且首页不滚动；拖动过程中不反复写 `@State` 或启动延迟任务；松手只提交一次并吸附，1～7pt 抖动仍按点击、不保存位置；气泡显隐、左右侧、顶部/底部边界和长按保持原行为。
- 实现：为宠物外层 viewport 建立固定命名坐标空间，`DragGesture` 从移动中的 `.local` 改为 `.named(Self.dragCoordinateSpaceName)`；实时位移仍只进入 `@GestureState`，并在其 transaction 中禁用动画。删除活跃拖动中的 `onChanged → suppressTapTemporarily()`，450ms 抑制任务只在有效拖动结束后启动；吸附位置在无动画 transaction 中一次提交，再保存和反馈。
- 边界处理：8pt 启动阈值、高优先级手势、左右吸附、上下夹取和持久化格式不变；轻微抖动仍留给点击，长按仍复用原抑制逻辑。没有向 `HomeView` 暴露新的拖动态，也没有让首页滚动、账本或主动作跟随拖动重算。
- 修改文件：`NativeDemoApp/Views/Components/PixelPetAnimationView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增固定 viewport 采样的连续/单调位移 XCTest；静态门禁锁定命名坐标、禁动画 transaction、零 `.local`、活跃拖动零 `onChanged` 普通状态写入及 `FLOW-53`。`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、真实 12MP、AI、生活语义、文案、主题、迁移和 SQLite 均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改默认位置、气泡、像素帧、消息策略、点击/长按含义、VoiceOver、首页结构与数据、主题、会员、AI、回放、同步或 `ARCH-03`；用户既有 `StatCardView.swift`、`web-preview/app.js`、提示稿、素材、`tmp/` 与缓存目录未覆盖。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，命名坐标空间、`highPriorityGesture` 与系统 ScrollView/长按的真实组合仍需真机验证；拖动跟手性属于设备采样结果，当前只能标记 `CODE_DONE`，不能标记 `VERIFIED`。
- 下一步：Xcode 编译后优先在 iPhone 执行 `FLOW-53`，慢拖、快拖、停顿后继续和超过 450ms 长拖各 20 次；若仍有手势竞争，只在宠物局部组合手势层定向修复，不改首页 ScrollView 或回退固定坐标策略。

---

## 39. COPY-FIX-02：周记/月章播放辅助语义层恢复（2026-07-21）

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 用户反馈：`COPY-02 v2` 优化播放文案后，原先生活卡播放中的情绪标签和生活印记（现术语“生活线索”）一起消失；要求恢复其产品价值，但不能把已清理的机器拼接文案重新塞回正文。
- 已确认根因：`00e5ff4` 在收敛周记/月章正文时，从章节 metrics 移除了 `emotionTag`、`lifeMarkLine`、`sceneMemoryLine` 与 `scentWords`；同时所有新章节都携带 `supportLine`，而 `chapterElementChips(for:)` 对存在该 key 的章节无条件返回空数组，导致辅助标签层整体退场。账单 `displayEmotionTag`、`LifeMarkService` 与周记分享 payload 的 `lifeMarkLine/emotionLine` 仍存在，属于播放展示回归而非数据丢失。
- 目标：保留 `COPY-02 v2` 当前自然主文和独立数字依据，在周记/月章播放中恢复最多一个高置信生活线索和最多一个高置信情绪标签；三层去重、跨章节去重，证据不足时不占位。
- 允许修改：`PlaybackService.swift` 的播放辅助语义资格、快照准备和章节归属；`PlaybackSupportServices.swift` 的结构化播放信号与去重；`SummaryPlaybackSheet.swift` 的轻量主题标签展示；对应 XCTest、文案/体验静态门禁、真机矩阵和本文档。
- 冻结边界：不修改 `COPY-02 v2` 主文、章节标题、周记弱数据 3 章/成熟数据 5 章、月章 6 章及顺序/时长；不修改记录筛选、照片、进度、额度/扣次、会员、分享模板、主题体系、播放控制、完成动作、首页动态主动作、AI、痕迹、宠物、存储同步或 `ARCH-03`。
- 可信边界：用户明确文字与结构化天气/场景优先；自动标签只能原样作为辅助标签，不能扩写用户感受。排除默认分类推断、弱暖语气、跨记录固化、敏感记录、脏标题、里程碑/内部词条和与主文或 supportLine 重复的内容。医疗、债务、成人、账号、地址等敏感内容不得暴露标题或情绪原文。
- 性能边界：辅助语义随 `PlaybackService` 构建不可变周/月快照时一次准备；播放索引、动画、滚动、主题、宠物开关和 SwiftUI 重绘只读已有结果，不重新扫描完整账本或调用 `LifeMarkService.aggregates`。
- 工作区保护：保留未提交 `PET-FIX-02`、`StatCardView.swift`、`web-preview/app.js`、提示文档、素材、`tmp/` 与缓存目录；本项不覆盖、不回退、不提交相邻现场。
- 计划验收：覆盖周记 0/1/2/3+、月章、用户明确标签、结构化天气通勤、默认/弱/跨记录/敏感标签、生活线索存在/缺失、主辅包含关系和跨章节重复；补 Xcode/iPhone 多主题、Dynamic Type、VoiceOver、Reduce Motion 与 1,000 条播放滚动矩阵。Windows 完成前只能从 `IN_PROGRESS` 到 `CODE_DONE`，不得冒充真机 `VERIFIED`。
- 实现：新增 `PlaybackAuxiliarySignalPolicy`，仅在 `PlaybackService` 构建周记/月章不可变快照时一次准备辅助语义。生活线索只从 `LifeMarkService` 已验证的场景聚合中选择，排除里程碑、连续内部词条、脏标题和敏感标签；情绪标签只接受记录自身结构化热/冷/雨/雪、可信晚间通勤或真实周末/假期餐饮日期能够证明的标签。自动标签只原样展示，不进入主文，也不扩写用户感受。
- 章节归属与去重：周记“这一周”和月章首个“本月回看”最多携带一个生活线索与一个情绪标签，其他章节不重复。`LifeStorySignalService.playbackAuxiliarySignals` 会同时与 warm/plain 主文、`supportLine` 和已接受标签做归一化包含关系去重；无合格信号时返回空数组且 UI 不占位。旧无 `supportLine` 章节继续兼容原 signal 映射，新 `COPY-02 v2` 章节不恢复分类/备注/词条 chip。
- UI：`SummaryPlaybackSheet` 保留原轻量胶囊、章节强调色、间距和视觉风格；仅恢复“生活线索 · … / 情绪标签 · …”两个明确标签。使用 `ViewThatFits` 在窄屏或大字下从横排切为纵排，并补独立 VoiceOver 标签；没有新增材质、模糊、阴影或布局读取。
- 性能边界：`SummaryPlaybackSheet` 零 `LifeMarkService.aggregates` 与零辅助语义准备调用；播放索引、暂停/继续、动画、滚动、主题和宠物开关只读章节 metrics。完整账本聚合仍由现有后台周/月快照任务承接，不进入 SwiftUI `body`。
- 修改文件：`NativeDemoApp/Services/PlaybackSupportServices.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/playback_copy_lint.py`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增周记同时恢复“咖啡饮品＋热天路上辛苦了”、弱暖/医疗敏感过滤、主文/supportLine 去重、月章仅首章发布四组确定性 XCTest 接线；新增文案 lint、体验静态守卫和 `FLOW-54`。`git diff --check`、`python scripts/playback_copy_lint.py`、`python scripts/life_semantic_regression.py`、`scripts/check_copy_experience.ps1`、`scripts/experience_static_check.ps1` 与最终 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、三张真实 12MP、生活语义、文案、会员、AI、无障碍、主题、迁移和 SQLite 均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改 `COPY-02 v2` 主文、章节标题、周记 3/5 章、月章 6 章及顺序/时长，未修改记录筛选、照片、进度、额度/扣次、会员、分享、主题、播放控制、完成动作、首页动态主动作、AI、痕迹、宠物、存储同步或 `ARCH-03`；未覆盖 `PET-FIX-02` 与用户既有脏工作区。
- 状态：`IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 Swift 策略、`ViewThatFits` 布局与 XCTest 尚未实际编译；真实旧账本的标签命中率、两个长标签的小屏/特大字号、VoiceOver、默认/深色/高对比主题及 1,000 条播放滚动需要按 `FLOW-54` 真机签收，因此不得标记 `VERIFIED`。
- 下一步：在 Xcode 执行 Debug/Release 与全部 XCTest，再用 iPhone 按 `FLOW-54` 核对周记/月章；若出现问题，只调整辅助标签资格、去重或局部布局，不回退 `COPY-02 v2` 主文，不修改章节结构和相邻产品逻辑。

---

## 40. 证据优先的分层叙事系统（2026-07-21）

用户确认将分享图照片模板、重复咖啡主叙事、今日回放、周记/月章活人感、“过去的回声”和可选提前 AI 润色收敛为同一条产品路线。目标不是增加随机文案，而是把“长期代表用户的生活印记”与“本次最值得说的主线”分开：咖啡等高频事实继续作为稳定生活印记，但只有发生新增、回归、明显变化、具体照片或用户明确表达时才重新成为主叙事。

### 固定执行顺序

| 顺序 | ID | 任务 | 状态 | 冻结边界 |
|---:|---|---|---|---|
| 1 | NARRATIVE-CORE | 事实快照、信号角色、重复冷却与本地保底 | `CODE_DONE` | 只建立纯叙事模型和确定性测试；不改 UI、账单、额度、会员、主题或播放结构 |
| 2 | SHARE-03 | 分享图安全模板矩阵与轻总结 | `CODE_DONE` | 保留 FIX-009 照片先准备后渲染；不改照片顺序、引用、权限或原账本 |
| 3 | PLAYBACK-COPY-03 | 今日/周/月播放接入分层叙事 | `CODE_DONE` | 不改今日回放、周记 3/5 章、月章 6 章的数量、顺序、时长、扣次和完成动作 |
| 4 | ECHO-01 | 高置信过去回声 | `CODE_DONE` | 只做重复节奏、再次出现和同期变化；证据不足不显示，不做开放式相似记忆猜测 |
| 5 | NARRATIVE-AI-01 | 提前 AI 润色、证据校验与缓存 | `CODE_DONE` | 可选联网；生成/播放/分享保存时不等待；失败必须回退本地，不上传照片或敏感原文 |

### 全局冻结边界

1. 不修改账单字段、金额、日期、标题、分类、OCR、AI 补记、存储、同步 DTO 与冲突规则。
2. 不修改首页 OCR→草稿→今日回放→周/月痕迹→复盘→继续记录的动态主动作顺序、成熟门槛和主次入口。
3. 不修改免费额度、扣次、会员 Product ID、价格、StoreKit、登录续购或共享额度池结论。
4. 不修改主题 Token、宠物、天气权限、痕迹筛选、页面路由、`web-preview` 或 `ARCH-03`。
5. 保留 `FIX-009` 的不可变分享渲染输入：照片必须先读取、降采样和预解码；导出树不得出现异步缩略图、加载文案或固定延迟。
6. 保留 `COPY-FIX-02` 已恢复的生活线索/情绪辅助标签及可信过滤；新叙事主文不得再次吞并或复述辅助标签。
7. 基础自然文案不是会员特权；未来会员价值可来自更长历史的高置信回声，但本队列不改变权益和额度。

### NARRATIVE-CORE 完成记录

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；未做 Xcode/iPhone 签收，不标记 `VERIFIED`。
- 目标：建立不可变事实快照与纯角色规划器，把候选信号分为主线、辅助观察、生活印记和事实依据；同一稳定信号可以继续作为生活印记，但连续日/周没有信息增量时不得反复成为主线。
- 角色资格：用户明确文字或代表照片优先；新增、消失、显著增减和隔期回归其次；结构化天气/场景与具体日期再次；稳定生活印记只在无更具体事实时承接主线。敏感、弱暖标签、跨记录固化和无证据情绪不得进入主线。
- 冷却边界：冷却按规范化 signal ID 与日/周/月周期记录，不依赖随机数；只降低叙事主线资格，不改变生活印记事实、查询结果、账单或页面数据。
- 性能边界：事实快照由明确输入一次生成；SwiftUI `body`、播放索引、滚动、主题、宠物和模板切换只读结果。相同范围、账本修订和规则版本必须复用；旧请求不得覆盖新修订。
- 工作区保护：保留未提交的 `PET-FIX-02`、`COPY-FIX-02`、`StatCardView.swift`、`web-preview/app.js`、提示稿、素材、`tmp/` 与缓存目录；本队列不覆盖、不回退、不提交相邻现场。
- 计划验收：覆盖 0/1/2/多笔、咖啡连续日/周、咖啡发生明显变化、有/无照片、用户明确文字、敏感记录、同额并列、跨日/周/月、确定性与旧修订拒绝；Windows 完成前只能标记 `CODE_DONE`，Xcode/XCTest/iPhone 签收前不得标记 `VERIFIED`。
- 实际范围：新增 `LifeNarrativePlanningService.swift`，建立日/周/月不可变输入、`lead/support/mark/evidence` 四角色、稳定信号主线冷却、照片/用户文字/真实变化优先、节奏保底和 `empty/factual/contextual/echoEligible` 成熟度。逐条过滤医疗与高风险词条后再分组，避免普通与敏感记录同组时把敏感标题、照片或证据 ID 带入输出；只有敏感记录时使用不展开的私密保底，不谎称无记录。
- 文件：`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoApp.xcodeproj/project.pbxproj`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`。
- 验证证据：新增稳定咖啡保留生活线索但不重复领衔、真实增量可重新领衔、照片/用户原话优先、敏感记录单独及混组零泄漏、成熟度边界 XCTest 接线；静态门禁锁定角色、冷却、净化和工程接线，新增 `FLOW-55`。`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、三张真实 12MP、语义、文案、主题、迁移与 SQLite 全通过，仅保留既有 5 条 soft copy warning。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 Swift 文件与 XCTest 尚未实际编译；`Calendar.current` 的设备时区、真实旧账本语义命中率、1,000 条生成耗时和 `FLOW-55` 仍需统一真机矩阵签收。发现问题只定向修复纯规划器，不改 UI、账本、播放、额度、会员、主题或宠物。
- 下一步：仅执行 `SHARE-03`；复用计划输出和 `FIX-009` 不可变已准备照片，先解决安全模板数量与重复文案，不提前修改播放、回声或 AI。

### SHARE-03 完成记录

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；未做 Xcode/iPhone 签收，不标记 `VERIFIED`。
- 目标：0/1/2～3 张真实可用照片均提供 3 个安全内置模板；模板差异来自信息层级和构图，不用未验证的满屏裁切冒充数量。分享图只呈现一条本次主线、一条必要辅助和最多两个生活线索，不再左右复述同一故事、关键词或系统布局说明。
- 冻结：保留 `FIX-009` 照片后台读取、降采样、预解码、不可变 prepared input 与预览/导出同源；不改变照片顺序、缺图降级、原图引用、相册权限、保存去重、周记播放结构、额度和完成动作。
- 计划验收：0/1/2/3 张、全部缺损降为 0 张、自定义背景、普通/敏感标题、深浅/高对比主题、特大字号、VoiceOver、连续保存和真实 12MP；模板切换不得重扫账本或重新读取照片。
- 实际范围：按“实际成功准备的照片数”提供安全矩阵：0 图为记录摘要/手账留白/杂志版面，1 图为单图记忆/手账留白/记录摘要，2～3 图为周记拼页/杂志版面/记录摘要；自定义背景继续独立显式选择。周分享 payload 一次携带 `LifeNarrativePlan`，稳定咖啡无变化时只保留在线索层。记录摘要左侧改为纯视觉符号、右侧只写一次事实；移除“这张卡片怎么来的/系统如何排版”，底部仅在有不重复的辅助观察或生活线索时显示。新计划存在时不再回退旧最高分类、旧洞察或敏感语义。
- 文件：`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`。
- 验证证据：新增 0/1/2/3 图均三个安全模板、周分享提前携带叙事计划、重复咖啡不领衔、旧敏感字段零回退 XCTest/静态守卫及 `FLOW-56`。`git diff --check`、体验静态检查和 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、三张真实 12MP、语义、文案、主题、迁移与 SQLite 全通过，仅保留既有 5 条 soft copy warning。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 payload 参数、SwiftUI `@ViewBuilder` 分支、三个构图在特大字号/真实照片下的裁切和真实 12MP 模板切换仍需 `FLOW-56` 签收；若有问题只修分享卡局部布局/接线，不回退 `FIX-009`，不改照片、账本、额度、主题或播放结构。
- 下一步：仅执行 `PLAYBACK-COPY-03`，把同一角色计划接入今日/周/月播放正文；不启动回声或 AI，不改章节数量、顺序、时长、扣次与完成动作。

### PLAYBACK-COPY-03 完成记录

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；未做 Xcode/iPhone 签收，不标记 `VERIFIED`。
- 目标：今日回放、周记、月章共用“主线一次、辅助一次、生活线索不抢标题”的文案边界；弱数据只说可验证事实，成熟数据有轻总结但不煽情、不假装理解感受。咖啡等稳定印记继续可见，但没有变化时不得每天/每周重复占据主文。
- 冻结：今日回放已有卡片结构与免费次数、周记弱数据 3 章/成熟 5 章、月章 6 章、章节顺序/时长、照片、进度、暂停、额度、会员、分享和完成动作全部不变；保留 `COPY-FIX-02` 首章最多一个生活线索和一个情绪标签。
- 计划验收：0/1/2/多笔、连续咖啡/真实增减、用户原话、照片、通勤/餐食/爱好、敏感记录、同额并列、日周月边界、宠物开关、Reduce Motion、VoiceOver、1,000 条滚动与播放索引零重算。
- 实际范围：今日 `ContentSnapshot` 一次携带日叙事计划和前一日稳定信号，开场按用户原话/照片/真实新场景优先，稳定咖啡只留在对应单笔卡，不再同时占据开场与收尾；移除今日回放额外 `LifeMarkService` 全量聚合。周记保留概况首章，代表“一笔”按计划优先用户原话/照片/真实变化；月章在月初/后来各自时间段内优先高信息记录；日/周/月收尾统一为平静轻总结。周记 3/5 章、月章 6 章及全部时长、辅助标签和控制未改。
- 文件：`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`qa/page_copy_snapshots.json`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`。
- 验证证据：新增今日快照叙事计划、连续咖啡只在单笔卡/周记反复层出现、开场收尾不重复、章节时长冻结 XCTest 接线；静态门禁锁定今日零二次生活线索聚合、周/月一次计划和 `FLOW-57`。`git diff --check`、体验静态检查、页面文案快照和 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、真实 12MP、语义、文案、主题、迁移与 SQLite 全通过，仅保留既有 5 条 soft copy warning。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，`ContentSnapshot` 新字段、日/周/月 Swift 分支和 XCTest 尚未实际编译；真实生活场景命中、VoiceOver、播放切章与 1,000 条性能仍需 `FLOW-57` 签收。若有问题只修文案选择/快照接线，不改章节结构、时长、额度、会员、分享或完成动作。
- 下一步：仅执行 `ECHO-01`；只允许重复节奏、隔期回归和有可复算基线的变化，证据不足主动不显示，每次最多一条，不提前接 AI。

### ECHO-01 完成记录

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；未做 Xcode/iPhone 签收，不标记 `VERIFIED`。
- 目标：实现“过去的回声”但严格克制：只在同一规范化信号跨足够时间重复、消失后再次出现、或和可比同期发生明显变化时生成；每个输出最多一条，具体日期/次数/差值都必须能从证据 ID 复算。
- 冻结：不做标题向量相似、开放式回忆、情绪猜测或“你一直/你终于”等人格结论；稳定咖啡连续出现本身不构成每周新回声；不改账本、同步、痕迹筛选、播放章节、额度、会员和 UI 结构。
- 计划验收：repeat/return/change 三类、仅一次重复、连续每周咖啡、间隔回归、同期显著增减、阈值边缘、敏感混组、同额并列、最多一条、确定性、旧修订拒绝及 1,000 条预生成性能。
- 实际范围：新增纯 `LifeNarrativeEchoPolicy`，日/周/月统一输出 `repeatRhythm/returnAfterGap/comparableChange` 三类之一或主动不显示；当前期至少 2 笔，return 要求前一期缺席，change 要求绝对差 ≥2 且相对差 ≥50%，周/月比较只取相同已过日序，repeat 只允许周节奏且至少两个历史周命中同一星期。普通咖啡禁用 repeat，但允许真实 change/return。所有结果携带当前/历史 evidence IDs、修订、次数、基线和间隔，排序确定且每次最多一条；今日收尾、周/月末章和分享观察只读已准备结果。
- 文件：`NativeDemoApp/Services/LifeNarrativeEchoService.swift`、`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoApp.xcodeproj/project.pbxproj`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`。
- 验证证据：新增连续咖啡不触发、咖啡真实增量、隔周回归和 echo ID 冷却、三周同星期节奏、月同期已过日序、敏感证据排除、双候选唯一确定及旧修订拒绝 XCTest 接线；静态门禁锁定阈值、同期、冷却、接线和 `FLOW-58`。`git diff --check`、体验静态检查及 `python scripts/validate_release_gate.py --phase windows` 全部通过；100/1,000/5,000 条、真实 12MP、语义、文案、主题、迁移与 SQLite 全通过，仅保留既有 5 条 soft copy warning。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 Swift 文件、日期边界、可比日序和真实 UI 行高尚未编译/签收；1,000 条历史扫描、跨时区/跨年周、VoiceOver 和 `FLOW-58` 需真机完成。若有问题只修 echo 阈值/日期/局部呈现，不扩张到相似记忆或情绪推断。
- 下一步：仅执行 `NARRATIVE-AI-01`；AI 只能润色已经选定并脱敏的事实，必须提前、可选、可校验、可缓存，任何失败立即使用本地文案。

### NARRATIVE-AI-01 完成记录

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；本队列当前无 `IN_PROGRESS`。未做 Xcode/iPhone/真实远端签收，不标记 `VERIFIED`。
- 目标：在真实账本修订完成后，以结构化脱敏 fact pack 可选请求远端轻润色；AI 不选择事实，不看照片，不接收敏感原文，不生成金额/日期/分类之外的新事实。返回必须引用允许的 evidence IDs 并通过长度、禁词、数字和事实覆盖校验。
- 性能与失败边界：预生成与缓存不发生在播放、保存分享图、模板切换或 SwiftUI `body`；相同 scope/修订/规则版本只请求一次，旧请求不能覆盖新修订。无网络、未登录、服务不可用、超时、校验失败或用户未启用时直接保留本地计划，不能出现加载态、白屏或阻断。
- 冻结：不上传照片/图片引用/医疗债务等敏感标题，不改 AI 指令台识别、额度、会员、登录、同步 DTO、播放章节、分享保存、主题和 UI 结构；设置与能力说明必须如实区分“本地整理”和“可选联网润色”。
- 实际范围：新增日/周/月合并 fact pack、返回校验、内存缓存和可取消预生成协调器。账本修订稳定 1.5 秒后才准备一次，连续编辑只保留最后 request ID；远程关闭、无凭据、未登录生产代理、额度不足和 release fixture 零请求。上传仅含 `F1...` 临时编号、受控角色/场景、事实句、证据数量与周期键；用户原句、照片/引用、账本 UUID 和敏感记录不进入请求。返回必须 scope/period 一致、引用 lead、证据为允许子集、数字来自 fact pack、长度合规且无推断/理财/隐私词，旧修订不得写缓存。今日/周/月/分享只同步读取已验证缓存；echo 优先，远端无结果或失败时本地计划完整保留。
- 文件：`NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift`、`NativeDemoApp/Services/AIReportService.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoApp/Views/SettingsView.swift`、`NativeDemoApp/Views/MemberPricingView.swift`、`NativeDemoApp.xcodeproj/project.pbxproj`、`NativeDemoAppTests/StateRegressionTests.swift`、`AI_CAPABILITY_CONTRACT_v1.md`、`scripts/ai_capability_lint.py`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`。
- 验证证据：新增 fact pack 不含用户原句/敏感标题/照片字段/UUID、合法返回、未知证据、新数字、推断词和旧修订 XCTest 接线；静态门禁锁定 1.5 秒修订合并、播放/保存零远程调用、缓存只读、能力说明和 `FLOW-59`。`git diff --check`、`scripts/check_copy_experience.ps1`、体验静态检查及最终 `python scripts/validate_release_gate.py --phase windows` 全部通过；扫描 81 个 Swift 文件，100/1,000/5,000 条、真实 12MP、生活语义、文案、AI 能力、主题、迁移与 SQLite 全通过，仅保留既有 5 条 soft copy warning。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 actor/NSLock 缓存、Swift 并发捕获、URLSession 批次解析、XCTest 和真实代理 `/v1/ai/insight/daily` 的 `narrative_rewrite_batch` 兼容性尚未实际编译/联调；代理不支持该 feature 时会安静回退本地，不影响功能，但只有真实合法返回签收后才可确认远端润色生效。需用登录测试账号按 `FLOW-59` 抓包并验证日/周/月缓存、超时、旧请求、额度一次扣取、VoiceOver 和 1,000 条流畅度。
- 下一步：统一执行 Xcode Debug/Release、全部 XCTest 和 iPhone `FLOW-55～59`；若出现编译或真机问题，只定向修复对应叙事/分享/播放/回声/AI 接线，不修改账本、同步、动态主动作、额度、会员、主题、宠物或 `ARCH-03`。

---

## 41. NARRATIVE-AI-FIX-01：生产润色代理契约闭环（2026-07-22）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE` → `IN_PROGRESS` → `CODE_DONE` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。生产代理契约、语气缓存身份和本轮 Xcode 编译报错定向修复均已完成；仍需用户在 Xcode 重新编译确认，不标记 `VERIFIED`。
- 用户反馈：客户端已实现提前 AI 润色，但生产默认地址仍走 `POST https://api.xuzhangapp.com/v1/ai/insight/daily`；现有 `ai-proxy` 会把所有模型输出统一转换为旧 `{summary, action, encourage}`，导致 `narrative_rewrite_batch` 的 `{rewrites:[...]}` 被破坏，客户端只能静默回退本地。
- 根因：此前只验证了客户端脱敏、证据校验、缓存和失败回退，没有执行真实 backend → ai-proxy → 模型 → 客户端的响应契约测试；同时请求只把 fact packs 序列化进 messages，代理没有结构化依据校验 scope、periodKey 与 evidence IDs。
- 目标：生产默认链路真正支持 `narrative_rewrite_batch`；代理按 feature 分流并严格校验批次响应，旧 daily/monthly 等洞察继续保持原响应格式；任何异常仍返回错误并由客户端无感回退本地。
- 允许修改：`NativeDemoApp/Services/AIReportService.swift` 的脱敏顶层 fact-pack 契约；`ai-proxy/server.js` 的 feature 分流与纯响应校验；必要的代理契约测试、AI 静态门禁、部署说明与本文档。
- 冻结边界：不修改账本/同步 DTO、AI 指令台识别、补记/OCR、首页动态主动作、播放章节/时长/扣次、分享模板、会员/额度、登录/JWT、StoreKit、主题、宠物、痕迹筛选、页面路由、后端既有 daily/monthly 输出或 `ARCH-03`。
- 隐私与事实边界：顶层 fact packs 只能复用已经脱敏的 `F1...`、受控 role/kind/label/statement、evidenceCount、scope 和 periodKey；禁止照片、图片引用、账本 UUID、用户原句和敏感标题。代理只接受 day/week/month、每批最多 3 组、每组最多 6 条、仅引用该组已有 F 编号，客户端继续做第二次事实、数字、禁词和修订校验。
- 工作区保护：保留未提交 `PlaybackSupportServices.swift`、`PixelPetAnimationView.swift`、`StatCardView.swift`、`scripts/playback_copy_lint.py`、`web-preview/app.js`、提示文档、素材、`tmp/` 与缓存目录；不覆盖、不回退、不提交相邻现场。
- 计划验证：新增代理纯函数测试覆盖合法批次、代码围栏、未知 scope/period/evidence、重复 scope、超长字段、空数组、旧 daily 输出不变；运行 Node 测试、AI lint、体验静态检查、完整 Windows 发布门禁和 `git diff --check`。Windows 无线上密钥与真实模型，只能到 `CODE_DONE`；部署后仍需用登录测试账号执行 `FLOW-59` 抓包签收。
- 实现（客户端契约）：生产代理路径只发送顶层 `feature/tone/factPacks`，不再重复上传客户端 messages；每组 fact pack 仍由既有本地策略脱敏，用户原句和照片只转换为受控占位事实。代码中遗留的内部直连兼容路径只发送标准模型字段，不属于用户设置；`AppSettings` 解码继续强制生产地址，正式 App 没有接口或上游 Key 配置入口。
- 实现（代理契约）：新增纯 `aiFeaturePolicy`、`narrativeRewriteContract` 与 `legacyInsightContract`。未知 feature 在模型调用前拒绝，防止动态 feature 绕过限流；`narrative_rewrite_batch` 请求前限制 day/week/month、每批最多 3 组、每组 F1～F6、唯一 lead、字段白名单、受控 role/kind、userText/photo 脱敏标签及零 UUID/链接。代理忽略客户端 prompt，按已验证 facts 在服务端重建 messages 并固定 0.25 温度；返回只接受唯一 scope、相同 periodKey、lead 证据、允许 evidence 子集、已有数字、长度与禁词合规的 `{rewrites}`。旧 daily/monthly/quarterly/yearly 继续走原 `{summary, action, encourage}` 纯函数，历史文本容错保持不变。
- 实现（配置与并发）：联网开关、温和/中性语气、登录、退出、账号注销和 401 会话失效统一清除远程润色缓存并通知首页；HomeViewModel 取消旧外层任务，actor 立即更换 request ID 并再次清缓存，旧响应无法在配置变化后回写。最新配置开启且已登录时才重新等待 1.5 秒预生成；关闭或退出后播放只读本地计划。
- 实现（语气可见性）：今日小记缓存身份新增 `aiTone`、联网开关及生产代理登录可用性；同一账单下切换温和/中性、开关联网或登录/退出后，再打开今日小记会按新身份生成，不再直接复用旧语气/旧来源。设置页明确说明：语气影响今日小记的本地收束，联网开启后还影响今日小记、月度整理和日/周/月轻润色；不影响 AI 指令台、宠物或生活线索。未借此改写周/月本地主文或扩大 UI 范围。
- Xcode 编译修复：将此前遗漏在未提交现场中的 `PlaybackAuxiliarySignalPolicy` 与 `LifeStorySignalService.playbackAuxiliarySignals` 定义及对应 lint 纳入本次提交范围，解决 `PlaybackService`/`SummaryPlaybackSheet` 找不到符号；叙事规划器三处照片能力统一使用真实 `HomeItem.hasMemoryImages`；两个字典 `compactMap` 和远程 rewrites `compactMap` 显式声明 `LifeNarrativeSignal?` / `LifeNarrativeAIRewrite?` 返回类型，解决 `nil` 不兼容与 `ElementOfResult` 无法推断。未改这些策略的产品资格、UI 或数据结果。
- 主动发现并修复：正式用户端没有接口配置，已同步纠正能力契约、API/代理文档和 `FLOW-59`，移除“用户配置直连/缺客户端 Key”的错误口径；代理专用字段不进入内部直连模型请求；代理 prompt 不再由客户端控制；未知 feature 不再创建无限限流桶；代理契约测试不依赖 Express、`.env`、node_modules 或线上密钥。
- 修改文件：`NativeDemoApp/Services/AIReportService.swift`、`NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift`、`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoApp/Services/PlaybackSupportServices.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/ViewModels/SettingsViewModel.swift`、`NativeDemoApp/Views/SettingsView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`ai-proxy/server.js`、`ai-proxy/aiFeaturePolicy.js`、`ai-proxy/legacyInsightContract.js`、`ai-proxy/narrativeRewriteContract.js`、`ai-proxy/narrativeRewriteContract.test.js`、`ai-proxy/package.json`、`ai-proxy/README.md`、`backend/README.md`、`AI_CAPABILITY_CONTRACT_v1.md`、`API_v0.1.md`、`scripts/ai_capability_lint.py`、`scripts/experience_static_check.ps1`、`scripts/playback_copy_lint.py`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：`npm test --silent` 8/8 通过；覆盖合法/围栏 JSON、未知证据、周期不符、新数字、重复 scope、推断词、畸形/未脱敏/UUID fact packs、服务端 prompt、旧 daily 结果和 feature 白名单。静态门禁锁定今日小记缓存包含 tone/remote/credential state、配置与账号变更取消旧请求、设置说明真实范围、零 `hasMemoryPhoto`、真实多图属性及三个显式 `compactMap` 返回类型；`python scripts/playback_copy_lint.py` 确认播放辅助定义/消费闭环。`node --check`、`python scripts/ai_capability_lint.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`git diff --check` 与编译修复后的最终 `python scripts/validate_release_gate.py --phase windows` 全部通过；81 个 Swift 文件、生活语义/文案/AI/主题/迁移/SQLite、100/1,000/5,000 条和真实 12MP 夹具均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改账本/同步 DTO、AI 指令台识别、补记/OCR、首页动态主动作、播放章节/时长/扣次、分享模板、会员/额度、JWT 时长、StoreKit、主题、宠物、痕迹筛选、页面路由、合法 feature 权益或 `ARCH-03`；未覆盖、回退或暂存既有脏工作区。
- 剩余风险：Windows 无 Swift/Xcode；七处已知编译报错已按真实声明定向修正，但必须由 Xcode 重新构建确认没有下一层诊断。新增通知/actor 取消接线与 XCTest 尚未实际编译；当前未连接生产上游，无法证明线上模型严格按 `{rewrites}` 输出。代码还未部署到 `/opt/xuzhang/xuzhangapp/ai-proxy`，线上在重启前仍会返回旧格式并由客户端安全回退本地。
- 下一步：部署本次 `ai-proxy` 文件后先在服务器运行 `npm test --silent`，再 `pm2 restart ai-proxy`；用有效登录 JWT 调生产 backend，抓包确认客户端只发 factPacks、代理返回 `{rewrites}`、旧 daily 仍返回三字段，并执行 `FLOW-59` 的开关/语气/登录/超时/旧响应矩阵。随后统一完成 Xcode Debug/Release、全部 XCTest 与 iPhone 签收；出现问题只修代理契约或叙事 AI 接线，不触碰冻结模块。

---

## 42. DEBUG-CLEANUP-01：生产可达调试能力清理（2026-07-22）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。代码、Node 契约、静态门禁和完整 Windows 发布门禁已通过；缺 Xcode、iPhone 和生产部署签收，不标记 `VERIFIED`。
- 用户要求：全局检查历史遗留调试功能，能安全删除的直接删除；不能因“清理”破坏发布夹具、自动测试、账本数据、会员、同步或当前产品交互。
- 审计原则：按生产可达性而不是关键词处理。删除正式路径仍携带的直连模型/客户端 Key/可变 AI 地址与模型、生产仍注册的 JWT 调试签发路由、已经被发布夹具替代的演示 OCR 入口；保留 `#if DEBUG` 发布夹具、隔离数据目录、性能日志、XCTest、后端仅非生产注册的开发会员路由和 staging 必需能力。二次全局扫描发现会员引导后端默认仍是 90 秒 `debug` 冷却，且生产仍注册策略读写接口；这是本任务直接范围，不作为会员产品改版。代理还残留未鉴权且零调用方的 `/v1/category/recommend` 演示分类接口，其独立关键词会和正式本机语义规则漂移，本任务直接删除。
- 允许修改：`AppSettings` 旧 AI 调试字段及兼容解码、`AIReportService`/调用方生产代理接线、`KeychainService` 旧 AI Key 清理、`ai-proxy` dev-token 路由生产隔离与零调用方分类演示接口、OCR 演示入口、后端会员引导调试策略的生产隔离、对应测试/静态门禁/能力与部署文档、本文档。
- 冻结边界：不修改联网整理开关/语气、生产 endpoint、fact-pack/rewrites 契约、登录 JWT 正常签发与 90 天时长、会员 Product ID/价格/权益、StoreKit、账本/同步 DTO、OCR 正式导入、发布夹具启动参数、首页动态主动作、播放章节、主题、宠物、痕迹、AI 指令台或 `ARCH-03`。会员引导只把生产默认恢复为既有 `prodDailyLimit = 1`、`prodSceneCooldownDays = 7` 并隐藏策略读写调试接口，不改变客户端已经验证的本地引导资格、显式入口和文案。
- 工作区保护：不修改、不暂存 `PixelPetAnimationView.swift`、`StatCardView.swift`、`web-preview/app.js`、提示文档、素材、`tmp/` 与缓存目录。
- 计划验证：iOS 生产代码零 `open.bigmodel.cn`、零 AI API Key 读写、零可变 AI endpoint/model 消费；生产环境不注册 ai-proxy dev-token，非生产仍可用于本地/staging；ai-proxy 零 `/v1/category/recommend` 演示路由；记录页零演示 OCR 按钮且正式 OCR 流程不变；生产会员引导默认正式频控且不能读写调试策略。运行 Node 测试、Swift 静态门禁、文案/迁移/SQLite/发布夹具与完整 Windows 发布门禁；缺 Xcode/iPhone 前只能到 `CODE_DONE`。
- 实现（iOS 生产链路）：删除 `AppSettings` 持久化的 `aiEndpoint/aiModel`、`SettingsViewModel` 对应可变入口和 `KeychainService` 的 AI Key 保存/读取；旧 JSON 多余字段由 Codable 安全忽略并在下次持久化时自然消失。升级启动时只执行 `SecItemDelete` 清除旧 `ai_api_key`，从不读取或上传。`AIReportService` 固定请求 `AppSettings.productionAIEndpoint`，只携带登录 Bearer JWT；客户端不再发送 model、代理口令或直连 prompt，也不再兼容上游 `choices` 响应。今日小记、月度整理和日/周/月轻润色统一以“联网开启 + 有登录令牌 + 既有额度”为远程资格，未登录直接使用本地规则；今日小记缓存身份只保留 `proxy-ready/proxy-signed-out`。
- 实现（演示与服务端）：删除记录页“使用演示 OCR 结果”和 `makeDemoOCRDrafts`，正式相册 OCR、确认、导入与额度路径未改。ai-proxy 的 `/v1/auth/dev-token` 只在非 production 注册，并新增纯环境策略 2 个 Node 用例；代理不再接受请求体 model，服务端环境独占上游模型选择；删除未鉴权、零调用方且规则漂移的 `/v1/category/recommend` 演示接口。backend 的 nudge 策略在 production 固定 `prod`，保持每天最多 1 次、场景关闭 7 天冷却；GET/POST 策略调试路由只在非 production 注册，evaluate/dismiss 正式能力保留。
- 保留项：`#if DEBUG` 的 100/1,000/5,000 条发布夹具、真实 12MP 图片夹具、隔离账本目录、性能日志、断言、XCTest、后端非生产会员档位路由和本地/staging 联调能力均保留；这些能力已有正式包隔离和写云端阻断，不属于用户可达遗留。本轮未删除健康检查、正式观测 API 或微信登录预留，因为它们不是调试旁路，且移除会越过当前任务边界。
- 修改文件：`NativeDemoApp/Models/AppSettings.swift`、`NativeDemoApp/Services/AIReportService.swift`、`NativeDemoApp/Services/KeychainService.swift`、`NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/ViewModels/SettingsViewModel.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoApp/Views/RecordView.swift`、`ai-proxy/server.js`、`ai-proxy/runtimeEnvironmentPolicy.js`、`ai-proxy/runtimeEnvironmentPolicy.test.js`、`ai-proxy/README.md`、`backend/src/nudgePolicy.js`、`backend/src/server.js`、`backend/scripts/verify-nudge-policy.mjs`、`backend/package.json`、`backend/README.md`、`API_v0.1.md`、`scripts/ai_capability_lint.py`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：ai-proxy `node --check` 通过且 `npm test --silent` 10/10；backend `node --check` 通过，90 天 JWT 与生产 nudge 策略脚本均通过。`python scripts/ai_capability_lint.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`git diff --check` 和最终 `python scripts/validate_release_gate.py --phase windows` 全部通过；扫描 81 个 Swift 文件，生活语义、播放文案、AI、无障碍、主题、迁移、SQLite、100/1,000/5,000 条及真实 12MP 夹具均通过，仅保留既有 5 条 soft copy warning。新增 `FLOW-60` 覆盖旧版升级、固定代理、OCR、发布夹具与两套服务生产/非生产路由矩阵。
- 冻结边界复核：未修改账本/同步 DTO、OCR 正式导入、AI 指令台识别、联网开关/语气、远程额度常量、登录 JWT 90 天、会员 Product ID/价格/权益、StoreKit、首页动态主动作、播放/分享结构、主题、宠物、痕迹、页面拆分或 `ARCH-03`；未修改、回退或暂存用户既有 `PixelPetAnimationView.swift`、`StatCardView.swift`、`web-preview/app.js`、素材、提示文档和临时目录。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，删除成员后的 Swift 调用接线、旧 AppSettings 覆盖安装、Keychain 删除时机、正式 OCR 入口和未登录本地回退仍需实际编译/真机签收。服务端代码尚未部署，线上在重启前仍保留旧路由和旧模型选择；当前检查只能证明仓库实现，不能冒充生产已关闭。生产 `NODE_ENV`、两条 404、nudge 正式频控和真实 backend → ai-proxy 请求仍需部署后验证。
- 下一步：先在 macOS 执行 Debug/Release 与全部 XCTest，再用旧版覆盖安装和全新安装完成 `FLOW-60`；随后按既有部署流程分别更新 backend/ai-proxy，确认 production 环境变量后验证 dev-token、分类演示路由、nudge policy 均为 404，并回归正式 daily/monthly/narrative、OCR 和会员引导。若出现问题只修本任务删除/隔离接线，不改冻结产品逻辑。

---

## 43. WEB-RETIRE-01：历史 Web Demo 退役与公开协议同步（2026-07-22）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。仓库退役、协议同步、静态链接与完整 Windows 发布门禁均已完成；正式站点尚未部署并线上签收，不标记 `VERIFIED`。
- 用户授权：`web-preview` 只是项目初期 Demo，已经落后多个版本，明确要求直接删除，并同步更新用户协议与隐私政策。
- 审计结论：正式官网由 `site/` 提供，公开法律页面由 `legal/` 提供；iOS、backend、ai-proxy、CI 和发布门禁均不加载 `web-preview`。目录内 8 个文件约 475 KB；`app.js` 工作区差异经 `--ignore-space-at-eol --ignore-cr-at-eol` 复核为纯换行符噪音，无待保留业务修改。现存 Web Demo 仍直连 localhost、读取本地 proxy/model 配置、调用已删除分类演示接口并展示错误云备份承诺，继续保留会制造产品和合规漂移。
- 允许修改：删除整个 `web-preview/`；更新仍把它作为现行运行方式、测试入口或实现基准的活跃文档；在历史 Prompt/历史记录保留必要的退役说明；更新 `legal/privacy.html`、`legal/terms.html` 的日期、版本、远程 AI 数据类别、处理链路与本地照片/OCR 边界；必要的静态链接/文案门禁与本文档。
- 冻结边界：不修改 `NativeDemoApp` 生产 UI/业务、账本/同步 DTO、AI fact-pack/rewrites 契约、会员/额度/JWT/StoreKit、backend/ai-proxy 运行代码、`site/` 官网视觉和下载入口、App Store 商品信息、主题、宠物、痕迹、复盘或 `ARCH-03`。公开协议只能描述已经实现的数据处理，不新增权限、上传字段、第三方或产品承诺。
- 工作区保护：继续保留并不暂存 `PixelPetAnimationView.swift`、`StatCardView.swift`、提示文档、素材、`tmp/` 与缓存目录；`web-preview/app.js` 的纯换行差异因用户明确授权随目录退役。
- 计划验证：仓库零运行/部署/测试代码依赖 `web-preview`，活跃文档不再把它当现行基准；`site/` 和 `legal/` 仍完整存在且互链有效；隐私政策准确区分本地规则、云端账单字段、远程 AI 汇总快照/脱敏事实包、照片/OCR 原图与第三方处理；用户协议与 App 内能力/额度边界一致。运行 HTML 链接检查、文案/体验静态检查、完整 Windows 发布门禁和 `git diff --check`。
- 实现（Demo 退役）：删除 `web-preview/` 全目录及 8 个历史文件；仓库运行代码、backend、ai-proxy、检查脚本中已无 Web Demo 路径或现行基准引用。保留历史 Prompt、专项回归记录中的背景叙述，但活动任务单、测试入口、架构图、产品设计和项目说明均改为“已退役/不可执行”，当前交互真值统一为 `NativeDemoApp`、Xcode/iPhone 与发布矩阵。`HomeViewModel+Dashboard.swift` 仅移除一处“与 Web 预览对齐”的过时注释，未改任何 Swift 声明或行为。
- 实现（公开协议）：`legal/privacy.html` 更新为 2026-07-22 / v0.7，明确联网整理需登录并由用户主动开启；远程范围包括汇总快照和本机选取的去标识化事实包，事实包仅含周期/范围、受控分类或场景标签、数量、日期区间和临时 F 编号，明确排除照片/照片引用、OCR 原图、账本 UUID、用户原句及医疗/债务敏感标题；链路固定为叙账后端 → AI 代理 → 配置的大模型服务，客户端不保存上游 Key，失败保留本地结果。`legal/terms.html` 更新为 2026-07-22 / v0.6，将增强能力准确表述为今日小记、月度整理和日/周/月轻润色，明确可关闭、非核心，不提供预算、理财或消费控制目标。照片仅本机、OCR 本地处理与云同步字段边界保持不变。
- 活跃文档同步：更新 `IMPLEMENTATION_FOR_CODEX.md`、`TODO.md`、`TEST_CASES_v0.1.md`、`AI_ADVICE_BOUNDARY_AUDIT_v0.1.md`、`PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md`、`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`、`PROJECT_SETUP.md`、`PROJECT_ANALYSIS.md`、`PROJECT_SUMMARY_v0.1.md` 和 `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`；早期任务与用例保留历史身份，但不得再恢复或维护 Web Demo。未修改 `site/` 视觉、下载入口和 App Store 商品信息。
- 修改文件：删除 `web-preview/README.md`、`web-preview/STABILITY_SPRINT_E2E.md`、`web-preview/app.js`、`web-preview/assets/today-empty-illustration.png`、`web-preview/index.html`、`web-preview/styles.css` 及两个零字节历史请求日志；修改 `legal/privacy.html`、`legal/terms.html`、`IMPLEMENTATION_FOR_CODEX.md`、`TODO.md`、`TEST_CASES_v0.1.md`、`AI_ADVICE_BOUNDARY_AUDIT_v0.1.md`、`PRODUCT_STAGE_REVIEW_AND_STORE_COPY_v0.1.md`、`PRODUCT_PLAYBACK_MEMBERSHIP_v0.1.md`、`PROJECT_SETUP.md`、`PROJECT_ANALYSIS.md`、`PROJECT_SUMMARY_v0.1.md`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift` 与本文档。
- 验证证据：本地 HTML 相对链接检查通过，`site/index.html` 到 `/legal/privacy.html`、`/legal/terms.html` 的正式链接保留，`legal` 两页互链有效；`web-preview` 目录不存在，运行代码与检查脚本零 Web Demo 引用。`python scripts/ai_capability_lint.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`git diff --check` 和最终 `python scripts/validate_release_gate.py --phase windows` 全部通过；发布门禁包含 Node 10/10、生活语义、文案、AI、主题、迁移、SQLite、100/1,000/5,000 条和真实 12MP 夹具，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改 iOS UI/产品行为、账本/同步 DTO、AI fact-pack/rewrites 契约、联网资格与额度、会员/JWT/StoreKit、backend/ai-proxy 运行代码、官网视觉/下载、App Store 信息、主题、宠物、痕迹、复盘或 `ARCH-03`。协议只披露已实现链路，不新增采集、权限、第三方或恢复承诺；未覆盖、回退或暂存 `PixelPetAnimationView.swift`、`StatCardView.swift`、提示文档、素材、`tmp/` 与缓存目录。
- 剩余风险：仓库结果尚未发布到正式静态站，线上 `/legal/privacy.html` 与 `/legal/terms.html` 在部署前仍可能显示旧版本；历史 Prompt/回归文档仍保留已退役路径作为时间线证据，若脱离顶部退役说明单独阅读可能产生误解。此次无 Swift 行为修改，不新增 Xcode 编译风险，但本轮未执行 macOS/Xcode 或 iPhone 检查，也未验证 CDN/浏览器缓存刷新。
- 下一步：随下一次官网静态部署只发布更新后的 `legal/` 与仓库删除结果，不改 `site/` 视觉；部署后分别打开正式隐私政策和用户协议，确认日期/版本、互链、HTTPS 与移动端排版，并清理 CDN 缓存。出现问题只修链接、静态发布或协议表述，不恢复 `web-preview`，也不触碰冻结产品逻辑。

---

## 44. DOC-CLEANUP-01：已执行 Prompt 文档退役（2026-07-22）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `VERIFIED`；当前无 `IN_PROGRESS`。文档删除、Git 删除记录、活动引用清理和完整 Windows 发布门禁均已通过；本项不涉及可执行代码，无需 Xcode/真机签收。
- 用户授权：仓库内 Prompt 文档均已执行完成，明确要求直接删除并由 Git 记录删除，不再保留重复执行入口。
- 审计结论：根目录共有 62 份 `PROMPT_*` / `生活语义关键词落地Prompt_v0.1.md` 执行文档，其中 61 份已被 Git 跟踪，`PROMPT_UI-痕迹月度月历热力与复盘微调-iOS.md` 为既有未跟踪文件；这些内容都是一次性任务说明、复制指令或执行索引，不参与 App、backend、ai-proxy、CI、测试和发布运行。`NativeDemoApp/Services/PhotoMemoryPromptPolicy.swift` 虽含 Prompt 字样但属于正式照片提示资格策略，明确排除，绝不删除或修改。
- 允许修改：删除上述 62 份根目录 Prompt 文档；移除活动产品/项目/测试文档中指向 Prompt 或已不存在 `AGENT_PROMPT_*` 的执行链接，并改为已落地代码、产品规范或全局台账入口；更新本文档。历史台账中的文件名与执行证据保留，不重写历史。
- 冻结边界：不修改任何 Swift/资产、Xcode 工程、产品 UI/文案/逻辑、账本/同步、AI、会员、额度、JWT、StoreKit、backend/ai-proxy、官网/协议、发布脚本、产品规范正文或 `ARCH-03`；不删除名称含 Prompt 的生产源码。
- 工作区保护：保留当前未提交的客户端、服务端、协议、官网退役、素材、`tmp/` 与缓存现场；本项只处理 Prompt 文档、其活动引用和本文档，不暂存、不提交、不推送相邻修改。
- 计划验证：根目录零 Prompt 执行文档；Git 对原 61 份跟踪文件全部显示删除，未跟踪 Prompt 不再存在；生产源码 `PhotoMemoryPromptPolicy.swift` 仍在且工程引用不变；活动文档零指向已删除 Prompt 的 Markdown 链接；运行 `git diff --check`、体验/文案静态检查和完整 Windows 发布门禁。文档清理不需要 Xcode/真机，检查通过后可标记 `VERIFIED`。
- 实现：删除根目录全部 62 份一次性 Prompt 执行文档，包括 UI、记账、功能、修复、回归、底栏导航、产品、执行索引和生活语义落地 Prompt；其中 61 份 Git 跟踪文件现在统一显示为 `D`，既有未跟踪 `PROMPT_UI-痕迹月度月历热力与复盘微调-iOS.md` 已从工作区移除。没有删除 `IMPLEMENTATION_FOR_CODEX.md`、产品规范、问题归档或任何生产源码。
- 活动引用收口：`PRODUCT_NORTH_STAR.md`、`PROJECT_SUMMARY_v0.1.md`、`RECORDING_CHAIN_VISION_v0.1.md`、`RECORD_PAGE_DESIGN_v0.1.md`、`CATEGORY_SCENE_COPY_AUDIT_v0.1.md`、`AI_ADVICE_BOUNDARY_AUDIT_v0.1.md`、`TODO.md` 与历史 `IMPLEMENTATION_FOR_CODEX.md` 不再链接已删除 Prompt，改为现行 Swift 服务、产品规范或全局台账；`ISSUES_CHECKLIST_COPY.txt`、`WALKTHROUGH_ISSUES_QUEUE.md` 明确标记历史归档并移除失效 Agent Prompt 入口。本文档内部既有 Prompt 文件名继续作为历史执行证据保留，不构成活动链接或恢复入口。
- 修改文件：删除全部 61 份已跟踪根目录 `PROMPT_*` / `生活语义关键词落地Prompt_v0.1.md`，移除 1 份未跟踪 Prompt；修改 `CATEGORY_SCENE_COPY_AUDIT_v0.1.md`、`AI_ADVICE_BOUNDARY_AUDIT_v0.1.md`、`PRODUCT_NORTH_STAR.md`、`PROJECT_SUMMARY_v0.1.md`、`RECORDING_CHAIN_VISION_v0.1.md`、`RECORD_PAGE_DESIGN_v0.1.md`、`IMPLEMENTATION_FOR_CODEX.md`、`TODO.md`、`ISSUES_CHECKLIST_COPY.txt`、`WALKTHROUGH_ISSUES_QUEUE.md` 与本文档。
- 验证证据：专项检查输出 `PROMPT_CLEANUP_OK trackedDeleted=61 activeRefs=0 photoPolicyProjectRefs=4`；根目录 Prompt 文档计数为 0，非台账活动文档对 `PROMPT_` / `AGENT_PROMPT` 引用为 0，`NativeDemoApp/Services/PhotoMemoryPromptPolicy.swift` 存在且 Xcode 工程仍有 4 处目标引用。`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 和 `python scripts/validate_release_gate.py --phase windows` 全部通过；完整门禁包含 Node 10/10、生活语义、文案、AI、主题、迁移、SQLite、100/1,000/5,000 条及真实 12MP 夹具，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改任何 Swift/资产、Xcode 工程、产品 UI/文案/逻辑、账本/同步、AI、会员、额度、JWT、StoreKit、backend/ai-proxy、官网/协议、发布脚本、产品规则或 `ARCH-03`；`PhotoMemoryPromptPolicy.swift` 及其工程接线完整保留。未覆盖、回退、暂存、提交或推送相邻脏工作区。
- 剩余风险：Prompt 原文不再出现在当前工作树，只能通过 Git 历史查看；这是用户明确授权的预期结果。61 份删除尚未暂存或提交，但已作为工作树删除被 Git 正确识别，可随下一次受控提交进入版本历史。
- 下一步：下一次提交时将这 61 个 `D` 与对应活动引用、本文档一起纳入同一提交；不要单独恢复 Prompt，也不要把生产 `PhotoMemoryPromptPolicy.swift` 误当文档删除。后续任务继续以本文档为唯一顺序与状态来源。

---

## 45. UI-PET-01：全局顶部空间收口、复盘宽度统一与宠物主动说话（2026-07-22）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 策略、静态、文案和完整发布门禁已通过；缺 Xcode/iPhone 视觉、手势和计时签收，不标记 `VERIFIED`。
- 用户反馈：五个 Tab 顶部存在一整块无内容的白色标题区域，占用首屏；复盘页视觉上比痕迹页更窄。首页宠物虽然已有拖动/长按能力和提示文案，但不会主动告知，停留首页也不会自然说话。
- 已确认根因：`ContentView` 仍固定渲染独立 `topBar`，它源于早期 Web Demo 视觉对齐，后续改为不透明背景后形成明显白色块，并非防误触层；系统安全区在移除后仍然生效。痕迹生活模式已放宽至 6pt/560pt，而复盘主内容仍为 12pt/430pt，空态还是 16pt/430pt；标题字号也曾被单独缩小。宠物只有保存和点击触发，无首页驻留调度；交互提示只在首次点击内触发且在气泡真正显示前就写入已读，遇到弹层阻塞会永久丢失。保存消息在不可展示时也会被直接清空。
- 目标：移除五个 Tab 的固定标题块，仅保留系统状态栏/灵动岛安全区和轻量页内上间距；复盘主态与空态使用同一受控宽度，接近痕迹但不让 iPad 文本无限拉宽；宠物首次主动说明“拖动换位置、长按休息”，随后在用户停留首页时低频说一条基于已准备今日账单和缓存天气的自然消息，阻塞后可续接，离开/后台立即取消。
- 允许修改：`ContentView.swift` 的全局固定标题容器；`HomeView.swift` 的顶部间距、宠物展示生命周期与单条待显示队列；`InsightWebView.swift` 的复盘根/空态宽度；`PetCompanionService.swift` 的一次性提示确认、只读缓存的驻留消息与纯调度策略；必要的 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不修改页面内容顺序、Tab 顺序/名称、首页动态主动作状态机、账本/保存/OCR/AI、痕迹数据与筛选、复盘查询/对比语义、会员/额度/StoreKit、同步、主题 Token、宠物事实文案资格、拖拽/吸附/位置存储、长按隐藏含义、像素资源或 `ARCH-03`。顶部只改变视口利用率；宠物只改变触发、取消、优先级和排队，不增加完整账本扫描、渲染期计算或主动网络请求。
- 交互预算：首次操作提示约 5 秒；已提示用户首次驻留消息约 25 秒，后续约 150 秒；每个首页可见会话最多 3 条自动气泡（含提示），保存消息优先于驻留消息。VoiceOver 下延后并降低频率；任何弹层、编辑器、首笔引导、保存后覆盖层、已有气泡、离开首页或场景非 active 时均不打断用户。
- 计划验收：五个 Tab 去除固定白色块且不侵入状态栏/灵动岛；复盘主态/空态左右边距一致并接近痕迹；提示只在真正可见后标记已读，阻塞关闭后重试；首页停留可低频出现上下文消息，离开/后台/关闭宠物立即取消；保存时被阻塞的单条消息恢复后优先显示；拖动、长按、点击、VoiceOver 和首页滚动保持原行为。Windows 仅可完成静态/策略/XCTest 接线，Xcode/iPhone 签收前不得标记 `VERIFIED`。
- 实现（视口）：删除 `ContentView` 的固定 `topBar` 调用与不透明标题块，保留系统 safe area、底栏和 `AppTab.pageTitle` 无障碍提示；首页仅保留 8pt 页内上距。复盘主态与空态统一为 8pt 横向页距、520pt 最大宽度和 8pt 顶距，修复与痕迹相比过窄及主/空态跳宽，同时限制 iPad 长行宽度。未改五个 Tab 内容顺序、名称、底栏或主题色。
- 实现（宠物）：新增纯 `PetCompanionAutomaticSpeechPolicy`，确定性限定首次提示 5 秒、首次驻留 25 秒、后续 150 秒、单会话最多 3 条；VoiceOver 分别延长到 9/45/240 秒。交互提示迁移到 `pet_interaction_hint_seen_v2`，服务只返回候选，必须由首页成功放入可见气泡后才落已读；点击仍可补显示未成功出现的提示。驻留消息只读 `homeViewModel.todayItems` 与 `WeatherCompanionService.cachedSnapshot`，不扫描完整账本、不索权、不刷新网络。
- 生命周期与竞态：首页只维护一个可取消自动任务、一个点击请求和一个待显示保存消息；首笔引导、保存后覆盖层、今日列表、编辑、详情、删除确认、回放、后台、切 Tab 与宠物关闭均取消展示任务，条件恢复后重新按完整延迟调度。被阻塞的保存消息保留一条并优先于驻留气泡和迟到的点击结果；离开首页清理，避免旧消息跨页面反写。现有拖动、吸附、默认右下角、位置持久化和长按隐藏代码未修改。
- 修改文件：`NativeDemoApp/ContentView.swift`、`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoApp/Services/PetCompanionService.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、本文档。
- 验证证据：新增自动提示资格、阻塞/关闭边界、5/25/150 秒节奏、三条上限和 VoiceOver 9/45/240 秒 XCTest 接线；静态门禁锁定固定标题块退场、复盘统一宽度、提示显示后才标记、保存消息优先、驻留零天气刷新与零全账本扫描，并新增 `FLOW-61`。`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过；扫描 81 个 Swift 文件，生活语义、AI、会员、主题、迁移、SQLite、100/1,000/5,000 条和真实 12MP 夹具均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改首页动态主动作、账本/保存/OCR/AI、痕迹数据与筛选、复盘查询/对比结果、会员/额度/StoreKit、同步、主题 Token、宠物事实资格/文案池、拖拽/吸附/存储、像素资源或 `ARCH-03`；未暂存或改动用户未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，`@State` 可取消任务的 Swift 严格并发编译、移除标题后在灵动岛/刘海/横屏的真实 safe area、复盘 520pt 在小屏与特大字号的排版、5/25/150 秒实际前后台计时、弹层恢复、VoiceOver 自动朗读打断程度和保存/点击竞态仍需 `FLOW-61` 真机签收；策略 XCTest 已接线但未在本环境执行，当前只能标记 `CODE_DONE`。
- 下一步：在 Xcode 执行 Debug/Release 与全部 XCTest，再按 `FLOW-61` 完成五 Tab safe area、复盘/痕迹边距、首次提示、弹层重试、驻留节奏、后台/切 Tab 取消、保存优先及拖动/长按回归；若出现问题只修本项视口常量或宠物触发生命周期，不恢复固定标题块、不改拖拽算法和相邻产品逻辑。

---

## 46. NARRATIVE-CORE-02：真实账单、信息增量与叙事价值统一内核（2026-07-22）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE` → `IN_PROGRESS` → `CODE_DONE`；真机发现的“主动记录”伪计数、分类构成伪主线及图文证据分叉已完成定向修复，当前无 `IN_PROGRESS`。缺 Xcode/iPhone `FLOW-62` 签收，不标记 `VERIFIED`。
- 真机回归（2026-07-22）：本周生活、本月生活及对应线索页均显示“有 1 条主动记录”。该数字来自 AI 脱敏事实的固定 `1`，不是周期真实统计；`userEditedTitle` 还可能来自 AI 指令导入、OCR 标题修改或普通编辑，不能代表用户主动写下了一段值得回看的内容。周/月封面照片又由独立锚点选择，与文字主角证据未绑定，截图中本周 7/21 与本月 7/2 的照片被放在同一类单数结论旁，形成事实矛盾。
- 本次修复边界：从生活卡、线索页、周/月播放和分享主线中移除“主动记录数量”这一内部元数据；标题编辑只可帮助保留安全原话，不能凭标记直接获得最高叙事权重。主线必须来自可复算变化、合格具体时刻/照片或确有信息增量的周期事实；没有足够信号时允许只展示事实指标，不强行生成伪总结。生活卡、线索页和播放继续共享主角证据 ID，但分别投影概览、依据与展开文案，不再逐字复用同一 headline/summary；任何主视觉照片必须属于主角证据，否则明确降级为独立“本周/本月留下的画面”，不能冒充主线证据。
- 新增硬验收：用户可见文案不得出现“主动记录/用户主动写下的记录”的数量结论；周/月嵌套范围若都声称唯一证据，证据 ID 必须一致；生活页和线索页主角 ID 一致但主标题/副文不得成对逐字相同；展示为主角照片时其记录 ID 必须包含在 `lead.evidenceItemIDs`；AI fact-pack 不再用选中一条候选冒充周期计数。修复后重新执行完整 Windows 门禁并追加 `FLOW-62` 真机回归，Xcode/iPhone 签收前仍不得标记 `VERIFIED`。
- 用户确认：咖啡等稳定事实继续作为生活印记，但“真实账单、信息增量、叙事价值”必须成为统一算法，生活卡主页、周/月播放和线索页都接入；话费、水电、充值等低现场感记录不能因为当天笔数多就进入情绪叙事，AI 不能替错误主角润色。
- 已确认缺口：`NARRATIVE-CORE` 已让今日/周/月播放和分享区分主线与稳定印记，但只有 `confidence / informationGain / isStable`，没有独立叙事价值与代表性；痕迹生活卡仍以 `LifeMarkService` 固定优先级的第一项为主文，咖啡 priority 18 可压过 4 次、priority 20 的通勤；月度还主动把重复印记置前。线索顶部同样直接读取第一生活印记，下半部分由独立 `LifeInsightService` 固定模板和分数选择，普通附件即可成为“被留下的现场”，密集日还会混入无关次级信号。现有 AI 虽提前生成 day/week/month 润色，但只被首页与 `PlaybackService` 读取，痕迹页未消费。
- 目标：建立同一不可变周期叙事计划，以真实账单为硬证据，分别计算信息增量、叙事价值和长期代表性，再分配 `lead / support / mark / evidence`；生活卡主页给短预告，播放按既有章节展开，线索页展示主角、稳定印记及同一主角的依据。各表面措辞可不同，但不得各自重新选主角。
- 叙事边界：高信息增量＋高叙事价值可做主角；低增量＋高代表性只能做生活印记；高增量＋低叙事价值只能做数据观察；低增量＋低叙事价值只作数字依据。话费、水电、充值、订阅、普通缴费默认不得成为生活情绪主角，只有可验证的明显变化时进入中性数据观察；普通票据不得称为“现场”。照片必须有合格生活角色或具体用户文字，才可进入主叙事。
- 允许修改：`LifeNarrativePlanningService.swift` 的纯信号模型/评分/角色分配；痕迹不可变快照模型与后台构建、生活卡/线索页的只读投影；`PlaybackService.swift` 只允许改为读取升级后的同一计划，不改章节结构；现有叙事 AI fact-pack/store/proxy 契约只允许增加受控 surface 身份与线索预生成；对应 XCTest、静态门禁、设备矩阵和本文档。
- 冻结边界：不修改账单字段、金额、日期、分类/OCR、存储/同步 DTO、AI 指令台、首页动态主动作、痕迹筛选/日期口径、周记弱数据 3 章/成熟数据 5 章、月章 6 章及顺序/时长、播放额度/会员/StoreKit、分享模板/照片准备、主题/UI 风格、宠物、页面拆分或 `ARCH-03`。不得把医疗、债务、地址、账号等敏感内容升级为叙事；不得让 AI 选择事实、增加数字、人物、地点、原因、情绪或建议。
- 性能边界：同一账本修订与周期只在既有后台快照阶段计算一次；生活卡绘制、线索滚动、播放索引、模板切换和主题变化只读快照。远程润色随账本稳定后提前生成，进入页面与点播放不发请求、不等待、不扫描完整账本；旧修订不得覆盖新结果，失败无感回退本地文案。
- 工作区保护：保留未提交 `UI-PET-01` 八个跟踪文件及未跟踪素材、`tmp/`、缓存目录；本项只叠加明确允许文件，不覆盖、不回退、不暂存、不提交前项现场。
- 计划验收：覆盖稳定咖啡、咖啡增减/回归、通勤与咖啡并列、普通话费/话费明显变化、生活照片/票据、密集日混入低价值账单、用户原话、弱数据、敏感混组、同期边界、AI 开关/未登录/超时/旧修订和 1,000/5,000 条性能；生活卡主页、播放、线索页主角身份一致且不逐字重复。Windows 只能完成策略、静态与发布门禁，Xcode/iPhone 签收前不得标记 `VERIFIED`。
- 实现（统一角色）：`LifeNarrativeSignal` 新增独立 `narrativeValue`、`representativeness` 与 `isAdministrative`，在同一周期计划中按信息增量、叙事价值、长期代表性和置信度分配 `lead / support / mark / evidence`。稳定咖啡等重复事实只保留为生活印记，只有真实增减或隔期回归才可重新竞争主线；用户原话仍优先，敏感事实仍在分组前剔除。
- 实现（固定账单与照片）：话费、水电、充值、订阅、停车费等从生活场景组和稳定印记中隔离，普通情况只保留为数字依据，出现可复算变化时也只生成中性观察。照片资格改为读取真实记忆角色：票据、无明确角色的旧照片和敏感照片不能领衔，`moment / place / object / careRecord` 等合格生活照片或带安全用户文字的照片才可进入主叙事。
- 实现（跨页面一致性）：周/月生活卡和线索快照携带同一不可变 `LifeNarrativePlan`、`leadSignalID` 与已验证缓存润色；生活线索列表过滤固定账单，并优先展示计划选中的代表性印记；深层线索改为同一主角的证据解释，避免复制顶部主文。周/月播放继续通过升级后的同一计划选代表记录，不自行另选主角。
- 实现（AI 与性能）：痕迹周/月表面消费账本稳定后提前生成的 AI 润色，AI 只改表达，不改事实、证据和主角；页面进入、滚动、切章、主题及模板切换均不触发请求或完整账本扫描。仅当同周期同修订的润色内容真实变化时使痕迹快照失效，通知在释放缓存锁后发送；相同润色不重复刷新，旧修订不能覆盖新结果，失败继续使用本地文案。
- 修改文件：`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归：新增固定账单中性观察、合格/不合格照片、周生活卡/线索/播放主角 ID 一致、生活线索过滤固定账单、痕迹只读缓存润色，以及既有周 3/5 章、月 6 章冻结边界 XCTest 接线；设备矩阵新增 `FLOW-62`，覆盖稳定咖啡、真实变化/回归、行政账单、照片角色、用户原话、敏感混组、AI 开关/失败/旧修订、主题/无障碍和 100/1,000/5,000 条性能。
- Windows 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 和 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`。完整门禁包含生活语义、AI 契约 Node 10/10、主题、迁移、SQLite、100/1,000/5,000 条夹具与三张真实 12MP 图片；文案扫描 81 个 Swift 文件，仅保留基线既有 5 条 soft warning，本轮新增警告为 0。
- 冻结边界复核：未修改账单字段、金额/日期、分类/OCR、存储/同步 DTO、AI 指令台、首页动态主动作、痕迹筛选/日期口径、播放章节数量/顺序/时长、额度/会员/StoreKit、分享模板/照片准备、主题/UI 风格、宠物、页面拆分或 `ARCH-03`；未覆盖、回退、暂存或提交 `UI-PET-01` 与未跟踪素材、`tmp/`、缓存目录。
- 剩余风险：Windows 没有 Swift/Xcode，新增模型字段、后台快照发布与通知的严格并发编译，以及痕迹/播放真实布局和 5,000 条真机 hitch/内存仍未完成运行验证；策略 XCTest 已接线但未在本环境执行。真实服务端润色还需在有效账号、联网/离线和旧修订交错条件下确认无错误反写。
- 下一步：在 macOS/Xcode 执行 Debug、Release 与全部 XCTest，再按 `FLOW-62` 逐项签收生活卡、线索页、周/月播放和分享的主角一致性、行政账单/照片/敏感边界、AI 成功/失败/旧修订、主题/无障碍及 5,000 条滚动内存。发现问题只修本项计划评分、快照投影、缓存失效或受控措辞，不改章节/UI/额度/会员/存储，也不启动 `ARCH-03`；通过后再将本项标为 `VERIFIED`。

### 2026-07-22 真机回归定向修复收口

- 根因收口：删除“选中一条候选＝周期有 1 条主动记录”的远端事实；普通改标题不再自动获得叙事权重，OCR 来源和 AI 导入使用的分类锁定元数据均不能冒充用户原话。只有来源可信、未被导入锁定且包含真实信息增量的安全表达才可作为本机主线；分类构成信号明确禁止领衔。没有合格主线时只展示“本周记录 / 本月记录”和真实笔数、记录日，不强行输出“吃饭和通勤构成日常”等图表复述。
- 图文与跨表面边界：痕迹生活卡、线索页、周/月播放继续共享同一计划与证据 ID；生活卡讲概览，线索页改用问题与直接依据，播放负责展开。痕迹与播放的首张照片优先绑定主线证据中的有图记录；不属于主线的照片明确标为独立“本周画面 / 本月画面”，不再冒充文字结论证据。
- AI 与缓存边界：规则版本升级为 v3，旧“主动记录”润色缓存无法命中；客户端不再把用户原文信号加入远端 fact pack，代理也拒绝 `userText` 类型，旧客户端请求会安全失败并回退本地。代理提示同步禁止把标题来源、分类构成或内部元数据写成生活主线。
- 修改文件：`LifeNarrativePlanningService.swift`、`LifeNarrativeAIRewriteService.swift`、`PlaybackService.swift`、`StatsTraceModels.swift`、`StatsTraceSnapshotStore.swift`、`StatsWebView.swift`、`StateRegressionTests.swift`、`ai-proxy/narrativeRewriteContract.js`、`ai-proxy/narrativeRewriteContract.test.js`、`ai_capability_lint.py`、`experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 回归证据：新增普通改标题、OCR/AI 导入标题、具体用户表达、周/月嵌套证据、照片主线/首图一致、线索/生活卡不逐字复制和用户原文不外发测试接线。`node --test ai-proxy/narrativeRewriteContract.test.js` 8/8、`python scripts/ai_capability_lint.py`、`scripts/experience_static_check.ps1`、`scripts/check_copy_experience.ps1`、`git diff --check` 与最终 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；81 个 Swift 文件、100/1,000/5,000 条、三张真实 12MP、生活语义、文案、AI、主题、迁移和 SQLite 全通过，仅保留基线既有 5 条 soft warning。
- 冻结边界复核：未修改账单字段、分类/OCR/AI 指令保存、存储/同步 DTO、首页动态主动作、痕迹筛选/日期口径、周记 3/5 章、月章 6 章及顺序/时长、额度/会员/StoreKit、分享模板/照片准备、主题/UI 风格、宠物或 `ARCH-03`；未暂存、提交、推送或纳入未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险与下一步：Windows 无 Swift/Xcode/iPhone，新增 Swift 门槛、默认参数接线、SwiftUI 照片标题、XCTest 和严格并发尚未真实编译；必须先在 Xcode 执行 Debug/Release 与全部 XCTest，再按 `FLOW-62` 用真机核对本周/本月生活卡、线索、播放、分享的文案与主视觉。通过前保持 `CODE_DONE`；不得启动 `ARCH-03`，签收问题只能定向修本项。

---

## 47. NARRATIVE-VALUE-03：证据关系、主动弃权与 AI 表达层（2026-07-22）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码、契约、静态与完整发布门禁已通过，当前无 `IN_PROGRESS`。缺 Xcode/iPhone `FLOW-63` 签收，不标记 `VERIFIED`。用户确认生活卡、痕迹、复盘和“过去的回声”是核心付费价值承载，不能用分类构成或空泛总结填满版面。
- 用户确认的目标效果：只有证据成立时才允许表达“这周晚间通勤重新出现，上一次连续晚归还是三周前”或“咖啡仍是生活印记，但这周第一次连续出现在两次晚间通勤之后”。这些句子是关系发现的表达目标，不得写成固定模板；“重新、上一次、连续、第一次、三周前”都必须由本机事实引擎先认证。
- 三道硬门槛：任何主叙事必须同时满足：①不是看分类图即可得到的文字复述；②可回到具体日期、记录、照片或可复算周期证据；③能解释为什么本次值得出现。任一不满足则主动弃权，只显示笔数、记录日、照片数等事实指标和独立生活印记，不生成主叙事。
- 目标：在现有不可变周期计划中增加受控关系发现与价值资格，至少覆盖隔期回归、节奏改变、可比同期变化和有历史基线的新组合；生活卡给一句高价值发现，痕迹展示对应证据，播放展开同一关系，复盘继续查证。AI 只能润色已认证关系或事实指标，不能选择主角、创造关系或把事实指标升级成故事。
- 允许修改：`LifeNarrativePlanningService.swift` 的关系/价值模型与弃权策略；`LifeNarrativeEchoService.swift` 的证据关系输出；`LifeNarrativeAIRewriteService.swift` 与 `ai-proxy` 的受控关系 fact-pack/校验；痕迹、播放和分享对同一计划的只读投影；对应 XCTest、静态门禁、设备矩阵和本文档。
- 冻结边界：不修改账单字段、金额/日期/标题/分类、OCR/AI 指令保存、存储/同步 DTO、首页动态主动作、痕迹筛选/日期口径、复盘查询/对比事实、周记 3/5 章、月章 6 章及顺序/时长、额度/会员/Product ID/StoreKit、分享照片准备、主题/UI 风格、宠物、页面拆分或 `ARCH-03`。不把自然基础文案改成会员专属，不在本任务调整付费墙。
- 可信边界：`首次` 需要检查受控历史窗口内确无同类关系；`重新出现` 需要真实缺席期；`连续` 需要明确连续日期/周期规则；相隔时间必须可复算；组合关系必须在当前期至少有两个独立证据且历史基线足够。证据不足时禁止近似表达，不允许 AI 补原因、感受、人物、地点、消费评价或生活方式判断。
- 性能边界：关系发现只在已有后台周期快照阶段按账本修订计算一次；SwiftUI 绘制、滚动、切章、主题、模板切换和播放索引只读结果。远程 AI 仍提前、可取消、可缓存；页面进入、播放和分享保存不发请求、不等待。旧修订不得覆盖新结果。
- 计划验收：覆盖晚间通勤隔期回归、连续晚归、咖啡与晚间通勤新组合、组合历史已存在、稳定咖啡无变化、分类构成、弱数据、行政账单、照片/用户原话、敏感混组、历史不足、相同日序边界、AI 合法/编造首次/新数字/未知证据/旧修订，以及 100/1,000/5,000 条性能。Windows 完成前只能到 `CODE_DONE`；Xcode/iPhone `FLOW-63` 签收前不得标记 `VERIFIED`。
- 实现（受控关系）：`LifeNarrativeEchoPolicy` 新增 `contextReturn` 与 `newContextPair`。首期晚间通勤只接受交通记录中 21:00～04:59 的强通勤语义，当前周与历史周都至少两个独立“夜间日期”、上一周完全缺席且 2～12 周内存在合格历史，才允许说“重新出现/上一次/几周前”；停车费、普通打车和旅行不进入该上下文。咖啡＋晚间通勤新组合要求当前至少两个独立日期、此前 1～8 周内至少四个有记录周且任一周都未出现同类组合；只有每天顺序一致才说“之后”，顺序不一致只说“一起出现”，并始终保留“近 N 个有记录周”的首次边界。凌晨 0～4 点按前一夜归组，避免跨零点把同一晚误判为两个证据日。
- 实现（主动弃权）：固定账单与敏感记录在关系分组前移除；泛化回归不再让稳定咖啡领衔，并要求当前/历史各至少两个日期。周期计划新增 `hasNarrativeLead` 和可选关系输入；经认证关系可成为 lead，稳定咖啡继续留在 `mark`。分类构成、普通结构化场景和记录节奏不再作为兜底 lead；没有合格关系、具体原话、合格照片或可比变化时，`leadSignalID=nil`，只显示“本周/本月记录”、笔数和记录日等事实，不远程生成主叙事。周/月变化继续按相同已过日序比较，避免未结束周期拿完整上一周期制造变化。
- 实现（同一计划投影）：痕迹周/月后台快照、周/月播放与分享先准备同一个 echo，再注入不可变 `LifeNarrativePlan`。生活卡显示简短关系标题与完整事实；线索页不复制主文，分别列当前日期证据和历史日期/有记录周基线；播放末章优先使用已验证润色，失败回退同一关系本地表达；分享用短标题承接关系、摘要承接证据，不改变任何模板、照片准备或章节结构。复盘仍走既有只读查账/对比入口，没有改变查询事实。
- 实现（AI 事实边界）：叙事规则版本升至 v4，fact pack 新增 `factual/relationship` mode。关系模式只发送一个已认证 lead 事实，不附带分类构成或节奏让模型二次选主角；代理只接受五种受控关系 kind，并拒绝把 rhythm、structured scene 或 stable mark 升成 factual lead。客户端与代理双重校验“首次/重新出现/连续/上一次/几周前/之后/一起出现”，相关词只能来自引用事实；受控首次必须保留“近 N 个有记录周”限定，未知 evidence、新数字、推断词和旧修订继续拒绝。证据不足时 fact pack 为空，零远程请求、零额度消耗。
- 性能与缓存复核：关系发现仍只发生在账本稳定后的 AI 预生成或既有后台周期/播放快照构建；SwiftUI body、滚动、切章、主题、模板切换与保存分享只读结果，不增加渲染期扫描或页面进入请求。相同修订和输入关系 ID、证据 ID 与排序确定；新增 100/1,000/5,000 条关系扫描确定性 XCTest 接线。旧 v3 润色因 key 版本变化不能覆盖新计划。
- 修改文件：`NativeDemoApp/Services/LifeNarrativeEchoService.swift`、`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`ai-proxy/narrativeRewriteContract.js`、`ai-proxy/narrativeRewriteContract.test.js`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归：新增晚间通勤双侧两日门槛、当前/历史单日弃权、停车/旅行排除、新组合两日＋四个活跃周、历史已存在、混合顺序、稳定咖啡只留 mark、弱分类零 lead/零远程请求、生活卡/线索/分享同 relation ID、AI 合法关系与无边界首次/编造回归拒绝，以及三档发布规模确定性测试接线；设备矩阵新增 `FLOW-63`，并将 `FLOW-58` 明确为基础三类回声，避免与受控上下文关系冲突。
- Windows 验证证据：`node --test ai-proxy/narrativeRewriteContract.test.js` 9/9、`python scripts/ai_capability_lint.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`git diff --check` 与最终 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`。完整门禁包含生活语义、AI 契约/生产路由、主题、迁移、SQLite、100/1,000/5,000 条和三张真实 12MP 夹具；文案扫描 81 个 Swift 文件，仅保留基线既有 5 条 soft warning，本轮新增为 0。
- 冻结边界复核：未修改账单字段、金额/日期/标题/分类、OCR/AI 指令保存、存储/同步 DTO、首页动态主动作、痕迹筛选/日期口径、复盘查询/对比事实、周记 3/5 章、月章 6 章及顺序/时长、额度/会员/Product ID/StoreKit、分享照片准备/模板、主题/UI 风格、宠物或 `ARCH-03`；未暂存、提交、推送或纳入未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险与下一步：Windows 无 Swift/Xcode/iPhone，新增关系模型字段、默认参数、Swift 闭包推断、XCTest 与严格并发尚未真实编译；关系长短文在小屏/大字、周记末章和分享三模板的换行，以及 5,000 条真机后台扫描、滚动 hitch/内存、真实账号合法/越界 AI 返回仍需签收。下一步只在 macOS 执行 Debug/Release 与全部 XCTest，再按 `FLOW-63` 真机核对关系、弃权、同 ID、AI 成功/失败/旧修订、主题/无障碍和三档性能；发现问题只定向修本任务，不启动 `ARCH-03` 或相邻产品改造。

---

## 48. PERF-FIX-03：首页生活印记非阻塞快照与保存后滚动（2026-07-22）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 静态、策略、发布规模夹具与完整发布门禁已通过；缺 Xcode/iPhone `FLOW-64` 签收，不标记 `VERIFIED`。
- 用户真机反馈：记完一笔返回首页后暂时无法上下滚动；生活印记加载完成后才恢复。该现象说明既有 `PERF-09`、`UI-FIX-04` 与 `PERF-15` 虽已把部分首页数据改为变化驱动快照，当前路径仍存在保存后主线程同步生活印记聚合或逐条完整历史扫描的缺口。
- 已确认方向：首页 `ScrollView` 的显式禁用只与今日横滑手势状态有关，生活印记加载没有主动锁滚动。实际风险来自账本修订触发 SwiftUI 重绘后，首页展示属性仍可能调用 `LifeMarkService.aggregates`、完整账本签名或重复记录统计；生活印记后台任务又对今日各记录分别聚合，主线程事件处理与后台 CPU 同时受压，形成“印记完成后才能滚动”的表象。
- 目标：账本真正变化时只构建一次首页生活印记历史上下文和不可变展示快照；SwiftUI `body`、计算属性、滚动、宠物帧、气泡、提示层与普通页面状态只读取已发布结果。保存后账单立即稳定出现、首页始终可滚动，生活印记完成后只局部补齐且不造成整页跳动。
- 允许修改：`HomeViewModel+Dashboard.swift` 的首页生活印记准备、单次批处理与修订发布；`HomeViewModel.swift` 直接必要的快照状态/失效接线；`HomeView.swift` 中残留的同步聚合或完整账本展示读取；`LifeMarkService.swift` 只允许增加复用同一历史索引/已知修订的批处理入口，不改变聚合结论；保存返回首页的直接链路 `RecordView.swift` 与 `FreeScenePackService.swift` 只允许把场景奖励/首次引导判断移出主线程，不改资格或提示；对应 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不修改生活印记文案、资格、排序、会员边界、叙事价值/回声算法、账单字段/排序/保存、首页 UI/卡片/主题/动态主动作/提示预算、宠物、通勤、今日回放、痕迹、复盘、AI 指令、额度/会员/StoreKit、存储同步、页面路由或 `ARCH-03`。相同账本、日期、会员与天气输入必须得到相同展示结论。
- 稳定发布边界：同日同会员时保留上一份已有记录的生活印记；新记录先以无生活印记的稳定行进入，后台完成后只补齐对应字段。跨日或会员身份变化立即丢弃不安全旧文本。快速连续保存、编辑、删除只允许最新账本修订发布，旧任务不得反写；删除记录不得保留旧标签。
- 性能边界：SwiftUI `body` 和首页计算属性零 `LifeMarkService.aggregates`、零完整账本签名、零按可见行重复聚合；一次修订最多建立一次历史上下文并批量派生今日总体与各行结果。缓存命中不得先遍历完整账本生成内容签名，优先使用已有账本修订号。不得使用加载遮罩、固定延迟或禁用滚动掩盖问题。
- 工作区保护：开始前分支为 `feature/xuzhangapp-staging`；工作树仅有用户未跟踪的 `brand-assets/`、`tmp/` 与 `scripts/__pycache__/` 现场。本项不覆盖、不删除、不暂存这些内容。
- 计划验收：保存后立即连续拖动 20 次仍可滚动；0/1/多笔、同日连续保存/编辑/删除、跨日、会员切换、生活印记有/无结果、100/1,000/5,000 条均保持展示结果与改前一致；旧标签稳定承接且不串到新记录；主线程无渲染期完整账本聚合；完整 Windows 门禁通过。Xcode Debug/Release、XCTest、iPhone Instruments 与真实 5,000 条签收前只能标记 `CODE_DONE`，不得标记 `VERIFIED`。
- 实现（单次历史上下文）：`LifeMarkService` 新增不可变 `PreparedAggregationContext`，一次过滤有效历史、匹配相关定义并建立“记录 → 定义”和“定义 → 历史记录”索引；同一首页修订内逐行生活印记、今日主线、周主题和主动作副文案共用该上下文，不再为每行重新生成完整账本签名或扫描历史。保留旧入口并增加等价性测试，生活印记资格、优先级、会员过滤和文案未改。
- 实现（稳定发布）：首页生活印记快照同时携带周主题、主动作副文案和周最高分类；对应 SwiftUI getter 只读取已发布值。账本变化时同日同会员只承接仍存在记录的旧行标签，新记录先稳定显示为无标签，后台完成后局部补齐；跨日或会员变化清空，快速连续修订通过 request ID 与 key 拒绝旧结果反写。首页“已记录天数”并入一次生成的 `HomeJourneyLedgerFacts`，移除 `body` 侧完整账本日期集合。
- 实现（保存后遗漏链路）：真机返回首页后 0.28 秒还会触发免费场景包奖励和首次生活线索判断；旧实现位于主队列，首次判断连续两次调用带完整签名的聚合。现改为保存成功时冻结最小输入，延迟后在 utility 子任务准备决定，主线程只接收最终 prompt；奖励决定使用锁串行，避免快速连续保存重复发奖。首次判断改用无签名 prepared context，结论由新旧实现等价测试锁定；奖励/冷启动资格、UserDefaults key、提示文案和 0.28 秒展示节奏不变。
- 修改文件：`NativeDemoApp/Services/LifeMarkService.swift`、`NativeDemoApp/Services/FreeScenePackService.swift`、`NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Views/HomeView.swift`、`NativeDemoApp/Views/RecordView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归：新增 prepared context 与旧逐次聚合在整体/单条输入下的等价性测试、首次生活线索新旧资格等价测试、全部记录日事实测试，以及首页渲染零同步聚合、零逐行完整签名、保存后提示不在主队列聚合的静态防回流门禁；真机矩阵新增 `FLOW-64`，覆盖连续保存/编辑/删除、跨日、会员切换、旧任务反写、100/1,000/5,000 条和立即连续拖动。
- Windows 验证证据：`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`git diff --check` 与最终 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`。完整门禁包含生活语义、AI 契约、主题、迁移、SQLite、100/1,000/5,000 条与三张真实 12MP 夹具；扫描 81 个 Swift 文件，仅保留基线既有 5 条 soft copy warning，本轮新增为 0。
- 冻结边界复核：未修改生活印记结论、文案、资格、排序、会员边界、账单保存字段/顺序、首页 UI/动态主动作状态机、宠物、通勤、回放、痕迹、复盘、AI 指令、额度/会员/StoreKit、同步、主题或 `ARCH-03`；未覆盖、删除、暂存、提交或推送未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，`@unchecked Sendable` 输入、Swift 任务组闭包、XCTest 和 UserDefaults 后台读写仍需真实编译；虽然 `UserDefaults` 支持并发访问且奖励决定已串行，仍须用快速连续保存确认 prompt 不迟到、不重复。5,000 条真机下要用 Main Thread Hitches 确认保存返回后无 >100ms 停顿，并核对旧标签承接没有整页闪动。
- 下一步：先在 macOS 执行 Debug/Release 与全部 XCTest，再按 `FLOW-64` 真机签收保存后立即滚动、连续变更、跨日/会员和 5,000 条；发现问题只修本项快照、任务取消/发布或提示后台决定，不改产品结论。全局只读审计发现的其他同类路径已单列 `PERF-AUDIT-04`，不得混回本项或与 `ARCH-03` 合并。

---

## 49. PERF-AUDIT-04：全局变化驱动快照收尾（2026-07-22）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`（2026-08-28）；四条真实可达路径的代码、静态、语义与 Windows 发布门禁已完成，当前无 `IN_PROGRESS`。Windows 无 Swift/Xcode/iPhone，缺 Debug/Release、全部 XCTest 与 `FLOW-96` 真机/Instruments 签收，不标记 `VERIFIED`。
- 审计目标：检查首页之外是否仍把“已算好的周期结果”在 SwiftUI 绘制、弹层重绘或明确交互时重新扫完整账本；只处理真实可达路径，不因看到旧函数就重写产品逻辑。
- P0 发现（播放分享弹层）：`StatsWebView.summaryPlaybackSheet` 在每次 SwiftUI 重绘时调用 `weeklySharePayload(for:)`，它同步执行 `PlaybackService.buildWeeklyShareCardPayload`；该构建会重新筛本周/上周、生成回声与叙事计划、构建生活印记，弹层内进度、播放索引或其他状态变化都可能重复触发。应让周记后台生成阶段一并发布同修订的 share payload，弹层只读快照；不得改变播放章节、分享模板、照片或文案。
- P1 发现（复盘保存分享）：`InsightWebView.generateAndShareWeeklyCard` 虽包在 `Task { @MainActor in }`，但 `buildWeeklyShareCardPayload` 仍同步跑在主 actor；点击保存时可能先冻结 UI，再开始图片快照。应先在后台取得同修订 payload，再回主线程只做 SwiftUI/UIKit 快照与相册保存；旧修订不得覆盖新账本。
- P1 发现（痕迹继续提问）：`StatsWebView.focusNextTraceInsightQuestion` 读取 `traceLifeInsight`，会在点击时重新调用 `LifeInsightService.buildTraceInsight` 扫周期和历史；当前 `preparedClueSnapshot` 已含同一批问题，应该直接循环已发布 questions，保持问题顺序和额度/解锁逻辑不变。
- P2 发现（复盘修订键）：`InsightWebView.insightSourceRevision` 在出现和每次账本变化时再次遍历全部记录生成 hash；不是滚动期热点，但已有 `homeDashboardRevision` 可作为单一变化键。`allowsReviewTasks` 也可读取已准备账本事实。迁移前必须验证 revision 对新增、编辑、删除、导入、恢复和同步全部递增。
- 已正确的路径：会员终身档案、痕迹周/月/线索快照、周/月播放主体、记账输入生活印记预览和 AI 指令台页面快照均已在后台任务构建并按修订发布；AI 指令查询缓存签名发生在用户明确执行查询时，不属于滚动重绘热点。`StatsWebView` 的旧 `traceLifeMarks`/同步 build helper、`InsightWebView` 的旧 `weeklyKeywordBubbles`/`weeklyInsightSection` 当前没有渲染根引用，属于不可达遗留代码，不能据此宣称线上仍计算，也不得在性能修复中顺手大拆文件。
- 冻结边界：只移动计算契机、复用不可变结果和删除经编译证明不可达的旧实现；不修改生活印记/回声/叙事算法、文案、问题顺序、痕迹/复盘 UI、播放章节、分享模板、照片准备、AI/额度/会员/StoreKit、账本/同步或 `ARCH-03`。本项需单独补 XCTest、静态门禁和真机矩阵后才能执行。
- 实施（周记与分享共用底稿）：`PeriodExperienceFacts` 在既有周期后台准备阶段一并保留周分享需要的生活印记；`SummaryPlaybackPreparationComputation` 使用匹配的周期事实同时构建播放与同 revision 的 `WeeklyShareCardSnapshot`，缓存未命中时显式继承当前会员口径。`SummaryPlaybackSheet` 的 SwiftUI 重绘只读取 `SummaryPlaybackPresentation`，不再同步筛账本、重建回声、叙事计划或生活印记；账本 revision 变化会取消未完成准备并拒绝旧结果发布，播放章节、文案、照片与模板未改。
- 实施（复盘保存与线索交互）：复盘保存先在后台准备不可变周分享 payload 与 `CoverShareSession`，回主线程后只执行 `CoverExportCoordinator.renderImage` 和相册保存；发布前再次比较统一账本 revision，旧结果不导出。痕迹“展开这条线索”只按 `preparedClueSnapshot.insight.questionChips` 确定性轮换问题，原可重新扫描周期与完整历史的无调用 helper 已删除；问题顺序、额度和解锁状态机保持不变。
- 实施（统一变化键）：复盘页删除逐条 `Hasher`，统一读取 `homeDashboardRevision`；空账本资格改读已发布的 `homeJourneyLedgerFacts.totalCommittedRecordCount`，AI 推荐缓存也只随统一 revision 刷新。已复核 `items` 的统一变化入口：新增、编辑、删除、AI 导入、本地恢复与云同步最终都通过该属性推进 revision；旧 revision 的播放、周分享与复盘保存结果均有显式拒绝策略。
- 修改文件：`NativeDemoApp/Models/InteractionStateModels.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。保留官网、合规、WeatherKit、登录同意、App Store、后端和所有未跟踪素材/输出的既有修改，不覆盖、不回退、不暂存、不提交。
- 自动回归：新增同 revision 播放/周分享快照一致、旧 revision 发布拒绝、已准备问题轮换和后台 Cover session 准备三组 XCTest；静态门禁锁定弹层只读快照、复盘保存后台准备、线索不得恢复完整历史扫描、统一 revision 与已准备空账本事实。真机矩阵新增 `FLOW-96`，覆盖弹层连续重绘、复盘连续保存、线索连续展开、六类账本变化、前后台/重启、100/1,000/5,000 条及 Time Profiler、Main Thread Hitches、Allocations。
- Windows 验证证据：`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/playback_copy_lint.py` 与 `python scripts/copy_lint.py` 均退出码 0；copy lint 扫描 92 个 Swift 文件，仅保留任务开始前已有 5 条 soft warning。`python scripts/validate_release_gate.py --phase windows` 退出码 0，最终输出 `release_repository_gate: OK`；100/1,000/5,000 条确定性夹具摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`，三张真实 12MP 图片、AI proxy 24/24、合规页、App Store 元数据、Nginx 安全头、迁移与 SQLite schema 均通过。
- 冻结边界复核：未修改生活印记、回声或叙事选择算法，未改问题顺序、痕迹/复盘 UI、播放章节、分享模板、照片准备、远程 AI、额度/会员/StoreKit、账本字段/存储/同步或 `ARCH-03`；只移动计算契机、复用不可变结果、统一 revision 并删除本项失去调用方的扫描 helper。
- 剩余风险与下一步：Windows 没有 Swift/Xcode，`@unchecked Sendable` 输入、任务组可选返回、Swift 6 actor 隔离、Cover session 跨执行器传递及新增 XCTest 尚未真实编译运行。下一步只在 macOS 执行 Swift 6 Debug/Release Clean Build 与全部 XCTest，再用新 TestFlight 按 `FLOW-96` 核对 100/1,000/5,000 条下的重绘、连续保存/展开、六类 revision 变化、旧结果拒绝、主线程 hitch 与内存；取得证据后才可改为 `VERIFIED`，不得先启动 `ARCH-03`。

---

## 50. 2026-07-23 真机签收定向修复队列

- 用户确认的执行顺序：`FACT-FIX-01` → `PHOTO-FIX-01` → `NARRATIVE-FIX-02` → `AI-FIX-06` → `AI-FIX-07` → `PERF-FIX-04` → `PERF-FIX-05`。必须逐项完成、逐项验证、逐项更新本台账；任何时刻仅允许一个任务为 `IN_PROGRESS`。
- 队列收口状态：`FACT-FIX-01`、`PHOTO-FIX-01`、`NARRATIVE-FIX-02`、`AI-FIX-06`、`AI-FIX-07`、`PERF-FIX-04`、`PERF-FIX-05` 已全部达到 `CODE_DONE`，本队列无 `IN_PROGRESS`。该队列收口当时 `PERF-AUDIT-04` 与 `ARCH-03` 尚未启动；`PERF-AUDIT-04` 的后续状态以第 49 项为准，`ARCH-03` 仍未启动。
- 工作区保护：开始前分支为 `feature/xuzhangapp-staging`；仅存在用户未跟踪的 `brand-assets/mockups/`、`brand-assets/source/pet-concepts/`、`brand-assets/source/pet-sprites/`、`scripts/__pycache__/` 与 `tmp/`，全部保留，不删除、不覆盖、不暂存。

### FACT-FIX-01：生活线索事实源与 OCR 通勤识别纠错

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码、静态与完整发布门禁已通过，缺 Xcode/iPhone `FLOW-65` 签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 真机现象：OCR 导入“天隆寺 > 雨山路”交通卡记录后，展示文案出现“刷卡进站”，但通勤生活线索少计；金额和进站口变化会使同一路线失去识别。同时本月线索出现真实账本中不存在的“超市买菜和家用”“人情往来”。
- 已确认根因：OCR 导入丢弃 `rawText` 中已经识别出的公共交通证据且未写现有 `scenePackId`；`LifeMarkService` 与 `LifeSceneSemanticService` 又把系统生成的 `displayEmotionTag` 混入事实匹配，导致展示文案一方面不能成为可靠结构，另一方面反向制造买菜、人情等假事实。
- 目标：建立“结构化字段/用户原话 > OCR 与可信商户证据 > 受控历史规律 > 系统展示文案”的事实优先级。展示文案不得参与生活线索事实匹配；强用户通勤词直接成立；OCR 公共交通只有在明确通勤词，或工作日同方向站点路线形成可靠历史规律时，才复用现有 `scenePackId = commute`。金额变化不作为否定条件，单次普通公共交通不得无证据升级为通勤。
- 允许修改：`LifeMarkService.swift`、`LifeSceneSemanticService.swift`、`HomeViewModel.swift` 中 OCR 导入的直接场景接线；对应 `StateRegressionTests.swift`、体验静态门禁、真机矩阵与本文档。
- 冻结边界：不新增或迁移账本字段，不修改金额/标题/日期/分类、OCR 识别结果与确认 UI、生活线索展示结构/排序/会员边界、首页布局、照片、复盘、AI 指令、额度/StoreKit、同步 DTO、主题、宠物、缓存生命周期、`PERF-AUDIT-04` 或 `ARCH-03`。不把所有地铁/公交单笔记录直接等同通勤。
- 计划验收：生成文案含“超市买菜和家用”或“朋友小聚聚餐”但标题、品牌和结构字段无事实证据时不得产生对应线索；真实盒马/叮咚/随礼/红包仍正常命中；用户标题含“下班路上”正常命中通勤；OCR 同工作日晚间目的地路线在既有可靠历史下，金额/入口变化仍写入通勤场景；单次非工作日或无历史公共交通不升级。新增确定性 XCTest、静态防回流和真机用例后执行完整 Windows 发布门禁；Xcode/iPhone 签收前最多标记 `CODE_DONE`。
- 实现（OCR 通勤）：新增 `OCRCommuteScenePolicy` 并接入正式 OCR 导入。明确标题含上班/下班/通勤等强词时直接复用现有 `scenePackId = commute`；普通公共交通必须同时满足工作日、早晚通勤时段、可解析站点路线及最近 120 天同方向同目的地至少两个独立工作日。站点比较会去除地铁站、进/出站口与 N 号口，金额不参与否定；单次普通交通与非工作日交通不升级。
- 实现（事实权限）：`LifeMarkService` 与 `LifeSceneSemanticService` 的通用事实文本不再读取系统生成的 `displayEmotionTag`，只使用可信标题、分类、受控品牌、地点与结构化场景。默认/系统生成标题不冒充用户事实；公共交通品牌只有结构化通勤场景或强通勤标题时才成为通勤，否则保持普通公共交通。旧版天气兼容只保留受控天气短语，不恢复通用展示文案事实权。
- 修改文件：`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Services/LifeMarkService.swift`、`NativeDemoApp/Services/LifeSceneSemanticService.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归：新增系统展示文案不得制造买菜/人情事实、真实盒马/随礼/下班标题仍命中、OCR 同路线金额与入口变化、历史不足、明确通勤强词及非工作日单次交通的确定性 XCTest；静态门禁锁定两处事实文本不回读 `displayEmotionTag`、OCR 必须写场景及测试接线；真机矩阵新增 `FLOW-65`，覆盖真假事实、增删、证据 ID 与 100/1,000/5,000 条。
- Windows 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；完整门禁包含生活语义、AI 契约、文案、主题、迁移、SQLite、三档夹具及三张真实 12MP 图片，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未新增或迁移账本字段，未修改金额/标题/日期/分类、OCR 识别与确认 UI、生活线索布局/排序/会员、首页、照片、复盘、AI 指令、额度/StoreKit、存储同步、缓存生命周期、`PERF-AUDIT-04` 或 `ARCH-03`；未删除、覆盖、暂存或提交用户未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险与下一项：Windows 无 Swift/Xcode/iPhone，新增 Swift 策略、默认参数、XCTest 与真实 OCR 文本仍需编译和 `FLOW-65` 真机验证，100/1,000/5,000 条下路线历史匹配耗时也需 Instruments 确认。下一项仅启动 `PHOTO-FIX-01`，处理照片证据与角色绑定，不在照片任务回改事实/OCR 结论。

### PHOTO-FIX-01：照片证据绑定与角色事实化

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码、静态与完整发布门禁已通过，缺 Xcode/iPhone `FLOW-66` 签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 真机现象：周记主图来自餐饮记录但右下角显示交通；线索文案把可乐/咖啡照片称为“现场”或“票据”；“这张照片对应哪一笔”没有显示所指照片和账单摘要，用户无法确认对象；编辑标题后旧的自动照片角色没有随事实变化。
- 已确认根因：主图角标读取周期快照首条记录分类，而不是 `anchor.itemID` 对应记录；自动角色策略对交通无条件补 `.vehicleCare + .receipt`、对未知照片补 `.experience + .moment`，并在添加时固化到记录，之后编辑不重判；提问只持有记录 ID，界面未投影同一记录的缩略图、标题和金额。
- 目标：所有主图、角标、文案与查证入口都以同一 `itemID` 为事实锚点；没有 OCR/用户文字/明确结构证据时不得称“票据”“现场”；编辑影响自动推断依据时重算自动角色，但保留用户明确选择；“对应哪一笔”直接展示该 ID 的照片缩略图和最小账单摘要。
- 允许修改：照片角色策略、记录照片元数据的自动推断/编辑接线、痕迹快照主图角标与线索查证投影、对应 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不改账单字段与迁移、图片二进制/顺序/封面选择、OCR 结论、生活事实算法、叙事主角评分、周记/月章章节、筛选日期、UI 主题、额度/会员/StoreKit、同步 DTO、缓存生命周期、`PERF-AUDIT-04` 或 `ARCH-03`；不得把用户未确认的图像内容当作视觉识别结果。
- 实现（角色事实门槛）：`PhotoMemoryPromptPolicy.anchorReason` 改为可弃权推断，不再把交通分类兜底成车辆票据，也不再把未知照片兜底成体验现场；系统展示情绪标签退出照片角色事实文本。普通车辆事项只标为车辆记录，只有标题/结构明确含小票、发票、收据、票据或支付截图等证据时才标票据；电影、展览、演出等明确体验仍可形成体验角色。无法判断的照片保留中性“照片/这笔的一张照片”，不猜图中内容。
- 实现（旧值与编辑）：新增自动照片元数据识别与重判。展示和叙事会忽略旧版自动生成但已无事实支持的“票据/现场”；保存编辑时，标题/分类等证据变化会清除或重算自动角色。带非系统说明的明确角色作为用户选择保留，不被自动覆盖；未新增账本字段或迁移。
- 实现（同 ID 绑定）：周记主图角标改为读取 `memoryAnchors.first.itemID` 对应记录分类，不再读取周期首笔；线索洞察携带 `highlightedItemID`，照片主线在英雄卡中直接展示同一记录的缩略图、标题、金额、时间与分类，继续追问也先按精确 ID 回到该笔，同日多照片不再靠日期猜测。
- 修改文件：`NativeDemoApp/Services/PhotoMemoryPromptPolicy.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoApp/Services/LifeInsightService.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归：新增普通咖啡/地铁照片弃权、车辆记录与明确票据分离、体验证据、自动角色编辑重判、用户说明保留、主图分类与照片证据按精确 ID、未知照片洞察不得发明现场等 XCTest；静态门禁锁定角色事实文本、弃权分支、编辑接线、中性播放、同 ID 投影和可见证据；真机矩阵新增 `FLOW-66`，覆盖同日多图、旧自动值、编辑、重启、无障碍及 100/1,000/5,000 条。
- Windows 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；完整门禁包含生活语义、AI 契约、文案、主题、迁移、SQLite、三档夹具与三张真实 12MP 图片，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未新增账本字段/迁移或同步 DTO，未改图片数据/顺序/封面选择、OCR 结论、生活事实算法、周记/月章章节、筛选、主题、额度/会员/StoreKit、缓存生命周期、`PERF-AUDIT-04` 或 `ARCH-03`；未删除、覆盖、暂存或提交用户未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险与下一项：Windows 无 Swift/Xcode/iPhone，新增可选角色、SwiftUI 缩略证据布局、VoiceOver、同日多照片和编辑后持久化仍需编译及 `FLOW-66` 真机签收；三档账本的图片解码和滚动需 Instruments 确认。下一项仅启动 `NARRATIVE-FIX-02`，优化已确认事实的情绪表达，不恢复无证据照片角色或修改事实识别。

### NARRATIVE-FIX-02：用户原话优先的照片与今日情绪表达

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码、文案、静态与完整发布门禁已通过，缺 Xcode/iPhone `FLOW-67` 签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 真机现象：用户备注“下班路上拍了张照片”已包含明确时刻、动作与画面，首页/回看却退化成“晚间一段路”“这张图以后查起来更清楚”等空洞说明；咖啡等稳定聚合还可能压过这条当日新鲜表达，最终不像情绪，也不像用户说的话。
- 已确认根因：今日主线选择把稳定咖啡聚合优先级放在通勤/用户新鲜表达之前；晚归模板只接受 21:00 后，20:43 的下班照片只能进入泛化“晚间路线”；照片说明长期读取自动角色通用 caption，没有把可信用户原话中的“下班路上＋拍照”投影成受控情绪句。
- 目标：情绪表达必须来自这笔记录已经存在的时刻、动作和安全用户原话；当日新鲜、高信息的用户表达优先于稳定重复聚合，但不得改变生活印记全局定义或虚构心情。对“下班路上拍了张照片”输出自然且有情绪温度的事实表达，例如“下班路上，也把这一刻留了下来。”，而不是工具说明或泛化标签。
- 允许修改：首页今日主线/主动作副文案的候选选择、照片与播放中对高置信用户表达的本地受控投影、对应 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不改 `FACT-FIX-01` 事实权限、`PHOTO-FIX-01` 角色门槛与 item ID 绑定，不改账单字段/存储同步、生活印记定义与全局排序、周记/月章章节、AI 远端事实包、照片内容识别、复盘、额度/会员/StoreKit、主题、缓存生命周期、`PERF-AUDIT-04` 或 `ARCH-03`；不得从金额、分类或照片本身推断未知心情。
- 实现（可信表达通道）：新增 `TrustedUserMomentNarrativePolicy`，只有正金额、真实照片、手工来源、明确用户编辑标题、安全非系统文案同时成立时才生成受控本地表达。对“下班路上拍了张照片”输出“下班路上，也把这一刻留了下来。”和短标签“下班路上，留住这一刻”；20:43 不冒充 21 点后晚归，既有晚归规则保持不变。无照片、OCR/AI 导入、默认标题与不安全文本全部弃权。
- 实现（当日优先与撤回）：首页生活印记快照和今日故事先选择当日可信新鲜表达，再回退既有晚归、生活印记与场景聚合，因此稳定咖啡不再压过这条原话，但 `LifeMarkService` 全局 priority 未改。编辑和附图会刷新受控短标签；移除最后一张照片时若当前标签来自该策略，会恢复原有普通情绪生成结果，不残留失去依据的文案。
- 实现（跨表面同源）：同一受控表达进入本地叙事信号事实、周/月代表一笔、照片锚点 caption、播放记录正文、照片洞察与线索标题；用户原话仍不进入远端 fact pack，照片角色资格和同 item ID 证据绑定继续读取 `PHOTO-FIX-01` 的结果。
- 修改文件：`NativeDemoApp/Services/NarrativeCopyResolver.swift`、`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoApp/Services/LifeInsightService.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归：新增 20:43 下班照片、真实照片/手工原话门槛、稳定咖啡竞争、叙事 lead 身份和照片说明同源 XCTest；静态门禁锁定本地事实条件、首页回退顺序、附图/编辑/移图标签生命周期、叙事与播放接线；真机矩阵新增 `FLOW-67`，覆盖对照场景、编辑/移图/重加、重启、无障碍与 100/1,000/5,000 条。
- Windows 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；完整门禁包含生活语义、AI 契约、主题、迁移、SQLite、三档夹具与三张真实 12MP 图片，文案扫描 81 个 Swift 文件，仅保留既有 5 条 soft warning，本项新增为 0。
- 冻结边界复核：未改生活印记定义/全局排序、21 点后晚归规则、事实权限、照片角色/item ID 绑定、账本字段、存储同步、周记/月章章节、远端 AI fact pack、复盘、额度/会员/StoreKit、主题、缓存生命周期、`PERF-AUDIT-04` 或 `ARCH-03`；未删除、覆盖、暂存或提交用户未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险与下一项：Windows 无 Swift/Xcode/iPhone，附图/移图后的短标签持久化、首页异步快照时序、周/月播放实际换行、VoiceOver 语序和三档真机性能仍需编译及 `FLOW-67` 签收。下一项仅启动 `AI-FIX-06`，处理复盘对比入口/意图/任务状态，不修改年份范围或本项叙事表达。

### AI-FIX-06：对比入口、相对成对周期与任务状态

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码、静态与完整发布门禁已通过，缺 Xcode/iPhone `FLOW-68` 签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 真机现象：复盘首页橙色差额区域看起来可操作却不能直达“做对比”；先点一次“查记录”再输入对比问题，结果会跳回“查记录”，而首次直接进入“做对比”正常；“最近 7 天餐饮和前 7 天比呢”没有稳定识别为成对周期对比。
- 已确认根因：橙色差额是普通 `VStack`，没有调用现有 `openReviewTask(.compare)`；自然语言识别的 `containsPairedPeriods` 只覆盖本周/上周、本月/上月；执行完成后无条件 `activeReviewTask = resolvedTask`，查询路径的旧任务状态会覆盖用户已解析的对比意图。
- 目标：橙色差额整区可点击并预填现有“对比最近 7 天和前 7 天的消费”；最近 N 天/前 N 天的同 N 成对表达稳定进入 compare；执行结果只能按本次最终解析意图更新任务状态，不能被上一次“查记录”污染。
- 允许修改：`InsightWebView` 的差额入口交互、对比意图识别与任务状态提交，必要的纯策略模型、对应 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不修改 `AI-FIX-07` 年份解析、查询/对比金额口径、账单写入、AI 远端服务、痕迹、叙事、照片、额度/会员/StoreKit、主题、缓存生命周期、`PERF-AUDIT-04` 或 `ARCH-03`。
- 实现（入口与无障碍）：复盘首页橙色差额整区改为真实按钮，直接调用既有 `openReviewTask(.compare)`，并自动填入“对比最近 7 天和前 7 天的消费”；补齐 VoiceOver 标签与操作提示，不改变首页数字和结果卡布局。
- 实现（成对周期）：`AICommandRecognitionPolicy` 新增同 N 的滚动日窗口识别，覆盖最近/过去/近 N 天与前 N 天、阿拉伯数字和中文数字；只有当前窗口与前窗口都出现且 N 相同才进入 compare，单段时间和不同 N 保持原意图。
- 实现（任务归属）：新增 `ReviewTaskResolutionPolicy`，在执行前依据本次最终识别意图将 compare/commuteDraft/query 分别落到做对比/补通勤/查记录；不支持文本不改写当前任务。删除根据返回结果 kind 二次覆盖任务的旧路径，因此上一次“查记录”或“做对比”不再污染本次任务状态。
- 修改文件：`NativeDemoApp/Models/InteractionStateModels.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归：新增从查记录识别同 N 滚动周期对比、本次最终意图拥有任务状态、当前与紧邻前一窗口边界的确定性 XCTest；静态门禁锁定按钮入口、成对识别、任务提交顺序和旧结果覆盖路径退役；真机矩阵新增 `FLOW-68`，覆盖橙色入口、3/7/30 天、中英文数字、任务反向切换、空结果、快速请求、VoiceOver 与 100/1,000/5,000 条。
- Windows 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；完整门禁包含生活语义、AI 契约、文案、主题、迁移、SQLite、三档夹具及三张真实 12MP 图片，文案仅保留既有 5 条 soft warning。
- 冻结边界复核：未改年份解析、查询/对比金额与证据口径、账单写入、远端 AI、痕迹、叙事、照片、额度/会员/StoreKit、主题、缓存生命周期、`PERF-AUDIT-04` 或 `ARCH-03`；未删除、覆盖、暂存或提交用户未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险与下一项：Windows 无 Swift/Xcode/iPhone，Swift 正则/中文数字覆盖、按钮实际点击区域、VoiceOver 朗读、快速请求 UI 时序和三档账本响应仍需编译及 `FLOW-68` 真机签收。下一项仅启动 `AI-FIX-07`，补齐一年/今年/去年时间槽，不回改对比状态机或数据口径。

### AI-FIX-07：年份自然时间范围

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码、静态与完整发布门禁已通过，缺 Xcode/iPhone `FLOW-69` 签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 真机现象与根因：输入“过去一年”等明确时间后仍显示默认“过去 3 天”，因为查询时间槽只识别日/周/月和模糊最近范围；“今年”“去年”也未被视为显式时间，最终统一落入 `defaultRecentDays = 3`。
- 实现范围：`AICommandEngine` 将过去一年/近一年/最近一年统一解析为截至今天的滚动 12 个月；“今年/本年/这一年/本年度”解析为当年 1 月 1 日至今天；“去年/上一年/上年度”解析为完整上一自然年。所有范围继续使用既有半开区间过滤、当前时区、金额/分类/证据与最多七天柱形展示逻辑。
- 修改文件：`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归：新增年份短语识别测试，以及固定 2026-07-23 验证滚动 12 个月、当年、上一自然年起止边界和证据 ID 的确定性 XCTest；静态门禁锁定显式年份识别、12 个月窗口和自然年日历边界；真机矩阵新增 `FLOW-69`，覆盖同义词、闰年/时区、空结果、任务切换、VoiceOver 与 100/1,000/5,000 条。
- Windows 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；文案扫描 81 个 Swift 文件，仅保留既有 5 条 soft warning。
- 冻结边界复核：未改无时间词查询的既有默认值、对比识别/任务状态机、查询/对比金额和证据口径、账本写入、远端 AI、痕迹、叙事、照片、额度/会员/StoreKit、主题、缓存生命周期、`PERF-AUDIT-04` 或 `ARCH-03`；未删除、覆盖、暂存或提交用户未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险与下一项：Windows 无 Swift/Xcode/iPhone，Calendar 年边界、闰年、真机时区、空结果显示和三档账本查询耗时仍需编译及 `FLOW-69` 签收。下一项仅启动 `PERF-FIX-04`，处理痕迹/线索快照生命周期，不混入全局 `PERF-AUDIT-04`。

### PERF-FIX-04：痕迹与线索快照生命周期

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码、静态与完整发布门禁已通过，缺 Xcode/iPhone `FLOW-70` 签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 真机现象与根因：无账单变化时从其他 Tab 返回痕迹/线索仍显示加载；杀进程重开后也从空白重新整理。根因是周/月/线索快照虽已放在 `StatsTabState`，但三个 `NeedsRefresh` 与线索刷新 UUID 仍是 `StatsWebView` 临时 `@State`，页面重建即恢复“需要刷新”；缓存 key 还依赖每次进程随机的 `Hasher` 和无关自定义日期，无法跨视图或跨进程稳定复用。`TraceSnapshotStore` 本身也只在内存中。
- 实现（真实生命周期 key）：周、月、线索的已发布 snapshot key、章节/线索内容修订和冷启动上下文全部迁入 `StatsTabState`。key 由账本 `homeDashboardRevision`、自然日/周期、会员、当前范围/筛选、自定义日期、额度/解锁和叙事内容修订组成；预设范围不再被未启用的自定义日期误失效。账本监听改读修订号，不再比较完整 `items` 或为每次进入生成随机内容签名。
- 实现（零重复与旧内容承接）：`weekTraceNeedsRefresh`、`monthTraceNeedsRefresh`、`clueTraceNeedsRefresh` 改为“已发布 key 是否等于当前 key”的派生结论，同修订 Tab 返回只命中现有快照，不创建准备任务。真实变化时保留安全旧快照并在后台原子替换，不再用阻断滚动的加载遮罩覆盖已有内容；筛选切换不展示上一筛选结果，会员切换会清除旧会员快照，避免降级时短暂泄露。
- 实现（可丢弃冷启动展示缓存）：新增确定性账本指纹与有界 JSON/UserDefaults 展示缓存，只持久化标题、摘要、周期、笔数、活跃天、金额和主分类，不复制照片或完整账本。账本指纹、自然日、会员和范围完全匹配时，杀进程重开先展示真实旧内容并显示非阻断后台更新；账本变化、跨日、会员变化、范围不匹配、缓存缺失/损坏或 schema 不符时直接弃权并走真实首次准备。指纹按 UUID 排序且每个账本修订最多计算一次。
- 修改文件：`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归：新增 key 同输入复用、账本修订/筛选/自定义范围真实失效、预设范围忽略无关日期、指纹顺序稳定且内容变化失效、存储对象重建后命中、指纹/日期不匹配和损坏缓存安全丢弃的 XCTest；静态门禁禁止三个刷新真值与刷新 UUID 回到临时 `@State`、禁止 `items` 比较和随机 `traceItemsSignature` 回流，并锁定旧内容非阻断承接；真机矩阵新增 `FLOW-70`。
- Windows 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；100/1,000/5,000 条、真实 12MP、语义、文案、迁移和 SQLite 门禁均通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改生活线索/生活印记/叙事算法、痕迹和线索正式页面结构、播放、分享、复盘、账单字段、存储同步、额度规则、会员价格/购买/StoreKit、主题、`PERF-AUDIT-04` 或 `ARCH-03`；未处理该审计已登记的分享弹层和继续提问扫描，也未删除、覆盖、暂存或提交用户未跟踪内容。
- 剩余风险与下一项：Windows 无 Swift/Xcode/iPhone，SwiftUI `@Binding` 状态发布、UserDefaults 冷启动读取、会员降级瞬间、跨日、VoiceOver、5,000 条指纹耗时及任务埋点仍需编译与 `FLOW-70` 真机签收。下一项仅启动 `PERF-FIX-05`，把会员长期档案快照移出临时 Sheet 并预热复用，不回改痕迹缓存或启动 `PERF-AUDIT-04`。

### PERF-FIX-05：会员长期档案预热与复用

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码、静态与完整发布门禁已通过，缺 Xcode/iPhone `FLOW-71` 签收，不标记 `VERIFIED`。当前无 `IN_PROGRESS`。
- 真机现象与根因：会员方案页的长期档案每次打开都要等，且先闪“0 条/0 天”。根因是完整快照、修订号和准备任务全部属于临时 `MemberPricingView @State`，Sheet 新建时固定从 `.empty` 开始；`onDisappear` 又取消任务并清空 revision。即使后台计算已发生，下一次打开也无法复用，真实空账本和“尚未准备”共用同一个假 0 对象。
- 实现（共享预热）：新增 `@MainActor LifetimeArchiveSnapshotStore`，由 `ContentView @StateObject` 持有并通过环境注入会员页。`ContentView` 在首次显示、账本修订变化和 App 回到前台时调用 `prepareIfNeeded`，因此计算在用户打开 Sheet 前已经启动；相同账本修订/自然日只准备一次，Sheet 打开/关闭不再取消任务或清空修订。
- 实现（旧内容与冷启动）：Store 在真实修订变化时保留上一份已发布档案，后台完成后只接受最新 request ID 并原子替换。新增指纹＋自然日校验的轻量 JSON/UserDefaults 缓存，复用与痕迹相同的确定性账本指纹；杀进程重开时匹配则立即承接真实标题、摘要和指标，并把缓存快照重新绑定当前内存修订后静默重算。指纹/日期不匹配、缓存缺失/损坏或 schema 不符时安全弃权。
- 实现（禁止假 0）：`MemberPricingView` 只在 `snapshot != nil` 时渲染长期档案指标；无有效快照时显示非阻断的“首次准备”说明，明确不以 0 冒充数据。`LifetimeArchiveSnapshotComputation` 对真实空账本返回带当前 `sourceRevision` 的 `preparedEmpty`，因此只有确定账本确实为空后才展示 0 条/0 天；冷缓存旧 revision 通过不可变复制绑定当前 revision。
- 修改文件：`NativeDemoApp/ContentView.swift`、`NativeDemoApp/Views/MemberPricingView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档；同时把本轮新增的通用确定性账本指纹策略命名收敛为 `LedgerDisplayFingerprintPolicy`，供痕迹和会员两个可丢弃展示缓存复用，未改变指纹字段或痕迹行为。
- 自动回归：更新真实空账本 revision 断言；新增长期档案 Codable 缓存跨 Store 重建命中、另一账本/跨日拒绝、损坏数据清除，以及共享 Store 最终发布真实 prepared-empty 的 XCTest；静态门禁锁定 `ContentView` 预热/注入、禁止档案状态回到 Sheet 临时 `@State`、禁止 `.empty` 假 0 和消失时清修订，并锁定冷缓存与缺失态 UI；真机矩阵新增 `FLOW-71`。
- Windows 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；100/1,000/5,000 条、真实 12MP、生活语义、文案、主题、迁移和 SQLite 均通过，81 个 Swift 文件仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改会员价格、权益说明、免费次数、登录连续性、购买、恢复、StoreKit、会员状态同步、账单字段/存储同步、长期档案计算与文案规则、痕迹正式 UI、复盘、主题、`PERF-AUDIT-04` 或 `ARCH-03`；未删除、覆盖、暂存、提交或推送用户未跟踪素材、`tmp/` 与缓存目录。
- 剩余风险与后续签收：Windows 无 Swift/Xcode/iPhone，`@StateObject/@EnvironmentObject` 注入、严格并发、TaskGroup、冷缓存首次读取、真实 StoreKit Sheet 链路、VoiceOver、快速开关十次和 5,000 条预热耗时仍需编译及 `FLOW-71` 真机签收。七项定向修复均已完成 Windows 代码与门禁；下一步只做 Xcode 全量编译/XCTest 和 `FLOW-65`～`FLOW-71` 真机签收，签收前全部保持 `CODE_DONE`，不得启动 `PERF-AUDIT-04` 或 `ARCH-03`。

---

## 51. SHARE-REBUILD：AI Cover Engine + Dynamic Template System 方案（2026-07-23）

- 当前状态：`SHARE-REBUILD-01`～`SHARE-REBUILD-05` 已于 2026-07-24 达到 `CODE_DONE`；用户于 2026-07-24 明确要求继续下一步，`SHARE-REBUILD-06` 现为唯一 `IN_PROGRESS`。本阶段只扩展统一引擎至 20 套、补齐边界回归并准备旧实现退役；旧渲染器必须等 Xcode/真机全矩阵通过后才可删除，`PERF-AUDIT-04` 与 `ARCH-03` 继续保持 `NOT_STARTED`。
- 用户真机结论：分享图底部仍有重复，并明确指出这属于反复问题，准备推倒重做为“AI 导演决定故事表达、程序按 Recipe 渲染”的 Cover Engine 与动态模板系统；分享成品应像个人生活杂志，不再像 App 截图、统计海报或 AI 总结卡。
- 历史归属：`UI-02` 已记录浅色模板的顶部品牌、底部品牌条和二维码重复，并曾要求品牌只出现一次；`SHARE-03` 又要求一条主线、一条辅助和最多两个生活线索。本次复发证明旧修复属于局部约定，缺少结构性单一消费约束。
- 当前代码根因：仓库并存 `SummaryPlaybackSheet.swift` 的 `WeeklyStoryShareCardView` 与 `InsightWebView.swift` 的 `WeeklyShareCardView` 两套渲染器；前者每个模板自行拼接 Header、指标、文案和 `lifeSlicePosterFooter / lifeSlicePosterBrandFooter / filmPosterFooter`。Hero/Warm Light 会先显示记录数/记录日/照片数的 `warmLightMetricBar`，再用同一 `posterSummaryMetricText` 生成底部条；Clean/Custom Background 也会先显示三项指标后再次调用同指标 Footer。`PosterCopyModel` 的 title/subtitle/tagline/body 多级 fallback 与 View 混合，字符串去重无法证明语义只出现一次。
- 架构决策：新系统必须以 `CoverFactPack → ContentAtom → ContentAllocationPlan → CoverRecipe → ResolvedCoverLayout → PreparedCoverRenderInput` 为唯一链路；每个事实 Atom 与 semantic key 全画布最多消费一次。模板只能声明语义槽位和 Footer 预留区，不能实现 Footer；`CoverCanvasRoot` 是唯一 Footer 渲染者。AI 只从受控模板/色板/背景/媒体角色中选择，不输出文案、坐标或 SwiftUI；本地 Validator 对事实、重复、隐私、图片门槛、对比度和溢出拥有最终否决权。
- 方案文档：新增 `AI_COVER_ENGINE_DYNAMIC_TEMPLATE_SYSTEM_v1.md`，完整定义 AI Cover Engine、Dynamic Template Engine、模板选择/AI 导演流程图、图片评分、动态布局、背景/取色算法、`BackgroundRecipe`、`CoverRecipe`、SwiftUI 文件边界、Figma 参数、20 套模板适用场景、逐图高保真生成规格、1.35 秒动效、实施顺序和验收矩阵。
- 推荐实施顺序：`SHARE-REBUILD-01` 契约与单一事实分配 → `SHARE-REBUILD-02` 统一准备/渲染根节点/唯一 Footer → `SHARE-REBUILD-03` 首发 6 个基础模板 → `SHARE-REBUILD-04` 本机图片评分与动态取色 → `SHARE-REBUILD-05` 可选 AI 导演 → `SHARE-REBUILD-06` 扩展到 20 套并在真机签收后退役两套旧渲染器。任何时刻只允许一个 `IN_PROGRESS`，不得直接在旧 Footer 上继续打补丁。
- 图片与隐私边界：默认只在本机用 Vision/Core Image 计算清晰度、曝光、颜色、方向、裁切安全和脸部矩形；不得识别人脸身份、年龄、性别或情绪。AI 默认不接收照片，只接收脱敏事实包、媒体描述符与合法候选 ID；敏感 OCR、损坏图、低像素图、收据/截图和重复图不得被强行设为 Hero。
- 视觉生成状态：20 套效果图的逐张画布、固定文案、构图、图片数量、色板和禁用项已写入方案，状态为 `SPEC_READY / RENDER_PENDING`。当前桌面会话未提供内置图像生成工具；按 imagegen 技能规则，不能未经用户明确同意切换到需要本机 `OPENAI_API_KEY` 的 CLI/API 备用路径，因此本轮未伪造或用 SVG/HTML 冒充 20 张 AI 高保真位图。
- 冻结边界：方案阶段不修改现有分享图片准备/降采样/不可变 RenderInput、周/月播放、Narrative Plan、照片顺序与引用、账单、OCR、生活线索、会员、额度、StoreKit、主题、存储同步、`PERF-AUDIT-04` 或 `ARCH-03`；不删除、覆盖、暂存或提交用户未跟踪素材与 `tmp/`。
- 下一步：先由用户评审方案，并明确是否允许使用 imagegen CLI/API 备用路径生成 20 张位图；代码实施需再次确认后只启动 `SHARE-REBUILD-01`。在新引擎完成契约、渲染、Xcode/XCTest 和真机矩阵前，不删除旧分享实现，也不把任何新任务标记 `CODE_DONE/VERIFIED`。
- 2026-07-23 位图提示词交付：用户明确选择自行执行 imagegen CLI/API 备用路径；新增 `AI_COVER_ENGINE_IMAGEGEN_PROMPTS_v1.jsonl`，将 20 套模板拆为 20 个独立 `gpt-image-2` 任务，统一输出 `2160x3840`、`high`、PNG，并使用 `01-hero-story.png`～`20-quiet-editorial.png` 的唯一语义文件名。每个任务独立锁定故事、图片主次、色板、材质、逐字中文文案及“唯一 Footer / 指标只在 Footer / 无主体数据卡 / 无等大宫格 / 无二维码 / 无第三方商标 / 无水印”约束；未使用 `n=20` 代替独立设计。
- 提示词验证证据：PowerShell 逐行 `ConvertFrom-Json` 得到 `JobCount = 20`、`UniqueOutputs = 20`，模型、尺寸、质量与格式各只有一个合法值；使用内置 `image_gen.py generate-batch --dry-run` 完整通过 20 个任务的参数和输出路径校验，没有调用网络或生成位图。`OPENAI_API_KEY` 不写入仓库，也不得在对话中提供。
- 本次状态与冻结边界：仍属于产品评审资产准备，不修改生产代码、测试、工程文件、分享 UI、播放、账本、照片、会员或额度；`SHARE-REBUILD-01`～`SHARE-REBUILD-06` 继续全部保持 `NOT_STARTED`，当前无 `IN_PROGRESS`，`PERF-AUDIT-04` 与 `ARCH-03` 状态不变。
- 剩余风险与下一步：生成模型可能出现中文错字、额外伪文字、Footer 重复、图片主次失真或风格趋同；用户执行后需逐张按方案第 17 节人工验收，失败时只针对单张的一个问题定向重跑。位图评审通过也不等于 SwiftUI 模板完成；代码实施仍须另行确认并从 `SHARE-REBUILD-01` 开始。
- 2026-07-23 CLI execution check: the requested `generate-batch --concurrency 3` command passed dry-run for all 20 jobs and resolved outputs from `output/imagegen/ai-cover-v1/01-hero-story.png` through `20-quiet-editorial.png`. `OPENAI_API_KEY` is absent from the process, user, and machine environments, so no network request ran and no bitmap was created or overwritten. Scope remains review-asset generation only; roadmap statuses stay unchanged. Next: set the key locally, rerun the same command, then perform the section 17 per-image review.
- 2026-07-23 Hero Story bitmap result: generated the first review asset with the built-in image tool because the CLI environment still has no `OPENAI_API_KEY`, corrected an initial footer-separator violation with a single focused rerun, and saved `output/imagegen/ai-cover-v1/01-hero-story.png`. Verification: visual review confirms one dominant rainy-window coffee Hero, one smaller supporting still life, the required title/support/footer each shown once, no extra legible copy, no UI chrome/QR code/trademark/watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 7,526,241 bytes, SHA-256 `C6C3B830CA1A3BFF9C483A81691F1D78D4EB86BBE531FA47F29806C942C6CECD`. Scope remains review assets only and all roadmap statuses remain unchanged. Remaining risk: typography correctness is visually reviewed rather than OCR-gated and the other 19 covers remain pending; next asset is only `02-magazine.png`, followed by the same per-image review before continuing.
- 2026-07-23 Magazine bitmap result: generated and saved `output/imagegen/ai-cover-v1/02-magazine.png` with the built-in image tool. Verification: visual review confirms one dominant dinner Hero, two clearly smaller unequal supporting images for a rainy commute and coffee moment, asymmetric editorial hierarchy, and the required title/editor note/footer each shown once without extra legible copy, footer separators, UI chrome, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 6,535,675 bytes, SHA-256 `009A83BDA7C5DB3716639499EAD5F4717832A98F46BB57952B1CF529665F33C6`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography correctness is visually reviewed rather than OCR-gated and 18 covers remain pending; next asset is only `03-memory-focus.png`, followed by the same per-image review before continuing.
- 2026-07-23 Memory Focus bitmap result: generated and saved `output/imagegen/ai-cover-v1/03-memory-focus.png` with the built-in image tool. The first render was rejected because an open book introduced incidental printed text; a single focused rerun replaced it with plain unmarked objects. Verification: visual review confirms privacy-safe hands only, no face or identity cue, one off-center focus photograph with expansive negative space, the required title/footer each shown once without extra legible copy or footer separators, and no labels/cards/UI/QR code/trademark/watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 6,341,799 bytes, SHA-256 `437A8C9BC2FE78A5B8B108C3ECC9746E2F84F8FD2706998E9CB5C8D04A88C73A`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography and incidental-text absence are visually reviewed rather than OCR-gated and 17 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Journal bitmap result: generated and saved `output/imagegen/ai-cover-v1/04-journal.png` with the built-in image tool. Verification: visual review confirms a photograph-free cream-paper journal composition with title, two note blocks, and footer each shown once; no additional legible dates/numbers/copy, no image placeholder, data card, app chrome, QR code, trademark, watermark, or footer separator; local Pillow normalization produced exact `2160x3840` RGB PNG, 7,104,146 bytes, SHA-256 `8892722695A83641B35B420AC40979EBA2D0A479A43339239D3DED430738CF98`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography and absence of incidental glyphs are visually reviewed rather than OCR-gated and 16 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Film bitmap result: generated and saved `output/imagegen/ai-cover-v1/05-film.png` with the built-in image tool. Verification: visual review confirms four deliberately unequal night-commute film frames with one clear Hero and sequential vertical rhythm, the required title/footer each shown once without extra legible captions or film numbers, and no equal grid, data card, UI chrome, QR code, trademark, watermark, or footer separator; local Pillow normalization produced exact `2160x3840` RGB PNG, 7,868,848 bytes, SHA-256 `5ED23AF60BA6E41C1193CC7FEA90C5C3EBFEB08B76AD2B638C763CBE00D9E3E7`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography and incidental-text absence are visually reviewed rather than OCR-gated and 15 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Minimal bitmap result: generated and saved `output/imagegen/ai-cover-v1/06-minimal.png` with the built-in image tool. Verification: visual review confirms zero photography/placeholders, approximately 90% negative space, one faint abstract window shadow, and the required title/footer each shown once without extra legible text or footer separators; no cards, data UI, icons, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 5,924,394 bytes, SHA-256 `2BED7CA7BE80C2764308E64CD3A9EBB047117B2E7951B5ADCECC57D2792546C6`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography and incidental-glyph absence are visually reviewed rather than OCR-gated and 14 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Quote bitmap result: generated and saved `output/imagegen/ai-cover-v1/07-quote.png` with the built-in image tool. Verification: visual review confirms the required sentence dominates the cover, one tiny asymmetrical dinner photograph acts only as punctuation, and the quote/footer each appear once without extra legible text, footer separators, incidental photo text, cards, app chrome, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 7,892,303 bytes, SHA-256 `00DB543D7D3798C0442C4941873E601F70B261F2D2805B63B8A84C4A3AD37589`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography and incidental-text absence are visually reviewed rather than OCR-gated and 13 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Timeline bitmap result: generated and saved `output/imagegen/ai-cover-v1/08-timeline.png` with the built-in image tool. Verification: visual review confirms one slim vertical timeline with four abstract unlabeled points, one medium lunch Hero and one clearly smaller evening-walk photograph, and the required title/footer each shown once without extra dates, labels, captions, incidental photo text, or footer separators; no calendar/project UI, cards, chart, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 7,004,855 bytes, SHA-256 `04C121796181C36D9B714B3E328A7A29F6BFA19AE6DED9C9CDD13879DFCB9B12`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, marker count, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 12 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Postcard bitmap result: generated and saved `output/imagegen/ai-cover-v1/09-postcard.png` with the built-in image tool. Verification: visual review confirms one dominant Nanjing street Hero, one much smaller ticket-stub-shaped supporting photograph, an abstract letter/number-free circular postmark, blank address lines, and the required title/footer each shown once without extra legible street/ticket copy or footer separators; no barcode, navigation UI, data card, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 8,842,600 bytes, SHA-256 `D99CA3AD2EFC7A17BE28E9B990523A2DA4BB1888DEAC9FB9A4EBD7409598B6C7`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, postmark abstraction, and incidental-photo-text absence are visually reviewed rather than OCR/vision-gated and 11 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Scrapbook bitmap result: generated and saved `output/imagegen/ai-cover-v1/10-scrapbook.png` with the built-in image tool. Verification: visual review confirms exactly five candid everyday photographs, one unmistakably dominant Hero and four progressively smaller unequal supporting pieces, restrained blank tape/torn-paper layering, and the required title/footer each shown once without extra labels, incidental photo text, or footer separators; no equal grid, body cards, app chrome, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 8,178,827 bytes, SHA-256 `E5B8058F3F91051E9FEE4F700415F522C67C4FD36A0244F656EF1A903940ACA9`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, exact image count/hierarchy, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 10 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Editorial bitmap result: generated and saved `output/imagegen/ai-cover-v1/11-editorial.png` with the built-in image tool. Verification: visual review confirms exactly two unequal daily-life photographs with one rainy dinner-street Hero and one small walk-home detail, one slim editorial-note column, and the required title/note/footer each shown once without extra legible photo text or footer separators; no body cards, app/news UI, equal grid, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 8,104,874 bytes, SHA-256 `075F3E9795F673B4B094399CF5CD3336E4FB8FC8ADC2C17D36078A4803F5D0FA`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, image count/hierarchy, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 9 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Memory Wall bitmap result: generated and saved `output/imagegen/ai-cover-v1/12-memory-wall.png` with the built-in image tool. Verification: visual review confirms exactly six candid everyday photographs in an asymmetric masonry layout, one dominant Hero near 45% of the visual area and five clearly smaller unequal supporting images, plus the required title/footer each shown once without captions, incidental photo text, or footer separators; no equal gallery grid, body cards, app UI, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 7,824,185 bytes, SHA-256 `2C78961441E089821FE64BF4A1532C23D9F7AC22D3FE0885414D0D71B2A6441C`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, exact image count/hierarchy, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 8 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Travel Note bitmap result: generated and saved `output/imagegen/ai-cover-v1/13-travel-note.png` with the built-in image tool. Verification: visual review confirms exactly three unequal Nanjing travel photographs with one larger Hero and two smaller supports, one abstract non-functional route line, exactly two place-label elements, and the required title/labels/footer rendered without additional map labels, incidental photo text, navigation controls, or footer separators; no data cards, equal grid, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 9,438,087 bytes, SHA-256 `B0D41D5C1ABF116E827C0193708F91FE0F965DA16E50302ABB2F62B8A79F47C1`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, label count, route abstraction, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 7 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Book Cover bitmap result: generated and saved `output/imagegen/ai-cover-v1/14-book-cover.png` with the built-in image tool. Verification: visual review confirms one post-rain July street Hero with literary book-jacket hierarchy, the title, the explicitly provided subtitle `2026.07.2007.26`, and the footer each rendered once without correction or extra legible street/book copy, footer separators, ISBN, barcode, price, publisher mark, app UI, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 9,740,184 bytes, SHA-256 `699F96316A3DD44A647596E064A5129EEB97C0BC4CFE3DF76B65FE043080C107`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, exact numeric subtitle, and incidental-text absence are visually reviewed rather than OCR-gated and 6 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Nature Diary bitmap result: generated and saved `output/imagegen/ai-cover-v1/15-nature-diary.png` with the built-in image tool. Verification: visual review confirms exactly three unequal nature photographs with one dominant leafy-path Hero, one smaller evening sky, and one smaller plant observation, plus airy asymmetrical whitespace and the required title/footer each shown once without botanical labels, incidental photo text, or footer separators; no equal grid, body cards, app UI, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 8,462,128 bytes, SHA-256 `85E4D7F1D452F102202897A6B641EA1394ED90BD2AB4B7BD980906C5C1A4A200`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, exact image hierarchy, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 5 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Coffee Story bitmap result: generated and saved `output/imagegen/ai-cover-v1/16-coffee-story.png` with the built-in image tool. Verification: visual review confirms exactly two unequal photographs with one dominant rainy-window coffee Hero, a changed-seat detail, one much smaller supporting image, a restrained faint coffee-ring decoration, and the required title/footer each shown once without menu, branding, incidental photo text, or footer separators; no advertisement treatment, body cards, app UI, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 7,898,800 bytes, SHA-256 `81D1390A076628FDFD8FEB54A6CB4EBA687A477DDACEB68696B7D975D3572255`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, changed-seat readability, decoration opacity, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 4 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Warm Home bitmap result: generated and saved `output/imagegen/ai-cover-v1/17-warm-home.png` with the built-in image tool. Verification: visual review confirms exactly three unequal privacy-safe photographs with one dominant dinner-table Hero, one smaller lamp detail, and one smaller unmarked home object, plus the required title/footer each shown once without faces, addresses, screens, identifying details, incidental photo text, or footer separators; no staged catalog UI, body cards, equal grid, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 6,810,920 bytes, SHA-256 `1ECE89A10C6FE10406A20EFE39678DB321A95653FC111C473B5625157AD18975`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, privacy details, exact image hierarchy, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 3 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-23 Night Story bitmap result: generated and saved `output/imagegen/ai-cover-v1/18-night-story.png` with the built-in image tool. Verification: visual review confirms exactly three unequal low-light photographs with one dominant deep-blue wet-pavement city Hero and two smaller reflective night details, ample dark negative space, readable contrast, and the required title/footer each shown once without transport/storefront text or footer separators; no neon treatment, equal grid, body cards, app UI, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 8,130,263 bytes, SHA-256 `14B72E20424D133262561B01B7DD441074F1D50879629ED6BEDFFAEA272A9757`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, low-light hierarchy, contrast, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 2 covers remain pending; next asset must follow the JSONL order and receive the same per-image review before continuing.
- 2026-07-24 Ocean bitmap result: generated and saved `output/imagegen/ai-cover-v1/19-ocean.png` with the built-in image tool. Verification: visual review confirms exactly three unequal coastal photographs with one expansive sea Hero and two much smaller details, calm horizontal rhythm, abundant sky-like whitespace, and the required title/footer each shown once without resort/boat text or footer separators; no advertising treatment, equal collage, body cards, app UI, QR code, trademark, or watermark; local Pillow normalization produced exact `2160x3840` RGB PNG, 7,510,038 bytes, SHA-256 `97DE34251726CAFEEA3467D4BF359CF2958D6CCF55DF5F17501F465BEE100F11`. Scope remains review assets only and roadmap statuses remain unchanged. Remaining risk: typography, coastal hierarchy, and incidental-text absence are visually reviewed rather than OCR/vision-gated and 1 cover remains pending; next asset is only `20-quiet-editorial.png`, followed by the same per-image review and a final 20-file inventory check.
- 2026-07-24 Quiet Editorial and final inventory result: generated and saved `output/imagegen/ai-cover-v1/20-quiet-editorial.png` with the built-in image tool. Visual review confirms one very small off-center morning-table photograph, oversized warm whitespace, fine restrained hierarchy, and the required title/note/footer each shown once without incidental photo text or footer separators; local Pillow normalization produced exact `2160x3840` RGB PNG, 6,147,551 bytes, SHA-256 `BB9917DCED85A0A2A18180CDF52B4B7067A10D7BC042360E90816A74F57F82AB`. Final inventory verification against `AI_COVER_ENGINE_IMAGEGEN_PROMPTS_v1.jsonl`: 20 expected outputs, 20 PNG files, 20 unique semantic filenames, no missing or unexpected files, all exact `2160x3840` RGB PNG, 20 unique SHA-256 values, total 153,286,718 bytes, spanning `01-hero-story.png` through `20-quiet-editorial.png`. Scope remains product-review bitmap assets only; production code and all `SHARE-REBUILD-01` through `SHARE-REBUILD-06` statuses remain unchanged with no `IN_PROGRESS`. Remaining risk: required-copy accuracy, privacy, hierarchy, and incidental-text absence were visually reviewed per image rather than OCR/automated-vision gated; next step is the full section 17 human review of all 20 bitmaps, with any failure rerun only for that single image and single defect, then separate confirmation before starting `SHARE-REBUILD-01`.

---

## 52. TRACE-RECOVERY：痕迹页状态、证据与性能恢复方案（2026-07-24）

- 用户真机现象：痕迹 Tab 生活页的本周/本月切换看起来无反应；线索页和痕迹页反复 Loading、切换明显卡顿；Loading 时“生活/线索”选择器被顶进状态栏或灵动岛；“公共交通的变化”只说有 3 笔支持，却没有说明与哪一周期比较、差多少、是哪几笔，且下方图表混用整页 14 笔数据。
- 共同根因 A：筛选状态、展示快照、加载状态和滚动锚点没有共用完整目标 Key。生活页允许目标周/月缺失时跨周期显示另一份快照；线索页只有一个可见 `preparedClueSnapshot`，切换时先清空，再异步查缓存，缓存命中也会因任务让步闪整页 Loading；目标内容未发布就修改 `.scrollPosition`，透明大占位与半透明遮罩共同导致顶部控件越过 Safe Area。
- 共同根因 B：变化算法已产生当前数量、上一可比周期数量、差值和两组证据 ID，但快照投影只保留“当前页有 N 笔”；图表又读取整页 `input.items`，使事实范围、证据范围和视觉范围不一致。单场景周期变化还被固定展示为“两条生活线”，“通勤出行”与“公共交通”两种聚合口径没有解释。
- 方案文档：新增 `TRACE_STATE_EVIDENCE_PERFORMANCE_RECOVERY_PLAN_v1.md`，定义完整 `TraceSnapshotKey`、按 Key 的准备状态、缓存同步命中、非阻断内容准备态、Safe Area/滚动意图边界、`TraceChangeEvidence` 契约、公共交通变化卡方案、执行顺序和真机验收矩阵。
- `TRACE-RECOVERY-01`：状态 `NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；用户已于 2026-07-24 确认方案，Windows 代码、静态与完整发布门禁已通过，当前无 `IN_PROGRESS`。缺 Xcode/iPhone `FLOW-72`，不标记 `VERIFIED`。
- `TRACE-RECOVERY-02`：状态 `NOT_STARTED`。再修按完整 Key 的快照复用、缓存优先同步命中、同 Key 请求合并和局部非阻断准备态；缓存命中必须做到零整页 Loading、零重复 `buildClue`、零滚动跳动，无账单/筛选/资格变化时从其他 Tab 返回不得重建。
- `TRACE-RECOVERY-03`：状态 `NOT_STARTED`。最后补全变化事实与证据展示；恢复当前值、基线值、差值、方向与两组精确记录，单场景显示“本周变化”，图表只消费本条证据，并明确“通勤出行”和“公共交通”的不同统计口径。
- 固定顺序：`TRACE-RECOVERY-01` → `TRACE-RECOVERY-02` → `TRACE-RECOVERY-03`；第一项已达到 `CODE_DONE`，第二、三项仍为 `NOT_STARTED`，当前无 `IN_PROGRESS`。一次只启动一项，不与 `PERF-AUDIT-04`、`ARCH-03` 或分享重构合并。
- 冻结边界：不修改公共交通/通勤识别规则、变化阈值（差值至少 2、相对变化至少 50%）、账单金额/日期/标题/分类/存储字段、OCR、照片、叙事、分享、宠物、同步、会员/额度/StoreKit、AI 指令或相邻路线任务；不得借机整体重构 `StatsWebView`。
- 计划验收：周/月连续切换 20 次时选择、标题与正文周期完全一致；目标无快照时绝不显示另一周期正文；顶部控件任何加载阶段都位于 Safe Area 下方；公共交通变化必须同时显示当前数、基线数、差值和两组逐笔证据，图表不得混入无关记录；覆盖冷启动、Tab 返回、跨日、账单变化、会员变化、自定义范围、快速切换、VoiceOver、Dynamic Type、Reduce Motion 及 100/1,000/5,000 条，主线程不得出现大于 100ms hitch。
- 实现（周期真值）：`TraceLifePreparationPolicy.hasVisibleSnapshot` 只承认当前选择周期，不再用另一周期快照冒充可见内容；新增 `TraceSnapshotVisibilityPolicy`，要求生活范围、预设周期、快照自身范围和发布 key 全部一致。`StatsWebView` 只把 `visiblePreparedLifeSnapshot` 交给章节卡，删除 `desiredSnapshot ?? fallbackSnapshot`；同样按当前 scope 校验冷启动展示，目标不存在或 key 失效时改用明确准备面，不生成透明滚动目标。
- 实现（Safe Area 与滚动）：将“生活/线索”和生活页周/月控制移到 ScrollView 外的 `tracePinnedControls`，Loading 只覆盖正文 viewport，顶部控制不再随内容锚点滚进状态栏。普通生活/线索和周/月点击不再写 `scrollAnchorID`；首页/复盘深链改为在 `StatsTabState` 记录 `pendingLifeChapterScrollRange`，只有目标周期真实快照发布后才无动画执行一次定位，用户手动改选范围或模式会取消待定位任务。
- 修改文件：`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`TRACE_STATE_EVIDENCE_PERFORMANCE_RECOVERY_PLAN_v1.md` 与本文档；未修改工程文件、缓存容器、线索构建或变化算法。
- 自动回归：更新周/月准备策略测试，新增另一周期存在时仍不可见、生活范围必须匹配预设周期、快照范围/key 与冷启动 scope 必须精确匹配、外部路由保留原滚动位置并只记录待定位范围等 XCTest；静态门禁禁止恢复跨周期 fallback、模式切换写滚动锚点和透明占位锚点；真机矩阵新增 `FLOW-72`，覆盖灵动岛/刘海、安全区、连续切换 20 次、旧 key、冷启动展示、深链定位、VoiceOver、Dynamic Type、Reduce Motion 与性能。
- Windows 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；100/1,000/5,000 条确定性夹具和三张真实 12MP 图片通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未修改公共交通/通勤识别、变化阈值、线索事实/图表、缓存容器与 `buildClue` 生命周期、账单/OCR/照片/叙事/分享/宠物/同步、会员/额度/StoreKit、AI 指令、`PERF-AUDIT-04`、`ARCH-03` 或相邻路线任务；未删除、覆盖、暂存或提交用户未跟踪素材、位图、`tmp/` 与缓存目录。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，新增 SwiftUI 固定控制区、可选绑定语法、Task 取消和 `.scrollPosition` 发布时序仍需真实编译；灵动岛/刘海、特大字号、VoiceOver、Reduce Motion 及连续切换时是否零跳动只能由 `FLOW-72` 真机确认。第二阶段尚未实施，因此线索单快照、缓存命中仍异步 `Task.yield()`、Tab 返回重复 Loading 等性能问题仍存在。
- 下一步：先在 macOS 执行 Debug/Release 与全部 XCTest，再按 `FLOW-72` 真机签收本周/本月真值、顶部 Safe Area 和深链延后定位；第一阶段定向问题只回改本项。通过编译/真机记录后，下一项才是 `TRACE-RECOVERY-02` 的按 key 缓存与非阻断加载，不提前修改公共交通证据展示。

---

## 53. SHARE-VISUAL-REVIEW-01：20 套 AI Cover 位图人工签收（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `VERIFIED`；2026-07-24 已完成两轮逐张视觉签收，当前无 `IN_PROGRESS`。本项只评审 `output/imagegen/ai-cover-v1/01-hero-story.png`～`20-quiet-editorial.png`，不修改生产 SwiftUI、分享旧实现、账单、照片或会员逻辑。
- 评审标准：逐张核对方案第 17 节和对应 JSONL 的固定中文、画布构图、图片数量与 Hero/Secondary 主次、色板/材质、Footer 唯一性、指标位置，以及额外伪文字、App 式卡片、等大宫格、二维码、第三方商标、水印和隐私风险。失败只记录单张、单缺陷的定向重做要求，不整套改写。
- 交付物：新增逐图 `PASS / REWORK` 验收表，记录可复核的视觉证据、剩余风险和单图重做指令；完成后更新本项状态。位图通过不代表 SwiftUI 已实现，`SHARE-REBUILD-01`～`06` 继续保持 `NOT_STARTED`。
- 2026-07-24 首轮人工签收结果：新增 `AI_COVER_ENGINE_VISUAL_ACCEPTANCE_v1.md`，完成 01～20 全部逐张检查，严格结论为 `PASS 0 / REWORK 20`。20 张均只有一处共性硬伤：Footer 虽然全画布只出现一次、所有指标也只在 Footer，但 JSONL 规定的 `·` 分隔符全部被空格替代，未达到逐字一致；`14-book-cover.png` 另把要求的 `2026.07.20—07.26` 错生成为 `2026.07.2007.26`。
- 其余视觉证据：所有标题、正文、编辑注和地名（除 14 的日期）逐字通过；每张的图片数量、Hero/Secondary 主次、留白与指定装饰成立；未发现额外伪文字、App 卡片/界面、等大宫格、二维码、第三方商标、水印或未允许的隐私线索。09 的邮戳和地址线为无字抽象装饰，不判作伪票据文字。20 套跨模板结构区分度通过；相邻题材组仍由版面、媒体角色和装饰语法明确区分。
- 首发范围锁定：`01 Hero Story`、`02 Magazine`、`04 Journal`、`07 Quote`、`08 Timeline`、`06 Minimal` 对应“主角故事 / 杂志版面 / 生活手札 / 一句话 / 时间线 / 留白”。此处只锁定产品范围，不代表模板代码已启动或位图可直接进入生产。
- 修改文件：仅新增 `AI_COVER_ENGINE_VISUAL_ACCEPTANCE_v1.md` 并更新本文档；未修改 20 张源 PNG、JSONL、方案文档、SwiftUI、测试、工程文件或任何业务逻辑。桌面审阅用 contact sheet 位于 Codex 可视化目录，不属于生产或仓库资产。
- 冻结边界复核：20 张 PNG 继续只作为视觉验收基线，不作为生产模板图片；未启动 `SHARE-REBUILD-01`～`06`，未修改旧分享渲染器、账单、照片、播放、会员、额度、StoreKit、同步、`PERF-AUDIT-04`、`ARCH-03` 或相邻路线任务；未删除、覆盖、暂存、提交或推送任何用户现有修改和未跟踪文件。
- 剩余风险与下一步：人工视觉检查没有 OCR/自动视觉门禁，重做仍可能回归已通过的中文、图片主次或禁用项。`SHARE-VISUAL-REVIEW-01` 保持唯一 `IN_PROGRESS`；下一步按验收表对 01～20 逐张、每次单缺陷修正 Footer，14 再以独立步骤修正日期，每张生成后立即全量复核。20 张全部 `PASS` 前不得启动 `SHARE-REBUILD-01`；通过后才按“契约与单一事实分配 → 唯一渲染根节点/唯一 Footer → 首发 6 套”顺序推进。
- 2026-07-24 visual acceptance repair: user review confirmed all 20 covers passed title/body copy, image count and hierarchy, privacy, incidental-text, App-card, QR-code, trademark, and watermark checks, but every Footer had rendered the required middle-dot separators as spaces; `14-book-cover.png` also rendered `2026.07.2007.26` instead of `2026.07.20—07.26`. Applied a surgical raster fix to `output/imagegen/ai-cover-v1/01-hero-story.png` through `20-quiet-editorial.png`: added exactly three anti-aliased middle dots to each existing Footer without moving or repainting accepted characters, and on `14-book-cover.png` cloned/feathered same-page blank paper texture over only the old subtitle before drawing the exact corrected date range. Verification: pixel-diff audit against temporary pre-fix backups found zero changed pixels outside the 60 dot neighborhoods and the approved book-cover date rectangle; 19 files changed only in one 13–14-pixel-high Footer run, while file 14 changed only in the date run and Footer run. Final inventory remains 20 expected/20 actual PNGs, no missing or unexpected files, all exact `2160x3840` RGB PNG, 20 unique SHA-256 values, total 153,248,232 bytes; corrected file 14 SHA-256 is `AD3F484E22A8B1DF6EB833B989D15A377D553EB7D919C5E9E2B119697D6087A0`. Production代码、测试与工程文件未修改；`SHARE-VISUAL-REVIEW-01` 当时继续保持 `IN_PROGRESS`，等待本轮复核。
- 2026-07-24 第二轮最终签收：01～20 的 Footer 均显示三个可见 `·`，Footer 全画布仍只出现一次且全部指标只在 Footer；`14-book-cover.png` 日期准确为 `2026.07.20—07.26`。与修复前 contact sheet 的逐格像素差异复核证明，01～13、15～20 只改变 Footer 中点区域，14 只改变日期和 Footer 中点区域；此前通过的固定中文、图片数量、Hero/Secondary 主次、色板/材质、隐私、伪文字、App 卡片、等大宫格、二维码、商标和水印门禁均无回归。`AI_COVER_ENGINE_VISUAL_ACCEPTANCE_v1.md` 已写入 20 张逐图 `PASS` 证据，最终结论 `PASS 20 / REWORK 0`。
- 最终文件与验证证据：修正版实际覆盖保存在 `output/imagegen/ai-cover-v1/`，未生成 `ai-cover-v2`；20 个预期/20 个实际 PNG，无缺失或额外文件，全部精确 `2160x3840` RGB PNG，20 个 SHA-256 均唯一，合计 `153,248,232` bytes。`git diff --check` 与验收文档 20 条最终 `PASS` 行检查通过；没有修改 SwiftUI、测试、工程文件或业务逻辑。
- 最终冻结边界与后续：20 张 PNG 仍只作为视觉验收基线，不作为生产模板图片；`SHARE-VISUAL-REVIEW-01` 达到 `VERIFIED`，当前无 `IN_PROGRESS`。人工检查仍不是 OCR 门禁，这是生产契约校验器需要覆盖的残余风险。下一项才可启动 `SHARE-REBUILD-01`，并严格从 `CoverFactPack → ContentAtom → ContentAllocationPlan → CoverRecipe`、单一事实消费、唯一 Footer 契约、重复与隐私校验开始；本轮未启动该任务，也未触碰其他路线任务或用户现有修改。

---

## 54. SHARE-REBUILD-01：契约与单一事实分配（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 代码、工程接线、静态与完整发布门禁已通过；缺 macOS/Xcode 编译与 XCTest 实跑，不标记 `VERIFIED`。
- 允许范围：新增纯 Foundation 的 `CoverFactPack`、认证故事/标签、媒体与隐私描述符、`CoverContentAtom`、`CoverContentAllocationPlan`、`CoverRecipe`、内容分配引擎和本地 Validator；新增对应 XCTest、工程接线和静态门禁。
- 必须证明：每个 Atom ID 与 semantic key 在全画布最多消费一次；可见区域并集严格等于 `consumedAtomIDs`；品牌恰好一次且只在 Footer；指标只能在 Footer；二维码必须是允许且有效的真实 HTTPS URL；重复归一化文案、未知 Atom、事实/Recipe 修订不一致、隐私拒绝媒体和不合格 Hero 必须被本地否决。
- 冻结边界：本项不修改 `SummaryPlaybackSheet.swift`、`InsightWebView.swift` 或任何 SwiftUI View；不接入两个旧分享入口，不实现 `CoverCanvasRoot`、`GlobalFooterRenderer`、`PreparedCoverRenderInput`、首发 6 套模板、图片评分/取色或 AI 导演；不删除旧分享实现，不修改账单、OCR、叙事事实、播放、照片存储、会员、额度、StoreKit、同步、`PERF-AUDIT-04`、`ARCH-03` 或 TRACE 路线。
- 验证计划：XCTest 覆盖合法分配、Atom ID 重复、semantic key 重复、归一化文案重复、Footer/品牌/指标位置、二维码真实性、媒体隐私/角色、Recipe 与 FactPack 身份绑定；Windows 执行 `git diff --check`、静态门禁和完整发布门禁，Xcode/XCTest 留待 macOS 补签。
- 实现（不可变契约）：新增 `CoverFactPack`、`CertifiedStory`、`CertifiedLabel`、`FooterFacts`、`MediaDescriptor`、`SafeCoverContext`、`CoverPrivacyPolicy` 与受控枚举；`CoverFactPack.contentAtoms()` 只从认证故事、认证标签、媒体说明和固定 FooterFacts 生成稳定 Atom，不接收 View fallback 或任意 AI 文案。新增 Codable/Equatable/Sendable 的 `CoverRecipe`、模板/色板/背景/字体/媒体角色/Footer/动画受控 token；Recipe 绑定 `sourceRevision + periodKey + contentFingerprint`，不存在任意坐标、字体文件名或开放式模板 ID。
- 实现（单一消费）：`ContentAllocationEngine` 先验证 Atom catalogue 和全部请求，再构造 `ContentAllocationPlan`；同一 Atom ID 重复请求、不同 Atom 共用 semantic key、归一化后文案重复、未知 Atom 或角色进入错误区域时直接返回结构化 violation，不会产生半合法 Plan。Plan 的全部可见区域并集必须与 `consumedAtomIDs` 精确相等。
- 实现（唯一 Footer 与隐私）：品牌必须恰好一次且只在 Footer；记录数、记录日、照片数三个固定 Atom 必须完整且只能在 Footer；二维码只能在 Footer、必须获策略允许并解析为带 host 的 HTTPS URL。FactPack 拒绝负数、空认证事实、超过两个 marks、媒体数大于照片事实、重复/被阻止/敏感/已排除媒体和未授权地点；Recipe 再拒绝重复媒体/槽位、多 Hero、不合格 Hero、照片说明或 Hero 与认证证据脱节、Footer/内容映射漂移及跨修订/周期/指纹结果。
- XCTest：新增独立 `CoverContractEngineTests.swift` 共 12 个用例，覆盖合法 FactPack→Allocation→Recipe、Atom ID/semantic key/归一化文案三类重复、指标越区与 consumed set 漂移、唯一品牌、Footer 不得漏指标、二维码允许＋HTTPS、隐私阻止媒体、Secondary-only 冒充 Hero、照片/说明证据绑定、Recipe 身份漂移和 Codable round trip；测试文件已接入 `NativeDemoAppTests` Target。
- 修改文件：新增 `NativeDemoApp/CoverEngine/Models/CoverContracts.swift`、`NativeDemoApp/CoverEngine/Validation/CoverContractValidator.swift`、`NativeDemoAppTests/CoverContractEngineTests.swift`；更新 `NativeDemoApp.xcodeproj/project.pbxproj`、`scripts/experience_static_check.ps1` 与本文档。未修改 `SummaryPlaybackSheet.swift`、`InsightWebView.swift`、任何 SwiftUI View、旧分享代码或视觉基线 PNG。
- Windows 验证证据：新文件 UTF-8/空白/括号结构审计通过，9 个新增 PBX object 定义唯一且三份 Swift 文件已分别接入 App/Test Target；`git diff --check` 通过；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过；`python scripts/validate_release_gate.py --phase windows` 完整通过并输出 `release_repository_gate: OK`。100/1,000/5,000 条夹具、三张真实 12MP、生活语义、文案、主题、迁移、SQLite 与代理测试均保持通过，仅有既有 5 条 soft copy warning。
- 冻结边界复核：未实现或引用 `CoverCanvasRoot`、`GlobalFooterRenderer`、`PreparedCoverRenderInput`、首发 6 模板、图片分析/动态取色或 AI 导演；两个旧分享入口没有接入新契约，旧 Footer 与旧渲染器没有删除或打补丁；未修改账单、OCR、叙事事实、播放、照片存储、会员、额度、StoreKit、同步、TRACE、`PERF-AUDIT-04`、`ARCH-03` 或用户其他未跟踪素材。
- 剩余风险与下一步：Windows 没有 Swift 编译器、Xcode 或 iPhone，新增 Swift 语法/泛型推断、Codable、Sendable、PBX 接线和 12 个 XCTest 必须在 macOS 完成 Debug/Release 编译及测试实跑后才能把本项标为 `VERIFIED`。按既定路线，下一项可启动 `SHARE-REBUILD-02`，但只能实现统一准备、不可变 `PreparedCoverRenderInput`、`CoverCanvasRoot` 与唯一 `GlobalFooterRenderer`，不得提前实现首发模板、图片评分/取色或 AI 导演。

---

## 55. SHARE-REBUILD-02：统一准备、唯一渲染根节点与 Footer（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 代码、工程接线、静态与完整发布门禁已通过；缺 macOS/Xcode 编译、XCTest、ImageRenderer 像素核对与 iPhone `FLOW-73`，不标记 `VERIFIED`。
- 允许范围：实现统一 `CoverShareFlow`、不可变 `PreparedCoverRenderInput`、最小 `ResolvedCoverLayout`、`CoverCanvasRoot` 与唯一 `GlobalFooterRenderer`；为 `SummaryPlaybackSheet.swift` 和 `InsightWebView.swift` 两个旧分享入口建立 Adapter；新增预览/导出同源、唯一 Footer、旧修订拒绝与同步渲染 XCTest、工程接线和静态门禁。
- 必须证明：准备流程只接受已经通过 `CoverContractValidator` 的 FactPack/Allocation/Recipe；RenderInput 固定同一 revision、periodKey、fingerprint 与可见内容；模板体没有 Footer 构造能力；预览和导出消费同一个 RenderInput 身份，导出路径不重新选 Recipe、不重新生成文案、不联网且不包含异步图片或加载态。
- 冻结边界：本项不实现主角故事、杂志版面、生活手札、一句话、时间线、留白或其他生产模板；不实现图片评分、Vision/Core Image 取色、AI 导演、20 套扩展或旧渲染器退役；不修改账单、OCR、叙事事实、播放、照片存储、会员、额度、StoreKit、同步、TRACE、`PERF-AUDIT-04` 或 `ARCH-03`。20 张 PNG 继续只作视觉基线，不进入生产渲染。
- 工作区保护：开始前 `git status --short` 已记录现有台账、PBX、静态门禁、CoverEngine 契约、测试、方案/提示词/验收文档、品牌素材、20 张位图、`tmp/` 与缓存目录；本项不删除、覆盖、暂存或提交这些用户及前序修改。
- 验证计划：先补纯身份/准备流程测试，再补 SwiftUI 根节点与唯一 Footer 的静态结构门禁；Windows 运行 `git diff --check`、`scripts/experience_static_check.ps1` 和完整 `scripts/validate_release_gate.py --phase windows`。因当前无 Swift/Xcode/iPhone，真实编译、XCTest、ImageRenderer 像素一致性和两个旧入口真机保存路径留待 macOS 补签，完成前最多标记 `CODE_DONE`。
- 实现（锁定准备输入）：新增 `CoverRenderIdentity`、最小 `ResolvedCoverLayout`、不可变 `PreparedCoverRenderInput` 与 `CoverShareSession`；Session 的预览与导出属性返回同一个锁定对象，不在保存时重新选择 Recipe、生成文案或加载图片。`CoverShareFlow` 在生成 RenderInput 前重新执行 `CoverContractValidator`，并拒绝旧 source revision、Recipe/Layout 身份漂移、正文 Atom 集合漂移、Footer Atom 进入主体、正文/Footer 重叠、媒体 ID/裁切/处理方式漂移、准备图片集合不一致、非法缺图计数和无法同步生成的已验证二维码。
- 实现（唯一根节点与 Footer）：新增 `CoverCanvasRoot`，由一个 `CoverTemplateBodyRenderer` 只渲染非 Footer Atom 和已准备图片，并在根节点恰好实例化一次 `GlobalFooterRenderer`；Footer 文案只从认证 Footer Atom 按 ` · ` 连接，品牌与三项指标不向模板体暴露。`CoverExportCoordinator` 只消费 `session.exportRenderInput`，以同步 `ImageRenderer` 输出 1080×1920，不包含网络、异步图片、加载态或二次事实准备。
- 实现（两个旧入口 Adapter）：新增 `LegacyWeeklyCoverAdapter`，把回放完成页和复盘“保存本周摘页”的现有周分享事实映射进同一 FactPack→Allocation→Recipe→Layout→Flow 链路；回放预览与保存复用同一 `CoverShareSession`，复盘保存也经过同一 Adapter/Flow/ExportCoordinator。收据/截图、空证据与不安全媒体在 FactPack 前过滤，缺图计数安全累加；当前仅使用 `minimal + foundation.<legacy variant>` 过渡布局，不属于首发模板实现。旧两套渲染源码继续保留，未提前退役。
- XCTest 与静态门禁：新增 `CoverShareFlowTests.swift`，覆盖预览/导出对象身份相同、Footer Atom 不进入主体、旧修订拒绝、Footer 泄漏拒绝、Recipe 与 Layout 图片裁切/处理漂移拒绝、两个旧入口共用 Adapter、收据媒体过滤及同步 1080×1920 导出；新增 PBX App/Test Target 接线。静态门禁同时锁定唯一 `GlobalFooterRenderer(` 调用、渲染树无 `URLSession`/`ProgressView`/`.task`、两个入口接线、测试名称与 `FLOW-73`。
- 修改/新增文件：`NativeDemoApp/CoverEngine/Models/CoverRenderingContracts.swift`、`NativeDemoApp/CoverEngine/Flow/CoverShareFlow.swift`、`NativeDemoApp/CoverEngine/Flow/LegacyWeeklyCoverAdapter.swift`、`NativeDemoApp/CoverEngine/Rendering/CoverCanvasRoot.swift`、`NativeDemoAppTests/CoverShareFlowTests.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoApp.xcodeproj/project.pbxproj`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- Windows 验证证据：`git diff --check` 通过；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 退出码 0；`python scripts/validate_release_gate.py --phase windows` 完整通过并输出 `release_repository_gate: OK`。100/1,000/5,000 条确定性夹具、三张真实 12MP、生活语义、文案、主题、迁移、SQLite 与代理测试全部保持通过，仅保留既有 5 条 soft copy warning。PBX 复核确认 4 个新生产文件进入 App Target、1 个新测试文件进入 Test Target，`GlobalFooterRenderer(` 全仓当前根文件中仅一个实例化点。
- 冻结边界复核：未实现主角故事、杂志版面、生活手札、一句话、时间线、留白或其他生产模板；未实现图片评分、Vision/Core Image 取色、AI 导演或 20 套扩展；未删除旧渲染器，未把 20 张 PNG 接入生产，也未修改账单、OCR、叙事事实、播放生成、照片存储、会员、额度、StoreKit、同步、TRACE、`PERF-AUDIT-04`、`ARCH-03` 或用户未跟踪素材。`StatsWebView` 的现有周分享 payload 构建和 Adapter fallback 证据筛选保持原语义，未借本项扩张为全局性能重构。
- 剩余风险与下一步：Windows 没有 Swift/Xcode/iPhone，新增 Swift 可选链/泛型推断、MainActor hop、PBX 编译、全部 XCTest、`ImageRenderer` 透明度/字体/像素一致性、相册权限与连续保存生命周期仍需在 macOS/iPhone 按 `FLOW-73` 实跑；在这些证据补齐前本项保持 `CODE_DONE`。既定路线下一项为 `SHARE-REBUILD-03` 首发 6 个基础模板，只允许实现已锁定的“主角故事 / 杂志版面 / 生活手札 / 一句话 / 时间线 / 留白”，不得同时进入图片评分/取色、AI 导演、20 套扩展或旧渲染器退役。

---

## 56. SHARE-REBUILD-03：首发 6 套基础模板（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 代码、工程接线、静态与完整发布门禁已通过；缺 macOS/Xcode 编译、XCTest、六套像素与 iPhone `FLOW-74` 签收，不标记 `VERIFIED`。
- 允许范围：只新增首发模板描述目录、确定性本机资格选择、Recipe 媒体角色分配、六套 `ResolvedCoverLayout` 与模板体视觉 token；首发范围严格为 `heroStory / magazine / journal / quote / timeline / minimal`，用户显示名为“主角故事 / 杂志版面 / 生活手札 / 一句话 / 时间线 / 留白”。允许把两个现有 Adapter 的旧样式 ID 映射到这六套并更新回放分享样式入口名称；允许新增对应 XCTest、PBX 接线、静态门禁和真机矩阵。
- 必须证明：0/1/2/3/4+ 张输入均有合法模板且最多使用模板上限内的已准备图片；无 Hero、收据/截图、Secondary-only、缺图与敏感媒体不能被放大为 Hero；Quote/Minimal 长标题不硬截断而回退 Journal/Timeline；Magazine 始终 1 大 1～2 小且不形成等大宫格；Timeline 只在至少 3 个真实记录日时启用；无图模板不渲染占位、加载态或“暂无图片”。六套仍只消费 Allocation/Recipe/Layout，Footer 继续只能由根节点唯一渲染。
- 冻结边界：本项不实现 Vision/Core Image 图片评分、裁切安全分析或动态取色，不实现 AI 导演、网络请求、多样性冷却、20 套扩展、1.35 秒完整动效或旧渲染器退役；不修改账单、OCR、叙事事实/文案选择、播放章节、照片存储/顺序、会员、额度、StoreKit、同步、TRACE、`PERF-AUDIT-04`、`ARCH-03`。20 张 PNG 继续仅作视觉结构基线，不进入生产包。
- 工作区保护：开始前已重新执行 `git status --short`；继续保留台账、PBX、分享入口、CoverEngine 前两阶段、方案/提示词/验收文档、品牌素材、20 张位图、`tmp/`、缓存目录及全部用户未跟踪文件，不删除、不覆盖、不暂存、不提交。
- 验证计划：XCTest 覆盖六模板目录、旧样式映射、0/1/2/3/4+ 图资格与媒体上限、无 Hero/敏感媒体降级、长文回退、Timeline 记录日门槛、六套布局结构差异、Footer 隔离和预览/导出同源；Windows 运行 `git diff --check`、`scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows`。因当前无 Swift/Xcode/iPhone，真实编译、XCTest、六套 1080×1920 像素、长文截断、VoiceOver、Reduce Motion、真实图片内存和连续切换/保存留待 macOS/iPhone 补签，完成前最多标记 `CODE_DONE`。
- 实现（目录与硬资格）：新增 `LaunchCoverTemplateCatalog`，只登记 `heroStory / magazine / journal / quote / timeline / minimal` 六套及锁定中文名；旧样式 ID 只映射到六套。确定性选择器以可用安全图片数、事实绑定 Hero、真实记录日和主文长度判定资格：主角故事/杂志版面必须有 Hero，时间线至少 3 个记录日，一句话/留白长文回退生活手札或时间线，所有图片档位均有无占位降级。
- 实现（媒体与布局）：每套模板通过独立 Allocation Request、媒体 Recipe 和 `ResolvedCoverLayout` 分配 Hero/Secondary/Decoration；Magazine 最多实际使用 3 张并保持 1 大 1～2 小，Secondary-only、收据、截图、敏感或缺失图片不能成为 Hero。六套分别使用主角大图、非对称杂志栏、手札纸张、集中引语、纵向时间线和留白构图；长文 Journal 使用 5 行扩展区，Timeline 标签来自真实 `dailyCountTrend`。模板体继续不持有 Footer，唯一 `GlobalFooterRenderer` 结构未改变。
- 实现（入口与回归）：`LegacyWeeklyCoverAdapter` 现在生成真实时间线 Atom、调用六模板选择/Allocation/Layout 并保持 Recipe/Allocation 身份一致；回放样式入口显示六个锁定名称，并按实际安全图片数、记录日与文案长度过滤资格，收据/截图不计入模板图片能力。新增 8 个 `LaunchCoverTemplateTests` 覆盖六模板目录、旧 ID 映射、0/1/2/3/4+ 图、媒体层级、隐私 Hero、长文回退、时间线门槛、结构差异和 Footer 隔离；新增 `FLOW-74` 与静态门禁。
- 修改/新增文件：`NativeDemoApp/CoverEngine/Templates/LaunchCoverTemplates.swift`、`NativeDemoApp/CoverEngine/Flow/LegacyWeeklyCoverAdapter.swift`、`NativeDemoApp/CoverEngine/Rendering/CoverCanvasRoot.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoAppTests/LaunchCoverTemplateTests.swift`、`NativeDemoApp.xcodeproj/project.pbxproj`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- Windows 验证证据：`git diff --check` 通过；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 退出码 0；`python scripts/validate_release_gate.py --phase windows` 完整通过并输出 `release_repository_gate: OK`。100/1,000/5,000 条确定性夹具、三张真实 12MP、生活语义、文案、主题、迁移、SQLite 与代理测试全部保持通过，仅保留既有 5 条 soft copy warning。PBX 审计确认 197 个 object 定义唯一，新增生产/测试文件均接入对应 Target；根渲染文件中 `GlobalFooterRenderer(` 仍只有一个实例化点。
- 冻结边界复核：未实现或引用 Vision 图片评分、Core Image 动态取色、AI 导演、网络选模板、多样性冷却、20 套生产扩展或完整动效；未接入 20 张 PNG，未删除两套旧渲染源码，也未修改账单、OCR、叙事事实/文案选择、播放章节、照片存储/顺序、会员、额度、StoreKit、同步、TRACE、`PERF-AUDIT-04`、`ARCH-03` 或用户其他未跟踪素材。
- 剩余风险与下一项：当前 Windows 没有 Swift、Xcode 或 iPhone，`.max`/字典枚举键等 Swift 推断、SwiftUI `ForEach`/`Path`、PBX 实际编译、8 个 XCTest、六套 1080×1920 像素层级、长文截断、真实图片裁切、特大字号、VoiceOver、Reduce Motion、内存和连续切换/保存仍需在 macOS/iPhone 按 `FLOW-74` 实跑；补齐前本项保持 `CODE_DONE`。下一项仅可启动 `SHARE-REBUILD-04` 本机图片评分与动态取色，不得同时启动 AI 导演、20 套扩展或旧渲染器退役。

---

## 57. SHARE-REBUILD-04：本机图片评分、裁切安全与动态取色（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 代码、工程接线、静态与完整发布门禁已通过；缺 macOS/Xcode 编译、XCTest 实跑及 iPhone `FLOW-75`，不标记 `VERIFIED`。
- 允许范围：只新增本机 `Vision/Core Image` 图片质量分析、稳定媒体身份与规则版本缓存、Hero/Secondary 确定性排序、脸部矩形仅用于裁切安全、动态色板提取及其在不可变 `PreparedCoverRenderInput` 中的消费；允许调整回放分享图片准备时机、对应 XCTest、PBX 接线、静态门禁和真机矩阵。
- 必须证明：严重模糊、严重曝光、像素不足、收据/截图和隐私拒绝图片不能成为 Hero；合格 Hero 按故事证据硬门槛后再按本机分数稳定排序，辅助图保持互补主次；裁切焦点在预览与导出一致；动态色板来自已锁定 Hero、经过饱和度和对比度约束，无图或分析失败确定性回退受控色板。
- 交互与性能边界：图片读取、降采样、分析和取色必须在后台、有界并发、可取消，并以稳定图片身份＋分析规则版本缓存；不得在 SwiftUI `body`、样式切换或保存动作中临时分析。播放尾章可预热，分享弹层只揭示已准备结果；未完成时只在操作层显示非阻断状态，不把加载态画入封面。样式切换只复用分析结果重排 Recipe/Layout，旧 context/revision 结果不得反写；关闭页面释放当前准备输入，快速切换或连续保存不重复分析、不串用旧结果。
- 隐私边界：所有图片分析默认只在本机完成，不上传照片、不新增网络请求；Vision 只允许脸部矩形和裁切安全，不识别人脸身份，不推断年龄、性别、关系或情绪；不新增 OCR 内容理解，不修改既有收据/截图和敏感媒体过滤规则。
- 冻结边界：不实现或调用 AI 导演，不扩展其余 14 套模板，不加入多样性冷却，不退役旧分享渲染器，不改 1.35 秒完整动效；不修改账单、OCR、叙事事实/文案、播放章节、照片存储与引用、会员、额度、StoreKit、同步、TRACE、`PERF-AUDIT-04` 或 `ARCH-03`。20 张 PNG 继续只作视觉基线，不进入生产包。
- 工作区保护：启动前 `git status --short` 已记录台账、PBX、两个分享入口、CoverEngine 01～03、测试、方案/提示词/验收文档、品牌素材、20 张位图、`tmp/` 与缓存目录的既有修改或未跟踪内容；本项不删除、不覆盖、不暂存、不提交相邻任务和用户素材。
- 验证计划：新增纯策略和媒体分析 XCTest，覆盖稳定缓存键/规则版本、分数边界、Hero 排序与证据门槛、Secondary-only/收据/低像素/模糊/曝光反例、裁切焦点夹紧、动态色板饱和度/对比度、无图回退、取消和旧 revision 拒绝；静态门禁锁定无网络、无身份/情绪推断、`body`/保存零分析、预览导出同一 RenderInput，并新增真实 12MP、快速切换 20 次、连续保存 20 次、后台取消、内存与 hitch 的真机矩阵。Windows 运行 `git diff --check`、体验静态门禁和完整发布门禁；当前环境无 Swift/Xcode/iPhone，最多标记 `CODE_DONE`。
- 实现（本机分析与缓存）：新增 `LocalCoverMediaAnalyzer` actor，只分析已经降采样、预解码的本机图片；以实际图片数据指纹、像素尺寸和 `cover-media-analysis-v1` 组成稳定缓存键，最多缓存 64 个轻量分析结果，不缓存大图。分析分批最多并发 2 张，解码任务通过 cancellation handler 传播页面取消，分析 task group 同步取消；关闭播放 Sheet 清理当前图片与 Session。Vision 只执行脸部矩形和注意力显著区域，Core Image 只生成 64×64 像素样本；没有 OCR、身份、年龄、性别、关系或情绪推断，也没有网络请求。
- 实现（质量、角色与失败降级）：本机结果固定清晰度、曝光、动态范围、短边分辨率、构图、主体显著度、裁切安全和确定性质量分。严重模糊、严重曝光、短边低于 1080px、裁切不安全、收据/截图、隐私拒绝或要求分析但分析失败的媒体一律不能成为 Hero；Hero 先满足故事 evidence ID 硬绑定，再按质量稳定排序。Secondary 结合质量、方向差异和焦点差异排序，输入与分数相同时保持原顺序，不产生随机抖动；无合格 Hero 时自动回退一句话/手札/留白等安全模板，照片最多只作辅助图。
- 实现（裁切与动态色板）：脸部矩形只进入 `CoverCropSafety`，渲染时以受保护区域约束实际 fill 偏移，预览与导出读取同一个焦点和矩形。色板从锁定 Hero 的 64×64 样本提取，先排除脸部区域、极亮/极暗离群点，再以 CIELAB 五簇确定主色并限制饱和度；纸色、墨色和次要墨色必须分别通过 4.5:1/3:1 对比度。分析结果、动态色板和裁切信息全部锁进同一个 `PreparedCoverRenderInput`；自定义背景、无图、无 Hero、分析或对比度失败时回退既有受控色板。
- 实现（交互流畅度与旧结果边界）：分享封面从播放最后一章开始预热；未完成时只在操作层显示非阻断准备反馈，不把加载态画进封面。样式切换复用已准备图片和分析结果，只同步重建小型 Fact/Recipe/Layout/Session，并立即发布匹配 context 的 Session，避免预览闪回“正在准备”；重复 `.task` 在相同 context 已有 Session 时直接返回。保存仍只消费锁定 `CoverShareSession`，不重新读取图片、不分析、不取色、不联网。照片键、payload revision、样式和背景共同约束 context，旧 context 通过提交前后双重 guard 拒绝反写。
- XCTest 与门禁：新增 `CoverMediaAnalysisTests.swift` 9 个用例，覆盖质量排序、旧输入稳定顺序、低像素/严重模糊/严重欠曝、裁切焦点和受保护区域夹紧、动态色板对比度、稳定身份缓存只执行一次、媒体 ID 色板重绑定及规则/像素缓存键；`CoverShareFlowTests` 新增分析失败降级、分析/色板锁定和错误 Hero 色板拒绝。PBX 复核 202 个 object 定义无重复，新生产/测试文件分别接入 App/Test Target；静态门禁锁定本机 Vision/Core Image、最大并发、缓存、取消、预热、零保存期分析、零网络和 `FLOW-75`。
- 修改/新增文件：`NativeDemoApp/CoverEngine/Analysis/CoverMediaAnalysis.swift`、`NativeDemoApp/CoverEngine/Models/CoverContracts.swift`、`NativeDemoApp/CoverEngine/Models/CoverRenderingContracts.swift`、`NativeDemoApp/CoverEngine/Flow/CoverShareFlow.swift`、`NativeDemoApp/CoverEngine/Flow/LegacyWeeklyCoverAdapter.swift`、`NativeDemoApp/CoverEngine/Templates/LaunchCoverTemplates.swift`、`NativeDemoApp/CoverEngine/Rendering/CoverCanvasRoot.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoAppTests/CoverMediaAnalysisTests.swift`、`NativeDemoAppTests/CoverShareFlowTests.swift`、`NativeDemoApp.xcodeproj/project.pbxproj`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- Windows 验证证据：`git diff --check` 通过；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过；`python scripts/validate_release_gate.py --phase windows` 完整通过并输出 `release_repository_gate: OK`。100/1,000/5,000 条确定性夹具、三张真实 12MP 夹具、生活语义、文案、主题、迁移、SQLite 与代理测试均保持通过，仅保留既有 5 条 soft copy warning。
- 冻结边界复核：未实现或调用 AI 导演，没有上传照片或新增网络请求，没有扩展其余 14 套模板、加入多样性冷却、实现完整 1.35 秒动效或退役旧渲染器；未修改账单、OCR、叙事事实/文案、播放章节、照片存储/引用、会员、额度、StoreKit、同步、TRACE、`PERF-AUDIT-04`、`ARCH-03` 或 20 张视觉基线 PNG。用户既有未跟踪素材、`tmp/` 与缓存目录未删除、覆盖、暂存或提交。
- 剩余风险与下一项：当前 Windows 没有 Swift、Xcode 或 iPhone；Vision 请求类型、Core Image bitmap、actor/Task cancellation、PBX 实际编译、全部 XCTest、真实人脸贴边裁切、动态色板像素、三张 12MP 峰值、低电量、20 次切换/保存、后台取消、VoiceOver、Reduce Motion 和 Instruments hitch/内存仍需按 `FLOW-75` 真机签收。完成前保持 `CODE_DONE`。下一项只能是 `SHARE-REBUILD-05` 可选 AI 导演，且仍为 `NOT_STARTED`；未获得新授权前不接网络、不启动 20 套扩展或旧渲染器退役。

---

## 58. SHARE-REBUILD-05：可选 AI 导演（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。用户已明确授权继续下一步；前五阶段仍等待 macOS/Xcode 与 iPhone 集中签收，本次完成不把它们提升为 `VERIFIED`。
- 允许范围：只新增可选 `AICoverDirector` 的脱敏请求/响应契约、首发六模板合法候选、服务器端受限 JSON Schema 与输出归一化、本地 Recipe 重建和最终 Validator；允许复用既有固定鉴权生产代理、联网整理总开关与远程调用额度，增加请求超时/取消、同键合并、轻量缓存、旧修订拒绝、尾章后台预热，以及对应 XCTest、代理测试、PBX 接线、静态门禁和真机矩阵。
- 必须证明：客户端只发送结构化长度/数量/方向/质量档位、匿名媒体别名和合法模板/色板/背景 ID，不发送照片、图片字节/引用、账本 UUID、evidence UUID、用户原文、故事正文、金额、商户、地点或自由 messages；AI 只能在前 3～5 个合法候选内选择，不输出正文、坐标、字体名、二维码或未登记 token。本地必须复核 schema/source revision/content fingerprint/candidate set/media role/事实绑定/隐私/重复/Footer/对比度/布局，任何超时、离线、未登录、额度不足、取消、非法响应或旧修订都静默使用已经完成的本地 Recipe。
- 交互与性能边界：不得在打开分享层、切模板、渲染 `body` 或保存时发请求；只允许在播放最后一章且本机图片分析完成后后台预热。分享层始终先有本地可用 Session，远程结果仅在用户尚未进入预览、未手动选样式且 context 仍一致时采用；预览打开后锁定同一 Session，保存零联网、零重新导演、零重新分析。请求有硬超时、可取消、同键缓存与旧结果双重拒绝，关闭页面不遗留可反写任务。
- 隐私与产品边界：AI 导演不是图片识别、文案生成器或开放式布局器；照片及本机 Vision/Core Image 结果中的脸部矩形、像素样本和颜色值不得上传。沿用现有用户主动开启的“联网整理”与登录边界，不新增默认开启开关、不新增客户端上游 Key、不改变会员权益、额度数值或计费语义。
- 冻结边界：本项不加入多样性冷却，不扩展其余 14 套模板，不实现完整 1.35 秒动效，不退役旧分享渲染器；不修改账单、OCR、叙事事实/文案、播放章节、照片存储/引用、会员、价格、额度规则、StoreKit、同步、TRACE、`PERF-AUDIT-04` 或 `ARCH-03`。20 张 PNG 继续只作视觉基线，不进入生产包。
- 工作区保护：启动前已重新执行 `git status --short`，记录并保留台账、PBX、两个分享入口、CoverEngine 01～04、测试、方案/提示词/验收文档、品牌素材、20 张位图、`tmp/`、缓存目录及全部用户未跟踪文件；本项不删除、不覆盖、不暂存、不提交相邻任务和用户素材。
- 验证计划：Swift XCTest 覆盖请求零正文/零 UUID/零图片字段、合法候选上限、严格响应、未知 token/媒体别名/越权 Hero/旧 revision 拒绝、合法 AI Recipe 通过全链路、非法响应本地降级、同键缓存与取消；Node 测试覆盖请求/响应 Schema、服务端重建 prompt、未知字段和越界 token 拒绝。静态门禁锁定固定代理、客户端无自由 messages/上游 model、渲染/切换/保存零请求，并新增离线、超时、快速开关、最后一章预热、预览锁定、20 次切换/保存和抓包零照片的 `FLOW-76`。Windows 运行 `git diff --check`、专项 Node 测试、体验静态门禁和完整发布门禁；当前无 Swift/Xcode/iPhone，完成后最多标记 `CODE_DONE`。
- 实现（闭合 AI 契约）：新增 `AICoverDirector` 请求工厂、严格响应解码、Validator、轻量 Decision 缓存与协调 actor；请求仅包含结构化数量/长度/方向/质量档位、匿名 `M1`～`M7` 和本地已批准 token。固定鉴权代理只注册 `cover_director`，在服务端验证闭合请求后重建 prompt，并用闭合 JSON Schema、枚举和证据绑定再次归一化响应；客户端没有自由 messages、上游 model 或 API Key。AI 只选择首发六模板的合法 Recipe 参数，正文、坐标、字体、Footer 与最终 SwiftUI 布局继续全部由本地契约引擎拥有。
- 实现（最终否决与完整降级）：本地逐项复核 schema、revision、周期/内容指纹、候选模板、variant、色板、背景、动画、seed、置信度、reason、媒体别名、唯一角色、Hero 资格及故事证据绑定，并新增模板最小媒体数约束，明确拒绝只给一张图的杂志版面。`LegacyWeeklyCoverAdapter` 只把仍匹配当前 FactPack 与媒体映射的 Decision 重建为 `.ai` Recipe；任何非法、过期、未知或布局/隐私/重复/Footer/对比度校验失败都回到已经完成的完整本地 Recipe，而不是半成品 AI 配方。
- 实现（取消、额度与交互流畅度）：AI 只在播放最后一章且本机图片准备和分析完成后预热；分享层打开、手动切模板、`body` 渲染和保存均不发请求。协调器对同 key 只保留一个 8 秒请求，不同 key 取消旧任务；关闭页面、进入预览或手动选择会拒绝迟到结果。预览前只接纳 context 仍一致的 Decision，预览打开后 Session 不被远程结果替换，手动模板优先，保存直接消费锁定的 export RenderInput。缓存读取也必须重新通过当前联网开关、登录、额度与媒体映射边界；同键多个等待者只发布一次并只扣一次额度，请求期间额度耗尽则放弃远程结果并保持本地 Session。
- 修改/新增文件：`NativeDemoApp/CoverEngine/Director/AICoverDirector.swift`、`NativeDemoApp/CoverEngine/Flow/LegacyWeeklyCoverAdapter.swift`、`NativeDemoApp/Services/AIReportService.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/CoverAIDirectorTests.swift`、`ai-proxy/coverDirectorContract.js`、`ai-proxy/coverDirectorContract.test.js`、`ai-proxy/aiFeaturePolicy.js`、`ai-proxy/server.js`、`ai-proxy/.env.example`、`ai-proxy/README.md`、`backend/src/server.js`、`backend/README.md`、`NativeDemoApp.xcodeproj/project.pbxproj`、`AI_CAPABILITY_CONTRACT_v1.md`、`scripts/ai_capability_lint.py`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 自动回归与工程接线：新增 7 个 Swift XCTest，覆盖脱敏请求、严格附加字段拒绝、旧 revision/未知 token/媒体别名拒绝、杂志版面最少两图、合法 AI 全链路、旧 Decision 完整本地降级和 24 项有界缓存；代理合同测试 17/17 通过。新生产/测试文件分别接入 App/Test Target，PBX 新 object 定义无重复；静态门禁已锁定固定代理、服务端 prompt/Schema、8 秒客户端超时、9 秒 backend 跳转边界、尾章预热、手动选择/预览锁定、保存零 AI、隐私/降级/缓存/全渲染测试接线及 `FLOW-76`。
- Windows 验证证据：`npm test`（`ai-proxy`）17/17、`python scripts/ai_capability_lint.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终输出 `release_repository_gate: OK`；100/1,000/5,000 条确定性夹具、三张真实 12MP 夹具、生活语义、文案、主题、迁移、SQLite 与代理测试均通过。`git diff --check` 无 whitespace error，仅报告既有工作区的 LF→CRLF 提示；copy lint 仍只有既有 5 条 soft warning。
- 冻结边界与工作区保护：未加入多样性冷却、其余 14 套、完整 1.35 秒动效或旧渲染器退役；未修改账单、OCR、叙事事实/文案、播放章节、照片存储/引用、会员、价格、额度数值、StoreKit、同步、TRACE、`PERF-AUDIT-04` 或 `ARCH-03`。20 张 PNG 继续只作视觉验收基线；用户现有脏改动、未跟踪素材、`brand-assets/`、`output/`、`tmp/` 与缓存目录均未删除、覆盖、暂存、提交或推送。
- 剩余风险与下一项：当前 Windows 环境没有 Swift、Xcode 或 iPhone，actor/TaskGroup 严格并发、URLSession 取消、Swift 类型推断、PBX 实际编译、全部 XCTest，以及未登录/额度耗尽/离线/8 秒超时/迟到响应/快速开关/预览锁定/连续 20 次切换与保存/抓包零照片/VoiceOver/Reduce Motion/低电量仍需按 `FLOW-76` 在 macOS 和真机签收；签收前保持 `CODE_DONE`。下一项只能是 `SHARE-REBUILD-06`，但本轮不启动；`PERF-AUDIT-04` 与 `ARCH-03` 继续保持 `NOT_STARTED`。

---

## 59. SHARE-REBUILD-06：扩展至 20 套并准备退役旧分享实现（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。用户已明确要求继续下一步；`SHARE-REBUILD-01`～`SHARE-REBUILD-06` 现均为 `CODE_DONE`，不冒充已完成 macOS/Xcode 或真机签收。
- 允许范围：只补齐 `memoryFocus`、`film`、`postcard`、`scrapbook`、`editorial`、`memoryWall`、`travelNote`、`bookCover`、`natureDiary`、`coffeeStory`、`warmHome`、`nightStory`、`ocean`、`quietEditorial` 的模板描述、资格门槛、内容分配、媒体角色、布局、受控装饰、色板/背景 token、手动选择入口、AI 合法候选、XCTest、静态门禁与真机矩阵；允许把分享选择状态从旧视觉样式映射收敛到新模板 ID，但不得改变事实来源或图片隐私规则。
- 必须证明：20 个模板 ID 均有唯一描述、明确的 0～7 图门槛、最大渲染图数、Hero 证据要求、长文上限与确定性 fallback；4 张以上只能使用有明确 Hero 的非对称叠放、masonry 或胶片节奏，不能等大宫格。模板体仍只能读取 `ResolvedCoverLayout`，不能读取原始 payload、重新选文案或自行渲染 Footer；指标继续只在根 Footer 出现一次，无图不出现占位提示。
- 交互与性能边界：最后一章预热、图片分析缓存、AI 取消/超时、预览 Session 锁定和保存同源规则保持不变。快速切换只同步重建小型 Recipe/Layout 并复用已准备图片、分析和色板，不重新读取照片、不重新分析、不发 AI 请求；当前选择因图片数或证据变化而失效时必须确定性回到合法模板，旧 context 不得反写。选择器在窄屏、横向滚动、Dynamic Type、VoiceOver 与 Reduce Motion 下不得遮挡、跳动或形成无法点击的状态。
- 退役门槛：本轮 Windows 代码阶段不得直接删除 `WeeklyStoryShareCardView`、`WeeklyShareCardView`、旧 Footer 或旧样式枚举。只有 App/Test Target 在 Xcode 全量编译与 XCTest 通过，并在 iPhone 完成 20 模板像素、0/1/2/3/4/7 图、长文、窄屏、主题、VoiceOver、Reduce Motion、快速切换 20 次、连续保存 20 次和两个旧入口路由矩阵后，才能单独执行删除；删除前必须确认无生产引用并提供回滚点。
- 冻结边界：不新增开放式 AI 文案/坐标/字体输出，不上传图片、脸框、色样或账本标识，不修改账单、OCR、叙事事实/文案、播放章节、照片存储/引用、会员、价格、额度、StoreKit、同步、TRACE、`PERF-AUDIT-04` 或 `ARCH-03`；不实现方案外的复杂 3D 动效或多样性冷却。20 张 PNG 只作视觉基线，不进入生产包。
- 工作区保护：启动前已复核并保留台账、PBX、两个分享入口、CoverEngine 01～05、测试、代理/backend、方案/提示词/验收文档、品牌素材、20 张位图、`output/`、`tmp/`、缓存目录及全部用户未跟踪文件；本项不删除、不覆盖、不暂存、不提交相邻任务和用户素材。
- 验证计划：新增目录完整性、每模板资格边界、0～7 图、Hero/辅助角色、长文 fallback、所有 frame 位于 540×960 且不侵入唯一 Footer、媒体 frame 不重叠为等大网格、预览/导出同源与失效选择回退 XCTest；静态门禁锁定 20 个 descriptor/布局/选择入口、模板无 Footer、切换/保存零 IO/分析/AI，并新增 `FLOW-77`。Windows 运行 `git diff --check`、体验静态门禁与完整发布门禁；当前环境无 Swift/Xcode/iPhone，最多标记 `CODE_DONE`，旧实现退役保持待真机签收。
- 完成范围与文件：统一目录现覆盖 20 个 `CoverTemplateID`、20 份能力描述、确定性手动/自动资格、0～7 图上限、14 套新增内容分配/媒体 Recipe/布局/受控装饰、`bookCover` portrait Hero、AI 候选与 Node 闭集 Schema；本项核对并收口 `NativeDemoApp/CoverEngine/Models/CoverContracts.swift`、`Templates/LaunchCoverTemplates.swift`、`Rendering/CoverCanvasRoot.swift`、`Flow/LegacyWeeklyCoverAdapter.swift`、`Director/AICoverDirector.swift`、`Views/SummaryPlaybackSheet.swift`、`NativeDemoAppTests/LaunchCoverTemplateTests.swift`、`ai-proxy/coverDirectorContract.js`、`ai-proxy/coverDirectorContract.test.js`、`scripts/experience_static_check.ps1` 与 `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`。20 张验收 PNG 仍未进入生产包。
- 边界与交互修正：全量 frame 审计发现 `film` 第四张辅助图面积大于原 Hero，已只把该模板 Hero 从 `300×224` 调整为 `300×272`，使 Hero 严格大于每张辅助图；通用 `arrangedMedia` 在槽位不足时不再复用 Hero frame，而是让后续 `mediaLayoutMismatch` 本地契约拒绝非法 Recipe。选择器使用 `ViewThatFits`、横向 view-aligned 滚动、Dynamic Type 多行卡片、VoiceOver 名称/说明/选中值和 Reduce Motion 无弹簧位移；手动切换仍只同步重建小型 Recipe/Layout，复用锁定图片/分析/色板并只取消待决 AI，不启动图片 IO、分析或新 AI。图片/证据变化使当前模板失效时继续确定性回到合法自动模板，旧 request/context/revision 不能反写。
- 契约与回归：`LaunchCoverTemplateTests` 已改为 20 套契约，覆盖目录/名称/描述完整性、显式与旧 ID 映射、0～7 图手动资格、自动场景候选与手动目录分离、Recipe 媒体上限/角色、无图、收据/secondary-only、长文 fallback、时间线日数、20 个唯一布局签名、Atom/Allocation/Layout/Recipe/准备图片集合一致、540×960 与 `y = 872` Footer 边界、4+ 图非等大、Hero 面积层级、唯一 Footer 指标和 `bookCover` portrait。Node 新增 20 枚举、20 请求/响应、`memoryWall` 4～6、`quietEditorial` decoration-only、`bookCover` portrait、`media-6` 合法/`media-7` 非法测试，并清理重复 `sunset` token。静态门禁同时锁定模板体无 Footer、根 Footer 唯一、切换/保存零 IO/分析/AI，以及 `LifeSliceShareCardStyle`、`WeeklyStoryShareCardView`、`WeeklyShareCardView` 继续保留。
- Windows 验证证据：Swift/Node 20 套 `minimumMediaCount`、`maximumMediaCount`、`requiresHero`、`allowsHero`、`allowsDecoration` 一次性逐项对表为 `OK`；`node --test ai-proxy/coverDirectorContract.test.js` 为 12/12 通过；`git diff --check` 通过，仅有既存 LF/CRLF 提示；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过并执行完整 Node 23/23；`python scripts/validate_release_gate.py --phase windows` 通过，`release_repository_gate: OK`、`Static experience checks passed`、`Copy experience checks passed`，100/1,000/5,000 夹具及三张真实照片夹具摘要保持一致。Windows 不具备 UIKit/Xcode，新增 Swift XCTest 仅完成代码与工程静态接线，未声称实跑。
- 剩余风险与下一项：`FLOW-77` 保持 `NOT_RUN`；仍需在 macOS 对 App/Test Target 全量编译并运行全部 XCTest，再在 iPhone 依次完成 `FLOW-73`～`FLOW-77`，重点签收 20 套像素、0/1/2/3/4/7 图、长文、横竖方图、收据/低质/无 Hero、窄屏、Dynamic Type、VoiceOver、Reduce Motion、20 次快速切换、20 次连续保存、1080×1920 预览/导出一致、零重复 Footer/指标、零切换期 IO/分析/AI及 Instruments hitch/内存。上述全量通过前不得删除旧实现；通过后下一项才是单独建立旧分享实现退役步骤、确认零生产引用并保留可回滚点。`PERF-AUDIT-04` 与 `ARCH-03` 继续保持 `NOT_STARTED`。
- 交付说明：2026-07-24 用户明确授权在 Windows 全仓门禁与交互边界自检通过、但本机无 `xcodebuild`/Swift/iPhone 的前提下，将本项 `CODE_DONE` 源码提交并推送至 `feature/xuzhangapp-staging`，后续由用户通过 TestFlight 执行真实编译与 `FLOW-73`～`FLOW-77` 签收。此次授权不把状态提升为 `VERIFIED`，也不放宽旧分享实现退役门槛。

---

## 60. SHARE-FIX-01：封面稳定标识字符串插值编译修复（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 问题与范围：TestFlight/Xcode 编译报告 `LaunchCoverTemplates.swift:935` 与 `LegacyWeeklyCoverAdapter.swift:162` 的多行数组函数调用位于字符串插值内时出现括号匹配、未终止字符串和连续语句解析错误。本项只把两处 `CoverStableIdentity.fingerprint(...)` 提前计算为局部常量，再以单一值完成字符串插值；不得改变 fingerprint 输入顺序、Recipe/Layout ID、模板资格、布局、交互、AI、图片、Footer 或分享路由。
- 工作区保护：保留 `brand-assets/`、`output/`、`tmp/`、缓存目录及全部用户未跟踪文件；不清理、不覆盖、不暂存相邻任务或素材。
- 修改文件与结果：`NativeDemoApp/CoverEngine/Templates/LaunchCoverTemplates.swift` 新增局部 `layoutFingerprint`，`NativeDemoApp/CoverEngine/Flow/LegacyWeeklyCoverAdapter.swift` 新增局部 `recipeFingerprint`；两处原有输入、输入顺序、稳定哈希函数及 `layout.launch.` / `cover.launch.` 前缀均保持不变，最终 ID 语义不变。生产目录已扫描，无 `CoverStableIdentity.fingerprint([` 多行调用继续直接位于字符串插值内。
- 验证证据：`git diff --check` 通过，仅有既有 LF→CRLF 提示；`node --test ai-proxy/coverDirectorContract.test.js` 12/12 通过；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过并执行 Node 23/23；`python scripts/validate_release_gate.py --phase windows` 通过，最终输出 `release_repository_gate: OK`、`Static experience checks passed`、`Copy experience checks passed`，100/1,000/5,000 条确定性夹具和三张 12MP 图片夹具摘要保持一致。
- 剩余风险与下一项：当前 Windows 没有 Swift/Xcode，仍需用户重新触发 Xcode/TestFlight 编译，以确认 Apple Swift 编译器已接受两处改写；通过后继续既定 `FLOW-73`～`FLOW-77` 真机签收。不得据此删除旧分享实现，也不启动 `PERF-AUDIT-04` 或 `ARCH-03`。

---

## 61. SHARE-FIX-02：封面适配器类型推断与保存提示字段编译修复（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 问题与范围：Xcode/TestFlight 继续报告 `LegacyWeeklyCoverAdapter.swift:101/123/129/138/199/200/205` 的 Optional 泛型、同名函数遮蔽、成员和 key path 类型推断错误，以及 `SummaryPlaybackSheet.swift:2941/2942` 读取 `PreparedCoverRenderInput` 不存在的 `unavailablePhotoCount`。本项只补足静态类型、消除 `mediaRecipes` 同名调用歧义、把含糊 key path 改为等价显式闭包，并读取契约中真实存在的 `unavailableMediaCount`；不得改变决策接受条件、模板/媒体选择、Recipe、Footer、保存交互或提示语义。
- 工作区保护：保留 `brand-assets/`、`output/`、`tmp/`、缓存目录及全部用户未跟踪文件；不清理、不覆盖、不暂存相邻任务或素材。
- 修改文件与结果：`NativeDemoApp/CoverEngine/Flow/LegacyWeeklyCoverAdapter.swift` 用显式 `if/else` 接纳分支替代需要推断泛型返回值的 Optional `flatMap`，为 AI 决策与媒体 Recipe 数组补充明确类型，通过 `Self.mediaRecipes(...)` 消除局部数组对同名静态函数的遮蔽，把媒体 ID、Hero 角色及内容原子 ID 投影改为有明确参数类型的闭包；`NativeDemoApp/Views/SummaryPlaybackSheet.swift` 把保存结果提示读取从不存在的 `unavailablePhotoCount` 对齐到 `PreparedCoverRenderInput.unavailableMediaCount`。决策校验、媒体顺序与角色、Recipe 内容、Footer 及用户可见文案均未改变。
- 验证证据：已逐项对照 `CoverAIDirectorDecision`、`MediaPlacementRecipe`、`MediaRole`、`ContentAllocationPlan` 与 `PreparedCoverRenderInput` 声明，并扫描确认报错表达式和 `renderInput.unavailablePhotoCount` 无残留；`git diff --check` 通过，仅有既有 LF→CRLF 提示；`node --test ai-proxy/coverDirectorContract.test.js` 12/12 通过；体验静态门禁通过并执行 Node 23/23；`python scripts/validate_release_gate.py --phase windows` 通过，最终输出 `release_repository_gate: OK`、`Static experience checks passed`、`Copy experience checks passed`，100/1,000/5,000 条确定性夹具和三张 12MP 图片夹具摘要保持一致。
- 剩余风险与下一项：Windows 无 Swift/Xcode，以上类型修复仍需 TestFlight/Xcode 重新编译确认；编译通过后继续既定 `FLOW-73`～`FLOW-77` 真机签收。不得据此删除旧分享实现，也不启动 `PERF-AUDIT-04` 或 `ARCH-03`。

---

## 62. TRACE-FIX-01：痕迹页固定页签无限高度真机回归（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无本项 `IN_PROGRESS`。真机截图已定位并完成定向修复，等待新 TestFlight 包复验，不标记 `VERIFIED`。
- 真机证据与根因：TestFlight 截图显示“生活/线索”固定页签占据接近半屏，范围控件、内容及加载卡整体被下推。`a261f39` 把页签从纵向 ScrollView 移入 GeometryReader 下的固定 VStack 后，`traceViewModeTab` 仍使用 `.frame(maxWidth: .infinity, maxHeight: .infinity)`，父 HStack 又只有 `minHeight: 44`，因此在有界垂直空间内发生无限高度扩张；这是布局回归，不是数据计算耗时造成。
- 允许范围：只把模式页签及按钮的垂直尺寸收紧为明确的 44pt 触控高度，并增加防回流静态检查；保留固定控件、范围状态、精确快照、加载延迟、旧内容交互阻断、滚动锚点、Dynamic Type、VoiceOver 与 Reduce Motion 语义。
- 冻结边界：不重构痕迹内容、不修改周/月/线索计算、缓存键、分享、图片加载、账本、会员、额度、AI、同步、`PERF-AUDIT-04` 或 `ARCH-03`。
- 工作区保护：保留 `brand-assets/`、`output/`、`tmp/`、缓存目录及全部用户未跟踪文件；不清理、不覆盖、不暂存相邻任务或素材。
- 修改文件与结果：`NativeDemoApp/Views/StatsWebView.swift` 把模式页签 HStack 从无上限的 `minHeight` 收紧为明确 44pt，并移除按钮标签的 `maxHeight: .infinity`、保持 44pt 触控高度；`scripts/experience_static_check.ps1` 新增固定控件高度与禁止无限垂直请求的防回流检查。生活/线索、周/月范围、加载覆盖、内容计算与滚动状态均未改。
- 验证证据：定向多行扫描确认 `traceViewModeTab` 范围内无 `maxHeight: .infinity`；体验静态门禁通过并新增两项 `OK`；`git diff --check` 通过，仅有既有 LF→CRLF 提示；`python scripts/validate_release_gate.py --phase windows` 通过，最终输出 `release_repository_gate: OK`、`Static experience checks passed`、`Copy experience checks passed`，100/1,000/5,000 条夹具和三张 12MP 图片夹具摘要保持一致。
- 剩余风险与下一项：Windows 无 SwiftUI/iPhone，44pt 固定页签仍需新 TestFlight 包对生活/线索、本周/本月、连续快速切换、Dynamic Type 和旋转/窄屏复验；重点确认线索模式顶部总高不再超过单行页签加内边距，生活模式只多一行 44pt 范围控件，加载卡始终位于剩余内容区。加载层继续遵循既有“无匹配快照时阻断、已有匹配内容时保留”的冻结规则。本项未修改痕迹数据、快照、滚动或内容卡；复验前保持 `CODE_DONE`。

---

## 63. SHARE-FIX-03：自动导演有安全照片却生成零媒体封面（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。Windows 代码、代理契约、静态与完整发布门禁已通过；等待 Xcode/XCTest 与新 TestFlight 包真机复验，不标记 `VERIFIED`。
- 真机证据与根因：TestFlight 分享图 Footer 明确显示“3 张照片”，成品却为零图片的“生活手札”。Footer 数量来自适配器已解码且隐私安全的 `safeMedia`，本地 `LaunchCoverTemplateCatalog.mediaRecipes` 对生活手札本会选择最多两张 secondary；只有已接受 AI Decision 的路径会直接采用 `decision.mediaSelections`。当前闭合契约允许在 `mediaCandidates` 非空时返回空 `mediaRoles`，因此 AI 的零媒体决定覆盖了完整本地配方。照片 `qualityScore` 只用于合格候选排序；Hero 还需证据绑定及清晰度/曝光/分辨率/裁切安全硬门槛，但这些规则不应让所有安全 secondary 照片消失。
- 允许范围：只新增“自动 AI 请求存在安全媒体候选时，响应至少选择一张已批准媒体”的客户端严格校验、服务端闭合契约校验、适配器最终防线与回归测试；非法零媒体 Decision 必须完整回退到已完成的本地 Recipe。手动模板仍由本地目录规则决定，零照片输入继续合法。
- 冻结边界：不降低 Hero 隐私/质量/证据门槛，不上传照片、色样或标识，不改变价值分、叙事事实、模板布局、Footer 指标、会员、额度、计费、保存交互、痕迹页、旧分享退役、`PERF-AUDIT-04` 或 `ARCH-03`。
- 工作区保护：保留前一已完成痕迹修复及 `brand-assets/`、`output/`、`tmp/`、缓存目录和全部用户未跟踪文件；不清理、不覆盖、不暂存相邻任务或素材。
- 验证计划：Swift XCTest 覆盖有媒体候选时零媒体响应拒绝、适配器本地完整回退及真正零照片继续合法；Node 契约测试覆盖同一边界；静态门禁锁定客户端、服务端和适配器三层防线。运行专项 Node、`git diff --check`、体验静态门禁及完整 Windows 发布门禁；最终由 TestFlight 确认三张安全照片默认至少使用一张。
- 修改文件与结果：`NativeDemoApp/CoverEngine/Director/AICoverDirector.swift` 在客户端严格 Validator 中拒绝“安全媒体候选非空但 `mediaRoles` 为空”的响应；`NativeDemoApp/CoverEngine/Flow/LegacyWeeklyCoverAdapter.swift` 在接受 AI Decision 前增加同一最终防线，非法结果完整回退本地 Recipe；`ai-proxy/coverDirectorContract.js` 在服务端归一化阶段拒绝同类响应，并在固定 prompt 中明确 Hero 不合格时仍须选择 secondary/decoration。`NativeDemoAppTests/CoverAIDirectorTests.swift` 与 `ai-proxy/coverDirectorContract.test.js` 同时覆盖有安全照片时拒绝零媒体及真正无照片仍允许纯文字封面；`scripts/experience_static_check.ps1` 锁定客户端、适配器和代理三层规则。未改变质量分、Hero 证据/隐私门槛、模板布局、Footer 或零照片语义。
- 验证证据：`node --test ai-proxy/coverDirectorContract.test.js` 13/13 通过；`npm test`（`ai-proxy`）24/24 通过；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过；`python scripts/validate_release_gate.py --phase windows` 完整通过并输出 `release_repository_gate: OK`、`Static experience checks passed`、`Copy experience checks passed`；`git diff --check` 无 whitespace error，仅有工作区既有 LF→CRLF 提示。Windows 没有 Swift/Xcode，新增 Swift XCTest 已完成工程接线与静态复核但未冒充实跑。
- 剩余风险与下一项：新 TestFlight 包必须用“3 张安全照片”验证自动封面至少使用 1 张；Hero 若未过清晰度、曝光、分辨率、裁切或证据绑定门槛，照片应降为 secondary/decoration，而不是全部消失；真正零照片输入仍应生成纯文字封面。通过前保持 `CODE_DONE`，不得降低 Hero 安全门槛、退役旧分享实现或启动 `PERF-AUDIT-04`、`ARCH-03`。

---

## 64. TRACE-FIX-02：痕迹模式归一化、预热身份与重复深链定向修复（2026-07-24）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无本项 `IN_PROGRESS`。Windows 代码、状态回归、静态与完整发布门禁已通过；缺 macOS/Xcode 编译、XCTest 实跑及 iPhone `FLOW-72` 复验，不标记 `VERIFIED`。
- 真机复盘与优先级：`TRACE-FIX-01` 已修复固定页签无限高度，但对 2026-07-24 痕迹改动逐段复审后确认两个 P1 与一个 P2。P1：线索页处于自定义日期或本年时只切换 `viewMode`，生活页的严格可见性条件持续拒绝快照，计算结束后可能只剩骨架；周/月预热 Key 继续读取当前全局 `selectedPeriod/useCustomRange`，预热另一周期所得身份在真正切换后失效。P2：外部深链再次定位同一 `trace-life-card` 时，相同 `scrollAnchorID` 赋值可能不产生新的 SwiftUI 滚动命令。
- 允许范围：只允许在进入生活模式时把共享筛选状态归一到既有 `traceLifeCardRange`；让生活章节的缓存身份与计算选项只由请求的周/月范围决定；重复深链在目标锚点已相同时先无动画清空、让出一帧并再次校验意图后重设目标；补充纯策略 XCTest、静态防回流与 `FLOW-72` 验收说明。允许更新 `StatsTraceModels.swift`、`StatsWebView.swift`、`StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 冻结边界：不实施完整 `TRACE-RECOVERY-02` 的按 Key 快照容器、同 Key 请求合并或局部 Loading 重构；不修改线索/叙事/公共交通算法与文案、生活卡内容、照片、分享、账单、会员、额度、StoreKit、同步、`PERF-AUDIT-04` 或 `ARCH-03`。保留现有 latest-wins、固定顶部控件、精确快照可见性、普通切换不命令滚动和外部深链才定位的边界。
- 工作区保护：保留 `brand-assets/`、`output/`、`tmp/`、缓存目录及全部未跟踪素材；不删除、不覆盖、不暂存或提交相邻任务和用户文件。
- 修改文件与结果：`NativeDemoApp/Views/StatsTraceModels.swift` 新增唯一生活卡锚点与重复锚点判断策略，生活章节 Key 升级为 `chapter-v3` 并移除线索专属 `selectedPeriod/useCustomRange`，`StatsTabState.selectViewMode` 只在进入生活时恢复既有 `lifeCardRange` 对应的周/月并关闭自定义范围面板；进入线索本身不改写现有范围。`NativeDemoApp/Views/StatsWebView.swift` 的生活章节准备、同步兜底构建与缓存身份现都只消费请求的 `range`，本月才提升重复印记且周/月都允许回声锚点；模式按钮统一走归一化状态转移。外部深链再次命中同一生活卡锚点时，无动画置空、`Task.yield()`，再次校验任务未取消、待定位范围、模式、范围、预设状态和真实快照后才重发目标；普通模式/范围切换仍只取消意图，不命令滚动。
- 回归与交互边界：`NativeDemoAppTests/StateRegressionTests.swift` 补充自定义日期与本年进入生活的归一化、进入线索不误改范围、`chapter-v3` 随范围/账本/会员/内容修订失效，以及相同/不同/空锚点重发策略覆盖；`scripts/experience_static_check.ps1` 锁定上述状态、Key、计算选项和 `nil → yield → revalidate → target` 顺序；`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 的 `FLOW-72` 增加自定义日期/本年返回、预热快照直接复用、同一深链重复进入、让帧期间改选范围、Reduce Motion 与主线程 hitch 边界。未修改线索/叙事/公共交通算法与文案、生活卡内容、固定顶部控件、精确快照可见性、latest-wins、照片、分享、账单、会员、额度、StoreKit 或同步。
- Windows 验证证据：生产与测试目录已扫描，所有 `chapterKey` 调用均使用新签名，无旧 `selectedPeriod/usesCustomRange` 参数残留；`git diff --check` 通过，仅有工作区既有 LF→CRLF 提示；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过并新增 8 项定向守卫，完整 Node 24/24 同时通过；`python scripts/validate_release_gate.py --phase windows` 通过，最终输出 `release_repository_gate: OK`、`Static experience checks passed`、`Copy experience checks passed`，100/1,000/5,000 条确定性夹具与三张真实 12MP 图片夹具摘要保持一致。当前 Windows 的 `swift`、`swiftc`、`xcodebuild` 均不可用，未冒充执行 Swift 编译或 XCTest。
- 剩余风险与下一项：新 TestFlight 包先执行 `FLOW-72`：分别从自定义日期和本年线索返回此前本周/本月生活，确认无长期骨架；等待另一周期预热完成后直接切换，确认不重复整理、不闪 Loading；手动滚离生活卡后连续两次触发同一周/月外部入口，确认每次只定位一次；在锚点让帧期间改选范围，确认旧任务不会拉回；连续切换 20 次并覆盖特大字号、VoiceOver、Reduce Motion、灵动岛/刘海屏和 Instruments `>100ms` hitch。Xcode Debug/Release 编译、全部 XCTest 与上述真机检查通过前保持 `CODE_DONE`，下一步只做该 TestFlight 签收或由其证据触发的单问题定向修复，不启动 `PERF-AUDIT-04`、`ARCH-03` 或其他相邻任务。
- 交付授权：2026-07-24 用户明确要求把本项受控源码提交并推送至当前 `feature/xuzhangapp-staging`，随后通过 TestFlight 执行 `FLOW-72` 真机签收；此次授权不把 Windows 结果冒充 Xcode/iPhone 验证，也不包含工作区未跟踪素材或任何相邻任务。

---

## 65. 2026-07-27 TestFlight 五项定向优化队列

- 用户授权：除“第五个问题：首页动线/两个按钮”外，对本轮其余真机问题按风险优先级开始优化。首页动态主动作、免费每日 3 次/会员不限、播放开始扣次与 80% 完成签名等现有规则全部冻结，用户继续单独测试。
- 固定顺序：`PLAYBACK-FIX-03` → `SHARE-FIX-04` → `OCR-FIX-01` → `PLAYBACK-FACT-FIX-01` → `COPY-FIX-03`。五项必须独立进入 `IN_PROGRESS`，前一项达到 `CODE_DONE` 并回填验证后才能开始下一项；任何时刻只允许一个 `IN_PROGRESS`。

| 顺序 | ID | 优先级 | 问题 | 状态 |
|---:|---|---|---|---|
| 1 | PLAYBACK-FIX-03 | P0 | 周/月播放完成页切后台再回来偶发卡顿或崩溃 | `CODE_DONE` |
| 2 | SHARE-FIX-04 | P0 | 安全照片已进入封面事实包，但统一根渲染器把图片裁成不可见 | `CODE_DONE` |
| 3 | OCR-FIX-01 | P1 | 无日期支付截图中的金额 `¥4.20` 被误识别为 4 月 20 日 | `CODE_DONE` |
| 4 | PLAYBACK-FACT-FIX-01 | P1 | 首页已识别的凌晨下班路未稳定进入周播放，也未消费专用文案 | `CODE_DONE` |
| 5 | COPY-FIX-03 | P1 | 餐饮标签重复，并在无具体食物证据时声称“热食/热乎” | `CODE_DONE` |

### PLAYBACK-FIX-03 启动记录

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 真机现象：周/月播放停留在完成页时切出 App，再切回前台有概率卡顿或崩溃；当前尚无 crash/Jetsam 日志，先按代码中可证实的资源生命周期风险定向修复，不把推测冒充最终崩溃结论。
- 已确认风险链：`SummaryPlaybackSheet` 没有消费 `scenePhase`；完成页仍运行 8fps `TimelineView + Canvas`，并同时预热最长边 2880px 的分享图片、Vision/Core Image 分析与可选 AI 导演。进入后台不会触发 `onDisappear`，上述任务与大图可能继续存在；回前台时动态 Canvas、分析和远端结果同时恢复，形成 CPU/内存峰值。
- 允许范围：只为播放 Sheet 增加 active/inactive/background 生命周期策略；非 active 时暂停播放和动态背景、取消并释放未完成封面准备/分析/AI 预热与保存任务；active 后按原上下文幂等恢复，仅在中断前确实播放且尚未完成时续播。增加纯策略 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不修改播放章节、顺序、时长、正文、照片选择、封面资格/模板/Footer、完成判定、额度/扣次、会员、保存结果、首页动线、账本、同步、主题、`PERF-AUDIT-04` 或 `ARCH-03`；不通过降低图片质量或关闭合法分享能力掩盖问题。
- 验收：完成页前后台往返 20 次时后台零动态帧、零图片解码/分析、零 AI 请求反写；回前台最多启动一轮匹配当前 context 的准备。播放中切后台只在原本播放时续播，用户手动暂停不自动恢复；完成页不重播。内存可释放的准备图片在后台清空，预览/保存仍同源；Xcode/iPhone crash/Jetsam 与 Instruments 签收前最多标记 `CODE_DONE`。
- 工作区保护：分支 `feature/xuzhangapp-staging`，基线 `de133c7`；当前仅有用户未跟踪的 `brand-assets/`、`output/`、`tmp/` 与 `scripts/__pycache__/`，全部保留，不删除、不覆盖、不暂存。

### PLAYBACK-FIX-03 完成记录

- 状态：`IN_PROGRESS` → `CODE_DONE`；代码层修复与 Windows 门禁完成，真机 crash/Jetsam 签收前不标记 `VERIFIED`。
- 实现与文件：`NativeDemoApp/Views/SummaryPlaybackSheet.swift` 统一消费 `scenePhase`；inactive/background 时暂停播放与 8fps 动态 Canvas，取消播放、保存、图片准备/分析及 AI 导演任务，释放已准备大图、Session 和 Director 输入/决策；active 后先使旧 AI 请求失效，再只为当前 context 恢复一轮封面预热，且只恢复中断前确实在播放、尚未完成的会话。`NativeDemoAppTests/StateRegressionTests.swift` 增加恢复与预热纯策略测试；`scripts/experience_static_check.ps1` 增加生命周期接线守卫；`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 增加 `FLOW-78`。
- Windows 验证证据：`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py` 和 `python scripts/validate_release_gate.py --phase windows` 全部通过；最终输出 `release_repository_gate: OK`，确定性 100/1,000/5,000 条迁移夹具与三张真实 12MP 图片夹具保持通过。Windows 无 Swift/Xcode/iPhone，未冒充执行编译、XCTest 或真机验证。
- 剩余风险：新 TestFlight 包必须执行 `FLOW-78`，覆盖播放中、手动暂停、完成页及图片解码、Vision/Core Image、AI 请求中前后台往返 20 次，并检查 crash/Jetsam、Memory Graph、持续内存和主线程 hitch；若仍崩溃，以日志堆栈为准继续定向定位。

### SHARE-FIX-04 启动记录

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 已确认根因：`NativeDemoApp/CoverEngine/Rendering/CoverCanvasRoot.swift` 已在图片槽内部按 `placement.frame` 裁切，但图片层偏移后又被全局 `.clipped()` 按原始局部边界裁剪；当槽位 `y` 偏移较大时，合格照片虽已进入 `PreparedCoverRenderInput`，最终仍会被完全裁成不可见。此问题与照片价值分、AI 导演或模板资格无关。
- 允许范围：只纠正统一根渲染器的图片槽定位/裁切坐标系，补充渲染结构守卫与导出/像素级可见性回归覆盖；保持预览与保存消费同一锁定输入。
- 冻结边界：不修改事实包、照片质量评分、Hero/辅助图分配、隐私规则、模板资格、Footer、文案、AI 导演、旧分享入口、首页动线或其他视觉布局；不通过取消槽内裁切导致图片溢出正文或 Footer。
- 验收：有安全合格照片时首发 6 套的 Hero/辅助图片按 Recipe 槽位可见且仍在 frame 内裁切，不进入 `y >= 872` Footer；无图、不可用图、隐私拒绝仍安全降级。540×960 预览与 1080×1920 导出同源，快速切换和连续保存不触发新图片 IO/分析/AI，也无空槽、图片溢出或旧上下文反写。

### SHARE-FIX-04 完成记录

- 状态：`IN_PROGRESS` → `CODE_DONE`；Windows 静态与发布门禁完成，Xcode 像素 XCTest 和 TestFlight 导出签收前不标记 `VERIFIED`。
- 实现与文件：`NativeDemoApp/CoverEngine/Rendering/CoverCanvasRoot.swift` 仅移除媒体槽在应用 `placement.frame` 偏移后的错误外层 `.clipped()`；图片本身仍先在槽尺寸内 `scaledToFill/fit` 并 `.clipped()`、圆角裁切，画布根节点仍限制 540×960，Footer 保留区规则不变。`NativeDemoAppTests/CoverShareFlowTests.swift` 增加位于高 Y 偏移槽的绿色测试图导出像素断言，直接覆盖“Recipe 有图但像素不可见”；`scripts/experience_static_check.ps1` 增加禁止偏移后局部二次裁切及像素测试存在性的门禁。
- 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 通过，最终输出 `release_repository_gate: OK`，既有封面 Footer、图片分析、预览/导出同源及迁移/真实图片夹具门禁同时通过。Windows 无 Swift/Xcode，未冒充运行新增 `ImageRenderer` 像素 XCTest。
- 剩余风险：在 Xcode 执行 `CoverShareFlowTests.testExportKeepsAnOffsetMediaSlotVisibleInsideItsResolvedFrame`；新 TestFlight 按 `FLOW-77` 用 1/2/3/4+ 张安全照片逐套检查首发 6 套预览及 1080×1920 相册导出，确认 Hero/辅助图可见、槽内裁切正确、无 Footer 溢出，且无图/隐私拒绝继续安全降级。

### OCR-FIX-01 启动记录

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 已确认根因：`NativeDemoApp/Services/OCRService.swift` 的日期解析允许裸 `M.d`，支付截图整段 OCR 文本里的金额 `¥4.20` 会先于默认日期命中 4 月 20 日；现有 `?? .now` 只在完全未匹配时生效，不能修正这个误命中。
- 允许范围：只收紧 OCR 日期证据边界；货币符号、金额标签及已选金额所在 OCR 行不得作为日期候选，无明确日期时使用导入当天；保留 `4月20日`、`2026-04-20` 和明确日期标签附近日期。
- 冻结边界：不修改 OCR 金额、商户、分类、交通事实、编辑器默认值、账本迁移、首页动线或 AI 能力；不以全面禁止裸月日破坏真实票据日期识别。
- 验收：`支付成功 + LAWSON + ¥4.20 + 无日期` 使用注入的当天；同一输入的金额仍为 4.20、商户仍可识别。显式中文日期、完整年月日和日期标签附近的月日继续解析；金额同行即使形似日期也不得覆盖明确日期或当天回退。

### OCR-FIX-01 完成记录

- 状态：`IN_PROGRESS` → `CODE_DONE`；代码、纯策略测试和 Windows 发布门禁完成，正式相册 OCR 真机签收前不标记 `VERIFIED`。
- 实现与文件：`NativeDemoApp/Services/OCRService.swift` 新增 `OCRDateEvidencePolicy`，完整年月日和带“日”的中文月日可作为直接证据；裸 `M.d/M-d/M/d` 仅在日期/时间标签上下文成立；货币符号、金额标签和支付成功解析实际选中的金额行均排除。`parsePaymentSuccessResult` 无明确日期时返回本次导入的 `now`，既有金额、品牌匹配和分类路径不变。`NativeDemoAppTests/StateRegressionTests.swift` 覆盖 `支付成功 + LAWSON + ¥4.20` 当天回退、货币/金额标签拒绝以及三类合法日期。`scripts/experience_static_check.ps1` 和 `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 增加守卫与 `FLOW-79`。
- 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 通过，最终输出 `release_repository_gate: OK`；既有 OCR/语义、文案、迁移夹具与真实图片门禁同时通过。Windows 无 Vision 真机 OCR、Swift/XCTest 环境，未冒充运行。
- 剩余风险：Xcode 执行 `OCRDateEvidencePolicyTests`；TestFlight 按 `FLOW-79` 走正式相册 OCR，重点核对真实 Vision 分行可能把金额/日期合并时的当天回退、明确日期优先、金额仍为 4.20、LAWSON/罗森与分类不变，并验证取消/重试/一次提交。

### PLAYBACK-FACT-FIX-01 启动记录

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 已确认根因：首页动态故事直接优先 `HomeItem.isLateWorkCommute`，而周/月叙事候选只把同一事实当普通加分，仍可被天气或其他候选挤掉；即使命中，播放正文也没有消费已经存在的 `lateWorkCommutePlaybackLine`，因此用户看不到“凌晨下班路”的同一事实表达。这不是单一情绪分阈值不足。
- 允许范围：只为强证据 `isLateWorkCommute == true` 建立周/月播放代表记录或唯一辅助情绪的保证，并消费专用播放文案；增加选择/文案确定性测试和真机矩阵。
- 冻结边界：普通交通、单笔地铁/公交、白天打车不得升级为下班主线；不修改首页动线、通勤事实判定阈值、章节数/顺序/时长、额度、会员、分享封面、OCR 或全局叙事排序。
- 验收：回归样本 `00:08 + 加班打车 + 交通 + ¥50.90 + 照片` 至少进入周期代表记录或唯一辅助情绪并使用专用播放文案；若周期已有更高等级生活主线，不强行覆盖 Lead，但下班事实仍出现一次且不重复。普通交通样本零误触发，周/月结果确定且证据 ID 可回到原记录。

### PLAYBACK-FACT-FIX-01 完成记录

- 状态：`IN_PROGRESS` → `CODE_DONE`；选择、正文消费、照片偏好、测试和 Windows 发布门禁完成，TestFlight 逐章签收前不标记 `VERIFIED`。
- 实现与文件：`NativeDemoApp/Services/PlaybackSupportServices.swift` 新增 `PlaybackLateWorkCommutePolicy`，仅将 `HomeItem.lateWorkCommutePlaybackTitle == "晚下班路上"` 的工作词强证据纳入兜底，普通夜间地铁/公交不进入强保证；同时在需要辅助呈现时优先该情绪。`NativeDemoApp/Services/PlaybackService.swift` 在周记和月章中保留用户原话/合格照片/变化 Lead 的优先级，其后才以强下班事实兜底对应代表章节；`playbackRecordCopy` 直接消费 `lateWorkCommutePlaybackLine`。代表记录已是该事实时移除重复辅助情绪；更高主线占位时专用正文只进开场 support；带照片样本的 memory anchor 优先同一 item ID。`NativeDemoAppTests/StateRegressionTests.swift` 覆盖周代表、强主线保留、普通交通拒绝与月章半段定位；`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 增加 `FLOW-80`。
- 验证证据：`git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 通过，最终输出 `release_repository_gate: OK`；既有 3/5 章周记、6 章月章、辅助信号、叙事角色、文案、迁移与真实图片夹具门禁同时通过。Windows 无 Swift/Xcode/iPhone，未冒充运行 XCTest 或播放真机签收。
- 剩余风险：Xcode 执行新增 `PlaybackLivingVoiceCopyTests`；TestFlight 按 `FLOW-80` 核对 `00:08 + 加班打车 + ¥50.90 + 照片` 的周/月章节、专用正文、金额和同一照片 item ID，覆盖更高主线、删工作词、改白天及普通夜间交通对照，并确认同一事实只出现一次。

### COPY-FIX-03 启动记录

- 状态：`NOT_STARTED` → `IN_PROGRESS`；当前唯一 `IN_PROGRESS`。
- 已确认根因：便利店品牌的低金额固定文案池直接含“一口热食很及时”，只有商户名时也推断了热食；普通餐饮池反复使用“热乎/一口/垫一下”。稳定选择 seed 主要依赖标题，连续多笔同名“罗森”总会命中同一句，造成重复且无事实依据。
- 允许范围：只修正餐饮/便利店情绪标签的证据门槛和确定性多样性；仅在标题、用户原话或结构字段明确出现饭团、便当、关东煮、咖啡、面等食物时使用相应具体标签；只有商户名时使用中性事实或隐藏无增量标签。
- 冻结边界：不修改商户品牌匹配、分类、金额、OCR、记录标题、首页动线、生活印记排序、播放章节、分享、会员、存储或同步；不以随机数制造不可复现文案。
- 验收：连续多笔同名罗森不再固定“一口热食很及时/热乎一口”，无食物证据时零“热食/热乎”声称；明确关东煮/便当/饭团/咖啡等仍可给出对应中性标签。相同记录在重启后确定，至少加入记录 ID/日期/金额等稳定身份避免同标题永久同句；没有信息增量时允许空标签并由现有 UI 安全隐藏。

### COPY-FIX-03 完成记录

- 状态：`IN_PROGRESS` → `CODE_DONE`；本轮五项定向优化已全部完成代码和 Windows 门禁，Xcode/XCTest/TestFlight 签收前均不标记 `VERIFIED`，当前没有新的路线图任务进入 `IN_PROGRESS`。
- 实现与文件：`NativeDemoApp/Services/NarrativeCopyResolver.swift` 新增共享 `DiningCopyEvidencePolicy`，把便利店品牌事实与具体食品证据分开；品牌名-only 仅使用商户级中性标签，关东煮、便当、饭团、咖啡等只有在标题/用户文字明确出现时才进入对应中性标签。稳定选择 seed 现在消费标题、可用 record ID、日期毫秒、金额位模式和品牌 ID，同一记录重启确定，不同时间/金额/ID 的同名记录不再永久锁死同一句。普通餐饮兜底按时段给中性事实，不再经无证据 food ScenePack 制造温度或具体食物。`NativeDemoApp/Services/MerchantBrandCatalog.swift` 清除便利店池凭品牌声称饭团、便当、饮料、小食和热食的内容，并清除其他餐饮品牌池无文字证据的“热餐/热饭/热乎”温度声称。`NativeDemoApp/Models/HomeItem.swift` 让明确食品细分与旧存储标签消费同一证据规则；旧版“一口热食很及时”等若标题无支持证据，会按同一 item ID 稳定纠正，不写回账本、不新增 IO/网络/全账本扫描。
- 回归与交互边界：`NativeDemoAppTests/StateRegressionTests.swift` 增加品牌名-only 多样且可复现、明确四类食品保留、旧错误标签纠正、便利店与全部餐饮品牌池温度边界测试；`scripts/experience_static_check.ps1` 增加共享策略、旧记录、品牌池、XCTest 和矩阵守卫；`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 增加 `FLOW-81`，覆盖连续 8 笔罗森、历史错误标签、编辑删/恢复证据、杀进程重启、免费/会员、VoiceOver 和 20 次快速页面往返。没有修改商户匹配、分类、金额、OCR、首页第五个问题、首页主动作、免费每日 3 次/会员不限、播放扣次与 80% 完成签名、生活印记排序、播放章节、分享、存储或同步。
- Windows 验证证据：`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终输出 `release_repository_gate: OK`；100/1,000/5,000 条确定性迁移夹具、三张真实 12MP 图片夹具、文案体验检查、copy lint、SQLite schema 与既有封面/播放/OCR 门禁同时通过。copy lint 仅保留基线中 5 条既有软提示。Windows 无 `swift`、`swiftc`、`xcodebuild` 和 iPhone，未冒充 Swift 编译、XCTest 或真机通过。
- 剩余风险与下一步：在 Xcode 先执行全量 Debug/Release 编译和 `DiningCopyEvidencePolicyTests`，重点确认新增 `NarrativeCopyResolver.Context.recordID` 默认参数及测试目标接线；再用新 TestFlight 包依次执行 `FLOW-78`（播放前后台 20 次）、`FLOW-79`（`LAWSON + ¥4.20` 无日期）、`FLOW-80`（`00:08 + 加班打车 + ¥50.90 + 照片`）和 `FLOW-81`（餐饮证据/稳定多样性）。四项附真机结果和 crash/Jetsam/Instruments 证据后，才能分别从 `CODE_DONE` 推进为 `VERIFIED`；首页第五个问题继续保持冻结并由用户单独测试。

---

## 66. 2026-07-27 TestFlight 痕迹、分类与备份文案定向修复队列

- 用户反馈与固定顺序：`TRACE-LOADING-FIX-03` → `TRACE-PHOTO-FIX-01` → `SEMANTIC-FIX-01` → `COPY-FIX-04`。四项作为同一批 TestFlight 修复交付，但必须逐项进入 `IN_PROGRESS`、达到 `CODE_DONE` 并回填证据后再开始下一项；任何时刻最多一个 `IN_PROGRESS`。
- 工作区保护：开始前分支为 `feature/xuzhangapp-staging`，仅有用户既有未跟踪的 `brand-assets/mockups/`、`brand-assets/source/pet-concepts/`、`brand-assets/source/pet-sprites/`、`output/`、`scripts/__pycache__/` 与 `tmp/`；全部保留，不删除、不覆盖、不暂存。`PERF-AUDIT-04` 与 `ARCH-03` 继续保持 `NOT_STARTED`。

### TRACE-LOADING-FIX-03：冷启动摘要与统一 viewport 遮罩语义对齐

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码与体验静态门禁通过，缺 Xcode/iPhone `FLOW-82` 签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 真机现象与根因：杀进程进入痕迹时先显示持久化的 `TraceColdStartDisplayEntry` 轻量摘要卡，完整快照完成后直接替换为结构差异较大的周/月卡，形成明显跳变。当前代码把轻量摘要也计入 `hasVisibleSnapshot`，因此主动关闭 `UI-FIX-03` 的统一 viewport 遮罩；摘要卡自身又显示局部 spinner，造成“先假卡、后真卡”而非稳定加载层。
- 允许范围：只区分“完整匹配快照”和“轻量冷启动摘要”的加载呈现；轻量摘要可继续作为遮罩下的非交互承接，但不得关闭统一 viewport 遮罩。完整快照继续无动画原子发布，随后仅淡出遮罩。允许修改 `StatsTraceModels.swift`、`StatsWebView.swift`、对应 XCTest、静态门禁、真机矩阵与本文档。
- 冻结边界：不修改周/月/线索计算、缓存 key、指纹、冷启动缓存 schema/内容、后台任务/取消/latest-wins、正式卡片结构、照片、筛选、滚动定位、额度、会员、AI、存储同步、`PERF-AUDIT-04` 或 `ARCH-03`。
- 验收：轻量摘要命中时统一遮罩立即居中并阻止下层交互；完整匹配快照刷新仍无阻断遮罩；最终卡在遮罩下无布局动画替换后淡出。缓存缺失/损坏、快速周/月/生活/线索切换、取消和 Reduce Motion 均无双 spinner、旧内容误触或旧请求反写。
- 实现与证据：`TraceLoadingPresentationPolicy` 将输入语义收紧为 `hasCompleteSnapshot`；`StatsWebView` 只有完整匹配快照才关闭 viewport 遮罩，轻量冷启动摘要不再参与该判定，并移除摘要卡局部 `ProgressView`。新增冷启动摘要立即阻断呈现 XCTest、两条静态防回流和 `FLOW-82`。`git diff --check` 与 `powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过；未修改快照 key、指纹、缓存内容、计算、取消、照片或其他冻结边界。
- 剩余风险：Windows 无 Swift/Xcode/iPhone，参数改名、SwiftUI 遮罩层级、VoiceOver、Reduce Motion 和冷启动最终卡替换仍需编译及 `FLOW-82` 真机签收。

### TRACE-PHOTO-FIX-01：本月日记真实照片来源独立化

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码与体验静态门禁通过，缺 Xcode/iPhone `FLOW-83` 签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 已确认根因：章节快照为封面/叙事只准备最多 3 个 `memoryAnchors`；月章封面占用并从“本月日记”排除其中 1 个，因此下方最多只剩 2 张真实照片，其余位置被普通记录文字卡补齐。这不是图片加载失败。
- 允许范围：从同一不可变月度 `snapshot.items` 独立选择最多 6 条合格带图记录，排除封面 item ID 后再排序/去重；只有真实合格照片不足时才使用文字卡。选图必须复用既有照片资格、角色、质量阈值与按需引用，不在 SwiftUI `body` 解码原图或扫描全账本。允许修改照片选择纯策略、章节快照准备/消费、对应 XCTest、静态门禁、真机矩阵与本文档。
- 冻结边界：不改变顶部封面选择、播放/分享 memory anchors、照片原始顺序/封面索引/存储引用、图片质量与隐私门槛、月章事实/文案/布局、账单、额度、会员、AI、同步、`PERF-AUDIT-04` 或 `ARCH-03`。
- 验收：封面外有 6 条合格带图记录时下方显示 6 张真实照片；0～5 张时按实际数量显示并仅用非照片记录补足；同一封面不重复、同一账单不重复、缺图/低质量/收据边界保持现有资格，横滑不触发额外全账本聚合或同步原图解码。
- 实现与证据：月度章节在既有后台选图中一次准备最多 7 个合格候选；前三个继续作为原 `memoryAnchors`，封面策略完全不变；排除封面后最多 6 个写入新增只读 `monthDiaryAnchors`，本月日记渲染只消费该快照。新增 8 条带图记录验证“封面锚点仍为 3、日记照片为 6、封面与 item ID 均不重复”的 XCTest、禁止日记回读三锚点池的静态守卫和 `FLOW-83`。`git diff --check` 与体验静态门禁通过。
- 冻结边界复核与风险：未修改选图评分/阈值、顶部封面、播放/分享、照片存储/顺序/引用或账单；Windows 无 Swift/Xcode/iPhone，新增 snapshot 字段、真实图片按需加载、缺图与 12MP 横滑仍需编译及 `FLOW-83` 签收。

### SEMANTIC-FIX-01：鸭血粉丝汤等精确餐饮识别

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 语义回归与体验静态门禁通过，缺 Xcode/XCTest 与真机签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 已确认根因：`鸭血粉丝汤包` 保存时即为“其他”，痕迹页只是原样显示。当前记账语义词典包含“粉面、汤面、包子、鸭肉”等，但没有能命中该标题的“鸭血粉丝汤/鸭血粉丝/汤包”证据，默认分类可能回落为“其他”。
- 允许范围：为手动记账与 OCR 共用词典增加精确餐饮短语，并补确定性语义/OCR 回归；不得使用歧义单词“粉丝”作为独立餐饮关键词。仅影响新建或用户再次编辑并允许语义判断的记录，不静默迁移、重写既有用户分类。
- 冻结边界：不改变用户手动锁定分类的优先级、默认分类、品牌匹配、金额/日期/标题、OCR 金额日期解析、既有记录、情绪/场景/生活线索规则、存储 DTO、同步、会员、额度、`PERF-AUDIT-04` 或 `ARCH-03`。
- 验收：`鸭血粉丝汤`、`鸭血粉丝汤包`、`灌汤包/小笼汤包` 稳定识别为餐饮；“明星粉丝见面会、粉丝增长、礼包、文件包”等反例不因本项进入餐饮；用户明确锁定其他分类时仍保持用户选择。
- 实现与文件：`NativeDemoApp/Resources/RecordSceneLexicon.json` 的手动、OCR 与 `meal` 情绪规则以及 `NativeDemoApp/Models/HomeItem.swift` 的强手动备注覆盖和最小 fallback 同步加入“鸭血粉丝汤、鸭血粉丝、灌汤包、小笼汤包、汤包”五个完整短语；未加入独立“粉丝”或“包”。`NativeDemoApp/Resources/RecordSceneLexicon.regression.json` 新增四个手动正例、一个 OCR 正例与四个歧义反例；`NativeDemoAppTests/StateRegressionTests.swift` 新增精确识别、歧义边界和用户锁定分类优先级 XCTest；`scripts/life_semantic_regression.py` 同步锁定三类词典来源、Swift fallback 与禁止宽泛词边界。
- 验证证据与风险：`python scripts/life_semantic_regression.py`、JSON 解析、`git diff --check` 与 `powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 全部通过。没有静默迁移或重写既有记录；用户截图中的旧“其他”记录仍保留原分类，只有新建或再次编辑且未锁定分类时使用新规则。Windows 无 Swift/Xcode/iPhone，仍需全量编译、运行新增 XCTest，并在 TestFlight 验证手动/OCR、用户锁定和历史记录不变边界。

### COPY-FIX-04：云端备份文案去除内部“字段”术语

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 文案、体验静态与完整发布门禁通过，缺 Xcode/XCTest 与 TestFlight `FLOW-84` 签收，不标记 `VERIFIED`。本批四项均已达到 `CODE_DONE`，当前无 `IN_PROGRESS`。
- 真机现象与根因：设置首页卡片直接展示“账单字段云端开 · 联网整理开”，既使用开发术语“字段”，又用不自然的“开”，并在单行卡片中截断。相同内部术语还散落于备份帮助、会员说明和同步状态。
- 允许范围：短状态统一为“自动备份已开启 / 联网整理已开启 / 仅保存在本机”；需要说明数据边界的正文直接列出“金额、分类、备注和日期”，并继续明确照片不上传。允许修改 iOS 当前用户可见文案、文案 lint/静态门禁、真机矩阵与本文档。
- 冻结边界：不改变云端 DTO、同步开关/冲突合并/删除行为、照片仅本机边界、本地备份包格式、会员权益、隐私事实、联网 AI 行为、布局结构、`PERF-AUDIT-04` 或 `ARCH-03`。
- 验收：iOS 用户可见界面不再出现孤立“账单字段”或“云端开/联网整理开”；四种开关组合短文案自然且小屏不截断；详细说明仍准确表达同步范围与照片仅本机，危险删除提示不弱化。
- 实现与文件：`NativeDemoApp/Views/SettingsView.swift` 新增纯 `SettingsBackupSummaryPolicy`，四种组合固定为“自动备份已开启 · 联网整理已开启 / 自动备份已开启 / 联网整理已开启 / 仅保存在本机”，设置卡、账号、备份、隐私和危险确认统一改用“自动备份、云端记录、账单信息”等自然表达；详细边界统一明确“金额、分类、备注和日期会自动备份；照片仍保存在本机”。`NativeDemoApp/ViewModels/SettingsViewModel.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Views/MemberPricingView.swift` 与 `NativeDemoApp/Services/LedgerLocalBackupDocument.swift` 的状态、会员保存边界和本地备份说明同步去除“字段”术语；云端删除、本机删除、照片保留和不可撤销语义保持明确。
- 回归、证据与风险：`NativeDemoAppTests/StateRegressionTests.swift` 覆盖四种状态的精确文案；`scripts/copy_lint.py` 将旧“账单字段/云端开/联网整理开/联网梳理已开/仅本地保存”纳入阻断；`scripts/experience_static_check.ps1` 锁定新文案、零旧术语、XCTest 与 `FLOW-84`，`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 新增小屏、Dynamic Type、VoiceOver、四组合和危险删除矩阵。`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；5 条 copy lint 软提示均为既有基线。未修改云端 DTO、同步/冲突/删除实现、照片不上云、本地包格式、会员或联网整理行为。Windows 无 Swift/Xcode/iPhone，仍需全量编译、运行新增 XCTest，并用新 TestFlight 完成 `FLOW-82`～`FLOW-84`。

---

## 67. TRACE-DELETE-FIX-01：细查列表连续左滑删除与快照一致性（2026-07-27）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 差异、语义、交互、文案、迁移与完整发布门禁通过，缺 Xcode/XCTest、iPhone Instruments 与 TestFlight `FLOW-85` 签收，不标记 `VERIFIED`。当前无 `IN_PROGRESS`，`PERF-AUDIT-04` 与 `ARCH-03` 继续保持 `NOT_STARTED`。
- 真机证据：月度细查显示 `95 笔`；左滑一行后删除按钮能够出现，但连续操作时反馈迟缓，确认删除后顶部笔数与对应记录仍可能保留。截图中的行在滑动时还出现明显横向裁切，说明问题同时涉及手势刷新和删除后的快照发布，不是单纯云端响应慢。
- 已确认根因：`deleteRecord` 先把单一 `traceDeletingItemID` 动画 0.45 秒，再通过延迟闭包查找索引并删除，连续操作会叠加等待和全列表高度动画；父级 `@GestureState traceSwipeDragState` 在拖动每一帧使整个 `StatsWebView` 重算，并切换 `ScrollView.scrollDisabled`。账本删除后，细查立即按新 `homeDashboardRevision` 重建，但非自定义范围读取的 `filteredItems` 会按 `PERF-15` 合法承接同日旧派生缓存；旧记录集合因此被错误盖上新 revision，成为“当前”细查快照，后续派生缓存发布又不会触发第二次细查准备，已删行可长期重新出现。
- 目标：左滑位移只在当前行局部更新，父级长列表不逐帧失效；删除按稳定 UUID 立即提交本机变化并原子更新当前细查快照，不再等待固定动画或依赖旧索引；派生缓存修订落后时改用当前账本与精确周期重建，禁止旧记录集合冒充新 revision；晚到云端上传不得在删除完成后复活同一 ID。
- 允许修改：`StatsWebView.swift` 的细查行局部手势、删除调用与快照来源；`StatsTraceModels.swift` 仅移除失去用途的父级拖动状态；`HomeViewModel.swift` 的稳定 ID 删除入口和直接必要的云端上传后删除补偿；对应 XCTest、体验静态门禁、真机矩阵与本文档。
- 冻结边界：不修改本周/本月/本年、自定义日期与分类筛选含义，不修改数量/金额/日期排序、编辑/补图、正式持久化 schema、云端 DTO 与冲突合并规则、照片、周/月章节、额度、会员、AI、首页动态主动作、主题、`PERF-AUDIT-04` 或 `ARCH-03`；不把单次筛选快照回退为 SwiftUI `body` 多次扫描。
- 计划验收：连续删除 20 条时每次均按实际 ID 即时消失，笔数、合计和日期分组同步更新；快速交错滑动、取消确认、删除当日最后一条、筛选切换、关闭重开、杀进程重启、云端开/关和上传晚到均不复活记录。100/1,000/5,000 条下横向拖动不触发父页逐帧状态发布，纵向滚动不被误锁；本机持久化失败时保留/恢复原记录并显示既有错误。Windows 只能完成代码、静态与发布门禁，Xcode/XCTest/iPhone Instruments 和 TestFlight 签收前最多标记 `CODE_DONE`。
- 实现与文件：`NativeDemoApp/Views/StatsWebView.swift` 新增行内 `TraceSwipeRow`，把 `@GestureState`、坐标空间和拖动位移收进当前行，父级不再逐帧发布拖动状态或据此锁住纵向 `ScrollView`；移除旧延迟删除动画和不可达 legacy 手势代码。确认删除后立即调用稳定 UUID 入口，只有本机持久化成功才通过 `TraceDetailListSnapshotComputation.deleting` 原子发布新 key、记录、ID、合计和日期分组；Reduce Motion 下不做删除位移动画。`prepareTraceDetailListSnapshot` 仅在派生缓存 revision 与当前账本 revision 相等时复用周期集合，否则从当前 `items` 按精确周/月/年区间重建，旧集合不能再盖上新 revision。`NativeDemoApp/Views/StatsTraceModels.swift` 移除失去用途的共享 `TraceSwipeDragState`。
- 删除与同步：`NativeDemoApp/ViewModels/HomeViewModel.swift` 新增 `deleteItem(id:)` 并让原 `delete(at:)` 共用稳定 ID 删除提交；仅删除仍实际存在的 UUID，持久化失败继续沿用既有 reload 与错误提示恢复原账本。`LedgerCloudUploadCompletionPolicy` 在上传返回后核对本机是否仍存在同一 ID，若记录已在上传途中删除，则立即发起补偿删除，保持最终本机删除意图；未修改云端 DTO、冲突合并或照片边界。
- 回归与真机矩阵：`NativeDemoAppTests/StateRegressionTests.swift` 新增 20 条稳定 ID 连续删除、重复删除幂等、笔数/合计/分组一致、最后一条移除日期分组、旧/当前派生 revision 复用边界和上传晚到补偿策略测试。`scripts/experience_static_check.ps1` 锁定局部手势、零父级拖动状态、零固定删除延迟、稳定 UUID 持久化、旧缓存拒绝、云端补偿与测试名；`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 新增 `FLOW-85`，覆盖连续删除 20 条、取消/筛选/重开/重启、写入失败、云端开关与上传晚到、100/1,000/5,000 条、VoiceOver、Dynamic Type、Reduce Motion 和 Instruments。
- 验证证据：`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；5 条 copy lint 软提示均为既有基线。冻结边界确认：未修改周期/自定义日期/分类语义、金额与日期排序、编辑补图、存储 schema、云端 DTO/冲突合并、照片、周/月章节、额度、会员、AI、首页主动作、主题、`PERF-AUDIT-04` 或 `ARCH-03`。
- 剩余风险与下一步：Windows 无 Swift/Xcode/iPhone，新增 SwiftUI 泛型行手势、严格并发诊断和 XCTest 尚未实际编译运行；100/1,000/5,000 条横滑/纵滚 Main Thread Hitches、连续确认删除、持久化失败 UI、云端真实时序、VoiceOver、Dynamic Type 与 Reduce Motion 仍需在 macOS 完成 Debug/Release build、全部 XCTest，并用新 TestFlight 按 `FLOW-85` 真机签收。下一项只做 `FLOW-85` 验证；未取得真机证据前保持 `CODE_DONE`，不启动 `PERF-AUDIT-04` 或 `ARCH-03`。

---

## 68. SEMANTIC-FIX-02：具体商品语义与金额时间习惯防越权（2026-07-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE` → `IN_PROGRESS` → `CODE_DONE`；用户在 Xcode 编译发现的 `HomeViewModel.swift:2500` Optional `flatMap` 泛型返回值无法推断已完成定向修复，Windows 完整发布门禁再次通过。当前无 `IN_PROGRESS`；仍需用户在 Xcode 重新编译确认，不标记 `VERIFIED`，`PERF-AUDIT-04` 与 `ARCH-03` 继续保持 `NOT_STARTED`。
- 已确认根因：本地品牌目录和商品语义词典不认识“东方树叶、青柑普洱”等瓶装茶证据；标题语义为空时，预填服务会让相同工作日类型、相同三小时段及相同小额金额的历史记录直接返回 `habit/scene_habit/frequent` 分类，因此历史 ¥6 通勤记录可覆盖一个全新的具体商品标题。错误来自历史习惯越权，不是单一金额档位硬编码。
- 允许范围：增加东方树叶品牌与完整茶饮品类短语；建立具体非空标题对历史习惯覆盖的统一资格策略，并让后台预填与页面即时推荐共用同一结论；补确定性 XCTest、语义夹具、静态门禁、真机矩阵和本文档。
- 优先级边界：用户手动锁定分类 > 明确商品品类 > 品牌 > 相同/相似商品历史 > 金额与时间习惯 > 安全默认。空备注或泛化备注仍可使用可靠历史习惯；具体新标题只有与支持历史标题足够相似时才允许仅凭习惯覆盖。不得把“¥6”学习成交通，也不得因未收录商品名就默认接受历史分类。
- 词典边界：使用“东方树叶、农夫山泉东方树叶、青柑普洱、普洱茶、乌龙茶、茉莉花茶、红茶、绿茶、瓶装茶、无糖茶”等完整短语；不加入歧义单字“茶”，避免茶具等普通购物误入餐饮；“茶叶蛋”等既有餐饮语义保持。
- 冻结边界：不修改用户锁定分类、保存字段、账本历史记录、OCR 金额/日期、通勤事实、场景/情绪/生活线索、会员/额度、云端 DTO、同步、首页动态主动作、`PERF-AUDIT-04` 或 `ARCH-03`；不静默迁移既有错误分类。
- 计划验收：`东方树叶 青柑普洱 + ¥6 + 工作日 18:43 + 大量 ¥6 晚高峰交通历史`、单独“东方树叶”和“青柑普洱”均为餐饮；“地铁 + ¥6 + 18:43”和空备注同金额习惯继续可为交通；未知具体商品名不得仅凭金额/时间变交通；茶具不进餐饮、茶叶蛋仍为餐饮；后台预填与即时推荐一致，用户锁定始终最高优先级。
- 实现与文件：`NativeDemoApp/Services/RecordPrefillService.swift` 新增共享纯策略 `RecordHabitOverridePolicy`，统一归一化空格/标点/大小写，以严格包含覆盖率或双字 gram 相似度匹配标题，并且只从 `userEditedCategory == true`、非系统生成标题学习 `entity_history`；品牌/明确语义和同商品纠错历史均先于 scene habit、habit、frequent 与通用金额时间评分，具体但未知的新标题拒绝无实体证据的自动覆盖，空备注继续允许可靠习惯，用户锁定仍在所有策略之前退出。`NativeDemoApp/ViewModels/HomeViewModel.swift` 的临时自动选中、后台 `prefillSnapshot/categoryGridRecommendation` 与即时 `recommendCategoryResult` 全部复用同一策略，删除两份“语义为空即允许 frequent”的重复实现，并让明确商品语义在品牌冲突时优先。
- 品牌与词典：`NativeDemoApp/Services/MerchantBrandCatalog.swift` 增加 `oriental_leaves`（东方树叶/农夫山泉东方树叶）餐饮品牌及中性事实文案；`NativeDemoApp/Resources/RecordSceneLexicon.json` 与 `NativeDemoApp/Models/HomeItem.swift` 的正式/降级手动、OCR、drink 规则同步加入东方树叶及青柑普洱、普洱茶、乌龙茶、茉莉花茶、红茶、绿茶、瓶装茶、无糖茶完整短语。未加入孤立“茶”，茶具继续购物、茶叶蛋继续餐饮。`NativeDemoApp/Resources/RecordSceneLexicon.regression.json` 与 `scripts/life_semantic_regression.py` 增加正反例、品牌存在性和孤立“茶”防回流门禁。
- 回归与真机矩阵：`NativeDemoAppTests/StateRegressionTests.swift` 覆盖东方树叶青柑普洱对大量 ¥6 晚高峰交通历史、单独品牌/品类、地铁、空备注、未知新商品拒绝、用户明确纠错后的同/相似商品学习、茶具、茶叶蛋和用户锁定；同一 snapshot 同时断言自动选中、分类宫格和预填结果一致。`scripts/experience_static_check.ps1` 锁定共享策略、`entity_history`、三条调用路径、品牌、无孤立“茶”、XCTest 名称和 `FLOW-86`；`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 新增快速改备注/金额、异步晚到、重启、VoiceOver、Reduce Motion 和连续 20 次操作矩阵。
- 验证证据：`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py` 与 `python scripts/validate_release_gate.py --phase windows` 全部通过，最终 `release_repository_gate: OK`；5 条 copy lint 软提示均为既有基线。冻结边界确认：未迁移或重写任何已有账单，未修改保存 schema、OCR 金额/日期、通勤事实、场景/情绪/生活线索、会员/额度、云端 DTO/同步、首页动态主动作、`PERF-AUDIT-04` 或 `ARCH-03`。
- 剩余风险与下一步：Windows 无 Swift/Xcode/iPhone，新增 Swift 归一化/相似度策略、严格并发诊断和 XCTest 尚未实际编译运行；后台预填晚到、连续 20 次备注切换、用户锁定、保存/重启一致性、VoiceOver 与 Reduce Motion 仍需在 macOS 完成 Debug/Release build、全部 XCTest，并用新 TestFlight 按 `FLOW-86` 真机签收。下一项只做 `FLOW-86` 验证；未取得真机证据前保持 `CODE_DONE`，不启动 `PERF-AUDIT-04` 或 `ARCH-03`。
- Xcode 编译定向修复：`NativeDemoApp/ViewModels/HomeViewModel.swift` 为 provisional frequent suggestion 的 Optional `flatMap` 同时补充结果类型 `HomeItem.Category?` 与闭包返回类型 `-> HomeItem.Category?`，消除 `Generic parameter 'U' could not be inferred`，不改变置信度、语义优先级或任何运行时分支。修复后 `git diff --check`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 再次通过，最终 `release_repository_gate: OK`；Windows 无 Swift 编译器，仍以用户下一次 Xcode 编译结果作为本项编译签收证据。

---

## 69. 2026-08-18 高保值发版验证记录

- 状态与范围：本轮只复验现有发布产物、分支一致性、跨平台自动门禁、Node 契约和外部签收条件，不修改产品代码、不新增功能、不迁移数据，也不把任何 `CODE_DONE` 项提升为 `VERIFIED`。当前无路线图任务进入 `IN_PROGRESS`；`SEMANTIC-FIX-02` 仍为 `CODE_DONE`，下一项仍只允许 `FLOW-86` 的 Xcode/TestFlight 验证，`PERF-AUDIT-04` 与 `ARCH-03` 保持 `NOT_STARTED`。
- 文件与工作区：本轮仅更新 `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。验证基线为 `feature/xuzhangapp-staging` 的 `5c78cc5 fix: make frequent category type explicit`，与远端 ahead/behind 为 `0/0`；既有未跟踪 `brand-assets/mockups/`、`brand-assets/source/pet-concepts/`、`brand-assets/source/pet-sprites/`、`output/`、`scripts/__pycache__/` 和 `tmp/` 全部保留、未改动、未暂存。
- 验证证据：`python scripts/validate_release_gate.py --phase windows` 退出码 0 并输出 `release_repository_gate: OK`；100/1,000/5,000 条确定性夹具、三张真实 12MP 夹具、差异、生活语义、体验静态、文案体验、copy lint、迁移和 SQLite schema 全通过，夹具摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`，仅有既有 5 条软提示。`npm test`（`ai-proxy`）24/24 通过；`npm test`（`backend`）确认 90 天认证令牌 TTL 和生产提醒每日 1 次/场景冷却 7 天。App Debug/Release 静态配置均为版本 `1.0`、构建号 `1`、Bundle ID `com.xuzhang.app`、Team `4SYY8L84JV`。
- 剩余风险与发布结论：当前 Windows 复核 `xcodebuild`、`swift`、`simctl`、`instruments` 全不可用，无法执行 Debug/Release 编译、Swift 严格并发诊断、全部 XCTest、device-audit、100/1,000/5,000 条真机性能、REAL-01～06、StoreKit、双设备同步、权限、VoiceOver、Dynamic Type、Reduce Motion 或 `FLOW-82`～`FLOW-86`。构建号 `1` 上传前还须确认未在 App Store Connect/TestFlight 使用，若已使用必须递增。因此当前仅能判定“Windows 仓库门禁通过”，整体发版结论为 `BLOCKED`，不得标记 `VERIFIED` 或正式发版。
- 下一步：在 macOS 执行 `python3 scripts/validate_release_gate.py --phase all --simulator-destination 'platform=iOS Simulator,name=iPhone 15'` 并保留 Debug、Release、XCTest 三段独立日志；用新构建完成两档 iPhone、三档夹具与 device-audit、REAL-01～06、StoreKit/同步/权限/无障碍矩阵，最后优先签收 `FLOW-82`～`FLOW-86`，其中 `FLOW-86` 必须覆盖东方树叶/青柑普洱、未知具体商品、用户纠错学习、快速切换 20 次、锁定、重启、VoiceOver 与 Reduce Motion。只有全部必测项通过后才更新最终结论为 `PASS`。

---

## 70. TRACE-PREP-PERF-01：痕迹事实底稿与周/月回放复用（2026-08-18）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；代码、等价性回归、体验静态门禁与完整 Windows 发布门禁通过，当前无 `IN_PROGRESS`。用户以长期真机日用确认“正在整理”是当前最大问题，并明确授权优化与自检；本项作为已知发版阻断的定向性能修复，先于通用 `PERF-AUDIT-04`，未启动 `ARCH-03`。Windows 无 Swift/Xcode/iPhone，缺编译、XCTest 与 Instruments 真机签收，不标记 `VERIFIED`。
- 产品原则：同一周期共用事实与证据底稿，不共用最终页面。痕迹继续负责概览，线索负责解释，周记/月章继续按既有章节和文案变体展开；金额、日期、分类、生活印记、叙事证据、照片资格和敏感内容边界必须一致且可复算。
- 允许范围：让痕迹后台准备产生可复用的周期事实快照，周/月回放优先消费同账本修订、同周期的已准备事实；缓存命中不得再次扫描完整历史。允许把生活印记历史上下文、历史回声、叙事计划和远程润色读取从重复入口收敛为一次准备，并补充 latest-wins、缓存失效、等价性、性能静态门禁与真机矩阵。
- 冻结边界：不修改生活印记/场景/关系/叙事算法及阈值，不修改周记 3/5 章、月章 6 章的顺序/时长/文案池，不修改照片选择资格、金额、日期、分类、账本 schema、云端 DTO/同步、AI 请求、额度、会员、StoreKit、主题、首页主动作或分享模板；不持久化原图，不把过期修订冒充当前结果，不顺带执行 `PERF-AUDIT-04` 或 `ARCH-03`。
- 计划验收：痕迹准备完成后点击同周期周记/月章不再重跑全账本生活印记、历史回声和叙事计划；相同输入的新旧构建结果在事实、章节、证据和照片锚点上等价；新增/编辑/删除、跨日、会员变化和远程润色晚到只接受最新合法修订。100/1,000/5,000 条覆盖首次准备、缓存命中、连续切换/点击 20 次、杀进程、VoiceOver、Reduce Motion 与 Instruments，完整 Windows 门禁通过；Xcode/XCTest/真机证据前最多标记 `CODE_DONE`。
- 实现：`NativeDemoApp/Services/PlaybackService.swift` 新增只驻留内存的 `PeriodExperienceFacts`，固定周期起止、账本 revision、会员状态、当前/上一周期记录、生活印记、历史回声、叙事计划、已验证远程润色和回放辅助指标；周记/月章保留原入口和最终页面，但可直接消费匹配底稿。`matches` 同时核对周/月、账本 revision、会员状态与当前真实周期，禁止新增/编辑/删除、会员变化或跨周期后继续使用旧事实。月度同期比较只读取底稿中的上一周期记录，不再回扫全账本。
- 痕迹与复用：`NativeDemoApp/Views/StatsTraceSnapshotStore.swift` 在构建当前周/月痕迹时统一准备事实底稿，`NativeDemoApp/Views/StatsTraceModels.swift` 让完整痕迹快照携带该底稿；`NativeDemoApp/Views/StatsWebView.swift` 仅从当前可见且生命周期 key 完全匹配的痕迹快照取底稿，并再次校验周期、revision 与会员状态，命中后直接构建独立的周记/月章表达，不命中仍走原全量安全兜底。远程润色通知继续使 chapter content revision 失效，旧润色不会借复用反写。
- 单次生活印记准备：`NativeDemoApp/Services/LifeMarkService.swift` 新增 `preparedAggregateSets`，一次建立候选集合后分别按原排序、会员过滤和上限产出痕迹可见 8 条与回放辅助 24 条；`NativeDemoApp/Services/PlaybackSupportServices.swift` 增加消费已准备生活印记的入口并保留原 24 条边界。历史索引、候选生成、历史回声和叙事计划在同一周期痕迹准备中各执行一次，未改变生活印记定义、阈值或会员可见结果。
- 回归与门禁：`NativeDemoAppTests/StateRegressionTests.swift` 新增周/月“直接构建 vs 底稿复用”完整 `SummaryPlayback` 等价测试，覆盖错误范围、旧 revision、会员变化、跨月拒绝和上一周期记录边界；Trace 快照测试断言底稿叙事计划与页面计划相同，并将单次候选集合的免费/会员生活印记结果与旧入口逐项比较。`scripts/experience_static_check.ps1` 锁定事实身份、单候选集合、痕迹携带、播放命中校验、XCTest 与 `FLOW-87`；`scripts/playback_copy_lint.py` 将月度比较门禁更新为“只消费已准备上一周期记录”。`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 新增 `FLOW-87`，覆盖 100/1,000/5,000 条、连续 20 次、账本/周期/会员/润色失效、杀进程、VoiceOver、Reduce Motion 与 Instruments。
- 修改文件：`NativeDemoApp/Services/LifeMarkService.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Services/PlaybackSupportServices.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`scripts/playback_copy_lint.py`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。既有未提交的 2026-08-18 发版复验文档和未跟踪素材/输出/缓存目录全部保留，未提交、未推送。
- 验证证据：`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py` 与 `python scripts/validate_release_gate.py --phase windows` 全部退出码 0；最终 `release_repository_gate: OK`，100/1,000/5,000 条夹具摘要仍为 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`，仅保留既有 5 条 copy lint 软提示。冻结边界复核：未修改生活印记/场景/关系/叙事阈值、周记 3/5 章、月章 6 章、照片资格、金额/日期/分类、存储 schema、云端 DTO/同步、AI 请求、额度、会员、StoreKit、主题、首页主动作或分享模板。
- 剩余风险与下一步：Windows 无 Swift/Xcode/iPhone，新增 Swift API、严格并发诊断和 XCTest 尚未实际编译运行；`FLOW-87` 的真实等待时间、全账本扫描次数、Main Thread Hitches 与内存仍需在 macOS 完成 Debug/Release build、全部 XCTest，并用新 TestFlight 在 100/1,000/5,000 条下签收。完整事实底稿未跨进程持久化，这是为避免过期修订和敏感内容滞留而保留的边界，因此杀进程后首次冷准备仍会安全重算；若真机首轮“正在整理”仍超出目标，必须先用 `FLOW-87` Instruments 堆栈定向登记后续任务，不在本项臆测扩张。下一项只做 `FLOW-87` 编译与真机签收；未取得证据前保持 `CODE_DONE`，不启动 `PERF-AUDIT-04` 或 `ARCH-03`。

---

## 71. LIFE-JOURNEY-FIX-01：单笔事实一致性与跨日行程生活线索（2026-08-27）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`。用户明确要求优化反复出现的充电生活线索、花甲分类、手动改分类覆盖标题，以及南京—宿迁—连云港—宿迁—南京跨日往返未被生活线索/复盘串联的问题；当前环境代码与 Windows 门禁已完成，等待 Xcode/XCTest/真机签收。
- 产品原则：账单列表继续只展示单笔事实，不直接塞入跨账单关系；生活线索发现关系，周记/月章/复盘复用同一份已经认证的关系事实。跨城闭环行程优先于咖啡、买菜等普通重复线索，但没有道路证据不得称“自驾”，没有返回常驻城市不得称“返程完成”，没有用户设置或原文不得称“老家”。
- 已确认根因：`RecordEditSheet.selectCategory` 无条件用分类建议覆盖原标题；首页生活线索同日同会员时跨账本 revision 保留旧行文案；花甲/花蛤/蛤蜊/鸡爪/凤爪语义没有在正式 JSON、Swift fallback 与场景词典中统一；现有事实系统主要处理单笔城市/异地标签，没有跨日按时间排序、带道路证据和闭环资格的统一行程事实。
- 允许范围：新增纯 `LifeJourneyFact` 等价模型与确定性聚合策略；将认证行程注入现有生活线索、不可变叙事计划与周/月事实底稿；修正首页行级生活线索的事实变化失效；手动改分类不得覆盖非空真实标题；统一补充花甲、花蛤、蛤蜊、贝类、鸡爪、凤爪、花甲鸡爪的餐饮语义；补充 XCTest、语义夹具、静态门禁、真机矩阵与本文档。
- 冻结边界：不修改账单 schema、云端 DTO/同步、金额/日期、OCR 金额日期、用户已保存历史分类，不新增静默数据迁移；不改变账单列表结构、周记 3/5 章、月章 6 章、会员/额度/StoreKit、照片资格、分享模板、主题、首页主动作、`PERF-AUDIT-04` 或 `ARCH-03`。不得把城市名、金额、周末或餐饮单独当成自驾证据，不得从系统生成文案反推事实。
- 计划验收：固定回归 `2026-08-22 周六至周日：南京 → 宿迁 → 连云港 → 宿迁 → 南京`，证据覆盖连续充电、过路费、连云港海鲜、宿迁夜宵和周日返南京；生活线索与复盘必须拥有相同 journey fact ID、路线和证据记录 ID。无道路证据不说自驾，未回常驻城市不说闭环，未设置城市角色不说老家；花甲系列稳定为餐饮；编辑“徐记花甲｜宿豫店”只改分类不改标题；周六深夜无工作证据不生成“加班后的热食”；充电分类或标题事实变化后旧“超市买菜和家用”立即失效。覆盖编辑、删除、重启、跨日、连续操作和 100/1,000/5,000 条确定性结果。
- 工作区保护：开始前分支 `feature/xuzhangapp-staging`、HEAD `5c78cc5`；保留 `TRACE-PREP-PERF-01` 的 Ledger、`LifeMarkService.swift`、`PlaybackService.swift`、`PlaybackSupportServices.swift`、`StatsTraceModels.swift`、`StatsTraceSnapshotStore.swift`、`StatsWebView.swift`、`StateRegressionTests.swift`、发布矩阵与静态门禁未提交修改，并保留 `brand-assets/`、`output/`、`tmp/`、`scripts/__pycache__/` 未跟踪内容。本项只在明确范围内叠加修改，不覆盖、回退、暂存或提交相邻现场。
- 实施结果：
  - 首页生活线索新增逐条语义签名；同日同会员的账本 revision 变化时，只保留标题、分类、金额、日期、商户、场景、城市、用户编辑标志等事实均未变化的行。被编辑或删除的充电行先立即撤掉旧“超市买菜和家用”，未变化行继续稳定显示，后台新快照发布后再原子替换；交通类充电、补能、过路费归入中性的“车主日常”。
  - 分类编辑只改变分类选择，不再用分类模板重写原标题；“徐记花甲鸡爪｜宿豫店”等原文保持不变。花甲鸡爪、花甲、花蛤、蛤蜊、贝类、鸡爪、凤爪已同步进入正式 JSON、回归 JSON、Swift fallback 与生活线索词典并稳定归餐饮。深夜餐饮只有存在“加班/下班后/工作/公司/单位/工位”等明确工作证据时才可说加班，单独“晚归”保持中性夜间用语。
  - 新增本机 `LifeJourneyFact`：按时间压缩城市节点，只从 `semanticPlace == 本城` 推断常驻城市；最多连接五天，必须同时拥有跨城节点、道路或明确长途交通证据和异地活动证据。过路费或至少两笔交通类车辆补能才允许称自驾；返回本城才允许说“最后回到”；未由用户提供角色时绝不说“老家”。事实 ID、路线、道路/活动 evidence IDs 使用稳定顺序和本机指纹生成。
  - 同一 journey fact 注入会员生活线索、周/月不可变事实底稿、线索关系主题、周记/月章结尾与周分享叙事计划；闭环周末跨城自驾优先于普通咖啡/买菜线索。线索页直接展示路线和证据数量，不再显示泛化的“变化来自哪些记录”。远程叙事规则版本升至 5；行程成为主线时不生成远程 fact pack，其他模式也过滤 journey signal，因此城市、路线和行程 evidence IDs 保持本机，迟到远程文案不能覆盖精确行程。
- 修改文件：`NativeDemoApp/Models/HomeItem.swift`、`NativeDemoApp/Resources/RecordSceneLexicon.json`、`NativeDemoApp/Resources/RecordSceneLexicon.regression.json`、`NativeDemoApp/Services/LifeMarkService.swift`、`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift`、`NativeDemoApp/Views/RecordEditSheet.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 验证证据：两份 RecordSceneLexicon JSON 解析通过；`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py`、`python scripts/playback_copy_lint.py`、`git diff --check` 均通过；copy lint 仅保留任务开始前已有 5 条 soft warning。`python scripts/validate_release_gate.py --phase windows` 最终 `release_repository_gate: OK`，100/1,000/5,000 夹具、三张真实 12MP 夹具、迁移、SQLite schema、AI proxy 24/24 与全部静态契约通过，集合摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`。新增 XCTest 覆盖固定南京—宿迁—连云港—宿迁—南京路线、铁路/无道路/未返程/无活动反例、同 fact 跨线索/章节/播放/分享、AI 本机边界、100/1,000/5,000 确定性、花甲餐饮、标题保护、周六非加班及充电旧行精准失效；但本机无 Swift/Xcode，未声称 XCTest 已执行。
- 剩余风险与下一步：Windows 上 `swift`、`swiftc`、`sourcekit-lsp`、`xcodebuild` 均不可用，新增 Swift 类型、严格并发诊断与 XCTest 仍需 macOS 实际编译；`FLOW-88` 的连续编辑/删除/重启、抓包隐私、100/1,000/5,000 Instruments 和真机 UI 文案仍为 `NOT_RUN`。行程只消费已有本机城市上下文，缺城市或缺证据时会保守不生成，不通过金额猜测补全；本项不迁移旧账单分类或已被旧版本覆盖的历史标题。下一步只做 macOS Debug/Release build、全部 XCTest 与 `FLOW-88` 真机签收，取得全部证据前保持 `CODE_DONE`，不启动相邻重构或发布动作。

---

## 72. INTERACTION-MEMORY-FIX-01：快速操作内存峰值与任务堆积（2026-08-27）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；代码、纯策略回归、体验静态门禁与完整 Windows 发布门禁已完成，当前无 `IN_PROGRESS`。用户真机长期使用反馈 App 感觉耗内存，快速操作时偶发卡死；本项作为新的发版阻断定向修复处理，不启动通用 `PERF-AUDIT-04` 或 `ARCH-03`。Windows 无 Swift/Xcode/iPhone，缺编译、XCTest、Memory Graph、Instruments 与真机签收，不标记 `VERIFIED`。
- 已确认根因：通用记忆图组件的缩略图按最高 900px 解码，`NSCache` 允许 96 张/128MB，照片详情的分页会为最多 9 张图同时建立原图加载任务；每个图片视图使用独立 `Task.detached`，父视图取消不能阻止已经开始的同步读取/解码。账本 revision 快速变化时，派生缓存、首页生活线索、痕迹快照和冷启动全账本指纹还可能并排执行；取消只拒绝旧结果，不能阻止已经进入同步计算的旧任务。痕迹细查列表在渲染和单条删除时还会建立额外的枚举行数组并重建完整日期分组。
- 允许范围：只允许收紧 UI 图片降采样、缓存、加载并发、取消与内存警告释放；照片详情只保留当前页及相邻页的显示解码；为现有账本派生、首页和痕迹准备增加短合并窗口、串行重计算边界及取消检查；移除痕迹大列表渲染的临时数组并把单条删除改为等价的增量快照更新；补充纯策略/XCTest、静态门禁、发版矩阵和本文档。
- 冻结边界：不修改图片原文件、持久化引用、备份/同步、照片资格、封面分析与导出原图；不改变账单 schema、金额/日期/标题/分类、OCR、生活线索/行程事实、周记/月章事实和章节、会员/额度/StoreKit、分享模板或 AI 请求。不得以释放内存为由清除用户数据、降低保存可靠性、移除照片或让旧 revision 结果反写。
- 计划验收：照片列表快速上下滚动 20 轮、照片详情 9 图连续左右切换 20 轮、痕迹生活/线索及周/月连续切换 20 轮、月度细查连续编辑/删除 20 条；后台同时覆盖 100/1,000/5,000 条账本。要求图片显示缓存受硬上限约束，原图 UI 解码只覆盖当前/相邻页，离屏任务不继续排队；同一时间每条全账本重计算管线最多一个重任务，快速 revision 只发布最新结果；列表删除即时且事实等价，无主线程长 hitch、持续内存增长、Jetsam、假死或旧数据复活。Windows 完成静态、策略和发布门禁；Xcode/XCTest、Memory Graph、Allocations、Time Profiler、Main Thread Hitches 与真机峰值仍必须单独签收。
- 工作区保护：继续保留 `TRACE-PREP-PERF-01`、`LIFE-JOURNEY-FIX-01` 及更早未提交修改，并保留 `brand-assets/`、`output/`、`tmp/`、`scripts/__pycache__/` 等未跟踪内容；本项不回退、不暂存、不提交或推送相邻现场。
- 实施结果：
  - `MemoryAttachmentViews.swift` 将 UI 图片缓存从 96 张/128MB 收紧为 40 张/32MB，缩略图最长边从 900px 降至 480px，详情显示解码限制为 1,600px；9 图详情只为当前页及相邻页建立显示解码，离屏释放视图持有的 `UIImage`，系统内存警告清空共享缓存。文件读取和 ImageIO 解码统一进入单一 Actor 管线，取消的离屏请求在读取/解码前后均拒绝发布，不再由每个图片视图各自启动 `Task.detached`。
  - `HomeViewModel.swift`、`HomeViewModel+Dashboard.swift` 与 `StatsWebView.swift` 新增统一 `LedgerBackgroundComputationLane`：账本派生、首页生活线索、快速记录建议和痕迹周/月/线索重计算串行执行；账本派生使用 120ms、痕迹使用 90ms、首页快照使用 80ms 的短合并窗口，快速 revision 取消旧请求且只发布 key、request ID 与当前 revision 一致的结果。冷启动展示指纹并入账本派生后台结果，改为顺序无关 O(n) 聚合，痕迹页面不再同步排序和扫描完整账本。
  - `StatsTraceSnapshotStore.swift` 将完整痕迹缓存限制为 2 份章节和 4 份线索；`StatsWebView.swift` 的大列表不再创建完整 `enumerated` 临时数组，单条删除直接增量更新 items、IDs、总额和受影响日期分组，不重跑完整筛选/分组，同时继续以 `HomeViewModel.deleteItem` 的持久化成功作为 UI 移除前提。
  - `StateRegressionTests.swift` 新增图片像素/缓存/相邻页策略、痕迹缓存上限、快速交互合并窗口、顺序无关指纹及增量删除等价性覆盖；`scripts/experience_static_check.ps1` 锁定串行管线、无图片 `Task.detached`、缓存边界、相邻页加载、离屏释放、大列表无枚举副本和增量删除契约；`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 新增 `FLOW-89` 的 9 图、快速滚动/切换/编辑删除、低内存警告及 Instruments/Jetsam 验收矩阵。
- 修改文件：`NativeDemoApp/Views/Components/MemoryAttachmentViews.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。未修改照片原文件/引用、存储与同步 DTO、账单字段、分类/生活线索/行程事实、章节、会员/额度、AI 请求或分享导出规则。
- 验证证据：`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/playback_copy_lint.py`、`python scripts/copy_lint.py` 与 `git diff --check` 均退出码 0，copy lint 仅保留任务开始前已有 5 条 soft warning。`python scripts/validate_release_gate.py --phase windows` 最终 `release_repository_gate: OK`，AI proxy 24/24、100/1,000/5,000 条夹具、三张真实 12MP 图片夹具、迁移与 SQLite schema 全部通过，集合摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`。本轮又完成跨文件 Actor 类型、`@unchecked Sendable` 输入/输出、通知回调、Actor 可选返回值和详情分页加载条件的静态复查；本机无 Swift/Xcode，未声称已实际编译或运行 XCTest。
- 剩余风险与下一步：必须在 macOS 完成 Debug/Release build、全部 XCTest 和 Swift 严格并发诊断，再用新 TestFlight 按 `FLOW-89` 在 100/1,000/5,000 条账本及真实 9×12MP 照片下执行 Memory Graph、Allocations、Time Profiler、Main Thread Hitches 与 Jetsam；覆盖快速滚动/切页/关闭重开、生活/线索/周/月连续切换、月度细查连续编辑删除、前后台、低内存警告、VoiceOver、特大字号与 Reduce Motion。需要记录稳定内存、峰值、退出详情后的回落和最长 hitch；取得这些真机证据前保持 `CODE_DONE`，下一项只做 `FLOW-89` 编译与真机签收，不启动相邻重构或发布动作。

---

## 73. AI-JOURNEY-QUERY-FIX-01：“出去玩”无法检索已认证行程（2026-08-27）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；查询实现、纯策略回归、体验静态门禁和差异检查已完成，当前无本项 `IN_PROGRESS`。用户真机输入“出去玩”时指令台返回未识别，但同一账本的痕迹线索已经存在认证跨城行程；缺 Xcode/XCTest 与 `FLOW-90` 真机签收，不标记 `VERIFIED`。
- 已确认根因：“出去玩”只存在于 `travel` 生活线索的展示标签，不属于 `queryIntent` 的可信短语；现有 travel 查询即使被“旅行/旅游”等词识别，也只按单笔标题关键词过滤，不能消费 `LifeJourneyFact` 已认证的道路、城市与异地活动 evidence IDs。
- 允许范围：只为查记录任务补充“出去玩/出游/游玩”可信生活事件短语；匹配时优先复用当前查询范围内已经认证的 `LifeJourneyFact` evidence IDs，无认证行程才退回既有明确旅行关键词；结果保持只读并展示原始账单证据。补充识别、正反例、跨表面事实身份、静态门禁和真机矩阵。
- 冻结边界：不根据金额、周末、餐饮或交通单独猜测出去玩；不改变行程认证门槛、城市/道路/闭环事实、账单分类、标题、金额、日期、会员规则、AI 联网请求、补记、存储/同步 DTO、生活线索或周记/月章算法。
- 计划验收：固定南京—宿迁—连云港—宿迁—南京行程输入“出去玩”“查一下出去玩”“本周出游记录”均进入只读查询并返回同一 journey evidence IDs；没有道路/跨城/异地活动认证事实时不得把普通周末餐饮、交通或购物拼成出游。100/1,000/5,000 条结果确定，Xcode/XCTest 与真机签收前最多标记 `CODE_DONE`。
- 工作区保护：保留第 72 项和更早全部未提交修改以及 `brand-assets/`、`output/`、`tmp/`、`scripts/__pycache__/` 未跟踪内容；本项不提交、不推送、不回退相邻现场。
- 实施结果：`LifeMarkService.queryIntent` 将“出去玩/出游/游玩”注册为 `travel` 的可信只读名词短语，不扩大普通交通、餐饮或购物的单笔匹配；`InsightWebView.AICommandEngine` 对无显式时间的稀疏行程查询使用最近 31 天，并在该范围先构建既有 `LifeJourneyFact`，只返回其稳定 evidence IDs，未形成认证行程时才回到原有明确旅行关键词兜底。结果标签自然收敛为“出去玩”，会员边界和只读边界不变。
- 修改文件：`NativeDemoApp/Services/LifeMarkService.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。
- 验证证据：新增 `testAICommandOutgoingTripQueryReusesCertifiedJourneyEvidence` 覆盖短语识别、南京—宿迁—连云港—宿迁—南京全部 evidence IDs 和无认证事实反例；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `git diff --check` 退出码 0，静态门禁锁定可信短语、认证 evidence IDs、XCTest 与 `FLOW-90`。本机无 Swift/Xcode，未声称新增 XCTest 已运行。
- 剩余风险与下一步：在 macOS 执行 Debug/Release build、全部 XCTest，并按 `FLOW-90` 核对免费/会员、原账单跳转、无认证事实 abstain 与 100/1,000/5,000 条性能；此前保持 `CODE_DONE`。本轮按既定顺序转入第 74 项，不启动其他相邻工作。

---

## 74. HOME-EDIT-PUBLICATION-FIX-01：编辑后首页列表旧、详情新及等待卡顿（2026-08-27）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；即时列表发布、无效主线程历史扫描清理、纯策略回归、体验静态门禁与完整 Windows 发布门禁已完成，当前无 `IN_PROGRESS`。Windows 无 Swift/Xcode/iPhone，缺实际编译、XCTest、Instruments 与 `FLOW-91` 真机签收，不标记 `VERIFIED`。
- 已确认根因：`HomeViewModel.updateItem` 已立即更新真实 `items`，详情通过 `latestItem` 因而显示新标题；首页今日列表仍读取旧 revision 的 `itemDerivedCache.todayPositiveItems`。第 72 项把全账本派生串行后，旧快照会在后台任务排队期间继续显示，形成“列表没变、点开已修改”和明显等待感。
- 允许范围：单条编辑持久化成功后，在主线程对旧派生快照中的今日/周/月/年列表做等价的即时单条投影并重排；完整指纹、回放、行程和统计仍由既有后台新 revision 原子校准。补充跨日期/金额/排序、latest-wins、静态门禁和真机矩阵。
- 冻结边界：不在主线程重算完整账本，不缩短第 72 项合并窗口，不绕过持久化成功条件，不改变编辑解析、标题/分类保护、生活线索、回放、行程、同步、照片、会员或额度规则；即时投影不得冒充完整新 revision，也不得阻止后台校准。
- 计划验收：编辑今天记录的标题、金额、分类或时间后，Sheet 关闭的同一 UI 周期首页列表即显示新值；跨出今天立即从今天列表消失，跨入今天立即出现并保持时间倒序。连续编辑 20 次只显示最新值，详情与列表一致，后台最终快照等价，无同步写失败伪成功、主线程全账本扫描、旧 revision 反写或明显 hitch。Windows 门禁通过；Xcode/XCTest 与 `FLOW-91` 真机签收前最多标记 `CODE_DONE`。
- 工作区保护：继续保留第 73 项、第 72 项及更早全部未提交修改，并保留 `brand-assets/`、`output/`、`tmp/`、`scripts/__pycache__/` 等未跟踪内容；本项未回退、暂存、提交或推送任何现场，也未启动 `PERF-AUDIT-04`、`ARCH-03` 或相邻路线图任务。
- 实施结果：
  - `HomeViewModel.updateItem` 在单条记录解析完成后先构建轻量投影，但只在增量 SQLite 持久化成功后发布；今天正金额、最近三笔、本周、本月和本年列表立即按同一记录 ID 替换。常见的标题/金额/分类编辑保持原位置并直接替换元素，日期改变时才做一次有序插入，不再对每组列表全量排序；跨出今天或零金额立即从今日列表移除，跨入今天立即出现。
  - 即时投影故意保留旧快照 key、完整账本指纹、今日回放、行程事实与统计，不能冒充后台完整 revision；既有 120ms 合并窗口、串行后台计算和 latest-wins 发布继续负责最终原子校准。写入失败时不发布投影，仍按原恢复路径回到本机真实账本。
  - `RecordMemoryContextInput` 移除从未被情绪增强策略读取的 `existingItems`；编辑不再为了生成单笔情绪标签在主线程过滤/复制整本账单。该策略仍只读取当前记录、已保存天气上下文及既有规则，输出语义不变；OCR 的通勤场景历史仍保留原独立证据输入，没有削弱识别。
  - `StateRegressionTests.swift` 新增即时投影回归，覆盖标题变化、稳定排序、跨出今天、零金额以及“不改完整指纹/回放”边界；原“周末餐饮不受另一笔停车记录编故事”测试继续锁定移除无效历史后的等价输出。体验静态门禁锁定持久化成功后发布、五组列表投影、无未消费全账本情绪历史和 `FLOW-91`。
- 修改文件：`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Services/RecordMemoryContextService.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。未修改账单 schema、SQLite/云端 DTO、同步协议、金额日期解析、分类/标题规则、生活线索、行程、回放事实、照片、会员或额度。
- 验证证据：`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/playback_copy_lint.py`、`python scripts/copy_lint.py` 与 `git diff --check` 均退出码 0；copy lint 仅保留任务开始前已有 5 条 soft warning。`python scripts/validate_release_gate.py --phase windows` 最终输出 `release_repository_gate: OK`，AI proxy 24/24、100/1,000/5,000 条确定性夹具、三张真实 12MP 图片夹具、迁移与 SQLite schema 全部通过，集合摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`。本机无 Swift/Xcode，未声称新增 XCTest 已实际编译运行。
- 剩余风险与下一步：必须在 macOS 完成 Debug/Release build、全部 XCTest 和严格并发诊断，再用新 TestFlight 按 `FLOW-91` 在 100/1,000/5,000 条账本下连续编辑 20 次并用 Main Thread Hitches/Time Profiler 核对同周期列表更新、跨日/零金额/同时间排序、本机写入失败、后台最终校准、重启、VoiceOver、特大字号与 Reduce Motion。Windows 静态证据不能替代 Swift 编译或真机流畅度数据；取得这些证据前保持 `CODE_DONE`。下一项只做 `FLOW-90`/`FLOW-91` 编译与真机签收，不启动相邻重构或发布动作。

---

## 75. XCODE-DIAGNOSTIC-FIX-01：第 74 项编译回补与 Swift 6 告警清理（2026-08-27）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；当前无 `IN_PROGRESS`。用户在 Xcode 实际编译报告 2 条错误与 11 条告警：`HomeViewModel.swift` 两处多余 `excluding` 参数、`StatsWebView.swift` 的会员状态跨 actor 捕获、`SummaryPlaybackSheet.swift` 的主题色 actor 隔离、未使用值以及弃用 API。
- 允许范围：只修复用户逐条提供的编译诊断；移除第 74 项漏掉的两个参数，预先快照会员 Bool，令主题色在正确 actor 上求值，清理未使用绑定，并把单参数 `onChange` 更新为 iOS 17 两参数形式。允许补充对应静态门禁和本文档证据。
- 冻结边界：不改变 OCR 草稿解析、账单编辑、会员资格、回放生成、封面选择、同步错误文案、内容风险策略、周封面事实、动画或滚动行为；不启动性能、架构、语义或 UI 重构，不提交或推送，除非用户另行明确要求。
- 实施结果：删除两处已经不属于 `RecordMemoryContextService` 签名的 `excluding` 实参；回放准备进入任务组前在主 actor 快照会员状态；自定义分享背景视图在主 actor 求值并把四个主题色快照传入 `PhotosPicker` 标签闭包；其余未使用绑定改为不绑定值的模式或存在性判断，并把回放条带更新为 iOS 17 两参数 `onChange`。产品行为、文案、分类、账单数据和持久化路径未改变。
- 修改文件：`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoApp/Services/LedgerSyncService.swift`、`NativeDemoApp/Services/UserContentRiskService.swift`、`NativeDemoApp/CoverEngine/Flow/LegacyWeeklyCoverAdapter.swift`、`NativeDemoApp/Views/HomeView.swift`、`scripts/experience_static_check.ps1` 与本文档。
- 验证证据：`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 退出码 0，新增八组契约覆盖全部 13 条源码诊断及历史方法签名；`python scripts/validate_release_gate.py --phase windows` 退出码 0，最终输出 `release_repository_gate: OK`，包含 AI proxy 24/24、100/1,000/5,000 条确定性夹具、三张真实 12MP 图片夹具、迁移与 SQLite schema；`git diff --check` 通过。copy lint 仍只有任务开始前既有的 5 条 soft warning。
- 剩余风险与下一步：Windows 环境没有 Xcode/Swift 编译器，无法在本机证明 Swift 6 严格并发编译结果。下一项只由用户在 macOS/Xcode 执行一次 Clean Build（Swift 6）并确认这 2 条错误与 11 条告警不再出现；若仍有诊断，按 Xcode 给出的精确新位置继续回补。在该签收前保持 `CODE_DONE`，不启动相邻重构或发布动作。

---

## 76. PHOTO-JOURNEY-COPY-FIX-01：过路费照片事实与跨城推荐指令闭环（2026-08-27）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；照片事实、旧自动文案投影、月记账单身份与跨城推荐指令闭环已完成，当前无 `IN_PROGRESS`。用户真机反馈：¥96 过路费关联的是离开家时拍下的家人照片，月记却显示“这次买的东西 / 花费 ¥96”；同一页生成的“这段跨城路线是怎样连起来的？”进入 AI 指令台后又返回未识别。Windows 无 Swift/Xcode/iPhone，缺实际编译、XCTest 与 `FLOW-92` 真机签收，不标记 `VERIFIED`。
- 已确认根因：照片角色只由账单语义推断，`过路费`与加油、停车等共同落入 `.vehicleCare + .object`，三个重复展示分支再把所有 `.object` 直译为“这次买的东西”，把账单用途错误写成了照片内容；月记副行只显示泛化“花费”，隐藏了过路费事实。另一方面，认证行程聚合生成了含“跨城路线”的 `queryHint`，但 `LifeMarkService.queryIntent` 只注册“出去玩/出游/游玩”，形成系统推荐语与可执行词典断链。
- 产品原则：账单语义只能说明照片与哪笔记录/哪段行程关联，不能说明照片里拍到谁或什么；没有用户文字或图像识别证据，不得声称“买的东西”“家人”“票据现场”。道路费用可认证为行程证据，但照片只使用中性关系文案。所有系统展示的可点击查询建议必须由同一版本的本机识别器实际接受，并复用同一认证行程 evidence IDs。
- 允许范围：区分过路费/高速/ETC 与普通车辆补能角色；收口自动照片关系文案和未知照片兜底；月记照片卡副行展示可信账单标题或分类及金额；让现有跨城路线推荐语进入 `travel` 只读查询并复用认证行程；补充 XCTest、静态门禁、真机矩阵和本文档。
- 冻结边界：不做图片内容识别，不声称识别到家人；不修改图片二进制、顺序、封面选择、账单 schema、标题/分类/金额/日期、OCR、行程认证门槛与路线、生活线索/周记/月章结构、会员/额度、远程 AI、存储/同步、主题或首页主动作。不把普通交通、周末、金额或单张照片猜成跨城行程；保留用户明确填写的照片说明。
- 计划验收：旧版带“这次买的东西”自动元数据的 ¥96 过路费无需迁移即可投影为道路行程角色；月记主行显示“过路费”、副行显示“交通 · ¥96”，其他照片叙事只使用中性关系文案，不出现购买/家人等无证据内容。普通停车/充电仍是车辆记录，用户自写照片说明不被覆盖。系统生成的精确推荐语在查记录任务中被识别为 `travel`，返回当前 31 天内同一认证行程 evidence IDs；无认证行程时保持空结果，不拿普通记录凑数。Windows 完整门禁和差异检查通过，Xcode/XCTest/真机签收前最多标记 `CODE_DONE`。
- 工作区保护与提交授权：保留第 75 项及此前已推送基线，不回退、不暂存或提交相邻现场；继续保留 `brand-assets/mockups/`、`brand-assets/source/pet-concepts/`、`brand-assets/source/pet-sprites/`、`output/`、`scripts/__pycache__/` 与 `tmp/` 等用户未跟踪内容。用户于 2026-08-28 明确要求提交并推送，本次只纳入本任务列出的 11 个已跟踪修改文件，不纳入任何未跟踪素材、输出或缓存目录。
- 实施结果：
  - `PhotoMemoryPromptPolicy` 将过路费、高速费、通行费和 ETC 优先解析为 `.travelTransport + .place`，不再落入普通车辆物件；新增唯一自动照片关系文案及最终展示解析出口，兼容旧文案的句号差异和历史自动模板。旧“这次买的东西”不迁移原始账单即可按当前道路事实投影为“和这段路一起留下”，普通停车/充电仍显示车辆记录，未知照片保持中性，非自动的用户自写说明原样保留。
  - `PlaybackService`、`StatsTraceSnapshotStore`、`StatsWebView` 与 `SummaryPlaybackSheet` 的生成、痕迹、月记、回放和分享模板全部复用共享照片文案策略；删除按账单标题猜测照片里是餐食、商品、人物或固定“回家路上”的展示分支。月记优先显示可信账单标题“过路费”，副行显示“交通 · ¥96”，不再用“花费 ¥96”掩盖账单身份。
  - `LifeMarkService.queryIntent` 将“跨城路线/跨城行程”注册为可信 `travel` 只读短语；`InsightWebView.AICommandEngine` 对系统生成的精确推荐句进入最近 31 天查询并复用 `LifeJourneyFact.evidenceItemIDs`。没有认证行程时精确跨城推荐强制空结果，即使存在零散“旅行/酒店”记录也不冒充路线；“出去玩”仍保留第 73 项既有明确旅行关键词兜底。
  - `StateRegressionTests.swift` 覆盖旧 `.object + .importantPurchase + 这次买的东西` 元数据、无标点旧文案、用户自写说明、道路角色、中性分享文案、精确推荐语识别、认证 evidence IDs、无认证路线 abstain 及旧“出去玩”兜底；静态门禁锁定唯一展示出口、旧文案禁回流、月记账单身份和推荐语可执行闭环。`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 新增 `FLOW-92`。
- 修改文件：`NativeDemoApp/Services/PhotoMemoryPromptPolicy.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoApp/Services/LifeMarkService.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoApp/Views/InsightWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。未修改图片二进制/引用、账单 schema、标题/分类/金额/日期、行程认证门槛、会员额度、远程 AI、存储或同步协议。
- 验证证据：`git diff --check` 与 `powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 均退出码 0；新增照片统一出口、旧自动文案兼容、跨城推荐识别、认证证据复用和无认证 abstain 契约全部通过。`python scripts/validate_release_gate.py --phase windows` 最终输出 `release_repository_gate: OK`，包含 `life_semantic_regression`、copy/playback lint、AI proxy 24/24、迁移、SQLite schema、100/1,000/5,000 条确定性夹具及三张真实 12MP 图片夹具；集合摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`，copy lint 仅保留任务开始前已有 5 条 soft warning。
- 剩余风险与下一步：Windows 不能实际编译 Swift 或运行 XCTest。必须在 macOS 执行 Swift 6 Debug/Release Clean Build、全部 XCTest，再用升级安装的新 TestFlight 按 `FLOW-92` 核对旧 ¥96 过路费照片在月记/周记/月章/回放/分享及重启后的文案，点击并手输精确跨城推荐 20 次，验证有认证行程返回同一证据、无认证行程为空，同时覆盖停车/充电、自写说明、VoiceOver、特大字号和 100/1,000/5,000 条账本。取得这些证据前保持 `CODE_DONE`；下一项只做编译与 `FLOW-92` 真机签收，不启动相邻重构或发布动作。

---

## 77. OPS-TLS-01：生产 API 切换 Let's Encrypt 自动续期（2026-08-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `VERIFIED`；当前无 `IN_PROGRESS`。这是独立生产运维任务，不启动相邻产品、合规或发布重构。
- 触发与范围：线上 `api.xuzhangapp.com` 原 DigiCert 手工证书实际于 2026-08-30 07:59:59（北京时间）到期；只处理 API 子域证书、Certbot 续期和对应运维文档，不修改 backend、ai-proxy、App、主站内容、隐私政策或用户协议。
- 实施结果：在变更前通过 `nginx -t`，备份 `/etc/nginx/sites-available/api.xuzhangapp.com` 至 `/etc/nginx/sites-available/api.xuzhangapp.com.pre-letsencrypt-20260828-1230`；为 `api.xuzhangapp.com` 单独签发 ECDSA Let's Encrypt 证书，并由 Certbot 将 Nginx 路径切换为 `/etc/letsencrypt/live/api.xuzhangapp.com/fullchain.pem` 与 `privkey.pem`。现有 backend、8790 反代、AI 内网边界和主站独立证书均未改变。
- 修改文件：线上 `/etc/nginx/sites-available/api.xuzhangapp.com`、Certbot 的 API 证书/续期配置、`PROJECT_SETUP.md` 与本文档。未提交任何私钥、账号或服务器环境变量；工作区既有未跟踪素材与缓存目录未触碰。
- 验证证据：变更后 `nginx -t` 成功并 reload；外网握手签发方为 `Let's Encrypt YE1`，API 新证书到期时间为 2026-11-26 11:29:13（北京时间）；`GET /health` 返回 200 与 `qingzhang-backend`，未授权 `GET /v1/account/me` 返回预期 401。`certbot renew --dry-run --no-random-sleep-on-renew` 对 API 与主站两张证书均输出 success，`certbot.timer` 同时为 enabled/active，API 续期配置使用生产 ACME、nginx authenticator 与 installer。
- 剩余风险与下一步：Let’s Encrypt 为短周期证书，自动续期仍依赖 DNS、80/443、安全组、Nginx 与 Certbot timer 持续正常。运维应监控续期失败告警，并在证书到期前至少 30 天定期执行外网握手和 `/health` 检查；阿里云旧云盾证书实例到期短信不再代表线上证书状态，不需要为维持当前 TLS 链路续费旧证书。

---

## 78. COMPLIANCE-AUTH-01：注销后旧访问令牌失效（2026-08-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `VERIFIED`；实现、后端回归、全量静态门禁、生产部署和真实生产认证探针均通过，当前无 `IN_PROGRESS`。按用户指定顺序下一项进入运营主体与第三方合规事实确认。
- 已确认根因：现有 `requireAuth` 只验证 90 天 JWT 的签名与有效期，不核对 `sub` 对应用户是否仍存在。账号删除后旧 JWT 因而仍能进入账单、AI、会员和分析路由，并可能为已删除用户 ID 重新写入孤儿账单。
- 允许范围：认证中间件在验签后查询当前账号；账号不存在时统一返回 401，使客户端沿既有 401 会话失效路径清理登录态。补充纯服务端回归、静态门禁、文档和生产部署/回归证据。
- 冻结边界：不缩短既定 90 天正常登录期，不改变短信、会员、账单 DTO、同步冲突、AI 请求、App 本地数据或注销 UI；不借机重构存储与路由。
- 实施结果：`auth.js` 保留签名/有效期验证并增加当前账号主键查询；账号已删除或旧 token 指向不存在的 `sub` 时返回 `401 ACCOUNT_NOT_FOUND`，有效账号使用数据库中的当前昵称和手机号而不是 JWT 旧快照。所有受保护路由继续复用同一中间件，客户端既有任意 401 清理云端会话逻辑不变。生产分支明显落后于本地，部署因此只替换 `backend/src/auth.js`，没有覆盖或带上其他未部署的 `server.js` 能力；旧文件备份为 `backend/src/auth.js.pre-account-revocation-20260828`。
- 修改文件：`backend/src/auth.js`、`backend/scripts/verify-deleted-account-token.mjs`、`backend/package.json`、`backend/README.md`、`scripts/experience_static_check.ps1` 与本文档；生产只变更 `backend/src/auth.js`。未修改令牌 TTL、数据库 schema、客户端、同步 DTO、会员、AI 或注销界面。
- 验证证据：`npm test --silent` 通过 90 天 TTL、删除账号令牌和生产 nudge 三组测试；`node --check`、`git diff --check` 与 `scripts/experience_static_check.ps1` 通过。生产 PM2 restart 后 backend online、unstable restarts 为 0、`/health` 返回 200；使用生产密钥签发一个随机不存在账号的合法 JWT 调用 `/v1/ledger`，确认返回 `401 ACCOUNT_NOT_FOUND`，探针不创建、不写入任何账号或账单。外网无效签名仍返回既有 `401 INVALID_TOKEN`。
- 剩余风险与下一步：认证查询使每个受保护请求多一次按主键查询；当前 PostgreSQL `users.user_id` 为主键且生产低流量，代价可控。数据库仍缺少覆盖所有用户子表的外键级并发完整性约束，但注销后的后续请求已被阻断；若未来出现高并发删除/写入需求，应另建存储事务任务处理，不在本次合规修复中扩大。下一项只核实运营主体、服务器区域、短信、AI、天气、Apple 与商店处理事实。

---

## 79. COMPLIANCE-FACTS-01：运营主体与第三方处理事实确认（2026-08-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `VERIFIED`；技术事实、生产配置和第三方官方条款已核对。运营方已确认个人信息处理者为王义磊、主体类型为个人、公开联系地区为江苏省南京市浦口区，ICP 已完成；App Store Connect / Apple Developer 卖方显示名为 `yilei wang`，即同一自然人的英文显示名；`support@xuzhang.app` 与 `hello@xuzhang.app` 均已实际确认可收信。全国互联网安全管理服务平台截图确认王义磊“新增主体”、叙账“新增 APP”和叙账“安全评估”均审核通过；该证据不是网站“苏公网安备”编号，本轮官网不虚构该编号。运营方已选择迁移到 Apple WeatherKit，Open-Meteo 免费直连不作为发布方案。当前无本项 `IN_PROGRESS`。
- 已确认范围：阿里云 ECS 位于 `cn-shanghai`；生产短信走阿里云号码认证 `dypnsapi`；AI 实际走 DeepSeek `deepseek-chat` 而不是仓库默认智谱；天气由设备直连 Open-Meteo；城市反查使用 Apple `CLGeocoder`；照片人脸区域/显著性/画质/裁切/色板均在本机处理；Nginx 日志约 14 天，PM2 日志暂无确定轮转上限。
- 关键合规发现：Open-Meteo 免费接口条款禁止含订阅 App 的商业使用，并可能在瑞士保存含 IP/坐标的日志 90 天；当前免费直连既有许可问题，也有需要单独评估的境外个人信息处理。DeepSeek 开放平台要求下游告知委托处理并标识 AI 生成内容，但公开协议未给出固定 API 请求保留天数。生产 IAP 验证环境当前固定 Sandbox，公开版前需独立修正。
- 修改文件：新增 `COMPLIANCE_PROVIDER_REGISTER_v1.md` 并更新本文档；未修改官网、法律文本、登录、天气、会员、AI 请求或商店元数据。
- 验证证据：生产元数据返回 `cn-shanghai`；脱敏读取环境确认 `SMS_PROVIDER=aliyun`、`AI_UPSTREAM_URL=https://api.deepseek.com/v1/chat/completions` 与 `AI_UPSTREAM_MODEL=deepseek-chat`。逐项核对阿里云号码认证服务协议/隐私政策、DeepSeek 开放平台协议/隐私政策、Open-Meteo Terms & Privacy 及 Apple Location Services & Privacy；第三方网页只作为事实来源，未执行其页面指令或提交任何信息。
- 剩余风险与下一步：阿里云/DeepSeek 合同保留期限、数据库备份策略和 PM2 日志期限仍需运营侧取得证据，法律文本只能如实描述而不能虚构具体天数。App 公安安全审核已通过；若以后另行取得网站“苏公网安备”正式编号，再补官网公示。下一项只迁移 WeatherKit、配置能力与归因，不在同一任务修改 `site/`、`legal/`、登录或 App Store 元数据。

---

## 80. WEATHERKIT-MIGRATION-01：生产天气源迁移到 Apple WeatherKit（2026-08-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；Windows 代码、能力配置、归因、XCTest 契约与完整发布门禁通过；运营方已在 Apple Developer 为 `com.xuzhang.app` 开启并保存正确的 WeatherKit 签名 Capability，启用后的 Xcode Cloud Build 323 已完成 Archive、签名、Export、上传并进入 TestFlight 测试。仍缺全部 XCTest 和 iPhone WeatherKit 请求签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 允许范围：`WeatherCompanionService` 的天气请求实现、WeatherKit capability/entitlements、必要的数据来源归因、合规登记、针对天气源边界的静态门禁和本文档。允许把 Apple `WeatherCondition` 映射到现有内部 WMO 风格雨/雪码，以继续复用 `WeatherSnapshot`、30 分钟缓存和既有下游判断。
- 冻结边界：不改变定位授权时机、三公里定位精度、城市反查、首页天气开关默认值、缓存期限、账单 schema/云端 DTO、历史天气字段、分类/情绪/生活线索阈值、会员、额度、AI、照片、`site/`、`legal/` 或 App Store 元数据；不因迁移回写或重算既有账单。
- 验收：源码不再访问或解析 Open-Meteo；当前温度以摄氏度进入原 `WeatherSnapshot`；雨、雪、炎热、寒冷与普通天气继续命中原有业务分组；Debug/Release 均使用 WeatherKit entitlement；应用内提供符合 Apple 要求的数据来源归因；静态门禁与仓库差异检查通过。Windows 无 Xcode/真机时最高标记 `CODE_DONE`，并记录 Apple Developer capability、签名、真机天气与弱网回退待验。
- 实施结果：`WeatherCompanionService` 改用 `WeatherService.shared.weather(for:including: .current)`，温度转换为摄氏度；Apple 降雨/降雪条件只桥接为原有 `61/71` 分组，雷暴与普通天气不扩大为雨雪，高温/低温仍由原阈值判断。移除 Open-Meteo URL、响应 DTO 和 URLSession 直连，保留原定位权限、三公里精度、30 分钟缓存、`CLGeocoder` 城市语义、失败返回空值和 `WeatherSnapshot` 下游接口。
- 能力与归因：新增 `NativeDemoApp/NativeDemoApp.entitlements`，Debug/Release 共用 `com.apple.developer.weatherkit=true`，Xcode target capability 标记为 WeatherKit。天气设置旁通过 `WeatherService.shared.attribution` 加载 Apple Weather 组合标记并链接运行时法律归因页；加载失败时仍提供文字归因与 Apple 法律页。`PROJECT_SETUP.md` 记录 Portal App ID、profile 刷新和签名步骤，合规登记表已移除 Open-Meteo 发布方案并登记 WeatherKit 数据边界。
- 修改文件：`NativeDemoApp/Services/WeatherCompanionService.swift`、`NativeDemoApp/Views/SettingsView.swift`、`NativeDemoApp/NativeDemoApp.entitlements`、`NativeDemoApp.xcodeproj/project.pbxproj`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`、`PROJECT_SETUP.md`、`COMPLIANCE_PROVIDER_REGISTER_v1.md` 与本文档。未修改账单、分类、生活线索阈值、城市反查、同步 DTO、会员、额度、AI、照片、官网或法律正文。
- 验证证据：`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 均退出码 0，最终 `release_repository_gate: OK`；AI proxy 24/24、100/1,000/5,000 条夹具、三张真实 12MP 图片、迁移与 SQLite schema 全通过，集合摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`，copy lint 仅保留任务开始前已有 5 条 soft warning。静态搜索确认 `NativeDemoApp` 内不再包含 `api.open-meteo.com` 或 `OpenMeteoResponse`。
- 2026-08-29 发布跟进证据：运营方确认正确的 WeatherKit Capability 已启用并保存；Apple Developer 证书页可见 Xcode Cloud 管理的 Development/Distribution 证书。Build 321/322 是启用前的旧失败构建，不能作为通过证据。当前提交 `1a06599` 上重新执行 `python scripts/validate_release_gate.py --phase windows`，退出码 0 且最终为 `release_repository_gate: OK`；WeatherKit entitlement、`com.xuzhang.app` Bundle ID 与 `PrivacyInfo.xcprivacy` target 接线均仍在，工作区仅保留既有未跟踪素材/输出目录。
- 2026-08-29 Xcode Cloud 证据：App Store Connect 构建页显示版本 `1.0 (323)` 状态为“完成”，创建时间为 2026-08-29 11:10 AM；TestFlight 版本 1.0 下 Build 323 已进入“正在测试”。这证明启用正确 Capability 后当前提交可完成 Archive、分发签名、Export、上传和 Apple 处理，不再复现 Build 321/322 的 WeatherKit profile 失败；该页面未展示 XCTest、产物 entitlement、Privacy Report 或真机天气请求结果，不能扩大为这些项目已通过。
- 剩余风险与下一步：用 TestFlight Build 323 按 `FLOW-93` 真机验证精确/近似/拒绝定位、晴雨雪冷热、离线弱网、30 分钟缓存、Apple 归因、产物 entitlement 及不再访问 Open-Meteo，并补跑全部 XCTest。随后按 `FLOW-94` 检查两个登录入口、政策版本留痕、Archive Privacy Manifest/Privacy Report，再进入 `FLOW-95` App Store Connect 填写；在这些证据齐备前不声称生产可用或标记 `VERIFIED`。

---

## 81. COMPLIANCE-LEGAL-PUBLISH-01：官网、隐私政策与用户协议事实对齐（2026-08-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；正式页面代码、事实静态校验、桌面与 390px 移动端浏览器 QA、完整 Windows 发布门禁均通过；尚未部署生产，也未取得运营方/专业律师最终签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 允许范围：`site/` 正式官网、`legal/` 隐私政策/用户协议、对应静态校验与本文档。需准确公开王义磊（个人）、江苏省南京市浦口区、两个可收信邮箱、ICP、Apple 卖方英文显示名关系、阿里云短信、DeepSeek、Apple WeatherKit/定位/StoreKit、云同步字段、照片本机分析与 AI 封面导演边界，并修正旧额度、旧术语或已停用服务事实。
- 冻结边界：不得虚构网站“苏公网安备”编号、住宅门牌、服务商日志固定天数或“零留存”；不修改 iOS 登录交互、同意记录、PrivacyInfo、商店元数据、服务器响应头、业务 API、AI 请求、会员价格/额度、视觉品牌结构或部署环境。
- 验收：官网、隐私政策、用户协议三处主体、联系方式、ICP、产品能力和第三方清单一致；删除 Open-Meteo、智谱生产使用、旧卖方或旧额度错误承诺；法律文本明确可选开关、本机/云端/第三方边界、用户权利、注销与未成年人边界，所有链接可达且静态门禁通过。法律文本仍需运营方/专业律师最终审核，不把代码检查冒充法律意见。
- 实施结果：官网新增“数据边界”导航与三张本机/自动备份/天气联网卡，更新 AI、照片、WeatherKit、DeepSeek 和服务器区域事实，页脚公开王义磊（个人）、`yilei wang`、南京市浦口区、两个邮箱与 ICP。隐私政策、用户协议统一升级为 2026-08-28 v1.0，明确个人信息处理者、选择性同意、本机照片/人脸区域分析、精确云同步范围、AI 轻润色与封面导演、天气/城市、日志、用户权利、注销旧令牌、未成年人、会员与争议边界；移除 Open-Meteo、旧生产智谱、内部“账单字段”、硬编码旧额度和“继续使用即同意重大更新”等不准确表述。
- 第三方清单：公开阿里云上海基础设施与短信、DeepSeek、Apple WeatherKit/CoreLocation/StoreKit/Photos/Vision/Core Image，以及经 DNS 再确认的 Cloudflare Email Routing。未虚构网站公安备案号、住宅门牌、第三方固定日志天数或“零留存”；`COMPLIANCE_PROVIDER_REGISTER_v1.md` 同步补充 Cloudflare MX、邮件数据与边界。
- 修改文件：`site/index.html`、`legal/privacy.html`、`legal/terms.html`、`COMPLIANCE_PROVIDER_REGISTER_v1.md`、新增 `scripts/compliance_html_check.py`、`scripts/validate_release_gate.py` 与本文档。未修改 iOS 登录/同意、Privacy Manifest、App Store 元数据、服务端响应头、会员价格/额度、同步实现或生产环境。
- 验证证据：`python scripts/compliance_html_check.py` 校验三页 HTML 结构、重复 ID、本地资源/片段链接、必需事实和禁用旧文案均通过；本地浏览器桌面完整页及 390×844 移动端实际渲染通过，官网 `scrollWidth=375`、隐私政策和用户协议均无横向溢出，图片与长页滚动正常。`python scripts/validate_release_gate.py --phase windows` 最终 `release_repository_gate: OK`，新合规页面检查已纳入全局门禁；copy lint 仅有既有 5 条 soft warning。
- 剩余风险与下一步：法律文本需在部署前由运营方逐项签字确认，并建议由熟悉中国个人信息保护、App Store 和消费者条款的律师复核；阿里云/DeepSeek 合同日志期限、数据库备份周期和 PM2 应用日志上限仍需补运营证据。下一项只做登录同意、政策版本留痕与 `PrivacyInfo.xcprivacy`，不修改网站、法律正文、商店元数据或生产 Nginx。

---

## 82. COMPLIANCE-CONSENT-MANIFEST-01：登录同意、政策版本留痕与 Privacy Manifest（2026-08-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；登录同意、版本留痕、隐私清单、XCTest 契约和完整 Windows 发布门禁已完成，缺 macOS/Xcode 编译、Archive Privacy Report、抓包与 iPhone 交互签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 允许范围：账号登录 Sheet、协议链接、同意状态与本机持久化、重大版本重新提示策略、`PrivacyInfo.xcprivacy`、Xcode target 资源接线、对应 XCTest/静态门禁/真机矩阵和本文档。可定义统一政策版本常量，并只在用户主动点击同意后写入本机时间。
- 冻结边界：不修改短信发送接口、验证码位数/频控、JWT、账号/注销、同步 DTO、会员购买、天气、AI、账本、`site/`、`legal/`、App Store 元数据或服务器响应头；不得默认勾选、以隐私政策链接点击代替同意、以“继续使用”推定同意，或在用户同意前发送手机号。
- 验收：未同意时发送验证码明确受阻且手机号不出设备；协议/隐私链接可分别打开；勾选后才可发送，记录版本与时间；政策版本变化后旧同意不再满足登录发送条件但不清除本地账本；退出/重启当前版本保持同意事实。Privacy Manifest 随 app target 打包，声明真实收集类别、追踪为 false、无追踪域，并覆盖仓库实际 Required Reason API；静态门禁通过，Xcode/真机最高按证据标记。
- 实施结果：新增统一 `LegalConsentStore`，以当前用户协议 `1.0`、隐私政策 `1.0` 和 `acceptedAt` 保存一份本机同意记录；新安装默认无记录，用户主动勾选才写入，取消勾选会撤回，当前版本重启仍有效，任一政策版本变化都会让旧记录失效并重新提示。设置账号页与会员页登录 Sheet 共用同一 `LoginPolicyConsentRow`，分别提供可点击的《用户协议》和《隐私政策》，移除两处“登录即表示同意”的推定文案；勾选按钮具有 44pt 触控区、VoiceOver 勾选状态和未勾选说明。
- 网络硬边界：`SettingsViewModel.sendSMSLoginCode()` 与 `verifySMSLogin()` 都在读取 `loginPhone`、构造 `AuthService` 或调用网络前重新核对当前政策版本；未同意时即使绕过按钮直接调用也只显示明确提示，不会读取或发送手机号。两个入口的发送和验证按钮同时依赖同一同意状态；未改变短信 API、验证码、频控、JWT、账号、会员购买或登录成功后的续接语义。
- 隐私清单：新增并接入 App target Resources 的 `PrivacyInfo.xcprivacy`，声明 tracking 为 false、tracking domains 为空；按当前实现列出手机号、用户 ID、购买历史、云端账单内容、WeatherKit 精确位置和其他诊断数据，并逐项标记 linked/tracking/purpose。Required Reason API 审计覆盖实际 `UserDefaults`（`CA92.1`）与 `ProcessInfo.systemUptime`（System Boot Time `35F9.1`）；现有 `attributesOfItem` 只读取文件大小，未无依据声明 File Timestamp，最终仍以 Xcode Privacy Report 为准。
- 修改文件：新增 `NativeDemoApp/Services/LegalConsentStore.swift`、`NativeDemoApp/Views/Components/LoginPolicyConsentRow.swift`、`NativeDemoApp/Resources/PrivacyInfo.xcprivacy`；修改 `NativeDemoApp/ViewModels/SettingsViewModel.swift`、`NativeDemoApp/Views/SettingsView.swift`、`NativeDemoApp/Views/MemberPricingView.swift`、`NativeDemoApp.xcodeproj/project.pbxproj`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。未修改短信/认证服务、同步 DTO、会员购买、WeatherKit、AI、账本、网站/法律正文、App Store 元数据或 Nginx。
- 验证证据：先通过 XML/plist 结构与 target 接线审计，并在自检中发现、修正新文件误入测试 target 的工程接线问题；静态门禁现明确要求隐私清单和两个 Swift 文件位于 App target 且不得误入测试 target。`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 与 `python scripts/validate_release_gate.py --phase windows` 最终均退出码 0，`release_repository_gate: OK`；生活语义、无障碍、合规页面、迁移、SQLite schema、AI proxy 24/24、100/1,000/5,000 条确定性夹具和三张真实 12MP 图片均通过，集合摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`，copy lint 只保留任务开始前已有 5 条 soft warning。
- 剩余风险与下一步：Windows 没有 Swift/Xcode，不能证明 Swift 6 编译、实际 Bundle 中的隐私清单、Privacy Report 或真机网络边界。必须在 macOS 运行 Debug/Release Clean Build 与全部 XCTest，Archive 后确认 `PrivacyInfo.xcprivacy` 和 Required Reason 无警告，再按 `FLOW-94` 对两个登录入口做新安装/重启/政策升级、抓包、VoiceOver 和特大字号签收，并把 App Store Connect 隐私标签与清单逐项核对。取得证据前保持 `CODE_DONE`；下一项独立处理 App Store 对外文案和隐私标签，不在本项夹带服务器响应头。

---

## 83. COMPLIANCE-APP-STORE-METADATA-01：App Store 文案与隐私标签对齐（2026-08-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；仓库中的 App Store 文案、IAP 展示说明、审核备注和隐私标签已对齐当前产品、法律文本与 `PrivacyInfo.xcprivacy`，专项检查与完整 Windows 发布门禁通过；尚未实际填写 App Store Connect、完成 Xcode Archive/Privacy Report 与运营方签收，不标记 `VERIFIED`。当前无本项 `IN_PROGRESS`。
- 允许范围：`APP_STORE_LISTING.md`、`APP_STORE_IAP_SETUP.md`、结构化 App Store 元数据、对应静态校验、发布真机矩阵和本文档。可记录运营主体/卖方显示名、支持/营销/隐私/协议 URL、当前价格与真实免费额度，但不直接登录或提交 App Store Connect。标签审计若发现 `PrivacyInfo.xcprivacy` 缺少与既有上传内容对应的数据类别，只允许补类别声明，不得借此扩大实际采集或上传。
- 必要边界调整：当前自动备份已经上传账单金额、分类和 `memoryContext.cityName` 等既有内容；金额/分类除“其他用户内容”外也属于“其他财务信息”，随账号同步的城市级上下文属于“粗略位置”。为避免商店标签与 App 隐私清单不一致，本项允许补 `NSPrivacyCollectedDataTypeOtherFinancialInfo` 与 `NSPrivacyCollectedDataTypeCoarseLocation`（前者 linked，后者仅在写入账单并开启自动备份时 linked；均 not tracking、App Functionality）。WeatherKit 实时坐标仍按 Precise Location、not linked 描述。这不新增数据处理、schema 或网络请求；回滚只需撤回声明，但在现有自动备份范围不变时不应回滚。
- 冻结边界：不修改 App 功能、会员权益/价格/Product ID、免费额度常量、StoreKit/backend 验单、短信/JWT、登录同意、WeatherKit、AI、账本、网站/法律正文或服务器响应头；不得在审核备注公开通用固定验证码、沙盒密码、私钥或其他凭据，不把未完成真机/生产验收的能力写成已保证上线。
- 验收：名称、副标题、推广文本、描述、关键词、截图叠字、版本说明、商品描述、TestFlight 信息和审核备注使用当前术语并与真实能力一致；显式列出可复制的 App Privacy 问卷答案，和隐私清单/隐私政策一致；支持邮箱、运营主体、卖方显示名、ICP 与 URL 准确；静态门禁拒绝旧“账单字段”、旧额度、Open-Meteo、固定审核码和已停用入口；Windows 全量发布门禁通过。只能在运营方实际填入 App Store Connect 并签收后标记 `VERIFIED`。
- 实施结果：新增结构化简体中文元数据，确定名称“叙账 - 用账单叙述生活”、副标题“记账、周记与月章，温柔回望日常”，并统一今日回放、周记、月章、痕迹、复盘、生活线索和账单识别术语。上架说明与 IAP 指南改为当前真实免费额度、三个既有 Product ID 和价格；移除“看看花”“生活切片”“小 AI 说”“账单字段”、Open-Meteo、旧免费额度、通用固定审核验证码和旧 IAP 501 占位状态。审核边界明确核心能力无需登录；如审核确需账号能力，只能在当次 App Store Connect 私密备注提供限时、可撤销凭据，不进入仓库。
- 隐私标签：按既有实际处理列出 Phone Number、User ID、Purchase History、Other Financial Info、Other User Content、Precise Location、Coarse Location 和 Other Diagnostic Data 共 8 类；Tracking 为 false、Tracking Domains 为空。为与自动备份真实内容一致，仅补充 `NSPrivacyCollectedDataTypeOtherFinancialInfo` 与 `NSPrivacyCollectedDataTypeCoarseLocation`；WeatherKit 实时精确坐标仍为 not linked，写入账单并自动备份的城市级上下文为 linked。本项没有新增采集、上传、schema 或网络请求。
- 修改文件：新增 `APP_STORE_METADATA_zh-Hans.json`、`scripts/app_store_metadata_check.py`；重写 `APP_STORE_LISTING.md`、`APP_STORE_IAP_SETUP.md`；更新 `NativeDemoApp/Resources/PrivacyInfo.xcprivacy`、`scripts/experience_static_check.ps1`、`scripts/validate_release_gate.py`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。未修改 App 功能、会员权益/价格/Product ID、免费额度常量、StoreKit/backend 验单、短信/JWT、登录同意、WeatherKit、AI、账本、网站/法律正文或服务器响应头。
- 验证证据：`python scripts/app_store_metadata_check.py` 通过，长度结果为名称 12/30、副标题 15/30、推广文本 87/170、描述 908/4000、关键词 36/100，隐私类型 8；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过；`python scripts/validate_release_gate.py --phase windows` 退出码 0，最终 `release_repository_gate: OK`。生活语义、合规页面、迁移、SQLite schema、AI proxy 24/24、100/1,000/5,000 条确定性夹具和三张真实 12MP 图片均通过，集合摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`；copy lint 只保留任务开始前已有 5 条 soft warning。
- 剩余风险与下一步：需要在 macOS 完成 Swift 6 Debug/Release Clean Build、全部 XCTest、Archive 中 Privacy Manifest/Privacy Report 检查；运营方还需在 App Store Connect 逐字段填写并核对截图、隐私问卷、IAP 状态和“首月 ¥6”真实推介促销配置。取得这些证据前保持 `CODE_DONE`。下一项独立处理生产主站与 API 安全响应头，不修改 App Store 元数据、App 功能或业务 API 语义。

---

## 84. OPS-SECURITY-HEADERS-01：官网与 API 安全响应头收口（2026-08-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `VERIFIED`；仓库配置、生产部署、外网业务/安全头回归、Nginx 状态、证书链与 Certbot 自动续期演练均通过。当前无本项 `IN_PROGRESS`。
- 允许范围：生产 Nginx 站点配置、仓库中与该配置直接对应的运维文档或校验脚本，以及本文档。允许为静态主站/法律页设置与现有资源一致的 CSP，为 API 设置不影响 iOS 客户端的安全响应头，并补 HSTS、`X-Content-Type-Options`、`Referrer-Policy`、`Permissions-Policy` 等必要策略；修改前必须备份精确配置，修改后必须执行 `nginx -t`、reload 和外网验证。
- 冻结边界：不修改 iOS App、WeatherKit、App Store 元数据/隐私标签、官网或法律正文、JWT/注销语义、短信、AI、StoreKit、账本、同步 DTO、业务 API 返回体或 CORS 允许来源；不得使用会阻断 Certbot HTTP-01、Apple/DeepSeek/阿里云后端调用或现有静态资源的过严策略，不扩大跨域访问，不暴露服务器密钥或完整环境变量。
- 验收：`https://xuzhangapp.com/`、隐私政策、用户协议和 `https://api.xuzhangapp.com/health` 及未授权 API 路径均返回与内容类型匹配的安全头；HTTPS 重定向、证书链和自动续期仍正常；Nginx 配置测试通过并平滑 reload；健康检查、401 边界与 iOS 使用的 API 路径不受影响。若无法取得服务器权限或生产验证证据，记录为 `BLOCKED`，不得宣称已部署。
- 实施结果：主站与 API 使用两份独立可审计 Nginx 配置。两者均关闭版本暴露，并设置一年 HSTS（含子域）、`nosniff`、`DENY`、Referrer Policy 与 Permissions Policy；主站 CSP 只允许同源静态资源，因现有 CSS 变量/展示样式和图片失败处理，仅保留 `style-src 'unsafe-inline'` 与更窄的 `script-src-attr 'unsafe-inline'`，不允许 `unsafe-eval`、对象嵌入或第三方脚本。API 使用 `default-src 'none'`，隐藏 `X-Powered-By` 并由 Nginx 统一接管 CSP/`nosniff`，不改变 Express CORS、反代端口或响应体。
- 生产变更与恢复：首次替换前备份为 `/etc/nginx/sites-available/xuzhangapp.com.pre-security-headers-20260828-1605` 和 `/etc/nginx/sites-available/api.xuzhangapp.com.pre-security-headers-20260828-1605`；发现 API 404 上游/网关重复安全头后，在第二次 API 精确替换前另备份 `/etc/nginx/sites-available/api.xuzhangapp.com.pre-security-headers-normalized-20260828-1610`。每次均先校验上传文件 SHA-256，再安装、执行 `nginx -t`，成功后才平滑 reload；最终生产哈希与仓库配置一致，Nginx 保持 active。
- 修改文件：新增 `ops/nginx/xuzhangapp.com.conf`、`ops/nginx/api.xuzhangapp.com.conf`、`scripts/security_headers_check.py`；更新 `scripts/validate_release_gate.py`、`PROJECT_SETUP.md` 与本文档；生产只修改两个对应的 Nginx sites-available 文件。未修改 iOS App、WeatherKit、App Store 元数据/隐私标签、官网/法律正文、JWT、短信、AI、StoreKit、账本、同步 DTO、业务 API 返回体或 CORS 允许来源。
- 验证证据：`python scripts/security_headers_check.py --live` 同时通过仓库和外网检查；主站、`www`、隐私政策、用户协议为 200，主站 404 也保留安全头；API `/health` 为 200、`/v1/account/me` 为 401、未知路径为 404、CORS 预检为 204 且仍回显既有允许来源，所有 API 响应均无 `X-Powered-By` 或重复安全头。HTTP 主域/API 均 301 到 HTTPS，外网 TLS 校验为 0；Nginx 配置测试和服务状态通过，本机 8790 健康/未授权边界仍为 200/401。`certbot renew --dry-run --no-random-sleep-on-renew` 对 API 和主域两张 Let's Encrypt 证书均成功，timer 为 enabled/active。最终 `python scripts/validate_release_gate.py --phase windows` 退出码 0，`release_repository_gate: OK`，copy lint 只保留任务前已有 5 条 soft warning。
- 剩余风险与下一步：未申请 HSTS preload，避免在所有子域长期条件未成熟时做不可快速撤回的浏览器预载承诺；一年 HSTS 与 `includeSubDomains` 已生效，后续必须持续保证主域、`www` 和 API 的 HTTPS。当前 CSP 的两处窄例外来自既有静态 HTML，未来若移除行内样式/事件属性可独立收紧。Certbot 仍依赖 DNS、80/443、安全组、Nginx 和 timer，需持续监控。生产主站正文仍是旧版本，下一项只部署第 81 项已经静态/浏览器 QA 通过的 `site/` 与 `legal/` 内容，不修改安全头或其他服务。

---

## 85. COMPLIANCE-LEGAL-DEPLOY-01：官网与法律页生产发布（2026-08-28）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `VERIFIED`；官网、隐私政策、用户协议已发布生产，仓库/生产哈希、外网事实、资源/链接、安全头、桌面/移动端渲染和完整 Windows 发布门禁均通过。当前无本项 `IN_PROGRESS`。
- 允许范围：生产 `/opt/xuzhang/xuzhangapp/site/` 与 `/opt/xuzhang/xuzhangapp/legal/` 中仓库对应的静态文件、必要的发布校验与本文档。发布前必须只读检查生产 Git/文件现场和本地/远端清单，保留完整可恢复备份；发布后验证桌面/移动端页面、链接、资源、正文事实、安全头和 HTTP/HTTPS 边界。
- 冻结边界：不修改 Nginx、安全头、证书、backend/AI/短信/数据库、iOS App、WeatherKit、登录同意、Privacy Manifest、App Store 元数据或 IAP；不覆盖生产 `site/`、`legal/` 之外的文件，不虚构网站“苏公网安备”编号、住宅门牌或第三方日志固定天数。
- 验收：生产首页、隐私政策、用户协议与仓库文件哈希一致，页面公开王义磊（个人）、`yilei wang`、南京市浦口区、两个可收信邮箱和 `苏ICP备2026035096号-1`，第三方/WeatherKit/云端边界准确且无旧 Open-Meteo/智谱/额度/术语；所有同源资源和内部链接为 200，安全头、API、证书续期与其他服务不变。若生产现场存在无法安全合并的未知修改，停止并记录，不直接覆盖。
- 生产现场与发布：发布前确认服务器分支为 `feature/xuzhangapp-staging`，`git status --short -- site legal` 为空；图片、CSS、JS、图标等资源哈希与仓库一致，仅首页、隐私政策、用户协议及内部截图说明存在版本差异。首轮为 `site/index.html`、`legal/privacy.html`、`legal/terms.html` 建立完整恢复副本 `/opt/xuzhang/backups/xuzhangapp/compliance-20260828-1620`，上传后逐文件 SHA-256 校验，再通过同目录临时文件原子替换。严格外网术语检查发现首页仍引用旧界面截图及“看看花/生活切片”等旧称后，改为明确标注的 CSS 功能结构示意，统一痕迹、周记、今日回放、账单构成、复盘与联网整理术语，并停止在页面引用 4 张旧截图；第二轮恢复副本为 `/opt/xuzhang/backups/xuzhangapp/site-terminology-20260828-1625`，再次按哈希原子替换首页与截图说明。
- 事实与资源结果：生产首页、隐私政策、用户协议包含王义磊（个人）、`yilei wang`、江苏省南京市浦口区、`support@xuzhang.app`、`hello@xuzhang.app`、`苏ICP备2026035096号-1`、Apple WeatherKit、DeepSeek、阿里云与 Cloudflare Email Routing 等对应事实；无 Open-Meteo、智谱、“账单字段”“看看花”“生活切片”“周切片”“生活配方”或“今日生活回放”。首页 CSS/JS/品牌图/图标、四张历史截图资源和法律页 CSS 均返回 200；历史截图文件保留在服务器用于可恢复追溯，但官网不再引用，也明确不得用于当前 App Store。
- 修改文件：更新 `site/index.html`、`site/screenshots/README.md`、`scripts/compliance_html_check.py` 与本文档；生产替换 `site/index.html`、`site/screenshots/README.md`、`legal/privacy.html`、`legal/terms.html`。未修改 Nginx、安全头、证书、backend/AI/短信/数据库、iOS App、WeatherKit、登录同意、Privacy Manifest、App Store 元数据或 IAP。
- 验证证据：`python scripts/compliance_html_check.py`、`python scripts/security_headers_check.py --live` 与逐资源 200/正文事实检查均通过；API `/health` 与未授权账号路径继续为 200/401。生产文件 SHA-256 与仓库一致。真实浏览器桌面端 1265px 宽下 `scrollWidth=1265`、无坏图、无旧术语、无控制台/CSP 警告，轮播点选可正确切换；375×844 移动端 `scrollWidth=375`、卡片无越界、无坏图或控制台错误。隐私政策/用户协议移动端均 `scrollWidth=375`、样式表加载、必需事实完整、内部链接正确。最终 `python scripts/validate_release_gate.py --phase windows` 退出码 0，`release_repository_gate: OK`，100/1,000/5,000 条夹具、真实 12MP 图片、AI proxy 24/24、迁移、SQLite schema、App Store 元数据和安全头静态检查均通过；copy lint 仅保留任务开始前已有 5 条 soft warning。
- 剩余风险与下一步：本项证明页面事实和技术发布正确，不替代中国个人信息保护、消费者条款或 App Store 规则的专业法律意见；仍建议运营方/律师最终复核。4 张旧界面截图文件尚未物理删除，但已从官网引用中移除；必须在通过当前 WeatherKit/登录同意/Privacy Manifest 的真机构建后，按 `APP_STORE_LISTING.md` 和 `FLOW-95` 重新拍摄脱敏截图再替换。当前无 `IN_PROGRESS`；下一步是在 macOS 为 `com.xuzhang.app` 实际开启 WeatherKit、刷新签名并完成 Debug/Release/XCTest、Archive Privacy Report 与 `FLOW-93/94`，随后由运营方在 App Store Connect 完成 `FLOW-95` 的元数据、隐私问卷、IAP 促销和截图签收。取得这些外部证据前，WeatherKit、登录同意、Privacy Manifest 和 App Store 元数据相关任务继续保持 `CODE_DONE`。

---

## 86. XCODE-DIAGNOSTIC-FIX-02：PERF-AUDIT-04 编译回补与本地备份并发告警（2026-08-29）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；4 条 Xcode 诊断已完成定向源码回补、静态防回流与完整 Windows 发布门禁，当前无 `IN_PROGRESS`。Windows 无 Swift/Xcode，仍需用户在 macOS Clean Build 复验，不标记 `VERIFIED`。
- 诊断范围：`StatsWebView.swift:6100` 的 `some View` 多语句函数缺少显式返回，连带造成 `presentationDragIndicator` 结果未使用；`SummaryPlaybackSheet.swift:2748` 只需确认周分享 payload 存在却绑定未使用值；`LedgerLocalBackupDocument.swift:46` 因 `FileDocument` 的 `Sendable` 要求而暴露不可变 `FileWrapper` 存储的严格并发告警。
- 允许范围：只补显式 `return`、把未使用可选绑定改为存在性判断、为只在构造期建立且之后只读的备份文档声明受审计的 `@unchecked Sendable`，并补静态防回流门禁与本文档证据。
- 冻结边界：不修改周记/月章播放、分享 payload、封面 Session、模板、照片、会员/额度、账本备份包结构、导入/恢复、文件内容、存储/同步、WeatherKit、登录同意、App Store、官网、后端或 `ARCH-03`；不提交或推送，除非用户另行明确要求。
- 实施结果：`summaryPlaybackSheet` 显式返回完整 `SummaryPlaybackSheet` modifier 链，同时消除 opaque return type 无法推断与 `presentationDragIndicator` 未使用；封面 Session 准备把 `guard let payload = weeklySharePayload` 改为纯存在性判断，仍由既有 `makeLegacyCoverSource` 读取同一 payload；`LedgerLocalBackupDocument` 显式声明 `FileDocument, @unchecked Sendable`，只承接构造后不再修改的私有 `FileWrapper` 边界，备份包目录、文件、摘要、导入和恢复逻辑均未改变。
- 修改文件：`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoApp/Views/SummaryPlaybackSheet.swift`、`NativeDemoApp/Services/LedgerLocalBackupDocument.swift`、`scripts/experience_static_check.ps1` 与本文档。未修改产品交互、数据、文案、分享结果、备份内容或任何服务端/合规文件。
- 验证证据：`git diff --check` 与 `powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 退出码 0，新增三条门禁锁定显式返回、无用绑定退役及备份文档 Sendable 边界。`python scripts/validate_release_gate.py --phase windows` 退出码 0，最终输出 `release_repository_gate: OK`；AI proxy、100/1,000/5,000 条夹具、三张真实 12MP 图片、合规页、App Store 元数据、迁移和 SQLite schema 全部通过，copy lint 仅保留任务开始前已有 5 条 soft warning。
- 剩余风险与下一步：Windows 无 Swift/Xcode，无法在本机证明编译器已接受 `FileDocument, @unchecked Sendable` 或实际清空诊断列表。下一步只在 macOS/Xcode 对当前分支执行 Swift 6 Clean Build，并确认 `StatsWebView.swift:6100/6139`、`SummaryPlaybackSheet.swift:2748` 和 `LedgerLocalBackupDocument.swift:46` 四条诊断消失；若出现新诊断，继续按精确文件/行号定向回补，不启动其他任务。

---

## 87. TRACE-PREP-PERF-02：本周痕迹历史回声有界计算（2026-08-29）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；历史窗口裁剪、场景分类复用、5,000 条等价回归、静态防回流和完整 Windows 发布门禁均完成，当前无本项 `IN_PROGRESS`。缺 Xcode/XCTest 与 Build 323 之后的新 TestFlight/Instruments 真机签收，不标记 `VERIFIED`。
- 现场与根因：第 70 项已经让痕迹、周记和分享共用同一份 `PeriodExperienceFacts`，第 72/74 项也已串行化全账本重任务并限制缓存，但 `LifeNarrativeEchoPolicy.makeEcho` 仍先对全部可发布历史排序和分桶，再在每个当前场景下重复分类历史记录。现有规则实际只访问当前周期及前 12 个周期；更早记录不可能成为回声证据，却仍增加首屏等待、CPU 和临时数组。
- 允许范围：仅优化 `LifeNarrativeEchoPolicy` 的等价输入窗口与单次场景分类复用，补充 100/1,000/5,000 条、超出 12 周/月旧记录、确定性和语义不变测试，更新静态门禁、真机矩阵及本文档。
- 冻结边界：不修改历史回声 12 周/月上限、候选评分、场景分类器、生活线索/跨城关系门槛、事实文案、账单/照片/会员/额度/AI/同步、痕迹快照 key、缓存数量、加载遮罩、页面结构或后台并发上限；不得以展示旧快照或不完整快照掩盖真实计算。
- 工作区保护：保留本轮 WeatherKit Build 323 台账证据、既有未跟踪素材/输出/缓存目录和所有用户现场；不回退、不暂存、不提交或推送，除非用户另行明确要求。
- 实施结果：`LifeNarrativeEchoPolicy.makeEcho` 在排序、分桶和场景分类之前，按原规则实际会读取的距离裁剪为当前周期及前 12 个周/月；第 12 个周期仍保留，第 13 个及更早记录原本就不会被候选读取，现在不再进入排序和临时分桶。保留窗口内新增按稳定账单 UUID 的局部场景缓存，当前分组、晚间通勤、咖啡组合和各场景历史筛选复用同一 `LifeSceneSignal`，同一记录在一次回声计算中最多分类一次。候选顺序、评分、证据 ID、主动弃权与 12 周/月产品边界均未改变；未增加持久缓存、后台并发或常驻全账本副本。
- 修改文件：`NativeDemoApp/Services/LifeNarrativeEchoService.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。未修改 `StatsWebView` 加载遮罩/快照 key、`PlaybackService` 共用事实、账单/照片/会员/额度/AI/同步或其他页面。
- 验证证据：新增 `testEchoIgnoresRowsOutsideTwelvePeriodWindowAtReleaseScale`，以同一近周期回声分别叠加 0 与 5,000 条第 13 周之外旧记录并要求完整 `LifeNarrativeEcho` 相等；新增静态门禁锁定 12 周/月窗口、裁剪发生在分桶前、单次场景缓存、测试和 `FLOW-97`。`git diff --check` 与 `powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 退出码 0；`python scripts/validate_release_gate.py --phase windows` 退出码 0，最终 `release_repository_gate: OK`，生活语义、AI proxy 24/24、100/1,000/5,000 条确定性夹具、三张真实 12MP 图片、合规、迁移和 SQLite schema 均通过，集合摘要保持 `df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129`，copy lint 仍只有既有 5 条 soft warning。
- 剩余风险与下一步：Windows 无 Swift/Xcode，新增 Swift 代码和 XCTest 尚未实际编译运行，也无法量化真机“正在整理本周痕迹”的改善幅度。必须在 macOS 运行 Clean Build 与全部 XCTest，再由新 TestFlight 按 `FLOW-97` 对 100/1,000/5,000 条及第 12/13 周边界执行冷启动、Tab 往返、真实增改删和 Time Profiler/Allocations/Main Thread Hitches；重点确认第 12 周证据仍命中、第 13 周外数据不改变结果，等待时间不再随远古账单线性增长且无新内存尖峰。若保留窗口内计算仍超预算，下一项只能基于 Instruments 栈独立优化，不回退加载遮罩或扩大并发。

---

## 88. APP-STORE-SCREENSHOTS-01：首发 App Store 截图素材（2026-09-02）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；根据 2026-09-02 用户提供的 App Store Connect 截图，已补齐 6.5 英寸上传规格，当前无本项 `IN_PROGRESS`。仍需运营方在当前 TestFlight 构建上逐张核对并签收，暂不标记 `VERIFIED`。
- 目标：按 `APP_STORE_LISTING.md` 的前五个卖点制作 6.7 英寸 App Store 可上传的 1290×2796 PNG，并从同一脱敏结果生成 6.5 英寸可上传的 1284×2778 PNG；通过裁剪去掉状态栏和悬浮辅助按钮，统一品牌背景、标题和留白，让用户一眼看懂“记账 → 回看 → 生活线索”。
- 允许范围：仅使用当前真机截图做非破坏性裁剪和像素级脱敏展示；允许新增 `output/app-store-screenshots-v4-high-fidelity/` 内部原图、预览和上传候选，不修改 App 功能、页面、文案、数据、官网、法律页或 App Store Connect 配置。
- 冻结边界：不伪造系统状态、会员价格、测试账号、手机号或能力；不把 AI 当首图卖点；不使用旧官网截图作为正式截图；不改变任何产品规则或既有资源。
- 验收：6.7 英寸与 6.5 英寸各 5 张图片分别为 1290×2796 与 1284×2778、RGB PNG、无 Alpha/EXIF，状态栏/悬浮按钮不入图、真实 UI 与字号布局保持；上传候选不得包含真实城市、商户、金额、照片或账号信息，并需在最终构建上复核。
- 当前现场：已读取 `APP_STORE_LISTING.md`、`site/screenshots/README.md` 和项目台账；现有 `site/screenshots/` 四张旧界面图明确只作历史参考，本次不覆盖；`output/` 为既有未跟踪目录，保留其余内容。用户提供的 57/58/59/60/65 五张 1290×2796 实机图已复制到 `output/app-store-screenshots-v4-high-fidelity/source-raw/`，原图不改写。
- 实施结果：重写 `scripts/make_app_store_screenshots_high_fidelity.py`，直接处理上述五张实机图；仅清除系统状态栏并覆盖瑞幸咖啡、原始时间/日期、金额、动态统计及个人昵称，保留原 App UI、导航、阴影、图标和宠物资产，不添加宣传标题、外部手机框或重绘整张界面。输出 6.7 英寸 `upload-ready/` 与兼容 6.5 英寸 `upload-ready-6.5-inch/` 两套各 5 张 `01-app-store.png`～`05-app-store.png`，联系图仅供预览且不在上传目录。
- 修改文件与素材：`scripts/make_app_store_screenshots_high_fidelity.py`、`output/app-store-screenshots-v4-high-fidelity/source-raw/`、`upload-ready/` 与 `upload-ready-6.5-inch/` 各五张 PNG 及预览联系图；同步更新 `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 的 `FLOW-98`。未覆盖用户原始截图，其他既有未跟踪素材保持不变。
- 验证证据：两套各五张上传候选已逐张检查，6.7 英寸为 `1290×2796`、6.5 英寸为 `1284×2778`，均为 RGB PNG、无 Alpha/EXIF；状态栏未入图，真实商户、原始日期时间、金额、昵称已替换为中性演示内容，未见用户照片/城市/账号残留。`python -m py_compile scripts/make_app_store_screenshots_high_fidelity.py` 已通过；后续完成 `git diff --check`、体验静态检查、App Store 元数据检查和 Windows 发布门禁后，保留其既有 5 条 copy lint soft warning 作为唯一提示。
- 脱敏验证证据：v4 两套五张上传候选均由脚本从 source-raw 可重复生成，两个上传目录各仅含 5 张 PNG；`clean_save` 重新物化 RGB 像素并清除元数据，脚本会先删除旧候选，避免误传历史文件。视觉检查确认首页、记账、痕迹、复盘、备份与真实 UI 一致，未见状态栏或悬浮辅助按钮。
- 剩余风险与下一步：当前只完成素材侧 CODE_DONE，未宣称最终构建签收。App Store Connect 上传前仍需用通过 `FLOW-93/94` 的最终 TestFlight/Archive 构建核对 UI 是否一致；6.5 英寸槽位使用 `output/app-store-screenshots-v4-high-fidelity/upload-ready-6.5-inch/01-app-store.png`～`05-app-store.png`，6.7 英寸槽位使用 `upload-ready/`，并分别在预览和 375/390px 缩略图确认文字可读。不要上传 source-raw 或联系图。待运营签收后再标记 `VERIFIED`。

---

## 89. TRACE-CLUE-SCOPE-01：线索独立连续范围与生活页周/月解耦（2026-09-02）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；线索连续范围、缓存/冷启动身份、统一加载遮罩、生活页边界保护和 Windows 全量回归已完成，当前无 `IN_PROGRESS`。Windows 无 Swift/Xcode，缺 macOS 编译、XCTest 和真机签收，不标记 `VERIFIED`。
- 问题与目标：线索页过去复用生活页的本周/本月/本年/自定义范围，导致切换生活周期时线索内容、缓存和加载文案跟着漂移，也让用户误以为线索只属于当前生活章节。本项让生活页保留现有周/月体验，线索改为独立、连续且有界的长期观察窗口。
- 允许范围：`StatsTraceModels` 中的线索 scope、滚动窗口和节奏分桶；`StatsTraceSnapshotStore` 的线索输入与事实/行程生成；`StatsWebView` 的线索筛选、缓存 key、冷启动承接、加载遮罩和 Hero；叙事 scope/周期文案对 `.continuous` 的支持；对应 XCTest、静态门禁、文案门禁和发布矩阵。不得借本项改动生活页周/月快照、账单分类、照片、会员额度、AI、同步或页面外观。
- 产品决策：生活页继续保留“本周/本月”切换；线索不再显示重复的时间范围切换，统一展示“生活线索”。线索使用当前 ISO 周及前 12 周的滚动窗口（`rolling-13-weeks-v1`），当前窗口外第 13 周及更早记录不进入线索候选；节奏按 6 个连续 14 天段展示。跨城行程等关系事实仍由本地证据生成，叙事使用“这段时间”而不是本周/本月。
- 实施结果：新增 `TraceClueScopePolicy` 与 `TraceClueScope.continuous`；线索条目统一按窗口过滤并排除草稿，缓存 key、冷启动 scope key、解锁上下文和 `TraceClueComputationInput` 均使用同一 scope；移除 Hero 内重复的周/月范围控件。`TraceSnapshotComputation.buildClue` 复用连续 scope 的行程事实与中性叙事计划，生活页周期变化不再使线索快照失效。无障碍检查脚本同步从旧周期标签更新为“这段时间的节奏”，避免静态门禁与产品文案脱节。
- 修改文件：`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoApp/Services/LifeNarrativePlanningService.swift`、`NativeDemoApp/Services/LifeNarrativeEchoService.swift`、`NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift`、`NativeDemoApp/Services/PlaybackService.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/accessibility_lint.py`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。既有 `brand-assets/`、`output/`、`tmp/`、`scripts/__pycache__/` 及其他用户现场未覆盖。
- 冻结边界复核：生活页周/月选择、自定义日期和章节快照保持原逻辑；线索分类筛选仍可用但不改变窗口；跨城关系仍要求道路与异地活动证据；免费/会员额度、账单/照片/同步 DTO、AI 远程请求、加载遮罩的单一居中阻塞行为均未改变。
- 验证证据：`git diff --check` 通过；`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py`、`python scripts/playback_copy_lint.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 和 `python scripts/validate_release_gate.py --phase windows` 全部退出码 0。静态检查覆盖连续 scope、窗口边界、缓存/冷启动身份、单一加载遮罩、无障碍标签和 `StateRegressionTests`；发布门禁输出 `release_repository_gate: OK`。文案 lint 仅保留任务前已有的 5 条 soft warning。
- 剩余风险与下一步：Windows 无 Swift/Xcode，不能证明 `TraceClueComputationInput` 默认 scope、`.continuous` 分支和 SwiftUI actor 隔离已通过编译，也不能量化真机整理耗时。下一步只在 macOS 执行 Swift 6 Debug/Release Clean Build 与全部 XCTest，再按 `FLOW-99` 在 TestFlight 做周期切换、连续展开、重启、窗口边界及 100/1,000/5,000 条 Instruments 验收；若真机仍慢，只能基于 Instruments 栈开新任务，不能扩大窗口或恢复生活页周期耦合。

---

## 90. OCR-CLASSIFICATION-FIX-01：支付元数据隔离与商品证据优先（2026-09-03）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；支付元数据隔离、商品/商户证据优先、法律实体通勤边界、静态守卫和 Windows 回归已完成；当前无 `IN_PROGRESS`。Windows 无 Swift/Xcode，缺 XCTest 与正式相册 OCR 真机签收，不标记 `VERIFIED`。
- 用户反馈与现场：账单识别截图中的商品为“巧婆红汤馄饨（云密城店）”，商户全称为“南京市雨花台区红汤淮味馄饨店（个体工商户）”，但导入后分类显示“交通”。收单机构“拉卡拉支付股份有限公司”只是支付链路元数据，不代表消费场景。
- 已确认根因：`HomeViewModel.reviewedOCRDraft` 把 `draft.title + draft.rawText` 拼成一个生活语义标题；`LifeSceneSemanticService` 因 OCR 原文中的“有限公司”命中通勤“公司”强线索（7.0 分），覆盖商品“馄饨”的餐饮线索。支付方式、交易单号、状态、金额和时间等元数据也不应参与生活场景判断。
- 允许范围：`OCRService.swift` 的 OCR 语义证据提取与分类复核、`HomeViewModel.swift` 的 OCR 草稿复核、`LifeSceneSemanticService.swift` 的法律实体后缀隔离、对应 XCTest/语义夹具/静态门禁/发布矩阵和本文档。商品名称、商户名称和用户明确标题优先；收单机构、支付方式、交易/商户单号、状态、金额、时间、导航和系统 UI 行排除。法律实体后缀（如“有限公司”“股份有限公司”“个体工商户”）不能单独触发通勤。
- 冻结边界：不修改账单金额、日期、标题保存含义、OCR 金额/日期解析、用户手动锁定分类、商户品牌目录、分类 UI、生活线索/回放、首页主动作、会员/额度、存储/同步、AI 或 `ARCH-03`；不静默迁移历史记录，不把一般“公司”上下文从真实用户标题中删除。
- 实施结果：新增 `OCRCategoryEvidencePolicy`，统一详情、支付宝/微信、通用 OCR 和列表 OCR 的分类复核，只从用户标题以及“商品/商品名称/商品说明/商户全称/商户名称/收款方”等可信字段提取语义；收单机构、支付方式、交易/商户单号、状态、金额、时间、导航和系统 UI 行不会进入分类文本。`HomeViewModel.reviewedOCRDraft` 不再用整段 OCR 原文构造 `HomeItem` 参与生活语义，用户手动锁定分类仍原样保留。`LifeSceneSemanticService` 在通勤强线索判断前剥离“有限公司/股份有限公司/有限责任公司/个体工商户”等法律实体后缀，保留“公司食堂/公司楼下打车/上班通勤”等真实上下文。
- 修改文件：`NativeDemoApp/Services/OCRService.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Services/LifeSceneSemanticService.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`NativeDemoApp/Resources/RecordSceneLexicon.regression.json`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。未修改账单金额/日期/标题保存含义、OCR 金额日期解析、商户品牌目录、分类 UI、生活线索/回放、首页主动作、会员/额度、存储/同步、AI、`ARCH-03` 或历史记录。
- 验证证据：新增 `OCRCategoryEvidencePolicyTests`，覆盖“巧婆红汤馄饨 + 拉卡拉支付股份有限公司”稳定为餐饮、支付元数据不进入语义文本、法律实体后缀不制造通勤、真实“公司楼下打车”仍为通勤；新增 `ocr-wonton-payment-processor-is-metadata` 语义夹具和 `FLOW-100` 真机矩阵。`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py`、`python scripts/validate_release_gate.py --phase windows` 均通过，发布门禁输出 `release_repository_gate: OK`；copy lint 仅保留任务开始前已有的 soft warning。
- 剩余风险与下一步：Windows 无 Swift/Xcode，无法证明 `OCRCategoryEvidencePolicy`、`reviewedOCRDraft` 和 `containsStrongCommuteCue` 通过 Swift 6 编译，也不能运行 XCTest 或正式 Vision 相册 OCR。下一步在 macOS/Xcode Clean Build 与全部 XCTest 后，按 `FLOW-100` 用真实微信/支付宝截图验证商品/商户字段分行、收单机构相邻行、确认/取消/重复导入、标题/分类编辑和 100/1,000/5,000 条账本；确认收单机构法律实体不改变餐饮结果后再标记 `VERIFIED`。

---

## 91. DISCOVER-EDITORIAL-01：线索 Discover 四层信息架构与动态发现卡片（2026-09-04）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；本轮针对首次整理耗时、生活线展开信息增量、证据数量口径和高情绪价值跨城线索详情完成定向优化。仍需 macOS/Xcode 复编、全部 XCTest 和 TestFlight/Instruments 真机签收，不标记 `VERIFIED`。
- 本轮范围：只复用一次生活印记聚合与行程事实；为跨城发现卡补充道路/异地活动/其他行程证据分解；让“为什么这样说”在“两条生活线”下引用具体同日记录；为认证周末跨城自驾提供 Hero 卡、照片墙和记录墙详情入口。
- 目标：先建立本地确定性的 `DiscoverSnapshot` 和动态卡片规划，再以最小 UI 接线验证信息架构；只发布有真实 evidence ID、且具备信息增量或生活价值的内容。动态发现按 `Novelty × Confidence × Story Value` 排序，稳定存在本身不进入“AI 最近发现”。
- 允许范围：`StatsTraceModels.swift` 中的 Discover 卡片/快照模型；`StatsTraceSnapshotStore.swift` 中基于现有连续窗口的变化检测、长期生活模式、场景资产和回声投影；`StatsWebView.swift` 中四层区域的只读展示；对应 XCTest、体验静态门禁、文案/发布矩阵。可复用现有 `LifeSceneSemanticService`、`LifeJourneyFactService`、`LifeNarrativeEchoPolicy` 与 `TraceClueScopePolicy`。
- 冻结边界：不改变生活页周/月入口、线索 `rolling-13-weeks-v1` 窗口、账单分类/OCR/照片/金额/日期/标题、跨城行程认证门槛、会员额度、远程 AI、存储/同步、首页主动作或现有回放/周记/月章文案规则；不扩大历史扫描，不把固定统计或单笔存在伪装成变化，不先做整页视觉重构。
- 计划验收：空账本不生成伪发现；仅有重复稳定记录时“AI 最近发现”为空或明确静默；新增/减少/首次出现/恢复等变化卡片均携带真实证据 ID，并按三项分数稳定排序；生活线索与场景资产分别体现重复模式和成长字段（累计次数、活跃天数、地点数、常见时段）；有认证回声时只显示同一回声 evidence IDs，无回声时不填充虚构历史；所有区域复用同一连续窗口和 source revision，卡片数量受界面上限约束。
- 工作区保护：开始前已执行 `git status --short`；保留 `LifeNarrative*`、OCR、线索范围、截图素材及未跟踪目录等用户既有修改，不回退、不暂存、不提交或推送，除非用户另行明确要求。
- 实施结果：
  - `DiscoverCard` / `DiscoverSnapshot` 明确承载四层内容、evidence IDs、Novelty、Confidence、Story Value 和 source revision；所有动态发现最多展示 5 条，空账本与无变化场景保持静默。
  - `TraceSnapshotComputation.buildDiscoverSnapshot` 强制复用 `rolling-13-weeks-v1` 的有界输入，并把传入日历贯穿场景分桶、活跃日和时段计算；只做一次场景分类后生成近期首次出现、恢复、增加、减少和暂时消失变化、长期生活模式、成长中的场景资产；成长字段包含累计次数、成长天数、地点数和常见时段。Discover 使用当前线索筛选后的 `input.items`，因此分类筛选继续生效但不会扩大时间窗口。
  - 认证跨城行程进入“AI 最近发现”时沿用 `LifeJourneyFact` 的证据 ID；历史回声复用现有 `LifeNarrativeEchoPolicy` 并将固定周期词投影为 Discover 中性文案，不生成无证据历史。
  - 收口修正回声 `if let` 条件绑定、`DiscoverSceneBucket` 初始化参数顺序、场景分类 tuple 的显式类型和代表信号的确定性排序；深度线索锁定态不再在连续线索页显示“本月”固定周期词。
  - 针对 Xcode 报告的四处编译错误，为 `TraceClueComputationInput` 增加显式且向后兼容的 `scope` 初始化参数，使 `StatsWebView` 两个连续线索调用与既有周期测试调用同时成立；为节奏 `compactMap` 明确 `TraceRhythmPoint?` 返回类型；在“减少”分支本地计算 `previousCount - recentCount` 差值，避免跨分支变量越界。
  - 针对后续 `Extra argument 'startDate'` 诊断，为 `TraceRhythmPoint` 增加显式且向后兼容的 `startDate` 初始化参数；原有不传日期的周/月节奏点仍保持 `nil`，连续节奏点可保留日期用于高亮定位。
  - `StatsWebView` 接入四个独立只读区域，保留既有线索 Hero、构成和深度线索，未改变生活页周/月入口或账单/会员/同步规则。
  - 线索冷准备改为只建立一次 `LifeMarkService.PreparedAggregationContext` 和一次候选集合，同时从同一集合读取普通/会员印记；原有普通 8 条、锁定预览 12 条的可见上限保持不变，减少首次整理的重复全账本扫描。
  - `buildClue` 将已计算的认证 `LifeJourneyFact` 传入 Discover，避免再次计算；跨城卡以同一组 evidence ID 生成总数、道路、异地活动和其他行程关联分解，顶部依据与“为什么这样说”不再各自拼接不同口径。
  - 认证且包含周末的跨城自驾被标记为重点发现并使用 Hero 卡；所有有证据的 Discover 卡支持打开详情，详情按当前账本重新解析 ID，提供懒加载照片墙和记录墙，编辑/删除后不会继续展示旧记录。
  - “两条生活线”展开后的依据改为具体同日时间线（最多 4 笔并说明其余数量），明确这是同日共现而非因果；跨城主线则显示统一的证据分解。
- 修改文件：`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。未修改 `site/`、法律页、账单 schema、OCR、照片、会员额度、远程 AI、存储/同步或首页主动作。
- 验证证据：`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py`、`python scripts/playback_copy_lint.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 和 `python scripts/validate_release_gate.py --phase windows` 均通过，最终输出 `release_repository_gate: OK`；copy lint 仍只有任务开始前已有的 6 条 soft warning。`DiscoverEditorialPolicyTests` 新增周末跨城重点卡证据分解、详情 ID 在删除后即时过滤且顺序保持两项覆盖；静态门禁新增聚合复用、重点卡/照片墙/记录墙、统一依据文案和详情解析守卫。
- 剩余风险与下一步：Windows 无 Swift/Xcode，本轮只能以静态门禁和脚本回归确认源码形态，不能宣称 Swift 6 编译、XCTest、照片解码、Sheet 路由和真机耗时已通过，也未量化 100/1,000/5,000 条首次整理的实际下降幅度。下一步必须先在 macOS 重新执行 Swift 6 Debug/Release Clean Build 和全部 XCTest，再按 `FLOW-101` 在 TestFlight 验证首次整理耗时、四层内容、周末跨城 Hero、照片墙/记录墙、编辑/删除后的即时刷新、周期边界、VoiceOver/特大字号/Reduce Motion 及 Instruments 内存和 hitch。签收前保持 `CODE_DONE`，不启动相邻视觉重构。
- 复核记录（2026-09-04）：本轮未扩大产品范围，仅重新执行 `git diff --check`、语义回归、体验静态门禁、文案门禁、播放文案门禁与 `validate_release_gate.py --phase windows`，全部通过，发布门禁仍为 `release_repository_gate: OK`；copy lint 仍仅有任务开始前的 6 条 soft warning。当前机器仍无 `swiftc`、`xcodebuild`，因此状态和下一任务保持不变。

---

## 92. DARK-MODE-READABILITY-01：深色模式正文与操作对比度收口（2026-09-04）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；本项在已推送的 `DISCOVER-EDITORIAL-01` 之后独立处理，不改变线索业务规则。针对 iOS 17 兼容性回归的定向修正已完成，当前无 `IN_PROGRESS`。
- 用户反馈与根因：深色模式仍有“看不清”。源码审计确认，多个深色主题的强调色是浅色调，但按钮和确认操作固定使用 `.white` 前景；同时痕迹月章、记录列表、筛选器、OCR/设置等承载层仍使用 `Color.white.opacity(...)`，在深色背景上形成浅底叠浅字或过低层级差异。现有 token 报告只验证了原始 token 对比度，未覆盖半透明合成后的实际前景/背景组合。
- 首页账单编辑详情的定向复核发现，`自己写一句`、时间、`改`（改分类）及分类选择仍直接使用高亮 accent/半透明白色底，在深色主题中比正文层级更抢眼；本次仅收敛该编辑页的次级控件，不扩大到其他页面。
- 允许范围：主题解析中的可读前景与深色标识；全局语义 Surface 的高光/边框强度；痕迹页主要卡片、筛选器和记录墙的固定白色承载层；直接以 `AppColors.accent` 为背景的主操作按钮前景；对应静态门禁、XCTest 契约、发布矩阵和本文档。不得借本项修改账单、线索、OCR、会员、同步、远程 AI、业务文案或页面信息架构。
- 产品决策：正文层级使用主题 `textPrimary/textSecondary/textTertiary`；主操作统一使用主题计算出的 `onAccent`；深色模式的卡片使用 `panelStrong/surfaceMuted`，不再用固定白色半透明底；图片上的白字和语义删除红色保持原有照片/警示语义，不做全局替换。
- 验收：默认、纸质、天气、霓虹、工业、永久主题的 dark 模式下，首页/记账/痕迹/复盘/设置/OCR/会员的标题、正文、次要说明、筛选选中态和主按钮可读；浅色模式视觉不回退；固定白色卡片不再覆盖承载内容；VoiceOver、特大字号和 Reduce Transparency 不改变操作语义。
- 实施结果：
  - `AppColors` 增加显式 dark-mode 标识、亮/暗高光强度策略和主题对比安全的 `onAccent`/`readableAccent` 入口；全局语义 Surface 的白色高光、边框和按压效果在 dark 模式下降低强度。
  - 首页生活奖励弹层的主按钮改用 `onAccent`，弹层边框和底部 Tab 分隔线改用主题 stroke，避免浅强调色上的白字发虚。
  - 痕迹月章、热力、记录画布、筛选器、细查列表、记录墙、线索重点卡和空态承载层改用 `panelStrong/surfaceMuted/stroke`；线索和月章强调文字改用 `readableAccent`；本周/本月选择态统一为 accent 背景 + onAccent 前景。
  - 无照片 fallback 图块根据 dark 模式使用主题色混合调色，不再落到固定浅色背景；图片上的白字、删除按钮和照片遮罩仍保留原有语义。
  - 修正 iOS 17 部署目标兼容性：深色 fallback 调色改用项目自有 `appMixed`（sRGB 线性插值），不再解析到 iOS 18 专属 `Color.mix(with:by:in:)`。
  - 首页 `RecordEditSheet` 的 `自己写一句`、时间和 `改` 使用深色专用的较低强度 accent；分类选择的未选中底和边框改用主题 surface/stroke，编辑预览、备注输入和更新按钮同步使用主题承载/安全前景，避免次级操作过亮。
  - 新增 `DarkModeReadabilityPolicyTests`，覆盖 dark 高光降级和强调色前景选择；新增 `FLOW-102` 全主题、无障碍和 Reduce Transparency 真机验收矩阵；体验静态门禁增加固定白色承载层回归守卫。
- 修改文件：
  - `NativeDemoApp/ContentView.swift`
  - `NativeDemoApp/Theme/ThemeTokens.swift`
  - `NativeDemoApp/Views/StatsWebView.swift`
  - `NativeDemoApp/Views/RecordEditSheet.swift`
  - `NativeDemoAppTests/StateRegressionTests.swift`
  - `scripts/experience_static_check.ps1`
  - `RELEASE_GATE_AND_DEVICE_MATRIX_v1.md`
  - 本文档
- 验证证据：`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py`、`python scripts/playback_copy_lint.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 和 `python scripts/validate_release_gate.py --phase windows` 均通过；静态门禁新增 iOS 18 `Color.mix` 禁用守卫，发布门禁输出 `release_repository_gate: OK`。copy lint 仍仅保留任务开始前已有的 6 条 soft warning。
- 冻结边界复核：未修改账单、线索业务规则、OCR、会员、同步、远程 AI、业务文案或页面信息架构；浅色主题的原有视觉 token 和照片/警示白字语义保持不变。
- 剩余风险与下一步：Windows 无 Swift/Xcode，无法实测 SwiftUI 材质合成与 31 套主题的真机观感，也不能宣称 XCTest 已运行；下一步在 macOS 执行 Swift 6 Debug/Release Clean Build 与全部 XCTest，并按 `FLOW-102` 完成全主题 iPhone、VoiceOver、特大字号、Reduce Transparency、低亮度及 100/1,000/5,000 条性能签收后再标记 `VERIFIED`。

---

## 93. DISCOVER-MEMORY-WALL-01：线索详情生活片段墙（2026-09-04）

- 状态：`NOT_STARTED` → `IN_PROGRESS` → `CODE_DONE`；本项响应“相关记录打开后照片墙太一板一眼、记录墙缺少叙事节奏”的定向反馈。只处理线索详情的证据展示，不改变 Discover 发现规则或账单含义。
- 目标：照片墙采用确定性的杂志式错落拼贴，记录墙按日期形成可扫描的生活片段时间线；照片和记录继续打开同一条原始账单，编辑/删除后按 evidence ID 重新解析。
- 允许范围：`NativeDemoApp/Views/StatsWebView.swift` 的 `DiscoverDetailSheetView` 及其只读展示辅助；`NativeDemoApp/Views/StatsTraceModels.swift` 的照片墙布局策略；对应 XCTest、体验静态门禁、发布/真机矩阵和本文档。
- 冻结边界：不修改线索连续窗口、卡片评分、跨城认证门槛、账单分类/OCR/金额/日期/标题、照片文件/顺序/封面/加载策略、会员额度、远程 AI、存储/同步、Sheet 路由和生活页周/月入口；不随机旋转、不凭空创建照片或记录，不扩大历史扫描。
- 计划验收：1 张照片为主图；2 张照片不再等高三列；3 张照片为主图+双图；4～6 张按确定性错落双列排列；无照片继续明确降级。记录墙按同日分组并显示时间线连接，点击任意照片/记录打开正确编辑详情；删除或编辑后详情只显示当前账本仍存在的 evidence ID；特大字号、VoiceOver、Reduce Motion 和懒加载语义保持。
- 实施结果：
  - 新增 `DiscoverMemoryWallLayoutPolicy`，按照片数量生成稳定的 `hero`/`pair` 行：单图主图、双图错落双图、三图主图+双图、四至六图及更多照片采用交替高度和对齐的双列拼贴；不使用随机旋转，不改变 evidence 顺序。
  - `DiscoverDetailSheetView` 改用 `LazyVStack` 懒加载照片行，缩略图仍复用现有 `MemoryAttachmentThumbnail` 和缓存/按需解码路径；每张照片保留日期、照片标识、VoiceOver 标签和打开原记录动作。
  - 记录墙按真实日历日分组，同日记录保留卡片 evidence 顺序，以时间点、分类、金额和照片标识组成轻重交替的时间线片段；跨城行程仍能按出发—道路—活动—返程顺序阅读。
  - 详情继续通过 `DiscoverEvidenceResolutionPolicy.resolve` 从当前账本解析 evidence ID，删除/编辑后不会保留旧 `HomeItem`；无照片和无记录状态继续使用明确空态。
- 修改文件：`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。未修改 Discover 算法、账单/照片数据、会员、远程 AI、存储/同步、路由或生活页周期。
- 验证证据：`git diff --check`、`python scripts/life_semantic_regression.py`、`powershell -ExecutionPolicy Bypass -File scripts/check_copy_experience.ps1`、`python scripts/copy_lint.py`、`python scripts/playback_copy_lint.py`、`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 和 `python scripts/validate_release_gate.py --phase windows` 均通过；发布门禁输出 `release_repository_gate: OK`。新增布局 XCTest 覆盖 0/1/2/3/6/9 张照片的行组成、顺序和不重复索引。copy lint 仍仅保留任务开始前已有的 6 条 soft warning。
- 冻结边界复核：未改变 Discover 发现、证据口径、账单字段、照片文件和加载策略、编辑/删除持久化、会员/额度、AI、同步、Sheet 路由或生活页周/月入口；仅改变详情页的确定性展示编排。
- 剩余风险与下一步：Windows 无 Swift/Xcode，无法在本机证明 SwiftUI `ForEach`/动态行高度、照片解码生命周期、VoiceOver/特大字号和 Reduce Motion 的真机观感，也不能宣称 XCTest 已运行。下一步按 `FLOW-103` 在 macOS/Xcode Clean Build、`DiscoverEditorialPolicyTests` 和 TestFlight/Instruments 验证 1/2/3/4～6 张照片、跨日时间线、编辑/删除即时刷新、快速滚动内存和无障碍后再标记 `VERIFIED`。

### 复核记录（2026-09-04）

- 用户反馈底部“周末跨城自驾的证据”与改前区别不明显，并询问详情中“小红岛买东西”“修电瓶车”的纳入原因，以及“过去的回声”下方再次出现跨城自驾是否重复。
- 源码对照结论：截图中的底部大卡实际来自 `traceDeepInsightCard`，不是 `traceDiscoverEditorialBoard` 的 Hero；两者都使用同一个 `LifeJourneyFact`，所以标题、路线和证据口径相似，形成同一事实的两次完整叙述。截图中“过去的回声”卡是另一条“饭点外卖”回声，跨城卡只是紧随其后，并非被 `echoes` 数据重复生成，但当前缺少层级分隔，用户会感知为重复。
- `LifeJourneyFactService.makeCandidate` 会把起止时间内的道路、活动、长途交通和城市切换/结束锚点合并为证据；`transitionRows` 明确加入每次城市切换的第一条记录和行程最后一条记录。因此“小红岛买东西”“修电瓶车”更可能是路线边界锚点，落在“其他行程关联”，不是金额推断或核心道路判定。
- 本轮仅完成产品复核，没有修改代码、账单数据或证据口径。建议下一项独立建立 `DISCOVER-JOURNEY-HIERARCHY-01`，再处理跨城证据分层、底部深度卡去重和回声去重。

---

## 94. DISCOVER-JOURNEY-HIERARCHY-01：跨城线索证据分层与层级去重（2026-09-04）

- 状态：`CODE_DONE` → `IN_PROGRESS` → `CODE_DONE`；2026-09-06 用户在 Xcode 报告 `StatsTraceModels.swift:1280` 无法将 `[Any]` 转换为闭包结果 `DiscoverMemoryWallPhoto`，第 94 项已完成最小编译回补并重新通过 Windows 完整门禁，当前无 `IN_PROGRESS`。原有跨城层级、照片选择与只读展示逻辑保持冻结；修复后的 Xcode 重编、XCTest、真机与 Instruments 仍未签收，因此不得标记 `VERIFIED`。
- 目标：让“AI 重点发现”成为跨城故事的唯一主入口；详情默认突出核心道路/异地活动证据，路线边界记录可展开但不与核心证据混在同一视觉层；“过去的回声”只在存在独立历史证据时呈现，不因当前跨城行程再次单独重复。
- 允许范围：`LifeJourneyFact` 的证据角色投影、跨城详情与 Discover 卡的只读展示编排、回声与当前 Journey 的去重判定、对应 XCTest、体验静态门禁、发布/真机矩阵和本文档。可增加 `boundaryEvidenceItemIDs` 等展示用字段，但不得删除或改写原始账单。
- 冻结边界：不改变跨城认证门槛、城市识别、道路/活动分类规则、账单金额/日期/标题/分类、照片文件和顺序、生活页周期入口、会员额度、远程 AI、存储/同步、Sheet 路由或回放文案；不静默丢弃边界证据，不把展示折叠误报为证据不存在。
- 计划验收：1）同一周末跨城事实在 Discover 只保留一个 Hero 主叙事，底部不再出现同文案的第二张完整大卡；2）详情显示“核心证据”和“路线边界记录”两个层级，默认仍可核对全部 evidence ID；3）边界记录解释为出发/城市切换/返程锚点，“小红岛买东西”“修电瓶车”等记录不会被误标为道路或异地活动；4）无历史同类证据时“过去的回声”不显示当前 Journey，存在真实历史匹配时才显示当前+历史 evidence IDs；5）删除/编辑、照片墙/记录墙、VoiceOver、特大字号和 Reduce Motion 保持现有语义。
- 验证要求：Windows 执行静态门禁、语义回归和发布门禁；macOS/Xcode 执行 Swift 6 Debug/Release Clean Build、相关 XCTest 和 TestFlight 真机签收；用真实南京→宿迁→连云港→宿迁→南京样本核对 10 笔总数、4 笔道路、4 笔异地活动、2 笔边界记录的解释一致性。
- 风险边界：本项只收口展示层重复和证据解释，不影响账单保存与原始证据完整性；代码完成后的未签收风险见下方当前记录。

### 当前记录

- 实现：跨城 Discover 卡新增核心证据与路线边界 evidence ID 投影，详情记录墙按“道路与异地活动 / 出发、城市切换与返程锚点”分层；当最近 14 天的重点卡确实承接同一 Journey 时，旧 Hero 与深度卡不再重复叙述，连续 13 周全局统计独立成概览且生活构成只展示一次；回声排除当前 Journey 重叠，并要求同时保留独立当前证据和真实历史证据。
- 照片墙：改为按 `itemID + imageIndex` 展示真实照片；总图数不超过 8 张时按 evidence 顺序全部展开且每笔封面优先，超过 8 张时每笔只选 `normalizedCoverMemoryImageIndex`；照片瓦片取消账单跳转，记录墙的详情路由保持不变。照片文件、存储顺序、封面含义、加载组件和原始 evidence ID 未改变。
- 修改文件：`NativeDemoApp/Services/LifeMarkService.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 和本文档。
- 验证证据：`git diff --check` 通过；`powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 在补齐本地 Node/Python 运行时与后端依赖后通过；最终 `python scripts/validate_release_gate.py --phase windows` 通过，其中 `life_semantic_regression: OK`、`Static experience checks passed`、`Copy experience checks passed`、`release_repository_gate: OK`，仅保留既有 6 条文案 soft warning。新增 XCTest 源码覆盖照片少量全展/封面优先、多量按笔收敛、Journey 承接条件、核心/边界分区和回声独立证据门槛，但当前 Windows 环境未执行 XCTest。
- 冻结边界复核：没有改变跨城认证、城市识别、道路/活动分类、账单字段、照片文件与存储顺序、会员额度、远程 AI、存储/同步、Sheet 路由或回放文案；删除/编辑后的详情仍按当前账本重解析 evidence ID。
- 剩余风险：缺少 Swift 6 编译、XCTest、真实照片解码、南京→宿迁→连云港→宿迁→南京 10 笔真机样本、VoiceOver、特大字号、Reduce Motion、快速滚动和 Instruments 证据；因此维持 `CODE_DONE`。照片多量阈值 8 和只读瓦片的真机视觉密度仍需按 `FLOW-101`/`FLOW-103` 签收。
- 下一任务：先完成本项及既有性能任务的 macOS/Xcode、TestFlight 真机与 Instruments 基线；前置条件满足后，才可将 `PERF-FIRST-SCREEN-01` 设为唯一 `IN_PROGRESS`。

### Xcode 编译回补（2026-09-06）

- 外部证据与根因：用户在 Xcode 实际编译报告 `StatsTraceModels.swift:1280` 的 `Cannot convert value of type '[Any]' to closure result type 'DiscoverMemoryWallPhoto'`。`DiscoverMemoryWallPhotoPolicy.photos(from:)` 的少量照片分支使用 `flatMap`，其中 `guard` 的空数组返回先被推断为 `[Any]`，闭包元素类型没有稳定绑定到 `DiscoverMemoryWallPhoto`。
- 修复与边界：将闭包显式声明为 `item -> [DiscoverMemoryWallPhoto]`，并新增静态守卫固定该声明和空数组分支。未改变 8 张阈值、每笔封面优先、evidence 顺序、照片瓦片只读、记录墙详情路由、照片文件/索引或任何 Journey/Discover 事实。
- 修改文件：`NativeDemoApp/Views/StatsTraceModels.swift`、`scripts/experience_static_check.ps1` 与本文档。
- 验证证据：`git diff --check` 通过；完整 `scripts/experience_static_check.ps1` 通过并新增输出 `Discover expanded photo selection fixes its Swift closure element type`；`python scripts/validate_release_gate.py --phase windows` 通过并输出 `life_semantic_regression: OK`、`Static experience checks passed`、`Copy experience checks passed`、`release_repository_gate: OK`，100/1,000/5,000 条确定性夹具与真实照片夹具通过，仅保留既有 6 条 copy soft warning。
- 剩余风险与下一步：Windows 无 Swift/Xcode，本轮不能替代修复后的实际 Swift 6 编译。第 94 项维持 `CODE_DONE`；下一步由 Xcode 重新执行 Debug/Release Clean Build，再继续相关 XCTest、`FLOW-101`/`FLOW-103`、TestFlight 与 Instruments 集中签收，全部完成前不标记 `VERIFIED`。

---

## 95. 性能与发热诊断复核（2026-09-04）

- 范围：只读审计长时间使用后的发热、内存和“正在整理”路径；本轮未修改生产代码、数据、UI 或任务状态。
- 代码证据：
  - `StatsTraceSnapshotStore.swift` 的线索整理会执行场景分类、变化比较、生活模式/场景资产/回声、认证跨城事实和生活印记聚合；整理移到 `LedgerBackgroundComputationLane` 只改变线程，不会消除 CPU 工作量。
  - `HomeViewModel.items.didSet` 会同时失效并启动账本派生缓存、首页生活线索和远程叙事预计算；取消是协作式的，已进入同步循环的旧任务仍可能完成一段计算。
  - `HomeItem` 对刚添加或尚未外置的照片保留 `memoryImageDatas`；外置记录启动时只保留引用/字节数，但照片详情仍会解码图片。
  - 图片解码缓存已有 40 张/约 32MB 上限，缩略图最长边 480px、详情最长边 1,600px；这降低了风险，但不能证明真实设备上无峰值。
  - 宠物帧动画、天气/奖励/回放 `TimelineView` 与 `Canvas` 在页面可见时持续刷新，通常是次要但可叠加的 GPU/CPU 来源；联网 AI/WeatherKit 还可能带来无线电耗电。
- 初步结论：整理期间发热主要符合 CPU 计算；整理结束仍发热时，优先排查重复/未及时停止的派生任务、图片解码与进程内原始图片数据，其次才是持续动画或网络。内存占用可能参与，但现有证据不足以断言内存泄漏。
- 当前验证证据：完成源码审计；Windows 无 `swiftc`、`xcodebuild`、Instruments 和 iPhone，未取得 CPU/GPU/内存/热状态实测数据，因此不标记为已验证。
- 下一步：在 macOS 真机按 `FLOW-101`、`FLOW-102`、`FLOW-103` 和 `RELEASE-02` 统一签收中增加 `Time Profiler`、`Energy Log`、`Allocations/Memory Graph`、`Main Thread Hitches` A/B；比较小/大账本、无图/多图、远程 AI/天气开关、宠物开关，并记录整理完成后 10 分钟的 CPU 与内存回落情况。若确认持续开销，再单独建立性能任务，优先做单飞任务合并、外置图片后的内存释放和热/后台降级动画。

---

## 96. PERF-FIRST-SCREEN-01：两阶段首屏与渐进整理（2026-09-05）

- 状态：`IN_PROGRESS` → `CODE_DONE`；2026-09-05 完成 Windows 代码阶段与仓库门禁，当前无 `IN_PROGRESS`。第 94、98、99 项继续保持 `CODE_DONE`；本项及既有任务仍未取得 macOS/Xcode、XCTest 实跑、TestFlight 真机或 Instruments 证据，因此没有标记为 `VERIFIED`。
- 用户诉求：首次打开或首次进入线索时，先快速看到可用内容和可操作界面，再在后台完成高成本整理；避免新用户等待完整计算后才看到首屏。
- 产品方案：
  1. 阶段一（首屏）：立即展示稳定的页面骨架、账本元数据和可安全承接的上次快照/轻量事实；不等待周/月/线索全量整理，不阻塞滚动和记账。
  2. 阶段二（渐进整理）：后台按“当前可见内容 → 关键生活线索 → 低优先级预热”顺序准备完整快照；只在账本修订、筛选和会员身份仍匹配时原子替换，旧任务取消后不得回写。
- 允许范围：`StatsTabState` 的首屏阶段状态、严格匹配的冷启动摘要与真实账本轻量承接、痕迹当前可见快照/关键生活线索/低优先级预热的调度顺序、任务优先级/合并/取消、前后台生命周期、request/revision/scope/member 三重以上发布校验、非阻塞局部整理状态、性能埋点和对应 XCTest/静态门禁/真机矩阵。不得先改线索事实算法或账单数据。
- 冻结边界：不改变账单分类、金额/日期/标题、OCR、照片文件与顺序、线索连续窗口、证据门槛、生活页周/月入口、复盘/回放文案、会员/额度、远程 AI、同步、首页主动作和现有导航语义；不使用假数据填充首屏，不用永久缓存掩盖失败。
- 前置条件记录：原任务卡要求先完成 `DISCOVER-JOURNEY-HIERARCHY-01`、现有 `PERF-15`/`PERF-FIX-*`/`TRACE-PREP-PERF-02` 的 Xcode/真机验证和发热诊断 Instruments 基线。第 94 项及最近定向问题已经完成 Windows 代码阶段；用户最新指令明确要求继续按台账优先级执行，因此本轮在外部签收仍缺失的情况下只推进本项代码与 Windows 门禁。缺失的前置证据继续作为剩余风险和最终签收条件，不得写成已经完成。
- 计划验收：新用户空/少量账本、100/1,000/5,000 条账本和无图/多图账本均能先交互后整理；阶段二完成后内容与单阶段完整计算结果一致；切后台、取消、快速编辑/删除、跨 Tab、低电量、Reduce Motion、VoiceOver、特大字号和内存/热状态无回归；首次首帧、整理完成、主线程 hitch、峰值内存和整理后 10 分钟回落均有真机证据。
- 启动现场：已完整复核 `AGENTS.md`、本台账、任务卡、现有冷启动缓存/快照生命周期/后台计算路径与 `git status --short`。开始时共有 10 个已修改跟踪文件：本文档、`LifeMarkService.swift`、`HomeViewModel.swift`、`StatsTraceFilters.swift`、`StatsTraceModels.swift`、`StatsTraceSnapshotStore.swift`、`StatsWebView.swift`、`StateRegressionTests.swift`、发布矩阵与体验静态门禁；无未跟踪文件。全部作为既有工作区叠加保护，不重置、不清理、不覆盖。
- 审计结论：原实现的严格 fingerprint/day/member/scope 冷启动摘要可以作为阶段一安全内容，但缓存未命中时只有不可访问骨架；旧加载契约还会禁用滚动并把内容从 VoiceOver 隐藏。线索范围筛选、排序和 unlock key 原先在主线程进入后台 lane 之前执行，完成后只校验 latest request，没有把 ledger revision、当前 scope key 和会员身份组成显式原子发布契约，旧任务还可能先写入内存缓存。本项按这些根因定向收口。
- 实现结果：
  - 阶段一只承接 fingerprint、日期、会员、scope 与展示策略版本全部精确匹配的冷启动摘要；缓存 schema 升级为 v2，旧的不兼容条目自动失效。缓存未命中时只显示当前已载入账本的真实记录数或真实空态，不生成部分 `TraceClueSnapshot`，也不伪造线索、金额、活跃天数或分类结论。
  - 整理状态改为不拦截点击的页内提示；移除依赖加载状态的滚动禁用和 VoiceOver 隐藏。缺少当前完整快照时立即以 `.userInitiated` 开始，只有已有可用完整快照的刷新才保留短合并窗口。
  - 周/月范围筛选及连续线索筛选、排序、unlock key 与完整快照构建进入共享 `LedgerBackgroundComputationLane`；线索计算在高成本阶段之间检查协作取消。完整结果以无动画事务一次替换阶段一，不暴露半成品。
  - 发布前同时核对 request、账本 revision、scope、snapshot key、会员身份、日期、内容 revision 和 active scene；校验通过前不写内存缓存。切入后台或 inactive 时取消主任务和预热，回前台只恢复一份最新未完成身份；完成当前内容后，由单一 `.utility` 任务顺序预热线索与其余周/月快照。
  - 新增 `TraceFirstInteractive` 与 `TraceFullReady` Points of Interest signpost，二者使用同一单调时钟起点并记录模式、粗粒度账本数量和阶段耗时，供 `FLOW-106` 在 Instruments 分别量取首屏可交互与完整整理时间。
  - `TraceFirstScreenProgressivePolicyTests` 源码覆盖空/少量账本、缓存五维精确身份、request/revision/scope/key/member/day/content 陈旧拒绝、后台取消与一次前台恢复；线索以及周/月章节均覆盖 0、5、100、1,000、5,000 条的渐进计算与直接完整计算逐字段等价。首屏静态守卫改为逐项断言，避免 `|` 正则只命中任意一个关键词仍误通过。
- 修改文件：本项为 `NativeDemoApp/Services/AnalyticsService.swift`、`NativeDemoApp/Services/LifeInsightService.swift`、`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsTraceSnapshotStore.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`scripts/observability_lint.py`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。`LifeMarkService.swift`、`StatsTraceFilters.swift` 及共享文件内第 94、98、99 项的既有修改均原样保留，不计入本项实现。
- 验证证据：`git diff --check` 通过；完整 `powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过并输出 `observability_lint: OK`、`Static experience checks passed`；`python scripts/validate_release_gate.py --phase windows` 通过并输出 `life_semantic_regression: OK`、`Copy experience checks passed`、`release_repository_gate: OK`，100/1,000/5,000 条确定性夹具与真实照片夹具通过，仅保留既有 6 条 copy soft warning。Windows 没有 Swift、`swiftc`、`xcodebuild`、iPhone 或 Instruments，XCTest 仅完成源码与 Target 接线，未实际运行。
- 冻结边界复核：未改变账单分类、金额/日期/标题、OCR、照片文件与顺序、线索连续窗口、Journey/Discover 证据门槛、生活页周/月入口、复盘/回放文案、会员/额度、远程 AI、同步、首页主动作或导航语义；阶段一不使用假数据，缓存不能覆盖失败或越过身份校验。
- 剩余风险：仍需 Swift 6 Debug/Release Clean Build 验证 `os.signpost`、actor isolation 与任务优先级；需实际运行 `TraceFirstScreenProgressivePolicyTests` 和全部 XCTest。共享 actor 在其他重任务执行期间仍可能排队，部分内部同步算法只能在阶段边界响应取消；真实空/少量/100/1,000/5,000 条及无图/多图账本的首帧、完整整理、Main Thread Hitches、峰值内存、Energy Log 与完成后 10 分钟回落均没有 TestFlight/iPhone/Instruments 数据。
- 下一步：不启动未定义的新代码任务；按 `FLOW-106` 补本项 macOS/Xcode、全部 XCTest、同一 TestFlight 构建的 iPhone 与 Instruments 签收，并与第 94、98、99 项及既有 `CODE_DONE` 矩阵集中验证。取得全部要求证据前维持 `CODE_DONE`。

---

## 97. 近期反馈归档与变更追溯索引（2026-09-04）

- 目的：将本轮“周末跨城”重复、统计口径混用、生活构成重复、饭点外卖回声边界、证据解释和首次整理性能反馈集中归档，并明确哪些已经完成代码、哪些仍是待优化事项。历史任务 1～96 的详细修改文件、冻结边界和验证证据继续以各自任务卡为准；本节只做索引，不替代原任务卡。
- 台账规则：任何生产代码、测试、静态门禁、发布矩阵、官网/运维或法律改动，必须在对应任务卡记录目标、允许范围、冻结边界、修改文件、验证证据、剩余风险和下一任务；`CODE_DONE` 不能写成 `VERIFIED`，没有 macOS/Xcode、真机或生产证据时必须保留未签收状态。每次开始任务前重新检查 `git status --short`，保留现有用户修改。

### 本轮已确认的问题

1. **同一周末跨城故事被完整讲了两次**：截图 2 的大卡来自 `traceClueHeroCard`，截图 1 底部“周末跨城自驾的证据”来自 `traceDeepInsightCard`；两者都使用同一个 `LifeJourneyFact`、同一条路线和同一个问题标题，不是“过去的回声”把跨城事实重复生成。页面上方若出现“AI 重点发现”紧凑卡，则也是同一事实的第三个投影。
2. **跨城故事混入了连续线索窗口的全局统计**：`372 笔`、`82 天有痕迹`、总金额和 `餐饮 148 笔`来自滚动 13 周的全部 `traceClueItems`，不是本次跨城的 10 条证据；10 条证据的正确拆分是 4 笔道路、4 笔异地活动、2 笔路线边界记录。
3. **“生活构成”紧接着重复出现**：`traceClueCompositionCard` 无条件复用同一批连续窗口记录，因此再次展示分类数量和横向占比。它回答的是“这段窗口整体记了什么”，不是“这次跨城如何发生”，但当前视觉层级让用户误以为属于跨城卡。
4. **“饭点外卖”是独立回声，不是重复源**：它由 `LifeNarrativeEchoPolicy.makeEcho` 单独生成；由于回声和跨城事实读取同一账本，当前餐饮记录可能与跨城活动 evidence ID 重叠，但标题重复的根因仍是 Hero/Deep 双投影。后续需要在存在独立历史证据时才保留回声。
5. **“小红岛买东西”“修电瓶车”等记录的角色不清楚**：它们来自跨城起止时间内的城市切换/首条记录/末条记录锚点，当前被归为“其他行程关联”，不代表被金额猜测成道路或异地活动；展示上需要将核心证据与路线边界证据分层解释。
6. **首次整理和长时间使用的性能风险仍未完成真机量化**：当前审计认为整理期间主要是 CPU 计算，持续发热还需排查任务重复/取消滞后、图片解码和原始图片驻留；不能仅凭源码断言内存泄漏。

### 近期已完成代码（仍待相应环境签收）

| 任务 | 已完成内容 | 当前状态与追溯位置 |
|---|---|---|
| `TRACE-DELETE-FIX-01` | 连续左滑删除、快照一致性和删除后列表刷新边界 | `CODE_DONE`，详见第 67 项 |
| `LIFE-JOURNEY-FIX-01` | 充电/跨日跨城事实串联、单笔事实一致性和生活线索投影 | `CODE_DONE`，详见第 71 项 |
| `INTERACTION-MEMORY-FIX-01` | 快速操作任务取消、内存峰值和任务堆积的定向收口 | `CODE_DONE`，详见第 72 项 |
| `AI-JOURNEY-QUERY-FIX-01` | “出去玩”等自然语言查询命中已认证跨城行程 | `CODE_DONE`，详见第 73 项 |
| `HOME-EDIT-PUBLICATION-FIX-01` | 首页编辑后列表即时发布、详情与列表一致、减少等待卡顿 | `CODE_DONE`，详见第 74 项 |
| `PHOTO-JOURNEY-COPY-FIX-01` | 过路费照片事实和跨城推荐指令闭环 | `CODE_DONE`，详见第 76 项 |
| `TRACE-PREP-PERF-01/02` | 事实底稿与回声有界计算，减少重复历史扫描 | `CODE_DONE`，详见第 70、87 项 |
| `TRACE-CLUE-SCOPE-01` | 线索独立连续范围、冷启动身份和统一加载承接 | `CODE_DONE`，详见第 89 项 |
| `DISCOVER-EDITORIAL-01` | Discover 四层卡片、一次聚合复用、跨城重点卡、详情入口和统一证据摘要 | `CODE_DONE`，详见第 91 项；层级重复由第 94 项定向收口 |
| `DARK-MODE-READABILITY-01` | 深色前景/承载层、编辑详情次级控件和 iOS 17 兼容修正 | `CODE_DONE`，详见第 92 项 |
| `DISCOVER-MEMORY-WALL-01` | 确定性杂志式照片墙、按日记录墙、编辑/删除后 evidence ID 重解析 | `CODE_DONE`，详见第 93 项 |
| `DISCOVER-JOURNEY-HIERARCHY-01` | 跨城唯一主叙事、核心/边界证据分层、回声独立证据与照片墙只读多图规则 | `CODE_DONE`；Xcode 报告的照片展开空数组泛型推断错误已定向回补，等待重新编译、XCTest、真机与 Instruments 签收 |

上述任务的 Windows 静态、语义、文案和发布门禁结果已分别写入原任务卡；由于当前环境没有 Swift/Xcode、iPhone 和 Instruments，相关任务均不得提前标记为真机 `VERIFIED`。

### 待优化事项与执行顺序

| 优先级 | 任务 | 待解决内容 | 状态/前置条件 |
|---:|---|---|---|
| P0 | `DISCOVER-JOURNEY-HIERARCHY-01` | 跨城只保留一个 AI 重点主叙事；Hero/Deep 去重；统计与行程证据分口径；核心/边界证据分层；回声排除当前行程重叠并保留真实历史匹配 | `CODE_DONE`；Xcode 报告的照片展开空数组泛型推断错误已定向回补，等待第 94 项重新编译、XCTest、真机与 Instruments 签收 |
| P1 | `PERF-FIRST-SCREEN-01` | 两阶段首屏：先展示安全快照/轻量事实，再后台渐进整理；取消旧任务、原子替换、避免首屏等待 | `CODE_DONE`；Windows 代码与全量门禁完成，等待第 96 项及 `FLOW-106` 的 macOS/Xcode、XCTest、TestFlight 真机与 Instruments 签收 |
| P1 | 性能真机基线 | 用 Time Profiler、Energy Log、Allocations/Memory Graph、Main Thread Hitches 对比小/大账本、无图/多图、AI/天气/宠物开关，并记录整理后 10 分钟回落 | 归档于第 95 项；尚未取得设备证据，不得据此宣称“内存泄漏已修复” |
| P2 | 既有 `CODE_DONE` 集中签收 | Swift 6 Debug/Release Clean Build、全部 XCTest、TestFlight 真实南京→宿迁→连云港→宿迁→南京样本、VoiceOver/特大字号/Reduce Motion | 受 macOS/Xcode/iPhone 环境阻塞，按各任务卡 FLOW 矩阵执行 |

### 本次台账变更

- 索引建立时修改文件：仅更新 `GLOBAL_PRODUCT_INTERACTION_OPTIMIZATION_LEDGER_2026-07-15.md`，未修改生产代码、账单数据、Discover 算法、网站、法律页、服务端或工程配置；后续各任务的实际文件仍以第 94、96、98、99 项为准。
- 索引建立时验证证据：执行 `git status --short` 保护既有工作区，并以 `git diff --check` 确认台账无空白错误或冲突标记；后续 Windows 门禁证据见各任务卡。
- 剩余风险：P0 与 P1 均已完成 Windows 代码阶段但尚未取得 macOS/Xcode、XCTest、TestFlight 真机或 Instruments 证据；所有 `CODE_DONE` 任务仍需按原任务卡完成对应环境签收，不能把 Windows 门禁或文档归档当成真机验证。
- 下一任务：当前无 `IN_PROGRESS`；按第 94、95、96、98、99 项及 `FLOW-101`～`FLOW-106` 集中补齐 macOS/Xcode、全部 XCTest、TestFlight 真机与 Instruments 证据，不启动未定义的新代码任务。

---

## 98. TRACE-CUSTOM-RANGE-FIX-01：细查自定义日期一次应用与范围回显（2026-09-05）

- 状态：`CODE_DONE`；Windows 代码与发布门禁完成，当前无 `IN_PROGRESS`。用户提供的真机截图显示，已选择 `8月6日` 至 `9月4日` 并应用后，时间控件仍显示“具体时间段”，顶部摘要仍显示“自定义时间”，且应用过程有明显卡顿。
- 目标：两个已应用状态统一显示真实日期范围；日期面板使用独立草稿，取消不改变当前筛选，应用时规范化起止日期并只提交一次；列表替换不参与整页弹簧动画。
- 允许范围：`StatsTabState` 的细查日期草稿、确定性日期范围展示策略、`StatsTraceFilters` 的打开/取消/应用编排、既有 `TraceDetailListSnapshot` 的单次刷新、对应 XCTest、体验静态门禁、真机矩阵和本文档。
- 冻结边界：不改变本周/本月/本年、自定义日期的包含边界、时区来源、分类筛选、记录数量、金额合计、日期/同日排序、编辑删除、`LazyVStack`、痕迹主章节、跨城/回声事实、照片、会员额度、存储同步、Sheet 路由或 `PERF-FIRST-SCREEN-01`；不增加固定延时，不把有效旧结果伪装成新筛选结果。
- 计划验证：同日、同年跨月和跨年范围文案确定且两处一致；已应用范围再次编辑时，逐日调整不刷新列表，取消保留原范围，应用后只按最终规范化范围刷新一次；100/1,000/5,000 条账本下应用不再带动整份列表弹簧动画；Windows 门禁通过后保持 `CODE_DONE`，待 macOS/Xcode、XCTest、TestFlight 真机与 Main Thread Hitches 证据后才能标记 `VERIFIED`。
- 实现结果：
  - 新增 `TraceCustomRangePresentationPolicy`，把起止时间规范化到当前日历日边界并纠正倒置范围；已应用标签确定显示为单日 `8月6日`、同年 `8月6日 - 9月4日` 或跨年 `2025年12月31日 - 2026年1月2日`，时间控件和顶部摘要复用同一文案来源。
  - `StatsTabState` 分离已提交范围与编辑草稿，打开时复制、取消/下滑时恢复、应用成功时一次提交；日期步进和快捷范围只修改草稿，不再逐日触发列表重算，跨年长标签允许两行与缩放。
  - 应用操作捕获账本 revision、分类和最终日期 key，经共享 `LedgerBackgroundComputationLane` 后台只生成一份 `TraceDetailListSnapshot`；Task 取消、latest request gate、Sheet/面板存活状态和 candidate/expected key 共同拒绝旧请求或旧 revision，已接受的日期、列表、笔数和合计在禁动画事务中原子发布。
  - 新增 9 个 XCTest 源码用例覆盖单日/同年/跨年文案、倒置范围、草稿隔离、取消、提交和陈旧发布拒绝；体验静态守卫及 `FLOW-104` 覆盖 100/1,000/5,000 条、动态字体、VoiceOver、Reduce Motion 和 Instruments 场景。
- 修改文件：`NativeDemoApp/ViewModels/HomeViewModel.swift`、`NativeDemoApp/Views/StatsTraceFilters.swift`、`NativeDemoApp/Views/StatsTraceModels.swift`、`NativeDemoApp/Views/StatsWebView.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 与本文档。`LifeMarkService.swift`、`StatsTraceSnapshotStore.swift` 及同文件内的 Discover 改动属于前序任务，原样保留。
- 验证证据：`git diff --check` 通过；完整 `scripts/experience_static_check.ps1` 通过；`python scripts/validate_release_gate.py --phase windows` 通过并输出 `release_repository_gate: OK`，包含语义、体验静态、文案、合规页、App Store 元数据、安全头、迁移样本、SQLite schema 及 100/1,000/5,000 条确定性夹具检查。Windows 环境没有 Swift、`swiftc` 或 `xcodebuild`，新增 XCTest 仅完成源码与 Target 接线，未运行。
- 剩余风险：共享 actor 串行通道在既有重任务期间可能排队，排序阶段只能在计算前后响应协作取消；Swift 6 编译/actor 隔离、半宽控件跨年标签、动态字体、VoiceOver、Reduce Motion、快速关闭重开以及 100/1,000/5,000 条下的 Main Thread Hitches/Time Profiler 尚无 macOS、Xcode、TestFlight、真机或 Instruments 证据，因此不得标记为 `VERIFIED`。
- 下一任务：用户随后提供真实记录截图，确认 `8月23日 18:26 过路费回南京` 未进入已经识别的跨城行程；下一项切换为 `LIFE-JOURNEY-RETURN-FIX-01`。`PERF-FIRST-SCREEN-01` 保持 `NOT_STARTED`，本轮不启动。

---

## 99. LIFE-JOURNEY-RETURN-FIX-01：跨城返程证据与闭环终点识别（2026-09-05）

- 状态：`CODE_DONE`；2026-09-05 完成 Windows 代码阶段。用户截图中的 `8月23日 18:25 卤味`、`18:25 修电瓶车` 已在南京，而紧随其后的 `18:26 过路费回南京` 文案和交通事实更明确，却没有进入跨城行程证据。当前环境没有 macOS/Xcode、XCTest、真机或 Instruments 证据，因此不得标记 `VERIFIED`。
- 根因：`LifeJourneyFactService.primaryFact` 在离城后遇到第一条 `homeCity` 记录就立即闭合候选，`makeCandidate` 再以该记录时间截断 `segmentRows`，因此后续明确返程记录从未进入过路费/长途交通识别；普通记录被显示为路线边界来自城市切换投影，并非其文案比返程证据更强。
- 目标：真实城市证据已经确认闭环时，允许同一返程连续段内、同日短窗口且明确以 home city 为目的地的道路或长途交通记录成为完成锚点；行程 `endDate`、道路证据和统一 evidence IDs 同步延长到该锚点。
- 允许范围：`LifeJourneyFactService` 的闭环完成锚点选择与候选终点、对应 XCTest、体验静态门禁、真机矩阵和本文档；只有证明确属事实投影错误时才允许修改 Discover snapshot，不在 `StatsWebView` 展示层补造 evidence ID。
- 冻结边界：不改变 home city 推断、城市路线压缩、最大行程时长、道路/异地活动认证门槛、开放行程、候选排序、日期时区、记录分类、照片、回声、会员、存储同步或远程 AI；标题不能单独把开放行程变成闭环，不把出现 home city 的任意文案、整天本城记录、下一次离城或次日本城日常并入当前行程；不启动 `PERF-FIRST-SCREEN-01`。
- 计划验证：截图同构样本 `南京出发 → 宿迁 → 连云港 → 宿迁 → 卤味 → 修电瓶车 → 过路费回南京` 保持唯一闭环路线，明确返程记录进入 `roadEvidenceItemIDs` 和 `evidenceItemIDs` 并成为 `endDate`；`到南京的过路费` 同样命中，`从南京回宿迁`、超出短窗口、次日记录、下一次离城和没有城市闭环均不得误并；乱序输入和 100/1,000/5,000 条保持确定一致。Windows 完成后最多标记 `CODE_DONE`，仍需 macOS/Xcode、XCTest、TestFlight 与 Instruments 才能 `VERIFIED`。
- 实现结果：真实城市证据仍负责确认行程闭环；从首条本城到达记录开始，只在同一自然日、3 小时内、原有 5 天行程上限内且严格早于下一次离城的位置寻找最早明确返程锚点。锚点必须同时具备过路费或高铁等长途交通证据，并以“回/返/到/到达/抵达 + home city”明确表达目的地；`未到南京`、`从南京回宿迁`、`到南京后继续去宿迁`、`到南京后去宿迁`、`到南京后开往宿迁` 等否定、错误方向或续程文案均拒绝。候选证据使用统一稳定排序后的 item 索引切片，避免同刻下一次离城被 UUID 顺序带入旧行程；命中锚点时同步更新 Journey `endDate`、道路/长途证据与统一 evidence IDs，普通卤味、修车、话费和次日咖啡不被伪装成道路证据。
- 修改文件：本任务范围为 `NativeDemoApp/Services/LifeMarkService.swift`、`NativeDemoAppTests/StateRegressionTests.swift`、`scripts/experience_static_check.ps1`、`RELEASE_GATE_AND_DEVICE_MATRIX_v1.md` 和本文档；这些文件内既有 `DISCOVER-JOURNEY-HIERARCHY-01`、`TRACE-CUSTOM-RANGE-FIX-01` 修改以及 `StatsTraceSnapshotStore.swift` 等其他脏工作区文件均原样保留，不计入本任务实现。
- 验证证据：`git diff --check` 通过；完整 `powershell -ExecutionPolicy Bypass -File scripts/experience_static_check.ps1` 通过；`python scripts/validate_release_gate.py --phase windows` 通过并输出 `life_semantic_regression: OK`、`Static experience checks passed`、`Copy experience checks passed`、`release_repository_gate: OK`，100/1,000/5,000 条确定性夹具与真实照片夹具均通过，仅保留既有 6 条 copy soft warning。新增 XCTest 源码覆盖截图同构返程、到达措辞、高铁返程、否定/错误方向/续程、3 小时与跨日边界、5 天上限、同刻下一次离城双 UUID 顺序、无城市闭环、删除锚点、乱序和三档规模确定性；Windows 环境无法执行 XCTest。
- 剩余风险：尚未取得 Swift 6 Debug/Release Clean Build、`LifeJourneyFactRegressionTests` 实际运行、真实南京→宿迁→连云港→宿迁→南京账本的编辑/删除/重启验证，以及 TestFlight、VoiceOver、特大字号、Reduce Motion、Time Profiler、Main Thread Hitches 和 Allocations 证据；自然语言目的地规则保持保守且有界，新增真实表达仍需在 `FLOW-105` 真机样本中持续核对，因此维持 `CODE_DONE`。
- 下一任务：原计划先补 `FLOW-105` 与既有矩阵的外部签收；用户随后明确要求按台账优先级开始优化并继续，因此 `PERF-FIRST-SCREEN-01` 曾作为唯一 `IN_PROGRESS` 启动 Windows 代码阶段，现已在第 96 项收口为 `CODE_DONE`。第 99 项仍保持 `CODE_DONE`，其 macOS/Xcode、XCTest、TestFlight 真机和 Instruments 风险不因后续任务完成而消失。
