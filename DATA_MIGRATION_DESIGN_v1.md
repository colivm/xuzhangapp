# 叙账长期存储迁移设计 v1

> 对应台账：`DATA-01`
> 本文只确定目标格式、迁移步骤、校验与回滚；不切换生产读写，不删除 `home_items_v1.json`，不修改云端 DTO。

## 1. 当前存储现场

生产账本当前由 `LocalStore` 以一个 JSON 数组保存：

- 主文件：Documents/`home_items_v1.json`
- 同内容备份：UserDefaults `home_items_v1_backup`
- 编码方式：Swift `JSONEncoder` 默认日期与 `Data` 编码
- 写入方式：任何新增、编辑、删除都会重新编码并原子写入完整 `[HomeItem]`
- 读取失败：主文件失败后尝试 UserDefaults 备份；备份也失败时返回空数组

### 1.1 `HomeItem` 旧字段清单

| 字段 | 类型/可选 | 迁移要求 |
|---|---|---|
| `id` | UUID | 保持原值；缺失时旧解码会生成 UUID，迁移前必须把实际解码结果固定下来 |
| `title` | String | 原样保留 |
| `amount` | Double | 同时保存原始 `amount_value REAL` 与审计用分 `Int64`；校验前后原值及四舍五入到分均一致 |
| `category` | enum String | 原始中文 raw value 保留 |
| `source` | `manual`/`ocr` | 原样保留 |
| `createdAt` | Date | 原样保留 |
| `updatedAt` | Date | 原样保留；缺失时使用 `createdAt` |
| `emotionTag` | String | 原样保留，不重新推断 |
| `merchantBrandId` | String? | 原样保留 |
| `draftMeta.batchId` | String? | 原样保留 |
| `draftMeta.importedAt` | Date? | 原样保留 |
| `draftMeta.status` | pending/resolved | 原样保留 |
| `userEditedTitle` | Bool? | 保留 nil 与 false 的差异 |
| `userEditedCategory` | Bool? | 保留 nil 与 false 的差异 |
| `categoryCorrectionFrom` | category? | 原样保留 |
| `memoryContext.weatherKind` | String? | 原样保留 |
| `memoryContext.temperatureCelsius` | Double? | 原样保留 |
| `memoryContext.cityName` | String? | 原样保留 |
| `memoryContext.semanticPlace` | String? | 原样保留 |
| `scenePackId` | String? | 原样保留 |
| `memoryImageData` | Data? | 旧单图兼容字段；仅在 `memoryImageDatas` 为空时作为第 0 张图 |
| `memoryImageDatas` | [Data] | 图片顺序必须保持 |
| `coverMemoryImageIndex` | Int? | 迁移为 cover ordinal；越界时沿用当前标准化结果 |
| `memoryAnchorRole` | String? | 原样保留 |
| `memoryAnchorSceneHint` | String? | 原样保留 |
| `memoryAnchorCaption` | String? | 原样保留 |
| `memoryAnchorCreatedAt` | Date? | 原样保留 |

云端 `LedgerDTO` 当前只包含账单字段、草稿信息、编辑标记、记忆上下文与 `scenePackId`，不包含图片和图片锚点。DATA-01 至 DATA-03 不改变这一协议。

## 2. 目标目录与命名

```text
Documents/
├─ home_items_v1.json                 # 迁移完成后仍保留，回滚源
└─ LedgerStore/
   ├─ manifest.json                   # 当前激活版本与源摘要
   ├─ ledger-v2.sqlite                # 账单元数据与图片引用
   ├─ images/
   │  └─ <record-uuid-lowercase>/
   │     ├─ <sha256-a>.jpg
   │     └─ <sha256-b>.jpg
   └─ migration/
      ├─ checkpoint.json              # 可恢复进度
      ├─ source-inventory.json         # 只含数量、ID、摘要，不复制图片正文
      ├─ ledger-v2.sqlite.staging
      └─ images.staging/
```

规则：

1. 图片目录按账单 UUID 隔离，避免删一笔时扫描全库。
2. 文件名使用完整内容 SHA-256；顺序只保存在 `image_assets.ordinal`/记录引用数组中，因此换封面、删前一张或重排不会改动其他图片路径。
3. 正式目录只接收通过校验的 staging 内容；不在正式目录里边迁移边覆盖。
4. 图片扩展名暂用 `.jpg`，因为现有入口统一保存压缩 JPEG；`media_type` 仍写入数据库，为未来兼容保留边界。
5. 不以标题、日期、分类命名，避免用户编辑后移动文件或泄露内容。

## 3. 元数据数据库模型

### 3.1 `records`

主键 `id TEXT`，并保存 `title`、`amount_minor_units INTEGER`、`amount_value REAL`、`category`、`source`、`created_at`、`updated_at`、`emotion_tag`、品牌、草稿字段、用户编辑标记、记忆上下文、场景包、封面顺序和图片锚点字段。`amount_minor_units` 用于审计和汇总不变量，`amount_value` 原样保留历史 Double，避免迁移把少数非两位小数金额静默截断。

索引：

- `records_created_at_desc(updated_at)`：首页、日期排序。
- `records_category_created_at(category, created_at)`：痕迹筛选。
- `records_draft_status(draft_status, created_at)`：OCR 待整理。

### 3.2 `image_assets`

