# FIX-003 交接：Windows → macOS（2026-09-25）

配套阅读：`GLOBAL_PRODUCT_INTERACTION_OPTIMIZATION_LEDGER_2026-07-15.md` 的 `FIX-003` 小节。
技术判断、已修内容、以及「本次未采纳的改动」及其原因都在那里，本文件只记在 macOS 上要执行什么。

## 当前状态

- 分支 `feature/xuzhangapp-staging`，最新提交 `91f5b96`。
- `FIX-003` 状态 `CODE_DONE`。本机为 Windows，无 Swift 工具链，**未执行过任何 XCTest**，不得标 `VERIFIED`。
- 生产代码在本批次最后一步已全部回退，只剩一处测试夹具修改。
  （`RecordView.swift` 在 Windows 上显示 `M`，但 blob hash 与 HEAD 逐字节一致，仅 stat 缓存脏；干净 checkout 无此现象。）

## 两条待办用例

| 用例 | 类 | 状态 |
|---|---|---|
| `testManualAmountMatchesShortcutAmountWhenHistoryHasStableMerchantTitle` | `RecordInputAssistanceSnapshotTests` | 已修，待确认 |
| `testHostedEditorTransfersFocusBetweenAmountAndNote` | `CommittedRecordNoteFieldTests` | 已定位，未修 |

## 1. 取代码

不要从 Windows 工作目录拷贝：仓库内有 `output/`、`tmp/`、`scripts/__pycache__/`、`brand-assets/` 等本机生成的未跟踪目录。

```bash
git fetch origin
git checkout feature/xuzhangapp-staging
git log --oneline -1        # 期望 91f5b96
```

## 2. 跑这两条

scheme `NativeDemoApp`，测试 target `NativeDemoAppTests`。
仓库内无 `.xctestplan`（scheme 里 `shouldAutocreateTestPlan="NO"`），故 `-only-testing` 可直接用。
scheme 的 TestAction 已钉 `TZ=Asia/Shanghai`，勿在命令行覆盖。

```bash
xcodebuild test \
  -project NativeDemoApp.xcodeproj \
  -scheme NativeDemoApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:NativeDemoAppTests/RecordInputAssistanceSnapshotTests/testManualAmountMatchesShortcutAmountWhenHistoryHasStableMerchantTitle \
  -only-testing:NativeDemoAppTests/CommittedRecordNoteFieldTests/testHostedEditorTransfersFocusBetweenAmountAndNote \
  -resultBundlePath /tmp/xtest.xcresult
```

先只用 iPhone 16 迭代，最后再铺四台。

## 3. prefill 那条：预期直接绿

夹具已固定为本地周五 2026-09-25 09:08，D-1..D-3 为周四/三/二，全工作日，与参考日 `dayKind` 一致且满 3 条。

若仍红，说明对 `dayKind` 的推断有误，需回传 `history.frequentSuggestions` 相关断言的实际输出。

## 4. 焦点那条：先采集证据，勿直接改

失败推断为只出现在 `for _ in 0..<2` 的第二轮，但日志无轮次信息，需先坐实。
以下为**临时诊断改动，确认后删除**。

`NativeDemoAppTests/StateRegressionTests.swift`：第 812 行 `for _ in 0..<2` 改为 `for iteration in 0..<2`，
并在第 819 行 `settleUI(host)` 之后、第 820 行断言之前插入：

```swift
print("ITER \(iteration) after insert: note=\(note.isFirstResponder) amount=\(amount.isFirstResponder) noteText=\(note.text ?? "")")
```

`NativeDemoApp/Views/RecordView.swift`：`CommittedRecordNoteField.Coordinator.textFieldDidEndEditing` 开头插入：

```swift
print("NOTE_END_EDITING isFocused=\(parent.isFocused) isFirstResponder=\(textField.isFirstResponder)\n\(Thread.callStackSymbols.prefix(14).joined(separator: "\n"))")
```

调用栈是关键：用于区分「SwiftUI 因兄弟 `@FocusState` 清零而驱逐 first responder」与「其他路径主动 resign」。
`isFocused` 的值用于验证「`textFieldDidEndEditing` 在模型仍要求聚焦时触发」这一前提。

有 Xcode 时也可改用断点：在 `textFieldDidEndEditing` 处观察 `note` 与 `amount` 的 `isFirstResponder`，等价。

回传 `ITER` 与 `NOTE_END_EDITING` 两块输出。

## 5. 修复约束（务必保留）

正式修复必须同时满足，否则会换一个地方红：

- 不得在第 822 行 `amount.becomeFirstResponder()` 时把焦点从金额抢回 —— 会打破同一用例第 824/825 行的互斥断言。
- 不得在用户主动点击别处收起键盘时把键盘拉回。

这两条正是需要第 4 步调用栈才能区分的情形。已试写并回退的方案同时踩中两条，详见台账 `FIX-003`「本次未采纳的改动」。

## 6. 收尾

```bash
xcodebuild test -project NativeDemoApp.xcodeproj -scheme NativeDemoApp \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max'
```

- 删除第 4 步的所有诊断 `print`。
- 按台账要求更新 `FIX-003`：范围、文件、验证证据、剩余风险、下一任务。只有真实通过的运行结果才可将状态改为 `VERIFIED`。
- 顺带项：`testTrustedTitleBrandAndScenePackStillCreateFacts` 在 `c0dd306` 的 Xcode Cloud 结果中消失，但本批次未为它改动任何代码，不能判定已修复。全量跑时留意是否为间歇性失败。
