# INF-003 Post-Merge Verification Summary

- Run ID: run-20261128-inf003-postmerge
- Merge SHA: `d5fa8fe75747f85e6ed3d7f15e408457f4abd6bd`
- Approved HEAD: `8224d7efa84acac14cb5d54e40040f535b811f28`
- Tested r4 source: `ca5cc62351146d6216dc7a518a4b6c8300823a69`
- Host: WIN-8F5G6TCFF1J
- Timestamp UTC: 2026-11-28T14:48:15.343681Z
- Failures: 0
- Issue status: NOT DONE (handoff only)

| Test ID | Status | Expected | Actual |
|---|---|---|---|
| PMV-INF003-001 | PASS | host=WIN-8F5G6TCFF1J; PS=5.1; HEAD=d5fa8fe...; porcelain empty | host=WIN-8F5G6TCFF1J; PS=5.1.17763.9376; HEAD=d5fa8fe75747f85e6ed3d7f15e408457f4abd6bd; clean=True |
| PMV-INF003-002 | PASS | exit=0; overall=PASS; verified_preflight_passed=true; synthetic=false; git HEAD=merge; versions consistent; mapping=unique; operational_agent_ready=false | exit=0; overall=PASS; verified=True; synth=False; head=d5fa8fe75747f85e6ed3d7f15e408457f4abd6bd; versions=5.0.0.6230,5.0.0.6230,5.0.0.6230; mapping=unique; operational_agent_ready=False |
| PMV-INF003-003 | PASS | nonzero exit; verified_preflight_passed=false; actionable diagnostic; no false PASS | exit=1; overall=FAIL; verified=False; issues=['MetaEditorPath override not found: C:\\Program Files\\MetaTrader 5\\DOES_NOT_EXIST_metaeditor64.exe'] |
| PMV-INF003-004 | PASS | source unchanged; clean worktree; user mods preserved; r4 evidence unchanged | pmv=PMV-INF003-004; timestamp_utc=2026-11-28T14:46:21.4452375Z; worktree=C:\Project\ai_bot_trade_inf003_pmv; worktree_head=d5fa8fe75747f85e6ed3d7f15e408457f4abd6bd; worktree_head_equals_merge=True; wo |
