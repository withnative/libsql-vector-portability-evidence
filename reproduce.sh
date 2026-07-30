#!/usr/bin/env bash
set -euo pipefail

# Minimal reproduction for libSQL vector-index export portability.
#
# Defaults are the latest stable releases as of 2026-07-30. Override any
# executable with SQLD_BIN, TURSODB_BIN, SQLITE3_BIN, or CARGO_BIN.

SQLD_VERSION="${SQLD_VERSION:-0.24.32}"
TURSODB_VERSION="${TURSODB_VERSION:-0.7.1}"
LIBSQL_RUST_VERSION="0.9.30"
SQLITE3_BIN="${SQLITE3_BIN:-sqlite3}"
CARGO_BIN="${CARGO_BIN:-cargo}"
RUN_EMBEDDED="${RUN_EMBEDDED:-auto}"
FORCE_DOWNLOADS="${FORCE_DOWNLOADS:-false}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="${OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/libsql-vector-portability.XXXXXX")}"
release_checksums="$script_dir/checksums/RELEASES.sha256"

if [[ -e "$output_dir" && ! -d "$output_dir" ]]; then
  printf 'FAIL: OUTPUT_DIR is not a directory: %s\n' "$output_dir" >&2
  exit 1
fi
if [[ -n "${OUTPUT_DIR:-}" && -d "$output_dir" ]] &&
   find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
  printf 'FAIL: OUTPUT_DIR must be empty: %s\n' "$output_dir" >&2
  exit 1
fi

download_dir="$output_dir/downloads"
mkdir -p "$download_dir"

results_file="$output_dir/results.txt"
exec > >(tee "$results_file") 2>&1

section() {
  printf '\n== %s ==\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    shasum -a 256 "$file" | awk '{print $1}'
  fi
}

verify_pinned_checksum() {
  local archive_path="$1"
  local archive
  local expected
  local actual

  archive="$(basename "$archive_path")"
  expected="$(
    awk -v target="*$archive" '$2 == target { print $1 }' "$release_checksums"
  )"
  [[ -n "$expected" ]] || fail "no pinned checksum for $archive"
  actual="$(sha256_file "$archive_path")"
  [[ "$actual" == "$expected" ]] ||
    fail "checksum mismatch for $archive: expected $expected, got $actual"
  printf '%s: OK (pinned SHA-256 %s)\n' "$archive" "$actual" >&2
}

download_release_binary() {
  local project="$1"
  local version="$2"
  local asset_prefix="$3"
  local binary_name="$4"
  local os_name
  local arch_name

  case "$(uname -s)" in
    Darwin) os_name="apple-darwin" ;;
    Linux) os_name="unknown-linux-gnu" ;;
    *) fail "unsupported operating system: $(uname -s)" ;;
  esac

  case "$(uname -m)" in
    arm64|aarch64) arch_name="aarch64" ;;
    x86_64|amd64) arch_name="x86_64" ;;
    *) fail "unsupported architecture: $(uname -m)" ;;
  esac

  local tag
  local archive
  if [[ "$project" == "libsql" ]]; then
    tag="libsql-server-v${version}"
    archive="${asset_prefix}-${arch_name}-${os_name}.tar.xz"
  else
    tag="v${version}"
    archive="${asset_prefix}-${arch_name}-${os_name}.tar.xz"
  fi

  local base_url="https://github.com/tursodatabase/${project}/releases/download/${tag}"
  curl -fsSLo "$download_dir/$archive" "$base_url/$archive"
  verify_pinned_checksum "$download_dir/$archive"
  curl -fsSLo "$download_dir/$archive.upstream.sha256" \
    "$base_url/$archive.sha256"
  local pinned
  pinned="$(
    awk -v target="*$archive" '$2 == target { print $1 }' "$release_checksums"
  )"
  require_contains "$download_dir/$archive.upstream.sha256" "$pinned"
  tar -xJf "$download_dir/$archive" -C "$download_dir"

  local resolved
  resolved="$(find "$download_dir" -type f -name "$binary_name" -perm -111 -print | head -1)"
  [[ -n "$resolved" ]] || fail "could not find $binary_name in $archive"
  printf '%s\n' "$resolved"
}

require_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$file"; then
    printf 'Expected to find:\n%s\n\nIn:\n' "$expected" >&2
    sed -n '1,200p' "$file" >&2
    fail "expected output was not observed"
  fi
}

require_command curl
require_command tar
require_command "$SQLITE3_BIN"
[[ -f "$release_checksums" ]] || fail "checksum manifest not found"

case "$FORCE_DOWNLOADS" in
  1|true|yes) force_downloads=true ;;
  0|false|no) force_downloads=false ;;
  *) fail "FORCE_DOWNLOADS must be true or false" ;;
