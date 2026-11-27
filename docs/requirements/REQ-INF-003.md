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

Provide a reproducible, read-only Windows environment doctor that discovers Git, MetaEditor 5, MetaTrader 5, MetaTester, terminal data directories, tester agents, disk space, and historical-data inventory from the filesystem, registry, and running processes. Executable paths must not be invented. Missing required tools must produce a nonzero exit with actionable diagnostics (BLOCKED/FAIL), never a false PASS.

## Approval boundary

This requirement is approved only for Issue #3 / INF-003. It does **not** ratify INF-001, REQ-INF-001, or any other infrastructure requirement. Global governance documents remain PROPOSED where previously marked.

## Trading impact

No trading rule is created, changed, or implied. No live orders. No Strategy Tester trading run is required by this requirement.
