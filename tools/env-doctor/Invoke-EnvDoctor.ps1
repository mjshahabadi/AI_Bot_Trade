#Requires -Version 5.1
<#
.SYNOPSIS
  Read-only Windows / Git / MetaEditor 5 / MT5 environment doctor for INF-003.

.DESCRIPTION
  Discovers installed tools from the filesystem, registry, and running processes.
  Does not invent executable paths. Writes JSON + text reports. Secrets are not logged.

.PARAMETER RepoRoot
  Repository root used for git status. Defaults to the repository containing this script.

.PARAMETER OutputDir
  Directory for doctor_report.json and doctor_report.txt.

.PARAMETER MetaEditorPath
  Optional absolute path override for MetaEditor. If set and missing/unreadable, exits nonzero.

.PARAMETER TerminalPath
  Optional absolute path override for terminal64.exe.

.PARAMETER InstallRoot
  Optional install directory override (must contain metaeditor64.exe / terminal64.exe when provided).

.PARAMETER RequireTools
  When set, missing MetaEditor/terminal/metatester/Git causes nonzero exit (BLOCKED/FAIL).

.PARAMETER SkipGit
  Skip git inspection (tests only).
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = "",
    [string]$OutputDir = "",
    [string]$MetaEditorPath = "",
    [string]$TerminalPath = "",
    [string]$InstallRoot = "",
    [switch]$RequireTools,
    [switch]$SkipGit
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

function Get-ExeInfo {
    param([string]$Path)
    $read = Test-ReadableFile -Path $Path
    if (-not $read.Ok) {
        return [ordered]@{
            path         = $Path
            exists       = (Test-Path -LiteralPath $Path -PathType Leaf)
            readable     = $false
            read_error   = $read.Error
            length       = $null
            last_write   = $null
            file_version = $null
            product_name = $null
            company_name = $null
            sha256       = $null
        }
    }
    $fi = Get-Item -LiteralPath $Path
    $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return [ordered]@{
        path         = $fi.FullName
        exists       = $true
        readable     = $true
        read_error   = $null
        length       = $fi.Length
        last_write   = $fi.LastWriteTime.ToString("o")
        file_version = $vi.FileVersion
        product_name = $vi.ProductName
        company_name = $vi.CompanyName
        sha256       = $hash.Hash
    }
}

function Find-InstallRoots {
    $roots = New-Object System.Collections.Generic.List[string]

    if ($InstallRoot) {
        $roots.Add($InstallRoot) | Out-Null
        return @($roots | Select-Object -Unique)
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
            $display = $null
            $install = $null
            if ($_.PSObject.Properties.Name -contains "DisplayName") { $display = $_.DisplayName }
            if ($_.PSObject.Properties.Name -contains "InstallLocation") { $install = $_.InstallLocation }
            if ($display -and ($display -match "MetaTrader 5") -and $install) {
                $loc = $install.TrimEnd("\", "/")
                if ($loc) { $candidates += $loc }
            }
        }
    }

    Get-Process -Name "terminal64", "metaeditor64", "metatester64" -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.Path) {
                $dir = Split-Path -Parent $_.Path
                if ($dir) { $candidates += $dir }
            }
        }

    foreach ($c in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $c -PathType Container) {
            $roots.Add($c) | Out-Null
        }
    }
    return @($roots)
}

function Resolve-ToolPath {
    param(
        [string]$Override,
        [string[]]$Roots,
        [string]$FileName
    )
    if ($Override) {
        return $Override
    }
    foreach ($root in $Roots) {
        $p = Join-Path $root $FileName
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            return $p
        }
    }
    return $null
}

function Get-TesterAgents {
    $testerRoot = Join-Path $env:APPDATA "MetaQuotes\Tester"
    $result = [ordered]@{
        root                 = $testerRoot
        root_exists          = (Test-Path -LiteralPath $testerRoot -PathType Container)
        agent_directory_count = 0
        agent_directories    = @()
    }
    if (-not $result.root_exists) {
        return $result
    }
    $agents = @(Get-ChildItem -LiteralPath $testerRoot -Recurse -Directory -Filter "Agent*" -ErrorAction SilentlyContinue)
    $result.agent_directory_count = $agents.Count
    $result.agent_directories = @($agents | ForEach-Object { $_.FullName })
    return $result
}

