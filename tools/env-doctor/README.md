# Windows / MT5 Environment Doctor (INF-003)

Read-only preflight inventory and **strict verified preflight** for Git, MetaEditor 5, MetaTrader 5, MetaTester, discovered Agent-* directories, install↔data mapping, and disk space.

This tool does **not** launch trading operations and never claims Strategy Tester **operational** agent readiness from directories or process presence alone.

## Strict verified preflight (mandatory gates)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\env-doctor\Invoke-EnvDoctor.ps1 `
  -RepoRoot . `
  -OutputDir .\artifacts\env-doctor\latest `
  -InstallRoot "C:\Program Files\MetaTrader 5" `
  -StrictPreflight `
  -MinAgentDirectories 1
```

`-StrictPreflight` enables:

- `RequireTools`
- `RequireAgentDirectories`
- `FailOnBuildMismatch`
- `ValidateExecutables` (bounded DOS header + PE signature + product identity)
- `FailOnEmptyVersion`
- Git fail-closed (valid repo + HEAD SHA)
- Single-install isolation (no silent cross-root mixes)
- Unique install↔data-directory mapping (missing/ambiguous fail closed)

`-SkipGit` and `-AllowSyntheticVersionFixtures` are rejected under `-StrictPreflight` (test-only bypasses, not readiness evidence). Synthetic metadata never yields `verified_preflight_passed=true`.

Exit `0` only when verified preflight gates pass. Inspect `doctor_report.json` → `readiness`.

## Inventory-only (non-readiness)

Omit `-StrictPreflight` for discovery/inventory. Inventory-only results are **not** verified environment readiness. Synthetic fixtures remain available for isolated non-strict tests only.

## Parameters

| Parameter | Purpose |
|---|---|
| `-StrictPreflight` | Enable all mandatory readiness gates |
| `-InstallRoot` | Explicit MT5 install (required when multiple installs exist under strict mode) |
| `-MetaEditorPath` / `-TerminalPath` | Absolute overrides; conflicting roots are rejected |
| `-TesterRoot` | Override Tester inventory root (tests) |
| `-TerminalDataRoot` | Override terminal data inventory root (tests; default `%AppData%\MetaQuotes\Terminal`) |
| `-MinAgentDirectories` | Minimum discovered `Agent-*` dirs (must be >= 1) |
| `-RequireTools` / `-RequireAgentDirectories` / `-FailOnBuildMismatch` / `-ValidateExecutables` / `-FailOnEmptyVersion` | Individual gates |
| `-AllowSyntheticVersionFixtures` | Test-only sidecar `*.exe.fixture-meta.json` (forbidden with StrictPreflight) |
| `-SkipGit` | Test-only Git bypass (forbidden with StrictPreflight) |

## Tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tests\inf-003\Test-EnvDoctor.ps1 `
  -RepoRoot .
```

Requires a **clean** git worktree before evidence generation. Dirty trees are rejected via a real isolated-worktree negative probe (`TC-INF-003-M` / BIND). Suite: TC-A..R + REG-1/2 + BIND (21 cases).
