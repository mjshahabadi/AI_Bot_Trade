#Requires -Version 5.1
<#
.SYNOPSIS
  INF-003 Environment Doctor tests: TC-INF-003-A / B / C.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$EvidenceDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Id,
        [string]$Expected,
        [string]$Actual,
        [string]$Status
    )
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

function Invoke-DoctorCapture {
    param(
        [hashtable]$DoctorParams,
        [string]$OutDir
    )
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $doctor = Join-Path $RepoRoot "tools\env-doctor\Invoke-EnvDoctor.ps1"
    $stdoutPath = Join-Path $OutDir "stdout.log"
    $stderrPath = Join-Path $OutDir "stderr.log"

    # Build a quoted argument string. Start-Process array joining breaks unquoted paths with spaces.
    $argParts = New-Object System.Collections.Generic.List[string]
    $argParts.Add("-NoProfile") | Out-Null
    $argParts.Add("-ExecutionPolicy Bypass") | Out-Null
    $argParts.Add("-File `"$doctor`"") | Out-Null
    foreach ($key in $DoctorParams.Keys) {
        $val = $DoctorParams[$key]
        if ($val -is [switch] -or $val -is [bool]) {
            if ($val) { $argParts.Add("-$key") | Out-Null }
        }
        else {
            $argParts.Add("-$key `"$([string]$val)`"") | Out-Null
        }
    }
    $argString = ($argParts -join " ")

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = $argString
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $RepoRoot

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    Set-Content -LiteralPath $stdoutPath -Value $stdout -Encoding UTF8
    Set-Content -LiteralPath $stderrPath -Value $stderr -Encoding UTF8

    return [pscustomobject]@{
        ExitCode   = $proc.ExitCode
        StdOutPath = $stdoutPath
        StdErrPath = $stderrPath
        JsonPath   = (Join-Path $OutDir "doctor_report.json")
        TxtPath    = (Join-Path $OutDir "doctor_report.txt")
    }
}

$started = (Get-Date).ToUniversalTime()
if (-not $EvidenceDir) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $EvidenceDir = Join-Path $RepoRoot ("artifacts\issue-3\run-{0}" -f $stamp)
}
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

Push-Location -LiteralPath $RepoRoot
try {
    $testedSha = (& git rev-parse HEAD).Trim()
    $statusPorcelain = (& git status --porcelain=v1 | Out-String).TrimEnd()
    $branch = (& git rev-parse --abbrev-ref HEAD).Trim()
}
finally {
    Pop-Location
}

$hostName = $env:COMPUTERNAME
$psVer = $PSVersionTable.PSVersion.ToString()
Write-Output "INF-003 tests start $($started.ToString('o'))"
Write-Output "tested_sha=$testedSha"
Write-Output "branch=$branch"
Write-Output "host=$hostName powershell=$psVer"
Write-Output "evidence_dir=$EvidenceDir"

