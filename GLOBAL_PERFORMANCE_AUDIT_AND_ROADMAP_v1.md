# 叙账全局性能专项：审计与治理方案

日期：2026-09-15  
范围：`NativeDemoApp` iOS 客户端的启动、编辑、照片、批量导入、复盘、同步和分享链路。  
本轮原则：先证据、后改造；一次只推进一个性能任务，不改变账单字段、语义识别、会员规则、同步冲突规则或照片云端边界。

## 1. 审计结论

当前最明确的性能瓶颈有三类：

1. 主线程同步持久化：`HomeViewModel` 为 `@MainActor`，补图、删图、设封面、编辑和批量导入最终会同步进入 `persistItems`，继续执行图片哈希/写文件、SQLite 事务和孤儿清理。
2. 主线程批量工作：OCR/AI 批量导入在主 actor 构建并保存大量记录；分享背景和部分分享图渲染仍可能在 `Task @MainActor` 中做图片解码、缩放和渲染。
3. 同步请求重复：云同步合并和上传在 `HomeViewModel` 编排，上传逐笔串行；多次快速编辑同一记录会产生重复旧请求，单笔成功还会重复扫描全量 `items`。

照片展示的解码已经有 `MemoryAttachmentImageLoader` actor 和缓存；带图详情当前页/相邻页策略已收口为“当前展开页原图，其余缩略图”，仍需真机帧率确认。

## 2. 分级问题清单

### P0：优先治理，直接影响编辑和批量导入交互

| 问题 | 证据 | 用户表现 | 处理方向 |
|---|---|---|---|
| 写账单同步落盘 | `HomeViewModel.swift:1927-2062` → `persistItems` → `LedgerHomeItemsRepository.saveChanges`；`LedgerImageStore.prepareForPersistence`、SQLite `applyChanges`、`cleanupRecordOrphans` 均在调用链内 | 补照片、删图、编辑后短暂停顿/掉帧 | 建立串行 `LedgerPersistenceWriter` actor；主 actor 只提交不可变变更快照，成功后发布轻量 projection |
| 批量 OCR/AI 导入同步写入 | `HomeViewModel.swift:1414-1584`；OCR 确认路径在 `OCRConfirmSheet.swift:178-199` | 100/1,000 条导入时界面卡住 | 后台构建和校验批次，单次事务提交；进度状态回主 actor |
| 新图写盘与哈希 | `LedgerImageStore.swift:162-225` | 第一次补大图时尾帧 | 图片文件写入放入 persistence actor；不在 UI actor 做 SHA256/原子写盘 |
| 账单变更比较触碰图片 Data | `HomeViewModel.swift:3595+` 的 `ledgerChanges`；`HomeItem` 含 `memoryImageDatas` | 同步/批量操作时按字节比较大图 | 先按 ID、`updatedAt` 和元数据判断；照片引用/摘要单独比较，避免主线程复制原图 |

### P1：高收益，影响复盘、分享和同步耗时

| 问题 | 证据 | 用户表现 | 处理方向 |
|---|---|---|---|
| 分享背景处理仍可能在主 actor | `SummaryPlaybackSheet.swift:2467-2474`、`3247-3271` | 选大图作背景时界面冻结 | 统一 `ShareImagePreparation` detached pipeline，主 actor 只收结果 |
| 分享图渲染可能占主线程 | `SummaryPlaybackSheet.swift:3004-3022` | 保存分享图时动画/按钮无响应 | 用 signpost 量化后把渲染移到后台，完成后原子替换导出状态 |
| 同步上传逐笔串行且重复 | `HomeViewModel.swift:2100-2128`、`3625-3640` 及多处 `syncUpsertToCloud` | 大账本同步慢、状态消息抖动、快速编辑浪费请求 | `SyncCoordinator` actor 按 ID 合并/去重/debounce；有限并发或批量 API；复用 service 和 ID 索引 |
| 缩略图首次生成在滑动路径 | `LedgerImageStore.swift:261-307` | 首次翻页出现加载尾帧 | 缩略图生成与 UI 加载解耦，后台生成并缓存；当前页优先、相邻页低优先级 |
| 本地备份导出在主 actor 准备 | `SettingsView.swift:842-860` → `LedgerLocalBackupDocument.init` | 大账本导出时设置页冻结 | 后台读取原图、哈希、组装 FileWrapper 和 JSON；主 actor 只启动/结束 fileExporter |
| 痕迹详情同步生成快照 | `StatsWebView.swift:1073-1102, 6852-6902, 7431-7439` | 大账本筛选/打开详情时卡顿 | 后台生成不可变 snapshot，按 revision 丢弃过期结果 |

### P2：中长期治理，影响启动和大数据规模

