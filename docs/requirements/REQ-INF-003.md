# REQ-INF-003 â€” Windows MQL5 toolchain environment doctor

| Field | Value |
|---|---|
| ID | REQ-INF-003 |
| Rule | RULE-ENV-001 |
| Issue | #3 |
| Status | APPROVED (scoped) |
| Approval | Product Owner explicit authorization on 2026-11-27 for INF-003 only |
| Source | Issue #3 body Â§21 and authorization comment |

## Statement

Provide a reproducible, read-only Windows environment doctor with an explicit **StrictPreflight** verified mode. Discover Git, MetaEditor 5, MetaTrader 5, MetaTester, terminal data directories, discovered Agent-* directories, disk space, and historical-data inventory without inventing paths. Strict mode must validate bounded DOS header + PE signature (including `e_lfanew` bounds) and product identity, nonempty version metadata, Git repository/HEAD exit codes, single-install isolation, unique installâ†”data-directory mapping (missing/ambiguous fail closed; never silent first-match), Agent-* directory minimums, and build consistency. Missing/invalid required inputs must fail closed (BLOCKED/FAIL). Inventory-only mode must not be presented as verified readiness. Discovered Agent-* directories and process presence never equal operational Strategy Tester readiness. Synthetic fixtures used in tests must be explicitly marked, forbidden under StrictPreflight, and must never yield `verified_preflight_passed=true`.

## Approval boundary

This requirement is approved only for Issue #3 / INF-003. It does **not** ratify INF-001, REQ-INF-001, or any other infrastructure requirement. Global governance documents remain PROPOSED where previously marked.

## Trading impact

No trading rule is created, changed, or implied. No live orders. No Strategy Tester trading run is required by this requirement.

## Latest evidence (CTO rework r4) â€” acceptance PENDING

| Field | Value |
|---|---|
| Run ID | `run-20261127-inf003-r4` |
| Tested SHA | `ca5cc62351146d6216dc7a518a4b6c8300823a69` |
| Host | `WIN-8F5G6TCFF1J` (local Windows / PS 5.1) |
| Suite result | **21/21 PASS** (TC-A..R + REG-1/2 + BIND); TC-M dirty-worktree negative verified |
| Historical Windows SHA256 list | `evidence_sha256.txt` â€” 78 entries â€” **preserved / not overwritten** (LFâ†”CRLF historical note per CTO F14) |
| Canonical Git-blob SHA256 (F14) | `evidence_sha256_git_blobs.txt` â€” **82/82 matches / 0 mismatches** via `git cat-file` blob bytes at reviewed HEAD `9f9f1daef0620d3f82dc05a080f29b402251673e` |
| Evidence publication SHA (r4 Windows) | `7c906a18055e698a7f39321e904ff2ed2c864f41` (separate from tested_commit) |
| F14 supplemental publication SHA | `a1091a9bfee99c79dcee9ca01748f0f208e770dc` (separate from tested_commit) |
| Branch | `test/issue-3-inf-003-env-doctor` |
| PR | https://github.com/mjshahabadi/AI_Bot_Trade/pull/15 |
| Acceptance | PENDING independent GPT CTO review â€” **not approved** |
| Prior reviewed HEAD (pre-F14) | `9f9f1daef0620d3f82dc05a080f29b402251673e` |
| Prior remote HEAD at handoff | `49aabaa28ca1486ab857fcdc72c867561bd3bf20` |
| Prior tested r3 | `6564d06b964d8af1aa606d3d3ba25618e2acaaa7` |

### Tests (expected 21)

TC-INF-003-A..R, REG-INF-003-1, REG-INF-003-2, TC-INF-003-BIND â€” all **PASS** on tested SHA above. No suite rerun for F14.

### Artifact links

- `artifacts/issue-3/run-20261127-inf003-r4/run_manifest.json`
- `artifacts/issue-3/run-20261127-inf003-r4/unit_test_results.csv`
- `artifacts/issue-3/run-20261127-inf003-r4/test_summary.md`
- `artifacts/issue-3/run-20261127-inf003-r4/evidence_sha256.txt` (historical Windows list; preserved)
- `artifacts/issue-3/run-20261127-inf003-r4/checksum_independent_verify.txt`
- `artifacts/issue-3/run-20261127-inf003-r4/cto_findings_r4.md`
- `artifacts/issue-3/run-20261127-inf003-r4/evidence_sha256_git_blobs.txt` (F14 canonical Git-blob SHA256; 82 entries)
- `artifacts/issue-3/run-20261127-inf003-r4/evidence_sha256_git_blobs_verify.txt` (F14 verification report; 82/82)

### Known limitations

- `-SkipGit` is test-only and rejected under `-StrictPreflight`.
- `-AllowSyntheticVersionFixtures` is rejected under `-StrictPreflight`; synthetic metadata never yields `verified_preflight_passed=true`.
- Synthetic version fixtures remain available for isolated non-strict tests only and are marked `synthetic_fixture=true`.
- Verified preflight does not claim Strategy Tester operational agent readiness.
- Multiple MT5 installs require explicit `-InstallRoot` under StrictPreflight.
- Missing/ambiguous data-directory mapping fails closed and does not claim verified mapping.
