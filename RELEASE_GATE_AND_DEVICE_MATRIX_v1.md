# 叙账 RELEASE-01 发版门禁与统一真机矩阵 v1

> 日期：2026-07-15
> 适用：`NativeDemoApp` iOS 主产品
> 当前状态：2026-07-16 Windows/代码门禁通过；当前为 Windows 环境，Xcode、StoreKit 沙盒和 iPhone 真机矩阵因工具与设备不可用而阻塞
> 结论规则：自动门禁、Xcode 门禁和本文件全部必测项都通过后，才允许把相关任务标为 `VERIFIED`。

## 1. 冻结边界

本门禁只提供确定性夹具、测试接线、Debug 隔离装载和验收记录，不改变：

- 账单字段、分类、OCR/AI 结论、额度、会员价格和购买恢复逻辑。
- 今日回放、周记、月章、生活线索和月度整理的生成规则。
- 云端 DTO、同步冲突规则和“照片仅本机”的产品承诺。
- `web-preview` 的行为与视觉。

任何真机失败只允许定向修复对应任务，不得借发版检查重写其他已完成项。

## 2. 确定性夹具基线

夹具目录：`qa/release_fixtures/`。日期采用 UTC 的 Apple 参考时间秒数；三个规模共享相同的前缀 ID 和生成公式。

| 记录数 | 金额分总和 | 含图记录 | 图片数 | OCR pending/resolved | 年份 | 记录摘要前 12 位 |
|---:|---:|---:|---:|---:|---|---|
| 100 | 2,462,750 | 8 | 15 | 5 / 5 | 2024/2025/2026 | `f3a282ed166f` |
| 1,000 | 25,077,500 | 77 | 153 | 46 / 45 | 2024/2025/2026 | `0117d6c97b78` |
| 5,000 | 125,487,500 | 385 | 769 | 228 / 227 | 2024/2025/2026 | `6c597531a746` |

每档均覆盖全部十个分类、旧单图、旧多图、非零封面、多图顺序、有效 1×1 PNG、OCR 待整理/已整理、记忆上下文和跨年日期。完整总摘要固定为：

```text
df670606b42414bdf43f34d66d2b5977f897eaf5dc0fe3e5cc428f18977e7129
```

重新生成与验证：

```powershell
python scripts/generate_release_fixtures.py
python scripts/validate_release_gate.py --phase fixtures
```

生成后若摘要变化，必须先解释公式或数据边界为什么变化；不得直接更新基线掩盖回归。

PERF-04 另提供 3 张确定性真实尺寸 JPEG，位于 `NativeDemoApp/Resources/QARealPhotos/`：均不少于 12 MP、单张不少于 2 MB。它们只用于真机冷启动、滚动、缩略图和原图内存压力，不替代上表迁移夹具。

## 3. 自动门禁顺序

### 3.1 Windows/跨平台代码门禁

```powershell
python scripts/validate_release_gate.py --phase windows
```

该命令按失败即停顺序执行：夹具结构与摘要、`git diff --check`、生活语义回归、体验静态检查、文案体验检查、文案 lint、迁移样本和 SQLite schema 实际执行。体验静态检查内部继续执行术语、会员价值、AI 能力、无障碍和可观测性专项 lint。

### 3.2 macOS/Xcode 门禁

```bash
python3 scripts/validate_release_gate.py --phase all \
  --simulator-destination 'platform=iOS Simulator,name=iPhone 15'
```

必须保留以下三段独立结果，任一失败均不能发版：

1. Debug build。
2. Release build。
3. `NativeDemoAppTests` 全部 XCTest。

同时检查 Xcode 日志中无新增 Swift concurrency、actor isolation、Sendable、SQLite 链接、SwiftUI 泛型推断或可访问性 API 警告/错误。

2026-07-16 环境审计：当前系统为 Windows 10（10.0.19045），`xcodebuild`、`swift`、`simctl`、`instruments` 均不可用。因此本节没有执行，状态为 `BLOCKED`；解除条件是在 macOS/Xcode 环境运行上述三段命令并保存独立日志。

## 4. Debug 真机夹具装载

在 Xcode Scheme 的 Run Arguments 添加：

```text
-QAReleaseFixtureCount 1000
-QAReleaseFixtureReset
```

记录数只接受 `100`、`1000`、`5000`。也可使用环境变量 `QA_RELEASE_FIXTURE_COUNT` 和 `QA_RELEASE_FIXTURE_RESET=1`。