esac

if [[ -n "${SQLD_BIN:-}" ]]; then
  sqld_bin="$SQLD_BIN"
elif [[ "$force_downloads" == "false" ]] &&
     command -v sqld >/dev/null 2>&1 &&
     sqld --version 2>&1 | grep -Fq "$SQLD_VERSION"; then
  sqld_bin="$(command -v sqld)"
else
  sqld_bin="$(download_release_binary libsql "$SQLD_VERSION" libsql-server sqld)"
fi

if [[ -n "${TURSODB_BIN:-}" ]]; then
  tursodb_bin="$TURSODB_BIN"
elif [[ "$force_downloads" == "false" ]] &&
     command -v tursodb >/dev/null 2>&1 &&
     tursodb --version 2>&1 | grep -Fq "$TURSODB_VERSION"; then
  tursodb_bin="$(command -v tursodb)"
else
  tursodb_bin="$(download_release_binary turso "$TURSODB_VERSION" turso_cli tursodb)"
fi

section "environment"
printf 'date_utc: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf 'platform: %s %s\n' "$(uname -s)" "$(uname -m)"
printf 'sqld: %s\n' "$("$sqld_bin" --version 2>&1)"
printf 'tursodb: %s\n' "$("$tursodb_bin" --version 2>&1)"
printf 'sqlite3: %s\n' "$("$SQLITE3_BIN" --version 2>&1)"
printf 'output: %s\n' "$output_dir"

server_dir="$output_dir/server"
server_log="$output_dir/sqld.log"
pipeline_result="$output_dir/create.json"
server_dump="$output_dir/server-dump.sql"
mkdir -p "$server_dir"

port=$((20000 + ($$ % 20000)))
server_url="http://127.0.0.1:$port"
"$sqld_bin" \
  --db-path "$server_dir" \
  --http-listen-addr "127.0.0.1:$port" \
  --no-welcome \
  >"$server_log" 2>&1 &
sqld_pid=$!

cleanup_server() {
  kill "$sqld_pid" 2>/dev/null || true
  wait "$sqld_pid" 2>/dev/null || true
}
trap cleanup_server EXIT

ready=false
for _ in $(seq 1 100); do
  if curl -fsS -o /dev/null "$server_url/health" 2>/dev/null; then
    ready=true
    break
  fi
  sleep 0.1
done
[[ "$ready" == "true" ]] || fail "sqld did not become ready; see $server_log"

section "create minimal libSQL database"
curl -fsS \
  -X POST \
  -H 'content-type: application/json' \
  --data-binary @- \
  "$server_url/v2/pipeline" \
  >"$pipeline_result" <<'JSON'
{"requests":[{"type":"execute","stmt":{"sql":"CREATE TABLE embeddings(id INTEGER PRIMARY KEY, v F32_BLOB(2))"}},{"type":"execute","stmt":{"sql":"INSERT INTO embeddings(v) VALUES(vector32('[1.0,2.0]'))"}},{"type":"execute","stmt":{"sql":"CREATE INDEX idx_emb_vec ON embeddings(libsql_vector_idx(v))"}},{"type":"close"}]}
JSON
if grep -Fq '"type":"error"' "$pipeline_result"; then
  sed -n '1,200p' "$pipeline_result"
  fail "sqld rejected the minimal schema"
fi
printf '%s\n' 'created one table, one row, and one vector index'

section "sqld /dump output"
curl -fsS "$server_url/dump" -o "$server_dump"
sed -n '1,80p' "$server_dump"
require_contains "$server_dump" \
  'CREATE INDEX idx_emb_vec ON embeddings(libsql_vector_idx(v));'
require_contains "$server_dump" \
  'CREATE TABLE IF NOT EXISTS libsql_vector_meta_shadow'
require_contains "$server_dump" \
  'CREATE TABLE IF NOT EXISTS idx_emb_vec_shadow'

cleanup_server
trap - EXIT

live_data="$server_dir/dbs/default/data"
[[ -f "$live_data" ]] || fail "sqld data file not found at $live_data"

section "checkpoint WAL into a standalone file"
"$SQLITE3_BIN" "$live_data" 'PRAGMA wal_checkpoint(TRUNCATE);'
export_file="$output_dir/libsql-vector.db"
cp "$live_data" "$export_file"
printf 'standalone_file: %s\n' "$export_file"

section "schema written by sqld"
"$SQLITE3_BIN" "$export_file" \
  "SELECT type || '|' || name || '|' || sql FROM sqlite_schema ORDER BY type,name;"
