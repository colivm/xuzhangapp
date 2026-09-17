# 手动记录页：推荐、分类、文案与用户意图一致性审计

日期：2026-09-17；源码基线：`a7802ff`。

第 1–13 节保留初始只读审计，引用行号对应上述源码基线；用户随后授权优化，第 14 节记录限定范围的实现与验收。以下“已确认”指源码上可建立完整操作链路，不代表已在 iPhone 上复现。未获得截图对应的历史账本、置信度和操作日志，因此不将推导出的条件冒充用户当时的实际数据。

审计范围是手动记录入口的金额输入 → 推荐 → 备注/分类/角度交互 → 预览 → 保存，以及这些操作的异步与取消边界。不是整款应用、OCR、存储引擎或会员系统的全面审计。

## 1. 结论与用户要求

用户指出的不是“保存后才变其他”，而是保存前已经出现：提示说常是餐饮，实际分类却是其他，连续换句也一直生成其他类别的句子。

这条路径在当前源码中确定可达，完全不需要用户主动改分类或换角度。原因是“候选推荐”“实际采用分类”“分类面板推荐标记”分别决策；提示读取候选，普通帮写读取实际分类，保存又按实际分类和备注解析。系统内部允许这些输出互相矛盾。

本次按用户要求建立的验收原则：

1. 没有用户显式覆盖、没有新增明确备注事实时，显示为当前推荐的类别，应与默认类别、同类换句和保存类别一致。
2. 候选证据不够时，可以保留其他和空备注，但不能同时给出仿佛已采用另一类别的提示。不能为了使提示看起来正确而强行采纳所有低可信猜测。
3. “改分类后选中一个类别”“换角度后选中一个角度”才是显式选择；打开面板、取消、换措辞不是同一种行为。
4. 用户手写内容、真正清空内容、只打开编辑器，应分别识别。
5. 已明确选择的分类/角度不能被自动推荐静默覆盖；手写备注与主动选择分类不一致时，也不能简单删掉用户原话。

## 2. 当前状态分别由谁负责

| 状态 | 所在层 | 实际含义与消费者 |
|---|---|---|
| `selectedCategory` | HomeViewModel | 当前采用分类，初始其他；普通换句与保存 fallback 使用它 |
| `recordPrefillResult` | HomeViewModel | 候选分类、标题、来源、置信度；学习提示读取它，不保证分类已采用 |
| `recordRecommendedCategory` | HomeViewModel | 分类选择面板的推荐标记，另有优先级 |
| `categoryLockedByUser` | HomeViewModel | 真正选分类/应用角度形成的分类锁 |
| `inputTitle` | HomeViewModel | 手写、系统帮写、建议按钮都可写入；非空本身不能证明用户手写 |
| `lastDraftIntent` | RecordTabSession | automatic/note/category；普通换句也写 category，真正改分类却可能保留 note |
| `previewLineWasRotated` | RecordTabSession | 曾生成/换过文案；参与预览和是否刷新，不代表改过分类 |
| `noteEditorExpanded` | RecordTabSession | 编辑器是否展开；目前同时参与“手写过”“主动清空过”的判断 |
| `activeScenePack`、`userNoteAnchorTitle` | RecordTabSession | 已选角度、改写前备注锚点；预览与改写可用，保存参数不完整携带锚点 |

状态定义见 [RecordView.swift](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:12)；分类锁写入见 [HomeViewModel.swift](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:2907)。

关键区别：不能拿 `lastDraftIntent == .category` 判断“用户主动改过分类”。它描述文案处理路径，不是可靠的分类选择事件记录。

## 3. 已确认的问题

### D1. 低可信候选没有被采用，却照样显示类别提示——直接解释本次现象

证据链：

- [RecordPrefillService.swift:252](E:/workspace/xuzhangapp/NativeDemoApp/Services/RecordPrefillService.swift:252)：普通习惯即使低可信，也返回候选 category 和 source=habit；只有标题/情绪另设 `>= 0.65` 门槛。
- [RecordPrefillService.swift:491](E:/workspace/xuzhangapp/NativeDemoApp/Services/RecordPrefillService.swift:491)：最高分类不足 3 条，或同条件候选不足 4 条，置信度最多 `0.54`。
- [HomeViewModel.swift:590](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:590)：采用普通习惯分类要求 `>= 0.55`。低于门槛，没有其他依据时仍是其他。
- [HomeViewModel.swift:668](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:668)：结果清理只限制标题，保留候选类别；没有标题就原样返回。
- [HomeViewModel.swift:2784](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:2784)：分别发布 appliedCategory 和 result；前者可以为空，后者仍带餐饮。
- [HomeViewModel.swift:2376](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:2376)：habit 提示没有可信度检查，也不要求候选等于已选分类。

一个避开其他推荐分支的最小源码推导例子：近期总历史至少 6 条；仅 1 条是与当前 ¥12 同金额、同 3 小时时段、同日期类型的餐饮，其他 5 条不匹配该时段；备注为空、没有分类锁、初始类别其他。

该例不会满足场景习惯的至少 3 条候选，也不会满足常用金额的支持条件。普通习惯原始分数为 `1 × 0.72 + (1/8) × 0.28 = 0.755`，但支持不足，封顶为 `0.54`。于是：

| 环节 | 当前代码得到的结果 |
|---|---|
| 候选推荐 | 餐饮，0.54，无预填标题 |
| 实际采用分类 | 其他，因为未达到 0.55 |
| 提示 | 这个时间附近常是「吃饭」 |
| 帮写/连续换句 | 其他文案池 |
| 保存空备注或中性帮写 | 其他 |

这是源码分支推导与算术核对，不是已执行的 Swift 测试。

换句证据：[RecordView.swift:1128](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1128) 读取 selectedCategory；[1232](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1232) 的其他文案池为“先放进账本、日常小记录、临时花费补上……”；[1239](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1239) 的会员/免费入口最终使用同一改写决策。“帮我写一句”和“换一句”只是同一动作的不同标签。

