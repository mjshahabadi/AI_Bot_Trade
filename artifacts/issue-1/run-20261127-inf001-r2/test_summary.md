# INF-001 bound rerun

Run ID: `run-20261127-inf001-r2`

Tested source commit: `54ac899e89b47ae988986dd7e54888c9158b55bb`

This commit was clean when the checker started. The commit that adds this directory is only the evidence publication and was not the tested revision.

Timestamp: 2026-11-27T13:53:29Z

Host: `cursor`

OS: Linux 6.12.113+ x86_64

PowerShell: 7.7.0

Exit code: 0

14 checks PASS, including `TC-INF-001-BIND`.

The earlier run `run-20261127-inf001` stays in the tree as the original Windows evidence. Its source binding is UNVERIFIED because that pass happened before the first commit.
