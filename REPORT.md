# libSQL vector-index exports are not operationally portable to stock SQLite or Turso Database

Richard Ng · Native · 30 July 2026

## Summary

A libSQL database containing an index created with
`libsql_vector_idx(...)` remains a valid SQLite-format container, and its
vector values remain ordinary portable blobs. However, the schema contains an
engine-specific expression index that stock SQLite cannot validate or
reimport, and Turso Database 0.7.1 refuses to open the file.

This is not evidence of data corruption. It is a narrow schema-portability
gap: the application table and vector data remain readable, and removing the
vector-index schema objects restores a conventional SQLite database.

## Environment and reproduction

Primary run on 30 July 2026:

| Component | Version |
| --- | --- |
| Platform | macOS 26.3, arm64 |
| libSQL server (`sqld`) | 0.24.32 |
| Embedded Rust `libsql` | 0.9.30 |
| Turso Database (`tursodb`) | 0.7.1 |
| Stock SQLite | 3.51.0 |

The server-path reproduction also passed in a clean Debian Linux arm64
environment with stock SQLite 3.40.1. The included GitHub Actions workflow
runs the same assertions independently on Ubuntu x86-64. An earlier run with
Turso Database 0.7.0 produced the same Turso parse error.

As an upstream-current check, Turso Database main at
[`d95edf7b40bd2fce6c052e85de1a9c6423d0aec3`](https://github.com/tursodatabase/turso/commit/d95edf7b40bd2fce6c052e85de1a9c6423d0aec3)
(built locally as 0.8.0-pre.2) produced the same
`invalid expression ... libsql_vector_idx` error. libSQL main at
[`6f451a1fabacbcbc9960b232b4c1605a5021979b`](https://github.com/tursodatabase/libsql/commit/6f451a1fabacbcbc9960b232b4c1605a5021979b)
was source-audited; a local `sqld` build reached the final macOS link step but
failed because a bundled pcre2 archive member was not Mach-O, so `sqld`
0.24.32 remains the empirical server baseline.

The complete [`reproduce.sh`](./reproduce.sh) downloads and
checksum-verifies pinned `sqld` and `tursodb` binaries, creates the database,
checkpoints its WAL, tests both the file and local server dump, verifies
recovery and controls, and optionally repeats creation through embedded
libSQL:

```sh
./reproduce.sh
```

Recorded macOS and Debian results are included in
[`VERIFICATION.md`](./VERIFICATION.md). Public provenance for this package:

- [Pinned evidence snapshot `f4f9a6ee53d95b8caa88ac140fc60d06bbd94d3b`](https://github.com/withnative/libsql-vector-portability-evidence/tree/f4f9a6ee53d95b8caa88ac140fc60d06bbd94d3b)
- [Successful clean Ubuntu x86-64 workflow run](https://github.com/withnative/libsql-vector-portability-evidence/actions/runs/30550751954)

## Minimal reproduction

The schema reduces to one table, one vector column, one row, and one index:

```sql
CREATE TABLE embeddings(
  id INTEGER PRIMARY KEY,
  v F32_BLOB(2)
);

INSERT INTO embeddings(v)
VALUES(vector32('[1.0,2.0]'));

CREATE INDEX idx_emb_vec
  ON embeddings(libsql_vector_idx(v));
```

libSQL 0.24.32 additionally creates:

```sql
CREATE TABLE libsql_vector_meta_shadow (...);
CREATE TABLE idx_emb_vec_shadow (...);
CREATE INDEX idx_emb_vec_shadow_idx
  ON idx_emb_vec_shadow (...);
```

For a database produced through `sqld`, a WAL-aware SQLite connection must
first run `PRAGMA wal_checkpoint(TRUNCATE)`. This incorporates the WAL into
the main database before it is copied or tested as a standalone artifact.

## Observed behaviour

Stock SQLite can query the application table and read the vector value:

```text
0000803F00000040
```

This is the expected little-endian float32 encoding of `[1.0, 2.0]`. The
failures are caused by the vector-index schema entry, not the stored data.

Stock SQLite cannot complete an integrity check:

```text
Error: in prepare, unknown function: libsql_vector_idx()
```

It can emit a textual dump, but that dump cannot be imported into a new stock
SQLite database:

```text
Parse error near line 10: no such function: libsql_vector_idx
  CREATE INDEX idx_emb_vec ON embeddings(libsql_vector_idx(v));
                           error here ---^
```

Turso Database 0.7.1 refuses to open the same file:

```text
Error: Parse error: Error: invalid expression in CREATE INDEX: libsql_vector_idx (v)
```

Creating the schema through embedded `libsql` 0.9.30 produces the same file
shape and all three failures, so this is not specific to the server path.

An exact causal control isolates the index as the trigger: an otherwise
identical libSQL database with the same `F32_BLOB(2)` column and vector row,
but without `CREATE INDEX ... libsql_vector_idx(...)`, passes
`integrity_check`, dumps and reimports cleanly, and opens in Turso Database.
The declared type and vector bytes are not themselves the portability problem.

As a separate positive control, a vanilla database written by Turso Database
0.7.1 passes stock SQLite's `integrity_check` without modification. On clean
shell exit, its WAL is empty or absent. That is a cleaner standalone-file
result than current `sqld`, whose database requires an explicit checkpoint
before copying.

## Export path and blast radius

The local `sqld` 0.24.32 `/dump` endpoint emits the vector-index statement,
shared metadata table, per-index shadow table, and ordinary shadow-table
index. Importing that dump into stock SQLite fails at
`libsql_vector_idx(...)`; the local server exporter therefore does not
sanitise this feature. [libSQL PR #1591](https://github.com/tursodatabase/libsql/pull/1591)
deliberately retained the DiskANN shadow state for faithful libSQL-to-libSQL
restoration, so this is intentional full-state dump behaviour rather than
evidence that the exporter accidentally leaked internal objects.

Turso CLI source at
[`b65778d3f0721206a5642ba02d7a035f1e11f3f6`](https://github.com/tursodatabase/turso-cli/commit/b65778d3f0721206a5642ba02d7a035f1e11f3f6)
shows that `turso db shell <db> .dump` calls the same HTTP `/dump` endpoint
documented for SDK use. `turso db export` is a distinct raw generation
snapshot plus WAL or logical-log workflow, not a sanitising logical dump. The
CLI shell documentation says dumps omit libSQL or SQLite internal tables,
while the HTTP reference explicitly shows a vector dump containing internally
managed tables and non-stock `USING diskann_cosine_ops` syntax. Those
published expectations are inconsistent.

We did not test a managed Turso Cloud database because no authenticated CLI or
Cloud credentials were available; production Cloud behaviour is therefore
untested, not claimed as affected here.

Source history places the vector-index implementation in server release
0.24.18. That release stores one vector index as the marker expression index,
a per-index `<index-name>_shadow` table, and the shared
`libsql_vector_meta_shadow` table: three vector-related schema objects in the
one-index case. Commit
[`5eeba4330901f022963bf50cf35e3e7120cf1a09`](https://github.com/tursodatabase/libsql/commit/5eeba4330901f022963bf50cf35e3e7120cf1a09)
added the ordinary `<index-name>_shadow_idx` index on 8 August 2024; it appears
in 0.24.20, 0.24.32, and current sources, giving those versions four objects
in the one-index case. This makes recovery mechanically discoverable across
the versions inspected, but the names are internal rather than a documented
compatibility contract. The three-statement recovery below works in later
versions because dropping the shadow table also removes its ordinary index.

A date-bounded search through 30 July 2026 found no issue specifically
covering Turso Database's refusal to open an existing libSQL vector-index
file. libSQL PR #1591 addressed `.dump` and `VACUUM` within libSQL's own fork.
[Turso issue #3987](https://github.com/tursodatabase/turso/issues/3987)
documents the underlying inability to create a `libsql_vector_idx` expression
index. [Turso issue #1530](https://github.com/tursodatabase/turso/issues/1530)
delivered general expression-index support, but does not make the libSQL
marker function known. The whole-file-open failure is therefore best
presented as a new cross-engine interoperability case linked to #3987, not as
a duplicate or as proof that no related work exists.

## Verified recovery

For this one-index reproduction, stock SQLite can make the file portable again
with:

```sql
DROP INDEX idx_emb_vec;
DROP TABLE idx_emb_vec_shadow;
DROP TABLE libsql_vector_meta_shadow;
PRAGMA integrity_check;
```

The asserted recovery preserves the `embeddings` table and exact vector blob,
restores `integrity_check = ok`, dumps and reimports cleanly, and allows Turso
Database 0.7.1 to open and query the file.

Two cautions matter for real databases:

1. Begin with the complete database/WAL pair and checkpoint it before treating
   the main file as standalone.
2. With multiple vector indexes, enumerate and remove every vector index and
   corresponding `<index-name>_shadow` table first. Remove the shared
   `libsql_vector_meta_shadow` table only after no vector indexes remain.

This discards the search indexes, not the embeddings. Recreate the indexes
when returning to an engine that supports them.

## Documentation context and possible directions

libSQL's SQLite compatibility statement is explicitly conditional: it commits
to producing standard SQLite files if format-changing features are not used.
The result above should therefore not be framed as a broken promise. The exact
no-index control confirms that the ordinary file remains portable when the
vector index is absent. Stock SQLite's rejection also follows its documented
expression-index rules: an application-defined function used in an index must
be registered and deterministic.

The narrower issue is operational discoverability: the documented
vector-index expression leaves application data portable but makes common
stock-SQLite validation and dump/reimport workflows fail, while Turso Database
rejects the complete file rather than opening it with an unsupported index
disabled.

Possible improvements include:

- offering an optional portable export mode that removes vector indexes and
  shadow state while preserving vector columns and data, without changing the
  existing full-state dump's libSQL-to-libSQL semantics;
- documenting vector indexes as engine-specific schema objects and publishing
  a supported removal recipe; or
- allowing Turso Database to open such files with the unsupported index
  disabled, so the remaining data can be read and exported.

## References

- [Reproduction script](./reproduce.sh)
- [Recorded verification runs](./VERIFICATION.md)
- [Pinned release checksums](./checksums/RELEASES.sha256)
- [Clean-run GitHub Actions workflow](./.github/workflows/reproduce.yml)
- [libSQL compatibility statement](https://github.com/tursodatabase/libsql#compatibility-with-sqlite)
- [Turso `.dump` documentation](https://docs.turso.tech/cli/db/shell#database-dump)
- [Turso HTTP `/dump` reference](https://docs.turso.tech/sdk/http/reference#get-dump)
- [libSQL PR #1591](https://github.com/tursodatabase/libsql/pull/1591)
- [Turso issue #3987](https://github.com/tursodatabase/turso/issues/3987)
- [Turso expression-index issue #1530](https://github.com/tursodatabase/turso/issues/1530)
- [SQLite indexes on expressions](https://www.sqlite.org/expridx.html)
- [libSQL main audited commit](https://github.com/tursodatabase/libsql/commit/6f451a1fabacbcbc9960b232b4c1605a5021979b)
- [Turso Database main verified commit](https://github.com/tursodatabase/turso/commit/d95edf7b40bd2fce6c052e85de1a9c6423d0aec3)
- [Turso CLI audited commit](https://github.com/tursodatabase/turso-cli/commit/b65778d3f0721206a5642ba02d7a035f1e11f3f6)
- [Commit adding `<index-name>_shadow_idx`](https://github.com/tursodatabase/libsql/commit/5eeba4330901f022963bf50cf35e3e7120cf1a09)
- [Turso `db export` documentation](https://docs.turso.tech/cli/db/export)