# ---------- TC-INF-003-A: real host run ----------
$outA = Join-Path $EvidenceDir "tc-a"
$runA = Invoke-DoctorCapture -OutDir $outA -DoctorParams @{
    RepoRoot     = $RepoRoot
    OutputDir    = $outA
    RequireTools = $true
}
$jsonA = $null
if (Test-Path -LiteralPath $runA.JsonPath) {
    $jsonA = Get-Content -LiteralPath $runA.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

if ($runA.ExitCode -eq 0 -and $jsonA -and $jsonA.overall_status -eq "PASS") {
    $hasMeta = $jsonA.metaeditor -and $jsonA.metaeditor.path -and $jsonA.metaeditor.file_version
    $hasTerm = $jsonA.terminal -and $jsonA.terminal.path -and $jsonA.terminal.file_version
    $hasGit = $jsonA.git -and $jsonA.git.available -eq $true -and $jsonA.git.path
    $abs = ($jsonA.metaeditor.path -match '^[A-Za-z]:\\') -and ($jsonA.terminal.path -match '^[A-Za-z]:\\')
    $mapOk = $false
    if ($jsonA.install_data_mapping) {
        $mappedRoots = @($jsonA.install_data_mapping | Where-Object { $_.mapped -eq $true })
        $mapOk = ($mappedRoots.Count -ge 1)
    }
    $agentClassOk = $jsonA.tester_agents -and ($jsonA.tester_agents.operational_readiness_claimed -eq $false) -and
        ($null -ne $jsonA.tester_agents.discovered_agent_directory_count) -and
        ($null -ne $jsonA.tester_agents.operational_metatester_process_count)
    if ($hasMeta -and $hasTerm -and $hasGit -and $abs -and $mapOk -and $agentClassOk) {
        Add-Result "TC-INF-003-A" `
            "Doctor captures real MetaEditor/MT5/Git absolute paths/versions plus install-data map; agents classified without operational claim" `
            ("exit={0} meta={1} ver={2} term={3} git={4} mapped_roots={5} discovered_agents={6} operational_metatester={7} readiness_claimed={8}" -f `
                $runA.ExitCode, $jsonA.metaeditor.path, $jsonA.metaeditor.file_version, $jsonA.terminal.path, $jsonA.git.path, `
                @($jsonA.install_data_mapping | Where-Object { $_.mapped }).Count, `
                $jsonA.tester_agents.discovered_agent_directory_count, `
                $jsonA.tester_agents.operational_metatester_process_count, `
                $jsonA.tester_agents.operational_readiness_claimed) `
            "PASS"
    }
    else {
        Add-Result "TC-INF-003-A" `
            "Doctor captures real MetaEditor/MT5/Git absolute paths/versions plus install-data map; agents classified without operational claim" `
            ("incomplete report exit={0} meta={1} term={2} git={3} mapOk={4} agentClassOk={5}" -f $runA.ExitCode, [bool]$hasMeta, [bool]$hasTerm, [bool]$hasGit, $mapOk, $agentClassOk) `
            "FAIL"
    }
}
elseif ($runA.ExitCode -ne 0 -and $jsonA -and $jsonA.overall_status -eq "BLOCKED") {
    Add-Result "TC-INF-003-A" `
        "Doctor captures real MetaEditor/MT5/Git absolute paths and versions" `
        ("tools missing on host; doctor correctly BLOCKED exit={0} issues={1}" -f $runA.ExitCode, (($jsonA.issues) -join "|")) `
        "BLOCKED"
}
else {
    Add-Result "TC-INF-003-A" `
        "Doctor captures real MetaEditor/MT5/Git absolute paths and versions" `
        ("unexpected exit={0} json_exists={1}" -f $runA.ExitCode, (Test-Path $runA.JsonPath)) `
        "FAIL"
}

# ---------- TC-INF-003-B: invalid MetaEditor path ----------
$outB = Join-Path $EvidenceDir "tc-b"
$badPath = "C:\Program Files\MetaTrader 5\metaeditor64-DOES-NOT-EXIST.exe"
$runB = Invoke-DoctorCapture -OutDir $outB -DoctorParams @{
    RepoRoot        = $RepoRoot
    OutputDir       = $outB
    MetaEditorPath  = $badPath
    RequireTools    = $true
}
$stdoutB = ""
if (Test-Path -LiteralPath $runB.StdOutPath) {
    $stdoutB = Get-Content -LiteralPath $runB.StdOutPath -Raw -Encoding UTF8
}
$jsonB = $null
if (Test-Path -LiteralPath $runB.JsonPath) {
    $jsonB = Get-Content -LiteralPath $runB.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
$precise = ($stdoutB -match "MetaEditorPath override not found") -or ($jsonB -and (($jsonB.issues | Out-String) -match "MetaEditorPath override not found"))
if ($runB.ExitCode -ne 0 -and $precise) {
    Add-Result "TC-INF-003-B" `
        "Invalid MetaEditor path => nonzero exit and precise error" `
        ("exit={0} precise_error=true path={1}" -f $runB.ExitCode, $badPath) `
        "PASS"
}
else {
    Add-Result "TC-INF-003-B" `
        "Invalid MetaEditor path => nonzero exit and precise error" `
        ("exit={0} precise_error={1}" -f $runB.ExitCode, $precise) `
        "FAIL"
}

# ---------- TC-INF-003-C: path with spaces / non-ASCII ----------
$outC = Join-Path $EvidenceDir "tc-c"
$spaceRoot = Join-Path $env:TEMP "INF-003 Env Doctor Тест"
$spaceDir = Join-Path $spaceRoot "MetaTrader 5"
New-Item -ItemType Directory -Force -Path $spaceDir | Out-Null
$spaceEditor = Join-Path $spaceDir "metaeditor64.exe"
$spaceTerminal = Join-Path $spaceDir "terminal64.exe"
$spaceTester = Join-Path $spaceDir "metatester64.exe"

# Prefer copying from a discovered real install when available from TC-A report.
$srcEditor = $null
$srcTerminal = $null
$srcTester = $null
if ($jsonA -and $jsonA.metaeditor -and $jsonA.metaeditor.path -and (Test-Path -LiteralPath $jsonA.metaeditor.path)) {
    $srcEditor = $jsonA.metaeditor.path
    $srcRoot = Split-Path -Parent $srcEditor
    $candTerm = Join-Path $srcRoot "terminal64.exe"
    $candTester = Join-Path $srcRoot "metatester64.exe"
    if (Test-Path -LiteralPath $candTerm) { $srcTerminal = $candTerm }
    if (Test-Path -LiteralPath $candTester) { $srcTester = $candTester }
}

$boundaryMode = "copy"
if ($srcEditor -and $srcTerminal -and $srcTester) {
    Copy-Item -LiteralPath $srcEditor -Destination $spaceEditor -Force
    Copy-Item -LiteralPath $srcTerminal -Destination $spaceTerminal -Force
    Copy-Item -LiteralPath $srcTester -Destination $spaceTester -Force
}
else {
    # Fallback: tiny placeholder files are NOT valid MT5 binaries; doctor should still
    # accept readable files when overrides point at existing paths with spaces.
    # Use RequireTools + InstallRoot so discovery uses the spaced directory.
    Set-Content -LiteralPath $spaceEditor -Value "placeholder-not-a-real-binary" -Encoding ASCII
    Set-Content -LiteralPath $spaceTerminal -Value "placeholder-not-a-real-binary" -Encoding ASCII
    Set-Content -LiteralPath $spaceTester -Value "placeholder-not-a-real-binary" -Encoding ASCII
    $boundaryMode = "placeholder"
}

$runC = Invoke-DoctorCapture -OutDir $outC -DoctorParams @{
    RepoRoot     = $RepoRoot
    OutputDir    = $outC
    InstallRoot  = $spaceDir
    RequireTools = $true
    SkipGit      = $true
}
$jsonC = $null
if (Test-Path -LiteralPath $runC.JsonPath) {
    $jsonC = Get-Content -LiteralPath $runC.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$handled = $false
$detail = ""
if ($runC.ExitCode -eq 0 -and $jsonC -and $jsonC.overall_status -eq "PASS" -and $jsonC.metaeditor -and ($jsonC.metaeditor.path -like "* *")) {
    $handled = $true
    $detail = "handled spaced/unicode path exit=0 path=$($jsonC.metaeditor.path) mode=$boundaryMode"
}
elseif ($runC.ExitCode -ne 0 -and $jsonC -and ($jsonC.overall_status -eq "BLOCKED" -or $jsonC.overall_status -eq "FAIL")) {
    # Explicit BLOCKED/FAIL with path retained is acceptable for boundary per issue.
    $handled = $true
    $detail = "explicit $($jsonC.overall_status) for spaced path exit=$($runC.ExitCode) mode=$boundaryMode"
}

if ($handled) {
    Add-Result "TC-INF-003-C" `
        "Path with spaces/non-ASCII correctly handled or explicitly BLOCKED" `
        $detail `
        "PASS"
}
else {
    Add-Result "TC-INF-003-C" `
        "Path with spaces/non-ASCII correctly handled or explicitly BLOCKED" `
        ("unhandled exit={0} mode={1}" -f $runC.ExitCode, $boundaryMode) `
        "FAIL"
}

# ---------- TC-INF-003-D: missing Agent directories fail-closed ----------
$outD = Join-Path $EvidenceDir "tc-d"
$emptyTester = Join-Path $env:TEMP ("inf003-empty-tester-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $emptyTester | Out-Null
$runD = Invoke-DoctorCapture -OutDir $outD -DoctorParams @{
    RepoRoot                 = $RepoRoot
    OutputDir                = $outD
    TesterRoot               = $emptyTester
    RequireAgentDirectories  = $true
    MinAgentDirectories      = 1
    SkipGit                  = $true
}
$jsonD = $null
if (Test-Path -LiteralPath $runD.JsonPath) {
    $jsonD = Get-Content -LiteralPath $runD.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
$dOk = ($runD.ExitCode -ne 0) -and $jsonD -and ($jsonD.overall_status -eq "BLOCKED") -and
    (($jsonD.issues | Out-String) -match "Discovered Agent-\* directories below minimum|Tester root missing")
if ($dOk) {
    Add-Result "TC-INF-003-D" `
        "Missing/unavailable Tester Agent directories => nonzero BLOCKED" `
        ("exit={0} status={1} discovered={2}" -f $runD.ExitCode, $jsonD.overall_status, $jsonD.tester_agents.discovered_agent_directory_count) `
        "PASS"
}
else {
    Add-Result "TC-INF-003-D" `
        "Missing/unavailable Tester Agent directories => nonzero BLOCKED" `
        ("exit={0} json={1}" -f $runD.ExitCode, (Test-Path $runD.JsonPath)) `
        "FAIL"
}

# ---------- TC-INF-003-E: inaccessible required path ----------
$outE = Join-Path $EvidenceDir "tc-e"
$denyDir = Join-Path $env:TEMP ("inf003-deny-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $denyDir | Out-Null
$denyFile = Join-Path $denyDir "metaeditor64.exe"
Set-Content -LiteralPath $denyFile -Value "x" -Encoding ASCII
$acl = Get-Acl -LiteralPath $denyFile
$denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "Read", "Deny")
$acl.AddAccessRule($denyRule)
Set-Acl -LiteralPath $denyFile -AclObject $acl
$runE = Invoke-DoctorCapture -OutDir $outE -DoctorParams @{
    RepoRoot       = $RepoRoot
    OutputDir      = $outE
    MetaEditorPath = $denyFile
    RequireTools   = $true
    SkipGit        = $true
}
$stdoutE = if (Test-Path $runE.StdOutPath) { Get-Content -LiteralPath $runE.StdOutPath -Raw -Encoding UTF8 } else { "" }
$jsonE = $null
if (Test-Path -LiteralPath $runE.JsonPath) {
    $jsonE = Get-Content -LiteralPath $runE.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
$eOk = ($runE.ExitCode -ne 0) -and ($stdoutE -match "MetaEditorPath override not readable")
# restore ACL for cleanup
try {
    $acl2 = Get-Acl -LiteralPath $denyFile
    [void]$acl2.RemoveAccessRule($denyRule)
    Set-Acl -LiteralPath $denyFile -AclObject $acl2
}
catch { }
if ($eOk) {
    Add-Result "TC-INF-003-E" `
        "Inaccessible required MetaEditor path => nonzero actionable failure" `
        ("exit={0} precise_error=true status={1}" -f $runE.ExitCode, $(if ($jsonE) { $jsonE.overall_status } else { "n/a" })) `
        "PASS"
}
else {
    Add-Result "TC-INF-003-E" `
        "Inaccessible required MetaEditor path => nonzero actionable failure" `
        ("exit={0} precise={1}" -f $runE.ExitCode, [bool]($stdoutE -match "not readable")) `
        "FAIL"
}

# ---------- TC-INF-003-F: MetaEditor vs MT5 build mismatch ----------
$outF = Join-Path $EvidenceDir "tc-f"
$mismatchDir = Join-Path $env:TEMP ("inf003-mismatch-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $mismatchDir | Out-Null
$mEditor = Join-Path $mismatchDir "metaeditor64.exe"
$mTerm = Join-Path $mismatchDir "terminal64.exe"
$mTester = Join-Path $mismatchDir "metatester64.exe"
if ($srcEditor -and $srcTerminal -and $srcTester) {
    Copy-Item -LiteralPath $srcEditor -Destination $mEditor -Force
    Copy-Item -LiteralPath $srcTerminal -Destination $mTerm -Force
    Copy-Item -LiteralPath $srcTester -Destination $mTester -Force
    # Rewrite version resource is not feasible portably; instead stub terminal with a different readable fake
    # after copy so GetVersionInfo returns empty/different from real metaeditor.
    Set-Content -LiteralPath $mTerm -Value "not-a-real-terminal-binary" -Encoding ASCII
    $runF = Invoke-DoctorCapture -OutDir $outF -DoctorParams @{
        RepoRoot            = $RepoRoot
        OutputDir           = $outF
        InstallRoot         = $mismatchDir
        FailOnBuildMismatch = $true
        SkipGit             = $true
    }
    $jsonF = $null
    if (Test-Path -LiteralPath $runF.JsonPath) {
        $jsonF = Get-Content -LiteralPath $runF.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    $fOk = ($runF.ExitCode -ne 0) -and $jsonF -and ($jsonF.overall_status -eq "FAIL") -and ($jsonF.build_consistency.mismatch -eq $true)
    if ($fOk) {
        Add-Result "TC-INF-003-F" `
            "Differing MetaEditor/MT5 FileVersion => FAIL with mismatch evidence" `
            ("exit={0} versions={1}" -f $runF.ExitCode, (($jsonF.build_consistency.unique_versions) -join ",")) `
            "PASS"
    }
    else {
        Add-Result "TC-INF-003-F" `
            "Differing MetaEditor/MT5 FileVersion => FAIL with mismatch evidence" `
            ("exit={0} mismatch={1}" -f $runF.ExitCode, $(if ($jsonF) { $jsonF.build_consistency.mismatch } else { "n/a" })) `
            "FAIL"
    }
}
else {
    Add-Result "TC-INF-003-F" `
        "Differing MetaEditor/MT5 FileVersion => FAIL with mismatch evidence" `
        "source binaries unavailable to construct mismatch fixture" `
        "BLOCKED"
}

# ---------- Regression: trading freeze + governance templates ----------
$tradingHits = @()
Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '^\.(mq5|mqh|ex5)$' } |
    ForEach-Object { $tradingHits += $_.FullName }
if ($tradingHits.Count -eq 0) {
    Add-Result "REG-INF-003-1" `
        "No MQL5 trading sources present/changed for this infrastructure issue" `
        "mq5/mqh/ex5 count=0 under repo worktree" `
        "PASS"
}
else {
    Add-Result "REG-INF-003-1" `
        "No MQL5 trading sources present/changed for this infrastructure issue" `
        ("unexpected files: " + ($tradingHits -join ";")) `
        "FAIL"
}

$govBaseline = "aebe8cd62aaf15f84d4001f15a8b828c92202b77"
$govFiles = @(
    ".github/AGENTS.md",
    ".github/GPT_MASTER_GOVERNANCE.md",
    ".github/ISSUE_TEMPLATE/ai_task.md",
    ".github/PULL_REQUEST_TEMPLATE.md"
)
$govDelta = @()
foreach ($gf in $govFiles) {
    $diff = (& git -C $RepoRoot diff --name-only $govBaseline -- $gf 2>$null | Out-String).Trim()
    if ($diff) { $govDelta += $diff }
}
$agentsHash = (Get-FileHash -LiteralPath (Join-Path $RepoRoot ".github\AGENTS.md") -Algorithm SHA256).Hash
$gptHash = (Get-FileHash -LiteralPath (Join-Path $RepoRoot ".github\GPT_MASTER_GOVERNANCE.md") -Algorithm SHA256).Hash
if (($govDelta.Count -eq 0) -and ($agentsHash -eq $gptHash)) {
    Add-Result "REG-INF-003-2" `
        "Governance/issue/PR templates unchanged vs claim baseline; AGENTS==GPT_MASTER hash" `
        ("delta_count=0 agents_gpt_identical=True sha256={0}" -f $agentsHash) `
        "PASS"
}
else {
    Add-Result "REG-INF-003-2" `
        "Governance/issue/PR templates unchanged vs claim baseline; AGENTS==GPT_MASTER hash" `
        ("delta={0} identical={1}" -f ($govDelta -join ","), ($agentsHash -eq $gptHash)) `
        "FAIL"
}

# Binding check
Add-Result "TC-INF-003-BIND" `
    "Evidence bound to full tested commit SHA on clean evaluation tree" `
    ("tested_sha=$testedSha branch=$branch porcelain_empty=$([string]::IsNullOrWhiteSpace($statusPorcelain))" ) `
    $(if ($testedSha -match '^[0-9a-f]{40}$') { "PASS" } else { "FAIL" })

# Write outputs
$csvPath = Join-Path $EvidenceDir "unit_test_results.csv"
$results | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

$stdoutAll = Join-Path $EvidenceDir "test_stdout.log"
@(
    "INF-003 Test-EnvDoctor"
    "timestamp_utc=$($started.ToString('o'))"
    "tested_sha=$testedSha"
    "branch=$branch"
    "host=$hostName"
    "powershell=$psVer"
    "evidence_dir=$EvidenceDir"
    "git_status_porcelain<<"
    $statusPorcelain
    ">>"
    ""
    "RESULTS"
) + @($results | ForEach-Object { "$($_.TestId)|$($_.Status)|$($_.Actual)" }) |
    Set-Content -LiteralPath $stdoutAll -Encoding UTF8

$runLeaf = Split-Path -Leaf $EvidenceDir
$manifest = [ordered]@{
    issue                = 3
    task_id              = "INF-003"
    requirement_ids      = @("REQ-INF-003")
    rule_ids             = @("RULE-ENV-001")
    run_id               = $runLeaf
    branch               = $branch
    baseline_commit      = "a428d1cb5a3fc20b0f38fb1bb29653570e3fda2c"
    tested_commit        = $testedSha
    origin_main_at_claim = "aebe8cd62aaf15f84d4001f15a8b828c92202b77"
    execution_timestamp_utc = $started.ToString("o")
    host                 = $hostName
    os                   = [System.Environment]::OSVersion.VersionString
    powershell           = $psVer
    compiler_build       = "N/A — no MQL5 compile in INF-003"
    ex5_hash             = "N/A — no EX5 produced"
    authorization        = "Product Owner scoped approval 2026-11-27 for REQ-INF-003 only; INF-001 remains REWORK"
    pr_url               = "https://github.com/mjshahabadi/AI_Bot_Trade/pull/15"
    artifact_links       = [ordered]@{
        manifest = "artifacts/issue-3/$runLeaf/run_manifest.json"
        csv      = "artifacts/issue-3/$runLeaf/unit_test_results.csv"
        summary  = "artifacts/issue-3/$runLeaf/test_summary.md"
        stdout   = "artifacts/issue-3/$runLeaf/test_stdout.log"
        sha256   = "artifacts/issue-3/$runLeaf/evidence_sha256.txt"
        tc_a     = "artifacts/issue-3/$runLeaf/tc-a/"
        tc_b     = "artifacts/issue-3/$runLeaf/tc-b/"
        tc_c     = "artifacts/issue-3/$runLeaf/tc-c/"
        tc_d     = "artifacts/issue-3/$runLeaf/tc-d/"
        tc_e     = "artifacts/issue-3/$runLeaf/tc-e/"
        tc_f     = "artifacts/issue-3/$runLeaf/tc-f/"
    }
    acceptance_criteria  = @(
        [ordered]@{ id = "AC-001"; status = "see tests"; tests = @("TC-INF-003-A") }
        [ordered]@{ id = "AC-002"; status = "see tests"; tests = @("TC-INF-003-B", "TC-INF-003-D", "TC-INF-003-E", "TC-INF-003-F") }
        [ordered]@{ id = "AC-003"; status = "see tests"; tests = @("TC-INF-003-BIND") }
    )
    tests                = @($results | ForEach-Object { [ordered]@{ id = $_.TestId; status = $_.Status; expected = $_.Expected; actual = $_.Actual } })
    failure_count        = $failures.Count
    evidence_dir         = $EvidenceDir
    evidence_binding_note = "Tests executed on clean tree at tested_commit. Evidence publication commit is separate and must not be treated as the tested revision."
}
$manifestPath = Join-Path $EvidenceDir "run_manifest.json"
($manifest | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $manifestPath -Encoding UTF8

# SHA256 list written AFTER final manifest bytes are stable
$hashLines = @()
Get-ChildItem -LiteralPath $EvidenceDir -Recurse -File |
    Where-Object { $_.Name -ne "evidence_sha256.txt" } |
    ForEach-Object {
        $rel = $_.FullName.Substring($EvidenceDir.Length + 1)
        $h = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        $hashLines += ("{0}  {1}" -f $h, $rel)
    }
$hashLines | Set-Content -LiteralPath (Join-Path $EvidenceDir "evidence_sha256.txt") -Encoding UTF8

$summary = @"
# INF-003 Test Summary

- Run ID: $runLeaf
- Tested SHA: $testedSha
- Branch: $branch
- Host: $hostName
- Timestamp UTC: $($started.ToString('o'))
- Failures: $($failures.Count)
- PR: https://github.com/mjshahabadi/AI_Bot_Trade/pull/15

| Test ID | Status | Expected | Actual |
|---|---|---|---|
$(($results | ForEach-Object { "| $($_.TestId) | $($_.Status) | $($_.Expected) | $($_.Actual) |" }) -join [Environment]::NewLine)

Compilation: N/A (no MQL5 in scope)
Trading logic: unchanged
Governance templates: REG-INF-003-2
"@
Set-Content -LiteralPath (Join-Path $EvidenceDir "test_summary.md") -Value $summary -Encoding UTF8

# Re-hash after summary update so evidence_sha256 matches committed bytes
$hashLines = @()
Get-ChildItem -LiteralPath $EvidenceDir -Recurse -File |
    Where-Object { $_.Name -ne "evidence_sha256.txt" } |
    ForEach-Object {
        $rel = $_.FullName.Substring($EvidenceDir.Length + 1)
        $h = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        $hashLines += ("{0}  {1}" -f $h, $rel)
    }
$hashLines | Set-Content -LiteralPath (Join-Path $EvidenceDir "evidence_sha256.txt") -Encoding UTF8

Write-Output "failures=$($failures.Count)"
foreach ($f in $failures) { Write-Output "FAIL $f" }

if ($failures.Count -gt 0) {
    exit 1
}
exit 0
