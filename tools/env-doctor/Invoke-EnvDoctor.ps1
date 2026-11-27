#Requires -Version 5.1
<#
.SYNOPSIS
  Read-only Windows / Git / MetaEditor 5 / MT5 environment doctor for INF-003.

.DESCRIPTION
  Discovers tools from filesystem, registry, and running processes without inventing paths.
  Supports inventory-only mode and strict verified preflight mode.
  Never launches MetaTrader trading operations. Never claims operational agent readiness
  from Agent-* directories or process presence alone.

.PARAMETER StrictPreflight
  Enables mandatory gates: RequireTools, RequireAgentDirectories, FailOnBuildMismatch,
  ValidateExecutables, FailOnEmptyVersion, Git fail-closed, single-install isolation.
  SkipGit is rejected in this mode.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [string]$OutputDir = "",
    [string]$MetaEditorPath = "",
    [string]$TerminalPath = "",
    [string]$InstallRoot = "",
    [string]$TesterRoot = "",
    [int]$MinAgentDirectories = 1,
    [switch]$RequireTools,
    [switch]$RequireAgentDirectories,
    [switch]$FailOnBuildMismatch,
    [switch]$ValidateExecutables,
    [switch]$FailOnEmptyVersion,
    [switch]$StrictPreflight,
    [switch]$AllowSyntheticVersionFixtures,
    [switch]$SkipGit,
    [string]$TerminalDataRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-DoctorLog {
    param([string]$Message)
    $script:LogLines.Add($Message) | Out-Null
    Write-Output $Message
}

function Test-ReadableFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ Ok = $false; Error = "not_found" }
    }
    try {
        $fs = [System.IO.File]::Open($Path, "Open", "Read", "ReadWrite")
        $fs.Close()
        return [pscustomobject]@{ Ok = $true; Error = $null }
    }
    catch {
        return [pscustomobject]@{ Ok = $false; Error = $_.Exception.Message }
    }
}

function Test-PeMzHeader {
    <#
      Bounded DOS header + PE signature validation (INF003-F08).
      Requires: MZ at 0, DOS header size, e_lfanew within file bounds,
      and PE\0\0 signature at e_lfanew. MZ-only stubs are rejected.
    #>
    param([string]$Path)
    try {
        $fs = [System.IO.File]::Open($Path, "Open", "Read", "ReadWrite")
        try {
            $len = $fs.Length
            # Minimum: 64-byte DOS header + 4-byte PE signature
            if ($len -lt 68) { return $false }
            $hdr = New-Object byte[] 64
            $read = $fs.Read($hdr, 0, 64)
            if ($read -lt 64) { return $false }
            if (-not ($hdr[0] -eq 0x4D -and $hdr[1] -eq 0x5A)) { return $false } # MZ
            # e_lfanew at offset 0x3C (little-endian Int32)
            $e_lfanew = [BitConverter]::ToInt32($hdr, 0x3C)
            if ($e_lfanew -lt 64) { return $false }
            if (($e_lfanew + 4L) -gt $len) { return $false }
            [void]$fs.Seek([int64]$e_lfanew, [System.IO.SeekOrigin]::Begin)
            $sig = New-Object byte[] 4
            $sread = $fs.Read($sig, 0, 4)
            if ($sread -lt 4) { return $false }
            # PE\0\0
            return ($sig[0] -eq 0x50 -and $sig[1] -eq 0x45 -and $sig[2] -eq 0x00 -and $sig[3] -eq 0x00)
        }
        finally { $fs.Close() }
    }
    catch { return $false }
}