连续点击只递增当前类别的文案变体，并不采纳提示中的餐饮。与此同时，[1746](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1746) 在普通换句后可以跳过后续预填刷新，使这种不一致继续存在。

保存证据：[HomeViewModel.swift:1301](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:1301) 用 selectedCategory 作 fallback，[RecordDraftResolutionService.swift:37](E:/workspace/xuzhangapp/NativeDemoApp/Services/RecordDraftResolutionService.swift:37) 在没有新语义/品牌时保留 fallback。保存不读“这个时间常是……”提示。故无须怀疑存储把餐饮字段改成了其他。

### D2. 高可信路径也可能分歧：常用金额和习惯推荐的优先级相反

- 实际采用分类：[HomeViewModel.swift:572](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:572)，常用金额优先于普通/场景习惯。
- 提示用的 result：[324](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:324)，习惯类别与常用金额类别冲突时，可以继续保留习惯结果。
- 分类网格的推荐标记：[624](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:624)，可信习惯优先于常用金额。

例如，精确金额支持购物，但附近金额的习惯更支持餐饮，就可能得到“选中购物、提示餐饮、网格推荐餐饮”。普通习惯允许邻近金额，常用金额要求精确金额，因此两种证据不是天然相同的数据集。

这不是 D1 的同一个置信度漏洞。只过滤 0.54 提示，不能解决这条优先级冲突。具体历史样本仍应补 XCTest，不把分支推导说成真机复现。

### D3. 只打开备注编辑器，也被识别成主动清空

最小序列：可靠预填显示“地铁/公交”，但 inputTitle 为空 → 点卡片或“自己写一句” → 不输入、不删除 → 保存。

- [RecordView.swift:1011](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1011)：打开编辑器只设置展开和焦点，没有把预填标题写入输入，也没有记录用户是否实际编辑。
- [668](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:668)：只要编辑器展开且原输入为空，就不再使用兼容预填标题。
- [699](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:699)：同一条件被命名为 noteWasExplicitlyCleared。
- [1024](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1024)：保存据此传 preserveEmptyTitle，最终采用“未填写备注”。

源码确定会混淆“查看/准备输入”和“主动清空”。分类一般不因此变化，但用户未编辑就改变了将保存的标题。最终交互应如何呈现需单独签收，不能顺手并入分类修复。

### D4. 清空金额再输入，保留备注文本和分类锁，却丢掉手写意图

最小序列：输入金额 → 手写“牛肉面” → 主动选择购物 → 清空金额 → 重新输入金额。

清空前，“牛肉面 + 用户主动选购物”按当前规则允许保留。清空金额时，[RecordView.swift:1823](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1823) 重置 lastDraftIntent、编辑器展开状态、备注锚点和角度，但没有清 inputTitle，也没有解除 categoryLockedByUser。

重新输入后，文字仍是牛肉面、分类仍锁购物，但已经不被识别为手写。预览标题 [735](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:735) 可转为购物 fallback；保存的 userEditedTitle 判定 [940](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:940) 变成 false；[HomeItem.swift:1517](E:/workspace/xuzhangapp/NativeDemoApp/Models/HomeItem.swift:1517) 随后把不兼容原话修复成购物标题。

因此，这不仅是“清空金额后要不要保留分类”的产品选择，而是保留了一半草稿、丢掉另一半来源状态，存在静默替换原备注的确定路径。修复前应先明确清空金额究竟是同一草稿继续编辑，还是完整开始新草稿，不能混用两套规则。

### D5. 帮写后改日期，系统生成的购物文案可能反过来使分类掉回其他

这是另一个有条件、源码确定可达的操作序列，不是“每次普通换句都会改变分类”：

1. 空备注、金额不超过 80，可靠历史已自动采用购物；没有用户分类锁、没有手写锚点、没有选角度。
2. 第一次帮写产生“买到常用的小东西”，见 [RecordView.swift:1214](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1214)。
3. 用户只修改日期/时间，且此次修改导致 history key 改变，新的历史准备成功完成。它直接调用 VM 预填，绕过 View 的“已换句”守卫，详见 R1；不把任意时间微调都等同于必然重建。
4. 当前词典不把这句话识别为明确购物，它也不在 generatedSystemTitles 集合；如果没有该句对应的用户分类纠正历史，[RecordHabitOverridePolicy.allows](E:/workspace/xuzhangapp/NativeDemoApp/Services/RecordPrefillService.swift:39) 会把它当作未知具体备注，拒绝用常用金额/习惯覆盖。
5. provisional 分支没有品牌、语义、纠正历史或允许采用的常用金额依据，便把旧自动购物回退为其他；后续 habit/generic 同样被 allows 拒绝，不能恢复购物。保存这句中性文案也沿用其他。

对当前 RecordSceneLexicon.json 做了只读关键词匹配：“买到常用的小东西”“日用小补给”“先放进账本”均无关键词命中；“下单一个需要的”命中购物的“下单”。因此，同一个购物文案池中的句子在重算后可以有不同命运，不能靠不断补措辞来替代来源状态的识别。

直接原因是：系统生成文案被放回 inputTitle 后，重算没有可靠保留“这是购物表达，不是用户新增事实”的来源；这与主问题同属推荐、文案和意图状态的一致性范围。当前仍为源码和词典验证，未运行 SwiftUI 序列。

## 4. 异步和预览/保存风险：与确定主因分开

### R1. 换句后的“停止自动刷新”只在 View 入口生效

[RecordView.swift:1746](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1746) 先请求 warmup，再检查换句状态；[HomeViewModel.swift:2632](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:2632) 在 history key 变化时启动历史准备；历史完成 [2704](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:2704) 直接调用 refreshRecordPrefill，无法读取 View 中的换句守卫。

