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
