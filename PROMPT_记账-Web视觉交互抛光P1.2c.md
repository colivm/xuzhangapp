# Agent Prompt · Task UI-P1.2c-WEB — 视觉与交互质感抛光（最新 Web 预览）

> **状态：待做 · 当前最新 Web Agent prompt**  
> **前提**：L0/L1/L2 策略与 tier 逻辑 **已定，本 PR 不改**（见 P1.2 / P1.2b）。  
> **本 PR 只做**：生活纸条视觉、安静交互、文案气质、去表单/demo 痕迹。  
> **不动**：iOS、backend、引擎判定规则、耳语池 15 条正文。  
> 用法：**整段复制下方「复制发送」** 发给 Agent。

---

## 创始人诊断（本 PR 要修的糙感）

| 糙感 | 目标 |
|------|------|
| 层级有了，视觉没收住 | 主行/胶囊/meta/操作合成 **一张生活纸条**，非控件堆叠 |
| 旧 Demo / 表单改造底子 | 藏起快捷金额、调试条、会员包列表；OCR 不像模式切换器 |
| 文案气质不统一 | L2 品牌/习惯/换角度句统一 **叙账语气**（见 §文案） |
| 交互太工具化 | 用户先看到 **一句生活**；操作 **轻、晚、低对比** |

**禁止本 PR**：加新功能、改 tier 规则、改耳语池句子、动 NativeDemoApp。

---

## 北极星（不变）

```text
默认让用户确认，不让用户配置。
首屏：金额舞台 → 生活纸条 → 放进账本
```

---

## 必做 1 · 生活纸条：一张完整的视觉对象

**文件**：`index.html` 结构调整 + `styles.css` 重写 `.life-entry-*`

### 推荐 DOM（可等价实现，语义须保留）

```html
<section id="lifeEntryPreview" class="life-slip hidden">
  <div class="life-slip-body">
    <p id="lifeEntryHeadline" class="life-slip-headline"></p>
    <p id="lifeEntryHeadlineHint" class="life-slip-hint hidden"></p>
    <p id="lifeEntryEmotion" class="life-slip-mood hidden"></p>
    <p id="lifeEntryMeta" class="life-slip-meta muted"></p>
  </div>
  <div class="life-slip-foot">
    <nav id="lifeEntryQuietActions" class="life-slip-quiet-actions" aria-label="轻操作"></nav>
    <span id="lifeEntryAmount" class="life-slip-amount"></span>
  </div>
  <!-- 深操作：默认 hidden，仍在纸条内 -->
  <div id="lifeEntryNoteEditor" class="life-slip-expand hidden">...</div>
  <div id="lifeEntryCategoryPanel" class="life-slip-expand hidden">...</div>
</section>
```

**视觉原则**：

- **一个容器** `life-slip`：圆角 20–24、极淡纸纹/留白，**不要**每个子块各自像 button card
- **body 与 foot 分隔**：仅 1px 极淡线或 12px 留白，非第二面板
- **禁止** `scene-primary-btn` / 大 pill 主色块出现在纸条 foot（全部改为 text link）

---

## 必做 2 · L1 轻耳语态（不像卡片，像提示）

**class**：`life-slip--whisper`（tier L1）

| 元素 | L1 样式 |
|------|---------|
| 容器 | **无**重边框/阴影；或仅左侧 2px accent 竖线；背景几乎融进 panel |
| 主行 | 15–16px，**regular**，subtext 色，行高 1.55；**不是** 18px bold |
| 胶囊 | **不显示** |
| meta | 11px muted，`今天 · 16:24` |
| foot | **仅** 1 个轻 link：`帮我写一句` + `自己写一句`（竖线分隔，无 pill） |
| 角标金额 | 11px，opacity 0.55，tabular-nums |

用户感受：**一行许可 + 安静金额**，不是「又一张功能卡」。

---

## 必做 3 · L2 确认卡态（主行主角）

**class**：`life-slip--confirm`（tier L2）

| 元素 | L2 样式 |
|------|---------|
| 主行 | **20–22px semibold**，text 色，最大视觉权重 |
| 胶囊 mood | **弱化**：11px、无实心底或 opacity 0.5 描边；在主行 **下方 6px**，像附注不是第二标题 |
| meta | 12px muted，单行：`吃饭 · 今天 16:24`；**改** 为同行末尾 link，非独立按钮行 |
| 角标金额 | 12px，subtext，**弱于主行**；放 foot 右下，不挤占主行 |
| foot quiet actions | 见必做 4 |

---

## 必做 4 · 安静操作条（统一低干扰）

