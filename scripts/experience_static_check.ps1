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

function Assert-MultilinePattern($Path, $Pattern, $Label) {
    $raw = Get-Content -Raw -Path $Path -Encoding UTF8
    $matches = [regex]::IsMatch(
        $raw,
        $Pattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $matches) {
        throw "Missing: $Label"
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
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'PlaybackAuxiliarySignalPolicy|playbackLifeMarkLabel|playbackEmotionLabel|aggregate\.kind == \.scene|evidenceScore\(for: emotion|containsSensitiveText|playbackAuxiliarySignals\(from chapter' 'playback auxiliary signals restore only high-confidence life marks and emotion labels'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'PlaybackAuxiliarySignalPolicy\.preparedMetrics' 'week and month playback snapshots prepare auxiliary signals before rendering'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'presenceMetrics\.merge\(auxiliaryMetrics\)' 'weekly opening chapter receives only prepared auxiliary metrics'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'openingMetrics\.merge\(auxiliaryMetrics\)' 'monthly opening chapter receives only prepared auxiliary metrics'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'primaryChoice\(|supportChoices\(|shouldForceLifeMarkLead|shouldForceSceneLead' 'signal hard rules'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'weeklyLead\(|sceneLead\(|softFallbackHeadline|softFallbackPictureLine|humanizedMoment' 'humanized share copy helpers'
Assert-Pattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'enum ShareCopyRole|shareTitleRole\(|sharePictureRole\(' 'share copy roles'
Assert-Pattern 'COPY_GOVERNANCE_PLAN_v0.1.md' 'COPY_HARD_RULE_DATA_FIRST|COPY_HARD_RULE_NO_OVERCLAIM|COPY_HARD_RULE_NO_FAKE_SCENE|COPY_HARD_RULE_NO_FAKE_EMOTION|COPY_HARD_RULE_NO_FAKE_MILESTONE' 'copy governance hard constraint'
Assert-Pattern 'NativeDemoApp/Models/HomeItem.swift' 'weakWeekendDiningTags|weakWeekendRouteTags|weekendDiningTag\(for:' 'single-record emotion tags correct exact legacy system copy'
Assert-NoPattern 'NativeDemoApp/Services/RecordMemoryContextService.swift' 'weekendOutingLine' 'single-record emotion generation does not persist cross-record weekend stories'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' 'singleRecordTodayStoryLine' 'first-record home story uses the record fact instead of an emotion template'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'SingleRecordEmotionBoundaryTests|testParkingTagUsesFactCopyForNewAndStoredRecords|testWeekendDiningDoesNotPersistCrossRecordTransportStory|testStoredWeekendCombinationTagFallsBackToThisRecordOnly|testFirstRecordStoryUsesTimeAndRecordInsteadOfEmotionTemplate' 'single-record emotion and home story XCTest coverage'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'drawRain|drawTravel|drawLateCity|drawWarmDaily|drawFitness|drawSocial' 'visual profiles'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'supportLineText\(|chapterElementChips\(' 'playback chapter helpers'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'playbackAuxiliarySignals\(from: chapter\)|ViewThatFits\(in: \.horizontal\)|chapterElementChip\(|accessibilityLabel' 'playback auxiliary chips preserve the current style and adapt for narrow or accessible layouts'
Assert-NoPattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'PlaybackAuxiliarySignalPolicy\.preparedMetrics|LifeMarkService\.aggregates' 'playback rendering never recomputes auxiliary signals from the ledger'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testPlaybackRestoresHighConfidenceAuxiliarySignalsWithoutPuttingThemBackIntoNarration|testPlaybackAuxiliarySignalsRejectWeakAndSensitiveLabels|testPlaybackAuxiliarySignalsDeduplicateMainAndSupportCopy|testMonthPublishesAuxiliarySignalsOnlyOnOpeningChapter' 'playback auxiliary signal XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-54|生活线索|情绪标签|1,000 条账本' 'playback auxiliary signal device regression matrix'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativePlanningService.swift' 'LifeNarrativeSignalRole|case lead|case support|case mark|case evidence' 'narrative facts have explicit presentation roles'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativePlanningService.swift' 'recentLeadSignalIDs|score -= signal\.isStable \? 70 : 36|signal\.kind == \.stableMark' 'repeated stable signals cool down only in lead selection'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativePlanningService.swift' 'sourceRows\.filter \{ !isSensitive\(\$0\) \}|previousItems\.filter|privateHeadline' 'sensitive facts and evidence are removed before narrative grouping'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testStableCoffeeRemainsAMarkWithoutRepeatingAsLead|testCoffeeCanLeadAgainWhenTheCountReallyChanges|testSensitiveRecordCannotLeakThroughAMixedSceneEvidenceGroup|testOnlySensitiveRecordsUsePrivateFallbackWithoutPublishingEvidence' 'narrative repetition and privacy XCTest coverage'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'LifeNarrativePlanningService\.swift in Sources|LifeNarrativePlanningService\.swift \*/ = \{isa = PBXFileReference' 'narrative planner app target wiring'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-55|咖啡|主线|敏感' 'narrative role and privacy device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'case recordJournal|case recordMagazine|return \[\.recordSummary, \.recordJournal, \.recordMagazine\]|return \[\.singleMemory, \.recordJournal, \.recordSummary\]|return \[\.weeklyCollage, \.recordMagazine, \.recordSummary\]' 'share card exposes three safe built-in layouts for every prepared photo count'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'let narrativePlan = LifeNarrativeSignalPolicy\.makePlan|previousStableSignalIDs|narrativePlan: narrativePlan' 'weekly share payload prepares one evidence-based narrative plan'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'cleanRowVisual|posterObservationText|这一期还可以看到|payload\.narrativePlan\?\.summary' 'share card separates visual tiles from narrative and supporting observations'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'legacyScene = payload\.narrativePlan == nil|subtitleCandidates: \[String\?\] = payload\.narrativePlan == nil|if payload\.narrativePlan == nil' 'prepared narrative never falls back to legacy sensitive category copy'
Assert-NoPattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' '这张卡片怎么来的|系统按照片、类别和记录时间自动排版|系统按类别、日期和画面自动排版' 'share card does not explain its own layout instead of summarizing life'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testEveryAvailablePhotoCountGetsThreeSafeBuiltInLayouts|testWeeklySharePayloadPreparesNarrativeOnceAndCoolsRepeatedCoffeeLead' 'share template and prepared narrative XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-56|0/1/2/3 张|三个安全模板|不可变' 'share narrative and safe template device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'let narrativePlan: LifeNarrativePlan\?|previousDayItems|recentStableSignalIDs|narrativePlan: narrativePlan' 'today playback snapshot prepares one role-based narrative plan'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'leadIsRoutine|从早到晚，这些记录按发生顺序排在一起|closingTitle\(from: narrativePlan\)|closingBody\(recordCount:' 'today playback keeps routine marks out of opening and closing'
Assert-NoMultilinePattern 'NativeDemoApp/Views/HomeView.swift' 'private static func buildPlaybackMoments[\s\S]{0,1000}LifeMarkService[\s\S]{0,500}aggregates' 'today playback does not repeat a full life-mark aggregation while preparing moments'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'previousWeekRows|previousMonthRows|narrativeLeadItem|rolePlannedClosingLine' 'week and month playback consume one prepared role plan without changing chapters'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testRepeatedCoffeeStaysInTheWeeklyRepeatLayerWithoutTakingOpeningOrClosing|testRepeatedCoffeeDoesNotSurroundTodayPlaybackButRemainsInItemCards' 'today and week repeated-mark placement XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-57|今日回放|周记|月章|章节' 'role-planned playback copy device regression matrix'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativeEchoService.swift' 'case repeatRhythm|case returnAfterGap|case comparableChange|currentRows\.count >= 2' 'past echo is limited to three evidence-backed kinds with a sparse-data abstention'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativeEchoService.swift' 'scope == \.week, signalKind != \.coffee|abs\(delta\) >= 2, relativeChange >= 0\.5|historyByDistance\[1, default: \[\]\]\.isEmpty' 'past echo suppresses routine coffee and requires return or change evidence'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativeEchoService.swift' 'comparableRows|rowOffset <= elapsedDays|LifeNarrativeEchoPublicationPolicy|recentEchoIDs' 'past echo aligns elapsed periods and rejects cooled or stale results'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'LifeNarrativeEchoPolicy\.makeEcho|"supportLine": narrativeEcho\?\.line \?\? ""|narrativeEcho: narrativeEcho' 'week month and share consume at most one prepared echo'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'let narrativeEcho: LifeNarrativeEcho\?|closingBody\(recordCount: todayItems\.count, echo: narrativeEcho\)' 'today playback consumes its prepared echo without changing cards'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testContinuousCoffeeAloneDoesNotCreateAWeeklyEcho|testCoffeeCanCreateAnEchoForAComparableRealChange|testReturnRequiresARealGapAndCanBeCooledByStableEchoID|testRepeatRhythmNeedsThreeMatchingWeekdaysAndRejectsOldRevision|testMonthChangeUsesTheSameElapsedMonthDays|testEchoPublishesOnlyOneDeterministicCandidateAndExcludesSensitiveEvidence' 'past echo abstention threshold privacy determinism and revision XCTest coverage'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'LifeNarrativeEchoService\.swift in Sources|LifeNarrativeEchoService\.swift \*/ = \{isa = PBXFileReference' 'past echo service app target wiring'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-58|repeat|return|change|过去的回声' 'past echo device regression matrix'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift' 'redactedLabel|用户自写记录|有真实照片的记录|evidenceCount|itemIDsByFactID' 'narrative AI fact packs redact raw text photos and ledger identifiers'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift' 'citedFactIDs\.isSubset|citedFactIDs\.contains\(leadFactID\)|numbers\(in: combined\)|forbiddenTerms|expectedSourceRevision' 'narrative AI output validates evidence numbers inference terms and revisions'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift' 'LifeNarrativeAIPrecomputeCoordinator|latestRequestID|LifeNarrativeAIRewriteStore|LocalStore\.isReleaseFixtureMode|AIUsageLimiter' 'narrative AI precompute is cancellable cached optional and quota bounded'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'scheduleNarrativeAIPrecompute|narrativeAIPreparationRevision != homeDashboardRevision|1_500_000_000|LifeNarrativeAIPrecomputeCoordinator\.shared\.prepare' 'narrative AI starts only after a stable ledger revision'
Assert-NoPattern 'NativeDemoApp/Views/HomeView.swift' 'generateNarrativeRewrites|LifeNarrativeAIPrecomputeCoordinator\.shared\.prepare' 'today playback never starts or waits for remote narrative generation'
Assert-NoPattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'generateNarrativeRewrites|LifeNarrativeAIPrecomputeCoordinator\.shared\.prepare' 'summary playback and share save never start or wait for remote narrative generation'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'LifeNarrativeAIRewriteStore\.shared\.rewrite|narrativeEcho\?\.line \?\? narrativeRewrite\?\.summary' 'week month and share read validated narrative rewrites with local or echo priority'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'LifeNarrativeAIRewriteStore\.shared\.rewrite|if let rewrite \{ return "\\\(closing\)\\n\\\(rewrite\.summary\)" \}' 'today playback only reads a prepared validated rewrite'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testFactPackRedactsUserTextSensitiveRowsPhotosAndLedgerIDs|testRewriteValidationRequiresLeadEvidenceAndRejectsNewFacts|testRewriteStoreRejectsOldRevisionAndPublishesCurrentResult' 'narrative AI privacy validation and stale revision XCTest coverage'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'LifeNarrativeAIRewriteService\.swift in Sources|LifeNarrativeAIRewriteService\.swift \*/ = \{isa = PBXFileReference' 'narrative AI rewrite service app target wiring'
Assert-Pattern 'AI_CAPABILITY_CONTRACT_v1.md' '日/周/月轻总结|临时证据编号|播放、分享保存和模板切换不发请求' 'AI capability contract truthfully documents optional narrative rewrite'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-59|fact pack|evidence IDs|本地结果' 'narrative AI precompute and fallback device regression matrix'
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
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'RecordFlowVisibilityPolicy|showsOCRSideDoor\(hasAmountDraft:' 'record flow keeps the user-approved OCR side-door rule'
Assert-Pattern 'NativeDemoApp/Views/RecordView.swift' 'RecordFlowVisibilityPolicy\.showsOCRSideDoor\(hasAmountDraft: hasAmountDraft\)|ocrSideDoor|recordDateQuietActions|WarmRecordDatePanel\(selection: recordDateBinding\)|expandedDetails|amountAccessoryBar' 'record flow matches the frozen preview save conditional OCR date and optional editor order'
Assert-NoPattern 'NativeDemoApp/Views/RecordView.swift' 'recordDetailsFold|recordDetailToggleActions|Text\("\u8865\u5145\u7EC6\u8282"\)' 'record flow does not duplicate preview actions in a supplemental details fold'
Assert-Pattern 'NativeDemoApp/Views/Components/LifeEntryPreviewCard.swift' 'showsPrimaryAction|showAngleAction|showsFreePrimaryAction|showFreeAngleAction|quietAction\("\u81EA\u5DF1\u5199\u4E00\u53E5"' 'record preview action visibility logic remains owned by the preview card'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testRecordFlowShowsOCRUntilAnAmountDraftExists|testRecordSessionPersistsDraftUIUntilCommittedReset' 'record OCR visibility and editor session reset coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'TraceRangeContextPolicy|period\(for:|lifeRange\(for:' 'trace range mapping uses one testable policy'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'selectedPeriod = period|TraceRangeContextPolicy\.period\(for: range\)|traceLifeCardRange = range' 'trace life card and detail period stay synchronized'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceFilters.swift' 'TraceRangeContextPolicy\.lifeRange\(for: period\)|traceLifeCardRange = range' 'trace detail filter updates the visible life range'
Assert-NoMultilinePattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceChapterSnapshotCacheKey\([\s\S]{0,500}(customStartDate|customEndDate|selectedCategory)' 'life chapter cache does not depend on detail-only filters'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testTraceRangeContextUsesOneWeekMonthSource' 'trace range context XCTest coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'ReviewTaskIntent|case query|case compare|case backfill|presetCommand' 'review landing exposes three explicit supported tasks'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'ReviewTaskIntent\.allCases|reviewTaskButton|openReviewTask|\u73B0\u5728\u8981\u5B8C\u6210\u54EA\u4EF6\u4E8B' 'review page is task-first instead of duplicate journal-first'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' 'reviewOverview|previousStart|currentTotal|previousTotal|ReviewOverviewDay' 'review landing snapshot keeps current previous and daily facts off the render path'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'reviewOverviewHero|reviewOverviewDeltaBadge|reviewOverviewMetric|reviewTaskContext' 'review landing presents direct data before task actions'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'reviewOverviewMetrics|reviewOverviewMetricDivider|surfaceMuted\.opacity\(0\.62\)' 'review overview metrics share one lightweight visual strip'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'minHeight: 56|systemImage: "chevron\.right"|frame\(width: 40, height: 40\)' 'review task cards use a compact hierarchy without duplicate trailing action copy'
Assert-NoPattern 'NativeDemoApp/ContentView.swift' 'topBar' 'review and the other tabs use content space instead of a fixed title slab'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'aiCommandTaskPicker|aiCommandTaskHeaderTitle|aiCommandInputActionTitle|selectReviewTask' 'review tasks have distinct in-sheet navigation and instructions'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'aiCommandQueryOverview|aiCommandComparisonOverview|aiCommandDraftMetric|\u6309\u5929\u5206\u5E03' 'review query compare and backfill results use dedicated visual summaries'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testReviewOverviewMakesCurrentAndPreviousSevenDaysDirectlyComparable' 'review overview window and trend XCTest coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'minimumWeekRecordCount = 3|minimumWeekActiveDayCount = 2|minimumMonthRecordCount = 5|minimumMonthActiveDayCount = 3|monthSurfaceStartDay = 25' 'playback recommendations require enough records active days and period progress'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'homeRecommendationExplanation|接近月底时主动出现|周记会更完整' 'playback recommendation readiness has a user-facing explanation'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'PlaybackCompletionPolicy|showsMemberContinuation|return "完成"' 'playback completion keeps one natural primary action'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'PlaybackMaturityPolicy\.weekIsReady|PlaybackMaturityPolicy\.monthIsReady' 'home recommendations use the shared playback maturity policy'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'currentWeekActiveDayCount|currentMonthActiveDayCount|weekDays\.insert|monthDays\.insert' 'home journey snapshot prepares active-day maturity facts once'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'homeRecommendationExplanation|currentWeekActiveDayCount|currentMonthActiveDayCount' 'home explains recommendation readiness without a new blocking surface'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'reviewContinuationButton|memberContinuationButton|继续问' 'week and month completion keep review and membership as secondary actions'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'return LifeStorySignalService\.chapterSignals\(from: chapter\)' 'playback chapter element mapping returns explicitly after the support-line branch'
Assert-NoMultilinePattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'private func handlePrimaryDoneAction\(\)[\s\S]{0,400}onShowMemberPricing' 'playback primary completion action never opens membership'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'guard quotaStore\.weekRemaining\(isMember: false\) <= 1 else \{ return nil \}|guard quotaStore\.monthRemaining\(isMember: false\) <= 1 else \{ return nil \}' 'playback membership continuation only appears near quota exhaustion'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testPlaybackMaturityAndCompletionUseOnePrimaryRule' 'playback maturity and completion XCTest coverage'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'WeekTraceDiscoveryPolicy|shouldShowBadge|shouldMarkSeen|PlaybackMaturityPolicy\.weekIsReady' 'trace discovery badge reuses the shared week maturity policy'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'shouldShowCurrentWeekTraceBadge|markCurrentWeekTraceSeenIfEligible|currentWeekTraceSeenDefaultsKey|hasCompletedCurrentWeekPlayback' 'trace badge uses persisted seen state plus playback eligibility and completion'
Assert-Pattern 'NativeDemoApp/ContentView.swift' 'shouldShowCurrentWeekTraceBadge' 'stats tab badge reads the unified trace discovery state'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'markVisibleCurrentWeekTraceSeenIfEligible|traceViewMode == \.life|traceLifeCardRange == \.week|!weekTraceNeedsRefresh|snapshot\.coverFacts\.activeDays' 'only a visible prepared current-week trace consumes the discovery badge'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testWeekTraceDiscoveryUsesSharedMaturityAndSeparateSeenState|testTodayPlaybackStillPrecedesAReadyWeekTrace' 'trace badge maturity seen-state and home-priority XCTest coverage'
Assert-NoPattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'case weekSliceReady|case fiveRecordsNeverPlayed|refreshRouteGuidanceIfNeeded' 'legacy count-only weekly route guidance no longer competes with shared maturity'
Assert-NoPattern 'NativeDemoApp/Views/HomeView.swift' 'routeGuidanceContent|routeGuidanceBar|consumeRouteGuidance\(\.weekSliceReady\)' 'removed weekly home guidance cannot leave an unreachable badge state'
Assert-NoPattern 'NativeDemoApp/ContentView.swift' 'activeRouteGuidance' 'stats badge no longer depends on first-record route guidance'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-43|3 笔仅 1 个记录日不亮热点|生活＋本周的当前有效快照' 'trace discovery badge device regression matrix'
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
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'weekTraceNeedsRefresh|monthTraceNeedsRefresh|clueTraceNeedsRefresh|traceLoadingPresentationTask|prepareTraceIfNeeded' 'trace refresh state guard'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'withTaskGroup|group\.addTask\(priority: \.userInitiated\)|TraceSnapshotComputation' 'trace computation leaves main actor'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceChapterPreparation|prewarmTraceChapter|prewarmRange|desiredSnapshot|fallbackSnapshot' 'trace builds visible chapter first and preserves fallback while prewarming'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceModels.swift' 'TraceLoadingPresentationPolicy|refreshDelayNanoseconds: UInt64 = 150_000_000|\u6B63\u5728\u6574\u7406\u672C\u6708\u75D5\u8FF9|\u6B63\u5728\u6574\u7406\u672C\u6708\u7EBF\u7D22' 'trace loading policy distinguishes target and avoids fast refresh flicker'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'visibleTraceLoadingPresentation|traceLoadingOverlay|AppColors\.bg[\s\S]{0,120}opacity\(0\.82\)|presentation: \.card|scrollDisabled\(traceSwipeDragState != nil \|\| visibleTraceLoadingPresentation != nil\)' 'trace loading uses one centered viewport overlay and blocks stale content interaction'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'snapshotTransaction\.disablesAnimations = true|withTransaction\(snapshotTransaction\)|updateTraceLoadingPresentation\(nil, animated: true\)' 'trace snapshots publish without layout animation before overlay fade'
Assert-NoPattern 'NativeDemoApp/Views/StatsWebView.swift' 'showsTraceUpdatePill|traceUpdatePillTask|ComputationUpdatePill|presentation: \.page|waitsForDesiredRange' 'trace page has no duplicate content, pill, or card loading presentation'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'TraceLoadingPresentationPolicyTests|testInitialMonthTraceShowsOneImmediateAccuratePresentation|testRefreshWithExistingSnapshotDelaysTheSingleOverlay|testClueCopyDistinguishesMonthAndCustomRange' 'trace loading presentation XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-40|\u672C\u6708\u75D5\u8FF9|\u672C\u6708\u7EBF\u7D22|150ms|viewport' 'trace loading viewport overlay device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceModels.swift' 'TraceChapterCoverFacts|TraceChapterCoverPolicy|topCategoryRecordSharePercent|monthDayCounts|TraceMonthDiaryPolicy' 'trace week and month cover facts are deterministic snapshot data'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceSnapshotStore.swift' 'TraceChapterCoverPolicy\.make|coverFacts: coverFacts' 'trace cover facts are prepared with the chapter snapshot'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'snapshot\.coverFacts\.title|traceLifeMonthCoverPhoto|traceLifeMonthCoverHeatmap|traceLifeMonthCoverMetrics|TraceMonthDiaryPolicy\.anchors' 'trace week moment and month photo rhythm cover states are rendered'
Assert-NoPattern 'NativeDemoApp/Views/StatsWebView.swift' 'traceLifeMonthRoomBackdrop|\u8FD9\u4E2A\u6708\uFF0C\u751F\u6D3B\u6709\u4E86\u8F6E\u5ED3|\u6BCF\u4E00\u6761\u7EBF\u7D22\uFF0C\u90FD\u5728\u62FC\u51FA\u66F4\u5B8C\u6574\u7684\u751F\u6D3B|\u8FD9\u4E00\u5468\uFF0C\u6709\u4E00\u5E55\u88AB\u7559\u4E0B' 'trace cover no longer uses abstract room or passive generic headlines'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'TraceChapterCoverPolicyTests|testWeekCoverUsesRepresentativePhotoRecordAndFactualSupport|testMonthCoverExplainsCountShareAndBuildsRecordRhythm|testMonthWithoutPhotoUsesValidEmptyRhythmInsteadOfPhotoPlaceholder|testMonthDiaryExcludesEveryAnchorFromTheCoverRecord' 'trace week month cover policy XCTest coverage'
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
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'TextField\(placeholder, text: \$commandText' 'AI command input renders directly from the parent command binding'
Assert-NoPattern 'NativeDemoApp/Views/InsightWebView.swift' '@State private var draftText|_draftText\s*=|\$draftText' 'AI command input avoids a second local text state that can hide preset commands'
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
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'AICommandSuggestionPreparationInput|prepareAICommandSuggestionsIfNeeded|String\(tabState\.sourceRevision \?\? 0\)' 'AI command suggestions reuse one prepared ledger revision'
Assert-NoPattern 'NativeDemoApp/Views/InsightWebView.swift' 'WeatherMemoryBackdrop' 'AI command rain memory card has no animated blur backdrop'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandMemoryCard[\s\S]{0,4200}ultraThinMaterial' 'AI command memory card avoids live material compositing'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandComparisonScaleRow[\s\S]{0,1800}GeometryReader' 'AI command total comparison bar avoids layout readers'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandCategoryComparisonBar[\s\S]{0,1800}GeometryReader' 'AI command category comparison bar avoids layout readers'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' 'AICommandSuggestionSnapshot|static func aiCommandSuggestions|LifeMarkService\.aggregates' 'AI command suggestions are prepared as one immutable background snapshot'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandPresetSuggestions\(for task: ReviewTaskIntent\? = nil\)[\s\S]{0,900}(homeViewModel\.items|LifeMarkService\.aggregates|recentPositiveItems)' 'AI command suggestion rendering does not scan or aggregate the ledger'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandSuggestionPreparationKey\(\)[\s\S]{0,500}activeReviewTask' 'AI command suggestion preparation is shared by all review tasks'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testAICommandSuggestionsPrepareAllTasksFromOneImmutableSnapshot' 'AI command query compare and backfill suggestions share deterministic snapshot coverage'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' '\x{770B}\x{770B}\x{6700}\x{8FD1} 7 \x{5929}\x{7684}\x{8BB0}\x{5F55}|\x{627E}\x{6700}\x{8FD1}\x{91D1}\x{989D}\x{6700}\x{9AD8}\x{7684}\x{4E00}\x{7B14}|\x{627E}\x{627E}\x{6700}\x{8FD1}\x{6709}\x{6CA1}\x{6709}\x{91CD}\x{590D}\x{8D26}\x{5355}' 'AI query fallbacks stay lifestyle neutral'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' '\x{5BF9}\x{6BD4}\x{6700}\x{8FD1} 7 \x{5929}\x{548C}\x{524D} 7 \x{5929}\x{7684}\x{6D88}\x{8D39}|\x{5BF9}\x{6BD4}\x{672C}\x{5468}\x{548C}\x{4E0A}\x{5468}\x{7684}\x{6D88}\x{8D39}|\x{5BF9}\x{6BD4}\x{672C}\x{6708}\x{548C}\x{4E0A}\x{6708}\x{7684}\x{6D88}\x{8D39}' 'AI compare fallbacks stay period based instead of category based'
Assert-NoMultilinePattern 'NativeDemoApp/Services/InsightComputationService.swift' 'static func fallbacks\(for task: ReviewTaskIntent\)[\s\S]{0,900}(\x{4EA4}\x{901A}|\x{901A}\x{52E4}|\x{9910}\x{996E}|\x{5174}\x{8DA3}|\x{7231}\x{597D})' 'AI fixed fallbacks do not assume a category or lifestyle'
$aiSuggestionSource = Get-Content -Raw -LiteralPath 'NativeDemoApp/Services/InsightComputationService.swift'
$aiFallbackBlock = [regex]::Match(
    $aiSuggestionSource,
    'static func fallbacks\(for task: ReviewTaskIntent\) -> \[String\] \{(?<body>[\s\S]*?)\r?\n    \}\r?\n\}'
).Groups['body'].Value
if ($aiFallbackBlock -notmatch 'case \.backfill:[\s\S]*?return \[\]') {
    throw 'AI backfill must allow no recommendation when there is no evidence'
}
Write-Output 'OK  AI backfill may intentionally have no recommendation without evidence'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' 'categoryQuerySuggestions|records\.count >= 2 && \$0\.activeDays >= 2|categoryCompareSuggestions|distinctDays >= 2' 'AI category recommendations require repeated multi-day evidence'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' 'isStrongCommuteItem|scenePackId == \x22commute\x22|activeDays\.count >= 2' 'AI commute backfill requires strong evidence across multiple dates'
Assert-NoMultilinePattern 'NativeDemoApp/Services/InsightComputationService.swift' 'private static func shouldSuggestCommuteDraft[\s\S]{0,1400}amount <= 20' 'AI commute recommendations do not infer commuting from low-value transport'
Assert-Pattern 'NativeDemoApp/Services/InsightComputationService.swift' 'normalizedSuggestionWeatherKind|!rainyCommuteItems\.isEmpty' 'AI rainy commute lookup requires an actual rainy commute record'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func selectReviewTask\([\s\S]{0,1200}prepareAICommandSuggestionsIfNeeded\(\)' 'opening or switching an AI command task only reads the prepared suggestion cache'
$aiSuggestionViewSource = Get-Content -Raw -LiteralPath 'NativeDemoApp/Views/InsightWebView.swift'
if ($aiSuggestionViewSource -notmatch '\.onAppear[\s\S]{0,500}prepareAICommandSuggestionsIfNeeded\(\)' -or
    $aiSuggestionViewSource -notmatch '\.onChange\(of: homeViewModel\.items\)[\s\S]{0,500}prepareAICommandSuggestionsIfNeeded\(\)') {
    throw 'AI recommendation cache must be prepared before task entry and refreshed for ledger revisions'
}
Write-Output 'OK  AI recommendation cache is prepared before task entry and refreshed only for real inputs'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testAICommandSuggestionFallbacksStayNeutralAndAllowNoBackfill|testEmptyAndParkingOnlyLedgersDoNotInventCommuteRecommendations|testRepeatedRealCategoryEvidenceProducesFocusedSuggestionsOnly|testStrongCommuteEvidenceNeedsTwoDatesBeforeSuggestingBackfill|testCurrentRainNeedsAnActualHistoricalRainyCommuteForLookup|testRollingSevenDayComparisonCommandUsesThePreviousSevenDays' 'AI evidence recommendation and rolling comparison XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-49|\x{505C}\x{8F66}\x{8D39}|\x{975E}\x{901A}\x{52E4}|\x{96E8}\x{5929}\x{901A}\x{52E4}|\x{53EA}\x{8BFB}\x{7F13}\x{5B58}' 'AI evidence recommendation and cache device matrix'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'RecordInputHistorySnapshot|recordInputAssistanceRevision|prepareRecordInputHistorySnapshot|prepareRecordPrefillSnapshot|RecordInputAssistanceComputation\.historySnapshot|RecordInputAssistanceComputation\.prefillSnapshot' 'record input assistance uses ledger and draft driven snapshots'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'withTaskGroup|group\.addTask\(priority: \.utility\)|group\.addTask\(priority: \.userInitiated\)' 'record input history and prefill computation leave the main actor'
$recordInputSource = Get-Content -Raw -LiteralPath 'NativeDemoApp/ViewModels/HomeViewModel.swift'
$prefillKeyBlock = [regex]::Match($recordInputSource, 'struct RecordPrefillPreparationKey: Equatable \{(?<body>[\s\S]*?)\r?\n\}').Groups['body'].Value
$prefillInputBlock = [regex]::Match($recordInputSource, 'struct RecordPrefillPreparationInput: @unchecked Sendable \{(?<body>[\s\S]*?)\r?\n\}').Groups['body'].Value
if ($prefillKeyBlock -match '\blet now:\s*Date\b' -or $prefillInputBlock -notmatch '\blet now:\s*Date\b') {
    throw 'Record prefill now must belong to RecordPrefillPreparationInput, not its cache key'
}
Write-Output 'OK  record prefill now belongs to computation input instead of the cache key'
Assert-Pattern 'NativeDemoApp/Views/RecordView.swift' 'homeViewModel\.recordWarmupSuggestions|homeViewModel\.recordRecommendedCategory|task\(id: previewLifeMarkPreparationKey\)|RecordInputAssistanceComputation\.previewLifeMarkText' 'record view renders prepared input assistance and preview life mark snapshots'
Assert-NoPattern 'NativeDemoApp/Views/RecordView.swift' 'LifeMarkService\.aggregates|frequentRecordAmountSuggestions\(at:|recommendCategory\(for:' 'record view body does not aggregate or scan ledger assistance'
Assert-NoMultilinePattern 'NativeDemoApp/Views/RecordView.swift' 'private var previewLifeMarkText:[\s\S]{0,800}(homeViewModel\.items|LifeMarkService\.aggregates)' 'record preview life mark getter only reads a prepared snapshot'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'RecordInputAssistanceSnapshotTests|testHistoryKeyChangesOnlyForLedgerOrMeaningfulDateContext|testHistorySnapshotFeedsWarmupAndPrefillWithoutRescanningViewBody|testPreviewLifeMarkSnapshotIsDeterministicForTheSameDraftAndLedgerRevision' 'record input assistance snapshot XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-23|1,000 \u6761\u4E0B\u8F93\u5165|\u65E7\u8349\u7A3F\u7ED3\u679C\u4E0D\u77ED\u6682\u7528\u4E8E\u65B0\u91D1\u989D' 'record input assistance device regression matrix'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'HomeJourneyLedgerFacts|homeJourneyLedgerFacts|homeDashboardRevision|homeLifeMarkTextsByItemID|highConfidenceQuickRecordSuggestionSnapshot' 'home dashboard reuses ledger-derived facts and published snapshots'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' 'HomeLifeMarkSnapshot|HomeQuickRecordSnapshot|prepareHomeDashboardSnapshots|prepareHomeLifeMarkSnapshot|prepareHighConfidenceQuickRecordSnapshot|withTaskGroup|highConfidenceQuickRecordSuggestionForSnapshot' 'home life marks and commute suggestion use revision and time driven background snapshots'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'homeViewModel\.homeJourneyLedgerFacts|homeViewModel\.homeLifeMarkTextsByItemID\[item\.id\]|prepareHomeDashboardSnapshots' 'home rendering only reads prepared journey and line snapshots'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' 'todayPrimaryLine|homeTodayLifeMarkLine|LifeMarkService\.primaryLine' 'home today story consumes the revision-driven life mark snapshot'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' 'HomeLifeMarkRefreshPolicy|preservesVisibleLines|previousKey\.dayKey == nextKey\.dayKey|previousKey\.isMember == nextKey\.isMember' 'home life mark rows stay stable only within the same day and membership boundary'
Assert-NoMultilinePattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' 'var todayStoryNarrative:[\s\S]{0,1200}LifeMarkService\.aggregates' 'home today story no longer aggregates the full ledger during SwiftUI rendering'
Assert-NoPattern 'NativeDemoApp/Views/HomeView.swift' 'scheduleRecentSaveHighlight' 'home return does not replay an automatic saved-row glow'
Assert-NoMultilinePattern 'NativeDemoApp/Views/HomeView.swift' 'private var homeJourneyPrimaryAction[\s\S]{0,2400}(homeViewModel\.items|filteredItems\()' 'home journey action does not rescan the ledger during rendering'
Assert-NoMultilinePattern 'NativeDemoApp/Views/HomeView.swift' 'private func homeLifeMarkText\(for item: HomeItem\)[\s\S]{0,500}LifeMarkService\.aggregates' 'home visible record line getter does not aggregate the ledger per row'
Assert-NoMultilinePattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' 'var highConfidenceQuickRecordSuggestion:[\s\S]{0,300}highConfidenceCommuteSuggestion' 'home commute suggestion getter only reads the prepared snapshot'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'HomeDashboardSnapshotTests|testJourneyLedgerFactsReuseOneCommittedRecordSnapshot|testVisibleLifeMarksPrepareOnceForOnlyVisibleRecordIDs|testQuickRecordSnapshotKeyChangesOnlyWithLedgerOrMinuteBucket|testCommuteSuggestionKeepsExistingRulesOnImmutableLedgerInput' 'home dashboard snapshot XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-24|20 \u884C\u4E0D\u4EA7\u751F 20 \u6B21|\u5206\u949F\u65F6\u95F4\u6876' 'home dashboard snapshot device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'handleHomeScenePhaseChange\(phase\)|private func handleHomeScenePhaseChange\(_ phase: ScenePhase\)|phase == \.active|clearsStaleQuickRecord: true' 'home foreground immediately refreshes the current dashboard time bucket'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' 'HomeQuickRecordRefreshPolicy|shouldClearVisibleSuggestion|isLifecycleRefresh|clearsStaleQuickRecord' 'home lifecycle refresh clears stale actionable commute cards without timer flicker'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testForegroundResumeAdvancesTheQuickRecordKeyAcrossAnOvernightBoundary|testLifecycleRefreshClearsOnlyAStaleQuickRecordPresentation|testForegroundRefreshDoesNotRelaxCommuteWindowOrTodayDuplicateRules' 'home commute foreground and frozen-boundary XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-41|\u540E\u53F0\u8FC7\u591C|\u540C\u4E00\u5206\u949F|\u4E00\u952E\u8BB0\u901A\u52E4' 'home commute foreground refresh device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'let snapshot = BillPlaybackSheet\.makeContentSnapshot|struct ContentSnapshot|contentSnapshot\.todayItems|contentSnapshot\.playbackMoments|contentSnapshot\.playbackDuration' 'today playback uses one immutable content snapshot'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' '\.sheet\(item: \$playbackPresentation|TodayPlaybackPresentationPayload|TodayPlaybackPresentationPolicy\.accepts|TodayPlaybackPresentationPolicy\.consumesQuota' 'today playback snapshot sheet and quota use one atomic presentation payload'
Assert-NoPattern 'NativeDemoApp/Views/HomeView.swift' '@State private var showPlayback|@State private var playbackContentSnapshot|\.sheet\(isPresented: \$showPlayback' 'today playback no longer separates sheet visibility from content snapshot'
Assert-NoMultilinePattern 'NativeDemoApp/Views/HomeView.swift' 'private var todayItems: \[HomeItem\][\s\S]{0,300}(homeViewModel\.items|filter\s*\{|sorted\s*\{)' 'today playback item getter only reads the frozen snapshot'
Assert-NoMultilinePattern 'NativeDemoApp/Views/HomeView.swift' 'private var playbackMoments: \[PlaybackMoment\][\s\S]{0,250}(buildPlaybackMoments|LifeMarkService\.aggregates|homeViewModel\.items)' 'today playback moment getter does not rebuild chapters during animation'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'TodayPlaybackContentSnapshotTests|testSnapshotFreezesTodayItemsMomentsAndDurationForPlayback|testDenseSnapshotBuildsTimeBlocksOnceFromImmutableInput|testPresentationRequiresPreparedSnapshotAndOnlyAcceptsOneActivePayload|testValidEmptyDayCanPresentWithoutConsumingQuota' 'today playback immutable snapshot XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-25|\u64AD\u653E\u671F\u95F4\u53EA\u66F4\u65B0\u7D22\u5F15|\u4E0D\u91CD\u65B0\u7B5B\u9009' 'today playback immutable snapshot device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/MemberPricingView.swift' 'LifetimeArchivePreparationInput|LifetimeArchiveSnapshotComputation|homeDashboardRevision|withTaskGroup|group\.addTask\(priority: \.utility\)' 'member lifetime archive uses a revision driven background snapshot'
Assert-NoPattern 'NativeDemoApp/Views/MemberPricingView.swift' 'lifetimeArchiveItemsSignature|makeLifetimeArchiveSnapshot|refreshLifetimeArchiveSnapshot' 'member page no longer hashes or aggregates the full ledger during redraw'
Assert-NoMultilinePattern 'NativeDemoApp/Views/MemberPricingView.swift' 'private var memberProofLine: String[\s\S]{0,300}(homeViewModel\.items|filter\s*\{|Set\()' 'member proof line only reads the prepared archive snapshot'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'LifetimeArchiveSnapshotComputationTests|testArchiveSnapshotUsesCommittedRecordsAndPreservesExistingCopyRules|testArchiveEmptySnapshotDoesNotRequireLedgerScanningInViewBody' 'member lifetime archive snapshot XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-26|\u5957\u9910\u5207\u6362\u4E0D\u89E6\u53D1\u8D26\u672C\u626B\u63CF|\u65E7\u8BF7\u6C42\u4E0D\u8986\u76D6' 'member lifetime archive snapshot device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/SettingsView.swift' 'AccountMemoryStatsPreparationInput|AccountMemoryStatsComputation|scheduleAccountMemoryStatsRefresh|homeDashboardRevision|withTaskGroup|group\.addTask\(priority: \.utility\)' 'settings account statistics use a revision driven background snapshot'
Assert-NoPattern 'NativeDemoApp/Views/SettingsView.swift' 'private var accountMemoryStats: AccountMemoryStats|accountLongestRecordStreak|accountMonthKey|accountWeekKey' 'settings view no longer recomputes account statistics during redraw'
Assert-NoMultilinePattern 'NativeDemoApp/Views/SettingsView.swift' 'private var accountRowSummary: String[\s\S]{0,650}(homeViewModel\.items|filter\s*\{|Set\()' 'settings account summary only reads the prepared statistics snapshot'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'AccountMemoryStatsComputationTests|testAccountStatsReuseOneLedgerRevisionSnapshot|testAccountStatsEmptySnapshotKeepsZeroValues' 'settings account statistics snapshot XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-27|\u8D26\u53F7\u6458\u8981\u4E0E\u8D26\u53F7\u8BE6\u60C5\u5171\u7528|\u666E\u901A\u91CD\u7ED8\u4E0D\u7EDF\u8BA1' 'settings account statistics snapshot device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'TraceDetailListSnapshotKey|TraceDetailListPreparationInput|TraceDetailListSnapshotComputation|prepareTraceDetailListSnapshot|recordListContent\(snapshot: snapshot' 'trace detail list reuses one filter snapshot'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' '\.sheet\(item: \$traceDetailPresentation|TraceDetailPresentationPayload|traceDetailSheet\(initialSnapshot: presentation\.initialSnapshot\)|resolvedTraceDetailSnapshot' 'trace detail sheet receives its initial filter snapshot atomically'
Assert-NoPattern 'NativeDemoApp/Views/StatsWebView.swift' '@State private var showTraceDetailSheet|\.sheet\(isPresented: \$showTraceDetailSheet' 'trace detail no longer separates sheet visibility from filter snapshot'
Assert-NoMultilinePattern 'NativeDemoApp/Views/StatsWebView.swift' 'private var traceFilteredItemIDs: \[UUID\][\s\S]{0,650}(filteredItems|Dictionary\(grouping:|reduce\()' 'trace detail IDs and total do not rebuild the filter result'
Assert-NoMultilinePattern 'NativeDemoApp/Views/StatsWebView.swift' 'private func recordListContent\(fromTraceDetail:[\s\S]{0,1500}(Dictionary\(grouping: filteredItems|let groups = traceDayGroups)' 'trace detail rows render prepared day groups'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'TraceDetailListSnapshotComputationTests|testDetailSnapshotSharesItemsIDsTotalAndDayGroupsFromOneFilterPass|testDetailSnapshotKeyChangesOnlyForLedgerOrFilterInput|testPresentationCarriesInitialSnapshotAndRejectsDuplicateSheetRequest' 'trace detail list snapshot XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-28|ID\u3001\u603B\u989D\u548C\u6309\u65E5\u5206\u7EC4\u5171\u7528|\u7F16\u8F91\u5220\u9664\u8BED\u4E49\u4E0D\u53D8' 'trace detail list snapshot device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'customShareBackgroundImage|NormalizedShareBackground|normalizedShareBackground\(|customBackgroundImage: customShareBackgroundImage|customBackgroundImage: backgroundImage' 'share custom background keeps one decoded image cache'
Assert-NoMultilinePattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'private var customShareBackgroundCard:[\s\S]{0,2600}UIImage\(data: customShareBackgroundData\)' 'share background picker preview does not decode data during redraw'
Assert-NoMultilinePattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'private var lifeSlicePosterBackground:[\s\S]{0,6500}UIImage\(data: customBackground' 'share poster background does not decode data during redraw'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'ShareBackgroundDecodedImageTests|testNormalizedShareBackgroundReturnsDataAndReusableDecodedImage|testNormalizedShareBackgroundDownsamplesLargeImageOnce' 'share background decoded image XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-29|\u6837\u5F0F\u5207\u6362\u4E0D\u91CD\u590D\u89E3\u7801|\u5BFC\u51FA\u7ED3\u679C\u4E0D\u53D8' 'share background decoded image device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'PreparedWeeklyShareCardRenderInput|WeeklyShareCardImagePreparer|preparedImagesByAnchorID|isShareCardReadyToSave' 'weekly share export uses one prepared immutable render input'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'variant: \.original|exportMaxPixelSize = 2_880|Task\.detached\(priority: \.userInitiated\)' 'weekly share photos load and downsample off the main actor for export'
Assert-NoMultilinePattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'private func saveWeeklyStoryCard\([\s\S]{0,1800}Task\.yield' 'weekly share save never guesses photo readiness with a render delay'
Assert-NoMultilinePattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'private func posterImage\([\s\S]{0,1200}MemoryAttachmentThumbnail' 'weekly share export tree contains no asynchronous thumbnail loader'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'WeeklyShareCardPhotoPreparationPolicyTests|testResolutionKeepsSourceOrderAndCountsOnlyDecodedPhotos|testResolutionDowngradesAllMissingPhotosWithoutInventingAvailability|testResolutionIgnoresLoadedIDsOutsideTheLockedRequest' 'weekly share missing-photo downgrade XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-37|\u6B63\u5728\u52A0\u8F7D\u56FE\u7247|12MP|\u8FDE\u7EED\u70B9\u51FB\u4FDD\u5B58' 'weekly share atomic photo preparation device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'WeeklyShareCardTemplateCapabilityPolicy|case 0: return \.recordSummary|case 1: return \.singleMemory|default: return \.weeklyCollage' 'weekly share automatic templates follow actual photo capability'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'posterPeriodTitle|singlePhotoCaptionBadge|posterSummaryMetricText|\u4E2A\u8BB0\u5F55\u65E5' 'weekly share template uses factual period photo caption and useful metrics'
Assert-NoPattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'appStoreQRCodePlaceholder|posterQRCodePattern|\u4E8C\u7EF4\u7801\u9884\u7559\u4F4D' 'weekly share output contains no fake QR code'
Assert-NoPattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' '\u8FD9\u4E00\u5468\uFF0C\u4E00\u5F20\u7167\u7247' 'weekly share title no longer repeats photo quantity as the story'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'WeeklyShareCardTemplateCapabilityPolicyTests|testAutomaticTemplateFollowsTheNumberOfActuallyAvailablePhotos|testManualTemplateChoicesNeverOfferAPhotoHeavyStyleWithoutPhotos|testSensitivePhotoCaptionsStayCategoryNeutralInTheShareCard' 'weekly share template capability and privacy XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-38|0/1/2/3|\u4EFF\u4E8C\u7EF4\u7801|\u8BB0\u5F55\u65E5' 'weekly share consolidated template device regression matrix'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-39|\u6708\u7AE0\u6709\u7167\u7247/\u65E0\u7167\u7247|\u8BB0\u5F55\u65E5\u70ED\u529B|\u62BD\u8C61\u623F\u95F4\u63D2\u753B' 'trace week month three-state cover device regression matrix'
Assert-NoPattern 'NativeDemoApp/Views/HomeView.swift' 'Text\("🐱"\)' 'home pet no longer renders a system emoji'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'PixelPetAnimationView|petTapAnimationTrigger|accessibilityLabel\("\u5BA0\u7269\u52A9\u624B"\)' 'home pet uses the isolated pixel animation component'
Assert-Pattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'PetIdleFrames|PetTapFrames|PetSpeakFrames|interpolation\(\.none\)|scenePhase|accessibilityReduceMotion|isLowPowerModeEnabled|\.task\(id: animationRequest\)' 'pixel pet animation keeps assets crisp and lifecycle bounded'
Assert-Pattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'handledTapTrigger|_handledTapTrigger = State\(initialValue: tapTrigger\)|tapPending|followUpSequence' 'pixel pet consumes each tap once and does not replay after recreation'
Assert-Pattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' '_currentFrame = State\(initialValue: PixelPetSpriteSheet\.fallbackFrame\(\)\)' 'pixel pet has a synchronous stable first frame before its animation task starts'
Assert-Pattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'MovablePixelPetOverlay|HomePetOverlayPositionPolicy|HomePetOverlayPositionStore|dragActivationDistance: CGFloat = 8|highPriorityGesture\(dragGesture|onLongPressGesture\(minimumDuration: 0\.6' 'pixel pet uses a scroll-winning drag threshold with placement persistence and long-press hiding'
Assert-Pattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'dragCoordinateSpaceName|coordinateSpace\(name: Self\.dragCoordinateSpaceName\)|coordinateSpace: \.named\(Self\.dragCoordinateSpaceName\)' 'pixel pet drag samples against a viewport coordinate space that does not move with the pet'
Assert-Pattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'transaction\.disablesAnimations = true|withTransaction\(transaction\)' 'pixel pet drag tracking and final placement do not inherit layout animations'
Assert-NoPattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'coordinateSpace: \.local' 'pixel pet drag never measures against its own moving local coordinate space'
Assert-NoMultilinePattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'private func dragGesture[\s\S]{0,900}\.onChanged' 'pixel pet drag does not mutate ordinary state while the gesture is active'
Assert-Pattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'alignment: placement\.side\.alignment' 'pixel pet anchors its control to the selected viewport edge'
Assert-NoPattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'ZStack\(alignment: placement\.side\.alignment\)' 'pixel pet does not center a content-sized stack before expanding to the viewport'
Assert-NoPattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'simultaneousGesture\(dragGesture' 'pixel pet drag no longer competes equally with the parent vertical scroll view'
Assert-Pattern 'NativeDemoApp/Views/Components/PixelPetAnimationView.swift' 'minimumBottomInset|minimumTopClearance|clampedDragTranslation|committedPlacement|accessibilityAction\(named: "隐藏宠物"\)' 'pixel pet placement stays within safe viewport and remains accessible'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'MovablePixelPetOverlay|onHide: hidePetCompanion|settingsViewModel\.petCompanionEnabled = false|宠物已休息，可在“我的”里重新开启' 'home pet long press uses the existing setting and gives a restore path'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'HomePetOverlayPositionPolicyTests|testDefaultPlacementMatchesTheLegacyLowerRightAnchor|testTapJitterDoesNotQualifyAsADrag|testDragTranslationTracksViewportSamplesWithoutFeedbackOscillation|testDragCommitsToNearestEdgeAndKeepsVerticalPositionInBounds|testStoredPlacementNormalizesCorruptFractionsAndRestoresTheSide|testSmallViewportFallsBackWithoutProducingAnInvalidPlacement' 'pixel pet default anchor stable translation gesture threshold placement and persistence XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-53|viewport \x{5750}\x{6807}|\x{62D6}\x{52A8}\x{91C7}\x{6837}' 'pixel pet stable drag sampling device regression matrix'
Assert-Pattern 'NativeDemoApp.xcodeproj/project.pbxproj' 'PixelPetAnimationView.swift in Sources|PixelPetAnimationView.swift \*/ = \{isa = PBXFileReference' 'pixel pet component wired to app target'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'PixelPetAnimationPolicyTests|testEachSequenceKeepsEightValidatedFrameDurations|testNewTapTakesPriorityOverVisibleSpeakingBubble|testMotionPowerAndSceneBoundariesReturnStaticPlans' 'pixel pet animation policy XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-30|\u8FDE\u7EED\u5F00\u5173\u6C14\u6CE1 20 \u6B21|\u4E0D\u9010\u5E27\u6717\u8BFB' 'pixel pet animation device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'PetBubblePresentation|petBubbleDismissTask|petMessageRequestID|Task.sleep\(nanoseconds:|dismissPetBubble' 'pet bubble uses one cancellable lifecycle'
Assert-Pattern 'NativeDemoApp/Services/PetCompanionService.swift' 'PetCompanionMessagePolicy|recentMessageIDs|savedRecordCandidates|appendCurrentWeather|isSensitive' 'pet message policy prioritizes trusted context and recent deduplication'
Assert-NoPattern 'NativeDemoApp/Services/PetCompanionService.swift' 'rainyHome|weatherContextMessage|Double.random|randomElement' 'pet message policy avoids ungrounded random weather templates'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'PetCompanionMessagePolicyTests|testClickUsesCommuteAndCoffeeFactsBeforeCurrentRain|testSavedRecordUsesItsOwnWeatherInsteadOfCurrentWeather|testSystemWarmTagDoesNotBecomeAClaimAboutTheUser|testExplicitSafeUserLineRequiresUserEditedTitleAndSensitiveRecordsStayNeutral' 'pet trusted context XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-30|\u81EA\u52A8\u5173\u95ED|\u8FDF\u5230\u8BF7\u6C42' 'pet lifecycle and context device regression matrix'
Assert-Pattern 'NativeDemoApp/Services/PetCompanionService.swift' 'interactionHintDefaultsKey|PetCompanionInteractionHintPolicy|hotWeatherCare|rainyWeatherCare|coldWeatherCare|snowyWeatherCare|currentWeatherCareSuffix' 'pet companion provides one-time interaction guidance and bounded current-weather care'
Assert-Pattern 'NativeDemoApp/Services/PetCompanionService.swift' 'now\.timeIntervalSince\(snapshot\.ts\).*<= 60 \* 60|calendar\.isDate\(focusRecord\.createdAt, inSameDayAs: now\)|item\.category == \.dining && containsAny\(item\.title, coolingKeywords\)' 'pet current-weather and cold-drink claims require fresh same-day evidence'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testHotWeatherCoffeeAddsCareWithoutCallingCoffeeAColdDrink|testHotWeatherOnlyUsesColdDrinkCopyForExplicitDiningEvidence|testSavedSameDayCoffeeCanAddCurrentCareButHistoricalRecordCannot|testStaleWeatherDoesNotBecomeCurrentCare|testInteractionHintOnlyPresentsBeforeItHasBeenSeen' 'pet weather, beverage, historical and interaction-hint boundary XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-46|\u666E\u901A\u5496\u5561|\u5386\u53F2\u8865\u8BB0|\u9996\u6B21\u70B9\u51FB' 'pet trusted caring copy device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'padding\(\.top, 8\)' 'home keeps a lightweight inset after the fixed title slab is removed'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'pageHorizontalPadding: CGFloat = 8|pageMaxWidth: CGFloat = 520|frame\(maxWidth: Self\.pageMaxWidth\)' 'review main and empty states share one bounded wider viewport'
Assert-Pattern 'NativeDemoApp/Services/PetCompanionService.swift' 'PetCompanionAutomaticSpeechPolicy|maximumPresentationsPerSession = 3|pet_interaction_hint_seen_v2|interactionHintMessageIfNeeded|markInteractionHintPresented|idleMessage' 'pet proactive guidance and idle cadence are bounded and versioned'
Assert-NoMultilinePattern 'NativeDemoApp/Services/PetCompanionService.swift' 'func idleMessage[\s\S]{0,900}(requestWhenInUseAndRefresh|refreshWeatherInBackground)' 'automatic idle speech only reads cached weather'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'petAutomaticSpeechTask|pendingPetSavedMessage|cancelAutomaticPetSpeech|pausePetMessageFlow|resumePetMessageFlowIfPossible|homeViewModel\.todayItems' 'home owns one cancellable pet schedule and one pending saved-message slot'
Assert-MultilinePattern 'NativeDemoApp/Views/HomeView.swift' 'withAnimation\(\.easeInOut\(duration: 0\.24\)\)[\s\S]{0,300}if source == \.interactionHint \{\s+PetCompanionService\.shared\.markInteractionHintPresented\(\)' 'pet interaction guidance is marked only after visible presentation succeeds'
Assert-MultilinePattern 'NativeDemoApp/Views/HomeView.swift' 'petMessageRequestTask = nil\s+petMessageRequestID = nil\s+if pendingPetSavedMessage != nil \{\s+resumePetMessageFlowIfPossible\(\)' 'pending saved-record pet feedback outranks a late tap response'
Assert-NoMultilinePattern 'NativeDemoApp/Views/HomeView.swift' 'private func handlePetTap\(\)[\s\S]{0,2200}homeViewModel\.items' 'pet tap does not rescan the complete ledger'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testAutomaticSpeechRequiresAnUnblockedVisibleActiveHome|testAutomaticSpeechStartsWithTheInteractionHintThenUsesBoundedIdleCadence|testVoiceOverAutomaticSpeechUsesLongerDelays' 'pet proactive lifecycle and accessibility cadence XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-61|fixed title slab|proactive pet hint' 'global viewport and proactive pet device regression matrix'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativePlanningService.swift' 'narrativeValue|representativeness|isAdministrative|isEligibleLead|administrativeEvidenceSignal' 'narrative planner separates information gain narrative value representativeness and administrative evidence'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativePlanningService.swift' 'narrativeRows = rows\.filter|administrativeRows = rows\.filter|stableMarkSignals\([\s\S]{0,180}previous:' 'administrative rows stay outside narrative scene groups and stable marks require repeated evidence'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativePlanningService.swift' 'case \.receipt: return 18|case nil:[\s\S]{0,180}userEditedTitle == true \? max\(base, 82\) : 18' 'receipt and unqualified legacy photos cannot become narrative leads'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceModels.swift' 'let narrativePlan: LifeNarrativePlan|let narrativeRewrite: LifeNarrativeAIRewrite\?' 'trace chapter and clue snapshots carry the shared narrative plan and cached rewrite'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceSnapshotStore.swift' 'makeNarrativePlan|narrativeInsight|narrativeMarks|isAdministrativeMark|narrativeRewrite\?\.headline \?\? narrativePlan\.headline' 'trace snapshots project the shared plan cached rewrite and filtered marks'
Assert-NoPattern 'NativeDemoApp/Views/StatsTraceSnapshotStore.swift' 'AIReportService|URLSession|LifeNarrativeAIPrecomputeCoordinator|prepareFactPacks' 'trace snapshot construction never starts a remote rewrite request'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'snapshot\.narrative|snapshot\.chapterSummary|snapshot\.narrativePlan\.markLabels|narrativeRewrite\?\.headline|narrativeAIRewriteDidChange' 'life cards and clue hero render the shared plan and precomputed rewrite'
Assert-Pattern 'NativeDemoApp/Services/PlaybackService.swift' 'allowedKinds: \[\.userText, \.photo, \.change, \.structuredScene\]' 'week and month playback representative items read the upgraded narrative plan'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift' 'didChangeTraceRewrite|affectsTrace|rewrites\[rewrite\.key\] != rewrite|narrativeAIRewriteDidChange' 'only a genuinely changed week or month rewrite invalidates trace snapshots'
Assert-MultilinePattern 'NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift' 'func publish\(_ accepted:[\s\S]{0,1700}lock\.unlock\(\)[\s\S]{0,400}narrativeAIRewriteDidChange[\s\S]{0,260}func removeAll\(\)' 'rewrite invalidation posts after releasing the store lock and remains inside publish'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testAdministrativeChangeRemainsANeutralDataObservation|testQualifiedMomentPhotoCanBecomeAConcreteLead|testPhotoWithoutAQualifiedRoleStaysOutOfTheLead|testWeekLifeCardClueAndPlaybackShareTheSameLeadIdentity|testWeekClueKeepsAdministrativeBillsOutOfTheLifeMarkList|testTraceSurfacesConsumeCachedRewriteWithoutChangingTheSelectedFacts' 'cross-surface narrative identity administrative photo and cached rewrite XCTest coverage'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testWeekKeepsZeroOneTwoAndMatureChapterCounts|testMatureWeekSeparatesDistributionRecordAndReliableRepeat|testMonthKeepsSixRolesAndUsesSameDayComparison' 'playback chapter counts order and durations remain frozen'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-62|leadSignalID|固定账单|票据|相同润色不重复失效快照' 'unified narrative core device and performance regression matrix'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'Text\("\u70B9\u4EFB\u4E00\u6761\u53EF\u8C03\u6574"\)|todayRecordContextBadges|padding\(\.vertical, 11\)|VStack\(alignment: \.leading, spacing: 8\)' 'today full-record list uses the compact hierarchy and adaptive context badges'
Assert-NoPattern 'NativeDemoApp/Views/HomeView.swift' '\u5408\u8BA1 .*\u70B9\u4EFB\u4E00\u6761\u53EF\u8C03\u6574' 'today full-record list does not repeat count total and editing guidance'
Assert-Pattern 'NativeDemoApp/Views/HomeView.swift' 'height: 82' 'today full-record list keeps the readable photo thumbnail height'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-47|\u4ECA\u5929\u7559\u4E0B\u7684\u75D5\u8FF9|\u5DE6\u6ED1\u5220\u9664|82pt' 'today full-record compact-list device regression matrix'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' 'HomeEmptyTodayCopyPolicy|\u4ECA\u5929\u8FD8\u6CA1\u6709\u8BB0\u5F55|\u5F80\u5E38\u8FD9\u4E2A\u65F6\u95F4|\u6682\u65F6\u8FD8\u662F\u7A7A\u7684' 'home empty state is a calm fact with bounded historical context'
Assert-NoPattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' '\u4ECA\u5929\u53EF\u4EE5\u4ECE\u8FD9\u91CC\u5F00\u59CB|\u4E0D\u786E\u5B9A\u4E5F\u53EF\u4EE5\u53EA\u8F93\u91D1\u989D|\u4ECA\u5929\u4E5F\u5148\u7559\u4E00\u7B14|\u4E0D\u7528\u6574\u7406\u5F97\u5F88\u5B8C\u6574' 'home empty state does not pressure the user with recording instructions'
Assert-NoPattern 'NativeDemoApp/Services/PetCompanionCopy.swift' '\u4E0D\u7528\u786C\u51D1|\u60F3\u8D77\u4E00\u7B14\u518D\u5199' 'pet empty state offers company instead of bookkeeping instructions'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'HomeEmptyTodayCopyPolicyTests|testSuggestionAndSceneRemainObservationsInsteadOfRecordingCommands|testEmptyPetCopyOffersCompanyWithoutRepeatingRecordingInstructions' 'home and pet empty-copy XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-48|\u9996\u9875\u4ECA\u65E5\u5C0F\u8BB0|\u5BA0\u7269\u7A7A\u6001|\u4E0D\u50AC\u4FC3' 'home and pet calm empty-copy device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/Components/WarmRecordDatePanel.swift' 'RecordTimeSelectionPolicy|RecordTimePickerPresentation|WarmRecordTimePickerSheet|pickerStyle\(\.wheel\)|commitTime' 'record time picker uses a local wheel draft and one commit'
Assert-NoPattern 'NativeDemoApp/Views/Components/WarmRecordDatePanel.swift' 'timeStepper|setHour|setMinute' 'record time picker no longer requires single-step buttons'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceFilters.swift' 'showsTimeSelection: false' 'trace custom date filters remain day-only'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'RecordTimeSelectionPolicyTests|testLargeTimeChangeCommitsOneNormalizedDateWithoutChangingDay|testMidnightAndEndOfDayRemainOnTheSelectedDate|testDSTGapUsesAValidTimeOnTheSameLocalDay' 'record time boundary XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-32|22:55|08:05|DST' 'record time picker device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/MemberPricingView.swift' 'MembershipDetailPresentationPolicy|MembershipValueDefinition|membershipValueComparisonSection|memberUnlockedSummarySection|subscriptionActionsSection|memberDataBoundarySection' 'member detail uses one state-driven value definition'
Assert-NoPattern 'NativeDemoApp/Views/MemberPricingView.swift' 'benefitsSection|memberBoundarySection' 'member detail removes duplicate value surfaces'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'MembershipDetailPresentationPolicyTests|testProspectSeesOneSalesComparisonAndPricing|testSubscriptionSeesStatusUnlockedSummaryAndManagementWithoutSalesComparison|testLifetimeMemberGoesFromStatusToArchiveWithoutRepeatedValueCards' 'member detail state XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-33|StoreKit|Product ID' 'member detail identity and StoreKit device regression matrix'
Assert-Pattern 'NativeDemoApp/Services/LifeMarkService.swift' 'AICommandSemanticFacet|weatherCommuteQueryIntent|supportsNounPhraseQuery|querySemanticText|facetMatches|away_spending' 'AI command trusted semantic facets'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'allowsHighConfidenceNounQuery|action:nounQuery|score:trustedFacet' 'AI command query task accepts trusted noun phrases'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'reviewTaskIntent: activeReviewTask|decision.intent != \.commuteDraft|candidate.supportsNounPhraseQuery|evidenceLabel' 'AI command keeps task prior and write boundary separate'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'AICommandTrustedSemanticFacetTests|testQueryTaskAcceptsTrustedWeatherCommuteNounPhrases|testBackfillTaskDoesNotTurnTheSameNounPhraseIntoAWrite|testHotCommuteRequiresBothStructuredWeatherAndCommuteEvidence|testInterestConsumptionRequiresAConcreteInterestObjectOrActivity|testWeakEmotionAndValuePhrasesRemainOutsideLedgerFactQueries' 'AI trusted facet XCTest coverage'
Assert-Pattern 'AI_CAPABILITY_CONTRACT_v1.md' '\u9AD8\u6E29\u901A\u52E4|\u7231\u597D\u7C7B\u6D88\u8D39|\u6696\u8BED\u6C14|\u5DF2\u8BC6\u522B\u4F46\u6CA1\u6709\u8BB0\u5F55' 'AI trusted facet capability contract'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-34|hot/cold/rain/snow|\u96F6\u5019\u9009\u96F6\u5199\u5165' 'AI trusted facet device regression matrix'
Assert-Pattern 'backend/src/auth.js' 'ACCESS_TOKEN_TTL_SECONDS = 90 \* 24 \* 60 \* 60|expiresIn: ACCESS_TOKEN_TTL_SECONDS' 'backend access tokens use the reviewed 90-day lifetime'
$authTokenTTLOutput = node backend/scripts/verify-auth-token-ttl.mjs
if ($LASTEXITCODE -ne 0) {
    throw "Auth token TTL verification failed`n$authTokenTTLOutput"
}
Write-Output $authTokenTTLOutput
$nudgePolicyOutput = node backend/scripts/verify-nudge-policy.mjs
if ($LASTEXITCODE -ne 0) {
    throw "Backend nudge policy verification failed`n$nudgePolicyOutput"
}
Write-Output $nudgePolicyOutput
Assert-Pattern 'NativeDemoApp/Services/AuthService.swift' 'CloudSessionFailurePolicy|statusCode == 401|CloudSessionInvalidationPolicy|cloudSessionDidExpire|CloudSessionInvalidationService' '401 invalidates the stale cloud session without changing sync DTOs'
Assert-Pattern 'NativeDemoApp/ViewModels/SettingsViewModel.swift' 'publisher\(for: \.cloudSessionDidExpire\)|invalidateCloudSessionIfUnauthorized|applyExpiredCloudSessionState' 'settings reflects server-rejected sessions as logged out'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'CloudSessionFailurePolicy\.shouldInvalidateSession|CloudSessionInvalidationService\.invalidate\(\)|CloudSessionInvalidationService\.userMessage' 'manual and automatic ledger sync surface expired sessions'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'CloudSessionExpirationPolicyTests|testOnlyUnauthorizedHTTPResponsesInvalidateTheCloudSession|testSessionInvalidationPreservesLocalPreferencesAndClearsOnlyAccountState' 'cloud session expiration XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-36|90 \u5929|401|JWT_SECRET' 'cloud session expiration device regression matrix'
$petImageSets = @('PetIdleFrames', 'PetTapFrames', 'PetSpeakFrames')
foreach ($petImageSet in $petImageSets) {
    $imageSetPath = "NativeDemoApp/Assets.xcassets/$petImageSet.imageset"
    Assert-Pattern "$imageSetPath/Contents.json" "$petImageSet@2x\.png|$petImageSet@3x\.png" "$petImageSet asset catalog manifest"
    if (-not (Test-Path "$imageSetPath/$petImageSet@2x.png") -or -not (Test-Path "$imageSetPath/$petImageSet@3x.png")) {
        throw "Missing 2x/3x resources for $petImageSet"
    }
}
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'enum Scope: Equatable|case crossCategory|case singleCategory\(HomeItem\.Category\)|aiCommandQueryMetricScope' 'AI query metrics carry explicit recognized category scope'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'lifeMarkIntent\?\.categories \?\? categoryIntent\?\.categories|uniqueCategories\.count == 1|aiCommandAsksCategoryBreakdown\(command\)' 'AI query metric scope follows the recognized semantic category domain'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' '\x{5E73}\x{5747}\x{6BCF}\x{7B14}|\x{6700}\x{9AD8}\x{5355}\x{7B14}|\x{6700}\x{9AD8}\x{5206}\x{7C7B}|\x{8BE5}\x{7C7B}\x{91D1}\x{989D}' 'AI query metrics use scope-specific user-facing labels'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandMetricChips[\s\S]{0,1200}\x{91D1}\x{989D}\x{6700}\x{9AD8}' 'AI query metric chips no longer confuse top category with highest record'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'AICommandQueryMetricScopeTests|testExplicitSingleCategoryUsesAverageAndHighestRecordMetrics|testUnfilteredQueryKeepsCrossCategoryMetricsEvenWhenResultsContainOneCategory|testSingleCategoryEmptyAndOneRecordBoundariesStayExplicit' 'AI query metric scope XCTest coverage'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testSingleCategoryLifeMarkUsesFocusedMetricsWithoutRepeatingBaseCategory|testMultiCategoryLifeMarkAndExplicitBreakdownKeepCrossCategoryMetrics' 'AI semantic theme metric scope XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-31|\x{5E73}\x{5747}\x{6BCF}\x{7B14}|\x{6700}\x{9AD8}\x{5355}\x{7B14}' 'AI query metric scope device regression matrix'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'private func aiCommandPreviousRange' 'AI compare owns one previous-period range policy'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'value: -7, to: range\.start' 'AI week comparison aligns the same weekdays'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'matchingEnd' 'AI month comparison aligns the same elapsed month days'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'aiCommandComparisonTimeRange|aiCommandComparisonUsesImplicitCurrentWeek|aiCommandComparisonUsesImplicitCurrentMonth' 'AI omitted comparison subjects resolve to the current week or month'
Assert-NoMultilinePattern 'NativeDemoApp/Views/InsightWebView.swift' 'kind: \.compare,[\s\S]{0,700}bars: dailyBars' 'AI compare does not reuse the current-period-only chart'
Assert-Pattern 'NativeDemoApp/Models/InteractionStateModels.swift' 'containsOmittedSubjectPeriodComparison|text\.contains\("\x{548C}\\\(period\)\x{6BD4}"\)|text\.contains\("\x{6BD4}\x{6BD4}\\\(period\)"\)' 'AI recognizes natural omitted-subject comparison phrases without accepting generic standalone comparison words'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testAICommandComparisonKeepsBothPeriodsAndCategoryChanges|testOmittedComparisonSubjectDefaultsToTheCurrentWeekOrMonth|testExplicitHistoricalComparisonAndHistoricalQueryKeepTheirLiteralPeriods' 'AI comparison period, omitted subject and literal historical boundary XCTest coverage'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-52|\x{5BF9}\x{6BD4}\x{4E0A}\x{5468}|\x{4E0A}\x{5468}\x{5BF9}\x{6BD4}\x{524D}\x{4E00}\x{5468}' 'AI omitted comparison subject device regression matrix'
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
$aiProxyLocation = Join-Path $PSScriptRoot '..\ai-proxy'
Push-Location $aiProxyLocation
try {
    $aiProxyContractOutput = npm test --silent
    $aiProxyContractExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($aiProxyContractExitCode -ne 0) {
    throw "Narrative AI proxy contract tests failed`n$aiProxyContractOutput"
}
Write-Output $aiProxyContractOutput
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift' 'narrativeAIConfigurationDidChange|func removeAll\(\)|rewrites\.removeAll\(\)|func invalidatePendingRewrites\(\)|latestRequestID = UUID\(\)' 'narrative AI cache and in-flight request can be invalidated on configuration and account boundaries'
Assert-Pattern 'NativeDemoApp/ViewModels/SettingsViewModel.swift' 'notifyNarrativeAIConfigurationChanged\(\)|var aiTone:|var useRemoteAI:|hasCloudSession = true|func logoutCloud\(\)|applyExpiredCloudSessionState' 'narrative AI settings and account changes invalidate cached remote copy'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'publisher\(for: \.narrativeAIConfigurationDidChange\)|refreshNarrativeAIConfiguration\(\)|invalidatePendingRewrites\(\)|narrativeAIPreparationRevision = -1|scheduleNarrativeAIPrecompute\(now: Date\(\)\)' 'narrative AI configuration changes cancel stale work and reschedule once'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testRewriteStoreRejectsOldRevisionAndPublishesCurrentResult|store\.removeAll\(\)|XCTAssertNil\(store\.rewrite\(for: pack\.key\)\)' 'narrative AI cache invalidation XCTest coverage'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'dailyInsightSnapshotSignature\([\s\S]{0,500}settings: AppSettings|tone=\\\(settings\.aiTone\.rawValue\)|proxy-signed-out|proxy-ready|direct-unavailable|direct-ready' 'daily insight cache identity follows tone remote switch and credential state'
Assert-Pattern 'NativeDemoApp/Views/SettingsView.swift' '影响今日小记的本地收束；开启联网整理后，也影响今日小记、月度整理和日/周/月轻润色。不影响 AI 指令台、宠物或生活线索。' 'review tone setting explains its real product scope'
Assert-NoPattern 'NativeDemoApp/Services/LifeNarrativePlanningService.swift' 'hasMemoryPhoto' 'narrative planner uses the real multi-photo capability property'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativePlanningService.swift' 'contains\(where: \\.hasMemoryImages\)|compactMap \{ kind, rows -> LifeNarrativeSignal\? in' 'narrative planner photo capability and compactMap result types are compiler explicit'
Assert-Pattern 'NativeDemoApp/Services/LifeNarrativeAIRewriteService.swift' 'let accepted: \[LifeNarrativeAIRewrite\] = response\.rewrites\.compactMap \{ candidate -> LifeNarrativeAIRewrite\? in' 'narrative rewrite compactMap result type is compiler explicit'
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
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'ItemDerivedCacheComputation|ItemDerivedCachePublicationPolicy|coalescingDelayNanoseconds: UInt64 = 40_000_000|prepareItemDerivedCacheIfNeeded|group\.addTask\(priority: \.utility\)|itemDerivedCacheForRead' 'ledger-derived home cache coalesces rapid changes off the main actor and publishes only the latest revision'
Assert-NoPattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'rebuildItemDerivedCache|itemDerivedCacheNeedsRebuild|ensureItemDerivedCacheFresh' 'SwiftUI cache reads never synchronously rebuild the full ledger'
Assert-NoPattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' '@Published private\(set\) var (recordInputAssistanceRevision|homeDashboardRevision)' 'one ledger assignment does not emit extra revision-only publications'
Assert-NoPattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'items\[[^]]+\]\.[A-Za-z_][A-Za-z0-9_?]*\s=\s' 'logical record edits commit one updated value instead of publishing every field mutation'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel+Dashboard.swift' 'pendingHomeDashboardPreparationRequest|isItemDerivedCacheCurrent|resumePendingHomeDashboardPreparationIfNeeded|preservesVisibleLines|objectWillChange\.send\(\)' 'home dashboard waits for one derived revision and publishes stable visible snapshots'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'snapshotTransaction = Transaction\(animation: nil\)|snapshotTransaction\.disablesAnimations = true|withTransaction\(snapshotTransaction\)' 'insight snapshot replacement does not animate the whole layout'
Assert-Pattern 'NativeDemoApp/Views/StatsTraceModels.swift' 'prewarmDelayNanoseconds: UInt64 = 250_000_000' 'trace secondary range prewarm yields to the visible snapshot'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'prewarmDelayNanoseconds|tracePreparationGate\.accepts\(requestID\)' 'trace prewarm is cancellable when a newer ledger revision arrives'
Assert-Pattern 'NativeDemoAppTests/StateRegressionTests.swift' 'testItemDerivedCacheBuildsOneAtomicSnapshotAtReleaseScale|testItemDerivedCachePublicationRejectsOldRevisionAndRequest|testTracePrewarmWaitsUntilVisibleSnapshotHasSettled' 'PERF-15 cache, stale request and prewarm boundaries have XCTest coverage'
Assert-NoPattern 'NativeDemoApp' 'open\.bigmodel\.cn|loadAIAPIKey|saveAIAPIKey' 'iOS production code has no direct-model endpoint or API-key access'
Assert-NoPattern 'NativeDemoApp/Models/AppSettings.swift' 'var aiEndpoint|var aiModel|case aiEndpoint|case aiModel' 'saved settings no longer expose mutable AI endpoint or model fields'
Assert-NoPattern 'NativeDemoApp/ViewModels/SettingsViewModel.swift' 'var aiEndpoint|var aiAPIKey|var aiModel' 'settings view model has no legacy direct-model configuration surface'
Assert-Pattern 'NativeDemoApp/Services/KeychainService.swift' 'removeLegacyDirectModelCredential|SecItemDelete' 'legacy client model credential is deleted without being read'
Assert-Pattern 'NativeDemoApp/Services/AIReportService.swift' 'AppSettings\.productionAIEndpoint|Authorization|narrative_rewrite_batch' 'remote insight service uses only the fixed authenticated production proxy'
Assert-NoPattern 'NativeDemoApp/Services/AIReportService.swift' 'x-proxy-token|"model":|choices|normalizedEndpoint' 'iOS cannot select an upstream model or parse direct-model responses'
Assert-NoPattern 'NativeDemoApp/Views/RecordView.swift' '使用演示 OCR 结果|makeDemoOCRDrafts' 'record page no longer exposes the legacy OCR demo entry'
Assert-NoPattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'makeDemoOCRDrafts|direct-unavailable|direct-ready|直连模型需要' 'home model has no legacy OCR demo or direct-model states'
Assert-Pattern 'ai-proxy/runtimeEnvironmentPolicy.test.js' 'production never registers development routes|allowsDevelopmentRoutes\("production"\), false' 'proxy development route policy has executable production coverage'
Assert-Pattern 'ai-proxy/server.js' 'if \(DEVELOPMENT_ROUTES_ENABLED\) \{|app\.post\("/v1/auth/dev-token"' 'proxy dev-token route is registered only behind the development gate'
Assert-NoPattern 'ai-proxy/server.js' 'req\.body\?\.model' 'proxy ignores client attempts to select the upstream model'
Assert-NoPattern 'ai-proxy/server.js' '/v1/category/recommend|recommendCategoryFromText|category_input_rejected' 'unused unauthenticated proxy category demo is removed'
Assert-Pattern 'backend/src/nudgePolicy.js' 'defaultPolicyForEnvironment|mode.*production.*"prod"|prodDailyLimit: 1|prodSceneCooldownDays: 7' 'backend member nudge defaults to the established production budget'
Assert-Pattern 'backend/scripts/verify-nudge-policy.mjs' 'attemptedProductionBypass|assert\.equal\(attemptedProductionBypass\.mode, "prod"\)' 'backend member nudge debug bypass has executable coverage'
Assert-MultilinePattern 'backend/src/server.js' 'if \(!isProduction\) \{\s+app\.get\("/v1/member/nudge/policy"' 'backend nudge strategy diagnostics are unavailable in production'
Assert-Pattern 'backend/src/server.js' 'nudge/policy' 'backend retains nudge strategy diagnostics for local and staging verification'
Assert-Pattern 'RELEASE_GATE_AND_DEVICE_MATRIX_v1.md' 'FLOW-60|旧客户端模型凭据只删除不读取|生产 ai-proxy 的 dev-token' 'legacy debug cleanup upgrade and production device matrix'
$releaseFixtureOutput = python scripts/validate_release_gate.py --phase fixtures
if ($LASTEXITCODE -ne 0) {
    throw "Release fixture validation failed`n$releaseFixtureOutput"
}
Write-Output $releaseFixtureOutput

Write-Output 'Static experience checks passed.'
