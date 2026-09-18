#!/usr/bin/env python3
"""Build-386 record feedback contracts; not Swift execution or a latency benchmark."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


model = read("NativeDemoApp/ViewModels/HomeViewModel.swift")
view = read("NativeDemoApp/Views/RecordView.swift")
tier = read("NativeDemoApp/Models/RecordPreviewTier.swift")
emotion = read("NativeDemoApp/Services/RecordDraftResolutionService.swift")
prefill = read("NativeDemoApp/Services/RecordPrefillService.swift")

meta = section(view, "private var previewCardMeta:", "private var previewHint:")
for required in ("showsCategory", "categoryLockedByUser", "hasCurrentRecordCategoryRecommendation", "return previewMeta"):
    assert required in meta, required
assert "case .whisper: return hasResolvedCategory" in tier
assert "case .hidden: return false" in tier
current = section(model, "var hasCurrentRecordCategoryRecommendation:", "var recordLearningHint:")
for required in ("!isRecordAmountInputPending", "amount > 0", "amount == recordPrefillAmount",
                 "let result = recordPrefillResult", "canDescribeAdoptedRecommendation", "selectedCategory"):
    assert required in current, required
for forbidden in ("items.filter", "LocalStore", "MerchantBrandCatalog", "historySnapshot("):
    assert forbidden not in current, forbidden

history = section(model, "private func prepareRecordInputHistorySnapshot(", "private func prepareRecordQuickNoteHistorySnapshot(")
assert "includeQuickNoteHistory: false" in history
assert "recordInputHistoryRequestID == requestID" in history
assert history.index("recordInputHistorySnapshot = snapshot") < history.index("refreshRecordPrefill()")
quick = section(model, "private func prepareRecordQuickNoteHistorySnapshot(", "private func prepareRecordPrefillSnapshot(")
for required in ("recordInputHistorySnapshot?.key == key", "recordQuickNoteHistoryKey != key",
                 "recordQuickNoteHistoryPreparationKey != key", "group.addTask(priority: .utility)",
                 "RecordQuickNotePolicy.historicalTitles", "recordQuickNoteHistoryRequestID == requestID",
                 "recordQuickNoteHistoryPreparationTask?.cancel()", "recordQuickNoteHistoryRequestID = UUID()",
                 "history.key == key", "referenceDateEditedByUser: selectedDateEditedByUser"):
    assert required in quick, required
for start, end in (("func cancelRecordInputAssistancePreparation()", "private func prepareRecordInputHistorySnapshot("),
                   ("private func invalidateRecordInputHistorySnapshot()", "private func")):
    assert "cancelRecordQuickNoteHistoryPreparation()" in section(model, start, end)
refresh = section(model, "func refreshRecordPrefill()", "func cancelRecordInputAssistancePreparation()")
assert refresh.count("prepareRecordQuickNoteHistorySnapshot(key:") == 2, "resume cancelled optional history on re-entry"

scene = section(prefill, "private func dominantSceneHabit(", "private func sceneHabitTitle(")
assert scene.count("LifeSceneSemanticService.classify(") == 1
assert "LifeSceneSemanticService.dominantScene(" not in scene, "do not classify grouped rows a second time"

late = section(emotion, "private static func lateCommuteAlternatives(", "private static func scene(in")
for required in ('let canonical = "晚上这段通勤"', "context.merchantBrandID == nil",
                 'context.scenePackID == nil || context.scenePackID == "commute"',
                 "context.previewEmotionTag == canonical", "context.automaticEmotionTag == canonical",
                 'text.contains("通勤")', "HomeItem.refinedEmotionTag(", "isSameScene(context.title)",
                 "anchor.isEmpty || isSameScene(anchor)"):
    assert required in late, required
assert 'return ["晚间这段通勤", "这趟晚间通勤记下", "晚上的通勤记一笔"]' in late
for required in ("legacyFactSignature(tag) == legacyFactSignature(automaticDisplayTag)",
                 "rewardFactSignature(title: context.title, tag: tag)",
                 "context.item(emotionTag: tag).displayEmotionTag == tag", "candidates(for: selection.context).contains(selection.tag)"):
    assert required in emotion, required

print("record_preview_feedback_regression: OK (category display, deferred quick notes, cancellation, scene reuse, night commute)")
