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

Provide a reproducible, read-only Windows environment doctor with an explicit **StrictPreflight** verified mode. Discover Git, MetaEditor 5, MetaTrader 5, MetaTester, terminal data directories, discovered Agent-* directories, disk space, and historical-data inventory without inventing paths. Strict mode must validate bounded DOS header + PE signature (including `e_lfanew` bounds) and product identity, nonempty version metadata, Git repository/HEAD exit codes, single-install isolation, unique install↔data-directory mapping (missing/ambiguous fail closed; never silent first-match), Agent-* directory minimums, and build consistency. Missing/invalid required inputs must fail closed (BLOCKED/FAIL). Inventory-only mode must not be presented as verified readiness. Discovered Agent-* directories and process presence never equal operational Strategy Tester readiness. Synthetic fixtures used in tests must be explicitly marked, forbidden under StrictPreflight, and must never yield `verified_preflight_passed=true`.

## Approval boundary

This requirement is approved only for Issue #3 / INF-003. It does **not** ratify INF-001, REQ-INF-001, or any other infrastructure requirement. Global governance documents remain PROPOSED where previously marked.

## Trading impact

No trading rule is created, changed, or implied. No live orders. No Strategy Tester trading run is required by this requirement.

## Latest evidence (CTO rework r4) — acceptance PENDING

| Field | Value |
|---|---|
| Run ID | `run-20261127-inf003-r4` |
| Tested SHA | _(filled after source commit + Windows suite)_ |
| Evidence publication SHA | _(filled after evidence commit)_ |
| Branch | `test/issue-3-inf-003-env-doctor` |
| PR | https://github.com/mjshahabadi/AI_Bot_Trade/pull/15 |
| Acceptance | PENDING independent GPT CTO review — **not approved** |
| Prior reviewed HEAD | `46518b3c6a696171ff7ef26afe2c320cddb9feda` |
| Prior tested r3 | `6564d06b964d8af1aa606d3d3ba25618e2acaaa7` |

### Tests (expected 21)

TC-INF-003-A..R, REG-INF-003-1, REG-INF-003-2, TC-INF-003-BIND.

### Artifact links

- `artifacts/issue-3/run-20261127-inf003-r4/run_manifest.json`
- `artifacts/issue-3/run-20261127-inf003-r4/unit_test_results.csv`
- `artifacts/issue-3/run-20261127-inf003-r4/test_summary.md`
- `artifacts/issue-3/run-20261127-inf003-r4/evidence_sha256.txt`
- `artifacts/issue-3/run-20261127-inf003-r4/checksum_independent_verify.txt`
- `artifacts/issue-3/run-20261127-inf003-r4/cto_findings_r4.md`

### Known limitations

- `-SkipGit` is test-only and rejected under `-StrictPreflight`.
- `-AllowSyntheticVersionFixtures` is rejected under `-StrictPreflight`; synthetic metadata never yields `verified_preflight_passed=true`.
- Synthetic version fixtures remain available for isolated non-strict tests only and are marked `synthetic_fixture=true`.
- Verified preflight does not claim Strategy Tester operational agent readiness.
- Multiple MT5 installs require explicit `-InstallRoot` under StrictPreflight.
- Missing/ambiguous data-directory mapping fails closed and does not claim verified mapping.
