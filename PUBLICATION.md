# Publication provenance

This package is published at
`https://github.com/withnative/libsql-vector-portability-evidence`.

- License: Apache-2.0
- Copyright: Richard Ng
- Report author: Richard Ng
- Publisher: Native

The versioned commit that passes the clean public workflow is the pinned
evidence snapshot. A later metadata-only commit replaces the `REFRESH_COMMIT`
placeholder in `REPORT.md` and `VERIFICATION.md` with the immutable commit
SHA and adds the successful public workflow-run URL. The metadata commit does
not change the evidence, scripts, checksums, or substantive report text.

Post-push substitution (required once per refresh evidence snapshot):

1. Push the evidence commit and note its full SHA.
2. In `REPORT.md` and `VERIFICATION.md`, replace every literal `REFRESH_COMMIT`
   with that SHA (for example in
   `https://github.com/withnative/libsql-vector-portability-evidence/tree/REFRESH_COMMIT`).
3. Add the successful GitHub Actions workflow-run URL for that commit.
4. Commit those metadata-only edits as a separate follow-up commit.

If those materials change, treat the resulting commit as a new evidence
snapshot and run the complete verification again.