| 字段 | 含义 |
|---|---|
| `id TEXT PRIMARY KEY` | `sha256(recordId + ordinal + contentHash)` 的稳定 ID |
| `record_id TEXT` | 外键到 records，删除记录级联删除引用 |
| `ordinal INTEGER` | 图片展示顺序，和旧数组索引一致 |
| `relative_path TEXT` | 相对 `LedgerStore/` 的路径；相同内容可在同一记录中重复出现 |
| `sha256 TEXT` | 文件内容摘要 |
| `byte_count INTEGER` | 完整性校验 |
| `media_type TEXT` | 当前为 `image/jpeg` |

唯一约束：`(record_id, ordinal)`。`relative_path` 不设唯一约束，因为两张内容完全相同的图片必须仍能保留两个展示顺序；封面存储在 `records.cover_image_ordinal`，不复制图片。

### 3.3 `migration_state`

保存 `schema_version`、`source_digest`、阶段、下一条索引、已暂存记录/图片数、最后错误和更新时间。正式代码对应 `LedgerMigrationCheckpoint`。

## 4. 幂等迁移流程

1. **锁定单实例**：获取迁移文件锁；失败则保持旧存储读取，不并发迁移。
2. **读取源**：优先读取主 JSON；失败时读取 UserDefaults 备份。两者都失败必须返回“源不可读”，不得把空数组当成功。
3. **建立 inventory**：按实际 `HomeItem` 解码结果记录 ID、金额分、分类、日期、标准化图片数量/顺序/封面和源 SHA-256。
4. **检查已完成**：若 `manifest.schemaVersion == 2`、`sourceDigest` 相同且审计通过，直接结束。
5. **准备 staging**：若 checkpoint 的 `sourceDigest` 不同，删除的只能是 `migration/*.staging`，不得动旧 JSON或已激活 v2。
6. **逐条暂存图片**：
   - 先取 `memoryImageDatas`；为空时再取 `memoryImageData`。
   - 计算 SHA-256、稳定相对路径和 byte count。
   - 已存在且摘要/长度一致则跳过；不一致写到临时文件后原子替换 staging 文件。
   - 每完成一条账单更新 checkpoint。
7. **暂存元数据**：以 UPSERT 写入 staging SQLite；同一源重复执行不会新增重复记录或图片引用。
8. **只读审计**：比较记录数、ID 集合、金额分总和、分类计数、最早/最晚日期、图片数、图片顺序、封面与所有 SHA-256。
9. **激活**：审计通过后，先原子移动图片 staging，再原子替换数据库，最后写 `manifest.activeStore = metadataV2`。Manifest 是最后一个提交点。
10. **保留旧源**：至少跨一个发布版本保留 `home_items_v1.json` 与 UserDefaults 备份；DATA-01 不定义删除日期。

## 5. 中断恢复

- 进程在图片阶段终止：下次从 `nextRecordIndex` 继续，已有摘要一致的文件直接跳过。
- 进程在数据库阶段终止：UPSERT 重放，不生成重复行。
- 审计失败：保留 staging 与错误报告，继续使用旧 JSON；不得写激活 manifest。
- Manifest 写入前终止：旧 JSON 仍是唯一生产源。
- Manifest 写入后启动失败：读取 v2 失败时进入显式回滚分支并记录错误，不允许把空账本持久化回任何源。

## 6. 回滚方案

1. Manifest 保留 `sourceDigest` 和旧源位置。
2. 运行时仅在 v2 数据库打开、schema 校验和基础审计都通过后使用 v2。
3. 任一失败将 `activeStore` 临时视为 `legacyJSON`，只读旧 JSON；不删除 v2，便于诊断与重试。
4. 回滚不把 v2 反向覆盖旧 JSON。正式切换后的增量写入与双写窗口由 DATA-03 决定。
5. 用户可见错误必须说明“本机旧账本仍保留”，不得静默显示空账本。

## 7. 验收不变量

- 记录 ID 集合完全一致。
- 记录数、金额分总和、分类计数一致。
- 每条记录的标题、日期、来源、编辑标记、草稿状态、记忆上下文和场景包一致。
- 图片数、顺序、封面 ordinal、byte count 和 SHA-256 一致。
- 旧单图与新多图同时存在时，以当前 `HomeItem` 解码规则为准：非空多图数组优先。
- 无图、OCR 草稿、记忆上下文不因图片迁移丢失。
- 任意中断点重复执行均得到相同 manifest、记录和图片引用。

## 8. 本任务样本与工具

- `qa/migration_samples/legacy_home_items_v1.json`：旧单图、多图、无图、OCR 草稿、记忆上下文。
- `qa/migration_samples/expected_ledger_v2.json`：预期元数据、图片顺序、封面和摘要。
- `scripts/analyze_legacy_ledger.py`：只读分析任意旧账本，输出字段、数量、金额和图片摘要。
- `scripts/validate_migration_samples.py`：校验仓库样本与预期结果，不写生产数据。

## 9. 后续任务边界

- DATA-02：实现图片 staging、文件引用、旧数据迁移与孤立文件清理。
- DATA-03：实现 SQLite 增量 CRUD、启动切换和必要的双写/回滚窗口。
- DATA-04：单独决定云端是否备份图片；在此之前云端 DTO 不加入图片字段。
