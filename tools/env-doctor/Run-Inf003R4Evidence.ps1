#Requires -Version 5.1
<#
.SYNOPSIS
  Windows host helper: run INF-003 r4 suite and write immutable evidence under artifacts/issue-3/run-20261127-inf003-r4.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
    [string]$EvidenceDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $EvidenceDir) {
    $EvidenceDir = Join-Path $RepoRoot "artifacts\issue-3\run-20261127-inf003-r4"
}

$head = (git -C $RepoRoot rev-parse HEAD).Trim()
$status = (git -C $RepoRoot status --porcelain=v1)
if (-not [string]::IsNullOrWhiteSpace($status)) {
    throw "Refusing evidence run on dirty worktree:`n$status"
}

Write-Host "INF-003 r4 evidence run"
Write-Host "repo=$RepoRoot"
Write-Host "tested_sha=$head"
Write-Host "evidence=$EvidenceDir"
Write-Host "host=$env:COMPUTERNAME"

$harness = Join-Path $RepoRoot "tests\inf-003\Test-EnvDoctor.ps1"
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $harness -RepoRoot $RepoRoot -EvidenceDir $EvidenceDir
$exit = $LASTEXITCODE

# Independent checksum verification
$shaFile = Join-Path $EvidenceDir "evidence_sha256.txt"
$verifyPath = Join-Path $EvidenceDir "checksum_independent_verify.txt"
$ok = 0; $bad = 0; $lines = @()
if (Test-Path -LiteralPath $shaFile) {
    Get-Content -LiteralPath $shaFile | ForEach-Object {
        if ($_ -match '^([0-9A-Fa-f]{64})\s{2}(.+)$') {
            $want = $Matches[1].ToUpperInvariant()
            $rel = $Matches[2]
            $full = Join-Path $EvidenceDir $rel
            if (-not (Test-Path -LiteralPath $full)) {
                $bad++; $lines += "MISSING  $rel"; return
            }
            $got = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToUpperInvariant()
            if ($got -eq $want) { $ok++; $lines += "OK  $rel" }
            else { $bad++; $lines += "MISMATCH  $rel want=$want got=$got" }
        }
    }
}
@(
    "independent_verify_utc=$((Get-Date).ToUniversalTime().ToString('o'))"
    "tested_sha=$head"
    "host=$env:COMPUTERNAME"
    "harness_exit=$exit"
    "OK=$ok"
    "MISMATCHES=$bad"
) + $lines | Set-Content -LiteralPath $verifyPath -Encoding UTF8

Copy-Item -LiteralPath $verifyPath -Destination (Join-Path $EvidenceDir "checksum_verify_result.txt") -Force

Write-Host "harness_exit=$exit OK=$ok MISMATCHES=$bad"
exit $exit