所以“换句 → 改日期/历史版本变化”与“换句 → 普通刷新”未必遵守同一保护策略。D5 给出实际回退分类的有条件路径；其他文案的结果依赖历史和优先级，不断言每次都会变化。历史 key 未变、也没有尚未完成的历史准备时，普通连续换句不会经此回调重算。

### R2. 编辑后立即帮写/保存的时间窗口

- 新预填前，[HomeViewModel.swift:2809](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:2809) 的 provisional 分支在缺少快速依据时，可把旧自动分类回退其他。保存入口不等推荐完成。
- 备注变化有 220ms 防抖，[RecordView.swift:1732](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1732)。防抖等待时旧请求不立即失效；发布虽然检查 request ID/key，但没有再直接比较当前原始输入与本次捕获的输入。
- 已有取消、request ID、history key、prefill key、分类锁保护，不能描述成“没有任何旧结果保护”。离开页面也会取消任务。

应在可控异步执行器/Xcode 中验证：开始计算 A → 修改为 B → A 返回 → 马上帮写/保存 → B 返回。不能仅等界面最终稳定后检查。

### R3. 预览和保存没有完全相同的输入

- 预览“用户改过标题”允许 `noteEditorExpanded || categoryLockedByUser`；保存要求 `noteEditorExpanded && lastDraftIntent == .note`，见 [RecordView.swift:715](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:715) 与 [940](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:940)。普通兼容标题不一定产生差异，但不能认为两个布尔值含义相同。
- 改写后预览生活线索/情绪可使用“新句子 + 原手写锚点”，见 [848](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:848)；保存参数没有锚点，只带当前标题/分类/角度。预览构造的临时 HomeItem 也没有与最终记录完全相同的用户编辑标记。
- 保存还有 memory/weather 情绪增强，见 [HomeViewModel.swift:1341](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:1341)。部分差异可能是既有设计，不能未经测试就宣称具体文案错误。

需验证原备注含具体事实、帮写删去部分事实时，预览与保存后的分类、标题、情绪、生活线索分别是否符合承诺。尚未证明截图由此产生。

### R4. 保存已受理不等于已经写入磁盘——独立失败边界

[HomeViewModel.swift:3604](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:3604) 提交异步持久化后立即返回 true；手动保存随后清空输入；[ContentView.swift:1058](E:/workspace/xuzhangapp/NativeDemoApp/ContentView.swift:1058) 转到今日页。

如果最后一次写入失败，[HomeViewModel.swift:3728](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:3728) 重载磁盘账本并设置错误提示，没有恢复原输入草稿的路径。既有 revision 校验和旧失败重试存在，不应省略。

这不是本次“餐饮提示/其他分类”的原因；属于故障注入后应核对的独立保存失败体验，不在此次分类实现授权内，也不能据此声称发生过实际丢单。

## 5. 已核实应保留的行为

- 真正选择分类/角度会锁定类别、失效旧预填；自动推荐和保存解析尊重该锁。
- 单纯打开/取消分类或角度面板，不等于已选择，不会自行设置分类锁。
- 手写备注后改分类或选角度，代码可以保留用户原话；不要为了文案/类别表面一致而删除用户表达。
- 已选角度后写另一类备注，当前规则仍保留分类锁和原角度，下一次换句仍优先该角度。要改变此规则需要单独产品决定。
- `clearActiveScenePackIfManualNoteMovedAway` 不能证明“手写会自动清除角度”：唯一调用处的备注建议按钮刚将 lastDraftIntent 改为 category，使函数的 note 守卫直接返回，见 [RecordView.swift:1696](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1696) 和 [2742](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:2742)。但是否应清除仍受显式角度优先的边界约束。
- 常用金额快捷按钮是自动应用建议，不设置手动分类锁，见 [RecordView.swift:2207](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:2207)。
- 免费/会员的主要帮写入口共用分类/角度改写决策；不能把这次分歧归因于会员等级。
- “出行/交通”“吃饭/餐饮”是相同枚举的不同展示名称，不是两种类别之间发生转换。
- Tab session 由上层持有，离开会取消准备任务，返回会刷新。不能未经序列测试将切 Tab 等同于完整清空草稿。

## 6. 后续必须覆盖的操作矩阵

以下是待实现的验证要求，不是已经运行通过的用例。每个场景都要同时检查：提示及来源、selectedCategory、分类面板推荐、预览标题/分类、换句类别与角度、保存字段；涉及手写还检查 userEditedTitle/userEditedCategory 和原话是否保留。

| 场景 | 必须验证的边界 |
|---|---|
| 无历史/不足 6 条，只有金额 | 不编造类别事实或具体商家 |
| 低可信餐饮/购物，空备注，直接保存 | 不得显示另一类别已采用的提示 |
| 同上，帮写一次/连续换句 | 不把换措辞算成改分类；提示与文案池一致 |
| 高可信交通，有兼容预填标题 | 保留截图 2 的正确路径 |
| 高可信类别、没有可复用标题 | 类别可确定不代表允许编造标题；分别检验 |
| 精确金额购物、邻近金额习惯餐饮 | 已选、提示、网格推荐遵守统一裁决 |
| 0.54/0.55/0.65 附近的置信度 | 分类采用与标题采用是两道门槛，提示必须对应最终决定 |
| 仅打开/取消分类面板或角度面板 | 不因打开/取消动作新增用户锁或覆盖草稿；不要求冻结原本合法进行中的异步推荐 |
| 实际选其他/购物，再连续换句 | 自动推荐不能夺回分类 |
| 实际选角度，再换句 | 保留该角度，不暗中换包 |
| 手写明确备注，尚无分类锁 | 自动分类允许按真实备注调整 |
| 手写备注后改分类/选角度 | 保留用户原话及显式选择 |
| 先选分类/角度，再写冲突备注 | 按既有显式锁规则执行，不顺带改变优先级 |
| 可靠预填 → 仅打开备注 → 不输入保存 | 区别“打开”与“真实删除” |
| 真正删除备注 → 保存 | 不恢复用户明确删掉的预填标题 |
| 手写冲突备注＋主动分类 → 清空金额 → 重输 | 不丢失手写来源、不静默替换原话 |
| 已选角度 → 清空金额 → 重输 | 角度清除与分类锁保留的规则须明确，不能半重置 |
| 帮写 → 改金额/日期/历史变化 | 命中/未命中历史缓存时保护语义一致 |
| 备注建议按钮 → 帮写；原备注 → 多次帮写 | 建议、手写、生成文本的来源不能混淆 |
| 快速输入/修改后立即帮写或保存 | 旧结果不污染新草稿；处理中状态不产生自相矛盾承诺 |
| 切 Tab 返回、手动/OCR 入口往返但不导入 | 草稿、锁、原话、角度和取消行为一致；不扩大到 OCR 规则修改 |
| 已改写且原话含具体事实 → 预览/保存 | 标题、语义锚点、情绪和生活线索的承诺一致 |
| 写入拒绝/异步持久化失败 | 输入保留/恢复和用户反馈明确；独立存储专项验证 |

