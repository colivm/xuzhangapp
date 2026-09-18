#!/usr/bin/env python3
"""Continuous record wiring contracts. This is not Swift/XCTest execution."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


vm = read("NativeDemoApp/ViewModels/HomeViewModel.swift")
view = read("NativeDemoApp/Views/RecordView.swift")
resolver = read("NativeDemoApp/Services/RecordDraftResolutionService.swift")
sheet = read("NativeDemoApp/Views/RecordEditSheet.swift")
focused = read("NativeDemoApp/Views/FocusedRecordEditor.swift")
tests = read("NativeDemoAppTests/StateRegressionTests.swift")

typing = section(vm, "func applyUserRecordTitle(", "var isCurrentRecordNoteGenerated:")
for token in ("recordExplicitIntent.writeNote",
              "pendingCategoryCorrectionFrom = nil", "recordGeneratedNoteContext = nil"):
    assert token in typing, token
assert "var categoryLockedByUser: Bool { recordExplicitIntent.categoryWasSelectedByUser }" in vm
assert "categoryLockedByUser =" not in vm, "a second mutable category lock can diverge from the event source"
selection = section(vm, "func selectCategory(", "func applyUserRecordTitle(")
assert "recordExplicitIntent.selectCategory(category)" in selection
generated = section(vm, "func applyGeneratedRecordTitle(", "func applyScenePackDraft(")
assert "writeNote(" not in generated and ".selectCategory(" not in generated
assert "preservingHandwrittenAnchor" in generated

observer = section(view, ".onChange(of: homeViewModel.inputTitle)", ".onChange(of: homeViewModel.recordInputAssistanceRevision)")
assert "applyUserRecordTitle" not in observer and "applyRecommendedCategory" not in observer
assert "markedTextRange" in view and "guard !isComposing else { return }" in view
assert "guard rawValue != lastReportedText else { return }" in view
preview = section(view, "private var uncachedPreviewDraftResolution:", "private var automaticPreviewEmotion:")
assert "homeViewModel.resolvedManualRecordDraft(" in preview
candidate = section(view, "private func requestHandwrittenPolishCandidate(", "private func adoptHandwrittenPolishCandidate(")
assert "applyGeneratedRecordTitle" not in candidate and "inputTitle =" not in candidate
assert "candidate.context == handwrittenPolishContext" in view
assert "preservingHandwrittenAnchor: true" in view

for editor in (sheet, focused):
    for token in ("CommittedRecordNoteField(", "categoryIntent.writeNote(title)",
                  "categoryIntent.selectCategory(category)", "RecordEditPolicy.intent(",
                  "RecordEditPolicy.proposedItem(", "onSave(proposedItem, editIntent)"):
        assert token in editor, token
    assert "updated.updatedAt = Date()" not in editor
    assert "@State private var initialBaseline: HomeItem" in editor
    assert "baseline: initialBaseline" in editor, "live row refresh must not move the form's initial edit baseline"
assert "categoryIsSettled: true" in sheet
assert "var updated = current" in sheet
assert "guard factsChanged else { return updated }" in sheet
assert "updated.userEditedCategory = nil" in sheet
assert "updated.categoryCorrectionFrom = nil" in sheet

update = section(vm, "func updateItem(", "func attachMemoryImage(")
early = update.index("if candidate == original { return true }")
assert update.index("RecordEditPolicy.applying") < early
for side_effect in ("ensureLedgerWritesAllowed()", "resolved.updatedAt = Date()", "items[idx] = resolved",
                    "persistItems(", "analyticsService.track", "refreshTodayPlayback()", "syncUpsertToCloud"):
    assert early < update.index(side_effect), side_effect
for path in ("NativeDemoApp/Views/HomeView.swift", "NativeDemoApp/Views/StatsWebView.swift"):
    assert read(path).count("updateItem(updated, editIntent: intent)") == 2, path

assert "category:explicitIntent" in resolver and "category:generatedDraft" in resolver
assert "hasExplicitRecordCategoryDecision" in section(vm, "func refreshRecordPrefill()", "func refreshRecordWarmupSuggestions()")
assert "respectsHandwrittenAnchor" in vm
for name in ("testShoppingThenNightSnackWinsBeforeSaveAndSurvivesDecodedEdits",
             "testNightSnackThenShoppingAndRepeatedReversalKeepLastSelection",
             "testGeneratedSocialAndConvenienceSentencesRetainChosenCategory",
             "testExistingManualChoiceCanBeSupersededByNewNoteWithoutFakeCorrection",
             "testOriginalUpdateKeepsPrecisionEmotionAndAllMetadata",
             "testEditorMergesOnlyChangedFieldsIntoLatestLedgerRow",
             "testNewBrandIntentAndOldBrandUnbinding"):
    assert name in tests, name

print("record_continuous_intent_regression: OK (input provenance, shared decisions, candidate isolation, both editors, no-op before side effects; source checks only)")
