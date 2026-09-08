# Archive-source blockers

Richard Ng · Native · 8 September 2026

The Native archive source `1ea2173` referenced by refresh task `fc04d5a` is
not accessible from this worker. The claims below were not added to
[`REPORT.md`](./REPORT.md) because they could not be independently reproduced
with pinned upstream binaries and recorded transcripts.

## Withheld claims

1. Turso `PRAGMA integrity_check` reports `wrong # of entries in index` on a
   pristine Turso-created offline copy.
2. Stock SQLite's behaviour opening that runtime file.
3. Turso `PRAGMA wal_checkpoint` returns zero or hardcoded `log` and
   `checkpointed` counters regardless of WAL state.

## Reproduction attempts (8 September 2026)

Environment: Linux x86_64, Turso Database 0.7.1 and 0.7.2 release binaries
from `checksums/RELEASES.sha256`, stock SQLite 3.45.1.

### Claim 1 and 2: integrity_check on pristine Turso offline copies

Commands (representative; all returned `ok` on both Turso and stock SQLite):

```sh
tursodb -q with-index.db \
  "CREATE TABLE t(id INTEGER PRIMARY KEY, v TEXT); INSERT INTO t(v) VALUES('a'); CREATE INDEX idx ON t(v);"
tursodb -q with-index.db "PRAGMA integrity_check;"
sqlite3 with-index.db "PRAGMA integrity_check;"
cp with-index.db offline-copy.db
tursodb -q offline-copy.db "PRAGMA integrity_check;"
sqlite3 offline-copy.db "PRAGMA integrity_check;"
```

Expression-index variant (`CREATE INDEX idx ON t(length(v))`) and the
partial-index UPDATE case from
[Turso issue #5168](https://github.com/tursodatabase/turso/issues/5168) also
returned `ok` on Turso 0.7.1/0.7.2.

### Claim 3: wal_checkpoint counters

Turso-owned file after multiple shell-exit writes (empty `*.db-wal` sidecar,
`journal_mode=wal`):

```text
Turso wal_checkpoint(PASSIVE): busy=0, log=0, checkpointed=0
Stock wal_checkpoint(PASSIVE):  0|0|0
```

Live `sqld` 0.24.32 data file before explicit checkpoint (`data-wal` present,
8272 bytes):

```text
Turso wal_checkpoint(PASSIVE): busy=0, log=2, checkpointed=2
Stock wal_checkpoint(PASSIVE):  0|0|0
```

The Turso-owned case matches an empty WAL. The sqld case shows Turso reporting
non-zero frame counts, so a blanket hardcoded-zero claim is not supported by
these runs. The original archive scenario remains unknown.

## Recommendation

Recover or restate the exact schema and copy/checkpoint sequence from archive
`1ea2173` before publishing claims (1)–(3). Until then, this evidence package
documents only the verified libSQL vector-index portability gap.
