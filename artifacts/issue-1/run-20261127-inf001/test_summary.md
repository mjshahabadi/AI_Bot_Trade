# INF-001 test summary

Run ID: `run-20261127-inf001`

Host: `WIN-8F5G6TCFF1J`

OS: Microsoft Windows NT 10.0.17763.0

PowerShell: 5.1.17763.9376

Baseline: `a428d1cb5a3fc20b0f38fb1bb29653570e3fda2c`

## Attempt 1 — 2026-11-27T11:06:25Z

Command exit code: 1

`TC-INF-001-A1` FAIL. Actual template count was 2: `ai_task-md.md` and `ai_task.md`.

The legacy file was then removed. No expected result was changed.

## Attempt 2 — 2026-11-27T11:06:34Z

Command exit code: 0

13 checks PASS. Raw rows are in `unit_test_results.csv`. Stdout is in `test_stdout.log`.

## Not run

| Item | Status | Reason |
|---|---|---|
| MetaEditor compile | N/A | No MQL5 file is in scope. |
| EX5 hash | N/A | No EX5 was produced. |
| Strategy Tester | N/A | Issue section 15. |
| Optimization | N/A | Issue section 16. |
| Trading functional test | N/A | No EA in the baseline. |
| Integration, performance, smoke beyond this checker | N/A | Not required by the issue test table. |

## Acceptance mapping

AC-001 is not claimed as an approved document. The text is proposed.

AC-002 passed on attempt 2.

AC-003 records unique IDs and does not activate policy authority.