function Get-TerminalInventory {
    $termRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal"
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
                    name                 = $_.Name
                    history_exists       = (Test-Path -LiteralPath $hist -PathType Container)
                    history_symbol_dirs  = $symbolCount
                }
            }
        }
        $instances += [ordered]@{
            id              = $_.Name
            path            = $_.FullName
            origin          = $origin
            mql5_exists     = (Test-Path -LiteralPath (Join-Path $_.FullName "MQL5") -PathType Container)
            tester_exists   = (Test-Path -LiteralPath (Join-Path $_.FullName "Tester") -PathType Container)
            bases_exists    = (Test-Path -LiteralPath $bases -PathType Container)
            servers         = $servers
        }
    }
    return [ordered]@{ root = $termRoot; root_exists = $true; instances = $instances }
}

function Get-DiskInfo {
    $drive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    if (-not $drive) {
        return [ordered]@{ name = "C"; available = $false }
    }
    return [ordered]@{
        name     = "C"
        available = $true
        used_gb  = [math]::Round(($drive.Used / 1GB), 2)
        free_gb  = [math]::Round(($drive.Free / 1GB), 2)
    }
}

function Get-GitInfo {
    param([string]$Root)
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        return [ordered]@{
            available = $false
            path      = $null
            version   = $null
            repo_root = $Root
            head      = $null
            status    = $null
            error     = "git_not_in_path"
        }
    }
    $head = $null
    $status = $null
    $err = $null
    try {
        Push-Location -LiteralPath $Root
        $head = (& git rev-parse HEAD 2>&1 | Out-String).Trim()
        $status = (& git status --porcelain=v1 2>&1 | Out-String).TrimEnd()
    }
    catch {
        $err = $_.Exception.Message
    }
    finally {
        Pop-Location
    }
    return [ordered]@{
        available = $true
        path      = $gitCmd.Source
        version   = ((& git --version) | Out-String).Trim()
        repo_root = (Resolve-Path -LiteralPath $Root).Path
        head      = $head
        status    = $status
        error     = $err
    }
}

# ---- main ----
$script:LogLines = New-Object System.Collections.Generic.List[string]
$started = (Get-Date).ToUniversalTime()

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}
else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $RepoRoot "artifacts\env-doctor\latest"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-DoctorLog "INF-003 EnvDoctor start $($started.ToString('o'))"
Write-DoctorLog "host=$env:COMPUTERNAME user=$env:USERNAME"
Write-DoctorLog "os=$([System.Environment]::OSVersion.VersionString)"
Write-DoctorLog "powershell=$($PSVersionTable.PSVersion)"
Write-DoctorLog "cwd=$((Get-Location).Path)"
Write-DoctorLog "repo_root=$RepoRoot"
Write-DoctorLog "output_dir=$OutputDir"

$issues = New-Object System.Collections.Generic.List[string]
$overall = "PASS"

# Validate overrides before discovery
if ($MetaEditorPath) {
    Write-DoctorLog "override MetaEditorPath=$MetaEditorPath"
    if (-not (Test-Path -LiteralPath $MetaEditorPath -PathType Leaf)) {
        $msg = "MetaEditorPath override not found: $MetaEditorPath"
        Write-DoctorLog "ERROR $msg"
        $issues.Add($msg) | Out-Null
        $overall = "FAIL"
    }
    elseif (-not (Test-ReadableFile -Path $MetaEditorPath).Ok) {
        $msg = "MetaEditorPath override not readable: $MetaEditorPath"
        Write-DoctorLog "ERROR $msg"
        $issues.Add($msg) | Out-Null
        $overall = "FAIL"
    }
}
if ($TerminalPath) {
    Write-DoctorLog "override TerminalPath=$TerminalPath"
    if (-not (Test-Path -LiteralPath $TerminalPath -PathType Leaf)) {
        $msg = "TerminalPath override not found: $TerminalPath"
        Write-DoctorLog "ERROR $msg"
        $issues.Add($msg) | Out-Null
        $overall = "FAIL"
    }
}
if ($InstallRoot) {
    Write-DoctorLog "override InstallRoot=$InstallRoot"
    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        $msg = "InstallRoot override not found: $InstallRoot"
        Write-DoctorLog "ERROR $msg"
        $issues.Add($msg) | Out-Null
        $overall = "FAIL"
    }
}

$roots = @()
if ($overall -ne "FAIL") {
    $roots = Find-InstallRoots
    Write-DoctorLog ("install_roots=" + (($roots -join ";")))
}

$metaPath = $null
$termPath = $null
$testerPath = $null
if ($overall -ne "FAIL") {
    $metaPath = Resolve-ToolPath -Override $MetaEditorPath -Roots $roots -FileName "metaeditor64.exe"
    $termPath = Resolve-ToolPath -Override $TerminalPath -Roots $roots -FileName "terminal64.exe"
    $testerPath = Resolve-ToolPath -Override "" -Roots $roots -FileName "metatester64.exe"
}

