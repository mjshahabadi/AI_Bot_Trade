# AI_Bot_Trade — Project Charter

| Field | Value |
|---|---|
| Document ID | CHARTER-001 |
| Version | 1.0-proposed |
| Requirement | REQ-INF-001 |
| Rule | RULE-GOV-001 |
| Issue | #1 |
| Baseline SHA | a428d1cb5a3fc20b0f38fb1bb29653570e3fda2c |
| Status | PROPOSED |
| Authority effect | None until GPT CTO accepts the INF-001 pull request |

This document fills the previously empty charter. It does not replace `.github/AGENTS.md` version 1.0 and it does not introduce a trading rule.

## 1. Purpose

AI_Bot_Trade builds and verifies MQL5 software for MetaTrader 5 under an independent review gate. Infrastructure work comes before any trading-logic change. GitHub Issues are the only official task source.

## 2. Roles

| Role | Authority |
|---|---|
| Repository owner | Approves policy authority by accepting a reviewed change. Account of record: mjshahabadi. |
| GPT CTO | Project manager, architect, QA lead, and sole independent accepter. Merge and DONE require this acceptance. |
| Cursor AI | Implements one approved issue at a time, supplies real evidence, and opens the pull request. |
| Final approver | GPT CTO. A second final approver is a conflict and is BLOCKED. |

Cursor AI cannot merge, cannot close an issue as DONE, cannot push to `main`, and cannot place a live order.

## 3. Precedence

When two instructions disagree, the earlier item in this list wins:

1. Trading-logic freeze, and the explicit in-scope text of an accepted issue.
2. GPT CTO acceptance on the pull request.
3. `.github/AGENTS.md` version 1.0 and `.github/GPT_MASTER_GOVERNANCE.md` while those two files remain the owner-uploaded baseline.
4. This charter, `.github/TEST_POLICY.md`, and `.github/DEFINITION_OF_DONE.md` after GPT acceptance. Until that acceptance they are proposals.
5. The canonical issue template and the open issue body.
6. A chat or automation prompt. A prompt cannot weaken items 1 through 4.

If `.github/AGENTS.md` and `.github/GPT_MASTER_GOVERNANCE.md` ever diverge, the stricter rule that avoids an unapproved trading change wins. The divergence is recorded and the issue is BLOCKED until the owner decides. Silent downgrade is not allowed.

## 4. Recorded baseline conflict

On baseline `a428d1cb5a3fc20b0f38fb1bb29653570e3fda2c` the files `.github/AGENTS.md` and `.github/GPT_MASTER_GOVERNANCE.md` are byte-identical. SHA-256:

`C7ABA1687F898A7523697DEFCC93E9F475F4CE8C8621861749BE870AB7DA108E`

Both titles say "Autonomous MQL5 Development & Testing Agent". INF-001 does not rewrite either file. The duplicate filename is a documented conflict of identity, not a second policy.

## 5. Trading freeze

No entry, exit, signal, risk, volume, stop-loss, take-profit, trailing stop, timeframe, symbol, or optimization rule is ratified here. There is no Expert Advisor in this repository baseline. Strategy regression is N/A until an EA exists, because there is no trading behavior to compare. N/A still requires this reason.

## 6. Status contract

| Issue label | Meaning |
|---|---|
| status:backlog | Not eligible for implementation. |
| status:ready | Eligible only when Definition of Ready in the issue is satisfied. |
| status:in-progress | Claimed. One issue at a time. |
| status:rework | A valid GPT finding is being fixed. |
| status:blocked | Missing approval, access, data, or an unresolved authority conflict. |
| status:ready-for-review | Required evidence is published. Waiting for GPT. |
| DONE | Set only by GPT after acceptance and an authorized merge. |

Developer Status `COMPLETED` means the developer finished the handoff. It is not Issue Status `DONE`.

## 7. N/A and evidence policy

Allowed result values are PASS, FAIL, BLOCKED, NOT RUN, UNVERIFIED, and N/A. N/A is valid only with a written reason. PASS requires a real run tied to the commit SHA. Missing logs or a stale SHA are UNVERIFIED, never PASS. Compilation is N/A when the issue changes no MQL5. Strategy Tester is N/A when the issue says so.

## 8. Scope of this ratification

In scope: the empty charter, test policy, and definition of done; one canonical issue template; the RTM foundation. Out of scope: branch protection, toolchain doctor, test harness, CI, trading logic, and live trading. Those remain on their own issues.