| 问题 | 证据 | 处理方向 |
|---|---|---|
| 冷启动同步读账本与校验 | `HomeViewModel.swift:1202-1240`；`LedgerMetadataStore` 全量读记录、图片引用并执行完整性检查 | 两阶段启动：先展示可用骨架，再后台加载/校验并原子发布 |
| 初始派生缓存全量构建 | `HomeViewModel.swift:1081-1090, 1229-1240` | 大账本首屏延迟 | 复用已有 `LedgerBackgroundComputationLane`，按首屏优先、后台预热拆分 |
| 图片原图仍驻留内存 | `LedgerHomeItemsRepository.saveChanges` 后内存 `items` 可能保留完整 Data | 大账本 RSS 上升、SwiftUI diff 变慢 | 成功落盘后内存 projection 只保留引用/byteCount，详情按需读取 |

## 3. 分阶段实施顺序

### 阶段 0：建立可重复基线

- 使用 Instruments Time Profiler、Points of Interest、Allocations 和 Main Thread Checker。
- 记录冷启动、补图、详情分页、痕迹筛选、本地备份导出、分享图保存六条路径的 P50/P95、主线程超过 16.7ms 次数、峰值 RSS 和后台任务耗时。
- 使用 100/1,000/5,000 条账单夹具，以及 10MP × 1/3/9 张照片；本阶段只加 signpost/测试夹具，不改业务结果。

### 阶段 A：P0 持久化不卡 UI

只处理 `LedgerPersistenceWriter` actor 和批量提交协议：

- 输入：不可变 `LedgerHomeItemsChangeSet` + 当前版本号。
- 后台：图片外置、哈希、文件写入、SQLite 事务、孤儿清理。
- 主 actor：立即发布“处理中”状态；成功后用版本号确认结果仍对应当前账本，再更新 projection。
- 失败：保留原内存账本，显示明确失败状态，不触发云端上传。
- 反向场景：快速连续编辑、删除后撤销、同步合并期间补图、写入失败重试。

### 阶段 B：P0 批量导入

- OCR/AI 先在后台生成批次快照和校验结果。
- 一次 SQLite 事务提交，避免逐条 `persistItems`。
- UI 显示已处理数量，不在每条记录完成时触发全量派生计算或逐笔云上传。

### 阶段 C：P1 同步队列

- 按 `recordID` 只保留最新版本。
- 300–500ms debounce 合并快速编辑；退出页面/进入后台时 flush。
- 服务器支持前提下增加批量 upsert；否则有限并发，不能无限创建 Task。
- 同步完成只发布一次状态，避免每笔请求覆盖 `syncStatusMessage`。

### 阶段 D：P1 图片、备份与分享管线

- 统一图片读取、缩略图、分享背景和导出渲染的 detached pipeline。
- 本地备份包的照片读取、SHA256、FileWrapper 和 JSON 组装不得在主 actor 执行。
- 明确三档尺寸：列表缩略图、详情展示图、分享导出图。
- 每个请求带取消 token 和 revision，旧页面/旧分享任务完成后不得覆盖新状态。

### 阶段 E：P2 启动和内存

- 启动阶段 1：读取最小账本摘要并展示首屏。
- 启动阶段 2：后台校验 SQLite、加载图片引用和派生缓存。
- 对 1,000/5,000 条账本测量首帧、可交互时间、RSS 和滚动帧率。

## 4. 指标与验收矩阵

必须在 macOS/Xcode 真机用 Instruments（Time Profiler、Points of Interest、Allocations）记录：

| 指标 | 当前基线 | 目标 |
|---|---:|---:|
| 冷启动到首个可交互页面 | 待测 | P0 阶段不回归；P2 再降低 |
| 编辑/补图主线程最长阻塞 | 待测 | 普通记录 < 16ms；大图写入不阻塞滑动 |
| 9 张照片连续滑动 | 待测 | 主要手势区间保持 55–60 FPS |
| 1,000 条批量导入 UI 阻塞 | 待测 | 主线程单次阻塞 < 50ms |
| 1,000 条同步上传请求数 | 待测 | 同一记录只保留最终版本 |
| 分享大图处理主线程占用 | 待测 | 主线程只做状态发布与导出完成 |
| 内存峰值（1,000 条含图） | 待测 | 不因 projection 长期持有原图而持续增长 |

真机必测路径：

1. 账单编辑补 1/3/9 张 10MP 图片，编辑页滚动、选择、保存。
2. 带图详情收起/展开，连续左右滑动 9 张图，切换缩略图和封面。
3. OCR/AI 导入 100/1,000 条，取消、失败、重试和导入后立即编辑。
4. 账单快速连续编辑同一条，离线后恢复联网，确认只上传最终版本。
5. 复盘背景选择、分享图保存、取消和重复点击。
6. 1,000/5,000 条账本冷启动、切换 Tab、回到首页和内存警告。

## 5. 冻结边界与下一任务

本专项不改变：账单字段含义、分类/情绪/生活语义、照片云端边界、同步新者胜规则、会员/IAP、免费额度和 UI 产品结构。  
下一任务建议为 `PERF-PERSISTENCE-ASYNC-01`（阶段 A），完成后再进入批量导入；在阶段 A 未通过真机和失败回滚验收前，不启动同步队列重构。