portable_blob="$("$SQLITE3_BIN" "$export_file" 'SELECT hex(v) FROM embeddings;')"
[[ "$portable_blob" == "0000803F00000040" ]] || fail "unexpected vector blob: $portable_blob"
printf 'embedding_blob_hex: %s\n' "$portable_blob"

section "stock sqlite3 integrity_check"
stock_integrity="$output_dir/stock-integrity.txt"
("$SQLITE3_BIN" "$export_file" 'PRAGMA integrity_check;' >"$stock_integrity" 2>&1) || true
sed -n '1,80p' "$stock_integrity"
require_contains "$stock_integrity" 'unknown function: libsql_vector_idx()'

section "stock sqlite3 dump and reimport"
stock_reimport="$output_dir/stock-reimport.txt"
("$SQLITE3_BIN" "$export_file" .dump | \
  "$SQLITE3_BIN" "$output_dir/reimport.db" >"$stock_reimport" 2>&1) || true
sed -n '1,80p' "$stock_reimport"
require_contains "$stock_reimport" 'no such function: libsql_vector_idx'

section "Turso Database open"
turso_open="$output_dir/turso-open.txt"
("$tursodb_bin" -q "$export_file" '.tables' >"$turso_open" 2>&1) || true
sed -n '1,80p' "$turso_open"
require_contains "$turso_open" \
  'invalid expression in CREATE INDEX: libsql_vector_idx (v)'

section "server /dump reimport into stock sqlite3"
server_dump_reimport="$output_dir/server-dump-reimport.txt"
("$SQLITE3_BIN" "$output_dir/server-dump.db" \
  <"$server_dump" >"$server_dump_reimport" 2>&1) || true
sed -n '1,80p' "$server_dump_reimport"
require_contains "$server_dump_reimport" 'no such function: libsql_vector_idx'

section "verified remediation"
portable_file="$output_dir/portable.db"
cp "$export_file" "$portable_file"
"$SQLITE3_BIN" "$portable_file" <<'SQL'
DROP INDEX idx_emb_vec;
DROP TABLE idx_emb_vec_shadow;
DROP TABLE libsql_vector_meta_shadow;
PRAGMA integrity_check;
SQL

portable_integrity="$("$SQLITE3_BIN" "$portable_file" 'PRAGMA integrity_check;')"
[[ "$portable_integrity" == "ok" ]] || fail "remediated file failed integrity_check"
"$tursodb_bin" -q "$portable_file" 'SELECT count(*) FROM embeddings;'
portable_blob="$("$SQLITE3_BIN" "$portable_file" 'SELECT hex(v) FROM embeddings;')"
[[ "$portable_blob" == "0000803F00000040" ]] || fail "remediation changed vector data"
portable_dump="$output_dir/portable-dump.sql"
"$SQLITE3_BIN" "$portable_file" .dump >"$portable_dump"
"$SQLITE3_BIN" "$output_dir/portable-reimport.db" <"$portable_dump"
portable_reimport_integrity="$(
  "$SQLITE3_BIN" "$output_dir/portable-reimport.db" 'PRAGMA integrity_check;'
)"
[[ "$portable_reimport_integrity" == "ok" ]] || \
  fail "remediated dump/reimport failed integrity_check"
printf 'post_recovery_dump_reimport: ok\n'
printf 'post_recovery_embedding_blob_hex: %s\n' "$portable_blob"

section "causal control: identical libSQL database without the vector index"
control_server_dir="$output_dir/control-server"
control_server_log="$output_dir/control-sqld.log"
control_pipeline_result="$output_dir/control-create.json"
mkdir -p "$control_server_dir"
"$sqld_bin" \
  --db-path "$control_server_dir" \
  --http-listen-addr "127.0.0.1:$port" \
  --no-welcome \
  >"$control_server_log" 2>&1 &
sqld_pid=$!
trap cleanup_server EXIT

ready=false
for _ in $(seq 1 100); do
  if curl -fsS -o /dev/null "$server_url/health" 2>/dev/null; then
    ready=true
    break
  fi
  sleep 0.1
done
[[ "$ready" == "true" ]] || \
  fail "control sqld did not become ready; see $control_server_log"

curl -fsS \
  -X POST \
  -H 'content-type: application/json' \
  --data-binary @- \
  "$server_url/v2/pipeline" \
  >"$control_pipeline_result" <<'JSON'
{"requests":[{"type":"execute","stmt":{"sql":"CREATE TABLE embeddings(id INTEGER PRIMARY KEY, v F32_BLOB(2))"}},{"type":"execute","stmt":{"sql":"INSERT INTO embeddings(v) VALUES(vector32('[1.0,2.0]'))"}},{"type":"close"}]}
JSON
if grep -Fq '"type":"error"' "$control_pipeline_result"; then
  sed -n '1,200p' "$control_pipeline_result"
  fail "sqld rejected the no-index control schema"