至少选择餐饮、购物、交通、其他四类；主要帮写链路覆盖免费与会员；异步场景分完成前、完成后两种时点，而不只测试最终稳定画面。

## 7. 验证证据与局限

- 已逐入口交叉核对推荐生成、采用、提示、文案选择、意图状态、锁、预览、保存和取消代码；有独立只读交叉审计。
- 此前同一排查过程已运行 `python scripts/life_semantic_regression.py`，结果 OK；`scripts/experience_static_check.ps1` 退出码 0。后续未改变业务源码，未将这两个结果冒充新增 UI 序列验证。
- 当前又核对了单候选置信度算术：原始 0.755，支持不足后 0.54，低于类别 0.55 与标题 0.65 门槛。
- 只读匹配当前分类词典，确认 D5 中三个中性生成句没有分类关键词，而“下单一个需要的”匹配购物。该检查不等同于执行 Swift 完整分类服务。
- [StateRegressionTests.swift:4990](E:/workspace/xuzhangapp/NativeDemoAppTests/StateRegressionTests.swift:4990)、[5060](E:/workspace/xuzhangapp/NativeDemoAppTests/StateRegressionTests.swift:5060)、[5123](E:/workspace/xuzhangapp/NativeDemoAppTests/StateRegressionTests.swift:5123) 主要覆盖可靠习惯、用户锁和稳定历史快照；未见针对上述完整按钮顺序的一致性断言。
- [life_semantic_regression.py:665](E:/workspace/xuzhangapp/scripts/life_semantic_regression.py:665) 跳过含 history/selectedCategory/categoryLockedByUser 的分类样例，并要求输入文字；纯金额＋历史推荐问题不由它证明正确。静态体验检查主要验证符号/接线存在。
- Windows 当前没有 Swift、swiftc、xcodebuild。未执行 XCTest、SwiftUI 交互或 iPhone 真机复现，未运行真实持久化故障注入。
- 本次只新增本审计文档、追加全局台账证据；保留用户原有环境文件和未跟踪素材/脚本。无业务代码修复，不标记 CODE_DONE/VERIFIED。

## 8. 修复前应明确的最小方向（尚未实施）

核心不是全局降低置信度，也不是在保存最后一步强行改成提示类别。应先保证同一个有效草稿有一致的“已采用决定”：类别、依据、可信度、兼容标题与提示共同对应它，候选结果不能独立冒充最终决定。

普通换句只改变表达；显式分类/角度、手写、真实清空、仅展开编辑应分别记录。最终保存必须遵守同一草稿事实和用户锁；等待中的推荐结果不得改变已提交草稿。

建议后续独立分类一致性任务首先收束 D1、D2、D5 与其直接相关的换句/异步边界，并补上述序列测试。D3、D4、预览线索和持久化失败分别登记范围，不顺手修改。开始任何业务实现前，仍须按 AGENTS.md 完整阅读全局台账、核对唯一任务与冻结边界；本次诊断不代表已完成该实现前置步骤。

## 9. 扩展审计：场景包与三类“锁”

用户补充要求：场景包使用、锁定以及本页关联扩展都必须考虑。以下补充同一次诊断的关联范围，不把“考虑所有关联”理解成允许修改所有模块。

| 锁/保护 | 实际状态 | 保护对象 | 不代表什么 |
|---|---|---|---|
| 用户分类锁 | categoryLockedByUser | 用户明确选定的分类；选角度也会设置 | 不保证生成标题兼容、不表示会员权限、不冻结其他显式选择 |
| 场景包访问限制 | 会员、基础免费三包、首周、有效奖励 | 哪些包可选择/使用 | 不应直接改变账单类别或删除已有备注 |
| 已换句的刷新守卫 | previewLineWasRotated + lastDraftIntent | 在部分 View 刷新入口避免重新预填 | 不是真正用户分类锁；history 回调可以绕过 |

### 9.1 用户锁和角度的生命周期

