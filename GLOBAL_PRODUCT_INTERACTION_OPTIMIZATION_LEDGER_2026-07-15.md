# 叙账全局产品与交互优化执行台账

> 创建日期：2026-07-15
> 当前基线提交：`d425389`（`fix trace snapshot type checking`）
> 状态：第二轮全局收口进行中；本文档仍是唯一顺序与状态来源
> 适用范围：`NativeDemoApp` iOS 主产品；除非任务明确写入，默认不修改 `web-preview`

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
| `web-preview/app.js` | 已修改 | 既有修改，iOS 优化默认不处理 |
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
8. `web-preview` 行为和视觉。
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

---

## 9. 当前交接状态

- 当前无 `IN_PROGRESS`；`ARCH-FIX-01`、`ARCH-01`、`ARCH-02` 已完成 Windows 代码与回归，`RELEASE-02` 继续因缺少 Xcode、iPhone、StoreKit 沙盒与权限/无障碍真机条件而 `BLOCKED`。
- 保留阻塞任务：`GATE-00`，等待后续 macOS/Xcode 与真机补签收。
- 用户例外授权：2026-07-15 第一次允许启动 `INT-01`，第二次允许启动 `NAV-01`；第三次明确要求后续任务不再逐项询问、全部代码完成后统一真机验证。所有授权均不代表前序 Xcode/真机验收通过。
- 当前代码完成待签收：`INT-01`、`NAV-01`、`NAV-02`、`TEST-01`、`DATA-01`、`DATA-02`、`DATA-03`、`DATA-04`、`PERF-01`、`PERF-02`、`PROD-01`、`PROD-02`、`MEMBER-01`、`AI-01`、`A11Y-01`、`OBS-01`、`RELEASE-01`、`COPY-01`、`PERF-03`、`DATA-05`、`PERF-04`、`INT-02`、`DATA-06`、`MEMBER-02`。
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
| 3 | COPY-02 | 周记/月章播放文案活人感收敛 | `NOT_STARTED` | v2 可评审方案已完成并保留；先处理用户真机 Xcode 暴露的预填编译错误，用户确认方案后再启动文案代码 |

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
