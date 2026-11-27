# INF-001 governance contract checks.
# TC-INF-001-A template shape
# TC-INF-001-B policy cross-check
# TC-INF-001-C conflicting authority or incomplete AC is BLOCKED, never READY
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$EvidenceDir = ""
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Id, [string]$Expected, [string]$Actual, [string]$Status)
    $results.Add([pscustomobject]@{
        TestId   = $Id
        Expected = $Expected
        Actual   = $Actual
        Status   = $Status
    }) | Out-Null
    if ($Status -ne "PASS") {
        $failures.Add("$Id $Status :: $Actual") | Out-Null
    }
}

function Get-ReadyClassification {
    param([string]$Text)
    $approvers = @()
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s*Final approver:\s*(.+)\s*$') {
            $approvers += $Matches[1].Trim()
        }
    }
    $uniqueApprovers = @($approvers | Select-Object -Unique)
    $approved = $Text -match 'Requirement approved:\s*yes'
    $acLines = @($Text -split "`r?`n" | Where-Object { $_ -match 'AC-001:' })
    $acComplete = $false
    foreach ($line in $acLines) {
        $value = ($line -replace '.*AC-001:\s*', '').Trim()
        if ($value.Length -gt 0) { $acComplete = $true }
    }
    if ($uniqueApprovers.Count -ne 1 -or $uniqueApprovers[0] -ne "GPT CTO") {
        return "BLOCKED"
    }
    if (-not $approved -or -not $acComplete) {
        return "BLOCKED"
    }
    return "READY"
}

$templateDir = Join-Path $RepoRoot ".github\ISSUE_TEMPLATE"
$templates = @(Get-ChildItem -Path $templateDir -File -Filter "*.md" -ErrorAction SilentlyContinue)
$canonical = Join-Path $templateDir "ai_task.md"
$legacy = Join-Path $templateDir "ai_task-md.md"

if ($templates.Count -eq 1 -and $templates[0].Name -eq "ai_task.md" -and (Test-Path $canonical) -and -not (Test-Path $legacy)) {
    Add-Result "TC-INF-001-A1" "exactly one ISSUE_TEMPLATE markdown named ai_task.md" "count=$($templates.Count) name=$($templates[0].Name)" "PASS"
} else {
    $names = ($templates | ForEach-Object { $_.Name }) -join ","
    Add-Result "TC-INF-001-A1" "exactly one ISSUE_TEMPLATE markdown named ai_task.md" "count=$($templates.Count) names=$names legacy=$(Test-Path $legacy)" "FAIL"
}

$frontCount = 0
$sectionMissing = @()
if (Test-Path $canonical) {
    $templateText = Get-Content -Path $canonical -Raw -Encoding UTF8
    $frontCount = @([regex]::Matches($templateText, '(?m)^---\s*$')).Count
    for ($i = 1; $i -le 25; $i++) {
        if ($templateText -notmatch "(?m)^# $i\. ") {
            $sectionMissing += $i
        }
    }
    $yamlStart = $templateText.IndexOf("---")
    $yamlEnd = $templateText.IndexOf("---", $yamlStart + 3)
    $yaml = ""
    if ($yamlStart -ge 0 -and $yamlEnd -gt $yamlStart) {
        $yaml = $templateText.Substring($yamlStart, $yamlEnd - $yamlStart)
    }
    $nameCount = @([regex]::Matches($yaml, '(?m)^name:')).Count
    if ($frontCount -eq 2 -and $nameCount -eq 1 -and $sectionMissing.Count -eq 0) {
        Add-Result "TC-INF-001-A2" "one YAML front matter and sections 1-25" "front=$frontCount nameKeys=$nameCount missing=none" "PASS"
    } else {
        Add-Result "TC-INF-001-A2" "one YAML front matter and sections 1-25" "front=$frontCount nameKeys=$nameCount missing=$($sectionMissing -join ',')" "FAIL"
    }
} else {
    Add-Result "TC-INF-001-A2" "one YAML front matter and sections 1-25" "canonical template missing" "FAIL"
}

$requiredDocs = @(
    ".github\PROJECT_CHARTER.md",
    ".github\TEST_POLICY.md",
    ".github\DEFINITION_OF_DONE.md",
    "docs\RTM.md",
    "docs\requirements\REQ-INF-001.md"
)
foreach ($rel in $requiredDocs) {
    $path = Join-Path $RepoRoot $rel
    $len = 0
    if (Test-Path $path) { $len = (Get-Item $path).Length }
    if ($len -gt 200) {
        Add-Result "TC-INF-001-B1-$($rel.Replace('\','/'))" "non-empty document" "bytes=$len" "PASS"
    } else {
        Add-Result "TC-INF-001-B1-$($rel.Replace('\','/'))" "non-empty document" "bytes=$len" "FAIL"
    }
}

