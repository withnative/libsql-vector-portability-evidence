# Release checksum provenance

`RELEASES.sha256` pins the SHA-256 digests published alongside the upstream
release archives used by `reproduce.sh`:

- libSQL server 0.24.32:
  `https://github.com/tursodatabase/libsql/releases/tag/libsql-server-v0.24.32`
- Turso Database 0.7.2:
  `https://github.com/tursodatabase/turso/releases/tag/v0.7.2`

The libSQL server digests were retrieved from each archive's adjacent `.sha256`
asset on 30 July 2026. The Turso Database digests were retrieved from each
archive's adjacent `.sha256` asset on 8 September 2026. The reproduction
verifies the downloaded archive against this repository-owned manifest and
separately checks that the current upstream checksum file contains the same
pinned digest.

These checksums provide integrity and provenance evidence for the downloaded
release assets. They are not signatures and do not establish the identity of
the publisher independently of GitHub's release hosting.
