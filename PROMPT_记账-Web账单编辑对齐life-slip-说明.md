# Agent Prompt · Task UI-P1.2-WEB-EDIT — 账单编辑态对齐 life-slip（仅 web-preview）

> **状态：待做 · Web 编辑态专项**  
> **前置**：新建记账页 P1.2 life-slip 结构已落地（`PROMPT_记账-Web综合抛光P1.2-完整说明.md`）  
> **范围**：**仅** `editingRecordId` 编辑态；**不**重做新建流程、**不**动 iOS / backend  
> 用法：**整段复制同目录 `PROMPT_记账-Web账单编辑对齐life-slip-任务.txt`** 发给 Agent。

---

## 0. 一句话任务

把「从列表点进改一笔」从 **demo 全展开表单感** 收成与新建一致的 **「金额 → 生活纸条 → 更新这一笔」**；用户改的是 **一段生活**，不是 **编辑账单字段**。

---

## 1. 问题诊断（当前代码）

编辑复用记账 Tab（`openRecordEditor` → `switchTab("record")`），life-slip 外壳在，但一进编辑就 **强制展开所有深操作**：

| 位置 | 现状（demo 残留） |
|------|------------------|
| `openRecordEditor()` ~4199–4202 | `recordDetailsExpanded = noteEditorExpanded = categoryPanelExpanded = true`；`previewLineWasRotated = true` |
| `renderRecord()` ~4227–4230 | `isEditing` 时 **再次** 强制三者 `true`（每次 render 锁死展开） |
| `#lifeEntryNoteEditor` | 进编辑即见输入框（等同旧「备注字段」） |
| `#lifeEntryCategoryPanel` | 进编辑即见分类 chip grid 全展开 |
| `#deleteRecordBtn` | 文案「删除账单」+ `full-btn` 次级大按钮 |
| `#editDateBtn` | 📅 emoji 图标按钮，`title="补记日期"` |
| 保存 toast | 「账单已更新」（审计腔） |
| life-slip meta | 编辑仍显示「今天 H:mm」，补记日期后不反映真实日期 |

**新建路径**（`startNewManualRecordDraft`）已正确：`noteEditorExpanded = categoryPanelExpanded = false`。

**本 PR 只修编辑路径**，新建行为不得回归。

---

## 2. 产品共识（不可破）

```text
编辑 = 调整这一笔生活，不是打开账单表单。
默认让用户确认，不让用户配置。
```

编辑态首屏主路径与新建 **同结构**：

```text
1. 金额舞台
2. 生活纸条（life-slip · 通常 L2）
3. 更新这一笔（全页唯一主色 CTA）
4. 次要：改日期 · 删除这一笔（安静 link，非大按钮）
```

**禁止编辑态首屏默认出现**：分类 chip grid、备注输入框、`recordDetailsFold` 展开。

---

## 3. 范围与禁止

### 可改

- `web-preview/app.js`：`openRecordEditor`、`renderRecord`（仅 `isEditing` 分支）、`updateLifeEntryPreview`（编辑 meta 日期）、保存 toast
- `web-preview/index.html`：`#editDateBtn`、`#deleteRecordBtn` 结构与 copy
- `web-preview/styles.css`：编辑次要操作 quiet 样式（若需）

### 禁止

- 改 `resolveRecordPreviewTier()` 判定 if 条件
- 改 `coldStartWhispers`、品牌 lines、耳语池
- 改 `addRecord` / 保存字段逻辑（除 toast copy）
- 改首页列表、痕迹 Tab 列表、OCR 流程
- 改新建记账页 DOM / 新建态默认折叠行为
- `NativeDemoApp/` · `backend/`
- git commit（除非用户明确要求）

---

## 4. 编辑态行为规范

### 4.1 进入编辑（`openRecordEditor`）

**保留**（数据预填）：

- `editingRecordId`、`titleInput`、`amountStream`、`selectedCategory`、`categoryLockedByUser = true`
- `recordDateInput` = item 日期
- `refs.recordFormTitle` = 「调整这一笔」
- 隐藏 `#recordImportLink`（已有）
- 显示删除、改日期控件

**改为与新建一致的折叠默认**：

```javascript
recordDetailsExpanded = false;
noteEditorExpanded = false;
categoryPanelExpanded = false;
// 不要设 previewLineWasRotated = true
// tier 已由 editingRecordId → resolveRecordPreviewTier 的 edited 分支进 L2
```

用户已有 `title` 时：`edited = true` → L2，主行显示原生活句，**无需**伪造 `previewLineWasRotated`。

### 4.2 `renderRecord()` 编辑分支

**删除** ~4227–4230 对 `isEditing` 强制展开三 flag 的代码块。

编辑态与新建共用同一套 expand 规则：

- `#lifeEntryNoteEditor`：仅 `noteEditorExpanded === true`
- `#lifeEntryCategoryPanel`：仅 `categoryPanelExpanded === true` 且 L2
- `toggleRecordDetails`：编辑态 **不要** 因 `isEditing` 绕过折叠

