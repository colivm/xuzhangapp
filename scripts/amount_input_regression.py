#!/usr/bin/env python3
"""Static amount-input scheduling/cache contracts; not a Swift runtime benchmark."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
model = (ROOT / "NativeDemoApp/ViewModels/HomeViewModel.swift").read_text(encoding="utf-8")
view = (ROOT / "NativeDemoApp/Views/RecordView.swift").read_text(encoding="utf-8")
service = (ROOT / "NativeDemoApp/Services/RecordDraftResolutionService.swift").read_text(encoding="utf-8")


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


amount_observer = section(model, '@Published var inputAmount:', '@Published private(set) var isRecordAmountInputPending')
assert amount_observer.index("invalidateRecordPrefillSnapshot()") < amount_observer.index("scheduleRecordAmountInput()")
schedule = section(model, "private func scheduleRecordAmountInput()", "func flushPendingRecordAmountInput()")
for required in ("recordAmountInputTask?.cancel()", "amount > 0", "cancelPendingRecordAmountInput()",
                 "recordAmountInputGate.begin()", "Task.sleep", "!Task.isCancelled",
                 "recordAmountInputGate.finish(request)", "refreshRecordPrefill()"):
    assert required in schedule, required
assert "180_000_000" in service
flush = section(model, "func flushPendingRecordAmountInput()", "func cancelPendingRecordAmountInput()")
assert flush.index("recordAmountInputGate.finish(request)") < flush.index("refreshRecordPrefill()")
assert "recordAmountInputTask?.cancel()" in flush
refresh = section(model, "func refreshRecordPrefill()", "func refreshRecordWarmupSuggestions()")
assert refresh.index("guard !isRecordAmountInputPending") < refresh.index("prepareRecordPrefillSnapshot(")
assert "guard !categoryLockedByUser" in refresh
assert "guard !isCurrentRecordNoteGenerated" in refresh
cancel = section(model, "func cancelRecordInputAssistancePreparation()", "private func prepareRecordInputHistorySnapshot(")
assert "cancelPendingRecordAmountInput()" in cancel
manual_save = section(model, "func addManualRecord(", "func resolvedManualRecordDraft(")
assert manual_save.index("flushPendingRecordAmountInput()") < manual_save.index("resolvedManualRecordDraft(")

for start, end in (
    ("private func saveManualRecord()", "private func implicitScenePack"),
    ("private func handlePreviewQuickAction()", "private func handleFreePreviewQuickAction()"),
    ("private func handleFreePreviewQuickAction()", "private func resolveNoteRewriteDecision("),
    ("private func openFreeScenePackAngleSheet()", "private func preferredFreeScenePack()"),
    ("private func openNoteEditor()", "private func saveManualRecord()"),
    ("private func applyQuickNoteSuggestion(", "private var noteSection:"),
    ("private func applyScenePack(", "private var shouldPreserveUserNoteWhenChangingAngle"),
):
    body = section(view, start, end)
    assert "homeViewModel.flushPendingRecordAmountInput()" in body, start
    assert body.index("flushPendingRecordAmountInput()") < body.index("dismissKeyboard()"), start
save = section(view, "private func saveManualRecord()", "private func implicitScenePack")
assert save.index("flushPendingRecordAmountInput()") < save.index("currentTitleShouldBeUserEdited")
assert "onAngleAction: {\n                homeViewModel.flushPendingRecordAmountInput()" in view
assert "homeViewModel.cancelRecordInputAssistancePreparation()\n                    dismissKeyboard()" in view
assert "cancelPendingRecordAmountInput()" in cancel
assert 'Text(homeViewModel.inputAmount.isEmpty ? "0.00" : homeViewModel.inputAmount)' in view

raw_key = section(view, "private var previewComputationKey:", "private var previewDraftResolution:")
for forbidden in (".resolve(", "resolvedManualRecordDraft", "LocalStore", "homeViewModel.items", "previewDraftResolution"):
    assert forbidden not in raw_key, forbidden
for required in ("inputAmount", "inputTitle", "categoryLockedByUser", "selectedDate", "currentRecordGeneratedNoteContext",
                 "noteEditorExpanded", "lastDraftIntent", "previewLineWasRotated", "activeScenePack", "userNoteAnchorTitle",
                 "prefill?.title", "prefill?.category", "prefill?.emotionTag", "prefill?.source", "prefill?.confidence",
                 "weatherCompanionEnabled", "isDateInToday", "cachedSnapshot"):
    assert required in raw_key, required
assert "var calendar: Calendar = .current" in service
assert "private var cached: (key: Key, value: Value)?" in service
assert "cached.key == key" in service
for name, next_name, memo in (
    ("previewDraftResolution", "uncachedPreviewDraftResolution", "previewResolutionMemo"),
    ("emotionSceneContext", "uncachedEmotionSceneContext", "emotionContextMemo"),
):
    wrapper = section(view, f"private var {name}:", f"private var {next_name}:")
    assert wrapper.index("!homeViewModel.isRecordAmountInputPending") < wrapper.index(memo)
    assert "value(for: previewComputationKey)" in wrapper
life_key = section(view, "private var previewLifeMarkPreparationKey:", "private func preparePreviewLifeMark(")
assert life_key.index("!homeViewModel.isRecordAmountInputPending") < life_key.index("previewTier")
assert "for index in 0..<24 {\n            if Task.isCancelled { return [] }" in service
emotion_task = section(view, "private func prepareEmotionCandidates(", "private var previewLifeMarkText:")
assert emotion_task.index("!homeViewModel.isRecordAmountInputPending") < emotion_task.index("tabSession.emotionSelection = nil")
assert "selectedEntryMode == .manual" in emotion_task
print("amount_input_regression: OK (immediate invalidation, coalescing, action flush, preview memo and cancellation)")