| 操作 | 分类锁 | activeScenePack 与备注 |
|---|---|---|
| 自动采用推荐、点常用金额 | 不新增锁；已有锁会拒绝自动应用 | 不等于选择角度 |
| 只打开/取消分类或角度面板 | 不新增锁 | 不因该动作覆盖草稿；正常异步仍可能完成 |
| 真正选分类 | 设为 true，即使点的是当前类别 | 清 activeScenePack；原手写/明确语义可保留 |
| 真正选包 A | 设为 true | 分类设为 A.category，active=A；按条件保留原话或生成标题 |
| 已锁分类后再选包 B | 仍为 true | 显式新选择可覆盖旧锁，改为 B.category，并非锁死所有操作 |
| 已选包后再选分类 | 仍为 true | 改为新类别，清 active；即使选同类别也清角度 |
| 已选包后手写/清空备注 | 不自动解锁 | 原角度继续保留；清空文字会清备注锚点，不等于清包 |
| 已选包后连续换句 | 不解除锁 | 优先旧 active 包；文字冲突也不会自动改包 |
| 改有效金额/日期 | 不解除锁 | active 存在时不会走普通换句的清标题分支；旧文案可保留 |
| 金额清空或变无效 | 锁保留 | active、手写意图、编辑器、锚点重置；原输入文本保留，见 D4 |
| 排序/置顶/替换免费三包 | 不新增/解除分类锁 | 修改包配置，不等于为当前草稿选中某包 |
| 领取奖励但未使用 | 不新增锁 | 新增访问资格，不自动应用角度 |
| 切 Tab、首页快捷记账、AI 页返回记账 | 不等于重置分类锁 | 共用上层 RecordTabSession 与 VM，原草稿可继续 |
| 手动/OCR 入口往返 | 不等于新草稿 | OCR 导入会改变账本 revision，返回时推荐准备还需核对；不把 OCR 批次规则并入修改 |
| 手动保存被受理 | VM 解锁、重置分类；session 清 active 等状态 | 此时点不是磁盘成功时点，见 R4 |

证据：[HomeViewModel.swift:2907](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:2907)、[3575](E:/workspace/xuzhangapp/NativeDemoApp/ViewModels/HomeViewModel.swift:3575)；[RecordView.swift:528](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:528)、[1823](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1823)、[1919](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1919)、[2651](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:2651)；[ContentView.swift:948](E:/workspace/xuzhangapp/NativeDemoApp/ContentView.swift:948)。

`preferNoteSemanticsForCurrentDraft` 虽有解除锁代码，但全仓搜索只有声明，没有本页实际调用；当前不能说用户写新备注就能恢复自动推荐。同样，权限校验 helper `canUseScenePackForCurrentAccess` 只有声明，不能据此认为生成路径已有访问保护。

### 9.2 不把遗留 helper 当真实入口

本轮核对没有发现 `memberScenePackSection`、`preferredFreeScenePack` 的实际调用，也没有 `applyScenePack(... keepSelectedCategory: true)` 调用。当前生效入口是角度 Sheet 的选择回调。奖励领取实际传 `shouldApplyPack: false`；首页领取只领取并导航。这些区分可避免把“有代码”误认成“当前用户会走到”。

## 10. 场景包不是分类的同义词：生成、保存与后续学习

### 10.1 九个包的固定类别和表达范围

来源：[ScenePackCopyPool.swift:18](E:/workspace/xuzhangapp/NativeDemoApp/Services/ScenePackCopyPool.swift:18)，备注与包的兼容范围另见 [RecordView.swift:1677](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1677)。

| 包 ID | 页面表达 | 选择后固定类别 | 需要额外核对 |
|---|---|---|---|
| commute | 地铁公交打车停车 | 交通 | 包很宽，但保存 ID 会被下游当通勤证据 |
| food | 干饭点外卖和咖啡 | 餐饮 | 改日期后原系统早餐/夜宵措辞是否继续被当事实 |
| supply | 超市买菜和家用 | 日用 | 包兼容判断允许购物/居家，最终分类仍固定日用 |
| care | 看病买药健身恢复 | 健康 | 具体就医/健身事实不能仅凭金额模板互换 |
| home | 每月房租水电物业 | 居家 | 包兼容判断允许日用；保存按实际居家判断标题 |
| social | 请客吃饭人情局 | 人情 | 聚餐措辞可能同时带餐饮事实，不能简单等同类别错误 |
| shopping | 快递到了网购这件 | 购物 | 可兼容日用表达；系统标题来源与手写要区分 |
| travel | 出去玩订酒店买票 | 交通 | 包认可交通/住宿/娱乐/餐饮，最终标题兼容规则却不认可全部 |
| family | 娃和毛孩的补给站 | 日用 | 照护事实、会员宠物展示偏好不是同一状态 |

### S1. 包内合法文案可能被本页分类兼容检查丢弃（源码确定路径）

空备注、可使用 travel、金额 100、首次选择该包，日期设为 2026-09-10 白天。在默认公历/中文日期环境，按当前 FNV 索引算法推导，tierIndex=2、variant=0 时会生成“经济型住宿这一晚”。这是该包自身的合法模板。

但实际选择锁的是 transport。当前词典对该句只匹配住宿；`previewHeadline` 因不兼容且非手写意图，显示交通 fallback；保存同样按锁定交通修复成“日常出行”，同时保留 scenePackId=travel。也就是说，生成成功并不表示生成句能进入预览或最终保存。

关键代码：[ScenePackCopyPool.swift:108](E:/workspace/xuzhangapp/NativeDemoApp/Services/ScenePackCopyPool.swift:108)、[138](E:/workspace/xuzhangapp/NativeDemoApp/Services/ScenePackCopyPool.swift:138)、[574](E:/workspace/xuzhangapp/NativeDemoApp/Services/ScenePackCopyPool.swift:574)；[RecordView.swift:735](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:735)；[RecordDraftResolutionService.swift:37](E:/workspace/xuzhangapp/NativeDemoApp/Services/RecordDraftResolutionService.swift:37)；[HomeItem.swift:1517](E:/workspace/xuzhangapp/NativeDemoApp/Models/HomeItem.swift:1517)。

其他 travel 模板也有跨类别词：“展馆/景点门票”匹配娱乐，“旅途一顿特色简餐”匹配餐饮。本轮已只读检查词典和种子算术，但没有运行 SwiftUI。这里应先明确“角度的广义表达”与“实际分类”的合同，不能直接把所有包强制改分类，也不能取消用户锁。

### S2. 改日期后换句，系统生成的早餐可能被继续当作原始事实（源码确定路径）

