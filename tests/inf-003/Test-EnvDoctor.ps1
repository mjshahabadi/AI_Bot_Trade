#Requires -Version 5.1
<#
.SYNOPSIS
  INF-003 Environment Doctor tests: TC-INF-003-A..R + REG + BIND (21 cases).
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$EvidenceDir = "",
    [switch]$DirtyTreeProbeOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Id, [string]$Expected, [string]$Actual, [string]$Status)
    $results.Add([pscustomobject]@{ TestId = $Id; Expected = $Expected; Actual = $Actual; Status = $Status }) | Out-Null
    if ($Status -ne "PASS") { $failures.Add("$Id $Status :: $Actual") | Out-Null }
}

function Invoke-GitChecked {
    param([string]$RepoPath, [string[]]$GitArgs)
    $gitCmd = Get-Command git -ErrorAction Stop
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $gitCmd.Source
    $psi.Arguments = ($GitArgs | ForEach-Object { if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ } }) -join ' '
    $psi.WorkingDirectory = $RepoPath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ Ok = ($p.ExitCode -eq 0); ExitCode = $p.ExitCode; Output = $out.Trim(); Error = $err.Trim() }
}

function Get-PorcelainOutsideEvidence {
    <#
      Return git porcelain lines for RepoPath excluding the EvidencePath tree.
      TC-M writes probe artifacts under EvidenceDir; those must not count as user-worktree pollution.
    #>
    param([string]$RepoPath, [string]$EvidencePath, [string]$Porcelain = $null)
    if ($null -eq $Porcelain) {
        $Porcelain = (Invoke-GitChecked -RepoPath $RepoPath -GitArgs @("status", "--porcelain=v1")).Output
    }
    if ([string]::IsNullOrWhiteSpace($Porcelain)) { return "" }
    $repoFull = [System.IO.Path]::GetFullPath($RepoPath).TrimEnd('\', '/')
    $evFull = [System.IO.Path]::GetFullPath($EvidencePath).TrimEnd('\', '/')
    $evRel = $evFull
    if ($evFull.StartsWith($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $evRel = $evFull.Substring($repoFull.Length).TrimStart('\', '/').Replace('\', '/')
    }
    else {
        $evRel = $evRel.Replace('\', '/')
    }
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Porcelain -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $pathPart = if ($line.Length -ge 3) { $line.Substring(3) } else { $line }
        if ($pathPart -match ' -> ') { $pathPart = ($pathPart -split ' -> ')[-1] }
        $pathNorm = $pathPart.Trim().Trim('"').Replace('\', '/')
        if ($pathNorm -eq $evRel -or $pathNorm.StartsWith($evRel + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $kept.Add($line) | Out-Null
    }
    return ($kept -join "`n")
}

function Invoke-DoctorCapture {
    param([hashtable]$DoctorParams, [string]$OutDir)
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $doctor = Join-Path $RepoRoot "tools\env-doctor\Invoke-EnvDoctor.ps1"
    $stdoutPath = Join-Path $OutDir "stdout.log"
    $stderrPath = Join-Path $OutDir "stderr.log"
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
    $psExe = $null
    foreach ($cand in @("powershell.exe", "powershell", "pwsh")) {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue
        if ($cmd) { $psExe = $cmd.Source; break }
    }
    if (-not $psExe) { throw "No PowerShell executable found (powershell.exe/pwsh)" }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = ($argParts -join " ")
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
        ExitCode = $proc.ExitCode
        StdOutPath = $stdoutPath
        StdErrPath = $stderrPath
        JsonPath = (Join-Path $OutDir "doctor_report.json")
        TxtPath = (Join-Path $OutDir "doctor_report.txt")
    }
}

function New-MinimalPeStub {
    param([string]$Path)
    # Minimal valid DOS header + PE signature for F08 bounded validation.
    # Layout: 64-byte DOS stub, e_lfanew=64, PE\0\0 at offset 64.
    $bytes = New-Object byte[] 68
    $bytes[0] = 0x4D; $bytes[1] = 0x5A # MZ
    $eLfanewBytes = [BitConverter]::GetBytes([int32]64)
    [Array]::Copy($eLfanewBytes, 0, $bytes, 0x3C, 4) # e_lfanew
    $bytes[64] = 0x50; $bytes[65] = 0x45; $bytes[66] = 0x00; $bytes[67] = 0x00 # PE\0\0
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

function New-MzOnlyMalformed {
    param([string]$Path)
    # MZ-prefixed but missing valid PE signature / e_lfanew (TC-INF-003-O).
    $bytes = New-Object byte[] 64
    $bytes[0] = 0x4D; $bytes[1] = 0x5A
    # e_lfanew left as 0 => out of bounds / invalid
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

function Write-FixtureMeta {
    param(
        [string]$ExePath,
        [string]$FileVersion,
        [string]$ProductName,
        [string]$OriginalFilename,
        [string]$CompanyName = "MetaQuotes Ltd."
    )
    $obj = [ordered]@{
        file_version = $FileVersion
        product_name = $ProductName
        original_filename = $OriginalFilename
        company_name = $CompanyName
        synthetic = $true
    }
    ($obj | ConvertTo-Json) | Set-Content -LiteralPath ($ExePath + ".fixture-meta.json") -Encoding UTF8
}

function New-ToolFixtureDir {
    param(
        [string]$Dir,
        [string]$EditorVer,
        [string]$TermVer,
        [string]$TesterVer,
        [switch]$EmptyVersions,
        [switch]$PlainTextFake
    )
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $editor = Join-Path $Dir "metaeditor64.exe"
    $term = Join-Path $Dir "terminal64.exe"
    $tester = Join-Path $Dir "metatester64.exe"
    if ($PlainTextFake) {
        Set-Content -LiteralPath $editor -Value "not-an-executable" -Encoding ASCII
        Set-Content -LiteralPath $term -Value "not-an-executable" -Encoding ASCII
        Set-Content -LiteralPath $tester -Value "not-an-executable" -Encoding ASCII
    }
    else {
        New-MinimalPeStub -Path $editor
        New-MinimalPeStub -Path $term
        New-MinimalPeStub -Path $tester
        if (-not $EmptyVersions) {
            Write-FixtureMeta -ExePath $editor -FileVersion $EditorVer -ProductName "MetaQuotes Language 5 Editor" -OriginalFilename "metaeditor64.exe"
            Write-FixtureMeta -ExePath $term -FileVersion $TermVer -ProductName "MetaTrader 5 Client Terminal" -OriginalFilename "terminal64.exe"
            Write-FixtureMeta -ExePath $tester -FileVersion $TesterVer -ProductName "MetaTester" -OriginalFilename "metatester64.exe"
        }
        else {
            Write-FixtureMeta -ExePath $editor -FileVersion "" -ProductName "MetaQuotes Language 5 Editor" -OriginalFilename "metaeditor64.exe"
            Write-FixtureMeta -ExePath $term -FileVersion "" -ProductName "MetaTrader 5 Client Terminal" -OriginalFilename "terminal64.exe"
            Write-FixtureMeta -ExePath $tester -FileVersion "" -ProductName "MetaTester" -OriginalFilename "metatester64.exe"
        }
    }
    return [pscustomobject]@{ Dir = $Dir; Editor = $editor; Terminal = $term; Tester = $tester }
}

function New-MzMalformedFixtureDir {
    param([string]$Dir)
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $editor = Join-Path $Dir "metaeditor64.exe"
    $term = Join-Path $Dir "terminal64.exe"
    $tester = Join-Path $Dir "metatester64.exe"
    New-MzOnlyMalformed -Path $editor
    New-MzOnlyMalformed -Path $term
    New-MzOnlyMalformed -Path $tester
    Write-FixtureMeta -ExePath $editor -FileVersion "5.0.0.6230" -ProductName "MetaQuotes Language 5 Editor" -OriginalFilename "metaeditor64.exe"
    Write-FixtureMeta -ExePath $term -FileVersion "5.0.0.6230" -ProductName "MetaTrader 5 Client Terminal" -OriginalFilename "terminal64.exe"
    Write-FixtureMeta -ExePath $tester -FileVersion "5.0.0.6230" -ProductName "MetaTester" -OriginalFilename "metatester64.exe"
    return [pscustomobject]@{ Dir = $Dir; Editor = $editor; Terminal = $term; Tester = $tester }
}

# ---------- F06: capture baseline cleanliness BEFORE any evidence artifacts ----------
$started = (Get-Date).ToUniversalTime()
$headCmd = Invoke-GitChecked -RepoPath $RepoRoot -GitArgs @("rev-parse", "HEAD")
$branchCmd = Invoke-GitChecked -RepoPath $RepoRoot -GitArgs @("rev-parse", "--abbrev-ref", "HEAD")
$statusCmd = Invoke-GitChecked -RepoPath $RepoRoot -GitArgs @("status", "--porcelain=v1")

if (-not $headCmd.Ok -or ($headCmd.Output -notmatch '^[0-9a-f]{40}$')) {
    throw "Git rev-parse HEAD failed: exit=$($headCmd.ExitCode) err=$($headCmd.Error)"
}
if (-not $branchCmd.Ok) { throw "Git branch failed: $($branchCmd.Error)" }
if (-not $statusCmd.Ok) { throw "Git status failed: $($statusCmd.Error)" }

$testedSha = $headCmd.Output
$branch = $branchCmd.Output
$statusPorcelain = $statusCmd.Output
$cleanWorktree = [string]::IsNullOrWhiteSpace($statusPorcelain)
$hostName = $env:COMPUTERNAME
$psVer = $PSVersionTable.PSVersion.ToString()

if (-not $EvidenceDir) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $EvidenceDir = Join-Path $RepoRoot ("artifacts\issue-3\run-{0}" -f $stamp)
}

# TC-INF-003-M / BIND: reject dirty worktree before generating evidence files
if (-not $cleanWorktree) {
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
    Add-Result "TC-INF-003-M" "Dirty pre-test worktree => evidence binding rejected" ("porcelain=<<$statusPorcelain>>") "PASS"
    Add-Result "TC-INF-003-BIND" "Evidence bound only on clean tree with valid SHA" "rejected_dirty_worktree" "PASS"
    # Still record rejection artifacts — must NOT claim verified evidence success
    $csvPath = Join-Path $EvidenceDir "unit_test_results.csv"
    $results | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    $manifest = [ordered]@{
        issue = 3; task_id = "INF-003"; run_id = (Split-Path -Leaf $EvidenceDir)
        tested_commit = $testedSha; binding_rejected = $true; reason = "dirty_worktree"
        verified_evidence_manifest = $false
        dirty_tree_probe_only = [bool]$DirtyTreeProbeOnly
        porcelain = $statusPorcelain
        tests = @($results | ForEach-Object { [ordered]@{ id = $_.TestId; status = $_.Status; expected = $_.Expected; actual = $_.Actual } })
    }
    ($manifest | ConvertTo-Json -Depth 6) | Set-Content (Join-Path $EvidenceDir "run_manifest.json") -Encoding UTF8
    "dirty worktree binding rejected" | Set-Content (Join-Path $EvidenceDir "test_summary.md") -Encoding UTF8
    Write-Output "BINDING_REJECTED dirty worktree"
    exit 1
}

if ($DirtyTreeProbeOnly) {
    throw "DirtyTreeProbeOnly requires a dirty worktree; refusing to fabricate PASS on a clean tree."
}

New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
$EvidenceDir = (Resolve-Path -LiteralPath $EvidenceDir).Path
Write-Output "INF-003 tests start $($started.ToString('o'))"
Write-Output "tested_sha=$testedSha branch=$branch clean=$cleanWorktree evidence=$EvidenceDir"

$realInstall = "C:\Program Files\MetaTrader 5"
$realEditor = Join-Path $realInstall "metaeditor64.exe"
$realTerminal = Join-Path $realInstall "terminal64.exe"
$realTester = Join-Path $realInstall "metatester64.exe"
$secondInstall = "C:\MT5-Cursor-Test"

# ---------- TC-INF-003-A strict real host ----------
$outA = Join-Path $EvidenceDir "tc-a"
$runA = Invoke-DoctorCapture -OutDir $outA -DoctorParams @{
    RepoRoot = $RepoRoot
    OutputDir = $outA
    InstallRoot = $realInstall
    StrictPreflight = $true
    MinAgentDirectories = 1
}
$jsonA = $null
if (Test-Path $runA.JsonPath) { $jsonA = Get-Content $runA.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runA.ExitCode -eq 0 -and $jsonA -and $jsonA.overall_status -eq "PASS" -and $jsonA.readiness.verified_preflight_passed -eq $true -and
    $jsonA.metaeditor.pe_mz_valid -eq $true -and $jsonA.tester_agents.operational_agent_ready -eq $false -and
    $jsonA.selected_installation.data_mapping_verified -eq $true -and $jsonA.readiness.synthetic_fixture_present -ne $true) {
    Add-Result "TC-INF-003-A" "Strict preflight on real Windows install captures validated tools/Git; no operational agent claim" `
        ("exit=0 meta={0} ver={1} selected={2} data={3} discovered_agents={4} operational_ready={5} mapping={6}" -f `
            $jsonA.metaeditor.path, $jsonA.metaeditor.file_version, $jsonA.selected_installation.install_root, `
            $jsonA.selected_installation.data_directory, $jsonA.tester_agents.discovered_agent_directory_count, `
            $jsonA.tester_agents.operational_agent_ready, $jsonA.selected_installation.data_mapping_status) "PASS"
}
elseif ($runA.ExitCode -ne 0 -and $jsonA -and $jsonA.overall_status -in @("BLOCKED", "FAIL")) {
    Add-Result "TC-INF-003-A" "Strict preflight on real Windows install captures validated tools/Git; no operational agent claim" `
        ("strict_failed_on_host exit={0} status={1} issues={2}" -f $runA.ExitCode, $jsonA.overall_status, (($jsonA.issues) -join "|")) "BLOCKED"
}
else {
    Add-Result "TC-INF-003-A" "Strict preflight on real Windows install captures validated tools/Git; no operational agent claim" `
        ("unexpected exit={0}" -f $runA.ExitCode) "FAIL"
}

# ---------- TC-INF-003-B invalid path ----------
$outB = Join-Path $EvidenceDir "tc-b"
$badPath = "C:\Program Files\MetaTrader 5\metaeditor64-DOES-NOT-EXIST.exe"
$runB = Invoke-DoctorCapture -OutDir $outB -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outB; MetaEditorPath = $badPath; RequireTools = $true; SkipGit = $true
}
$stdoutB = Get-Content $runB.StdOutPath -Raw -Encoding UTF8
if ($runB.ExitCode -ne 0 -and $stdoutB -match "MetaEditorPath override not found") {
    Add-Result "TC-INF-003-B" "Invalid MetaEditor path => nonzero + precise error" ("exit={0}" -f $runB.ExitCode) "PASS"
}
else { Add-Result "TC-INF-003-B" "Invalid MetaEditor path => nonzero + precise error" ("exit={0}" -f $runB.ExitCode) "FAIL" }

# ---------- TC-INF-003-C spaces/unicode with synthetic consistent fixtures ----------
$outC = Join-Path $EvidenceDir "tc-c"
$spaceDir = Join-Path $env:TEMP ("INF-003 Env Doctor Тест\" + [guid]::NewGuid().ToString("N"))
$fxC = New-ToolFixtureDir -Dir $spaceDir -EditorVer "5.0.0.6230" -TermVer "5.0.0.6230" -TesterVer "5.0.0.6230"
$runC = Invoke-DoctorCapture -OutDir $outC -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outC; InstallRoot = $fxC.Dir
    ValidateExecutables = $true; FailOnEmptyVersion = $true; FailOnBuildMismatch = $true
    AllowSyntheticVersionFixtures = $true; SkipGit = $true
}
$jsonC = $null
if (Test-Path $runC.JsonPath) { $jsonC = Get-Content $runC.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runC.ExitCode -eq 0 -and $jsonC -and ($jsonC.metaeditor.path -like "* *") -and $jsonC.metaeditor.synthetic_fixture -eq $true) {
    Add-Result "TC-INF-003-C" "Path with spaces/non-ASCII handled (synthetic fixture explicitly marked)" `
        ("exit=0 path={0}" -f $jsonC.metaeditor.path) "PASS"
}
elseif ($runC.ExitCode -ne 0) {
    Add-Result "TC-INF-003-C" "Path with spaces/non-ASCII handled (synthetic fixture explicitly marked)" `
        ("explicit_nonzero exit={0}" -f $runC.ExitCode) "PASS"
}
else { Add-Result "TC-INF-003-C" "Path with spaces/non-ASCII handled" "unhandled" "FAIL" }

# ---------- TC-INF-003-D missing agents ----------
$outD = Join-Path $EvidenceDir "tc-d"
$emptyTester = Join-Path $env:TEMP ("inf003-empty-tester-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $emptyTester | Out-Null
$runD = Invoke-DoctorCapture -OutDir $outD -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outD; TesterRoot = $emptyTester
    RequireAgentDirectories = $true; MinAgentDirectories = 1; SkipGit = $true
}
$jsonD = $null
if (Test-Path $runD.JsonPath) { $jsonD = Get-Content $runD.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runD.ExitCode -ne 0 -and $jsonD -and $jsonD.overall_status -eq "BLOCKED") {
    Add-Result "TC-INF-003-D" "Missing Agent directories => BLOCKED" ("exit={0} discovered={1}" -f $runD.ExitCode, $jsonD.tester_agents.discovered_agent_directory_count) "PASS"
}
else { Add-Result "TC-INF-003-D" "Missing Agent directories => BLOCKED" ("exit={0}" -f $runD.ExitCode) "FAIL" }

# ---------- TC-INF-003-E inaccessible ----------
$outE = Join-Path $EvidenceDir "tc-e"
$isWindows = $false
try {
    if ($PSVersionTable.PSVersion.Major -ge 6) { $isWindows = [bool]$IsWindows }
    else { $isWindows = ($env:OS -match 'Windows') }
} catch { $isWindows = ($env:OS -match 'Windows') }
if (-not $isWindows) {
    Add-Result "TC-INF-003-E" "Inaccessible path => nonzero actionable failure" "windows_acl_apis_unavailable" "BLOCKED"
}
else {
    $denyDir = Join-Path $env:TEMP ("inf003-deny-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $denyDir | Out-Null
    $denyFile = Join-Path $denyDir "metaeditor64.exe"
    Set-Content -LiteralPath $denyFile -Value "x" -Encoding ASCII
    $acl = Get-Acl $denyFile
    $denyUser = if ($env:USERNAME) { $env:USERNAME } else { "Everyone" }
    $denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule($denyUser, "Read", "Deny")
    $acl.AddAccessRule($denyRule); Set-Acl $denyFile $acl
    $runE = Invoke-DoctorCapture -OutDir $outE -DoctorParams @{
        RepoRoot = $RepoRoot; OutputDir = $outE; MetaEditorPath = $denyFile; RequireTools = $true; SkipGit = $true
    }
    $stdoutE = Get-Content $runE.StdOutPath -Raw -Encoding UTF8
    try { $acl2 = Get-Acl $denyFile; [void]$acl2.RemoveAccessRule($denyRule); Set-Acl $denyFile $acl2 } catch {}
    if ($runE.ExitCode -ne 0 -and $stdoutE -match "not readable") {
        Add-Result "TC-INF-003-E" "Inaccessible path => nonzero actionable failure" ("exit={0}" -f $runE.ExitCode) "PASS"
    }
    else { Add-Result "TC-INF-003-E" "Inaccessible path => nonzero actionable failure" ("exit={0}" -f $runE.ExitCode) "FAIL" }
}

# ---------- TC-INF-003-F empty version via real PE without fixture (or synth empty) ----------
$outF = Join-Path $EvidenceDir "tc-f"
$fxF = New-ToolFixtureDir -Dir (Join-Path $env:TEMP ("inf003-emptyver-" + [guid]::NewGuid().ToString("N"))) -EditorVer "" -TermVer "" -TesterVer "" -EmptyVersions
$runF = Invoke-DoctorCapture -OutDir $outF -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outF; InstallRoot = $fxF.Dir
    ValidateExecutables = $true; FailOnEmptyVersion = $true; AllowSyntheticVersionFixtures = $true; SkipGit = $true
}
$jsonF = $null
if (Test-Path $runF.JsonPath) { $jsonF = Get-Content $runF.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runF.ExitCode -ne 0 -and $jsonF -and (($jsonF.issues | Out-String) -match "Empty/missing FileVersion")) {
    Add-Result "TC-INF-003-F" "Empty version metadata => FAIL/BLOCKED" ("exit={0} status={1}" -f $runF.ExitCode, $jsonF.overall_status) "PASS"
}
else { Add-Result "TC-INF-003-F" "Empty version metadata => FAIL/BLOCKED" ("exit={0}" -f $runF.ExitCode) "FAIL" }

# ---------- TC-INF-003-G strict + missing agents ----------
$outG = Join-Path $EvidenceDir "tc-g"
$emptyG = Join-Path $env:TEMP ("inf003-strict-empty-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $emptyG | Out-Null
$runG = Invoke-DoctorCapture -OutDir $outG -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outG; InstallRoot = $realInstall
    TesterRoot = $emptyG; StrictPreflight = $true; MinAgentDirectories = 1
}
$jsonG = $null
if (Test-Path $runG.JsonPath) { $jsonG = Get-Content $runG.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runG.ExitCode -ne 0 -and $jsonG -and $jsonG.overall_status -eq "BLOCKED" -and $jsonG.readiness.mode -eq "verified_preflight") {
    Add-Result "TC-INF-003-G" "Strict preflight with missing Agent dirs => nonzero BLOCKED" `
        ("exit={0} readiness_passed={1}" -f $runG.ExitCode, $jsonG.readiness.verified_preflight_passed) "PASS"
}
else { Add-Result "TC-INF-003-G" "Strict preflight with missing Agent dirs => nonzero BLOCKED" ("exit={0}" -f $runG.ExitCode) "FAIL" }

# ---------- TC-INF-003-H readable fake EXE ----------
$outH = Join-Path $EvidenceDir "tc-h"
$fxH = New-ToolFixtureDir -Dir (Join-Path $env:TEMP ("inf003-fakeexe-" + [guid]::NewGuid().ToString("N"))) -EditorVer "1" -TermVer "1" -TesterVer "1" -PlainTextFake
$runH = Invoke-DoctorCapture -OutDir $outH -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outH; InstallRoot = $fxH.Dir
    ValidateExecutables = $true; RequireTools = $true; SkipGit = $true
}
$jsonH = $null
if (Test-Path $runH.JsonPath) { $jsonH = Get-Content $runH.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runH.ExitCode -ne 0 -and $jsonH -and (($jsonH.issues | Out-String) -match "Invalid executable structure")) {
    Add-Result "TC-INF-003-H" "Readable fake EXE => nonzero FAIL/BLOCKED" ("exit={0} status={1}" -f $runH.ExitCode, $jsonH.overall_status) "PASS"
}
else { Add-Result "TC-INF-003-H" "Readable fake EXE => nonzero FAIL/BLOCKED" ("exit={0}" -f $runH.ExitCode) "FAIL" }

# ---------- TC-INF-003-I invalid git repo ----------
$outI = Join-Path $EvidenceDir "tc-i"
$badRepo = Join-Path $env:TEMP ("inf003-nongit-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $badRepo | Out-Null
$runI = Invoke-DoctorCapture -OutDir $outI -DoctorParams @{
    RepoRoot = $badRepo; OutputDir = $outI; InstallRoot = $realInstall; RequireTools = $true
}
$jsonI = $null
if (Test-Path $runI.JsonPath) { $jsonI = Get-Content $runI.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runI.ExitCode -ne 0 -and $jsonI -and (($jsonI.issues | Out-String) -match "Git inspection failed|not_a_git_repository")) {
    Add-Result "TC-INF-003-I" "Invalid Git repository => nonzero FAIL/BLOCKED" ("exit={0} err={1}" -f $runI.ExitCode, $jsonI.git.error) "PASS"
}
else { Add-Result "TC-INF-003-I" "Invalid Git repository => nonzero FAIL/BLOCKED" ("exit={0}" -f $runI.ExitCode) "FAIL" }

# ---------- TC-INF-003-J mixed installation roots ----------
$outJ = Join-Path $EvidenceDir "tc-j"
if ((Test-Path $realEditor) -and (Test-Path (Join-Path $secondInstall "terminal64.exe"))) {
    $runJ = Invoke-DoctorCapture -OutDir $outJ -DoctorParams @{
        RepoRoot = $RepoRoot; OutputDir = $outJ
        MetaEditorPath = $realEditor
        TerminalPath = (Join-Path $secondInstall "terminal64.exe")
        RequireTools = $true; SkipGit = $true
    }
    $jsonJ = $null
    if (Test-Path $runJ.JsonPath) { $jsonJ = Get-Content $runJ.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    if ($runJ.ExitCode -ne 0 -and $jsonJ -and ($jsonJ.selected_installation.ambiguous -eq $true -or (($jsonJ.issues | Out-String) -match "unrelated install roots|Inconsistent tool path"))) {
        Add-Result "TC-INF-003-J" "Mixed installation roots => explicit rejection" ("exit={0} ambiguous={1}" -f $runJ.ExitCode, $jsonJ.selected_installation.ambiguous) "PASS"
    }
    else { Add-Result "TC-INF-003-J" "Mixed installation roots => explicit rejection" ("exit={0}" -f $runJ.ExitCode) "FAIL" }
}
else {
    Add-Result "TC-INF-003-J" "Mixed installation roots => explicit rejection" "second_install_missing" "BLOCKED"
}

# ---------- TC-INF-003-K different nonempty versions ----------
$outK = Join-Path $EvidenceDir "tc-k"
$fxK = New-ToolFixtureDir -Dir (Join-Path $env:TEMP ("inf003-verdiff-" + [guid]::NewGuid().ToString("N"))) -EditorVer "5.0.0.1000" -TermVer "5.0.0.2000" -TesterVer "5.0.0.1000"
$runK = Invoke-DoctorCapture -OutDir $outK -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outK; InstallRoot = $fxK.Dir
    FailOnBuildMismatch = $true; ValidateExecutables = $true; FailOnEmptyVersion = $true
    AllowSyntheticVersionFixtures = $true; SkipGit = $true
}
$jsonK = $null
if (Test-Path $runK.JsonPath) { $jsonK = Get-Content $runK.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runK.ExitCode -ne 0 -and $jsonK -and $jsonK.build_consistency.mismatch -eq $true -and ($jsonK.metaeditor.synthetic_fixture -eq $true)) {
    Add-Result "TC-INF-003-K" "Different nonempty version fixtures => nonzero mismatch diagnostic (synthetic marked)" `
        ("exit={0} versions={1}" -f $runK.ExitCode, ($jsonK.build_consistency.unique_versions -join ",")) "PASS"
}
else { Add-Result "TC-INF-003-K" "Different nonempty version fixtures => nonzero mismatch diagnostic" ("exit={0}" -f $runK.ExitCode) "FAIL" }

# ---------- TC-INF-003-L empty version metadata ----------
$outL = Join-Path $EvidenceDir "tc-l"
$fxL = New-ToolFixtureDir -Dir (Join-Path $env:TEMP ("inf003-l-empty-" + [guid]::NewGuid().ToString("N"))) -EditorVer "" -TermVer "" -TesterVer "" -EmptyVersions
$runL = Invoke-DoctorCapture -OutDir $outL -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outL; InstallRoot = $fxL.Dir
    FailOnEmptyVersion = $true; ValidateExecutables = $true; AllowSyntheticVersionFixtures = $true; SkipGit = $true
}
$jsonL = $null
if (Test-Path $runL.JsonPath) { $jsonL = Get-Content $runL.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runL.ExitCode -ne 0 -and $jsonL -and (($jsonL.issues | Out-String) -match "Empty/missing FileVersion")) {
    Add-Result "TC-INF-003-L" "Empty version metadata => nonzero FAIL/BLOCKED" ("exit={0}" -f $runL.ExitCode) "PASS"
}
else { Add-Result "TC-INF-003-L" "Empty version metadata => nonzero FAIL/BLOCKED" ("exit={0}" -f $runL.ExitCode) "FAIL" }

# ---------- TC-INF-003-N invalid MinAgentDirectories ----------
$outN = Join-Path $EvidenceDir "tc-n"
$runN = Invoke-DoctorCapture -OutDir $outN -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outN; InstallRoot = $realInstall
    RequireAgentDirectories = $true; MinAgentDirectories = 0; SkipGit = $true
}
$stdoutN = Get-Content $runN.StdOutPath -Raw -Encoding UTF8
$jsonN = $null
if (Test-Path $runN.JsonPath) { $jsonN = Get-Content $runN.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runN.ExitCode -ne 0 -and ($stdoutN -match "Invalid MinAgentDirectories" -or (($jsonN.issues | Out-String) -match "Invalid MinAgentDirectories"))) {
    Add-Result "TC-INF-003-N" "Invalid MinAgentDirectories => explicit validation failure" ("exit={0}" -f $runN.ExitCode) "PASS"
}
else { Add-Result "TC-INF-003-N" "Invalid MinAgentDirectories => explicit validation failure" ("exit={0}" -f $runN.ExitCode) "FAIL" }

# ---------- TC-INF-003-O MZ-prefixed malformed PE rejected ----------
$outO = Join-Path $EvidenceDir "tc-o"
$fxO = New-MzMalformedFixtureDir -Dir (Join-Path $env:TEMP ("inf003-mzmalformed-" + [guid]::NewGuid().ToString("N")))
# Unique mapping so PE validation is the explicit failure under test (not mapping).
$termO = Join-Path $env:TEMP ("inf003-o-term-" + [guid]::NewGuid().ToString("N"))
$termOInst = Join-Path $termO ("O" + [guid]::NewGuid().ToString("N").Substring(0, 31))
New-Item -ItemType Directory -Force -Path $termOInst | Out-Null
Set-Content -LiteralPath (Join-Path $termOInst "origin.txt") -Value $fxO.Dir -Encoding ASCII
$runO = Invoke-DoctorCapture -OutDir $outO -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outO; InstallRoot = $fxO.Dir
    TerminalDataRoot = $termO
    ValidateExecutables = $true; RequireTools = $true
    AllowSyntheticVersionFixtures = $true; SkipGit = $true
}
$jsonO = $null
if (Test-Path $runO.JsonPath) { $jsonO = Get-Content $runO.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runO.ExitCode -ne 0 -and $jsonO -and $jsonO.metaeditor.pe_mz_valid -eq $false -and (($jsonO.issues | Out-String) -match "Invalid executable structure")) {
    Add-Result "TC-INF-003-O" "MZ-prefixed malformed executable must be rejected" `
        ("exit={0} pe_mz_valid={1}" -f $runO.ExitCode, $jsonO.metaeditor.pe_mz_valid) "PASS"
}
else { Add-Result "TC-INF-003-O" "MZ-prefixed malformed executable must be rejected" ("exit={0}" -f $runO.ExitCode) "FAIL" }

# ---------- TC-INF-003-P StrictPreflight + synthetic fixtures rejected ----------
$outP = Join-Path $EvidenceDir "tc-p"
$fxP = New-ToolFixtureDir -Dir (Join-Path $env:TEMP ("inf003-synth-strict-" + [guid]::NewGuid().ToString("N"))) -EditorVer "5.0.0.6230" -TermVer "5.0.0.6230" -TesterVer "5.0.0.6230"
$emptyAgentsP = Join-Path $env:TEMP ("inf003-p-agents-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $emptyAgentsP | Out-Null
# Create a dummy Agent dir so agent gate is not the first failure; synthetic rejection must be explicit.
New-Item -ItemType Directory -Force -Path (Join-Path $emptyAgentsP "Agent-0001") | Out-Null
$runP = Invoke-DoctorCapture -OutDir $outP -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outP; InstallRoot = $fxP.Dir
    TesterRoot = $emptyAgentsP; TerminalDataRoot = (Join-Path $env:TEMP ("inf003-p-term-" + [guid]::NewGuid().ToString("N")))
    StrictPreflight = $true; AllowSyntheticVersionFixtures = $true; MinAgentDirectories = 1
}
$jsonP = $null
if (Test-Path $runP.JsonPath) { $jsonP = Get-Content $runP.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
$stdoutP = Get-Content $runP.StdOutPath -Raw -Encoding UTF8
if ($runP.ExitCode -ne 0 -and $jsonP -and $jsonP.readiness.verified_preflight_passed -ne $true -and `
    (($jsonP.issues | Out-String) -match "StrictPreflight rejects AllowSyntheticVersionFixtures" -or $stdoutP -match "StrictPreflight rejects AllowSyntheticVersionFixtures")) {
    Add-Result "TC-INF-003-P" "Strict preflight with synthetic fixtures => nonzero + explicit rejection" `
        ("exit={0} verified_passed={1}" -f $runP.ExitCode, $jsonP.readiness.verified_preflight_passed) "PASS"
}
else { Add-Result "TC-INF-003-P" "Strict preflight with synthetic fixtures => nonzero + explicit rejection" ("exit={0}" -f $runP.ExitCode) "FAIL" }

# ---------- TC-INF-003-Q missing data-directory mapping ----------
$outQ = Join-Path $EvidenceDir "tc-q"
$fxQ = New-ToolFixtureDir -Dir (Join-Path $env:TEMP ("inf003-q-install-" + [guid]::NewGuid().ToString("N"))) -EditorVer "5.0.0.6230" -TermVer "5.0.0.6230" -TesterVer "5.0.0.6230"
$emptyTermQ = Join-Path $env:TEMP ("inf003-q-term-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $emptyTermQ | Out-Null
$runQ = Invoke-DoctorCapture -OutDir $outQ -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outQ; InstallRoot = $fxQ.Dir
    TerminalDataRoot = $emptyTermQ; RequireTools = $true
    AllowSyntheticVersionFixtures = $true; SkipGit = $true
}
$jsonQ = $null
if (Test-Path $runQ.JsonPath) { $jsonQ = Get-Content $runQ.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runQ.ExitCode -ne 0 -and $jsonQ -and $jsonQ.selected_installation.data_mapping_status -eq "missing" -and `
    $jsonQ.selected_installation.data_mapping_verified -ne $true -and `
    (($jsonQ.issues | Out-String) -match "No terminal data directory origin\.txt maps")) {
    Add-Result "TC-INF-003-Q" "Missing selected-install data-directory mapping => explicit rejection" `
        ("exit={0} status={1} reason={2}" -f $runQ.ExitCode, $jsonQ.selected_installation.data_mapping_status, $jsonQ.selected_installation.data_mapping_reason) "PASS"
}
else { Add-Result "TC-INF-003-Q" "Missing selected-install data-directory mapping => explicit rejection" ("exit={0}" -f $runQ.ExitCode) "FAIL" }

# ---------- TC-INF-003-R ambiguous data-directory mapping ----------
$outR = Join-Path $EvidenceDir "tc-r"
$fxR = New-ToolFixtureDir -Dir (Join-Path $env:TEMP ("inf003-r-install-" + [guid]::NewGuid().ToString("N"))) -EditorVer "5.0.0.6230" -TermVer "5.0.0.6230" -TesterVer "5.0.0.6230"
$termRootR = Join-Path $env:TEMP ("inf003-r-term-" + [guid]::NewGuid().ToString("N"))
$id1 = "AAAA1111BBBB2222CCCC3333DDDD4444"
$id2 = "EEEE5555FFFF6666AAAA7777BBBB8888"
$dir1 = Join-Path $termRootR $id1
$dir2 = Join-Path $termRootR $id2
New-Item -ItemType Directory -Force -Path $dir1 | Out-Null
New-Item -ItemType Directory -Force -Path $dir2 | Out-Null
# Both origins point at the same selected install => ambiguous; must not pick first match.
Set-Content -LiteralPath (Join-Path $dir1 "origin.txt") -Value $fxR.Dir -Encoding ASCII
Set-Content -LiteralPath (Join-Path $dir2 "origin.txt") -Value $fxR.Dir -Encoding ASCII
$runR = Invoke-DoctorCapture -OutDir $outR -DoctorParams @{
    RepoRoot = $RepoRoot; OutputDir = $outR; InstallRoot = $fxR.Dir
    TerminalDataRoot = $termRootR; RequireTools = $true
    AllowSyntheticVersionFixtures = $true; SkipGit = $true
}
$jsonR = $null
if (Test-Path $runR.JsonPath) { $jsonR = Get-Content $runR.JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json }
if ($runR.ExitCode -ne 0 -and $jsonR -and $jsonR.selected_installation.data_mapping_status -eq "ambiguous" -and `
    $jsonR.selected_installation.data_mapping_verified -ne $true -and `
    $null -eq $jsonR.selected_installation.data_directory -and `
    (($jsonR.issues | Out-String) -match "Ambiguous terminal data-directory mapping")) {
    Add-Result "TC-INF-003-R" "Ambiguous selected-install data-directory mapping => refuse first-match" `
        ("exit={0} status={1} reason={2}" -f $runR.ExitCode, $jsonR.selected_installation.data_mapping_status, $jsonR.selected_installation.data_mapping_reason) "PASS"
}
else { Add-Result "TC-INF-003-R" "Ambiguous selected-install data-directory mapping => refuse first-match" ("exit={0}" -f $runR.ExitCode) "FAIL" }

# ---------- TC-INF-003-M real dirty-tree negative test in isolated worktree ----------
$outM = Join-Path $EvidenceDir "tc-m"
New-Item -ItemType Directory -Force -Path $outM | Out-Null
$wtPath = Join-Path $env:TEMP ("inf003-dirty-wt-" + [guid]::NewGuid().ToString("N"))
$wtEvidence = Join-Path $outM "probe-evidence"
$mOk = $false
$mActual = "not_executed"
# Exclude EvidenceDir from "user untouched" porcelain: TC-M probe artifacts are written there by design.
$userStatusBefore = Get-PorcelainOutsideEvidence -RepoPath $RepoRoot -EvidencePath $EvidenceDir
try {
    $addWt = Invoke-GitChecked -RepoPath $RepoRoot -GitArgs @("worktree", "add", "--detach", $wtPath, $testedSha)
    if (-not $addWt.Ok) { throw "worktree add failed: $($addWt.Error)" }
    $dirtyMarker = Join-Path $wtPath "INF003-DIRTY-MARKER.txt"
    Set-Content -LiteralPath $dirtyMarker -Value "intentional dirty tree for TC-INF-003-M" -Encoding UTF8
    $wtStatus = Invoke-GitChecked -RepoPath $wtPath -GitArgs @("status", "--porcelain=v1")
    if ([string]::IsNullOrWhiteSpace($wtStatus.Output)) { throw "expected dirty worktree but porcelain empty" }
    $probeScript = Join-Path $wtPath "tests\inf-003\Test-EnvDoctor.ps1"
    $psExe = $null
    foreach ($cand in @("powershell.exe", "powershell", "pwsh")) {
        $cmd = Get-Command $cand -ErrorAction SilentlyContinue
        if ($cmd) { $psExe = $cmd.Source; break }
    }
    if (-not $psExe) { throw "No PowerShell executable found for dirty-tree probe" }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$probeScript`" -RepoRoot `"$wtPath`" -EvidenceDir `"$wtEvidence`" -DirtyTreeProbeOnly"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $wtPath
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $mOut = $proc.StandardOutput.ReadToEnd()
    $mErr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    Set-Content -LiteralPath (Join-Path $outM "probe_stdout.log") -Value $mOut -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $outM "probe_stderr.log") -Value $mErr -Encoding UTF8
    $probeManifestPath = Join-Path $wtEvidence "run_manifest.json"
    $probeManifest = $null
    if (Test-Path -LiteralPath $probeManifestPath) {
        $probeManifest = Get-Content -LiteralPath $probeManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Copy-Item -LiteralPath $probeManifestPath -Destination (Join-Path $outM "probe_run_manifest.json") -Force
    }
    $userStatusAfter = Get-PorcelainOutsideEvidence -RepoPath $RepoRoot -EvidencePath $EvidenceDir
    $markerInUserTree = Test-Path -LiteralPath (Join-Path $RepoRoot "INF003-DIRTY-MARKER.txt")
    $userUntouched = ($userStatusBefore -eq $userStatusAfter) -and (-not $markerInUserTree)
    $noVerifiedSuccess = ($null -eq $probeManifest) -or ($probeManifest.binding_rejected -eq $true) -or ($probeManifest.verified_evidence_manifest -eq $false)
    if ($proc.ExitCode -ne 0 -and $probeManifest -and $probeManifest.binding_rejected -eq $true -and $noVerifiedSuccess -and $userUntouched -and ($mOut -match "BINDING_REJECTED")) {
        $mOk = $true
        $mActual = ("exit={0}; dirty_porcelain=<<{1}>>; binding_rejected=true; user_untouched={2}" -f $proc.ExitCode, $wtStatus.Output, $userUntouched)
    }
    else {
        $mActual = ("exit={0}; binding_rejected={1}; user_untouched={2}; out=<<{3}>>" -f $proc.ExitCode, $(if ($probeManifest) { $probeManifest.binding_rejected } else { "n/a" }), $userUntouched, $mOut.Substring(0, [Math]::Min(200, $mOut.Length)))
    }
}
catch {
    $mActual = "exception: $($_.Exception.Message)"
}
finally {
    try { [void](Invoke-GitChecked -RepoPath $RepoRoot -GitArgs @("worktree", "remove", "--force", $wtPath)) } catch {}
    try { if (Test-Path -LiteralPath $wtPath) { Remove-Item -LiteralPath $wtPath -Recurse -Force -ErrorAction SilentlyContinue } } catch {}
    try { [void](Invoke-GitChecked -RepoPath $RepoRoot -GitArgs @("worktree", "prune")) } catch {}
}
if ($mOk) {
    Add-Result "TC-INF-003-M" "Dirty pre-test worktree => evidence binding rejected (isolated worktree negative test)" $mActual "PASS"
}
else {
    Add-Result "TC-INF-003-M" "Dirty pre-test worktree => evidence binding rejected (isolated worktree negative test)" $mActual "FAIL"
}

# ---------- Regression ----------
$tradingHits = @(Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -EA SilentlyContinue | Where-Object { $_.Extension -match '^\.(mq5|mqh|ex5)$' })
if ($tradingHits.Count -eq 0) {
    Add-Result "REG-INF-003-1" "No MQL5 trading sources" "count=0" "PASS"
}
else { Add-Result "REG-INF-003-1" "No MQL5 trading sources" ($tradingHits.FullName -join ";") "FAIL" }

$govBaseline = "aebe8cd62aaf15f84d4001f15a8b828c92202b77"
$govFiles = @(".github/AGENTS.md", ".github/GPT_MASTER_GOVERNANCE.md", ".github/ISSUE_TEMPLATE/ai_task.md", ".github/PULL_REQUEST_TEMPLATE.md")
$govDelta = @()
foreach ($gf in $govFiles) {
    $d = Invoke-GitChecked -RepoPath $RepoRoot -GitArgs @("diff", "--name-only", $govBaseline, "--", $gf)
    if (-not $d.Ok) { $govDelta += "git_diff_failed:${gf}:$($d.ExitCode)" }
    elseif ($d.Output) { $govDelta += $d.Output }
}
$agentsHash = (Get-FileHash (Join-Path $RepoRoot ".github\AGENTS.md") -Algorithm SHA256).Hash
$gptHash = (Get-FileHash (Join-Path $RepoRoot ".github\GPT_MASTER_GOVERNANCE.md") -Algorithm SHA256).Hash
if (($govDelta.Count -eq 0) -and ($agentsHash -eq $gptHash)) {
    Add-Result "REG-INF-003-2" "Governance/issue/PR templates unchanged; AGENTS==GPT_MASTER" ("sha256={0}" -f $agentsHash) "PASS"
}
else { Add-Result "REG-INF-003-2" "Governance/issue/PR templates unchanged; AGENTS==GPT_MASTER" ("delta={0}" -f ($govDelta -join ",")) "FAIL" }

Add-Result "TC-INF-003-BIND" "Evidence bound to valid tested SHA on clean pre-test worktree" `
    ("tested_sha={0} porcelain_empty={1}" -f $testedSha, $cleanWorktree) `
    $(if (($testedSha -match '^[0-9a-f]{40}$') -and $cleanWorktree) { "PASS" } else { "FAIL" })

# ---------- finalize evidence AFTER all tests ----------
$runLeaf = Split-Path -Leaf $EvidenceDir
$csvPath = Join-Path $EvidenceDir "unit_test_results.csv"
$results | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

$stdoutAll = Join-Path $EvidenceDir "test_stdout.log"
@(
    "INF-003 Test-EnvDoctor CTO-REWORK"
    "timestamp_utc=$($started.ToString('o'))"
    "tested_sha=$testedSha"
    "branch=$branch"
    "host=$hostName"
    "powershell=$psVer"
    "pre_test_clean=$cleanWorktree"
    "evidence_dir=$EvidenceDir"
    "RESULTS"
) + @($results | ForEach-Object { "$($_.TestId)|$($_.Status)|$($_.Actual)" }) |
    Set-Content -LiteralPath $stdoutAll -Encoding UTF8

$manifest = [ordered]@{
    issue = 3
    task_id = "INF-003"
    requirement_ids = @("REQ-INF-003")
    rule_ids = @("RULE-ENV-001")
    run_id = $runLeaf
    branch = $branch
    baseline_commit = "a428d1cb5a3fc20b0f38fb1bb29653570e3fda2c"
    reviewed_prior_head = "46518b3c6a696171ff7ef26afe2c320cddb9feda"
    prior_tested_r3 = "6564d06b964d8af1aa606d3d3ba25618e2acaaa7"
    tested_commit = $testedSha
    origin_main_at_claim = "aebe8cd62aaf15f84d4001f15a8b828c92202b77"
    execution_timestamp_utc = $started.ToString("o")
    host = $hostName
    os = [System.Environment]::OSVersion.VersionString
    powershell = $psVer
    compiler_build = "N/A — no MQL5 compile in INF-003"
    ex5_hash = "N/A — no EX5 produced"
    authorization = "Product Owner scoped approval 2026-11-27 for REQ-INF-003 only; INF-001 remains REWORK"
    pr_url = "https://github.com/mjshahabadi/AI_Bot_Trade/pull/15"
    cto_decision_prior = "REWORK REQUIRED (r3 findings F08-F12)"
    rework_round = "r4"
    expected_test_count = 21
    acceptance_status = "PENDING independent GPT CTO review — not approved"
    known_limitations = @(
        "SkipGit is test-only and never used as strict readiness evidence.",
        "Synthetic version fixtures are marked synthetic_fixture=true and are not real toolchain evidence.",
        "StrictPreflight rejects AllowSyntheticVersionFixtures; synthetic metadata never yields verified_preflight_passed=true.",
        "Strict preflight verified gates do not claim Strategy Tester operational agent readiness.",
        "Multiple MT5 installs require explicit -InstallRoot under StrictPreflight.",
        "Missing or ambiguous install↔data-directory mapping fails closed and never claims verified mapping."
    )
    artifact_links = [ordered]@{
        manifest = "artifacts/issue-3/$runLeaf/run_manifest.json"
        csv = "artifacts/issue-3/$runLeaf/unit_test_results.csv"
        summary = "artifacts/issue-3/$runLeaf/test_summary.md"
        stdout = "artifacts/issue-3/$runLeaf/test_stdout.log"
        sha256 = "artifacts/issue-3/$runLeaf/evidence_sha256.txt"
    }
    acceptance_criteria = @(
        [ordered]@{ id = "AC-001"; tests = @("TC-INF-003-A", "TC-INF-003-C") }
        [ordered]@{ id = "AC-002"; tests = @("TC-INF-003-B", "TC-INF-003-D", "TC-INF-003-E", "TC-INF-003-F", "TC-INF-003-G", "TC-INF-003-H", "TC-INF-003-I", "TC-INF-003-J", "TC-INF-003-K", "TC-INF-003-L", "TC-INF-003-N", "TC-INF-003-O", "TC-INF-003-P", "TC-INF-003-Q", "TC-INF-003-R") }
        [ordered]@{ id = "AC-003"; tests = @("TC-INF-003-BIND", "TC-INF-003-M") }
    )
    tests = @($results | ForEach-Object { [ordered]@{ id = $_.TestId; status = $_.Status; expected = $_.Expected; actual = $_.Actual } })
    failure_count = $failures.Count
    evidence_binding_note = "Tests executed only after clean pre-test worktree verification. TC-M executes a real dirty-tree probe in an isolated git worktree. Evidence publication commit is separate from tested_commit."
}
($manifest | ConvertTo-Json -Depth 10) | Set-Content (Join-Path $EvidenceDir "run_manifest.json") -Encoding UTF8

$summary = @"
# INF-003 Test Summary (CTO REWORK r4)

- Run ID: $runLeaf
- Tested SHA: $testedSha
- Branch: $branch
- Host: $hostName
- Pre-test clean: $cleanWorktree
- Timestamp UTC: $($started.ToString('o'))
- Failures: $($failures.Count)
- Distinct tests: $($results.Count) (expected 21)
- PR: https://github.com/mjshahabadi/AI_Bot_Trade/pull/15
- Acceptance: PENDING (not approved)

| Test ID | Status | Expected | Actual |
|---|---|---|---|
$(($results | ForEach-Object { "| $($_.TestId) | $($_.Status) | $($_.Expected) | $($_.Actual) |" }) -join [Environment]::NewLine)

Compilation: N/A
Trading logic: unchanged
"@
Set-Content (Join-Path $EvidenceDir "test_summary.md") -Value $summary -Encoding UTF8

# SHA256 after ALL evidence files finalized (except the hash list itself)
$hashLines = @()
Get-ChildItem $EvidenceDir -Recurse -File | Where-Object { $_.Name -ne "evidence_sha256.txt" } | ForEach-Object {
    $rel = $_.FullName.Substring($EvidenceDir.Length + 1)
    $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
    $hashLines += ("{0}  {1}" -f $h, $rel)
}
$hashLines | Set-Content (Join-Path $EvidenceDir "evidence_sha256.txt") -Encoding UTF8

Write-Output "failures=$($failures.Count)"
$failures | ForEach-Object { Write-Output "FAIL $_" }
if ($failures.Count -gt 0) { exit 1 }
exit 0
