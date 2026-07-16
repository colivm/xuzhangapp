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