空备注、¥12、2026-09-08 上午 9 点、首次选择 food，当前种子算法可产生“早餐简单吃一口”。随后仅把发生时间改为晚上 18 点：分类锁保留，原系统标题也保留。再点换句时，即使没有用户手写锚点，`applyScenePackCopy` 仍把当前生成句作为 sourceTitle 交给 anchoredScenePackCopy；其早餐分支直接轮换“早餐先记下”等句子，不检查新日期。

证据：[RecordView.swift:1316](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1316)、[1353](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1353)、[1535](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1535)、[1862](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1862)。初始模板及种子见 [ScenePackCopyPool.swift:281](E:/workspace/xuzhangapp/NativeDemoApp/Services/ScenePackCopyPool.swift:281)。

手写“早餐”可能是用户明确事实，改日期也应谨慎保留；但本例完全没有手写。问题是系统生成与真实原话没有在改写入口充分区分。改变有效金额也保留已选包标题，因此跨金额档、时段、工作日/休息日都需要测试，而不仅检查分类有没有变化。

### S3. 保存的 scenePackId 是语义证据，不是纯装饰（跨层合同待确认）

`commute` 包页面名称为“地铁公交打车停车”，描述还包含短途办事和补能。用户写“停车”，再选这个包，按现有保留原话规则可保存“停车 + 交通 + scenePackId=commute”。

下游 [RecordCalendarContext.swift:184](E:/workspace/xuzhangapp/NativeDemoApp/Services/RecordCalendarContext.swift:184) 只要 transport 且 scenePackId=commute 就直接认定通勤，不要求工作日、时段或标题证据；[LifeSceneSemanticService.swift:479](E:/workspace/xuzhangapp/NativeDemoApp/Services/LifeSceneSemanticService.swift:479) 也加入强通勤信号。全局台账第 107 节已明确将显式 commute ID 当证据，所以不能在此次局部排查中把下游规则当成随手可改项。

需要核对的是：用户选择这个宽泛出行包，是否真的等于确认“本笔通勤”。若不是，页面选择语义与下游证据合同不一致。类似地，选包形成的 userEditedCategory 会影响以后习惯支持权重（[RecordPrefillService.swift:434](E:/workspace/xuzhangapp/NativeDemoApp/Services/RecordPrefillService.swift:434)），不是仅影响眼前一张卡。

此外，清空金额会移除 active 包但保留类别锁；即使最终类别没变，保存的 scenePackId 和后续语义也可能不同。这属于 D4 的扩展影响。

### 10.2 不能忽略的事实与情绪优先级

`ScenePackCopyPool.note` 优先 factFirstNotes，再用日期上下文，再用金额模板；部分事实分支不要求事实类别等于 pack.category。[ScenePackCopyPool.swift:183](E:/workspace/xuzhangapp/NativeDemoApp/Services/ScenePackCopyPool.swift:183) 的话费、婴儿/宠物、聚会、医疗等就在此层。

所以“已锁定某包”不等于所有输出只来自该包模板；冲突原话可能仍主导生成，然后在预览/保存被分类修复。情绪也先处理品牌、具体事实等，再考虑 scenePackId，见 [NarrativeCopyResolver.swift:326](E:/workspace/xuzhangapp/NativeDemoApp/Services/NarrativeCopyResolver.swift:326)。应检查完整输出，不应只断言 activeScenePack 没变就算通过。

## 11. 免费、会员、首周、奖励与失效边界

### A1. 首周“扩展角度会锁定”提示与免费槽位实际规则冲突

首周将 travel/family 换进三个免费槽 → 首周结束 → 仍可以从当前免费包卡片选择，用于一笔新记录。

原因：[FreeScenePackService.swift:341](E:/workspace/xuzhangapp/NativeDemoApp/Services/FreeScenePackService.swift:341) 仅检查保存的三个 ID 合法，不按首周结束清理；[457](E:/workspace/xuzhangapp/NativeDemoApp/Services/FreeScenePackService.swift:457) 直接输出这些包；[ScenePackAngleSheet.swift:824](E:/workspace/xuzhangapp/NativeDemoApp/Views/ScenePackAngleSheet.swift:824) 当前免费卡片无扩展权限检查，直接选择。首周限制只在新换入和候选区检查。

与 [RecordView.swift:266](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:266) 的“扩展角度……会锁定”提示不一致。需确认是“首周选入可以保留”，还是“首周后全部扩展锁定”；本轮不擅自修改会员权益。

### A2. 已选角度失去访问资格后，仍可继续生成（行为确定，延续政策待定）

不用等待到期即可验证源码路径：免费用户选 supply → 把 supply 替换出免费三包 → 关闭面板 → 换句。替换回调只更新免费配置与刷新 token；activeScenePack 仍为 supply，生成仍按该包走。

生成 [RecordView.swift:1287](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1287) 没有实时资格检查；保存前 [729](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:729) 只检查包类别等于所选类别，不检查访问权限。会员到期、奖励到期、领取另一个奖励替换旧奖励，都需要沿同一边界验证。

必须分别定义“保留既有草稿并允许保存”与“继续生成新的受限包文案”。即便决定禁止继续生成，也不能因权限到期静默删掉原备注、解除用户选择，或把分类改成其他。

### A3. 七天奖励不等于永久解锁，也不是多包叠加

- 从领取时开始计算七天；待领取卡片当前不按 expiresAt 拒绝领取，不能把久未领取一概当作过期 bug。
- 有效奖励额外加入可用列表，不占基础三个槽位。
- 实际界面“领取”不自动为草稿选角度；真正使用时才设置分类锁。
- 只有一个 activeKey。领取 B 会覆盖仍有效的 A；同包不同奖励组可重新起算，不同包则替换访问资格。原草稿 active 包却不会因此自动清理。

