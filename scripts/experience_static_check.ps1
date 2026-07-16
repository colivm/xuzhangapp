$ErrorActionPreference = 'Stop'

$root = if ($PSScriptRoot) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }
Set-Location $root

function Assert-Pattern($Path, $Pattern, $Label) {
    $result = rg -n --encoding utf-8 $Pattern $Path -S
    if (-not $result) {
        throw "Missing: $Label"
    }
    Write-Output "OK  $Label"
}

function Assert-NoPattern($Path, $Pattern, $Label) {
    $result = rg -n --encoding utf-8 $Pattern $Path -S
    if ($result) {
        throw "Unexpected match for $Label`n$result"
    }
    Write-Output "OK  $Label"
}

function Assert-NoMultilinePattern($Path, $Pattern, $Label) {
    $result = rg -n -U --encoding utf-8 $Pattern $Path -S
    if ($result) {
        throw "Unexpected match for $Label`n$result"
    }
    Write-Output "OK  $Label"
}

function Assert-JsonFixtureIds($Path, $Ids, $Label) {
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    $items = $raw | ConvertFrom-Json
    $existing = @($items | ForEach-Object { $_.id })
    foreach ($id in $Ids) {
        if ($existing -notcontains $id) {
            throw "Missing fixture: $id"
        }
    }
    Write-Output "OK  $Label"
}

function Assert-SignalFixtureRoles($Path, $Label) {
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    $items = $raw | ConvertFrom-Json
    $signalItems = @($items | Where-Object { $_.category -eq 'signal' })
    foreach ($item in $signalItems) {
        if (-not $item.expected_title_role) {
            throw "Missing expected_title_role for fixture: $($item.id)"
        }
        if (-not $item.expected_picture_role) {
            throw "Missing expected_picture_role for fixture: $($item.id)"
        }
    }
    Write-Output "OK  $Label"
}

function Assert-AcceptanceMatrix($Path, $Ids, $Label) {
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    $items = $raw | ConvertFrom-Json
    $existing = @($items | ForEach-Object { $_.id })
    foreach ($id in $Ids) {
        if ($existing -notcontains $id) {
            throw "Missing acceptance case: $id"
        }
    }
    foreach ($item in $items) {
        if (-not $item.share_title_rule) {
            throw "Missing share_title_rule for acceptance case: $($item.id)"
        }
        if (-not $item.share_picture_rule) {
            throw "Missing share_picture_rule for acceptance case: $($item.id)"
        }
        if (-not $item.playback_background_rule) {
            throw "Missing playback_background_rule for acceptance case: $($item.id)"
        }
        if (-not $item.forbidden_copy -or $item.forbidden_copy.Count -eq 0) {
            throw "Missing forbidden_copy for acceptance case: $($item.id)"
        }
    }
    Write-Output "OK  $Label"
}