$metaInfo = $null
$termInfo = $null
$testerInfo = $null
if ($metaPath) {
    $metaInfo = Get-ExeInfo -Path $metaPath
    Write-DoctorLog ("metaeditor path={0} version={1} readable={2}" -f $metaInfo.path, $metaInfo.file_version, $metaInfo.readable)
}
else {
    Write-DoctorLog "metaeditor=NOT_FOUND"
}
if ($termPath) {
    $termInfo = Get-ExeInfo -Path $termPath
    Write-DoctorLog ("terminal path={0} version={1} readable={2}" -f $termInfo.path, $termInfo.file_version, $termInfo.readable)
}
else {
    Write-DoctorLog "terminal=NOT_FOUND"
}
if ($testerPath) {
    $testerInfo = Get-ExeInfo -Path $testerPath
    Write-DoctorLog ("metatester path={0} version={1} readable={2}" -f $testerInfo.path, $testerInfo.file_version, $testerInfo.readable)
}
else {
    Write-DoctorLog "metatester=NOT_FOUND"
}

$gitInfo = $null
if (-not $SkipGit) {
    $gitInfo = Get-GitInfo -Root $RepoRoot
    Write-DoctorLog ("git available={0} path={1} version={2} head={3}" -f $gitInfo.available, $gitInfo.path, $gitInfo.version, $gitInfo.head)
}
else {
    Write-DoctorLog "git=SKIPPED"
}

$agents = Get-TesterAgents
Write-DoctorLog ("tester_agents count={0} root={1}" -f $agents.agent_directory_count, $agents.root)

$terminals = Get-TerminalInventory
Write-DoctorLog ("terminal_instances count={0}" -f @($terminals.instances).Count)

$disk = Get-DiskInfo
Write-DoctorLog ("disk_c free_gb={0}" -f $disk.free_gb)

$running = @(
    Get-Process -Name "terminal64", "metaeditor64", "metatester64" -ErrorAction SilentlyContinue |
        ForEach-Object {
            [ordered]@{ name = $_.ProcessName; id = $_.Id; path = $_.Path }
        }
)

# Required-tool gate
if ($RequireTools -and $overall -ne "FAIL") {
    foreach ($pair in @(
            @{ Name = "MetaEditor"; Info = $metaInfo },
            @{ Name = "Terminal"; Info = $termInfo },
            @{ Name = "MetaTester"; Info = $testerInfo }
        )) {
        if (-not $pair.Info -or -not $pair.Info.exists -or -not $pair.Info.readable) {
            $msg = "Required tool missing or unreadable: $($pair.Name)"
            Write-DoctorLog "BLOCKED $msg"
            $issues.Add($msg) | Out-Null
            $overall = "BLOCKED"
        }
    }
    if (-not $SkipGit -and (-not $gitInfo -or -not $gitInfo.available)) {
        $msg = "Required tool missing: Git"
        Write-DoctorLog "BLOCKED $msg"
        $issues.Add($msg) | Out-Null
        $overall = "BLOCKED"
    }
}

$report = [ordered]@{
    schema                 = "ai-bot-trade.env-doctor.v1"
    task_id                = "INF-003"
    requirement_id         = "REQ-INF-003"
    rule_id                = "RULE-ENV-001"
    timestamp_utc          = $started.ToString("o")
    host                   = $env:COMPUTERNAME
    user                   = $env:USERNAME
    os                     = [System.Environment]::OSVersion.VersionString
    powershell             = $PSVersionTable.PSVersion.ToString()
    working_directory      = (Get-Location).Path
    repo_root              = $RepoRoot
    overall_status         = $overall
    issues                 = @($issues)
    install_roots_found    = @($roots)
    metaeditor             = $metaInfo
    terminal               = $termInfo
    metatester             = $testerInfo
    git                    = $gitInfo
    tester_agents          = $agents
    terminal_data          = $terminals
    disk                   = $disk
    running_processes      = $running
    discovery_notes        = @(
        "Paths are reported only when discovered via override, registry InstallLocation, known existing directories, or running process image paths.",
        "No executable path is invented.",
        "Read-only inspection; no trading actions."
    )
}

$jsonPath = Join-Path $OutputDir "doctor_report.json"
$txtPath = Join-Path $OutputDir "doctor_report.txt"
($report | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $jsonPath -Encoding UTF8
($script:LogLines -join [Environment]::NewLine) | Set-Content -LiteralPath $txtPath -Encoding UTF8
Write-DoctorLog "wrote $jsonPath"
Write-DoctorLog "wrote $txtPath"
Write-DoctorLog "overall_status=$overall"

if ($overall -eq "PASS") {
    exit 0
}
exit 1
