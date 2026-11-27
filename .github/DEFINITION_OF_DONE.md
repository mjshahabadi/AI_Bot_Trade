# AI_Bot_Trade — Definition of Ready and Definition of Done

| Field | Value |
|---|---|
| Document ID | DOD-001 |
| Version | 1.0-proposed |
| Requirement | REQ-INF-001 |
| Rule | RULE-GOV-001 |
| Issue | #1 |
| Status | PROPOSED |
| Authority effect | None until GPT CTO accepts the INF-001 pull request |

## 1. Definition of Ready

An issue may be claimed only when all of the following are true:

- The issue is open and labeled for implementation.
- Requirement IDs, scope, out of scope, and acceptance criteria are written and measurable.
- Dependencies are closed or explicitly none.
- Baseline commit SHA is identified.
- Required tests are listed, including the N/A reason for tests that do not apply.
- No other agent has an active claim.
- The issue is not an epic and is not only a management container.

If requirement approval is itself the work of the issue, as in INF-001, the developer may propose the text. The proposal does not change policy authority. GPT CTO acceptance is the approval evidence.

Incomplete acceptance criteria, or two different final approvers, are BLOCKED. They are never treated as READY.

## 2. Definition of Done

Done requires every item below. Cursor AI cannot mark the issue DONE.

- In-scope work is complete and out-of-scope files are unchanged.
- Real compilation has zero errors and zero warnings, or compilation is N/A with a reason.
- Every required test has a real status. Mandatory PASS cases passed. N/A cases have reasons.
- Evidence manifest, logs, and RTM links match the final commit SHA.
- Acceptance criteria are met, or an unmet criterion is explicitly not claimed as PASS.
- Developer self-review is recorded.
- GPT CTO independent review is approved.
- The pull request is merged by an authorized reviewer.
- Post-merge verification is recorded.

## 3. Handoff status

When the developer finishes the required runs, the developer status is COMPLETED and the issue label is `status:ready-for-review`. That handoff is not DONE and is not permission to merge.

## 4. Blocked

Use BLOCKED when approval, admin access, history, or a tool required by the issue is missing, or when the same in-scope failure remains after three documented attempts. Record the question on the issue. Do not invent the missing approval.
