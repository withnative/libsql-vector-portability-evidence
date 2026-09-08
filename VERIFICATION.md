# Recorded verification runs

The canonical reproduction is assertion-driven: it exits non-zero if an
expected failure is absent or if the recovery and control checks do not pass.
The excerpts below are condensed from complete `results.txt` transcripts; no
database artifacts or local filesystem paths are embedded in this repository.

## macOS arm64

Run on 30 July 2026:

```text
platform: Darwin arm64
sqld: sqld 0.24.32
tursodb: Turso 0.7.1
sqlite3: 3.51.0
embedded libSQL: 0.9.30

stock integrity_check:
Error: in prepare, unknown function: libsql_vector_idx()

stock dump/reimport:
Parse error near line 10: no such function: libsql_vector_idx

Turso Database open:
Error: Parse error: Error: invalid expression in CREATE INDEX: libsql_vector_idx (v)

local sqld /dump reimport:
Parse error near line 10: no such function: libsql_vector_idx

post_recovery_dump_reimport: ok
post_recovery_embedding_blob_hex: 0000803F00000040
same_libsql_schema_without_index: portable
control_integrity_check: ok
turso_owned_stock_integrity_check: ok
embedded libSQL stock/Turso/dump failures: reproduced

PASS: All expected portability failures and the remediation were reproduced.
```

## Debian Linux arm64

The server path was repeated in a clean `debian:bookworm-slim` arm64
environment on 30 July 2026. The script downloaded and checksum-verified the
official release archives itself.

```text
platform: Linux aarch64
sqld: sqld 0.24.32 (40c272de)
tursodb: Turso 0.7.1
sqlite3: 3.40.1

stock integrity_check:
Error: in prepare, unknown function: libsql_vector_idx()

stock dump/reimport:
Parse error near line 10: no such function: libsql_vector_idx

Turso Database open:
Error: Parse error: Error: invalid expression in CREATE INDEX: libsql_vector_idx (v)

local sqld /dump reimport:
Parse error near line 10: no such function: libsql_vector_idx

post_recovery_dump_reimport: ok
post_recovery_embedding_blob_hex: 0000803F00000040
same_libsql_schema_without_index: portable
control_integrity_check: ok
turso_owned_stock_integrity_check: ok

PASS: All expected portability failures and the remediation were reproduced.
```

## Linux x86_64 (refresh)

Run on 8 September 2026 with `FORCE_DOWNLOADS=true`, `RUN_EMBEDDED=true`, and
pinned release archives verified against the refreshed checksum manifest
(Turso Database 0.7.2):

```text
platform: Linux x86_64
sqld: sqld 0.24.32 (40c272de 2025-02-14)
tursodb: Turso 0.7.2
sqlite3: 3.45.1
embedded libSQL: 0.9.30

stock integrity_check:
Error: in prepare, unknown function: libsql_vector_idx()

stock dump/reimport:
Parse error near line 10: no such function: libsql_vector_idx

Turso Database open:
Error: Parse error: Error: invalid expression in CREATE INDEX: libsql_vector_idx (v)

local sqld /dump reimport:
Parse error near line 10: no such function: libsql_vector_idx

post_recovery_dump_reimport: ok
post_recovery_embedding_blob_hex: 0000803F00000040
same_libsql_schema_without_index: portable
control_integrity_check: ok
turso_owned_stock_integrity_check: ok
wal_after_clean_exit: empty_or_absent

embedded libSQL stock integrity_check:
Error: in prepare, unknown function: libsql_vector_idx()

embedded libSQL Turso Database open:
Error: Parse error: Error: invalid expression in CREATE INDEX: libsql_vector_idx (v)

embedded libSQL dump/reimport:
Parse error near line 10: no such function: libsql_vector_idx

PASS: All expected portability failures and the remediation were reproduced.
```

The server-path reproduction passed in the public package on a clean
GitHub-hosted Ubuntu x86-64 runner at the July 2026 pinned evidence snapshot
[`f4f9a6ee53d95b8caa88ac140fc60d06bbd94d3b`](https://github.com/withnative/libsql-vector-portability-evidence/tree/f4f9a6ee53d95b8caa88ac140fc60d06bbd94d3b).
The [successful workflow run](https://github.com/withnative/libsql-vector-portability-evidence/actions/runs/30550751954)
uploaded its exact `results.txt` transcript. After the refreshed evidence
commit is pushed, replace `REFRESH_COMMIT` in this file and in
[`REPORT.md`](./REPORT.md) with the immutable commit SHA and add the matching
public workflow-run URL; see [`PUBLICATION.md`](./PUBLICATION.md).

## What the script asserts

Every clean run independently checks:

- the release archive against `checksums/RELEASES.sha256` and the corresponding
  upstream checksum asset;
- the exact vector blob bytes;
- stock SQLite's integrity-check and dump/reimport failures;
- Turso Database's whole-file-open failure;
- the local server `/dump` reimport failure;
- data-preserving recovery, clean dump/reimport, and Turso Database open;
- an otherwise identical no-index libSQL control; and
- a vanilla Turso Database file opened by stock SQLite.

When Cargo is available, it repeats the portability failures for a database
created by embedded Rust `libsql` 0.9.30.

## Standalone package validation (historical, 30 July 2026)

On 30 July 2026 the extracted standalone package was validated again on macOS
arm64 against Turso Database **0.7.1** release checksums (superseded in the
September 2026 refresh by Turso Database 0.7.2 pins in
[`checksums/RELEASES.sha256`](./checksums/RELEASES.sha256)):

```text
libsql-server-aarch64-apple-darwin.tar.xz:
  pinned SHA-256 ced2a9d65a5d4b6bd72c67e98ad6c63139e2a139d91769f07fdd15be935381dd
turso_cli-aarch64-apple-darwin.tar.xz:
  pinned SHA-256 3730677c16aa595ebbaadcd3e5ce29fa19cefd280df9dd4ec5a26f1cacc2ea7c
server path with forced release downloads: PASS
embedded libSQL 0.9.30 path: PASS
```

Both upstream `.sha256` assets agreed with the repository-owned manifest.
Shell parsing, ShellCheck, actionlint, Cargo metadata, and
`cargo check --locked` also passed.