**保留**编辑专有：

- `refs.saveRecordBtn.textContent = "更新这一笔"`
- `refs.editDateBtn` 可见
- `refs.deleteRecordBtn` 可见
- `refs.amountAssist` 编辑时可 hidden（金额已有，不抢纸条）

### 4.3 life-slip 交互（与新建一致）

| 操作 | 行为 |
|------|------|
| foot「自己写一句」 | `noteEditorExpanded = true`，focus `#titleInput` |
| meta「改」 | toggle `#lifeEntryCategoryPanel` |
| foot「换一句 / 换说法」 | `rotatePreviewLine()`，**不**自动展开分类 grid |
| foot「换个角度」 | `openScenePackMoreSheet()` |
| 点主行 | 仍可展开手写（辅助） |

**验收**：从首页/痕迹列表点一条 → 首屏 **只见** 金额 + L2 纸条 + 「更新这一笔」；**不见** 输入框与分类 grid。

### 4.4 meta 日期（编辑专有 · 小改）

编辑态 meta 时间应反映 **该笔实际日期**，而非一律「今天」：

- 读 `refs.recordDateInput.value` 或 item `createdAt`
- 若是今天：「{分类} · 今天 H:mm」（H:mm 取自 item `createdAt`）
- 若非今天：「{分类} · M月D日」或「{分类} · yyyy-M-D」（与 App 其他列表 muted 风格一致即可）
- 用户点「改日期」并变更后，`updateLifeEntryPreview` 应刷新 meta

**不要**为此改 tier 判定。

### 4.5 次要操作 · 安静化

| 控件 | 目标 |
|------|------|
| `#editDateBtn` | 文案 link：**改日期**（去掉 📅）；`life-slip-link` 或同级 quiet 样式；仍触发 `#recordDateInput` picker |
| `#deleteRecordBtn` | 文案：**删除这一笔**；改为 text/link 按钮（`.record-edit-secondary` 或 destructive quiet link）；**不要** `full-btn` 大块 |
| 布局 | 建议放在 `#recordPrimaryActions` 下方一行 `.record-edit-secondary-row`：`改日期 · 删除这一笔`（竖线分隔）；或日期留 save-row 旁、删除单独一行 muted |

保存成功 toast：**这一笔已更新**（取代「账单已更新」）。

---

## 5. 入口与退出（勿回归）

| 场景 | 预期 |
|------|------|
| 首页今日列表点击 | `openRecordEditor` → 记下 Tab · 折叠编辑态 |
| 痕迹 Tab 列表点击 | 同上 |
| 保存成功 | 清 `editingRecordId`，`goHomeAfterSave()`，toast「这一笔已更新」 |
| 编辑中再点「记下」Tab | 现有 `startNewManualRecordDraft()` 清编辑 → **保持** |
| 删除 | 现有 modal 流程 → **保持** |

---

## 6. 实施顺序

```text
1. app.js：openRecordEditor 改折叠默认；去掉 previewLineWasRotated 强制 true
2. app.js：renderRecord 删 isEditing 强制展开块
3. app.js：updateLifeEntryPreview 编辑 meta 真实日期
4. index.html + styles.css：改日期 / 删除 quiet 化
5. app.js：保存 toast copy
6. 自测 §7
```

**最小 diff**：仅 `web-preview/index.html` · `app.js` · `styles.css`。

---

## 7. 验收清单

### 质感问句

> 从列表点进改一笔，第一眼是 **一句生活 + 确认**，还是 **表单字段全展开**？

### 必过

- [ ] 进编辑：life-slip L2 显示原 title/分类；**默认无** 备注输入框、**无** 分类 grid
- [ ] 「自己写一句」才展开输入；「改」才展开 grid
- [ ] 「换一句」不自动展开 grid
- [ ] 主 CTA 为「更新这一笔」；标题「调整这一笔」
- [ ] OCR 侧门编辑态 hidden
- [ ] 改日期 / 删除为 quiet link，无「删除账单」、无 📅 大图标按钮
- [ ] 补记日期后 meta 显示对应日期（非一律「今天」）
- [ ] 保存后回首页，列表数据正确
- [ ] **新建**记账路径：L0/L1/L2、折叠默认、放进账本 — **零回归**

### 可选

- [ ] 编辑保存后 pet toast 可保持现有或略叙式（非必须）

---

## 8. @ 文件

```text
@PROMPT_记账-Web账单编辑对齐life-slip-说明.md
@PROMPT_记账-Web综合抛光P1.2-完整说明.md
@RECORD_PAGE_DESIGN_v0.1.md
@web-preview/index.html
@web-preview/app.js
@web-preview/styles.css
```

---

## 9. 复制发送

见同目录 **`PROMPT_记账-Web账单编辑对齐life-slip-任务.txt`**（纯文本，可直接全选复制）。

---

## 修订记录

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 首版：Web 编辑态专项，对齐 life-slip 折叠默认 + 次要操作 quiet 化 |
