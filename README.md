# libSQL vector-index portability evidence

Report and reproduction by Richard Ng. Published by Native.

This repository contains a minimal, assertion-driven reproduction of a narrow
schema-portability gap. A libSQL database containing an index created with
`libsql_vector_idx(...)` keeps its application data and vector blobs in a
SQLite-format file, but stock SQLite cannot validate or reimport the schema,
and Turso Database 0.7.1 refuses to open the file.

Start with the standalone [report](./REPORT.md). The exact historical results
are in [VERIFICATION.md](./VERIFICATION.md).

## Run

Requirements:

- Bash
- `curl`
- a `tar` with xz support
- stock `sqlite3`
- macOS or Linux on arm64 or x86-64

Run the complete reproduction:

```sh
./reproduce.sh
```

The script downloads the pinned libSQL server 0.24.32 and Turso Database 0.7.1
release archives when matching executables are not already installed. It
verifies them against the repository-owned
[checksum manifest](./checksums/RELEASES.sha256) and the upstream checksum
assets. It uses the `sqlite3` on `PATH` and records its exact version.
Set `FORCE_DOWNLOADS=true` to download and verify the release archives even
when matching binaries are already installed.

If Rust and Cargo are installed, the default `RUN_EMBEDDED=auto` also repeats
database creation through embedded `libsql` 0.9.30. Use
`RUN_EMBEDDED=false` for the server path only, or `RUN_EMBEDDED=true` to
require the embedded check.

To retain generated artifacts, point `OUTPUT_DIR` at a missing or empty
directory:

```sh
OUTPUT_DIR="$PWD/results" RUN_EMBEDDED=false ./reproduce.sh
```

The script refuses a non-empty `OUTPUT_DIR`; it does not delete existing
files. It starts a loopback-only local server, makes network requests only to
the pinned GitHub release URLs, and writes database files only below its
output directory. Supply executables explicitly with `SQLD_BIN`,
`TURSODB_BIN`, `SQLITE3_BIN`, and `CARGO_BIN`.

## Expected result

The run succeeds only when it observes all expected portability failures and
all recovery/control successes. The headline failures are:

```text
stock SQLite integrity_check:
unknown function: libsql_vector_idx()

stock SQLite dump/reimport:
no such function: libsql_vector_idx

Turso Database open:
invalid expression in CREATE INDEX: libsql_vector_idx (v)
```

It then verifies on a copy that removing the one vector index and its internal
shadow state preserves the application row and exact embedding bytes, restores
`integrity_check = ok`, reimports cleanly, and opens with Turso Database.

## Limitations

- Managed Turso Cloud was not tested.
- The removal recipe is specific to this one-index reproduction. Real
  databases must enumerate every vector index and retain the complete
  database/WAL pair before checkpointing and recovery.
- The release checksums are integrity evidence, not publisher signatures.
- The embedded Rust path requires a native Rust toolchain and may take several
  minutes to compile.

The GitHub Actions workflow runs the server path on a clean Ubuntu x86-64
runner and uploads `results.txt`.

## License

Copyright 2026 Richard Ng. Licensed under the
[Apache License 2.0](./LICENSE). Attribution details are in
[`NOTICE`](./NOTICE).
