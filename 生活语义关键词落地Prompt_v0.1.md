# 生活语义关键词落地 Prompt v0.1

> 用途：补词 / 对齐 / 修复语义链路时，复制下方「执行 Prompt」给 AI 或开发同学。  
> 前置文档：[生活语义关键词缺口梳理_v0.1.md](./生活语义关键词缺口梳理_v0.1.md)  
> 说明：本文档**只定义落地规范**，不直接改代码。

---

## 一、落地总原则（红线）

1. **只做新增式改动，不动主线逻辑**
   - 不改分类优先级、hour 过滤 emotion、leisure 广度、weeklyCopy 等已稳定的主链路。
   - 不为了「更聪明」重构 `RecordDraftResolutionService`、`LifeMarkService` 匹配框架。
   - 允许：加词、加 intent、加品牌、加情绪规则、加 anchored 文案、修明显 bug（如旧 brandId 残留）。

2. **优先补具体词，禁止随手补单字宽词**
   - ❌ 禁止新增或恢复：`饭`、`吃`、`餐`、`面`、`奶` 等单字（已有误伤先例）。
   - ✅ 优先：`茶叶蛋`、`黄焖鸡`、`老乡鸡`、`续 B 站会员`、`保洁阿姨`、`山姆会员` 等可判定的短语/品牌。

3. **五表必须一起想，不能只改一处**
   - 每批词落地前，先填对齐清单（见第三节），再动手。
   - JSON 有、Swift fallback 无 → 必须同步，避免真机与 fallback 行为不一致。

4. **场景包文案 ≠ LifeMark 关键词**
   - `ScenePackCopyPool` 各档 `notes` 是**随机换句池**，会写进 `title`。
   - 不得放入 LifeMark 强匹配词：`房租`、`押金`、`租房`、`水电`、`电影`、`健身` 等（除非该 pack 就是专门承接且已验收）。
   - 用户**手输**「房租/押金」仍应走 LifeMark 独立链路；场景包不应「帮用户代写」这些强语义。

5. **品牌匹配只认 `matchBrand`，不用 alias 模糊 contains**
   - 编辑标题后：旧 `merchantBrandId` 若与新标题 `matchBrand` 不一致，必须清掉。
   - 不要用「标题包含某 alias 子串」保留旧品牌（美团 → 买牛奶 类 bug）。

6. **文案可优化，但别改产品预期行为**
   - 生活切片结束页**重播不扣免费次数**——这是预期，落地时不要动。
   - `weeklyCopy` 已回退过，本次批次不要顺手改。

7. **小步提交、可回归**
   - 单 PR / 单批次建议：**20–40 个词**或 **1 个场景域**（如「国民快餐品牌库」）。
   - 每批必须附真机回归用例（见第七节）。

---

## 二、涉及文件与改动类型

| 目标 | 文件 | 改动方式 | 注意 |
|------|------|----------|------|
| 分类 / OCR / 情绪主路径 | `RecordSceneLexicon.json` | 加 categoryKeywords、ocrKeywords、emotionRules | 改 JSON 后检查 Swift fallback 是否要同步 |
| JSON 加载失败兜底 | `RecordSemanticLexicon.swift` | minimalFallback 补词 | 与 JSON 保持一致，不要比 JSON 更宽 |
| 生活切片信号 | `LifeSceneSemanticService.swift` | 各 scene 的 keywords/brands | 与 LifeMark 类目语义一致，避免 groceries 有、印记无 |
| 生活印记 | `LifeMarkService.swift` | `definitions` 加词；必要时新 intent | 新 intent 设 `requiresKeywordMatch: true`；避免与宽 intent 抢匹配 |
| 品牌识别 + tier 文案 | `MerchantBrandCatalog.swift` | 新品牌 + aliases + category | 品牌 category 与 JSON 分类一致；tier 文案勿文艺腔 |
| 情绪标签精修 | `HomeItem.swift` `refinedEmotionTag` | 加细规则 | 优先级高于场景包时段池；便利店小食等要覆盖 |
| 换句 anchored | `RecordView.swift` | anchored copy / `noteHasSpecificSemantics` | 有具体语义时换角度/换句不跳 pack、不覆盖用户备注 |
| 场景包换句池 | `ScenePackCopyPool.swift` | 各 tier notes | **只改中性场景描述**，不加 LifeMark 强词 |
| 回放展示文案 | `HomeView.swift` `itemMomentBody` | 叙事文案 | 与品牌 tier、印记一致，不引入新误匹配词 |
| 编辑保存 | `ContentView.swift` | 一般**不改**；仅修 brand 残留类 bug | 旧品牌保留逻辑：`matchBrand(in: title)?.id == oldBrand.id` |