**容器** `#lifeEntryQuietActions`：单行 flex，**全是 link 或 12px text**，无 pill、无渐变、无 icon 大块。

**显隐（逻辑不变，样式统一）**：

| tier / 状态 | foot 文案（竖线 `|` 分隔） |
|-------------|---------------------------|
| L1 | `帮我写一句` \| `自己写一句` |
| L2 未换句 | `换一句` \| `自己写一句`（brand 用 `换说法`） |
| L2 已换句 | `换一句` \| `换个角度` \| `自己写一句` |

- **改分类**：只在 meta 行末尾 **改**，不要单独按钮行
- **换个角度**：仅 link 文字，**禁止**与「换一句」同权重 pill
- hover：仅 underline 或 opacity 0.85，**无**背景色块

**删除/禁止**：`.scene-primary-btn`、`.scene-quick-btn` 在预览卡 foot 的使用。

---

## 必做 5 · 系统句 hint（L2 引擎句）

`#lifeEntryHeadlineHint`：主行下 11px muted，仅引擎生成句时：

```text
想换说法，点下面轻字即可
```

**禁止**：「系统先写了一句 · 可点…」类功能说明书腔（太工具）。

用户手写后 hidden。

---

## 必做 6 · 文案气质统一（L2 句池）

**文件**：`app.js` — 集中 `narrativeToneLines` / 改写 brandsLite.emotion / 换角度 tagline

### 叙账语气规则

- ✅ 生活瞬间、周记感、可叙之材
- ❌ 功能提示（「适合通勤类小记」）、备注推荐腔（「比如输入¥」）、广告腔

### 品牌 emotion（5 品牌，每条 2–3 轮换）

luckin 示例：`早班路上，顺手续一口` / `蓝杯小小提神` / `赶路前醒一醒`

### 习惯/换句 fallback（接 scene pack note 后须过审）

禁用显式「通勤出行打卡」类审计词；保留生活感。

### 换个角度 Sheet

| pack | 标题 | 副行（叙式） |
|------|------|-------------|
| commute | 打工人通勤包 | 地铁公交，赶路路上的一小段 |
| food | 吃货专属包 | 一顿饭、一杯喝的、小聚 |
| travel | 旅行预算包 | 出发、途中、沿路痕迹 |
| pet | 铲屎官宠物包 | 宠物日常与陪伴 |

Sheet 标题：**换个角度**  
副标题：**从另一种生活角度，记下这一笔。**

---

## 必做 7 · 去表单 / Demo 痕迹

### 7.1 OCR 入口（不像模式切换器）

- **删除或隐藏** 顶部 `#recordModeSegment` 大 segment（手动录入 | 智能导入）
- 改：金额舞台下方 **一行轻 link**：`从账单截图导入 →`（`#recordImportLink`）
- 点 link → 展开 `#ocrForm` 区域（或 sheet），文案：`从账单里捞一段生活，确认后再放进账本`
- 默认页 **只有手动三段式**；OCR 是 **侧门**，不是 Tab 切换

（`state.recordMode` 逻辑可保留，UI 上不呈现双按钮 segment。）

### 7.2 快捷金额

- `#amountQuickKeyboard` **默认 hidden**
- 金额输入 **focus** 时，在键盘上方 **小字** 显示 `.00 | +10 | +50` link 行（非四颗大 pill）
- 或收到金额舞台右下角 `···` 点开（二选一，须低调）

### 7.3 调试与旧模块

- `#prefillDemoBar`：仅 `?debug=1`
- `#recordDetailsFold`：保持 `hidden` + `aria-hidden`
- `#memberScenePackBlock`：不在 DOM 主路径渲染（仅 Sheet 用 `memberScenePacks` 数据）
- 页顶 kicker `把一笔生活放进账本` 可保留；`记下这一笔` 标题可略缩小，让金额舞台更主角

### 7.4 放进账本 CTA

- 保持唯一主色块在首屏
- 预览卡 foot **不得** 出现与 CTA 同视觉重量的按钮

---

## 必做 8 · 金额舞台与整体节奏

- 金额字号保持舞台感；L1 时预览 **whisper** 视觉退后，金额仍是焦点
- `amountAssist`：L0 `记下一笔今天的生活` · L1 `数额够了。`（更短）· L2 可 hidden
- 首屏垂直 rhythm：`amountStage` → `life-slip` → `save-row` 间距 16–20px，**无**中间插入 fold/segment

---

## 禁止

- 改 `resolveRecordPreviewTier` 判定条件（除非修 obvious bug）
- 改 coldStartWhispers 15 条原文
- NativeDemoApp / backend
- 新增业务功能
- git commit（除非用户要求）

