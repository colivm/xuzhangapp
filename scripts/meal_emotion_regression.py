#!/usr/bin/env python3
"""Source contracts for semantic dining choices, not Swift runtime validation."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
service = (ROOT / "NativeDemoApp/Services/RecordDraftResolutionService.swift").read_text(encoding="utf-8")
model = (ROOT / "NativeDemoApp/ViewModels/HomeViewModel.swift").read_text(encoding="utf-8")
view = (ROOT / "NativeDemoApp/Views/RecordView.swift").read_text(encoding="utf-8")
item = (ROOT / "NativeDemoApp/Models/HomeItem.swift").read_text(encoding="utf-8")


def section(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


helper = section(service, "enum RecordEmotionCandidateSource {", "enum RecordDraftResolutionService {")
for contract in (
    "context.category == .dining", "context.merchantBrandID == nil",
    "MerchantBrandCatalog.matchBrand(in: context.title) == nil",
    "anchor.isEmpty || self.scene(in: anchor) == scene",
    "context.previewEmotionTag == canonical", "context.previewEmotionTag == context.automaticEmotionTag",
    "let scene = scene(in: context.title)", "DiningCopyEvidencePolicy.specificKind(in: text)",
    'rules.isSubset(of: ["meal", "drink", "convenience"])', "explicitMeals.count <= 1",
    'case .coffee: return .coffee', 'case .drink: return .drink',
    'matchingEmotionRuleIDs(in: context.previewEmotionTag).contains("meal")',
):
    assert contract in helper, contract
assert "explicitMealAlternatives" not in service
templates = section(model, "static func templates(for category:", "static func isCompatible(")
generic = section(item, "private static func shouldPreferRefinedTag(", "private static func correctedStoredEmotionTag(")
for name, band in (("breakfast", 0), ("lunch", 1), ("dinner", 3)):
    cues_source = re.search(rf'\(\.{name}, \[([^\]]+)\]\)', helper).group(1)
    cues = re.findall(r'"([^"]+)"', cues_source)
    variants_source = re.search(rf'case \.{name}: return \[([^\]]+)\]', helper).group(1)
    variants = re.findall(r'"([^"]+)"', variants_source)
    canonical = re.search(rf'case \.{name}: return "([^"]+)"', helper).group(1)
    template_source = re.search(rf'case {band}: return \[([^\]]+)\]', templates).group(1)
    titles = re.findall(r'"([^"]+)"', template_source)
    assert len(titles) == 3
    assert all(any(cue in title for cue in cues) for title in titles)
    assert all(f'"{title}"' not in helper for title in titles)  # No full-template whitelist.
    assert len(variants) == len(set(variants)) == 3
    assert f'return "{canonical}"' in item  # Existing default is still present.
    for variant in variants:
        assert variant not in titles and variant != canonical
        assert f'"{variant}"' not in generic  # Must not be collapsed to the default on display.
        assert not any(word in variant for word in ("上班", "下班", "加班", "热", "雨", "外地", "旅行"))

candidates = section(service, "static func candidates(", "static func next(")
assert "for index in 0..<24" in candidates and "if Task.isCancelled { return [] }" in candidates
assert "index == 0 ? context.previewEmotionTag" in candidates
assert "if result.count < 2" in candidates
assert candidates.index("for index in 0..<24") < candidates.index("if result.count < 2")
assert "for tag in RecordEmotionCandidateSource.alternatives(for: context)" in candidates
assert candidates.count("appendIfCompatible(tag)") == 2  # Both sources use identical guards.
assert candidates.count("if Task.isCancelled { return [] }") == 2
for contract in (
    "seen.insert(tag).inserted", "RecordSemanticLexicon.isTitle(tag, compatibleWith: context.category)",
    "isSubset(of: allowedRules)", "displayEmotionTag == tag",
    "legacyFactSignature(tag) == legacyFactSignature(automaticDisplayTag)",
    "rewardFactSignature(title: context.title, tag: tag)", "if result.count == 6 { break }",
):
    assert contract in candidates, contract
validation = section(service, "static func validatedTag(", "private static func legacyFactSignature(")
assert "candidates(for: selection.context).contains(selection.tag)" in validation
assert "selection.context.automaticEmotionTag == automaticEmotionTag" in validation
assert "preparedEmotionCandidates.count > 1" in view
assert "?? automaticEmotionTag" in model

for cue in ("雨天", "下雪", "加班", "上班", "晚归", "夜宵", "宵夜", "深夜", "凌晨", "夜市", "夜摊"):
    assert f'"{cue}"' in helper
assert '"雪"' not in helper and 'case .noodles: return .food("餐食")' in helper
for name in ("coffee", "drink", "food(let subject)"):
    variants_source = re.search(rf'case \.{re.escape(name)}: return \[([^\]]+)\]', helper).group(1)
    assert len(re.findall(r'"([^"]+)"', variants_source)) == 3
# New sources stay local and bounded; they cannot perform remote or history expansion.
for forbidden in ("URLSession", "UserDefaults", "homeViewModel", "DispatchQueue", "Task {"):
    assert forbidden not in helper

print("meal_emotion_regression: OK (semantic meal/coffee/drink/food sources, 9 quick templates, singleton-only fallback and shared save/fact guards; source checks only)")