fi

cleanup_server
trap - EXIT

control_live_data="$control_server_dir/dbs/default/data"
[[ -f "$control_live_data" ]] || fail "control sqld data file not found"
"$SQLITE3_BIN" "$control_live_data" 'PRAGMA wal_checkpoint(TRUNCATE);'
control_file="$output_dir/no-vector-index-control.db"
cp "$control_live_data" "$control_file"
control_blob="$("$SQLITE3_BIN" "$control_file" 'SELECT hex(v) FROM embeddings;')"
[[ "$control_blob" == "0000803F00000040" ]] || fail "unexpected control vector blob"
control_integrity="$("$SQLITE3_BIN" "$control_file" 'PRAGMA integrity_check;')"
[[ "$control_integrity" == "ok" ]] || fail "no-index control failed integrity_check"
"$SQLITE3_BIN" "$control_file" .dump >"$output_dir/control-dump.sql"
"$SQLITE3_BIN" "$output_dir/control-reimport.db" <"$output_dir/control-dump.sql"
"$tursodb_bin" -q "$control_file" 'SELECT count(*) FROM embeddings;'
printf 'same_libsql_schema_without_index: portable\n'
printf 'control_integrity_check: %s\n' "$control_integrity"

section "positive control: Turso-owned vanilla file"
turso_owned_file="$output_dir/turso-owned.db"
"$tursodb_bin" -q "$turso_owned_file" \
  "CREATE TABLE control(id INTEGER PRIMARY KEY, value TEXT); INSERT INTO control(value) VALUES('portable');" \
  >/dev/null
turso_owned_integrity="$("$SQLITE3_BIN" "$turso_owned_file" 'PRAGMA integrity_check;')"
[[ "$turso_owned_integrity" == "ok" ]] || fail "Turso-owned file failed stock integrity_check"
if [[ -e "$turso_owned_file-wal" && -s "$turso_owned_file-wal" ]]; then
  fail "Turso left a non-empty WAL after clean shell exit"
fi
printf 'stock_integrity_check: %s\n' "$turso_owned_integrity"
printf 'wal_after_clean_exit: empty_or_absent\n'

run_embedded=false
case "$RUN_EMBEDDED" in
  1|true|yes) run_embedded=true ;;
  0|false|no) run_embedded=false ;;
  auto)
    if command -v "$CARGO_BIN" >/dev/null 2>&1; then run_embedded=true; fi
    ;;
  *) fail "RUN_EMBEDDED must be auto, true, or false" ;;
esac

if [[ "$run_embedded" == "true" ]]; then
  section "embedded libSQL ${LIBSQL_RUST_VERSION}"
  embedded_file="$output_dir/embedded-libsql.db"
  "$CARGO_BIN" run \
    --quiet \
    --release \
    --manifest-path "$script_dir/embedded/Cargo.toml" \
    -- "$embedded_file"
  "$SQLITE3_BIN" "$embedded_file" '.schema'
  embedded_blob="$("$SQLITE3_BIN" "$embedded_file" 'SELECT hex(v) FROM embeddings;')"
  [[ "$embedded_blob" == "0000803F00000040" ]] || \
    fail "unexpected embedded vector blob: $embedded_blob"

  embedded_integrity="$output_dir/embedded-integrity.txt"
  ("$SQLITE3_BIN" "$embedded_file" \
    'PRAGMA integrity_check;' >"$embedded_integrity" 2>&1) || true
  sed -n '1,80p' "$embedded_integrity"
  require_contains "$embedded_integrity" 'unknown function: libsql_vector_idx()'

  embedded_turso="$output_dir/embedded-turso-open.txt"
  ("$tursodb_bin" -q "$embedded_file" \
    '.tables' >"$embedded_turso" 2>&1) || true
  sed -n '1,80p' "$embedded_turso"
  require_contains "$embedded_turso" \
    'invalid expression in CREATE INDEX: libsql_vector_idx (v)'

  embedded_reimport="$output_dir/embedded-reimport.txt"
  ("$SQLITE3_BIN" "$embedded_file" .dump | \
    "$SQLITE3_BIN" "$output_dir/embedded-reimport.db" \
    >"$embedded_reimport" 2>&1) || true
  sed -n '1,80p' "$embedded_reimport"
  require_contains "$embedded_reimport" \
    'no such function: libsql_vector_idx'
else
  section "embedded libSQL skipped"
  printf 'Set RUN_EMBEDDED=true and install Rust/Cargo to include the embedded-library check.\n'
fi

section "PASS"
printf 'All expected portability failures and the remediation were reproduced.\n'
printf 'Full results: %s\n' "$results_file"
