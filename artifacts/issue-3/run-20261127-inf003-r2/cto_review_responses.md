# CTO Review Responses — INF-003 / PR #15

Review basis: Product Owner scoped authorization remains valid. INF-001 remains REWORK.

| # | Question | Result | Evidence |
|---|---|---|---|
| 1 | Diff tested `936f9c0` → final `c12b74d` | **PASS** — only `artifacts/issue-3/run-20261127-inf003/**` added (17 files). No source changes. | `git diff --name-status 936f9c0 c12b74d` |
| 2 | Published SHA256 integrity (original run) | **FAIL (historical)** — `run_manifest.json` hash stale because manifest was enriched after `evidence_sha256.txt` was written. Other 15 hashed files matched. | Corrected in `run-20261127-inf003-r2` with post-finalization hashing; independent re-verify `SHA_MISMATCHES=0`. |
| 3 | Fail-closed missing Tester Agent dirs | **GAP on c12b74d** → **PASS after fix** via `TC-INF-003-D` | `tc-d/` |
| 4 | Nonzero inaccessible required path | **PASS** (already on prior doctor; formalized) via `TC-INF-003-E` | `tc-e/` |
| 5 | Divergent MetaEditor/MT5 builds | **GAP on c12b74d** → **PASS after fix** via `TC-INF-003-F` | `tc-f/` |
| 6 | Discovered dirs vs operational agents | **PASS after clarification** — `discovered_agent_directory_count=20`, `operational_metatester_process_count=0`, `operational_readiness_claimed=false` | `tc-a/doctor_report.json` |
| 7 | Install ↔ data-dir mapping (both installs) | **PASS** — both roots mapped via `origin.txt` | `tc-a` `install_data_mapping` |
| 8 | Secrets in artifacts | **PASS** — secret-pattern scan hits = 0 on published evidence | review probe + r2 artifacts |
| 9 | Governance / templates / trading freeze | **PASS** — `REG-INF-003-1`, `REG-INF-003-2` | CSV / summary |
| 10 | RTM + evidence test IDs / SHA / links | **PASS** — RTM row + r2 manifest `tests`, `artifact_links`, `acceptance_criteria` | `docs/RTM.md`, `run_manifest.json` |

## SHA references (this remediation)

| Role | SHA |
|---|---|
| Historical tested (pre-review) | `936f9c0851cc85650d8602a5441146fadc22a512` |
| Historical evidence pub | `c12b74dc12d5a53d68bd770b6e55721f675af700` |
| Remediation tested | `7835ef901712f9c41a5c5c2d361cc66222e4accb` |
| Remediation evidence pub | *(set on evidence commit)* |

## Root causes corrected

1. Stale evidence hash for mutated manifest.
2. No fail-closed gate for missing Agent-* directories.
3. No FileVersion mismatch gate.
4. Agent directory inventory could be misread as operational readiness.
5. Regression did not explicitly assert governance/template freeze.