证据：[FreeScenePackService.swift:72](E:/workspace/xuzhangapp/NativeDemoApp/Services/FreeScenePackService.swift:72)、[123](E:/workspace/xuzhangapp/NativeDemoApp/Services/FreeScenePackService.swift:123)、[150](E:/workspace/xuzhangapp/NativeDemoApp/Services/FreeScenePackService.swift:150)；[RecordView.swift:226](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:226)、[1970](E:/workspace/xuzhangapp/NativeDemoApp/Views/RecordView.swift:1970)；[ContentView.swift:1197](E:/workspace/xuzhangapp/NativeDemoApp/ContentView.swift:1197)。

### A4. 替换窗口跨界：服务拒绝，但 UI 仍可能说成功（待运行验收）

Sheet 的免费资格是传入布尔快照，30 秒计时只更新倒计时。若开着面板跨过首周/24 小时窗口边界，旧 UI 条件可能仍允许提交替换。服务会按真实时间重新检查并拒绝，这是已有保护；但返回值为 Void，UI 不知道是否成功，仍直接显示“已换上”。

证据：[ScenePackAngleSheet.swift:20](E:/workspace/xuzhangapp/NativeDemoApp/Views/ScenePackAngleSheet.swift:20)、[474](E:/workspace/xuzhangapp/NativeDemoApp/Views/ScenePackAngleSheet.swift:474)、[1327](E:/workspace/xuzhangapp/NativeDemoApp/Views/ScenePackAngleSheet.swift:1327)；[FreeScenePackService.swift:433](E:/workspace/xuzhangapp/NativeDemoApp/Services/FreeScenePackService.swift:433)。需要时钟注入和 SwiftUI 验证实际刷新，不将这个时间边界说成已真机复现。

扩展锁提示本身只用于非会员、首周后、金额有效、当前不可用的 travel/family，并有三天节流。提示不选择包、不改分类；care 的相关提示分支会被扩展集合过滤，不能把遗留分支当成当前生效权益。

## 12. 新增场景包联合验收矩阵

本节补充第 6 节。每项同时核对：实际类别、用户锁、active 包、访问资格、输入原话及其来源、预览、生成结果、保存标题/category/scenePackId/userEdited 标记；涉及事实时再核对生活线索与后续习惯。

| 组合场景 | 验收重点 |
|---|---|
| 自动推荐 → 选分类 → 选包 → 再选分类 | 最新显式选择生效，清包和分类锁的变化正确 |
| 已选包 → 点同类别 / 点另一个包 | 同类别确认是否退出角度明确；新包是新选择而非自动覆盖 |
| 打开/取消/排序/替换免费配置/领取奖励 | 与“实际使用角度”严格区分 |
| 空备注 / 手写具体事实 / 系统生成句，各自选包 | 三种来源的保留、替换、锁和锚点不同，不能只看有没有文字 |
| 选包后手写冲突事实 → 换句 → 保存 | 类别锁与原话事实均受检查，不只检查包 ID |
| 九个包 × 金额档边界 × 代表文案 | 生成句、预览、保存不能无解释地换成另一套标题 |
| travel 的住宿/门票/餐饮模板 | 包的多类别表达与固定交通锁一致性 |
| food 早餐 → 改晚间 → 换句 | 系统早餐不被误当用户明确早餐；手写早餐另测 |
| 工作日 → 周末/节假日；夜间 → 白天 | 场景上下文、旧生成句、手写事实分别处理 |
| 已选包 → 改有效金额 / 清空重输金额 | 跨金额模板和 active 包清除不产生半重置 |
| 写停车 → 选 commute → 保存 | 是否确实应产生通勤事实，和下游已冻结合同一致 |
| 免费三包内 / 候选区 / 首周扩展 / 会员 / 奖励包 | 不同入口遵循同一访问规则，类别锁不被权益状态冒充 |
| 首周选入 travel/family → 第八天新记录 | 到期文案与保留槽位政策一致 |
| 已选包 → 替换出免费槽 → 继续换句 / 保存 | 区分新生成权限与既有草稿保存 |
| 会员到期/降级/恢复，期间留着未提交草稿 | 不丢原话；是否继续生成有明确规则 |
| 奖励到期 / A 未到期领取 B / 同包不同奖励组 | 一个 activeKey 的替换、重新计时与旧草稿关系明确 |
| 面板停留跨首周/24 小时窗口/奖励到期 | UI 权限及时性、真实服务结果与反馈一致 |
| 锁包升级入口 → 取消/购买后返回 | 未选择前不改草稿，购买结果不冒充角度选择 |
| 首页/AI 入口、切 Tab、手动/OCR 往返 | 原草稿保留、异步重新准备和访问资格重评估联合检查 |
| 成功受理/失败/下一笔/新进程 | 保存 reset、失败草稿、内存 session 与持久权益分别验证；不假定有持久草稿恢复 |

## 13. 本次扩展审计的证据、范围与剩余风险

新增核对 ScenePackAngleSheet、FreeScenePackService、ScenePackCopyPool、RecordCalendarContext、相关 ContentView 回调和下游 scenePackId 消费点；访问权益部分经独立只读交叉审计。没有真实领取奖励、替换用户免费配置、修改会员状态或触碰用户账本。

补充验证包括当前词典的只读关键词匹配、Swift 种子算法的等价算术推导、全仓入口/调用点检索。它们不等于运行 Swift 分类服务或 XCTest。现有 [StateRegressionTests.swift:5373](E:/workspace/xuzhangapp/NativeDemoAppTests/StateRegressionTests.swift:5373) 是奖励冷启动聚合一致性验证；未见覆盖免费首周/窗口与当前草稿锁联合生命周期的专项 XCTest。

本轮仍只更新此报告及全局台账。原始 D1/D2/D5 不能被这些扩展发现冲淡；场景包、会员权益、语义事实与持久化边界需要进入各自明确的任务范围，不能以“修推荐”为由一起改写。所有 SwiftUI 时间顺序、权限跨界和故障场景仍待 Xcode/真机验收。