- 仅 Debug 生效；Release 构建不会装载。
- 账本写入 `Documents/QAReleaseFixtures/ledger_<count>_<photo-profile>/`，不覆盖普通账本。
- `-QAReleaseFixtureReset` 每次新进程先重建对应隔离账本；同一进程不会反复清空。
- 首次启动先写旧格式 JSON，再走真实图片文件化和 SQLite 激活路径。
- `tiny` 默认配置按上一条执行；`realistic` 配置直接建立隔离 SQLite/图片目录，避免把数百 MB Base64 JSON 当作性能目标本身。
- 夹具模式自动停止 `HomeViewModel` 云端上传/删除/合并，防止假数据进入真实账号。
- R-11 同步必须关闭夹具参数，并使用专用测试账号与可清理的云端环境。

完成每档性能测试后，从 Xcode Devices and Simulators 下载 App Container，再执行精确迁移审计：

```powershell
python scripts/validate_release_gate.py --phase device-audit `
  --device-container "D:\evidence\NativeDemoApp.xcappdata" `
  --expected-count 5000 `
  --photo-profile tiny
```

审计会读取隔离目录中的 SQLite 和图片文件，核对 quick check、schema、记录数、金额分、分类、OCR 状态、图片 SHA/顺序/封面、文件 byte count 和迁移 manifest。

### 4.1 PERF-04 真实照片性能装载

首次建立隔离数据：

```text
-QAReleaseFixtureCount 1000
-QAReleasePhotoProfile realistic
-QAReleaseFixtureReset
```

建立完成后移除 `-QAReleaseFixtureReset`，完全杀进程并连续冷启动 5 次。控制台必须出现 `PERF-04 ledger metadata cold start`，同时使用 Instruments 的 App Launch、Core Animation 和 Allocations/Memory Graph 记录：

| ID | 操作 | 通过标准 | 状态 |
|---|---|---|---|
| REAL-01 | 1,000 条、153 张 12 MP/约 3 MB 照片，连续冷启动 5 次 | 启动只读元数据；首屏可交互 p50 ≤ 1.8s、p95 ≤ 2.5s；无逐张原图读取峰值 | `NOT_RUN` |
| REAL-02 | 首页连续上下滚动 30 秒，再进入痕迹周/月卡 | 列表只加载缩略图；>100ms hitch 不超过 3 次，无单次 >400ms；图片出现时不跳错记录 | `NOT_RUN` |
| REAL-03 | 快速打开/关闭 10 条带图详情，并切换多图 | 详情才读取原图；关闭后内存可回落；无图片串位、黑屏或持续增长 | `NOT_RUN` |
| REAL-04 | 编辑一条无图记录、编辑一条带图记录、删中间图、换封面 | 只变更对应 SQLite 行和记录图片目录；其他图片修改时间不变 | `NOT_RUN` |
| REAL-05 | 记录稳定内存 | 首页稳定内存 ≤220 MB、滚动峰值 ≤320 MB、原图详情峰值 ≤420 MB；退出详情后 30 秒内明显回落 | `NOT_RUN` |

若设备低于 iPhone 13 或系统调试开销明显，允许同时记录设备基线对照，但不得只用模拟器替代以上真机结论。

## 5. 统一真机环境

至少覆盖：

- 一台小屏 iPhone 与一台常规/大屏 iPhone。
- 当前最低支持 iOS 与当前稳定 iOS；若只能使用一台设备，另一个系统版本用模拟器补布局，不替代 StoreKit、相册、权限和性能真机证据。
- 免费用户、月/年订阅沙盒用户、永久会员沙盒用户、未登录和专用同步账号。
- Wi-Fi 正常、离线、弱网/请求失败三种联网状态。

证据统一填写：设备/系统、构建号、夹具规模、前置状态、操作、实际结果、截图或录屏、日志、结论（`PASS`/`FAIL`/`BLOCKED`）和缺陷编号。

## 6. FIX-001 / FIX-002 必测

| ID | 前置与操作 | 通过标准 | 状态 |
|---|---|---|---|
| FIX-001-A | AI 指令台生成多条草稿并“确认导入” | 保存后回到指令台顶部，有成功承接，无白屏、重复 Sheet 或重复保存 | `NOT_RUN` |
| FIX-001-B | 只剩最后一条草稿时单笔保存 | 结果清空后页面仍有标题/输入区，不停在空白滚动区域 | `NOT_RUN` |
| FIX-001-C | 有结果时点清空，再立即输入新指令 | 回顶、输入可用、旧任务不回写 | `NOT_RUN` |
| FIX-002-A | 工作日 08:30 前补记今天通勤 | 今天不生成未来通勤 | `NOT_RUN` |
| FIX-002-B | 工作日 08:30～18:29 补记今天通勤 | 只生成早高峰，不生成晚间 | `NOT_RUN` |
| FIX-002-C | 工作日 18:30 后补记今天通勤 | 可生成早晚两条，重复检测仍有效 | `NOT_RUN` |
| FIX-002-D | 补记昨天/上周，另测周末/节假日 | 历史早晚规则和原工作日判断不变 | `NOT_RUN` |

## 7. 固定 R-01～R-12 回归

| ID | 核心操作 | 必查边界 | 建议数据 | 状态 |
|---|---|---|---|---|
| R-01 | 手动只输金额保存 | 只保存一次；标题/分类预填正确；成功承接不叠层 | 空账本、100 | `NOT_RUN` |
| R-02 | 手动改分类、备注、日期后切 Tab 返回并保存 | 用户锁定不被推荐覆盖；草稿日期不漂移；保存后才重置 | 空账本、100 | `NOT_RUN` |
| R-03 | 第一笔分别选“继续记”“听今日回放” | 未点击播放不扣额度；点击只扣一次；照片/奖励/宠物按队列出现 | 空账本 | `NOT_RUN` |
| R-04 | OCR 识别、取消、确认、快速重复点、待整理编辑/删除/全部确认 | 取消不写入；一次提交；pending/resolved 正确；关闭不偷偷导入 | 空账本、100 | `NOT_RUN` |
| R-05 | AI 通勤补记 | 执行 FIX-002 全部时段；历史和重复检测不变 | 空账本、100 | `NOT_RUN` |
| R-06 | AI 查询/补记后批量、单笔保存和清空 | 执行 FIX-001；快速重跑只落最后结果；切 Tab/关闭后旧任务不反写 | 100/1,000/5,000 | `NOT_RUN` |
| R-07 | 今日回放开始、暂停、继续、重播、关闭、额度用尽 | 明确开始才扣；退出完成度正确；关闭后队列继续且不叠层 | 100 | `NOT_RUN` |
| R-08 | 周记/月章切换、播放、空数据、弱数据、额度用尽 | 痕迹为完整章节主入口；周/月不串；旧内容承接；额度常量不变 | 空账本、100/1,000/5,000 | `NOT_RUN` |
| R-09 | 痕迹生活/线索、周/月/自定义/分类快速切换并切 Tab 返回 | 筛选/滚动保留；旧计算不反写；1,000/5,000 条可持续滚动 | 1,000/5,000 | `NOT_RUN` |
| R-10 | 多图新增、删中间图、换封面、缺图、相册取消/失败 | 顺序/封面稳定；缺图只影响该图；失败不破坏账本；孤儿清理 | 100/1,000 | `NOT_RUN` |
| R-11 | 专用账号上传、另一设备拉取、冲突合并、退出登录、删除云端字段 | 本地不被意外清空；冲突保留最新；照片不上传且文案明确 | 关闭 QA 参数 | `NOT_RUN` |
| R-12 | 月/年/永久购买成功、取消、失败、重复点、恢复成功/无权益 | 遮罩复位；权益和高亮正确；无重复购买；恢复结论准确 | StoreKit 沙盒 | `NOT_RUN` |

## 8. 前序优化集中签收

| 范围 | 必测项 | 通过标准 | 状态 |
|---|---|---|---|
| INT-01 | 连续保存两笔，分别触发照片与奖励；首笔选两种承接 | 同一时刻一个提示；FIFO 不丢失；回放只在点击后扣额度 | `NOT_RUN` |
| INT-02 | 首笔后连续保存、20 分钟内/后、跨自然日分别触发照片与奖励 | 单次保存最多一个强提示；每天最多两个；20 分钟冷却；奖励资格和照片入口仍存在 | `NOT_RUN` |
| NAV-01 | AI/痕迹/回放/设置会员入口快速连点和下滑关闭 | 不出现 `Attempt to present...`、空白 Sheet、重复页或目标丢失 | `NOT_RUN` |
| NAV-02 | 痕迹、复盘、记录页分别建立上下文后跨 Tab 往返 | 模式、筛选、滚动和未提交草稿保留；只构建当前 Tab | `NOT_RUN` |
| DATA-02/03 | 三档夹具首次启动迁移、单笔增删改、重启 | device-audit 全通过；已有图片/旧 JSON 不被无关重写；失败可恢复 | `NOT_RUN` |
| DATA-04 | 本地备份导出、缺图导出、清空本机危险提示 | 包含可用照片并报告缺图；不声称云端含照片 | `NOT_RUN` |
| DATA-06 | 导出后重新导入、预览取消、较新/较旧冲突、缺图包、篡改包与恢复失败 | 确认前零写入；只合并新增或较新记录；本机相同/较新版本保留；缺图位置可见；篡改/失败不替换原账本 | `NOT_RUN` |
| PERF-01/02 | 1,000/5,000 条滚动、输入、切范围、快速重跑/取消 | 主线程无明显长卡顿；加载态可取消；旧结果不回写 | `NOT_RUN` |
| PERF-03/DATA-05 | 真实照片启动、缩略图/原图加载、单笔增删改 | 启动不 hydrate 原图；只处理变化记录和对应图片目录；失败可回退 | `NOT_RUN` |
| PERF-04 | 执行 REAL-01～REAL-05 | 真实照片尺寸/字节验证通过，冷启动、滚动和内存达到阈值 | `NOT_RUN` |
| PROD-01/02 | 从痕迹看周/月章，从复盘继续问；全入口术语巡检 | 职责可理解；不出现并行旧称或第二份完整周/月章 | `NOT_RUN` |
| MEMBER-01/AI | 免费、会员、联网开关、远程成功/失败/缺 Key/额度耗尽 | 两层价值清晰；次数不变；本机/远程/回退来源真实；不编造事实 | `NOT_RUN` |
| MEMBER-02 | 未登录购买/恢复、登录取消/失败/成功、登录后再次确认、快速重复点 | 会员页直达登录；套餐/恢复意图只续接一次；登录后不自动扣款；Product ID、价格、验证和账号绑定不变 | `NOT_RUN` |
| OBS-01 | 首记、首播、周/月、AI、会员漏斗与耗时 | 事件顺序/桶正确；本机最多 1,000 条/30 天；无金额、标题、备注等敏感字段 | `NOT_RUN` |

### 8.1 DATA-06 本地备份恢复专项

| ID | 操作 | 通过标准 | 状态 |
|---|---|---|---|
| BACKUP-01 | 导出含多图/非首图封面的备份，再从“备份与联网”选择该包 | 校验在后台完成；预览显示时间、记录数和照片数；尚未确认时本机账本与图片目录不变 | `NOT_RUN` |
| BACKUP-02 | 在预览页取消、点遮罩取消，再重新选择并确认 | 两种取消都零写入；确认后新增记录进入正确日期顺序，照片顺序和封面不变 | `NOT_RUN` |
| BACKUP-03 | 同 ID 分别准备“本机较新、时间相同、备份较新”三组冲突 | 本机较新和相同版本保留；只有备份较新版本更新；每个恢复意图只执行一次 | `NOT_RUN` |
| BACKUP-04 | 导入官方导出但报告缺图的包，再导入照片内容被篡改或清单数量不符的包 | 官方缺图包可恢复并保留缺图位置；篡改/清单异常包拒绝，原账本和原照片保持不变 | `NOT_RUN` |
| BACKUP-05 | 1,000 条真实照片夹具导出并恢复，恢复时尝试下滑关闭 | 有明确加载态；恢复期间不可误关或重复提交；完成后仅变化记录/图片落盘，无空账本或持续卡死 | `NOT_RUN` |

### 8.2 MEMBER-02 登录续购专项

| ID | 操作 | 通过标准 | 状态 |
|---|---|---|---|
| MEMBER-LOGIN-01 | 未登录时分别点年度、月度、永久会员 | 直接打开账号登录 Sheet；返回后仍保留原套餐和实时价格；未再次点击前不出现 StoreKit 购买页 | `NOT_RUN` |
| MEMBER-LOGIN-02 | 登录 Sheet 发送验证码失败、验证码错误、取消和下滑关闭 | 可安全重试或取消；不调用购买、不出现重复 Sheet；回到会员页后可重新选择 | `NOT_RUN` |
| MEMBER-LOGIN-03 | 免费账号登录成功，再点续接卡片一次并快速重复点 | 只在明确点击后发起一次原套餐购买；购买遮罩阻止重复提交；Product ID 与 appAccountToken 绑定不变 | `NOT_RUN` |
| MEMBER-LOGIN-04 | 未登录点恢复购买，登录成功后暂不继续，再重新操作并确认 | 登录后不自动查询 StoreKit；恢复意图只消费一次；取消后可重新发起，恢复结果仍绑定当前账号 | `NOT_RUN` |
| MEMBER-LOGIN-05 | 登录到已有有效会员或永久会员的账号 | 直接同步现有权益并停止续购意图，不重复购买；会员页显示正确层级与到期状态 | `NOT_RUN` |

## 9. 无障碍与权限矩阵

| ID | 操作 | 通过标准 | 状态 |
|---|---|---|---|
| A11Y-01 | 默认、特大和至少一个无障碍字号走五个 Tab、OCR、会员、回放 | 不截断关键文案；按钮可触达；需要时自动纵排 | `NOT_RUN` |
| A11Y-02 | VoiceOver 走五个 Tab、AI 指令、图表、OCR、会员、回放完成页 | 名称/值/状态/提示完整；选中状态明确；图表有摘要 | `NOT_RUN` |
| A11Y-03 | 开启 Reduce Motion 后重复 AI、痕迹、记录/OCR、会员、回放 | 非必要位移/缩放/弹簧停用；功能反馈仍存在 | `NOT_RUN` |
| PERM-01 | 首次位置请求选择不允许，并在系统设置保持拒绝 | 记账和回放可用；天气上下文安全降级；无循环索权 | `NOT_RUN` |
| PERM-02 | 相册选择取消、有限照片、拒绝访问 | 不新增空图；队列释放；账本和已有图片不受损 | `NOT_RUN` |
| PERM-03 | 保存分享图时拒绝“添加照片”权限 | 明确失败提示；页面可继续操作；无假成功 | `NOT_RUN` |
| NET-01 | 离线执行 AI 指令台、今日小记、月度整理、同步 | 本机指令仍可用；远程功能明确回退/失败；本地数据保留 | `NOT_RUN` |

## 10. 发版签收记录

| 门禁 | 结果 | 证据位置/日志 | 签收人 | 日期 |
|---|---|---|---|---|
| Windows repository gate | `PASS` | `python scripts/validate_release_gate.py --phase windows`；夹具、差异、语义、交互、文案、迁移和 SQLite schema 全通过；仅有既有 7 条文案软提示 | Codex | 2026-07-16 |
| Xcode Debug build | `BLOCKED` | Windows 环境无 `xcodebuild`/Swift 工具链 | Codex | 2026-07-16 |
| Xcode Release build | `BLOCKED` | Windows 环境无 `xcodebuild`/Swift 工具链 | Codex | 2026-07-16 |
| 全部 XCTest | `BLOCKED` | 测试已接线；当前环境无法运行 iOS XCTest | Codex | 2026-07-16 |
| 100 条真机 | `BLOCKED` | 无 iPhone/Xcode 设备部署环境 | Codex | 2026-07-16 |
| 1,000 条真机 | `BLOCKED` | 无 iPhone/Xcode 设备部署环境 | Codex | 2026-07-16 |
| 5,000 条真机 | `BLOCKED` | 无 iPhone/Xcode 设备部署环境 | Codex | 2026-07-16 |
| 真实照片 REAL-01～05 | `BLOCKED` | 真实照片资产与夹具通过；无 iPhone/Instruments | Codex | 2026-07-16 |
| FIX-001/002 | `BLOCKED` | 无 iPhone，详细场景保持 `NOT_RUN` | Codex | 2026-07-16 |
| R-01～R-12 | `BLOCKED` | 无 iPhone；StoreKit/同步场景还需要沙盒账号与专用环境 | Codex | 2026-07-16 |
| DATA-06 BACKUP-01～05 | `BLOCKED` | 无 iOS 文件 App、iPhone 与 1,000 条恢复性能环境 | Codex | 2026-07-16 |
| MEMBER-02 MEMBER-LOGIN-01～05 | `BLOCKED` | 无短信测试账号、iPhone 与 StoreKit 沙盒 | Codex | 2026-07-16 |
| 无障碍/权限 | `BLOCKED` | 无 iPhone VoiceOver、Dynamic Type、Reduce Motion 与权限环境 | Codex | 2026-07-16 |
| StoreKit/同步 | `BLOCKED` | 无 StoreKit 沙盒、短信/同步测试账号与第二设备 | Codex | 2026-07-16 |

最终结论只能填写：

- `PASS`：所有必测项通过，且 device-audit 与自动门禁一致。
- `FAIL`：存在可复现缺陷，记录所属任务和定向修复范围。
- `BLOCKED`：缺设备、账号、Xcode 或外部服务；不得写成已验证。
