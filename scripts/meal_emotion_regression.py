#!/usr/bin/env python3
"""Source contracts for plain-meal emotion choices, not Swift runtime validation."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
service = (ROOT / "NativeDemoApp/Services/RecordDraftResolutionService.swift").read_text(encoding="utf-8")
model = (ROOT / "NativeDemoApp/ViewModels/HomeViewModel.swift").read_text(encoding="utf-8")
view = (ROOT / "NativeDemoApp/Views/RecordView.swift").read_text(encoding="utf-8")
item = (ROOT / "NativeDemoApp/Models/HomeItem.swift").read_text(encoding="utf-8")


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


helper = section(service, "private static func explicitMealAlternatives(", "static func next(")
for contract in (
    "context.category == .dining", "context.merchantBrandID == nil",
    "$0.titles.contains(title)", "anchor.isEmpty || meal.titles.contains(anchor)",
    "context.previewEmotionTag == meal.canonical", "context.automaticEmotionTag == meal.canonical",
):
    assert contract in helper, contract
rows = re.findall(r'\(\[([^\]]+)\],\s*"([^"]+)", \[([^\]]+)\]\)', helper)
assert len(rows) == 3
templates = section(model, "static func templates(for category:", "static func isCompatible(")
generic = section(item, "private static func shouldPreferRefinedTag(", "private static func correctedStoredEmotionTag(")
for (titles_source, canonical, variants_source), band in zip(rows, (0, 1, 3)):
    titles = set(re.findall(r'"([^"]+)"', titles_source))
    variants = re.findall(r'"([^"]+)"', variants_source)
    template_source = re.search(rf'case {band}: return \[([^\]]+)\]', templates).group(1)
    assert set(re.findall(r'"([^"]+)"', template_source)).issubset(titles)
    assert len(variants) == len(set(variants)) == 3
    assert f'return "{canonical}"' in item  # Existing default is still present.
    for variant in variants:
        assert variant not in titles and variant != canonical
        assert f'"{variant}"' not in generic  # Must not be collapsed to the default on display.
        assert not any(word in variant for word in ("上班", "下班", "加班", "热", "雨", "外地", "旅行"))

candidates = section(service, "static func candidates(", "private static func explicitMealAlternatives(")
assert "for index in 0..<24" in candidates and "if Task.isCancelled { return [] }" in candidates
assert "tag = context.previewEmotionTag" in candidates
assert "tag = mealAlternatives[index - 1]" in candidates
assert candidates.index("tag = mealAlternatives[index - 1]") < candidates.index("guard !tag.isEmpty")
for contract in (
    "seen.insert(tag).inserted", "isSubset(of: allowedRules)", "displayEmotionTag == tag",
    "legacyFactSignature(tag) == legacyFactSignature(automaticDisplayTag)",
    "rewardFactSignature(title: context.title, tag: tag)", "if result.count == 6 { break }",
):
    assert contract in candidates, contract
validation = section(service, "static func validatedTag(", "private static func legacyFactSignature(")
assert "candidates(for: selection.context).contains(selection.tag)" in validation
assert "selection.context.automaticEmotionTag == automaticEmotionTag" in validation
assert "preparedEmotionCandidates.count > 1" in view
assert "?? automaticEmotionTag" in model

print("meal_emotion_regression: OK (3 meal groups, 9 quick templates, unchanged selection safeguards; source checks only)")
