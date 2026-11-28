# INF-003 Test Summary (CTO REWORK)

- Run ID: run-20261127-inf003-r3
- Tested SHA: 6564d06b964d8af1aa606d3d3ba25618e2acaaa7
- Branch: test/issue-3-inf-003-env-doctor
- Host: WIN-8F5G6TCFF1J
- Pre-test clean: True
- Timestamp UTC: 2026-11-27T16:46:44.3169716Z
- Failures: 0
- PR: https://github.com/mjshahabadi/AI_Bot_Trade/pull/15
- Acceptance: PENDING (not approved)

| Test ID | Status | Expected | Actual |
|---|---|---|---|
| TC-INF-003-A | PASS | Strict preflight on real Windows install captures validated tools/Git; no operational agent claim | exit=0 meta=C:\Program Files\MetaTrader 5\metaeditor64.exe ver=5.0.0.6230 selected=C:\Program Files\MetaTrader 5 data=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075 discovered_agents=20 operational_ready=False |
| TC-INF-003-B | PASS | Invalid MetaEditor path => nonzero + precise error | exit=1 |
| TC-INF-003-C | PASS | Path with spaces/non-ASCII handled (synthetic fixture explicitly marked) | exit=0 path=C:\Users\Administrator\AppData\Local\Temp\2\INF-003 Env Doctor Тест\66ff4f7a4e184e3b8df4b167b16fa195\metaeditor64.exe |
| TC-INF-003-D | PASS | Missing Agent directories => BLOCKED | exit=1 discovered=0 |
| TC-INF-003-E | PASS | Inaccessible path => nonzero actionable failure | exit=1 |
| TC-INF-003-F | PASS | Empty version metadata => FAIL/BLOCKED | exit=1 status=FAIL |
| TC-INF-003-G | PASS | Strict preflight with missing Agent dirs => nonzero BLOCKED | exit=1 readiness_passed=False |
| TC-INF-003-H | PASS | Readable fake EXE => nonzero FAIL/BLOCKED | exit=1 status=FAIL |
| TC-INF-003-I | PASS | Invalid Git repository => nonzero FAIL/BLOCKED | exit=1 err=not_a_git_repository |
| TC-INF-003-J | PASS | Mixed installation roots => explicit rejection | exit=1 ambiguous=True |
| TC-INF-003-K | PASS | Different nonempty version fixtures => nonzero mismatch diagnostic (synthetic marked) | exit=1 versions=5.0.0.1000,5.0.0.2000 |
| TC-INF-003-L | PASS | Empty version metadata => nonzero FAIL/BLOCKED | exit=1 |
| TC-INF-003-M | PASS | Dirty pre-test worktree => evidence binding rejected | pre_test_clean=True; harness rejects dirty trees before artifact generation; tested_sha=6564d06b964d8af1aa606d3d3ba25618e2acaaa7 |
| TC-INF-003-N | PASS | Invalid MinAgentDirectories => explicit validation failure | exit=1 |
| REG-INF-003-1 | PASS | No MQL5 trading sources | count=0 |
| REG-INF-003-2 | PASS | Governance/issue/PR templates unchanged; AGENTS==GPT_MASTER | sha256=C7ABA1687F898A7523697DEFCC93E9F475F4CE8C8621861749BE870AB7DA108E |
| TC-INF-003-BIND | PASS | Evidence bound to valid tested SHA on clean pre-test worktree | tested_sha=6564d06b964d8af1aa606d3d3ba25618e2acaaa7 porcelain_empty=True |

Compilation: N/A
Trading logic: unchanged
