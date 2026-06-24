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
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'shareCareLine|shareCardPayload|shareSelection|shareTagTexts' 'legacy share card unified'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'shareProfile|profileAccent|profilePanelFill|profileAtmosphere' 'legacy share visual profiles'
Assert-Pattern 'NativeDemoApp/Views/InsightWebView.swift' 'headlineSection|shareCarePanel|shareTagPanel' 'legacy share hierarchy'
Assert-Pattern 'NativeDemoApp/Views/StatsWebView.swift' 'summaryMemberPitch\(|SummaryPlaybackMemberPitch' 'member playback pitch wiring'
Assert-Pattern 'NativeDemoApp/ViewModels/HomeViewModel.swift' 'ocrSuccessMessage|ocrQuotaExhaustedMessage' 'ocr copy routing'
Assert-NoPattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' '\x{8F7B}\x{8F7B}|\x{5B89}\x{9759}\x{5730}|\x{6700}\x{60F3}\x{7559}\x{4E0B}\x{7684}|\x{503C}\x{5F97}\x{88AB}\x{7559}\x{4E0B}|\x{90A3}\x{6BB5}\x{5728}\x{5916}\x{5730}\x{7684}\x{65E5}\x{5B50}|\x{8FD8}\x{60F3}\x{7559}\x{4E0B}\x{6765}|\x{88AB}\x{7559}\x{4E86}\x{4E0B}\x{6765}|\x{4E00}\x{8D77}\x{7559}\x{4E86}\x{4E0B}\x{6765}' 'overclaimed share wording'
Assert-Pattern 'NativeDemoApp/Views/SummaryPlaybackSheet.swift' 'accessibilityReduceMotion|periodic\(from: Date\(\), by: 1\.0 / 15\.0\)|rendersAsynchronously' 'playback animation performance guard'
Assert-NoPattern 'NativeDemoApp/Services/PlaybackSupportServices.swift' 'private let [A-Za-z0-9_]+ = Self\.' 'no covariant Self in stored property initializer'
Assert-JsonFixtureIds 'qa/life_story_regression_fixtures.json' @(
    'rain_commute',
    'first_fitness',
    'drink_streak',
    'away_city',
    'weekend_social',
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
    'weak_data_daily'
) 'share playback acceptance matrix'

Write-Output 'Static experience checks passed.'
