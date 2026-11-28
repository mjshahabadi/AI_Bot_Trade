# INF-003 Test Summary (CTO REWORK r4)

- Run ID: run-20261127-inf003-r4
- Tested SHA: ca5cc62351146d6216dc7a518a4b6c8300823a69
- Branch: test/issue-3-inf-003-env-doctor
- Host: WIN-8F5G6TCFF1J
- Pre-test clean: True
- Timestamp UTC: 2026-11-28T02:23:50.9976299Z
- Failures: 0
- Distinct tests: 21 (expected 21)
- PR: https://github.com/mjshahabadi/AI_Bot_Trade/pull/15
- Acceptance: PENDING (not approved)

| Test ID | Status | Expected | Actual |
|---|---|---|---|
| TC-INF-003-A | PASS | Strict preflight on real Windows install captures validated tools/Git; no operational agent claim | exit=0 meta=C:\Program Files\MetaTrader 5\metaeditor64.exe ver=5.0.0.6230 selected=C:\Program Files\MetaTrader 5 data=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075 discovered_agents=20 operational_ready=False mapping=unique |
| TC-INF-003-B | PASS | Invalid MetaEditor path => nonzero + precise error | exit=1 |
| TC-INF-003-C | PASS | Path with spaces/non-ASCII handled (synthetic fixture explicitly marked) | exit=0 path=C:\Users\Administrator\AppData\Local\Temp\2\INF-003 Env Doctor Тест\955cdd47dae74dd5822033fd7c938639\metaeditor64.exe |
| TC-INF-003-D | PASS | Missing Agent directories => BLOCKED | exit=1 discovered=0 |
| TC-INF-003-E | PASS | Inaccessible path => nonzero actionable failure | exit=1 |
| TC-INF-003-F | PASS | Empty version metadata => FAIL/BLOCKED | exit=1 status=FAIL |
| TC-INF-003-G | PASS | Strict preflight with missing Agent dirs => nonzero BLOCKED | exit=1 readiness_passed=False |
| TC-INF-003-H | PASS | Readable fake EXE => nonzero FAIL/BLOCKED | exit=1 status=FAIL |
| TC-INF-003-I | PASS | Invalid Git repository => nonzero FAIL/BLOCKED | exit=1 err=not_a_git_repository |
| TC-INF-003-J | PASS | Mixed installation roots => explicit rejection | exit=1 ambiguous=True |
| TC-INF-003-K | PASS | Different nonempty version fixtures => nonzero mismatch diagnostic (synthetic marked) | exit=1 versions=5.0.0.1000,5.0.0.2000 |
| TC-INF-003-L | PASS | Empty version metadata => nonzero FAIL/BLOCKED | exit=1 |
| TC-INF-003-N | PASS | Invalid MinAgentDirectories => explicit validation failure | exit=1 |
| TC-INF-003-O | PASS | MZ-prefixed malformed executable must be rejected | exit=1 pe_mz_valid=False |
| TC-INF-003-P | PASS | Strict preflight with synthetic fixtures => nonzero + explicit rejection | exit=1 verified_passed=False |
| TC-INF-003-Q | PASS | Missing selected-install data-directory mapping => explicit rejection | exit=1 status=missing reason=No terminal data directory origin.txt maps to selected install root: C:\Users\ADMINI~1\AppData\Local\Temp\2\inf003-q-install-3c0a62ab4e1344cbaad8e7e88c23216d |
| TC-INF-003-R | PASS | Ambiguous selected-install data-directory mapping => refuse first-match | exit=1 status=ambiguous reason=Ambiguous terminal data-directory mapping for install root C:\Users\ADMINI~1\AppData\Local\Temp\2\inf003-r-install-093077541d3a43218896b15176779040; matches=2 terminals=AAAA1111BBBB2222CCCC3333DDDD4444,EEEE5555FFFF6666AAAA7777BBBB8888. Refusing silent first-match selection. |
| TC-INF-003-M | PASS | Dirty pre-test worktree => evidence binding rejected (isolated worktree negative test) | exit=1; dirty_porcelain=<<?? INF003-DIRTY-MARKER.txt>>; binding_rejected=true; user_untouched=True |
| REG-INF-003-1 | PASS | No MQL5 trading sources | count=0 |
| REG-INF-003-2 | PASS | Governance/issue/PR templates unchanged; AGENTS==GPT_MASTER | sha256=C7ABA1687F898A7523697DEFCC93E9F475F4CE8C8621861749BE870AB7DA108E |
| TC-INF-003-BIND | PASS | Evidence bound to valid tested SHA on clean pre-test worktree | tested_sha=ca5cc62351146d6216dc7a518a4b6c8300823a69 porcelain_empty=True |

Compilation: N/A
Trading logic: unchanged