function Get-ExeInfo {
    param(
        [string]$Path,
        [string]$ExpectedTool, # metaeditor|terminal|metatester
        [switch]$AllowSynthetic
    )
    $read = Test-ReadableFile -Path $Path
    $info = [ordered]@{
        path              = $Path
        exists            = (Test-Path -LiteralPath $Path -PathType Leaf)
        readable          = $false
        read_error        = $null
        length            = $null
        last_write        = $null
        file_version      = $null
        product_name      = $null
        company_name      = $null
        original_filename = $null
        sha256            = $null
        pe_mz_valid       = $false
        product_identity_ok = $false
        version_nonempty  = $false
        synthetic_fixture = $false
        validation_error  = $null
        install_root      = $null
    }
    if (-not $read.Ok) {
        $info.read_error = $read.Error
        $info.validation_error = $read.Error
        return $info
    }
    $fi = Get-Item -LiteralPath $Path
    $info.path = $fi.FullName
    $info.readable = $true
    $info.length = $fi.Length
    $info.last_write = $fi.LastWriteTime.ToString("o")
    $info.install_root = Split-Path -Parent $fi.FullName
    $info.sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    $info.pe_mz_valid = Test-PeMzHeader -Path $Path

    $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
    $info.file_version = $vi.FileVersion
    $info.product_name = $vi.ProductName
    $info.company_name = $vi.CompanyName
    $info.original_filename = $vi.OriginalFilename

    $sidecar = "$Path.fixture-meta.json"
    if ($AllowSynthetic -and (Test-Path -LiteralPath $sidecar -PathType Leaf)) {
        try {
            $meta = Get-Content -LiteralPath $sidecar -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($meta.file_version) { $info.file_version = [string]$meta.file_version }
            if ($meta.product_name) { $info.product_name = [string]$meta.product_name }
            if ($meta.company_name) { $info.company_name = [string]$meta.company_name }
            if ($meta.original_filename) { $info.original_filename = [string]$meta.original_filename }
            $info.synthetic_fixture = $true
            # Synthetic fixtures still require bounded DOS/PE structure (F08); MZ-only stubs fail.
        }
        catch {
            $info.validation_error = "synthetic_fixture_parse_error"
        }
    }

    $info.version_nonempty = -not [string]::IsNullOrWhiteSpace([string]$info.file_version)

    $prod = [string]$info.product_name
    $orig = [string]$info.original_filename
    $company = [string]$info.company_name
    switch ($ExpectedTool) {
        "metaeditor" {
            $info.product_identity_ok = (
                ($prod -match 'MetaQuotes Language 5 Editor') -or
                ($orig -match '(?i)^metaeditor64\.exe$') -or
                (($company -match 'MetaQuotes') -and ($orig -match '(?i)metaeditor'))
            )
        }
        "terminal" {
            $info.product_identity_ok = (
                ($prod -match 'MetaTrader 5 Client Terminal') -or
                ($orig -match '(?i)^terminal64\.exe$') -or
                (($company -match 'MetaQuotes') -and ($orig -match '(?i)terminal'))
            )
        }
        "metatester" {
            $info.product_identity_ok = (
                ($prod -match 'MetaTester') -or
                ($orig -match '(?i)^metatester64\.exe$') -or
                (($company -match 'MetaQuotes') -and ($orig -match '(?i)metatester'))
            )
        }
        default { $info.product_identity_ok = $false }
    }
    return $info
}

function Find-InstallRoots {
    param([string]$ForcedRoot)
    $roots = New-Object System.Collections.Generic.List[string]
    if ($ForcedRoot) {
        $roots.Add($ForcedRoot.TrimEnd("\", "/")) | Out-Null
        return @($roots)
    }
    $candidates = @(
        "C:\Program Files\MetaTrader 5",
        "C:\Program Files (x86)\MetaTrader 5",
        "C:\MT5-Cursor-Test"
    )
    $uninstPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($pattern in $uninstPaths) {
        Get-ItemProperty -Path $pattern -ErrorAction SilentlyContinue | ForEach-Object {
            $display = $null; $install = $null
            if ($_.PSObject.Properties.Name -contains "DisplayName") { $display = $_.DisplayName }
            if ($_.PSObject.Properties.Name -contains "InstallLocation") { $install = $_.InstallLocation }
            if ($display -and ($display -match "MetaTrader 5") -and $install) {
                $candidates += $install.TrimEnd("\", "/")
            }
        }
    }
    Get-Process -Name "terminal64", "metaeditor64", "metatester64" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Path) { $candidates += (Split-Path -Parent $_.Path) }
    }
    foreach ($c in ($candidates | Select-Object -Unique)) {
        if ($c -and (Test-Path -LiteralPath $c -PathType Container)) { $roots.Add($c) | Out-Null }
    }
    return @($roots)
}

function Get-TesterAgents {
    param([string]$RootOverride = "")
    $testerRoot = if ($RootOverride) { $RootOverride } else { Join-Path $env:APPDATA "MetaQuotes\Tester" }
    $running = @(
        Get-Process -Name "metatester64", "metatester" -ErrorAction SilentlyContinue | ForEach-Object {
            [ordered]@{ name = $_.ProcessName; id = $_.Id; path = $_.Path }
        }
    )
    $result = [ordered]@{
        root = $testerRoot
        root_exists = (Test-Path -LiteralPath $testerRoot -PathType Container)
        discovered_agent_directories = @()
        discovered_agent_directory_count = 0
        operational_metatester_processes = $running
        operational_metatester_process_count = $running.Count
        operational_readiness_claimed = $false
        operational_agent_ready = $false
        classification_note = "Discovered Agent-* directories and running metatester process presence are inventory signals only. Operational Strategy Tester agent readiness is never claimed by this doctor."
        agent_directory_count = 0
        agent_directories = @()
    }
    if (-not $result.root_exists) { return $result }
    $agents = @(Get-ChildItem -LiteralPath $testerRoot -Recurse -Directory -Filter "Agent*" -ErrorAction SilentlyContinue)
    $result.discovered_agent_directories = @($agents | ForEach-Object { $_.FullName })
    $result.discovered_agent_directory_count = $agents.Count
    $result.agent_directories = $result.discovered_agent_directories
    $result.agent_directory_count = $result.discovered_agent_directory_count
    return $result
}

function Get-TerminalInventory {
    param([string]$RootOverride = "")
    $termRoot = if ($RootOverride) { $RootOverride } else { Join-Path $env:APPDATA "MetaQuotes\Terminal" }
    $instances = @()
    if (-not (Test-Path -LiteralPath $termRoot -PathType Container)) {
        return [ordered]@{ root = $termRoot; root_exists = $false; instances = @() }
    }
    Get-ChildItem -LiteralPath $termRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $originPath = Join-Path $_.FullName "origin.txt"
        $origin = $null
        if (Test-Path -LiteralPath $originPath -PathType Leaf) {
            $origin = (Get-Content -LiteralPath $originPath -Raw -ErrorAction SilentlyContinue)
            if ($null -ne $origin) { $origin = $origin.Trim() }
        }
        $servers = @()
        $bases = Join-Path $_.FullName "bases"
        if (Test-Path -LiteralPath $bases -PathType Container) {
            Get-ChildItem -LiteralPath $bases -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $hist = Join-Path $_.FullName "history"
                $symbolCount = 0
                if (Test-Path -LiteralPath $hist -PathType Container) {
                    $symbolCount = @(Get-ChildItem -LiteralPath $hist -Directory -ErrorAction SilentlyContinue).Count
                }
                $servers += [ordered]@{
                    name = $_.Name
                    history_exists = (Test-Path -LiteralPath $hist -PathType Container)
                    history_symbol_dirs = $symbolCount
                }
            }
        }
        $instances += [ordered]@{
            id = $_.Name
            path = $_.FullName
            origin = $origin
            mql5_exists = (Test-Path -LiteralPath (Join-Path $_.FullName "MQL5") -PathType Container)
            tester_exists = (Test-Path -LiteralPath (Join-Path $_.FullName "Tester") -PathType Container)
            bases_exists = (Test-Path -LiteralPath $bases -PathType Container)
            servers = $servers
        }
    }
    return [ordered]@{ root = $termRoot; root_exists = $true; instances = $instances }
}

