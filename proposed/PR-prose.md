# Proposed upstream pull request (not filed)

Target repository: **`tursodatabase/turso`** (Turso Database, `tursodb` CLI).

Patch file: [`turso-compat.patch`](./turso-compat.patch)

Upstream base commit:
[`81fdd4abe8120ed071e3fa0f25f127f60f2941e4`](https://github.com/tursodatabase/turso/commit/81fdd4abe8120ed071e3fa0f25f127f60f2941e4)
(Turso `main` as of 8 September 2026).

Verify before filing:

```sh
curl -fsSLO https://raw.githubusercontent.com/tursodatabase/turso/81fdd4abe8120ed071e3fa0f25f127f60f2941e4/COMPAT.md
git apply --check turso-compat.patch
```

## Why `tursodatabase/turso` rather than `tursodatabase/libsql`

| Concern | Correct upstream |
| --- | --- |
| Whole-file open failure (`invalid expression in CREATE INDEX: libsql_vector_idx`) | **`tursodatabase/turso`** — Turso Database parser/schema loader |
| Vector-index creation, shadow tables, `/dump` full-state export | **`tursodatabase/libsql`** — libSQL server and embedded crate; compatibility statement at [`libsql#compatibility-with-sqlite`](https://github.com/tursodatabase/libsql#compatibility-with-sqlite) |
| Optional portable export mode, dump sanitisation | **`tursodatabase/libsql`** — server exporter and PR #1591 semantics |
| User-facing compatibility matrix for opening SQLite files in Turso | **`tursodatabase/turso`** — `COMPAT.md` |

This proposed PR addresses only the Turso Database documentation gap: files
created by libSQL with vector indexes are SQLite containers whose application
data remains readable after remediation, but Turso Database currently refuses to
open them until the libSQL-specific index schema is removed.

A separate libSQL documentation issue or PR could describe vector indexes as
engine-specific schema objects and document an optional portable export mode;
that is out of scope for this minimal `COMPAT.md` patch.

## Proposed title

`docs: document libSQL vector-index schema portability limits in COMPAT.md`

## Proposed body

```markdown
## Summary

- Document that libSQL `libsql_vector_idx(...)` schema from `sqld` is not openable in Turso Database, while vector blob data remains portable.
- Clarify that the Vector extension section covers value/distance functions, not libSQL DiskANN index schema portability.
- Link to independent reproduction evidence at withnative/libsql-vector-portability-evidence.

## Test plan

- [ ] Docs-only change; no code paths modified.
- [ ] Wording reviewed against withnative/libsql-vector-portability-evidence REPORT.md (managed Turso Cloud not tested there either).
```

## Filing status

**Not filed.** No pull request, issue, or message was sent upstream.
