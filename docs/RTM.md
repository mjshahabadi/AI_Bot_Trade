# Requirements Traceability Matrix

| Field | Value |
|---|---|
| Document ID | RTM-001 |
| Version | 1.0-proposed |
| Issue | #1 |
| Baseline SHA | a428d1cb5a3fc20b0f38fb1bb29653570e3fda2c |
| Authority effect | None. PROPOSED is not approval. |

INF-001 starts the matrix. REQ-INF-001 remains PROPOSED pending GPT CTO acceptance. REQ-INF-003 received a **scoped** Product Owner approval on 2026-11-27 for Issue #3 only; that approval does not ratify INF-001 or other rows. Remaining rows are an index of open issues so identifiers stay unique.

| Requirement | Rule | Issue | This change | Approval | Authority effect |
|---|---|---|---|---|---|
| REQ-INF-001 | RULE-GOV-001 | #1 | Charter, Test Policy, DoD, canonical template, this RTM | PROPOSED pending GPT CTO acceptance | None until acceptance |
| REQ-INF-002 | RULE-GOV-002 | #2 | Not modified | NOT APPROVED | None |
| REQ-INF-003 | RULE-ENV-001 | #3 | Env doctor StrictPreflight + TC-INF-003-A..R + REG-INF-003-1/2 + BIND (21 cases; PR #15 CTO rework r4). Tested SHA `ca5cc62351146d6216dc7a518a4b6c8300823a69` on host `WIN-8F5G6TCFF1J`; Run `run-20261127-inf003-r4` **21/21 PASS**; historical Windows SHA256 list 78 entries preserved; INF003-F14 supplemental canonical Git-blob SHA256 **82/82 matches / 0 mismatches** (`evidence_sha256_git_blobs.txt` + verify). Evidence: `artifacts/issue-3/run-20261127-inf003-r4/`. Acceptance **PENDING**. | APPROVED scoped by Product Owner 2026-11-27; does NOT ratify INF-001; acceptance PENDING GPT CTO | Scoped execution authority for Issue #3 only; acceptance PENDING GPT CTO |
| REQ-INF-004 | Not read | #4 | Not modified | NOT APPROVED | None |
| REQ-INF-005 | Not read | #5 | Not modified | NOT APPROVED | None |
| REQ-INF-006 | Not read | #6 | Not modified | NOT APPROVED | None |
| REQ-INF-007 | Not read | #7 | Not modified | NOT APPROVED | None |
| REQ-INF-008 | Not read | #8 | Not modified | NOT APPROVED | None |
| REQ-INF-009 | Not read | #9 | Not modified | NOT APPROVED | None |
| REQ-INF-010 | Not read | #10 | Not modified | NOT APPROVED | None |
| REQ-INF-011 | Not read | #11 | Not modified | NOT APPROVED | None |
| REQ-INF-012 | Not read | #12 | Not modified | NOT APPROVED | None |

REQ-INF-004 through REQ-INF-012 use the issue title sequence only. Rule IDs for those rows stay "Not read" until each issue is selected.