function Get-InstallDataMapping {
    param([string[]]$InstallRoots, $TerminalData)
    $maps = @()
    foreach ($root in $InstallRoots) {
        $normRoot = $root.TrimEnd("\", "/")
        $matches = @()
        if ($TerminalData -and $TerminalData.instances) {
            foreach ($inst in @($TerminalData.instances)) {
                if ($inst.origin -and ($inst.origin.TrimEnd("\", "/") -ieq $normRoot)) {
                    $matches += [ordered]@{ terminal_id = $inst.id; data_path = $inst.path; origin = $inst.origin }
                }
            }
        }
        $maps += [ordered]@{
            install_root = $normRoot
            matched_terminal_ids = @($matches | ForEach-Object { $_.terminal_id })
            matches = $matches
            mapped = ($matches.Count -gt 0)
        }
    }
    return $maps
}

function Get-BuildConsistency {
    param($MetaInfo, $TermInfo, $TesterInfo)
    $versions = @()
    foreach ($pair in @(
            @{ Name = "metaeditor"; Info = $MetaInfo },
            @{ Name = "terminal"; Info = $TermInfo },
            @{ Name = "metatester"; Info = $TesterInfo }
        )) {
        if ($pair.Info -and $pair.Info.exists) {
            $ver = if (-not [string]::IsNullOrWhiteSpace([string]$pair.Info.file_version)) { [string]$pair.Info.file_version } else { "EMPTY" }
            $versions += [ordered]@{
                tool = $pair.Name
                file_version = $ver
                synthetic_fixture = [bool]$pair.Info.synthetic_fixture
            }
        }
    }
    $unique = @($versions | ForEach-Object { $_.file_version } | Select-Object -Unique)
    return [ordered]@{
        versions_recorded = $versions
        unique_versions = $unique
        consistent = (($unique.Count -eq 1) -and ($versions.Count -gt 0) -and ($unique[0] -ne "EMPTY"))
        mismatch = ($unique.Count -gt 1)
        empty_version_present = ($unique -contains "EMPTY")
    }
}

function Invoke-GitChecked {
    param([string]$RepoPath, [string[]]$GitArgs)
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        return [pscustomobject]@{ Ok = $false; ExitCode = 127; Output = ""; Error = "git_not_in_path"; Path = $null }
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $gitCmd.Source
    $psi.Arguments = ($GitArgs | ForEach-Object {
            if ($_ -match '\s') { '"{0}"' -f ($_ -replace '"', '\"') } else { $_ }
        }) -join ' '
    $psi.WorkingDirectory = $RepoPath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{
        Ok = ($p.ExitCode -eq 0)
        ExitCode = $p.ExitCode
        Output = $stdout.Trim()
        Error = $stderr.Trim()
        Path = $gitCmd.Source
    }
}

function Get-GitInfoStrict {
    param([string]$Root, [switch]$Required)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return [ordered]@{
            available = $false; path = $null; version = $null; repo_root = $Root
            head = $null; status = $null; error = "repo_root_not_found"
            head_valid = $false; is_git_repository = $false; command_results = @()
        }
    }
    $gitDir = Join-Path $Root ".git"
    $isRepo = (Test-Path -LiteralPath $gitDir)
    $ver = Invoke-GitChecked -RepoPath $Root -GitArgs @("--version")
    if (-not $ver.Ok) {
        return [ordered]@{
            available = $false; path = $ver.Path; version = $null; repo_root = $Root
            head = $null; status = $null; error = "git_version_failed:$($ver.ExitCode):$($ver.Error)"
            head_valid = $false; is_git_repository = $isRepo
            command_results = @([ordered]@{ command = "git --version"; exit_code = $ver.ExitCode; ok = $false })
        }
    }
    if (-not $isRepo) {
        return [ordered]@{
            available = $true; path = $ver.Path; version = $ver.Output; repo_root = (Resolve-Path -LiteralPath $Root).Path
            head = $null; status = $null; error = "not_a_git_repository"
            head_valid = $false; is_git_repository = $false
            command_results = @([ordered]@{ command = "git --version"; exit_code = 0; ok = $true })
        }
    }
    $headCmd = Invoke-GitChecked -RepoPath $Root -GitArgs @("rev-parse", "HEAD")
    $statCmd = Invoke-GitChecked -RepoPath $Root -GitArgs @("status", "--porcelain=v1")
    $headValid = ($headCmd.Ok -and ($headCmd.Output -match '^[0-9a-f]{40}$'))
    $err = $null
    if (-not $headCmd.Ok) { $err = "rev_parse_failed:$($headCmd.ExitCode):$($headCmd.Error)" }
    elseif (-not $headValid) { $err = "invalid_head_sha:$($headCmd.Output)" }
    elseif (-not $statCmd.Ok) { $err = "status_failed:$($statCmd.ExitCode):$($statCmd.Error)" }
    return [ordered]@{
        available = $true
        path = $ver.Path
        version = $ver.Output
        repo_root = (Resolve-Path -LiteralPath $Root).Path
        head = $(if ($headCmd.Ok) { $headCmd.Output } else { $null })
        status = $(if ($statCmd.Ok) { $statCmd.Output } else { $null })
        error = $err
        head_valid = $headValid
        is_git_repository = $true
        command_results = @(
            [ordered]@{ command = "git --version"; exit_code = $ver.ExitCode; ok = $ver.Ok }
            [ordered]@{ command = "git rev-parse HEAD"; exit_code = $headCmd.ExitCode; ok = $headCmd.Ok }
            [ordered]@{ command = "git status --porcelain=v1"; exit_code = $statCmd.ExitCode; ok = $statCmd.Ok }
        )
    }
}

function Get-DiskInfo {
    $drive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    if (-not $drive) { return [ordered]@{ name = "C"; available = $false } }
    return [ordered]@{
        name = "C"; available = $true
        used_gb = [math]::Round(($drive.Used / 1GB), 2)
        free_gb = [math]::Round(($drive.Free / 1GB), 2)
    }
}

# ---- main ----
$script:LogLines = New-Object System.Collections.Generic.List[string]
$started = (Get-Date).ToUniversalTime()
$issues = New-Object System.Collections.Generic.List[string]
$overall = "PASS"

if ($StrictPreflight) {
    $RequireTools = $true
    $RequireAgentDirectories = $true
    $FailOnBuildMismatch = $true
    $ValidateExecutables = $true
    $FailOnEmptyVersion = $true
}

if ($StrictPreflight -and $SkipGit) {
    Write-DoctorLog "ERROR StrictPreflight rejects SkipGit (test-only bypass is not verified readiness evidence)"
    $issues.Add("StrictPreflight rejects SkipGit") | Out-Null
    $overall = "FAIL"
}

if ($StrictPreflight -and $AllowSyntheticVersionFixtures) {
    Write-DoctorLog "ERROR StrictPreflight rejects AllowSyntheticVersionFixtures (synthetic metadata is not verified readiness evidence)"
    $issues.Add("StrictPreflight rejects AllowSyntheticVersionFixtures") | Out-Null
    $overall = "FAIL"
}

if ($MinAgentDirectories -lt 1) {
    $msg = "Invalid MinAgentDirectories=$MinAgentDirectories; must be >= 1"
    Write-DoctorLog "FAIL $msg"
    $issues.Add($msg) | Out-Null
    $overall = "FAIL"
}

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
else {
    if (-not (Test-Path -LiteralPath $RepoRoot)) {
        Write-DoctorLog "ERROR RepoRoot not found: $RepoRoot"
        $issues.Add("RepoRoot not found: $RepoRoot") | Out-Null
        $overall = "FAIL"
        $RepoRoot = $RepoRoot
    }
    else {
        $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
    }
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $RepoRoot "artifacts\env-doctor\latest"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$mode = if ($StrictPreflight) { "verified_preflight" } else { "inventory_only" }
Write-DoctorLog "INF-003 EnvDoctor start $($started.ToString('o')) mode=$mode"
Write-DoctorLog "host=$env:COMPUTERNAME user=$env:USERNAME"
Write-DoctorLog "os=$([System.Environment]::OSVersion.VersionString)"
Write-DoctorLog "powershell=$($PSVersionTable.PSVersion)"
Write-DoctorLog "cwd=$((Get-Location).Path)"
Write-DoctorLog "repo_root=$RepoRoot"
Write-DoctorLog "output_dir=$OutputDir"
Write-DoctorLog "gates RequireTools=$RequireTools RequireAgentDirectories=$RequireAgentDirectories FailOnBuildMismatch=$FailOnBuildMismatch ValidateExecutables=$ValidateExecutables FailOnEmptyVersion=$FailOnEmptyVersion MinAgentDirectories=$MinAgentDirectories"

# Override existence checks
foreach ($ov in @(
        @{ Name = "MetaEditorPath"; Path = $MetaEditorPath },
        @{ Name = "TerminalPath"; Path = $TerminalPath }
    )) {
    if ($ov.Path) {
        Write-DoctorLog ("override {0}={1}" -f $ov.Name, $ov.Path)
        if (-not (Test-Path -LiteralPath $ov.Path -PathType Leaf)) {
            $msg = "$($ov.Name) override not found: $($ov.Path)"
            Write-DoctorLog "ERROR $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
        }
        elseif (-not (Test-ReadableFile -Path $ov.Path).Ok) {
            $msg = "$($ov.Name) override not readable: $($ov.Path)"
            Write-DoctorLog "ERROR $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
        }
    }
}
if ($InstallRoot) {
    Write-DoctorLog "override InstallRoot=$InstallRoot"
    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        $msg = "InstallRoot override not found: $InstallRoot"
        Write-DoctorLog "ERROR $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
    }
}

$discoveredRoots = @()
$selectedInstallRoot = $null
$selectionAmbiguous = $false
$selectionNote = $null
if ($overall -ne "FAIL") {
    $discoveredRoots = Find-InstallRoots -ForcedRoot ""
    Write-DoctorLog ("discovered_install_roots=" + ($discoveredRoots -join ";"))

    $overrideRoots = @()
    if ($MetaEditorPath) { $overrideRoots += (Split-Path -Parent $MetaEditorPath).TrimEnd("\", "/") }
    if ($TerminalPath) { $overrideRoots += (Split-Path -Parent $TerminalPath).TrimEnd("\", "/") }
    $overrideRoots = @($overrideRoots | Select-Object -Unique)

    if ($InstallRoot) {
        $selectedInstallRoot = $InstallRoot.TrimEnd("\", "/")
        $selectionNote = "explicit_InstallRoot"
    }
    elseif ($overrideRoots.Count -eq 1) {
        $selectedInstallRoot = $overrideRoots[0]
        $selectionNote = "derived_from_path_overrides"
    }
    elseif ($overrideRoots.Count -gt 1) {
        $selectionAmbiguous = $true
        $selectionNote = "conflicting_path_overrides"
        $msg = "Inconsistent tool path overrides across install roots: $($overrideRoots -join ' | ')"
        Write-DoctorLog "FAIL $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
    }
    elseif ($discoveredRoots.Count -eq 1) {
        $selectedInstallRoot = $discoveredRoots[0]
        $selectionNote = "single_discovered_root"
    }
    elseif ($discoveredRoots.Count -gt 1) {
        $selectionAmbiguous = $true
        $selectionNote = "multiple_discovered_roots"
        if ($StrictPreflight -or $RequireTools) {
            $msg = "Ambiguous multiple MT5 install roots; specify -InstallRoot. Found: $($discoveredRoots -join ' | ')"
            Write-DoctorLog "FAIL $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
        }
        else {
            Write-DoctorLog "WARN multiple install roots in inventory-only mode; no silent cross-root tool mix"
        }
    }
    else {
        $selectionNote = "no_install_root_found"
    }
}

$metaPath = $null; $termPath = $null; $testerPath = $null
if ($overall -ne "FAIL") {
    if ($MetaEditorPath) { $metaPath = $MetaEditorPath }
    elseif ($selectedInstallRoot) { $metaPath = Join-Path $selectedInstallRoot "metaeditor64.exe" }
    if ($TerminalPath) { $termPath = $TerminalPath }
    elseif ($selectedInstallRoot) { $termPath = Join-Path $selectedInstallRoot "terminal64.exe" }
    if ($selectedInstallRoot) { $testerPath = Join-Path $selectedInstallRoot "metatester64.exe" }

    # Enforce same-root isolation when paths resolve
    $rootsUsed = @()
    foreach ($p in @($metaPath, $termPath, $testerPath)) {
        if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) {
            $rootsUsed += (Split-Path -Parent $p).TrimEnd("\", "/")
        }
    }
    $rootsUsed = @($rootsUsed | Select-Object -Unique)
    if ($rootsUsed.Count -gt 1) {
        $selectionAmbiguous = $true
        $msg = "Selected tools span unrelated install roots: $($rootsUsed -join ' | ')"
        Write-DoctorLog "FAIL $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
    }
    elseif ($rootsUsed.Count -eq 1 -and -not $selectedInstallRoot) {
        $selectedInstallRoot = $rootsUsed[0]
    }
}

$allowSynth = [bool]$AllowSyntheticVersionFixtures
$metaInfo = $null; $termInfo = $null; $testerInfo = $null
if ($metaPath -and (Test-Path -LiteralPath $metaPath)) {
    $metaInfo = Get-ExeInfo -Path $metaPath -ExpectedTool metaeditor -AllowSynthetic:$allowSynth
    Write-DoctorLog ("metaeditor path={0} ver={1} pe={2} identity={3} synth={4}" -f $metaInfo.path, $metaInfo.file_version, $metaInfo.pe_mz_valid, $metaInfo.product_identity_ok, $metaInfo.synthetic_fixture)
}
else { Write-DoctorLog "metaeditor=NOT_FOUND" }
if ($termPath -and (Test-Path -LiteralPath $termPath)) {
    $termInfo = Get-ExeInfo -Path $termPath -ExpectedTool terminal -AllowSynthetic:$allowSynth
    Write-DoctorLog ("terminal path={0} ver={1} pe={2} identity={3} synth={4}" -f $termInfo.path, $termInfo.file_version, $termInfo.pe_mz_valid, $termInfo.product_identity_ok, $termInfo.synthetic_fixture)
}
else { Write-DoctorLog "terminal=NOT_FOUND" }
if ($testerPath -and (Test-Path -LiteralPath $testerPath)) {
    $testerInfo = Get-ExeInfo -Path $testerPath -ExpectedTool metatester -AllowSynthetic:$allowSynth
    Write-DoctorLog ("metatester path={0} ver={1} pe={2} identity={3} synth={4}" -f $testerInfo.path, $testerInfo.file_version, $testerInfo.pe_mz_valid, $testerInfo.product_identity_ok, $testerInfo.synthetic_fixture)
}
else { Write-DoctorLog "metatester=NOT_FOUND" }

$gitInfo = $null
if (-not $SkipGit) {
    $gitInfo = Get-GitInfoStrict -Root $RepoRoot -Required:($RequireTools -or $StrictPreflight)
    Write-DoctorLog ("git available={0} repo={1} head={2} head_valid={3} err={4}" -f $gitInfo.available, $gitInfo.is_git_repository, $gitInfo.head, $gitInfo.head_valid, $gitInfo.error)
}
else {
    Write-DoctorLog "git=SKIPPED (test-only bypass; not verified readiness evidence)"
}

$agents = Get-TesterAgents -RootOverride $TesterRoot
Write-DoctorLog ("discovered_agent_directories count={0} root={1}" -f $agents.discovered_agent_directory_count, $agents.root)
Write-DoctorLog ("operational_metatester_processes count={0}" -f $agents.operational_metatester_process_count)
Write-DoctorLog "operational_readiness_claimed=False operational_agent_ready=False"

$terminals = Get-TerminalInventory -RootOverride $TerminalDataRoot
$mapRoots = @()
if ($selectedInstallRoot) { $mapRoots = @($selectedInstallRoot) }
elseif ($discoveredRoots.Count -gt 0) { $mapRoots = $discoveredRoots }
$installDataMap = Get-InstallDataMapping -InstallRoots $mapRoots -TerminalData $terminals
$selectedDataDir = $null
$selectedTerminalId = $null
$dataMappingStatus = "not_selected"
$dataMappingReason = $null
$dataMappingVerified = $false
foreach ($m in $installDataMap) {
    Write-DoctorLog ("install_data_map root={0} mapped={1} match_count={2} terminals={3}" -f $m.install_root, $m.mapped, @($m.matches).Count, ($m.matched_terminal_ids -join ","))
    if (-not ($selectedInstallRoot -and ($m.install_root -ieq $selectedInstallRoot))) { continue }
    $matchCount = @($m.matches).Count
    if ($matchCount -eq 0) {
        $dataMappingStatus = "missing"
        $dataMappingReason = "No terminal data directory origin.txt maps to selected install root: $($m.install_root)"
        Write-DoctorLog "FAIL data_directory_mapping_missing: $dataMappingReason"
        if ($StrictPreflight -or $RequireTools) {
            $issues.Add($dataMappingReason) | Out-Null
            $overall = "FAIL"
        }
    }
    elseif ($matchCount -gt 1) {
        $dataMappingStatus = "ambiguous"
        $ids = @($m.matched_terminal_ids) -join ","
        $dataMappingReason = "Ambiguous terminal data-directory mapping for install root $($m.install_root); matches=$matchCount terminals=$ids. Refusing silent first-match selection."
        Write-DoctorLog "FAIL data_directory_mapping_ambiguous: $dataMappingReason"
        $selectionAmbiguous = $true
        # Never silently select the first ambiguous match (INF003-F11).
        if ($StrictPreflight -or $RequireTools) {
            $issues.Add($dataMappingReason) | Out-Null
            $overall = "FAIL"
        }
    }
    else {
        $dataMappingStatus = "unique"
        $selectedTerminalId = $m.matched_terminal_ids[0]
        $selectedDataDir = $m.matches[0].data_path
        $dataMappingVerified = $true
        $dataMappingReason = "Unique origin.txt mapping"
        Write-DoctorLog ("data_directory_mapping_unique terminal_id={0} data={1}" -f $selectedTerminalId, $selectedDataDir)
    }
}

$buildConsistency = Get-BuildConsistency -MetaInfo $metaInfo -TermInfo $termInfo -TesterInfo $testerInfo
Write-DoctorLog ("build_consistency consistent={0} mismatch={1} empty={2} versions={3}" -f $buildConsistency.consistent, $buildConsistency.mismatch, $buildConsistency.empty_version_present, ($buildConsistency.unique_versions -join ","))

$disk = Get-DiskInfo
$running = @(
    Get-Process -Name "terminal64", "metaeditor64", "metatester64" -ErrorAction SilentlyContinue | ForEach-Object {
        [ordered]@{ name = $_.ProcessName; id = $_.Id; path = $_.Path }
    }
)

# Gates
if ($RequireTools -and $overall -ne "FAIL") {
    foreach ($pair in @(
            @{ Name = "MetaEditor"; Info = $metaInfo },
            @{ Name = "Terminal"; Info = $termInfo },
            @{ Name = "MetaTester"; Info = $testerInfo }
        )) {
        if (-not $pair.Info -or -not $pair.Info.exists -or -not $pair.Info.readable) {
            $msg = "Required tool missing or unreadable: $($pair.Name)"
            Write-DoctorLog "BLOCKED $msg"; $issues.Add($msg) | Out-Null; $overall = "BLOCKED"
        }
    }
    if (-not $SkipGit) {
        if (-not $gitInfo -or -not $gitInfo.available -or -not $gitInfo.is_git_repository -or -not $gitInfo.head_valid -or $gitInfo.error) {
            $msg = "Required Git inspection failed: $(if ($gitInfo) { $gitInfo.error } else { 'git_unavailable' })"
            Write-DoctorLog "BLOCKED $msg"; $issues.Add($msg) | Out-Null; $overall = "BLOCKED"
        }
    }
}

if ($ValidateExecutables -and $overall -ne "FAIL") {
    foreach ($pair in @(
            @{ Name = "MetaEditor"; Info = $metaInfo },
            @{ Name = "Terminal"; Info = $termInfo },
            @{ Name = "MetaTester"; Info = $testerInfo }
        )) {
        if (-not $pair.Info -or -not $pair.Info.exists) { continue }
        if (-not $pair.Info.pe_mz_valid) {
            $msg = "Invalid executable structure (MZ/PE) for $($pair.Name): $($pair.Info.path)"
            Write-DoctorLog "FAIL $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
        }
        elseif (-not $pair.Info.product_identity_ok) {
            $msg = "Unexpected product identity for $($pair.Name): product='$($pair.Info.product_name)' original='$($pair.Info.original_filename)'"
            Write-DoctorLog "FAIL $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
        }
    }
}

if ($FailOnEmptyVersion -and $overall -ne "FAIL") {
    foreach ($pair in @(
            @{ Name = "MetaEditor"; Info = $metaInfo },
            @{ Name = "Terminal"; Info = $termInfo },
            @{ Name = "MetaTester"; Info = $testerInfo }
        )) {
        if ($pair.Info -and $pair.Info.exists -and -not $pair.Info.version_nonempty) {
            $msg = "Empty/missing FileVersion metadata for $($pair.Name): $($pair.Info.path)"
            Write-DoctorLog "FAIL $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
        }
    }
}

if ($RequireAgentDirectories -and $overall -ne "FAIL") {
    if (-not $agents.root_exists) {
        $msg = "Tester root missing or unavailable: $($agents.root)"
        Write-DoctorLog "BLOCKED $msg"; $issues.Add($msg) | Out-Null; $overall = "BLOCKED"
    }
    elseif ($agents.discovered_agent_directory_count -lt $MinAgentDirectories) {
        $msg = "Discovered Agent-* directories below minimum: found=$($agents.discovered_agent_directory_count) min=$MinAgentDirectories root=$($agents.root)"
        Write-DoctorLog "BLOCKED $msg"; $issues.Add($msg) | Out-Null; $overall = "BLOCKED"
    }
}

if ($FailOnBuildMismatch -and $overall -ne "FAIL") {
    if ($buildConsistency.mismatch) {
        $msg = "MetaEditor/MT5/MetaTester FileVersion mismatch: $($buildConsistency.unique_versions -join ' vs ')"
        Write-DoctorLog "FAIL $msg"; $issues.Add($msg) | Out-Null; $overall = "FAIL"
    }
}

$anySynthetic = $false
foreach ($info in @($metaInfo, $termInfo, $testerInfo)) {
    if ($info -and $info.synthetic_fixture) { $anySynthetic = $true }
}
# Synthetic metadata must never yield verified_preflight_passed=true (INF003-F09).
$verifiedPassed = (($mode -eq "verified_preflight") -and ($overall -eq "PASS") -and (-not $anySynthetic) -and (-not $AllowSyntheticVersionFixtures))
if ($anySynthetic -and $mode -eq "verified_preflight") {
    Write-DoctorLog "ERROR synthetic fixture metadata present under verified_preflight; verified_preflight_passed forced false"
    $issues.Add("Synthetic fixture metadata cannot satisfy verified preflight") | Out-Null
    if ($overall -eq "PASS") { $overall = "FAIL" }
    $verifiedPassed = $false
}

$readiness = [ordered]@{
    mode = $mode
    inventory_only = ($mode -eq "inventory_only")
    verified_environment_preflight = ($mode -eq "verified_preflight")
    verified_preflight_passed = $verifiedPassed
    synthetic_fixture_present = $anySynthetic
    operational_agent_ready = $false
    note = "verified_environment_preflight asserts tool/Git/agent-directory/build gates only. It does not assert Strategy Tester operational readiness. Synthetic fixtures never satisfy verified preflight."
}

$report = [ordered]@{
    schema = "ai-bot-trade.env-doctor.v1.3"
    task_id = "INF-003"
    requirement_id = "REQ-INF-003"
    rule_id = "RULE-ENV-001"
    timestamp_utc = $started.ToString("o")
    host = $env:COMPUTERNAME
    user = $env:USERNAME
    os = [System.Environment]::OSVersion.VersionString
    powershell = $PSVersionTable.PSVersion.ToString()
    working_directory = (Get-Location).Path
    repo_root = $RepoRoot
    overall_status = $overall
    issues = @($issues)
    readiness = $readiness
    selected_installation = [ordered]@{
        install_root = $selectedInstallRoot
        data_directory = $selectedDataDir
        terminal_id = $selectedTerminalId
        selection_note = $selectionNote
        ambiguous = $selectionAmbiguous
        discovered_roots = @($discoveredRoots)
        data_mapping_status = $dataMappingStatus
        data_mapping_reason = $dataMappingReason
        data_mapping_verified = $dataMappingVerified
    }
    install_roots_found = @($discoveredRoots)
    install_data_mapping = $installDataMap
    build_consistency = $buildConsistency
    metaeditor = $metaInfo
    terminal = $termInfo
    metatester = $testerInfo
    git = $gitInfo
    tester_agents = $agents
    terminal_data = $terminals
    disk = $disk
    running_processes = $running
    discovery_notes = @(
        "No executable path is invented.",
        "Read-only inspection; MT5 is not launched for trading.",
        "StrictPreflight enables mandatory readiness gates; inventory-only mode does not imply verified readiness.",
        "Discovered Agent-* directories and metatester process presence never imply operational_agent_ready.",
        "Synthetic version fixtures are test-only and marked synthetic_fixture=true."
    )
}

$jsonPath = Join-Path $OutputDir "doctor_report.json"
$txtPath = Join-Path $OutputDir "doctor_report.txt"
($report | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $jsonPath -Encoding UTF8
($script:LogLines -join [Environment]::NewLine) | Set-Content -LiteralPath $txtPath -Encoding UTF8
Write-DoctorLog "wrote $jsonPath"
Write-DoctorLog "wrote $txtPath"
Write-DoctorLog "overall_status=$overall readiness_mode=$mode verified_preflight_passed=$($readiness.verified_preflight_passed)"

if ($overall -eq "PASS") { exit 0 }
exit 1
