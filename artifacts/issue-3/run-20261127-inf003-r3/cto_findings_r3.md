# INF-003 CTO Findings Remediation — r3

Reviewed prior HEAD: `003f17eda16972f94e40bebacb0d82014d2654dd`  
Prior tested r2: `7835ef901712f9c41a5c5c2d361cc66222e4accb`  
This tested SHA: `6564d06b964d8af1aa606d3d3ba25618e2acaaa7`  
Run ID: `run-20261127-inf003-r3`  
Acceptance: **PENDING** (not approved)

| Finding | Severity | Resolution | Evidence |
|---|---|---|---|
| INF003-F01 Fail-closed execution | HIGH | `-StrictPreflight` enables RequireTools, RequireAgentDirectories, FailOnBuildMismatch, ValidateExecutables, FailOnEmptyVersion; inventory_only vs verified_preflight distinguished; MinAgentDirectories validated; operational_agent_ready always false | TC-A, TC-G, TC-N, README |
| INF003-F02 Executable validation | HIGH | MZ/PE structure, product identity, nonempty version; plaintext fake rejected; spaces/Unicode preserved; MT5 not launched | TC-C, TC-H, TC-F/L |
| INF003-F03 Git validation | HIGH | Native exit codes; reject non-repo; validate 40-hex HEAD; fail-closed; SkipGit forbidden under StrictPreflight | TC-I, TC-A, BIND |
| INF003-F04 Installation isolation | MEDIUM | No silent cross-root mix; selected install + data dir recorded; ambiguous/inconsistent rejected | TC-J, TC-A selected_installation |
| INF003-F05 Build validation | MEDIUM | Two nonempty fixture versions + empty metadata + invalid EXE retained; synthetic marked | TC-K, TC-L, TC-H, TC-F |
| INF003-F06 Evidence binding | MEDIUM | Clean worktree + valid SHA required before artifacts; dirty rejected; hashes after finalize | TC-M, BIND, evidence_sha256 + independent verify |
| INF003-F07 Documentation | MEDIUM | PR #15, Issue #3, README, RTM, REQ updated with SHA/run/tests/links/limitations; acceptance not marked approved | this run + PR/Issue comments |

## RED/GREEN notes

- F01/F02/F03 defects confirmed under prior inventory-only / existence-only / unchecked-Git behavior (r1/r2 review); GREEN demonstrated by TC-G/H/I/N on this SHA.
- Assertions were not weakened to obtain PASS.

## Test matrix

All of TC-INF-003-A..N, REG-INF-003-1/2, TC-INF-003-BIND: **PASS** (see `unit_test_results.csv`).
