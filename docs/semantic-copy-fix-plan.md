# Semantic Copy P1 Fix Plan

## Goal

Fix the repeated semantic/copy regressions without patching one surface while leaving another surface broken.

Current P1 scope:

1. Manual input `烤鸭` must recommend `餐饮`, not `其他`.
2. `可口可乐` / ordinary drinks must not use narrow noon-meal copy.
3. `绝味鸭脖` must keep the `卤味小食` meaning across life mark, emotion tag, and playback copy.
4. Playback fallback must avoid generic copy for recognized food/drink notes.

Out of scope for this P1 pass:

- Large visual-system redesign.
- New animation system or heavier runtime effects.
- Rewriting all semantic services into one engine.

## Root Cause

The app has several semantic/copy entry points:

- Category recommendation: `CategoryRecommendService` + `RecordSemanticLexicon.keywordRules`.
- OCR category correction: `RecordSemanticLexicon.ocrKeywordRules`.
- Emotion tag: `NarrativeCopyResolver`, `HomeItem.refinedEmotionTag`, brand copy tiers.
- Life mark: `LifeMarkService`.
- Today playback: `HomeView.itemMomentBody` + `LifeSceneSemanticService`.
- Week/month playback and share: `PlaybackService` and support services.

The same concept was not represented consistently in all of these entry points. For example, `烤鸭` existed in OCR keywords but not in manual-input category keywords; drinks existed in emotion keywords but not enough in playback scene classification; `绝味` had a correct life mark but an odd brand emotion phrase.

## P1 Checklist

- [x] Add roast-duck terms to manual category keywords and emotion rules.
- [x] Add the same terms to minimal fallback lexicon in `HomeItem`.
- [x] Add roast-duck terms to life scene classification so playback sees it as food.
- [x] Replace odd `绝味` brand phrases such as the previous bag/convenience wording.
- [x] Make ordinary drinks win before meal copy in today playback.
- [x] Expand drink scene detection beyond coffee/tea to include `可乐`, `雪碧`, `汽水`, `水溶C100`, etc.
- [x] Add regression data for `烤鸭`, `可口可乐`, `水溶C100`, and `绝味鸭脖`.
- [x] Add/extend static checks for banned copy strings that caused this issue.

## Acceptance Cases

- Manual record: `烤鸭` + amount `25` => recommended category `餐饮`.
- Saved `烤鸭` playback line should be food-specific, not generic one-record fallback copy.
- `可口可乐` at noon should produce drink copy, not narrow meal copy.
- `水溶C100` should be treated as a drink, not a high-weight meal.
- `绝味鸭脖` emotion tag should be卤味/鸭脖 related, not generic bag/convenience wording.

## Visual Polish

The previous visual pass was too local. This P1 pass now extends the existing theme-aware interaction surface to:

- Today playback stage and film-strip selection cards.
- Week/month playback chapter stage.
- Weekly story image save entry and confirmation actions.
- Trace playback launch card.

Still intentionally deferred:

- A larger redesign of every list/card in the app.
- New heavy blur stacks, image layers, or long-running animation loops.
- Pixel-level visual QA on a real iOS simulator.