---

## 三、单批落地流程（必须按顺序）

### Step 1：从缺口文档选一批词

- 默认从 **P0 → P1** 取词。
- 本批明确范围，例如：「餐饮连锁品牌 15 个 + 便利店小食 anchored 5 个」。

### Step 2：填五表对齐清单（动手前）

对每个词/品牌，标注 ✅ / ❌ / 不改动：

| 词/品牌 | JSON 分类 | JSON OCR | JSON emotion | LifeScene | LifeMark | 品牌库 | refinedEmotion | RecordView anchored |
|---------|-----------|----------|--------------|-----------|----------|--------|----------------|---------------------|
| 示例：老乡鸡 | | | | | | | | |

**规则：**
- 本批要解决的链路必须标 ✅；暂不做的标 ❌ 并写原因。
- 若只加 OCR 不加品牌库，须在清单备注「仅 OCR，用户手打仍无品牌叙事」。

### Step 3：过误伤表（动手前）

对照下表，本批每个新词至少回答「会不会误伤什么」：

| 风险词/模式 | 可能误伤 | 处理 |
|-------------|----------|------|
| 单字：饭/吃/餐/面/奶 | 几乎所有备注 | 拒绝添加 |
| 押金 | 跑腿押金 vs 租房押金 | 用「租房押金」「房租押金」短语；errand 与 home 分开 |
| 下班/回家 | transport 情绪 vs 餐饮文案 | 不加到 dining 规则；场景包慎用 |
| 会员 | 视频/健身/山姆/店铺会员 | 用完整短语：「B站会员」「健身年卡」「山姆会员」 |
| 游戏 | 充值 vs 线下桌游 | 优先品牌或「Steam」「点券」等具体词 |
| 充电 | 汽车充电 vs 手机充电 | 用「充电桩」「新能源车充电」等 |
| 电影 | 误触发 movie_ticket | 新 leisure 词不要含「电影」除非就是电影票 intent |

### Step 4：实施（按链路顺序）

推荐顺序（减少半成品状态）：

1. **MerchantBrandCatalog**（若有品牌）
2. **RecordSceneLexicon.json**（category + ocr + emotion）
3. **RecordSemanticLexicon.swift** fallback（若 JSON 有新增 emotion/category）
4. **LifeSceneSemanticService**
5. **LifeMarkService**（含新 intent 时加 `requiresKeywordMatch`）
6. **HomeItem.refinedEmotionTag**
7. **RecordView** anchored / `noteHasSpecificSemantics` 相关
8. **ScenePackCopyPool**（仅当本批涉及场景包文案，且遵守第四节）

### Step 5：自测 + 真机回归

跑完第七节用例再提交。

---

## 四、场景包与换句专项注意

以下问题已在生产逻辑中踩过坑，落地时必须检查：

### 4.1 场景包 + 换一句 → 污染 title → 误触 LifeMark

**坏路径：** 用户选居家场景包 → 点「换一句」→ 抽到「房租与押金」→ title 被改写 → 命中 `home_utilities`「押金」。

**落地规则：**
- `ScenePackCopyPool.home`（及其他 pack）的 `notes` 用**中性居家描述**：维修、消耗、小物、补货。
- 强 LifeMark 词（房租、押金、水电、燃气、物业、宽带）**只出现在用户手输或 OCR**，不出现在场景包随机池。