function Assert-PageCopySnapshots($Path, $Label) {
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    $items = $raw | ConvertFrom-Json
    foreach ($item in $items) {
        if (-not $item.id) {
            throw "Page copy snapshot missing id"
        }
        if (-not $item.surface) {
            throw "Missing surface for page copy snapshot: $($item.id)"
        }
        if (-not $item.source_paths -or $item.source_paths.Count -eq 0) {
            throw "Missing source_paths for page copy snapshot: $($item.id)"
        }
        if (-not $item.evidence_required -or $item.evidence_required.Count -eq 0) {
            throw "Missing evidence_required for page copy snapshot: $($item.id)"
        }
        if (-not $item.expected_copy -or $item.expected_copy.Count -eq 0) {
            throw "Missing expected_copy for page copy snapshot: $($item.id)"
        }
        if (-not $item.forbidden_copy -or $item.forbidden_copy.Count -eq 0) {
            throw "Missing forbidden_copy for page copy snapshot: $($item.id)"
        }

        $combined = ""
        foreach ($sourcePath in $item.source_paths) {
            if (-not (Test-Path $sourcePath)) {
                throw "Missing source path for page copy snapshot $($item.id): $sourcePath"
            }
            $combined += "`n" + (Get-Content -Raw -Path $sourcePath -Encoding UTF8)
        }

        foreach ($expected in $item.expected_copy) {
            if (-not $combined.Contains($expected)) {
                throw "Missing expected page copy for $($item.id): $expected"
            }
        }
        foreach ($forbidden in $item.forbidden_copy) {
            if ($combined.Contains($forbidden)) {
                throw "Forbidden page copy for $($item.id): $forbidden"
            }
        }
    }
    Write-Output "OK  $Label"
}

Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'enum ExperienceRuleCopy' 'shared copy layer'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'ocrQuotaExhaustedMessage|todayPlaybackFirstUseMessage|summaryQuotaFootnote' 'quota copy coverage'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'LifeStorySignalService' 'shared signal layer'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'playbackPrimarySignalLine|weeklyShareSignals' 'playback share helpers'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'primaryChoice\(|supportChoices\(|shouldForceLifeMarkLead|shouldForceSceneLead' 'signal hard rules'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'weeklyLead\(|sceneLead\(|softFallbackHeadline|softFallbackPictureLine|humanizedMoment' 'humanized share copy helpers'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'enum ShareCopyRole|shareTitleRole\(|sharePictureRole\(' 'share copy roles'
Assert-Pattern 'COPY_GOVERNANCE_PLAN_v0.1.md' 'COPY_HARD_RULE_DATA_FIRST|COPY_HARD_RULE_NO_OVERCLAIM|COPY_HARD_RULE_NO_FAKE_SCENE|COPY_HARD_RULE_NO_FAKE_EMOTION|COPY_HARD_RULE_NO_FAKE_MILESTONE' 'copy governance hard constraint'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'drawRain|drawTravel|drawLateCity|drawWarmDaily|drawFitness|drawSocial' 'visual profiles'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'supportLineText\(|chapterElementChips\(' 'playback chapter helpers'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'storyHeadlineText|storyPictureLine|storySignals|storyDetailRows' 'share card structure'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'storyFactSlip|storySceneLine|normalizedShareLine' 'share card signal helpers'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'storyHeroPanel|storyDataPanel' 'share card hierarchy'
Assert-Pattern 'NativeDemoApp/ContentView.swift' 'enum AppSurfaceRole|AppSemanticSurface|recordSurface|playbackSurface|traceSurface|metricSurface' 'semantic card surfaces'
Assert-Pattern 'NativeDemoApp/ContentView.swift' 'PurposefulCardButtonStyle|PressableCardFeedback|pressableCardFeedback' 'purposeful card interaction'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'recordSurface|playbackSurface|traceSurface|appSurface\(\.action' 'home semantic card usage'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'case firstRecord|firstRecordPromptRequestID|completeFirstRecordPromptAfterPlayback|finishFirstRecordPromptFlow|canStartTodayPlaybackNow' 'first record playback requires explicit choice'
Assert-NoPattern 'NativeDemoApp/Views/HomeView.swift' 'requestTodayPlayback\(allowsFirstUsePrompt: false\)' 'first record playback no automatic quota use'
Assert-Pattern 'NativeDemoApp/ContentView.swift' 'pendingPostSaveMemoryPrompts|pendingHomeLifeMarkRewardPrompts|presentNextPostSavePromptIfPossible|handleManualRecordSaved|isDateInToday\(savedItem\.createdAt\)' 'post save prompts use one queue'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'PostSavePromptBudgetPolicy|dailyStrongPromptLimit = 2|strongPromptCooldown: TimeInterval = 20 \* 60|PostSavePromptBudgetStore' 'post-save strong prompt budget policy'
Assert-Pattern 'NativeDemoApp/ContentView.swift' 'reserve\(\.firstPlayback\)|reserve\(\.sceneReward\)|reserve\(\.memoryPhoto\)' 'first playback reward and photo share the prompt budget'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testPostSavePromptBudgetLimitsFrequencyAndResetsNextDay' 'post-save prompt budget XCTest coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'HomeJourneySnapshot|HomeJourneyActionPolicy|hasOCRDrafts|hasUnplayedTodayRecords|weekTraceReady|monthTraceReady' 'home journey has one testable next-action policy'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'homeJourneyPrimaryAction|homeJourneyActionCard|onQuickRecord\(\.ocr\)|onNavigateMonthlyTrace' 'home primary action follows journey state'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'hasUnplayedTodayItems|markTodayPlaybackCompleted|hasCompletedCurrentWeekPlayback|hasCompletedCurrentMonthPlayback' 'journey progress distinguishes new records from completed playback'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testHomeJourneyActionPrioritizesUnfinishedWorkThenPlaybackAndTrace|testHomeJourneyActionKeepsRecordingAvailableAsSecondaryAction' 'home journey priority XCTest coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'RecordFlowVisibilityPolicy|showsOCRSideDoor|showsOptionalDetails' 'record flow optional surfaces use a testable policy'
Assert-Pattern 'NativeDemoApp/Views/RecordView.swift' 'RecordFlowVisibilityPolicy\.showsOCRSideDoor|recordDetailsFold|detailToggleButton\("\u6539\u65F6\u95F4"|amountAccessoryBar' 'record flow keeps save primary and details progressive'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testRecordFlowKeepsOCRAndOptionalDetailsOutOfThePrimarySavePath' 'record flow XCTest coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'TraceRangeContextPolicy|period\(for:|lifeRange\(for:' 'trace range mapping uses one testable policy'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'selectedPeriod = period|TraceRangeContextPolicy\.period\(for: range\)|traceLifeCardRange = range' 'trace life card and detail period stay synchronized'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceFilters.swift' 'TraceRangeContextPolicy\.lifeRange\(for: period\)|traceLifeCardRange = range' 'trace detail filter updates the visible life range'
Assert-NoMultilinePattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceChapterSnapshotCacheKey\([\s\S]{0,500}(customStartDate|customEndDate|selectedCategory)' 'life chapter cache does not depend on detail-only filters'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testTraceRangeContextUsesOneWeekMonthSource' 'trace range context XCTest coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'ReviewTaskIntent|case query|case compare|case backfill|presetCommand' 'review landing exposes three explicit supported tasks'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'ReviewTaskIntent\.allCases|reviewTaskButton|openReviewTask|\u73B0\u5728\u8981\u5B8C\u6210\u54EA\u4EF6\u4E8B' 'review page is task-first instead of duplicate journal-first'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' 'reviewOverview|previousStart|currentTotal|previousTotal|ReviewOverviewDay' 'review landing snapshot keeps current previous and daily facts off the render path'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'reviewOverviewHero|reviewOverviewDeltaBadge|reviewOverviewMetric|reviewTaskContext' 'review landing presents direct data before task actions'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'aiCommandTaskPicker|aiCommandTaskHeaderTitle|aiCommandInputActionTitle|selectReviewTask' 'review tasks have distinct in-sheet navigation and instructions'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'aiCommandQueryOverview|aiCommandComparisonOverview|aiCommandDraftMetric|\u6309\u5929\u5206\u5E03' 'review query compare and backfill results use dedicated visual summaries'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testReviewOverviewMakesCurrentAndPreviousSevenDaysDirectlyComparable' 'review overview window and trend XCTest coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'PlaybackMaturityPolicy|minimumWeekRecordCount = 3|minimumMonthRecordCount = 3|monthSurfaceStartDay = 25' 'playback recommendations require mature week or month data'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'PlaybackCompletionPolicy|showMemberPricing|primaryTitle' 'playback completion has one testable primary action'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'PlaybackMaturityPolicy\.weekIsReady|PlaybackMaturityPolicy\.monthIsReady' 'home recommendations use the shared playback maturity policy'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'handlePrimaryDoneAction|PlaybackCompletionPolicy\.primaryAction|PlaybackCompletionPolicy\.primaryTitle' 'week and month playback completion use the shared exit policy'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testPlaybackMaturityAndCompletionUseOnePrimaryRule' 'playback maturity and completion XCTest coverage'
Assert-Pattern 'NativeDemoApp/Services/MemberNudgePolicyService.swift' 'MemberNudgePresentationSource|MemberNudgeEligibilityPolicy|automaticCooldownUntil|explicitUserAction' 'automatic and explicit member entries use separate eligibility rules'
Assert-Pattern 'NativeDemoApp/Services/MemberNudgePolicyService.swift' 'state\.automaticCooldownUntil = cooldownUntil|state\.sceneCooldownUntil\[scene\] = cooldownUntil' 'dismissing an automatic member nudge applies cross-scene and scene cooldowns'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'source: \.automatic' 'today playback member nudge reserves through the shared policy'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'nudgeService\.markDismissed' 'today playback member nudge dismissal records cooldown'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testAutomaticMemberNudgesRespectBudgetWhileExplicitEntriesStayImmediate|LegacyState' 'member nudge budget and migration XCTest coverage'
Assert-NoPattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'triggerMemberNudge\(scene:' 'non-presented member nudges do not consume the automatic budget'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'NewUserProgressionStage|NewUserProgressionSnapshot|NewUserProgressionPolicy|recordFirstEntry|reviewTasks' 'new-user progression uses one testable stage policy'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'NewUserProgressionPolicy\.stage|progressionStage: progressionStage|case \.review' 'home follows the shared new-user progression stage'
Assert-Pattern 'NativeDemoApp/ContentView.swift' 'onNavigateInsight: \{ selectTab\(\.insight\) \}|onStartRecording:' 'home and empty review state route directly to their next task'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'allowsReviewTasks|insightEmptyLedgerState|resetInsightPreparationForEmptyLedger|\u5148\u8BB0\u4E0B\u4E00\u7B14\uFF0C\u518D\u6765\u590D\u76D8' 'empty review state avoids meaningless computation and tasks'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'insightEmptyLedgerState[\s\S]{0,1600}onShowMemberPricing' 'empty review state contains no member selling action'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testNewUserProgressionUnlocksOneNextStageWithoutEmptyReviewSelling' 'new-user progression XCTest coverage'
Assert-NoPattern 'NativeDemoApp/Views/InsightWebView.swift' 'showMonthlyInsightSheet = true|showTodayInsightSheet = true' 'review landing no longer opens duplicate daily or monthly journals'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testReviewTaskIntentsMapToSupportedExplicitCommands' 'review task intent XCTest coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'MemberLoginContinuationIntent|MemberLoginContinuationState|beginLogin\(for:|loginSucceeded\(\)|takeResumedIntent\(\)' 'member login continuation is explicit and one-shot'
Assert-Pattern 'NativeDemoApp/Views/MemberPricingView.swift' 'MemberAccountLoginSheet|requestMemberLogin\(for:|continueMemberActionAfterLogin|showMemberLoginSheet|loginContinuation\.takeResumedIntent' 'member purchase and restore route directly to login without auto-charge'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testMemberLoginContinuationResumesSelectedPlanExactlyOnce|testMemberLoginCancellationClearsIntentWithoutResumingPurchaseOrRestore' 'member login continuation XCTest coverage'
Assert-NoPattern 'NativeDemoApp/Views/MemberPricingView.swift' '\x{8BF7}\x{5148}\x{5728}\x{8BBE}\x{7F6E}\x{9875}\x{767B}\x{5F55}\x{8D26}\x{53F7}' 'member flow no longer sends users away to find login'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'SheetDismissRoute|playbackDismissRoute|todayRecordsDismissRoute|editingDismissRoute|memoryDetailDismissRoute' 'home sheet routes wait for dismissal'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'SheetDismissRoute|traceDetailDismissRoute|summaryPlaybackDismissRoute|handleSheetDismissRoute' 'trace and playback routes wait for dismissal'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' 'Self\.items\(in: \.week, from: items' 'insight computation avoids items name shadowing'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'return Candidate\(' 'playback candidate map closure returns explicitly'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'self\.aiCommandMemoryItemMatches\(item, command: command\)' 'AI memory lazy closure has explicit self capture'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceFilters.swift' 'customStartDateBinding|customEndDateBinding|selection: customStartDateBinding|selection: customEndDateBinding' 'split trace filters use explicit date bindings'
Assert-NoPattern 'NativeDemoApp/Views/StatsTraceFilters.swift' '\$custom(Start|End)Date' 'split trace filters do not reference unavailable projected values'
Assert-Pattern 'NativeDemoApp/Views/FocusedRecordEditor.swift' 'struct FocusedRecordEditor: View|PhotosPickerItem|WarmRecordDatePanel' 'focused record editor moved intact to its own file'
Assert-NoPattern 'NativeDemoApp/Views/StatsWebView.swift' '^struct FocusedRecordEditor: View' 'stats root no longer embeds focused record editor type'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'FocusedRecordEditor.swift in Sources|FocusedRecordEditor.swift \*/ = \{isa = PBXFileReference' 'focused record editor wired to app target'
Assert-Pattern 'NativeDemoApp/Views/Components/WarmRecordDatePanel.swift' 'struct WarmRecordDatePanel: View|monthStart\(for:|onSelectionChanged' 'shared date panel moved intact to component file'
Assert-Pattern 'NativeDemoApp/Views/RecordEditSheet.swift' 'struct RecordEditSheet: View|onAttachMemoryImages|showDeleteConfirmation' 'record edit sheet moved intact to its own file'
Assert-NoPattern 'NativeDemoApp/ContentView.swift' '^struct (WarmRecordDatePanel|RecordEditSheet): View' 'content root no longer embeds record editing types'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'WarmRecordDatePanel.swift in Sources|RecordEditSheet.swift in Sources' 'record editing split files wired to app target'
Assert-Pattern 'NativeDemoApp/Views/SettingsView.swift' 'accountSheetDismissRoute|settingsSheetDismissRoute|openMemberPricingFromAccountSheet|handleSheetDismissRoute' 'settings member routes wait for dismissal'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'DeferredRouteQueue<DeferredDismissRoute>|monthlyInsightDismissRoutes|aiCommandDismissRoutes' 'insight member routes wait for dismissal'
Assert-Pattern 'NativeDemoApp/Views/RecordView.swift' 'opensMemberPricingAfterScenePackDismiss' 'scene pack member route waits for dismissal'
Assert-NoMultilinePattern 'NativeDemoApp' 'dismiss\(\)[\s\S]{0,220}DispatchQueue\.main\.asyncAfter' 'no fixed delay after dismiss for routing'
Assert-NoMultilinePattern 'NativeDemoApp' '(showAICommandSheet|showTodayRecordsSheet|showTraceDetailSheet|showAccountSheet|showScenePackAngleSheet)\s*=\s*false[\s\S]{0,220}DispatchQueue\.main\.asyncAfter' 'no fixed delay after boolean sheet dismissal'
Assert-NoMultilinePattern 'NativeDemoApp' '(memoryPreviewItem|memoryDetailItem|editingItem|summaryPlayback|activeSettingsSheet)\s*=\s*nil[\s\S]{0,220}DispatchQueue\.main\.asyncAfter' 'no fixed delay after item sheet dismissal'
Assert-Pattern 'NativeDemoApp/ContentView.swift' 'recordTabSession|statsTabState|insightTabState|switch selectedTab' 'tab container owns resumable page state without eager pages'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' '@Binding var tabState: StatsTabState|scrollPosition\(id: \$tabState\.scrollAnchorID|scrollTargetLayout\(\)' 'trace filters and scroll context persist across tabs'
Assert-Pattern 'NativeDemoApp/Views/RecordView.swift' 'final class RecordTabSession|@ObservedObject var tabSession|resetAfterCommittedDraft\(\)' 'record draft UI state persists until commit'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'struct InsightTabState|@Binding var tabState: InsightTabState|scrollPosition\(id: \$tabState\.scrollAnchorID|insight-journal|insight-next-chapter' 'insight state and scroll context persist across tabs'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceSurface|appSurface\(\.action' 'trace semantic card usage'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'appSurface\(\.share|appSurface\(\.trace' 'share semantic card usage'
Assert-NoPattern 'NativeDemoApp' 'ThemedPressButtonStyle' 'obsolete simple press style'
Assert-NoPattern 'NativeDemoApp/Views' 'glassPanelWithTint|storyFactCardFill|storyCareCardFill' 'obsolete local card helpers'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'shareCareLine|shareCardPayload|shareSelection|shareTagTexts' 'legacy share card unified'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'shareProfile|profileAccent|profilePanelFill|profileAtmosphere' 'legacy share visual profiles'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'headlineSection|shareCarePanel|shareTagPanel' 'legacy share hierarchy'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'summaryMemberPitch\(|SummaryPlaybackMemberPitch' 'member playback pitch wiring'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'ocrSuccessMessage|ocrQuotaExhaustedMessage' 'ocr copy routing'
Assert-NoPattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' '\x{8F7B}\x{8F7B}|\x{5B89}\x{9759}\x{5730}|\x{6700}\x{60F3}\x{7559}\x{4E0B}\x{7684}|\x{503C}\x{5F97}\x{88AB}\x{7559}\x{4E0B}|\x{90A3}\x{6BB5}\x{5728}\x{5916}\x{5730}\x{7684}\x{65E5}\x{5B50}|\x{8FD8}\x{60F3}\x{7559}\x{4E0B}\x{6765}|\x{88AB}\x{7559}\x{4E86}\x{4E0B}\x{6765}|\x{4E00}\x{8D77}\x{7559}\x{4E86}\x{4E0B}\x{6765}' 'overclaimed share wording'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'accessibilityReduceMotion|periodic\(from: Date\(\), by: 1\.0 / 15\.0\)|rendersAsynchronously' 'playback animation performance guard'
Assert-NoPattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'private let [A-Za-z0-9_]+ = Self\.' 'no covariant Self in stored property initializer'
Assert-Pattern 'NativeDemoApp/Views/OCRConfirmSheet.swift' 'OCRImportSubmissionGate|interactiveDismissDisabled\(isCollectingImport\)|importTask\?\.cancel\(\)' 'OCR import single submission and dismissal guard'
Assert-Pattern 'NativeDemoApp/Views/OCRConfirmSheet.swift' 'await Task\.yield\(\)' 'OCR import yields without artificial delay'
Assert-Pattern 'NativeDemoApp/Views/OCRConfirmSheet.swift' 'onTitleCommit|@FocusState private var isTitleFocused|onDisappear\(perform: commitTitle\)' 'OCR draft title local composition state'
Assert-NoPattern 'NativeDemoApp/Views/OCRConfirmSheet.swift' 'onChange\(of: titleText\)' 'OCR draft title avoids per-keystroke persistence'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'func updateOCRDraftTitle\(id: UUID, title: String\)' 'OCR draft title commit path'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'UniqueFIFOQueue|DeferredRouteQueue|LatestRequestGate' 'testable interaction state models'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testPostSaveQueueIsFIFOAndRejectsDuplicateIDs|testDeferredRouteConsumesOnceAndLatestRepeatedRequestWins|testLatestRequestGateRejectsStaleCompletion|testOnlyOneOCRImportCanSubmitUntilReset|testTodayCommuteSlotsNeverIncludeFutureTime|testPlaybackQuotaChangesOnlyAfterExplicitStart' 'XCTest interaction regression coverage'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'NativeDemoAppTests|com\.apple\.product-type\.bundle\.unit-test|StateRegressionTests\.swift in Sources' 'XCTest target wiring'
Assert-Pattern 'NativeDemoApp.xcodeproj/xcshareddata/xcschemes/NativeDemoApp.xcscheme' 'NativeDemoAppTests\.xctest|TestableReference' 'shared scheme test action'
Assert-Pattern 'DATA_MIGRATION_DESIGN_v1.md' 'home_items_v1\.json|ledger-v2\.sqlite|images\.staging|sourceDigest|\u56DE\u6EDA\u65B9\u6848|\u4E91\u7AEF DTO' 'ledger migration design boundaries'
Assert-Pattern 'NativeDemoApp/Models/LedgerMigrationModels.swift' 'LedgerStoreManifest|LedgerRecordMetadataV2|LedgerImageAssetV2|LedgerMigrationCheckpoint|LedgerMigrationAudit' 'ledger migration model coverage'
Assert-Pattern 'scripts/validate_migration_samples.py' 'legacy_single_image|multi_image|ocr_draft|memory_context|migration_samples: OK' 'migration fixture coverage'
Assert-Pattern 'qa/migration_samples/expected_ledger_v2.json' 'amountMinorUnitTotal|amountValue|coverImageOrdinal|sha256|memoryContext|draftStatus' 'migration expected invariants'
Assert-Pattern 'NativeDemoApp/Models/HomeItem.swift' 'memoryImageReferences|hasCompleteReferences|setExternalMemoryImages|removeMemoryImage' 'home item persists stable image references without embedded bytes'
Assert-Pattern 'NativeDemoApp/Services/LocalStore.swift' 'pre_image_migration|preservePreImageMigrationBackup|prepareForPersistence|cleanupOrphans|hydrate' 'image migration backup hydration and orphan cleanup'
Assert-Pattern 'NativeDemoApp/Services/LedgerImageStore.swift' 'SHA256|cleanupOrphans|unsafeRelativePath|unavailable' 'file-backed image integrity and missing-image recovery'
Assert-Pattern 'NativeDemoApp/Views/Components/MemoryAttachmentViews.swift' 'photo.badge.exclamationmark|memoryImageFallback' 'missing image placeholder'
Assert-Pattern 'NativeDemoAppTests/LedgerImageStoreTests.swift' 'testImagesMoveOutOfJSONAndHydrateInOriginalOrder|testRemovingOneImageCleansOnlyItsOrphan|testMissingImageBecomesPlaceholderWithoutBreakingLedgerDecode' 'file-backed image XCTest coverage'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'LedgerImageStoreTests.swift in Sources' 'file-backed image tests wired to XCTest target'
Assert-NoPattern 'NativeDemoApp/Services/LedgerHomeItemsRepository.swift' 'imageStore\.hydrate\(' 'cold start reads ledger metadata without eager photo hydration'
Assert-Pattern 'NativeDemoApp/Services/LedgerImageStore.swift' 'metadataOnly\(|LedgerImageLoadVariant|CGImageSourceCreateThumbnailAtIndex|thumbnailRootURL' 'thumbnail and original image loading are explicit and on demand'
Assert-Pattern 'NativeDemoApp/Views/Components/MemoryAttachmentViews.swift' 'DecodedMemoryAttachmentImage|MemoryAttachmentImageCache|Task\.detached\(priority: \.utility\)|preparingForDisplay' 'photo views decode and cache images off the main actor'
Assert-NoMultilinePattern 'NativeDemoApp/Views/Components/MemoryAttachmentViews.swift' 'var body: some View[\s\S]{0,500}UIImage\(data:' 'photo view body does not decode image data on the main actor'
Assert-Pattern 'NativeDemoAppTests/LedgerImageStoreTests.swift' 'testMetadataOnlyStartupDefersOriginalAndCreatesThumbnailOnDemand' 'metadata-only startup and thumbnail XCTest coverage'
Assert-Pattern 'NativeDemoApp/Services/LedgerMetadataStore.swift' 'CREATE TABLE IF NOT EXISTS records|CREATE TABLE IF NOT EXISTS image_assets|BEGIN IMMEDIATE|record_fingerprint|func reconcile' 'incremental SQLite metadata persistence'
Assert-Pattern 'NativeDemoApp/Services/LedgerMetadataStore.swift' 'func applyChanges\(|readRecordStats\(|validateSchemaVersion\(' 'explicit record change-set SQLite persistence'
Assert-Pattern 'NativeDemoApp/Services/LedgerHomeItemsRepository.swift' 'func saveChanges\(|prepareForPersistence\(changes\.upserts\)|cleanupRecordOrphans|removeRecordFiles' 'change-set persistence touches only changed record images'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'saveHomeItemChanges|persistItems\(upserting:|persistItems\(deleting:|ledgerChanges\(from:' 'view model sends explicit ledger changes'
Assert-NoPattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'LocalStore\.saveHomeItems\(items\)' 'normal view-model mutations do not request full-ledger save'
Assert-Pattern 'NativeDemoAppTests/LedgerMetadataStoreTests.swift' 'testChangeSetWritesOnlyExplicitUpsertsAndDeletes' 'change-set SQLite XCTest coverage'
Assert-Pattern 'NativeDemoApp/Services/LedgerMetadataStore.swift' 'PRAGMA quick_check|func audit|activeStore: .metadataV2|markLegacyActive' 'metadata activation audit and rollback manifest'
Assert-Pattern 'NativeDemoApp/Services/LedgerHomeItemsRepository.swift' 'recoverFromActiveMetadataFailure|persistEmergencyLegacy|writesBlocked: true|legacyPayloadState' 'cold-start fallback and overwrite protection'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'localLedgerWritesBlocked|ensureLedgerWritesAllowed|loadHomeItemsResult|guard persistItems' 'view model blocks unsafe ledger mutations'
Assert-Pattern 'NativeDemoAppTests/LedgerMetadataStoreTests.swift' 'testMigrationActivatesSQLiteAndPreservesDuplicateImageOrder|testReconcileReportsOnlyInsertedUpdatedAndDeletedRows|testCorruptActiveDatabaseFallsBackToRetainedLegacyWithoutEmptyOverwrite|testUnreadableLegacySourcesBlockSaveAndPreserveOriginalBytes' 'incremental metadata XCTest coverage'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'LedgerMetadataStore.swift in Sources|LedgerHomeItemsRepository.swift in Sources|LedgerMetadataStoreTests.swift in Sources|libsqlite3.tbd in Frameworks' 'SQLite production and test target wiring'
Assert-Pattern 'scripts/validate_metadata_store_schema.py' 'metadata_store_schema: OK|duplicate_path|foreign_keys|record_upsert' 'SQLite schema executable validation'
Assert-NoPattern 'NativeDemoApp/Services/LocalStore.swift' 'persistHomeItemsData|prepareForPersistence\(items\)' 'LocalStore no longer rewrites the whole ledger JSON on normal saves'
Assert-Pattern 'CLOUD_PHOTO_BACKUP_BOUNDARY_v1.md' '\u91C7\u7528\u65B9\u6848 B|\u4E91\u7AEF\u53EA\u540C\u6B65\u8D26\u5355\u5B57\u6BB5|\u8BB0\u5FC6\u7167\u7247\u4EC5\u4FDD\u5B58\u5728\u672C\u673A|\.xuzhangbackup|cloudPhotoBackupSupported' 'cloud photo backup product boundary decision'
Assert-NoPattern 'NativeDemoApp/Services/LedgerSyncService.swift' 'memoryImage|imageReference|photo' 'cloud ledger DTO excludes local photos'
Assert-Pattern 'NativeDemoApp/Services/LedgerLocalBackupDocument.swift' 'FileDocument|\.package|ledger.json|manifest.json|cloudPhotoBackupSupported: false|unavailablePhotoCount' 'local backup package includes explicit photo boundary'
Assert-Pattern 'NativeDemoApp/Views/SettingsView.swift' 'fileExporter|\u5BFC\u51FA\u672C\u5730\u5907\u4EFD\uFF08\u542B\u53EF\u7528\u7167\u7247\uFF09|\u8BB0\u5FC6\u7167\u7247\u4E0D\u4E0A\u4F20|\u8BB0\u5FC6\u7167\u7247\u4ECD\u53EA\u5728\u672C\u673A|handleLocalBackupExportResult' 'settings exposes cloud boundary and local export'
Assert-Pattern 'NativeDemoAppTests/LedgerLocalBackupDocumentTests.swift' 'testBackupPackageContainsRefsOnlyLedgerAndAvailablePhotoFiles|testUnavailablePhotoIsReportedWithoutBreakingLedgerExport|testImageWithoutDataOrStableReferenceCannotClaimCompleteExport' 'local backup package XCTest coverage'
Assert-Pattern 'NativeDemoApp/Services/LedgerLocalBackupDocument.swift' 'LedgerLocalBackupImporter|validateLedgerShape|expectedDigest == actualDigest|LedgerLocalBackupRestorePlanner|backupItem\.updatedAt > localItem\.updatedAt' 'local backup import validates package and keeps newest record'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'func restoreLocalBackup|Task\.detached\(priority: \.userInitiated\)|currentItemsForFallback: plan\.mergedItems|LedgerLocalBackupRestorePlan' 'local backup restore commits before replacing in-memory ledger'
Assert-Pattern 'NativeDemoApp/Views/SettingsView.swift' 'fileImporter|prepareLocalBackupImport|confirmPreparedLocalBackupRestore|localBackupRestoreResultMessage|interactiveDismissDisabled\(isLocalBackupFlowBlocking\)' 'settings previews and explicitly confirms non-destructive restore'
Assert-Pattern 'NativeDemoAppTests/LedgerLocalBackupDocumentTests.swift' 'testExportImportRoundTripPreservesRecordOrderPhotosAndCover|testTamperedPhotoDigestRejectsImport|testOfficialExportWithUnavailablePhotoImportsAsMissingSlot|testDuplicateRecordIDRejectsImportEvenWhenManifestCountMatches|testManifestCountMismatchRejectsImport|testRestorePlanKeepsNewerLocalUpdatesOlderLocalAndInsertsMissing|testRestorePersistenceFailureDoesNotMutateLocalLedger' 'local backup import restore XCTest coverage'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'LedgerLocalBackupDocument.swift in Sources|LedgerLocalBackupDocumentTests.swift in Sources' 'local backup production and test target wiring'
Assert-NoPattern 'NativeDemoApp' '\u6362\u673A\u4E0D\u4E22|\u5B8C\u6574\u8D26\u672C\u5DF2\u5728\u4E91\u7AEF|\u4E91\u7AEF\u5907\u4EFD\u5DF2\u51C6\u5907\u597D' 'no ambiguous cloud photo backup promise'
Assert-NoPattern 'NativeDemoApp' 'nanoseconds: 80_000_000\)' 'no fixed 80ms operation delay'
Assert-Pattern 'NativeDemoApp/Views/Components/ComputationLoadingView.swift' 'accessibilityStatusValue|updatesFrequently' 'loading accessibility progress'
Assert-Pattern 'NativeDemoApp/Views/Components/ComputationLoadingView.swift' 'quietIndicator|repeatForever' 'lightweight computation loading motion'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'insightSnapshotNeedsRefresh|insightUpdatePillTask|prepareInsightIfNeeded' 'insight refresh state guard'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'weekTraceNeedsRefresh|monthTraceNeedsRefresh|clueTraceNeedsRefresh|traceUpdatePillTask|prepareTraceIfNeeded' 'trace refresh state guard'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'withTaskGroup|group\.addTask\(priority: \.userInitiated\)|TraceSnapshotComputation' 'trace computation leaves main actor'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceChapterPreparation|prewarmTraceChapter|prewarmRange|waitsForDesiredRange|\u6B63\u5728\u6574\u7406\u672C\u6708|\u6B63\u5728\u6574\u7406\u672C\u5468' 'trace builds visible chapter first and preserves fallback while prewarming'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceModels.swift' 'TraceLifePreparationPolicy|needsPrimaryPreparation|hasVisibleSnapshot|prewarmRange' 'trace preparation policy is testable'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testInitialEntryBuildsOnlyVisibleRangeThenPrewarmsTheOther|testSwitchingToMissingMonthKeepsWeekVisibleDuringPreparation|testPreparedVisibleRangeDoesNotRebuildWhileOtherRangeWarms' 'trace on-demand preparation regression coverage'
Assert-NoPattern 'NativeDemoApp/Views/StatsWebView.swift' 'preparedWeekSnapshot != nil && preparedMonthSnapshot != nil|if let weekSnapshot, let monthSnapshot' 'trace no longer blocks visible chapter on both snapshots'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' 'InsightComputationInput|weeklyPageSnapshot|monthlyPreparation|weeklyKeywordBubbles|MonthlyInsightPreparation' 'review aggregation uses immutable background input'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'AICommandEngine: @unchecked Sendable|aiCommandRunGate|withTaskGroup|engine\.buildAICommandResult|InsightComputationService\.weeklyPageSnapshot' 'review and AI command computation leave the main actor'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'InsightComputationService\.monthlyPreparation|MonthlyInsightPreparation|preparation\.snapshot|preparation\.monthItems' 'monthly review aggregation leaves the main actor'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testThousandRecordReviewAndAIComputationAreDeterministic|testLatestAIRequestGateNeverAcceptsOlderCompletion' 'one thousand record deterministic computation coverage'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'InsightComputationService.swift in Sources' 'insight computation service wired to app target'
Assert-NoPattern 'NativeDemoApp/Views/InsightWebView.swift' 'nanoseconds: 90_000_000' 'AI command has no artificial main-thread delay'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'insightContinueQuestionCard|openReviewTask|ReviewTaskIntent\.allCases|onOpenTrace' 'review page owns follow-up while trace owns full week and month chapters'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'AICommandComparisonPeriod|AICommandCategoryComparison|AICommandComparison' 'AI compare result keeps both periods and category deltas'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'aiCommandComparisonOverview|aiCommandComparisonPeriodCard|aiCommandComparisonEvidencePanel|aiCommandComparisonDifferenceSources|aiCommandComparisonRecordEvidence' 'AI compare result separates summary difference sources and raw evidence'
Assert-NoPattern 'NativeDemoApp/Views/InsightWebView.swift' 'Text\("\u4E3B\u8981\u5206\u7C7B\u53D8\u5316"\)' 'AI compare no longer duplicates category changes above the evidence switcher'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'AICommandComparisonEvidenceMode|case differences|case records|aiCommandComparisonEvidenceMode = \.differences|aiCommandShowsAllComparisonCategories = false' 'AI compare defaults and resets to difference sources'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'AICommandComparisonPresentationPolicy|changeKind|changeSharePercent|categoryDeltas\.reduce' 'AI compare difference presentation is deterministic and testable'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'AICommandComparisonPresentationPolicyTests|testChangeKindsUseExistingAmountsAndCountsWithoutFuzzyPairing|testChangeShareUsesAbsoluteCategoryMovementInsteadOfNetDifference' 'AI compare source labels and contribution share have XCTest coverage'
Assert-NoPattern 'NativeDemoApp/Views/InsightWebView.swift' '\u91CD\u65B0\u6574\u7406\u4E00\u6B21' 'AI command deterministic results do not offer a duplicate rerun action'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'continueAICommandQuestion|aiCommandInputFocusRequest|aiCommandFocusesInputAfterResultDismissal' 'AI command result continues by returning to the preserved input'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'aiCommandSecondaryLabel\(\x22\u7EE7\u7EED\u95EE\x22, systemImage: \x22arrow\.up\x22\)' 'AI command continue action uses an unambiguous upward icon'
Assert-NoPattern 'NativeDemoApp/Views/InsightWebView.swift' 'systemImage: \x22text\.cursor\x22' 'AI command continue action avoids the cursor glyph that resembles letters'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func continueAICommandQuestion\(\)[\s\S]{0,1000}runAICommand\(' 'AI command continue action does not repeat deterministic computation'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func continueAICommandQuestion\(\)[\s\S]{0,1000}aiCommandText\s*=' 'AI command continue action preserves the current instruction'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'AICommandComparisonSourceSummary|aiCommandComparisonSourceSummaries|aiCommandComparisonSourceSummaryChip|AICommandComparisonSourceVisualStyle' 'AI comparison exposes a semantic state overview and per-state visual style'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'systemImage: \x22plus\x22' 'AI comparison appeared state icon'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'systemImage: \x22minus\x22' 'AI comparison disappeared state icon'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'systemImage: \x22arrow\.up\.right\x22' 'AI comparison increased state icon'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'systemImage: \x22arrow\.down\.right\x22' 'AI comparison decreased state icon'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'systemImage: \x22equal\x22' 'AI comparison steady state icon'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'AICommandComparisonSourceRatioBar|GhostStyle|case dashed|showsZeroMarker|ghostAmount' 'AI comparison bars show disappearance zero markers and change tails'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private struct AICommandComparisonSourceRatioBar[\s\S]{0,5200}GeometryReader' 'AI comparison semantic bars avoid layout readers'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'AICommandSurfaceModifier|AICommandRatioBar|AICommandPressStyle' 'AI command owns local lightweight theme-aware rendering primitives'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'toolbarBackground\(AppColors\.bg, for: \.navigationBar\)' 'AI command navigation bar uses an opaque theme background'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'String\(tabState\.sourceRevision \?\? 0\)' 'AI command suggestion cache reuses the prepared ledger revision'
Assert-NoPattern 'NativeDemoApp/Views/InsightWebView.swift' 'WeatherMemoryBackdrop' 'AI command rain memory card has no animated blur backdrop'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandMemoryCard[\s\S]{0,4200}ultraThinMaterial' 'AI command memory card avoids live material compositing'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandComparisonScaleRow[\s\S]{0,1800}GeometryReader' 'AI command total comparison bar avoids layout readers'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandCategoryComparisonBar[\s\S]{0,1800}GeometryReader' 'AI command category comparison bar avoids layout readers'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandSuggestionsCacheKey[\s\S]{0,700}aiCommandItemsSignature\(homeViewModel\.items\)' 'AI command suggestion cache does not rescan the ledger during view rebuilds'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandPreviousRange' 'AI compare owns one previous-period range policy'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'value: -7, to: range\.start' 'AI week comparison aligns the same weekdays'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'matchingEnd' 'AI month comparison aligns the same elapsed month days'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'kind: \.compare,[\s\S]{0,700}bars: dailyBars' 'AI compare does not reuse the current-period-only chart'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testAICommandComparisonKeepsBothPeriodsAndCategoryChanges' 'AI comparison period and evidence XCTest coverage'
Assert-Pattern 'NativeDemoApp/ContentView.swift' 'onOpenTrace: \{ range in|statsTabState\.openLifeChapter\(range\)|selectTab\(\.stats\)' 'review routes back to the requested trace range'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceModels.swift' 'mutating func openLifeChapter|lifeCardRange = range|selectedPeriod = range == \.week \? \.week : \.month|scrollAnchorID = "trace-life-card"' 'trace range routing policy is testable'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceContinueInReviewButton|onOpenInsight\?\(\)' 'trace sends follow-up questions to review'
Assert-NoPattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceInsightQuestionChips\(insight\.questionChips\)' 'trace no longer answers follow-up chips in place'
Assert-NoPattern 'NativeDemoApp/Views/InsightWebView.swift' 'insightJournalCard\(snapshot:' 'review landing no longer duplicates the full weekly journal'
Assert-Pattern 'PRODUCT_TERMINOLOGY_v1.md' '## 1\.|## 2\.|## 3\.|## 4\.' 'canonical product terminology map'
$terminologyOutput = python scripts/terminology_lint.py
if ($LASTEXITCODE -ne 0) {
    throw "Terminology lint failed`n$terminologyOutput"
}
Write-Output $terminologyOutput
$membershipValueOutput = python scripts/membership_value_lint.py
if ($LASTEXITCODE -ne 0) {
    throw "Membership value lint failed`n$membershipValueOutput"
}
Write-Output $membershipValueOutput
$aiCapabilityOutput = python scripts/ai_capability_lint.py
if ($LASTEXITCODE -ne 0) {
    throw "AI capability lint failed`n$aiCapabilityOutput"
}
Write-Output $aiCapabilityOutput
$accessibilityOutput = python scripts/accessibility_lint.py
if ($LASTEXITCODE -ne 0) {
    throw "Accessibility lint failed`n$accessibilityOutput"
}
Write-Output $accessibilityOutput
$observabilityOutput = python scripts/observability_lint.py
if ($LASTEXITCODE -ne 0) {
    throw "Observability lint failed`n$observabilityOutput"
}
Write-Output $observabilityOutput
$themeCatalogOutput = python scripts/theme_catalog_check.py
if ($LASTEXITCODE -ne 0) {
    throw "Theme catalog check failed`n$themeCatalogOutput"
}
Write-Output $themeCatalogOutput
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'MembershipQuotaBaseline|monthlyInsightTrialTotal = 5|todayPlaybackDaily|weeklyJournal|lifetimeMonthChapter|monthlyLifeClue' 'existing quota constants have a testable frozen baseline'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testDisplaySimplificationDoesNotChangeExistingQuotaConstants|lifetimeMonthChapter, 10|monthlyInsightTrialTotal, 5' 'membership display changes preserve quota constants'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testUnsupportedAICommandDoesNotInventFactsOutsideTheLedger|unsupported#|AICommandRecognitionPolicyTests' 'AI command unsupported prompts cannot invent facts'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'AICommandRecognitionPolicy|lastRecordActions|ledgerScopeConcepts|guard:negatedWrite|guard:outsideSubject|hasLedgerScope' 'AI command recognition uses explicit intent, scope and trust guards'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'recognizeAICommand|resolvedLifeMarkIntent|buildUnsupportedRecognitionResult|aiCommandRecognitionDigestForTesting' 'AI command engine consumes one testable recognition result'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'func buildAICommandResult\(for command: String\)[\s\S]{0,1800}command\.contains' 'AI command result routing does not return to scattered raw contains checks'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'AICommandRecognitionPolicyTests|testNaturalQueryExpressionsShareTheSameSupportedIntent|testBackfillRequiresStrongAffirmativeWriteLanguage|testSubjectiveAndOutsideLedgerQuestionsDoNotBorrowWeakLedgerWords|testIntentPriorityKeepsReadOnlyTasksDistinct' 'AI command recognition synonym, write and drift boundaries have XCTest coverage'
Assert-Pattern 'AI_CAPABILITY_CONTRACT_v1.md' '\u8BC6\u522B\u53EF\u4FE1\u8FB9\u754C|\u5F3A\u5199\u5165\u52A8\u4F5C|\u4F4E\u7F6E\u4FE1|\u4E0D\u4F7F\u7528\u6A21\u7CCA\u7F16\u8F91\u8DDD\u79BB' 'AI capability contract documents tolerant but bounded recognition'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceSnapshotStore.swift' 'CategoryPreviewRow|groupedRows: \[HomeItem\.Category: \[HomeItem\]\]|categories\.sort' 'trace snapshot compiler-friendly category aggregation'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'preparingSummaryRange|summaryPlaybackTask|ProgressView' 'playback generation interaction feedback'
Assert-Pattern 'NativeDemoApp/Services/LifeMarkService.swift' 'aggregateCacheLock|cachedAggregates' 'life mark cache thread safety'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceLifeRangeKicker|traceLifeRangeTab\("\u672C\u5468", range: \.week\)|traceLifeRangeTab\("\u672C\u6708", range: \.month\)' 'trace week and month use explicit range controls'
Assert-NoPattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceLifeCardPagingGesture|simultaneousGesture\(traceLifeCardPagingGesture\)|traceLifeCardPagingBlocksTap' 'trace photo scrolling no longer competes with whole-card range paging'
Assert-NoPattern 'NativeDemoApp/Views/StatsWebView.swift' '\.blur\(radius: 18\)' 'trace photos avoid duplicate live blur rendering'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceLifeSliceRecordCanvas|case 0:|case 1:|case 2:' 'weekly photo count adaptive layout'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceLifeMonthDiaryRecordCover|traceLifeMonthDiaryCoverTitle|anchorItemIDs' 'monthly diary uses real record covers'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'routineVisualPenalty|isHighValueExperience' 'weekly memory anchor visual ranking'
Assert-Pattern 'NativeDemoApp/Services/LifeInsightService.swift' 'previousPeriodItems|earlyStartChangeSignal|lateReturnChangeSignal' 'trace personal baseline insight'
Assert-Pattern 'NativeDemoApp/Services/LifeInsightService.swift' 'guard !isRoutineScene\(strongest\.kind\)' 'trace routine-only insight suppression'
Assert-Pattern 'NativeDemoApp/Services/LifeInsightService.swift' 'repeatedRelationSignal|photoMemorySignal|isMeaningful' 'trace meaningful signal layers'
Assert-Pattern 'NativeDemoApp/Services/LifeInsightService.swift' 'denseDaySupportLine|theme: \.day|usedThemes' 'trace dense day evidence and follow-up diversity'
Assert-NoPattern 'NativeDemoApp/Services/LifeInsightService.swift' 'repeatedSceneDetail|questionChips\(' 'trace avoids legacy tautological insight path'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceInsightRhythmOverview|traceInsightThemeTitle|!insight\.isMeaningful|tracePhotoInsightRecord|traceSpecificInsightRecord' 'trace emotional insight presentation'
Assert-JsonFixtureIds 'qa/life_story_regression_fixtures.json' @(
    'rain_commute',
    'first_fitness',
    'drink_streak',
    'away_city',
    'weekend_social',
    'first_hobby_gear',
    'ordinary_drink_no_effort_tone',
    'milestone_wins_over_generic_scene',
    'scene_wins_over_generic_emotion',
    'generic_emotion_cannot_lead',
    'short_quote_can_lead',
    'night_route_with_soft_emotion',
    'life_mark_without_scene_stays_memory_like',
    'emotion_without_scene_stays_feeling_like',
    'voice_without_scene_stays_quote_like'
) 'signal regression fixtures'
Assert-SignalFixtureRoles 'qa/life_story_regression_fixtures.json' 'signal fixture roles'
Assert-AcceptanceMatrix 'qa/share_playback_acceptance_matrix.json' @(
    'rain_commute',
    'first_fitness',
    'drink_streak',
    'away_city',
    'weekend_social',
    'first_hobby_gear',
    'ordinary_drink_no_effort_tone',
    'weak_data_daily'
) 'share playback acceptance matrix'
Assert-PageCopySnapshots 'qa/page_copy_snapshots.json' 'page copy snapshots'

Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FIX-001-A|FIX-002-D|R-01|R-12|A11Y-03|PERM-03|device-audit|StoreKit' 'unified release and device verification matrix'
Assert-Pattern 'scripts/generate_release_fixtures.py' 'SUPPORTED_COUNTS = \(100, 1_000, 5_000\)|PNG_BASE64_VARIANTS|build_records|recordDigestSha256' 'deterministic release fixture generator'
Assert-Pattern 'scripts/validate_release_gate.py' 'validate_png|amountMinorUnitTotal|imageSequenceDigestSha256|audit_device_container|run_xcode_checks' 'release fixture and Xcode gate validator'
Assert-Pattern 'scripts/generate_real_photo_fixtures.py' '3024, 4032|4032, 3024|quality=90|manifest.json' 'deterministic real-photo fixture generator'
Assert-Pattern 'qa/real_photo_fixtures/manifest.json' 'qa_real_01.jpg|qa_real_02.jpg|qa_real_03.jpg|byteCount|sha256' 'real-photo fixture manifest'
Assert-Pattern 'scripts/validate_release_gate.py' 'validate_real_photo_fixtures|12_000_000|2_000_000|real_photo_fixture_set' 'real-photo fixture validation'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'QARealPhotos in Resources|QARealPhotos \*/ = \{isa = PBXFileReference' 'real-photo resources wired to app target'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'ReleaseFixturePhotoProfile|QA_RELEASE_PHOTO_PROFILE|-QAReleasePhotoProfile|subdirectory: "QARealPhotos"' 'real-photo debug launch profile'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'REAL-01|REAL-05|App Launch|Allocations/Memory Graph|p50 \u2264 1\.8s' 'real-photo cold-start scroll and memory matrix'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'REAL-06|FLOW-01|FLOW-21' 'product logic, theme, AI command recognition, comparison evidence, semantic states, follow-up action, performance and trace gesture device matrix'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testRealisticPhotoFixtureUsesPhoneSizedJPEGResources' 'real-photo XCTest resource coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'ReleaseFixtureLaunchConfiguration|ReleaseFixtureFactory|supportedCounts: Set<Int> = \[100, 1_000, 5_000\]' 'debug release fixture factory'
Assert-Pattern 'NativeDemoApp/Services/LocalStore.swift' 'QAReleaseFixtures|prepareReleaseFixtureStore|releaseFixtureSeededKey|isReleaseFixtureMode' 'isolated debug fixture storage and migration seed'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'guard !LocalStore\.isReleaseFixtureMode else \{ return \}' 'release fixture blocks accidental cloud writes'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testGeneratedReleaseFixturesMatchSwiftFactoryAndDecodeValidImages|testReleaseScaleMigrationPreservesCountAmountImagesOrderAndCover|testReviewAndAIStayDeterministicAtAllReleaseScales' '100 1000 5000 XCTest release coverage'
$releaseFixtureOutput = python scripts/validate_release_gate.py --phase fixtures
if ($LASTEXITCODE -ne 0) {
    throw "Release fixture validation failed`n$releaseFixtureOutput"
}
Write-Output $releaseFixtureOutput

Write-Output 'Static experience checks passed.'
