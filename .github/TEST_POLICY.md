# AI_Bot_Trade — Test Policy

| Field | Value |
|---|---|
| Document ID | TEST-POLICY-001 |
| Version | 1.0-proposed |
| Requirement | REQ-INF-001 |
| Rule | RULE-GOV-001 |
| Issue | #1 |
| Status | PROPOSED |
| Authority effect | None until GPT CTO accepts the INF-001 pull request |

This policy restates the test rules already present in `.github/AGENTS.md` version 1.0. It adds no trading rule and no performance target.

## 1. Result values

Every test case records Test ID, Requirement ID, subject, input, expected result, actual result, and one status:

PASS, FAIL, BLOCKED, NOT RUN, UNVERIFIED, N/A.

N/A requires a reason. A test that was not executed is NOT RUN. A test whose log or commit SHA cannot be checked is UNVERIFIED. No status may be invented.

## 2. What counts as a test

Unit tests exercise deterministic logic through the project test harness, or through a static checker when the issue is documentation-only. A Strategy Tester backtest is not a unit test. Profit, win rate, or a green compile exit code alone is not acceptance.

Required cases in the issue are mandatory. Weakening or deleting a test to obtain PASS is forbidden.

## 3. Compilation

When MQL5 is in scope, MetaEditor 5 must compile the changed sources. The compile log is kept. Zero errors and zero warnings are required for those in-scope sources. The EX5 used in a later test must be the file produced by that compile, identified by hash and time. An old EX5 is not evidence for a new commit.

When the issue changes no MQL5, compilation is N/A with that reason. A missing compiler on an issue that requires compilation is BLOCKED.

## 4. Strategy Tester and optimization

Tester symbol, timeframe, dates, tick model, deposit, leverage, account mode, and set file come from the issue. They are not inferred. If the issue requires real ticks, the model is "Every tick based on real ticks". Missing history is BLOCKED. The tick model is not changed to force a run.

Complete optimization uses the slow complete algorithm unless the accepted issue names another algorithm. Pass counts are reported from the tester output. The highest-profit row is not automatically the selected parameter set.

## 5. Functional and regression checks

When trading behavior is in scope, evidence must cover why a signal was accepted or rejected, direction, entry conditions, stop-loss, take-profit, volume, and duplicate-order control. A change to existing behavior needs a baseline run and a new run with the same settings. Expected differences must map to an acceptance criterion. A higher profit does not justify an unapproved trading change.

This infrastructure issue has no EA. Functional trading checks and strategy regression are N/A because no trading behavior exists in the baseline.

## 6. Failures

A failed test is fixed inside the issue scope and rerun. The expected result is not edited to match the code. The same failure after three documented attempts is BLOCKED with the logs attached.

## 7. Evidence

Each run has one Run ID. The manifest records issue, branch, baseline SHA, final SHA, timestamp, host tool versions, configuration, expected result, actual result, status, and artifact path. Files that were not produced are omitted. Secrets and tokens are redacted.
