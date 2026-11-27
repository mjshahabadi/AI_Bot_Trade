# INF-003 Test Summary

- Run ID: run-20261127-inf003-r2
- Tested SHA: 7835ef901712f9c41a5c5c2d361cc66222e4accb
- Branch: test/issue-3-inf-003-env-doctor
- Host: WIN-8F5G6TCFF1J
- Timestamp UTC: 2026-11-27T15:32:30.8551479Z
- Failures: 0
- PR: https://github.com/mjshahabadi/AI_Bot_Trade/pull/15

| Test ID | Status | Expected | Actual |
|---|---|---|---|
| TC-INF-003-A | PASS | Doctor captures real MetaEditor/MT5/Git absolute paths/versions plus install-data map; agents classified without operational claim | exit=0 meta=C:\Program Files\MetaTrader 5\metaeditor64.exe ver=5.0.0.6230 term=C:\Program Files\MetaTrader 5\terminal64.exe git=C:\Program Files\Git\cmd\git.exe mapped_roots=2 discovered_agents=20 operational_metatester=0 readiness_claimed=False |
| TC-INF-003-B | PASS | Invalid MetaEditor path => nonzero exit and precise error | exit=1 precise_error=true path=C:\Program Files\MetaTrader 5\metaeditor64-DOES-NOT-EXIST.exe |
| TC-INF-003-C | PASS | Path with spaces/non-ASCII correctly handled or explicitly BLOCKED | handled spaced/unicode path exit=0 path=C:\Users\Administrator\AppData\Local\Temp\2\INF-003 Env Doctor Тест\MetaTrader 5\metaeditor64.exe mode=copy |
| TC-INF-003-D | PASS | Missing/unavailable Tester Agent directories => nonzero BLOCKED | exit=1 status=BLOCKED discovered=0 |
| TC-INF-003-E | PASS | Inaccessible required MetaEditor path => nonzero actionable failure | exit=1 precise_error=true status=FAIL |
| TC-INF-003-F | PASS | Differing MetaEditor/MT5 FileVersion => FAIL with mismatch evidence | exit=1 versions=5.0.0.6230,EMPTY |
| REG-INF-003-1 | PASS | No MQL5 trading sources present/changed for this infrastructure issue | mq5/mqh/ex5 count=0 under repo worktree |
| REG-INF-003-2 | PASS | Governance/issue/PR templates unchanged vs claim baseline; AGENTS==GPT_MASTER hash | delta_count=0 agents_gpt_identical=True sha256=C7ABA1687F898A7523697DEFCC93E9F475F4CE8C8621861749BE870AB7DA108E |
| TC-INF-003-BIND | PASS | Evidence bound to full tested commit SHA on clean evaluation tree | tested_sha=7835ef901712f9c41a5c5c2d361cc66222e4accb branch=test/issue-3-inf-003-env-doctor porcelain_empty=True |

Compilation: N/A (no MQL5 in scope)
Trading logic: unchanged
Governance templates: REG-INF-003-2
