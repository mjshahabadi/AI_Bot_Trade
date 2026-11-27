# Windows / MT5 Environment Doctor (INF-003)

Read-only preflight inventory for Git, MetaEditor 5, MetaTrader 5, MetaTester, tester agents, terminal data, and disk space.

## Run on Windows

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\env-doctor\Invoke-EnvDoctor.ps1 `
  -RepoRoot . `
  -OutputDir .\artifacts\env-doctor\latest `
  -RequireTools
```

Exit code `0` means required tools were found and readable. Nonzero means `FAIL` or `BLOCKED` — inspect `doctor_report.json` and `doctor_report.txt`.

## Optional overrides

| Parameter | Purpose |
|---|---|
| `-MetaEditorPath` | Absolute path to `metaeditor64.exe` (used by negative tests) |
| `-TerminalPath` | Absolute path to `terminal64.exe` |
| `-InstallRoot` | Install directory containing the MT5 executables |
| `-RequireTools` | Fail closed when Git/MetaEditor/terminal/metatester are missing |
| `-RequireAgentDirectories` | Fail closed when discovered `Agent-*` dirs are below `-MinAgentDirectories` |
| `-MinAgentDirectories` | Minimum discovered agent directories (default 1) |
| `-TesterRoot` | Override Tester inventory root (tests only) |
| `-FailOnBuildMismatch` | FAIL when MetaEditor/terminal/metatester FileVersion values differ |
| `-SkipGit` | Skip git inspection (test helpers only) |

Discovered `Agent-*` directories are filesystem inventory only. This tool does **not** claim operational Strategy Tester agent readiness from directory presence.

## Tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tests\inf-003\Test-EnvDoctor.ps1 `
  -RepoRoot .
```

Produces `artifacts/issue-3/run-*/` with raw logs, CSV results, and `run_manifest.json`.