---

## 验收（质感问句）

> 用户第一眼看到的是 **一句生活**，还是 **一排按钮**？

- [ ] L1：像 **一行许可提示**，不像功能卡
- [ ] L2：主行最大；胶囊淡；金额安静；foot 全是轻字 link
- [ ] 无顶部 手动/导入 大 segment；导入为轻 link 侧门
- [ ] 快捷金额不大 pill 占位
- [ ] 换角度 Sheet 叙式 tagline，无「路上的一句」
- [ ] 自己写/换句/改/换个角度 不抢主行
- [ ] 首屏仍：金额 → 纸条 → 放进账本
- [ ] tier 行为与抛光前一致（L1 无胶囊等）

---

## @ 文件

```text
@PROMPT_记账-Web视觉交互抛光P1.2c.md
@PROMPT_记账-Web抛光P1.2b.md
@PRODUCT_VISION_EVAL_v0.1.md
@RECORD_PAGE_DESIGN_v0.1.md
@web-preview/index.html
@web-preview/app.js
@web-preview/styles.css
```

---

## 复制发送（从这里开始整段复制）

```text
你在 xuzhangapp 实现 **Task UI-P1.2c-WEB — 视觉与交互质感抛光**（仅 web-preview；**同一 PR**）。

## 前提
L0/L1/L2 策略与 tier 逻辑 **已定，不改**。本 PR **不堆功能**，只重做视觉与交互质感。
不动 iOS/backend；不改耳语池 15 条原文。

## 北极星
用户先看到一句生活，操作轻轻露出来。首屏：金额 → 生活纸条 → 放进账本。

## 执行顺序
1. 重构预览区为单一 .life-slip（body + foot + expand 区）
2. L1 .life-slip--whisper：轻提示态，无重卡阴影，主行 regular 15–16px，无胶囊
3. L2 .life-slip--confirm：主行 20–22px semibold；胶囊弱化；金额 foot 右下安静
4. foot 全部改为轻 link 条（无 scene-primary-btn pill）：帮我写一句|自己写一句 / 换一句|换个角度
5. 改 只在 meta 行末尾；hint 改为「想换说法，点下面轻字即可」
6. 文案气质：换角度 Sheet + 品牌 emotion 叙式统一（见下表）
7. 去表单痕迹：隐藏 recordModeSegment；改 OCR 为轻 link「从账单截图导入」
8. 快捷金额改为 focus 时小 link 或 ··· 低调入口
9. prefillDemoBar 仅 debug；memberScenePackBlock 不主路径渲染

## 必须先 Read
@PROMPT_记账-Web视觉交互抛光P1.2c.md
@web-preview/index.html
@web-preview/app.js
@web-preview/styles.css

---

## 生活纸条视觉

一个容器 life-slip，不是控件集合：
- body：主行 + hint + mood(弱) + meta
- foot：quiet-actions 全 link + 角标金额（小、muted）
- expand：手写输入 / 分类 grid，默认 hidden

L1 whisper：几乎融进背景，像提示不像卡
L2 confirm：主行主角，胶囊附注感，操作低对比

## 安静操作（禁止 foot 大 pill）
L1：帮我写一句 | 自己写一句
L2：换一句 | 自己写一句（brand：换说法）
L2 已换句：加 换个角度
改：仅 meta 行末尾 link

## 换个角度 Sheet 叙式文案
commute 打工人通勤包 · 地铁公交，赶路路上的一小段
food 吃货专属包 · 一顿饭、一杯喝的、小聚
travel 旅行预算包 · 出发、途中、沿路痕迹
pet 铲屎官宠物包 · 宠物日常与陪伴
标题：换个角度；副标题：从另一种生活角度，记下这一笔。

## OCR 侧门
去掉顶部 手动录入|智能导入 segment
改为轻 link：从账单截图导入 → 展开 ocrForm

## 快捷金额
不大 pill；focus 时小 link .00|+10|+50 或低调 ···

## 禁止
改 tier 规则、改耳语15条、NativeDemoApp、backend、加新功能、git commit（除非用户要求）

## 验收
- [ ] 第一眼是生活句不是按钮排
- [ ] L1 轻耳语 L2 确认卡
- [ ] 无大 segment、无 demo 主路径
- [ ] 叙式文案统一
- [ ] tier 行为不变

## 交付
1. 改动文件列表
2. L1/L2 视觉前后说明（3条）
3. 糙感修复对照
4. 验收勾选

最小 diff，仅 web-preview/。
```

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版：不动策略，视觉/交互/文案气质抛光；最新 Web prompt |
