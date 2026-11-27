# REQ-INF-003 — Windows MQL5 toolchain environment doctor

| Field | Value |
|---|---|
| ID | REQ-INF-003 |
| Rule | RULE-ENV-001 |
| Issue | #3 |
| Status | APPROVED (scoped) |
| Approval | Product Owner explicit authorization on 2026-11-27 for INF-003 only |
| Source | Issue #3 body §21 and authorization comment |

## Statement

Provide a reproducible, read-only Windows environment doctor with an explicit **StrictPreflight** verified mode. Discover Git, MetaEditor 5, MetaTrader 5, MetaTester, terminal data directories, discovered Agent-* directories, disk space, and historical-data inventory without inventing paths. Strict mode must validate executable MZ/PE structure and product identity, nonempty version metadata, Git repository/HEAD exit codes, single-install isolation, Agent-* directory minimums, and build consistency. Missing/invalid required inputs must fail closed (BLOCKED/FAIL). Inventory-only mode must not be presented as verified readiness. Discovered Agent-* directories and process presence never equal operational Strategy Tester readiness. Synthetic fixtures used in tests must be explicitly marked and distinguished from real toolchain evidence.

## Approval boundary

This requirement is approved only for Issue #3 / INF-003. It does **not** ratify INF-001, REQ-INF-001, or any other infrastructure requirement. Global governance documents remain PROPOSED where previously marked.

## Trading impact

No trading rule is created, changed, or implied. No live orders. No Strategy Tester trading run is required by this requirement.

## Latest evidence (CTO rework r3) — acceptance PENDING

| Field | Value |
|---|---|
| Run ID | `run-20261127-inf003-r3` |
| Tested SHA | `6564d06b964d8af1aa606d3d3ba25618e2acaaa7` |
| Branch | `test/issue-3-inf-003-env-doctor` |
| PR | https://github.com/mjshahabadi/AI_Bot_Trade/pull/15 |
| Acceptance | PENDING independent GPT CTO review — **not approved** |
| Independent SHA256 verify | OK=58, MISMATCHES=0 |

### Tests

TC-INF-003-A..N, REG-INF-003-1, REG-INF-003-2, TC-INF-003-BIND — all **PASS** (genuine host/fixture runs).

### Artifact links

- `artifacts/issue-3/run-20261127-inf003-r3/run_manifest.json`
- `artifacts/issue-3/run-20261127-inf003-r3/unit_test_results.csv`
- `artifacts/issue-3/run-20261127-inf003-r3/test_summary.md`
- `artifacts/issue-3/run-20261127-inf003-r3/evidence_sha256.txt`
- `artifacts/issue-3/run-20261127-inf003-r3/checksum_independent_verify.txt`
- `artifacts/issue-3/run-20261127-inf003-r3/cto_findings_r3.md`

### Known limitations

- `-SkipGit` is test-only and rejected under `-StrictPreflight`.
- Synthetic version fixtures are marked `synthetic_fixture=true` and are not real toolchain evidence.
- Verified preflight does not claim Strategy Tester operational agent readiness.
- Multiple MT5 installs require explicit `-InstallRoot` under StrictPreflight.