### 4.2 换角度 / 换句时跳 pack

**坏路径：** 用户备注「茶叶蛋」→ 换角度到吃饭 → 再换句 → conflict 分支按 `scenePackForTitle` 换 pack，小金额像通勤。

**落地规则：**
- `noteHasSpecificSemantics(title)` 为 true 时（匹配 category 或 emotion rule）：
  - `shouldPreserveUserNoteWhenChangingAngle` 应保护用户备注。
  - 换句 conflict 时**不要**因新 title 自动换 scene pack。
- 新增具体食物词时，务必同时进入 JSON emotion 或 category，确保 `noteHasSpecificSemantics` 能识别。

### 4.3 快捷备注 vs 手输

- 快捷备注可能设 `lastDraftIntent = .category`，anchor 保护较弱。
- 具体语义词（茶叶蛋、牛奶、保洁）必须有 emotion/category 匹配，不能只靠场景包档位。

### 4.4 金额 + 时段

- 小金额 + 晚餐时段 + 无具体语义 → 容易落到 `ScenePackCopyPool.food`「晚餐一份主菜」。
- 补便利店小食、轻食时，**情绪规则优先于时段场景包**。

---

## 五、LifeMark 新增 / 改词注意

1. **新 intent 优先于往旧 intent 狂塞词**
   - 例：电影票单独 `movie_ticket`，不要全塞进 `leisure`。
   - 数字订阅、家政保洁、配镜洗牙等 P2 场景，考虑新 intent 而非塞进 `entertainment` / `home_utilities`。

2. **`requiresKeywordMatch` 选择**
   - 具体场景（电影、健身、咖啡）：`true`
   - 宽类目兜底（commute、daily_supply）：`false`，但**不要**再往里面加单字宽词

3. **keywords 与 categories 一致**
   - `categories` 数组决定哪些分类下的记录参与聚合；keywords 错会导致「分类对了印记不对」。

4. **priority / minimumCount**
   - 新 intent 不要设过高 priority 抢过更具体的 intent。
   - 改 priority 属于主线逻辑，本批次避免。

---

## 六、品牌库注意

1. **aliases 要全但别宽**
   - 加：`老乡鸡`、`塔斯汀中国汉堡`
   - 不加：`鸡`（误伤一切含鸡备注）

2. **category 与默认叙事 tier 一致**
   - 餐饮品牌 → `.dining`；超市 → `.daily` / `.shopping` 按现有 convention。

3. **与 JSON OCR 对齐**
   - OCR 能识别但品牌库没有 → 导入有分类无品牌叙事，本批应一并补。

4. **编辑态**
   - 用户把「美团外卖」改成「认养一头牛」→ `merchantBrandId` 必须更新，不能留美团。

---

## 七、回归用例（每批至少跑一遍）

### 7.1 本批必测（按本批范围增删）

| # | 操作 | 预期 |
|---|------|------|
| 1 | 手输本批新增词（如「老乡鸡」） | 分类正确；有品牌则出品牌叙事 |
| 2 | OCR/粘贴含本批词的账单 | 分类 + 品牌（若已加）正确 |
| 3 | 选场景包 → 换一句 ×3 | title 不出现 LifeMark 强词；不跳 pack |
| 4 | 手输具体食物 → 换角度 → 换句 | 备注不被覆盖；不跳 pack |
| 5 | 编辑旧记录：改标题到本批词 | 旧 brandId 清掉；新品牌生效 |
| 6 | 生活印记页 / 切片回放 | 本批词能或不能出印记，符合对齐清单预期 |

### 7.2 固定防回归（每批都跑）

