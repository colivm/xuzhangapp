# 真机走查 · 问题队列

> 更新时间：2026-07-22
> 状态：历史归档；对应任务和 Prompt 均已执行，当前状态与验证证据以全局优化台账为准。

---

## 已完成（勿重复）

| # | 问题 | 状态 |
|---|------|------|
| — | 首页 + 记账页叙事化（life-slip、放进账本、双动作卡） | ✅ 用户已完成 |
| — | UI-P1.3：顶栏小字按 Tab、暖日历、「记下一笔」 | ✅ 代码已有 |

---

## 队列 · 按修复顺序

### A. 小改 · 单文件可闭环（优先）

| # | 问题 | 现象 / 根因 | 改哪里 | 历史状态 |
|---|------|-------------|--------|---------------|
| **A1** | 底栏 Tab 图标真机比例不对 | 30pt 外圈 + 18pt 图形，路径坐标按 24 系未缩放 | `ContentView.swift` tabIcon | 已执行，见全局台账 |
| **A2** | 往年账单列表无年份 | `zhBillDateTime` 固定 `M月d日 HH:mm` | `HomeItem.swift` Date 扩展 | 已执行，见全局台账 |
| **A3** | OCR 导入后小字残留 | `ocrStatus` 写入后 `clearResolvedOCRDrafts` 不清 | `HomeViewModel.swift` | 同上 · ⏳ |
| **A4** | 「写点细节」删空又被写回 | `onChange(inputTitle)` → `refreshRecordPrefill` 空则 `inputTitle = habitTitle` | `HomeViewModel` + `RecordView` | 同上 · ⏳ |
| **A5** | OCR 脏标题进习惯预填 | `05-20 08:` 类时间串通过 `isHabitTitle` | `RecordPrefillService.swift` | 同上 · ⏳ |
| **A6** | 写细节时键盘挡输入 | `noteSection` 在折叠区底部，`ScrollView` 无随焦点滚动 | `RecordView.swift` ScrollViewReader | 已执行，见全局台账 |

### B. 记账 / OCR 逻辑

| # | 问题 | 现象 / 根因 | 改哪里 | 历史状态 |
|---|------|-------------|--------|---------------|
| **B1** | 瑞幸支付成功页 OCR 无品牌 | 确认页无 brand chip；`fallbackTitle` 抓状态栏时间 | `OCRConfirmSheet` + `OCRService` | 已执行，见全局台账 |
| **B2** | OCR 列表只识别 4/6 条 | `parseListReceipts` 只收带负号支出行 | `OCRService.swift` | 已执行，见全局台账 |
| **B3** | 凌晨刷旅游/景区备注 | `.other → travel`；travel 无深夜池 | `RecordView` + `ScenePackCopyPool` | 已执行，见全局台账 |

### C. 回望 / 引导

| # | 问题 | 现象 / 根因 | 改哪里 | 历史状态 |
|---|------|-------------|--------|---------------|
| **C1** | 切片引导 App 重启后又弹 | `emittedRouteGuidanceTypes` 仅内存 | `HomeViewModel.swift` | 已执行，见全局台账 |
| **C2** | 月章「变化点」老出「交通」 | 上月无数据时全类算 new + `sorted().first` | `PlaybackService.swift` | 已执行，见全局台账 |

### D. UI 叙事 · 去工具感（大 PR，单独做）

| # | 问题 | 现象 | 改哪里 | 历史状态 |
|---|------|------|--------|---------------|
| **D1** | **痕迹 Tab 仍像查账 demo** | 首屏「账单」+ 筛选 + 合计 + 记录列表；切片埋下面 | `StatsWebView` + `ContentView` pageTitle | 已执行，见全局台账 |
| **D2** | **复盘 Tab 仍像报告生成器** | 渐变「生成月度复盘」、试用计数、按钮堆 | `InsightWebView.swift` | 已执行，见全局台账 |
| **D3** | **我的 Tab 偏管理后台** | 页内重复「设置」、开关矩阵 | `SettingsView.swift` | 已执行，见全局台账 |

---

## 建议执行节奏

```text
历史总索引：ISSUES_CHECKLIST_COPY.txt

第 1 轮：A1
第 2 轮：A2～A5（一 PR）
第 3 轮：A6
第 4 轮：D1（痕迹页，体感最大）
第 5 轮：D2
第 6 轮：B1 → C1 → C2
第 7 轮：B2 → B3 → D3
```

---

## 产品校验问句（每条改完过一遍）

> 这是在帮用户**温柔地看见生活**，还是在把叙账拉回**管钱工具**？

---

## 修订

| 日期 | 说明 |
|------|------|
| 2026-06-02 | 初版：汇总走查 + 叙事断层 + Tab 图标 |