$charter = Get-Content (Join-Path $RepoRoot ".github\PROJECT_CHARTER.md") -Raw -Encoding UTF8
$policy = Get-Content (Join-Path $RepoRoot ".github\TEST_POLICY.md") -Raw -Encoding UTF8
$dod = Get-Content (Join-Path $RepoRoot ".github\DEFINITION_OF_DONE.md") -Raw -Encoding UTF8
$joined = $charter + "`n" + $policy + "`n" + $dod
$must = @(
    "REQ-INF-001",
    "PROPOSED",
    "GPT CTO",
    "N/A"
)
$missingMust = @($must | Where-Object { $joined -notlike "*$_*" })
$tradingBan = ($charter -like "*No entry, exit, signal, risk, volume, stop-loss, take-profit*")
$noCursorMerge = ($charter -like "*cannot merge*")
if ($missingMust.Count -eq 0 -and $tradingBan -and $noCursorMerge) {
    Add-Result "TC-INF-001-B2" "cross-consistent proposal, trading freeze, single accepter" "required phrases present" "PASS"
} else {
    Add-Result "TC-INF-001-B2" "cross-consistent proposal, trading freeze, single accepter" "missing=$($missingMust -join ',') tradingBan=$tradingBan noCursorMerge=$noCursorMerge" "FAIL"
}

$agents = Join-Path $RepoRoot ".github\AGENTS.md"
$master = Join-Path $RepoRoot ".github\GPT_MASTER_GOVERNANCE.md"
$hashA = (Get-FileHash $agents -Algorithm SHA256).Hash
$hashB = (Get-FileHash $master -Algorithm SHA256).Hash
if ($hashA -eq $hashB -and $charter.Contains($hashA)) {
    Add-Result "TC-INF-001-B3" "identical governance baseline recorded" $hashA "PASS"
} else {
    Add-Result "TC-INF-001-B3" "identical governance baseline recorded" "agents=$hashA master=$hashB recorded=$($charter.Contains($hashA))" "FAIL"
}

$fixtureDir = Join-Path $RepoRoot "tests\fixtures\inf-001"
$expectedClass = @{
    "valid-control.md"      = "READY"
    "conflict-authority.md" = "BLOCKED"
    "incomplete-ac.md"      = "BLOCKED"
}
foreach ($name in $expectedClass.Keys) {
    $text = Get-Content (Join-Path $fixtureDir $name) -Raw -Encoding UTF8
    $actual = Get-ReadyClassification -Text $text
    $expected = $expectedClass[$name]
    $id = "TC-INF-001-C-$name"
    if ($actual -eq $expected) {
        Add-Result $id $expected $actual "PASS"
    } else {
        Add-Result $id $expected $actual "FAIL"
    }
}

$conflictActual = Get-ReadyClassification -Text (Get-Content (Join-Path $fixtureDir "conflict-authority.md") -Raw -Encoding UTF8)
$incompleteActual = Get-ReadyClassification -Text (Get-Content (Join-Path $fixtureDir "incomplete-ac.md") -Raw -Encoding UTF8)
if ($conflictActual -eq "READY" -or $incompleteActual -eq "READY") {
    Add-Result "TC-INF-001-C-never-ready" "BLOCKED fixtures are not READY" "conflict=$conflictActual incomplete=$incompleteActual" "FAIL"
} else {
    Add-Result "TC-INF-001-C-never-ready" "BLOCKED fixtures are not READY" "conflict=$conflictActual incomplete=$incompleteActual" "PASS"
}

$stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$sourceCommit = "UNVERIFIED"
$worktree = "UNVERIFIED"
try {
    $sourceCommit = (& git -C $RepoRoot rev-parse HEAD).Trim()
    $porcelain = & git -C $RepoRoot status --porcelain
    if ([string]::IsNullOrWhiteSpace(($porcelain | Out-String))) {
        $worktree = "clean"
    } else {
        $worktree = "dirty"
    }
} catch {
    $sourceCommit = "UNVERIFIED"
    $worktree = "UNVERIFIED"
}
if ($EvidenceDir -ne "") {
    $bindOk = ($worktree -eq "clean" -and $sourceCommit -match '^[0-9a-fA-F]{40}$')
    if ($bindOk) {
        Add-Result "TC-INF-001-BIND" "clean worktree at a full source commit" "worktree=$worktree source_commit=$sourceCommit" "PASS"
    } else {
        Add-Result "TC-INF-001-BIND" "clean worktree at a full source commit" "worktree=$worktree source_commit=$sourceCommit" "FAIL"
    }
}
Write-Output "INF-001 governance contract"
Write-Output "timestamp_utc=$stamp"
Write-Output "repo=$RepoRoot"
Write-Output "source_commit=$sourceCommit"
Write-Output "worktree=$worktree"
foreach ($row in $results) {
    Write-Output ("{0} expected={1} actual={2} status={3}" -f $row.TestId, $row.Expected, $row.Actual, $row.Status)
}

if ($EvidenceDir -ne "") {
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
    $results | Export-Csv -Path (Join-Path $EvidenceDir "unit_test_results.csv") -NoTypeInformation -Encoding UTF8
    $logPath = Join-Path $EvidenceDir "test_stdout.log"
    $results | ForEach-Object { "{0} expected={1} actual={2} status={3}" -f $_.TestId, $_.Expected, $_.Actual, $_.Status } | Set-Content -Path $logPath -Encoding UTF8
    Add-Content -Path $logPath -Encoding UTF8 -Value "timestamp_utc=$stamp"
    Add-Content -Path $logPath -Encoding UTF8 -Value "source_commit=$sourceCommit"
    Add-Content -Path $logPath -Encoding UTF8 -Value "worktree=$worktree"
    Add-Content -Path $logPath -Encoding UTF8 -Value "failure_count=$($failures.Count)"
}

if ($failures.Count -gt 0) {
    Write-Output "SUMMARY=FAIL count=$($failures.Count)"
    exit 1
}
Write-Output "SUMMARY=PASS count=$($results.Count)"
exit 0
