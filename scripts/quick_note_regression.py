#!/usr/bin/env python3
"""Quick-note-only static contracts; does not substitute for Swift/XCTest."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
model = (ROOT / "NativeDemoApp/ViewModels/HomeViewModel.swift").read_text(encoding="utf-8")
view = (ROOT / "NativeDemoApp/Views/RecordView.swift").read_text(encoding="utf-8")
lexicon = json.loads((ROOT / "NativeDemoApp/Resources/RecordSceneLexicon.json").read_text(encoding="utf-8"))


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


policy = section(model, "enum RecordQuickNotePolicy {", "struct RecordPrefillPreparationKey")
history = section(policy, "static func historicalTitles(", "static func templates(")
for guard in ("item.draftMeta == nil", "item.createdAt >= start", "item.createdAt <= date",
              "value: -180", "days.count >= 2", "Task.isCancelled", "accepted.count == historyLimit",
              "canReuseHabitTitle", "isHabitTitle", "validateManualNote"):
    assert guard in history, f"history boundary missing: {guard}"
assert "static let historyLimit = 6" in policy
assert "static let displayLimit = 4" in policy
assert "personalized.prefix(2)" in policy

getter = section(model, "func noteSuggestions(", "func frequentRecordAmounts(")
assert "recordInputHistorySnapshot?.key == key" in getter
assert "recordQuickNoteTitlesByContext" in getter
for forbidden in ("items.filter", "items.sorted", "historicalTitles(", "ScenePackCopyPool", "LocalStore"):
    assert forbidden not in getter, f"unbounded quick-note getter: {forbidden}"

publisher = section(model, "private func prepareRecordInputHistorySnapshot(", "private func prepareRecordPrefillSnapshot(")
assert "group.addTask(priority: .utility)" in publisher
assert "recordInputHistoryRequestID == requestID" in publisher
assert "recordQuickNoteTitlesByContext != snapshot.quickNoteTitlesByContext" in publisher

handler = section(view, "private func applyQuickNoteSuggestion(", "private var noteSection:")
for required in ("canUseActiveQuickNoteScene", "quickNoteMatchesActiveScene(suggestion)",
                 "RecordQuickNotePolicy.isCompatible", "lastDraftIntent = .category",
                 "homeViewModel.applyGeneratedRecordTitle(normalized)",
                 "rememberUserNoteAnchor(homeViewModel.inputTitle)"):
    assert required in handler, f"quick-note click boundary missing: {required}"
for forbidden in ("homeViewModel.inputTitle =", "selectCategory(", "preferNoteSemantics",
                  "lastDraftIntent = .note", "activeScenePack =", "applyScenePackDraft("):
    assert forbidden not in handler, f"quick-note click expands intent: {forbidden}"
scene = section(view, "private var canUseActiveQuickNoteScene:", "private func applyQuickNoteSuggestion(")
for required in ("implicitScenePacksForCurrentAccess", 'pack.id == "family"', 'pack.id == "supply"',
                 'pack.id == "commute"', "RecordQuickNotePolicy.templates", "containsTravelKeyword"):
    assert required in scene, f"scene candidate guard missing: {required}"
note_section = section(view, "private var noteSection:", "// MARK: - Save Row")
assert "ForEach(quickNoteSuggestions" in note_section
assert "applyQuickNoteSuggestion(suggestion)" in note_section
assert "clearActiveScenePackIfManualNoteMovedAway()" not in note_section

# Verify every actual template against the bundled category keyword rules.
templates = section(policy, "static func templates(", "static func isCompatible(")
category_names = dict(dining="餐饮", transport="交通", shopping="购物", daily="日用",
                      entertainment="娱乐", lodging="住宿", health="健康", home="居家", social="人情", other="其他")
active = None
count = 0
for line in templates.splitlines():
    match = re.search(r"case \.(\w+):", line)
    if match:
        active = category_names[match[1]]
    if "return [" not in line:
        continue
    for title in re.findall(r'"([^"]+)"', line):
        matches = {rule["category"] for rule in lexicon["keywordRules"]
                   if any(word.lower() in title.lower() for word in rule["keywords"])}
        allowed = {active}
        if active == "日用":
            allowed.add("购物")
        if active == "购物" or active == "居家":
            allowed.add("日用")
        assert not matches or not matches.isdisjoint(allowed), (active, title, matches)
        assert len(title) <= 32
        assert not any(word in title for word in ("早班", "加班", "出差", "下班", "热饭", "和朋友", "住一晚"))
        count += 1
assert count == 42, count
print(f"quick_note_regression: OK ({count} neutral templates; source, history, scene and cache contracts)")