## 14. 用户授权后的定向修复（2026-09-17）

任务为台账第 153 节 `RECORD-RECOMMENDATION-CONSISTENCY-FIX-01`。仅处理 D1/D2/D5 和直接关联的草稿来源/异步一致性，以上审计不是“所有问题均已修复”的清单。

### 已实施范围

- D1/D2：`RecordInputAssistanceComputation.adoptedPrefillResult` 产生唯一已采用结果，`result.category` 同时供实际分类、提示和网格推荐使用。保留品牌/明确备注/纠正历史优先，然后可信精确金额，再普通习惯；0.54 的候选不作为已采用结果发布。分类和标题原有阈值不降低，精确金额胜出时不能挪用其他类别的标题。
- 标题与商品边界：预填标题同时核对明确商品类别，不能仅因“罗森”属于餐饮品牌就接受“罗森纸巾”为餐饮文案。共同解析器的既有“便利店商品语义优先”规则不再因已选类别恰好等于商品类别就丢弃语义；尚未采用（其他）和已采用（日用）两种状态均解析日用。该修正适用于共享解析入口，不修改词典、非便利店品牌优先、用户锁或 OCR 提取。
- D5：新增仅内存的 `RecordGeneratedNoteContext`，统一登记普通帮写/换句及包内生成来源。它不是用户分类锁，也不随日期、历史更新或暂离页面失效；真实改写备注、选新分类/角度和保存重置按入口释放。生成入口先做既有 32 字规范化，防止 View 后续截断误丢来源；金额变化仍走原有草稿处理。
- 异步：备注、金额、日期变更同步失效旧预填；后台回包额外核对当前 history key、金额、日期、备注、分类、用户锁及生成来源。历史准备完成也不能绕过生成来源守卫；准备 key 的复用补上当前分类匹配。
- 预览/保存：交叉复核补出了“请客朋友→人情→换句为一起吃顿饭→词典重新判餐饮”的普通锚点反例。共同解析器接收默认 nil 的生成来源，只有当前标题与类别匹配时保留系统生成句所属类别和标题，优先级低于真实用户锁。无来源的同一句仍按真实备注识别餐饮；不会伪造 `userEditedCategory` 或分类纠正记录。
- 生成文本不会因为仅打开编辑器而被新增为手写标题；手写修改仍恢复既有语义分类。已显式锁定的包保持原有固定类别和标题修复规则，未顺手修 travel 文案映射。

### 未合并的边界

D3 只打开编辑器被当清空、D4 清空金额的意图延续、S1 travel 包跨类别标题、S2 生成早餐的事实锚点，以及首周免费槽位/奖励到期/会员失效政策、通勤证据合同和持久化失败恢复仍留在各自审计项。本任务不改变免费三包、奖励领取与替换、会员权益、场景包映射、OCR、同步或账单存储格式。

### 新增验证与真机签收

新增 `RecordRecommendationConsistencyTests` 的 19 个纯计算用例；不初始化有存储/后台副作用的 HomeViewModel。覆盖真实六条稀疏历史的 0.54 候选、0.55 采用边界及原服务标题门槛、精确金额与邻近金额冲突、有/无可信标题、可靠 4.75 交通标题、品牌/语义/纠正历史、生成来源和真实手写的区别、旧 key 拒绝、显式 travel 锁不变，以及便利店商品的标题与保存边界。既有具体未知备注拒绝覆盖用例继续保留。新增 23 条静态守卫负责核对策略接入实际入口，不能替代状态序列运行。

以下针对本补丁在免费、会员两种入口各跑一次，每步核对提示、分类、标题，保存后再核对记录：

| 操作 | 验收要求 |
|---|---|
| 仅金额＋不足支持的购物/餐饮历史 | 默认可为其他；不再同时声称已推荐另一类别 |
| 仅金额＋可靠交通/购物历史 | 默认、推荐提示、分类网格一致；已有可靠标题仍保留 |
| 精确金额购物、邻近金额餐饮冲突 | 精确金额采用购物，不混入餐饮标题 |
| 历史标题或手写罗森纸巾、分类尚未/已经推荐为日用 | 不发布“餐饮＋纸巾”历史文案；明确商品语义不因日用已选中而被品牌改回餐饮；共用解析的 OCR/历史编辑也复测 |
| 自动购物→帮写/连续换句→改日期跨历史 key→等待历史完成 | 仍为购物；不伪造手动分类锁 |
| 手写请客朋友→自动人情→换句为一起吃顿饭→保存 | 预览/保存同为人情和生成句；没有手动改分类记录 |
| 上述生成句改为手写牛肉面；另测手写同样的一起吃顿饭 | 释放生成来源，按真实备注识别餐饮 |
| 手选分类或选角度→连续换句→修改时间/历史刷新 | 用户锁仍优先；当前包不会被后台推荐换掉 |
| 只打开/取消分类或角度面板、只领取奖励或调整免费槽位 | 不因为该动作给草稿新增分类锁，不等于应用场景包 |
| 请求 A 未完成→备注/金额/日期 B→立即帮写或保存 | A 不覆盖 B；不复用过期提示/标题 |
| 生成后改金额、点常用金额、切 Tab 返回、成功保存后下一笔 | 金额原处理保持、草稿来源跨 Tab 保留、新一笔清理来源与旧推荐 |

最终补丁的 `python scripts/validate_release_gate.py --phase windows --release-branch feature/xuzhangapp-staging` 退出码 0，输出 `release_repository_gate: OK`；包含语义、静态体验、文案、schema、迁移和规模夹具检查，保留既有 7 条文案软提示。任务在台账第 153 节记录为 CODE_DONE。当前无 Swift/swiftc/Xcode，19 个新增 XCTest、Swift 6 编译及以上 UI 操作尚未执行，不得据此标记真机验证通过。