| # | 操作 | 预期 |
|---|------|------|
| A | 「茶叶蛋」+ 便利店场景 | 情绪/anchored 正确，不是「晚餐小聚一份主菜」 |
| B | 「第一次买电影票」 | 命中 `movie_ticket`，不是 justmysocks / 泛 leisure |
| C | 「买牛奶」/ 认养一头牛 | groceries 印记/切片正确；无美团 brand 残留 |
| D | ¥1000 + 居家场景包 + 换一句 | 不出「房租」「押金」类 title |
| E | 通勤补记草稿 | 日期带**周几**（`zhBillDateTimeWithWeekday`） |
| F | 生活切片结束页重播 | 不扣免费次数（预期行为，勿改） |

---

## 八、禁止事项清单

- ❌ 顺手重构匹配框架或调整 intent priority
- ❌ 改 `weeklyCopy`、生活切片扣次、leisure 广度
- ❌ 只改 JSON 不改 Swift fallback（或反之）
- ❌ 场景包文案池加热词
- ❌ 用 alias 子串 contains 保留旧品牌
- ❌ 一批塞 100+ 词无法回归
- ❌ 不加回归用例就合并 staging

---

## 九、交付物格式

每批落地完成后，输出简短说明（可贴在 PR / commit body）：

```markdown
## 本批范围
- 词表：……
- 优先级：P0 / P1
- 五表对齐清单：（表格或链接）

## 改动文件
- …

## 误伤评估
- 新词 X：不会误伤，因为……
- 未加单字「面」：因为……

## 回归结果
- [x] 用例 1 …
- [x] 固定防回归 A–F

## 未做（留下一批）
- …
```

---

## 十、执行 Prompt（复制使用）

将下方整段复制给 AI，把 `【批次占位符】` 换成实际内容即可。

---

```
你是 xuzhangapp 生活语义关键词落地助手。请严格按仓库内文档执行，不要动主线逻辑。

## 必读
- 生活语义关键词缺口梳理_v0.1.md
- 生活语义关键词落地 Prompt v0.1.md（本文档）

## 本批任务
【批次占位符：例如 P1 餐饮连锁品牌 15 个：老乡鸡、塔斯汀、库迪、海底捞……】

## 硬性约束
1. 只做新增式改动：加词、加品牌、加 intent、加情绪/anchored 规则。不改分类优先级、hour 过滤、leisure 广度、weeklyCopy、生活切片重播扣次。
2. 禁止新增单字宽词：饭、吃、餐、面、奶。
3. 五表对齐：RecordSceneLexicon.json、RecordSemanticLexicon fallback、LifeSceneSemanticService、LifeMarkService、MerchantBrandCatalog；涉及换句/情绪时同步 HomeItem.refinedEmotionTag、RecordView anchored。
4. ScenePackCopyPool 各档 notes 不得含 LifeMark 强词（房租、押金、水电、燃气、物业、宽带、电影等）。
5. 品牌只认 MerchantBrandCatalog.matchBrand；编辑标题时旧 merchantBrandId 不匹配则清空。
6. 新 LifeMark intent 默认 requiresKeywordMatch: true；具体场景（如电影票）单独 intent，不塞进 leisure。
7. 先输出五表对齐清单 + 误伤评估，等我确认后再改代码（若我明确说「直接做」则一并输出清单与改动）。

## 实施顺序
品牌库 → JSON（category/ocr/emotion）→ Swift fallback → LifeScene → LifeMark → refinedEmotionTag → RecordView anchored → ScenePackCopyPool（若需要）

## 完成后必须给出
1. 五表对齐清单（本批每个词的最终状态）
2. 误伤评估
3. 改动文件列表
4. 回归结果（本批用例 + 固定防回归：茶叶蛋、电影票、买牛奶、居家场景包换句、通勤周几、重播不扣次）
5. 明确列出「本批未做、下一批建议」

## 文案要求
- 品牌 tier、回放 itemMomentBody、场景包 notes：口语化、具体、少文艺腔。
- 与现有 MerchantBrandCatalog / HomeView 文案风格一致。

开始执行。
```

---

## 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.1 | 2026-06-25 | 初版：基于缺口梳理与已修复问题（场景包/LifeMark/brand/茶叶蛋/电影票）整理落地规范与可执行 Prompt |
