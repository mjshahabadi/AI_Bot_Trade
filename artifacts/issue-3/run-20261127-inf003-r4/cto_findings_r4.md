# INF-003 CTO Findings Remediation — r4

Reviewed prior HEAD: `46518b3c6a696171ff7ef26afe2c320cddb9feda`  
Prior tested r3: `6564d06b964d8af1aa606d3d3ba25618e2acaaa7`  
Source SHA before Windows host fix: `49aabaa28ca1486ab857fcdc72c867561bd3bf20`  
This tested SHA: `ca5cc62351146d6216dc7a518a4b6c8300823a69`  
Run ID: `run-20261127-inf003-r4`  
Host: `WIN-8F5G6TCFF1J` (local Windows)  
Acceptance: **PENDING** (not approved)

| Finding | Severity | Resolution | Evidence |
|---|---|---|---|
| INF003-F08 PE / e_lfanew bounds | HIGH | Bounded DOS+PE validation accumulates diagnostics; malformed MZ-prefixed stubs rejected | TC-O, doctor ValidateExecutables |
| INF003-F09 Synthetic under StrictPreflight | HIGH | StrictPreflight rejects AllowSyntheticVersionFixtures; synthetic never yields verified_preflight_passed=true | TC-P |
| INF003-F10 Data-directory mapping | HIGH | Missing/ambiguous install↔data mapping fails closed; no silent first-match | TC-Q, TC-R |
| INF003-F11 AppData / path hardening | MEDIUM | Terminal data discovery hardened; selected install mapping recorded | TC-A mapping=unique |
| INF003-F12 Evidence / harness isolation | MEDIUM | Isolated dirty-tree probe for TC-M; EvidenceDir excluded from user_untouched porcelain comparison (see host defect below) | TC-M, BIND |

## Windows host defect found on first r4 attempt (scoped harness fix)

Against clean HEAD `49aabaa…`, the suite executed on `WIN-8F5G6TCFF1J` and **TC-INF-003-M FAIL**ed with:

- `binding_rejected=True` (dirty probe correctly rejected)
- `user_untouched=False`

Root cause: `user_untouched` required primary-worktree porcelain to be empty **and** unchanged, but r4 evidence is written under `artifacts/issue-3/run-20261127-inf003-r4/` inside the repo, so porcelain is non-empty by design once the suite starts. Assertions were not weakened on binding rejection; only the porcelain comparison scope was corrected to exclude `EvidenceDir` and to assert the dirty marker never lands in the user tree.

Fix commit (this tested SHA): `ca5cc62351146d6216dc7a518a4b6c8300823a69`  
Doctor (`Invoke-EnvDoctor.ps1`) was **not** rewritten for this defect.

## RED/GREEN notes

- First Windows execution (RED): TC-M FAIL on `49aabaa…` as above; 20/21 other cases already PASS; checksum OK=78 MISMATCHES=0 on that incomplete run.
- GREEN: full suite re-run on `ca5cc62…` → **21/21 PASS**, independent SHA256 recount **OK=78 BAD=0**.

## Test matrix

All of TC-INF-003-A..R, REG-INF-003-1/2, TC-INF-003-BIND: **PASS** (see `unit_test_results.csv`).
